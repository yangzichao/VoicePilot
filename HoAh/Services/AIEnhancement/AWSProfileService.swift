import Foundation
import OSLog

/// Credentials for AWS authentication
struct AWSCredentials: Equatable {
    let accessKeyId: String
    let secretAccessKey: String
    let sessionToken: String?  // Optional, for temporary credentials
    let region: String?        // Optional, from config file
}

/// Errors that can occur when reading AWS profiles
enum AWSProfileError: LocalizedError {
    case credentialsFileNotFound
    case profileNotFound(String)
    case invalidCredentials(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .credentialsFileNotFound:
            return "AWS credentials file not found at ~/.aws/credentials"
        case .profileNotFound(let profile):
            return "AWS profile '\(profile)' not found"
        case .invalidCredentials(let profile):
            return "Invalid credentials for profile '\(profile)'"
        case .parseError(let message):
            return "Failed to parse AWS credentials: \(message)"
        }
    }
}

/// Service for reading AWS profiles from ~/.aws/credentials and ~/.aws/config
/// Used for AWS Bedrock authentication via SigV4 signing
class AWSProfileService {
    
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AWSProfileService")
    private let fileManager = FileManager.default
    
    /// Path to AWS credentials file
    private var credentialsPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.aws/credentials"
    }
    
    /// Path to AWS config file
    private var configPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.aws/config"
    }
    
    // MARK: - Public Methods
    
    /// Lists available AWS profile names from credentials file
    /// - Returns: Array of profile names, empty if file doesn't exist
    func listProfiles() -> [String] {
        guard let content = readFile(at: credentialsPath) else {
            logger.info("AWS credentials file not found")
            return []
        }
        
        let profiles = parseProfileNames(from: content)
        logger.info("Found \(profiles.count) AWS profiles")
        return profiles
    }

    
    /// Gets credentials for a specific profile
    /// - Parameter profile: The profile name to get credentials for
    /// - Returns: AWSCredentials if found and valid
    /// - Throws: AWSProfileError if profile not found or credentials invalid
    func getCredentials(for profile: String) throws -> AWSCredentials {
        guard let credentialsContent = readFile(at: credentialsPath) else {
            throw AWSProfileError.credentialsFileNotFound
        }
        
        // Parse credentials file
        let credentialsData = parseINIFile(credentialsContent)
        
        guard let profileData = credentialsData[profile] else {
            throw AWSProfileError.profileNotFound(profile)
        }
        
        guard let accessKeyId = profileData["aws_access_key_id"],
              let secretAccessKey = profileData["aws_secret_access_key"] else {
            throw AWSProfileError.invalidCredentials(profile)
        }
        
        let sessionToken = profileData["aws_session_token"]
        
        // Try to get region from config file
        let region = getRegionForProfile(profile)
        
        logger.info("Loaded credentials for profile: \(profile)")
        return AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            region: region
        )
    }
    
    /// Checks if a profile exists in the credentials file
    /// - Parameter profile: The profile name to check
    /// - Returns: true if profile exists
    func profileExists(_ profile: String) -> Bool {
        return listProfiles().contains(profile)
    }
    
    // MARK: - Private Methods
    
    /// Reads file content at path
    private func readFile(at path: String) -> String? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
    
    /// Parses profile names from INI-style content
    private func parseProfileNames(from content: String) -> [String] {
        var profiles: [String] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let profileName = String(trimmed.dropFirst().dropLast())
                profiles.append(profileName)
            }
        }
        
        return profiles
    }

    
    /// Parses INI-style file into dictionary of sections
    private func parseINIFile(_ content: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        var currentSection: String?
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }
            
            // Check for section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                result[currentSection!] = [:]
                continue
            }
            
            // Parse key=value pairs
            if let currentSection = currentSection,
               let equalsIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
                result[currentSection]?[key] = value
            }
        }
        
        return result
    }
    
    /// Gets region for a profile from config file
    /// Config file uses "profile <name>" format for non-default profiles
    private func getRegionForProfile(_ profile: String) -> String? {
        guard let configContent = readFile(at: configPath) else {
            return nil
        }
        
        let configData = parseINIFile(configContent)
        
        // Config file uses different section naming:
        // - [default] for default profile
        // - [profile <name>] for other profiles
        let sectionName = profile == "default" ? "default" : "profile \(profile)"
        
        return configData[sectionName]?["region"]
    }
}
