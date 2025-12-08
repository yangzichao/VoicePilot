import Foundation

extension UserDefaults {
    enum Keys {
        static let aiProviderApiKey = "HoAhAIProviderKey"
        static let legacyAiProviderApiKey = "VoicePilotAIProviderKey"
        static let audioInputMode = "audioInputMode"
        static let selectedAudioDeviceUID = "selectedAudioDeviceUID"
        static let prioritizedDevices = "prioritizedDevices"
    }
    
    // MARK: - AI Provider API Key
    var aiProviderApiKey: String? {
        get { string(forKey: Keys.aiProviderApiKey) ?? string(forKey: Keys.legacyAiProviderApiKey) }
        set {
            if let newValue {
                setValue(newValue, forKey: Keys.aiProviderApiKey)
            } else {
                removeObject(forKey: Keys.aiProviderApiKey)
            }
            removeObject(forKey: Keys.legacyAiProviderApiKey)
        }
    }

    // MARK: - Audio Input Mode
    var audioInputModeRawValue: String? {
        get { string(forKey: Keys.audioInputMode) }
        set { setValue(newValue, forKey: Keys.audioInputMode) }
    }

    // MARK: - Selected Audio Device UID
    var selectedAudioDeviceUID: String? {
        get { string(forKey: Keys.selectedAudioDeviceUID) }
        set { setValue(newValue, forKey: Keys.selectedAudioDeviceUID) }
    }

    // MARK: - Prioritized Devices
    var prioritizedDevicesData: Data? {
        get { data(forKey: Keys.prioritizedDevices) }
        set { setValue(newValue, forKey: Keys.prioritizedDevices) }
    }
} 
