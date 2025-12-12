import Foundation
import Combine

// MARK: - Configuration Validation Error

/// Error types for configuration validation with actionable messages
enum ConfigurationValidationError: LocalizedError, Equatable {
    case timeout
    case invalidCredentials(provider: String)
    case rateLimited(retryAfter: TimeInterval?)
    case networkError(String)
    case providerUnavailable(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return NSLocalizedString("Connection timed out. The provider may be slow or unavailable.", comment: "")
        case .invalidCredentials(let provider):
            return String(format: NSLocalizedString("Invalid credentials for %@.", comment: ""), provider)
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return String(format: NSLocalizedString("Rate limited. Try again in %.0f seconds.", comment: ""), seconds)
            }
            return NSLocalizedString("Rate limited. Try again later.", comment: "")
        case .networkError(let message):
            return String(format: NSLocalizedString("Network error: %@", comment: ""), message)
        case .providerUnavailable(let provider):
            return String(format: NSLocalizedString("%@ is currently unavailable.", comment: ""), provider)
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .timeout:
            return NSLocalizedString("Try again or check your network connection.", comment: "")
        case .invalidCredentials:
            return NSLocalizedString("Edit the configuration to update your API key.", comment: "")
        case .rateLimited:
            return NSLocalizedString("Wait a moment before trying again.", comment: "")
        case .networkError:
            return NSLocalizedString("Check your internet connection and try again.", comment: "")
        case .providerUnavailable:
            return NSLocalizedString("Try again later or use a different configuration.", comment: "")
        case .unknown:
            return NSLocalizedString("Please try again.", comment: "")
        }
    }
    
    /// Maps HTTP status code to appropriate error
    static func from(statusCode: Int, provider: String, message: String?) -> ConfigurationValidationError {
        switch statusCode {
        case 401, 403:
            return .invalidCredentials(provider: provider)
        case 429:
            return .rateLimited(retryAfter: nil)
        case 500...599:
            return .providerUnavailable(provider)
        default:
            return .unknown(message ?? "HTTP \(statusCode)")
        }
    }
}

// MARK: - Configuration Validation Service

/// Service for validating AI configurations before switching
/// Handles timeout, cancellation, and error mapping
@MainActor
class ConfigurationValidationService: ObservableObject {
    
    // MARK: - Published State
    
    /// ID of the configuration currently being validated
    @Published private(set) var validatingConfigId: UUID?
    
    /// Current validation error (if any)
    @Published private(set) var validationError: ConfigurationValidationError?
    
    /// ID of the last successfully validated configuration (for success indicator)
    @Published private(set) var lastSuccessConfigId: UUID?
    
    // MARK: - Dependencies
    
    private weak var appSettings: AppSettingsStore?
    private let awsProfileService = AWSProfileService()
    
    // MARK: - Configuration
    
    /// Timeout for validation requests (5 seconds per requirements)
    private let validationTimeout: TimeInterval = 5.0
    
    /// Duration to show success indicator
    private let successIndicatorDuration: TimeInterval = 2.0
    
    // MARK: - Internal State
    
    /// Current validation task (for cancellation)
    private var currentValidationTask: Task<Void, Never>?
    
    /// Timer for clearing success indicator
    private var successClearTimer: Timer?
    
    // MARK: - Initialization
    
    init() {}
    
    /// Configure with AppSettingsStore
    func configure(with appSettings: AppSettingsStore) {
        self.appSettings = appSettings
    }
    
    // MARK: - Public Methods
    
    /// Initiates validated configuration switch
    /// - Parameter configId: The ID of the configuration to switch to
    func switchToConfiguration(id configId: UUID) {
        // Cancel any existing validation
        cancelValidation()
        
        // Clear previous error
        validationError = nil
        
        // Get the configuration
        guard let config = appSettings?.aiEnhancementConfigurations.first(where: { $0.id == configId }) else {
            validationError = .unknown(NSLocalizedString("Configuration not found", comment: ""))
            return
        }
        
        // Check if configuration is valid (has required fields)
        guard config.isValid else {
            validationError = .unknown(config.validationErrors.first ?? NSLocalizedString("Invalid configuration", comment: ""))
            return
        }
        
        // Set validating state
        validatingConfigId = configId
        
        // Start validation task
        currentValidationTask = Task { [weak self] in
            await self?.performValidation(config: config)
        }
    }
    
    /// Cancels any in-progress validation
    func cancelValidation() {
        currentValidationTask?.cancel()
        currentValidationTask = nil
        validatingConfigId = nil
    }
    
    /// Clears the current error state
    func clearError() {
        validationError = nil
    }
    
    // MARK: - Private Methods
    
    private func performValidation(config: AIEnhancementConfiguration) async {
        let configId = config.id
        let provider = AIProvider(rawValue: config.provider) ?? .gemini
        
        // Create validation task with timeout
        let result = await withTaskGroup(of: AIConfigurationValidator.ValidationResult?.self) { group in
            // Add validation task
            group.addTask {
                await self.validateConfiguration(config: config)
            }
            
            // Add timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.validationTimeout * 1_000_000_000))
                return nil // nil indicates timeout
            }
            
            // Return first completed result
            for await result in group {
                group.cancelAll()
                return result
            }
            return nil
        }
        
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        // Handle result
        await MainActor.run {
            // Ensure we're still validating this config
            guard self.validatingConfigId == configId else { return }
            
            self.validatingConfigId = nil
            
            if let result = result {
                if result.success {
                    // Success - update active configuration
                    self.appSettings?.setActiveConfiguration(id: configId)
                    self.showSuccessIndicator(configId: configId)
                } else {
                    // Failure - map error
                    if let statusCode = result.httpStatusCode {
                        self.validationError = ConfigurationValidationError.from(
                            statusCode: statusCode,
                            provider: provider.rawValue,
                            message: result.errorMessage
                        )
                    } else if result.errorMessage?.contains("timed out") == true {
                        self.validationError = .timeout
                    } else if result.errorMessage?.contains("cancelled") == true {
                        // Request was cancelled, don't show error
                    } else {
                        self.validationError = .unknown(result.errorMessage ?? NSLocalizedString("Validation failed", comment: ""))
                    }
                }
            } else {
                // Timeout
                self.validationError = .timeout
            }
        }
    }
    
    private func validateConfiguration(config: AIEnhancementConfiguration) async -> AIConfigurationValidator.ValidationResult {
        guard let provider = AIProvider(rawValue: config.provider) else {
            return .failure("Invalid provider")
        }
        
        switch provider {
        case .awsBedrock:
            return await validateBedrockConfiguration(config: config)
        case .anthropic:
            guard let apiKey = config.getApiKey() else {
                return .failure("API key not found")
            }
            return await AIConfigurationValidator.verifyAnthropicKey(
                apiKey: apiKey,
                model: config.model,
                timeout: validationTimeout
            )
        default:
            guard let apiKey = config.getApiKey() else {
                return .failure("API key not found")
            }
            return await AIConfigurationValidator.verifyOpenAICompatibleKey(
                apiKey: apiKey,
                provider: provider,
                model: config.model,
                timeout: validationTimeout
            )
        }
    }
    
    private func validateBedrockConfiguration(config: AIEnhancementConfiguration) async -> AIConfigurationValidator.ValidationResult {
        let region = config.region ?? "us-east-1"
        
        // Check authentication method
        if let profileName = config.awsProfileName, !profileName.isEmpty {
            // AWS Profile authentication
            do {
                let credentials = try await awsProfileService.resolveCredentials(for: profileName)
                return await AIConfigurationValidator.verifyAWSCredentials(
                    credentials: credentials,
                    region: region,
                    timeout: validationTimeout
                )
            } catch {
                return .failure("Failed to resolve AWS Profile: \(error.localizedDescription)")
            }
        } else if let accessKeyId = config.awsAccessKeyId, !accessKeyId.isEmpty,
                  let secretKey = config.getAwsSecretAccessKey(), !secretKey.isEmpty {
            // Access Key authentication
            let credentials = AWSCredentials(
                accessKeyId: accessKeyId,
                secretAccessKey: secretKey,
                sessionToken: nil,
                region: region
            )
            return await AIConfigurationValidator.verifyAWSCredentials(
                credentials: credentials,
                region: region,
                timeout: validationTimeout
            )
        } else if let apiKey = config.getApiKey(), !apiKey.isEmpty {
            // Bearer Token authentication
            return await AIConfigurationValidator.verifyBedrockBearerToken(
                apiKey: apiKey,
                region: region,
                modelId: config.model,
                timeout: validationTimeout
            )
        } else {
            return .failure("No valid authentication method found")
        }
    }
    
    private func showSuccessIndicator(configId: UUID) {
        lastSuccessConfigId = configId
        
        // Clear after duration
        successClearTimer?.invalidate()
        successClearTimer = Timer.scheduledTimer(withTimeInterval: successIndicatorDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lastSuccessConfigId = nil
            }
        }
    }
}
