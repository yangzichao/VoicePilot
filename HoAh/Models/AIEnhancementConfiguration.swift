import Foundation
import Security

/// Represents a complete AI Enhancement configuration profile
/// Each configuration contains all settings needed to connect to an AI provider.
/// NOTE: API keys are stored securely in Keychain, not in this struct
struct AIEnhancementConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var provider: String  // AIProvider.rawValue
    var model: String
    
    // Authentication - API Key stored in Keychain (this is just a flag)
    var hasApiKey: Bool
    var awsProfileName: String?   // AWS Profile name for SigV4 signing (Bedrock only)
    
    // Provider-specific settings
    var region: String?           // AWS Bedrock region (e.g., "us-east-1")
    var enableCrossRegion: Bool   // AWS Bedrock Cross-Region Inference
    
    // Metadata
    var createdAt: Date
    var lastUsedAt: Date?
    
    // MARK: - Keychain Key
    
    /// Keychain key for storing the API key
    private var keychainKey: String {
        "com.yangzichao.hoah.aiconfig.\(id.uuidString)"
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        provider: String,
        model: String,
        apiKey: String? = nil,
        awsProfileName: String? = nil,
        region: String? = nil,
        enableCrossRegion: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.model = model
        self.hasApiKey = false
        self.awsProfileName = awsProfileName
        self.region = region
        self.enableCrossRegion = enableCrossRegion
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        
        // Store API key in Keychain if provided
        if let key = apiKey, !key.isEmpty {
            self.setApiKey(key)
        }
    }
    
    // MARK: - Keychain Operations
    
    /// Get API key from Keychain
    func getApiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Store API key in Keychain
    mutating func setApiKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        
        // Delete existing key first
        deleteApiKey()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        hasApiKey = (status == errSecSuccess)
    }
    
    /// Delete API key from Keychain
    mutating func deleteApiKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        
        SecItemDelete(query as CFDictionary)
        hasApiKey = false
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, provider, model, hasApiKey, awsProfileName
        case region, enableCrossRegion, createdAt, lastUsedAt
        // Legacy key for migration
        case apiKey
    }
    
    /// Custom decoder to handle backward compatibility
    /// - Handles missing hasApiKey field (defaults to false)
    /// - Migrates legacy plaintext apiKey to Keychain
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.provider = try container.decode(String.self, forKey: .provider)
        self.model = try container.decode(String.self, forKey: .model)
        self.awsProfileName = try container.decodeIfPresent(String.self, forKey: .awsProfileName)
        self.region = try container.decodeIfPresent(String.self, forKey: .region)
        self.enableCrossRegion = try container.decodeIfPresent(Bool.self, forKey: .enableCrossRegion) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        
        // Handle hasApiKey with default value for backward compatibility
        self.hasApiKey = try container.decodeIfPresent(Bool.self, forKey: .hasApiKey) ?? false
        
        // Migrate legacy plaintext apiKey to Keychain if present
        if let legacyApiKey = try container.decodeIfPresent(String.self, forKey: .apiKey),
           !legacyApiKey.isEmpty {
            // Store in Keychain
            self.setApiKey(legacyApiKey)
            print("📦 Migration: Migrated API key for configuration '\(name)' to Keychain")
        }
        
        // Sync hasApiKey flag with actual Keychain state
        // This handles cases where Keychain was cleared but hasApiKey is still true
        self.syncHasApiKeyWithKeychain()
    }
    
    /// Custom encoder - excludes apiKey (stored in Keychain)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(provider, forKey: .provider)
        try container.encode(model, forKey: .model)
        try container.encode(hasApiKey, forKey: .hasApiKey)
        try container.encodeIfPresent(awsProfileName, forKey: .awsProfileName)
        try container.encodeIfPresent(region, forKey: .region)
        try container.encode(enableCrossRegion, forKey: .enableCrossRegion)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        // Note: apiKey is NOT encoded - it's stored in Keychain
    }
    
    /// Syncs hasApiKey flag with actual Keychain state
    /// Call this after decoding to ensure consistency
    mutating func syncHasApiKeyWithKeychain() {
        let actuallyHasKey = getApiKey() != nil
        if hasApiKey != actuallyHasKey {
            hasApiKey = actuallyHasKey
        }
    }
}

// MARK: - Validation

extension AIEnhancementConfiguration {
    /// Whether this configuration is valid and can be used for AI Enhancement
    /// Uses actual Keychain check, not just the hasApiKey flag
    var isValid: Bool {
        validationErrors.isEmpty
    }
    
    /// Whether the API key actually exists in Keychain
    /// More reliable than hasApiKey flag which could be out of sync
    var hasActualApiKey: Bool {
        getApiKey() != nil
    }
    
    /// List of validation errors for this configuration
    /// Note: Uses lightweight checks for performance (no filesystem access)
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Configuration name is required")
        }
        
        if provider.isEmpty {
            errors.append("Provider is required")
        } else if AIProvider(rawValue: provider) == nil {
            errors.append("Invalid provider: \(provider)")
        }
        
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Model is required")
        }
        
        // Authentication validation based on provider
        // Use hasActualApiKey (Keychain check) instead of hasApiKey flag
        // Note: For AWS Profile, we only check if profile name is set (lightweight)
        // Full validation happens at save time in ConfigurationEditSheet
        if let providerEnum = AIProvider(rawValue: provider) {
            switch providerEnum {
            case .awsBedrock:
                // AWS Bedrock requires either API key or AWS Profile name
                let hasProfileName = !(awsProfileName?.isEmpty ?? true)
                if !hasActualApiKey && !hasProfileName {
                    errors.append("AWS Bedrock requires either an API key or an AWS Profile")
                }
                if region?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    errors.append("Region is required for AWS Bedrock")
                }
                
            default:
                if !hasActualApiKey {
                    errors.append("API key is required for \(provider)")
                }
            }
        }
        
        return errors
    }
    
    /// Whether the AWS profile name is set (lightweight check, no filesystem access)
    var hasAWSProfileName: Bool {
        guard let profileName = awsProfileName, !profileName.isEmpty else {
            return false
        }
        return true
    }
    
    /// Whether the AWS profile exists and has valid credentials
    /// WARNING: This performs filesystem I/O - use sparingly, not in hot paths
    /// For UI validation, use hasAWSProfileName instead
    var hasValidAWSProfile: Bool {
        guard let profileName = awsProfileName, !profileName.isEmpty else {
            return false
        }
        // Check if profile actually exists and has valid credentials
        let awsProfileService = AWSProfileService()
        do {
            let credentials = try awsProfileService.getCredentials(for: profileName)
            return !credentials.accessKeyId.isEmpty && !credentials.secretAccessKey.isEmpty
        } catch {
            return false
        }
    }
    
    /// Authentication method used by this configuration
    var authMethod: AuthMethod {
        if let profileName = awsProfileName, !profileName.isEmpty {
            return .awsProfile(profileName)
        } else if hasActualApiKey {
            return .apiKey
        } else {
            return .none
        }
    }
}

// MARK: - Authentication Method

extension AIEnhancementConfiguration {
    enum AuthMethod: Equatable {
        case apiKey
        case awsProfile(String)
        case none
    }
}

// MARK: - Display Helpers

extension AIEnhancementConfiguration {
    /// Short summary for display in lists
    var summary: String {
        if let providerEnum = AIProvider(rawValue: provider) {
            switch providerEnum {
            case .awsBedrock:
                let regionStr = region ?? "unknown"
                return "\(providerEnum.rawValue) • \(regionStr) • \(model)"
            default:
                return "\(providerEnum.rawValue) • \(model)"
            }
        }
        return "\(provider) • \(model)"
    }
    
    /// Masked API key for display
    var maskedApiKey: String {
        guard let key = getApiKey(), key.count > 8 else { return "****" }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }
    
    /// Icon name for the provider
    var providerIcon: String {
        if let providerEnum = AIProvider(rawValue: provider) {
            switch providerEnum {
            case .awsBedrock:
                return "cloud.fill"
            case .anthropic:
                return "brain.head.profile"
            case .openAI:
                return "sparkles"
            case .gemini:
                return "star.fill"
            case .groq, .cerebras:
                return "bolt.fill"
            case .openRouter:
                return "arrow.triangle.branch"
            }
        }
        return "questionmark.circle"
    }
}
