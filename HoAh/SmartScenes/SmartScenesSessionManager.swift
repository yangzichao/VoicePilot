import Foundation
import AppKit

struct ApplicationState: Codable {
    // Only persist state that isn't handled by AppSettingsStore overrides
    var transcriptionModelName: String?
}

struct SmartSceneSession: Codable {
    let id: UUID
    let startTime: Date
    var originalState: ApplicationState
}

// Smart Scene Session Manager
// Manages temporary state overrides for smart scenes
@MainActor
class SmartSceneSessionManager {
    static let shared = SmartSceneSessionManager()
    private let sessionKey = "smartSceneActiveSession.v1"

    private var whisperState: WhisperState?
    private var enhancementService: AIEnhancementService?
    private var appSettings: AppSettingsStore?

    private init() {
        recoverSession()
    }

    func configure(whisperState: WhisperState, enhancementService: AIEnhancementService, appSettings: AppSettingsStore? = nil) {
        self.whisperState = whisperState
        self.enhancementService = enhancementService
        self.appSettings = appSettings
    }

    func beginSession(with config: SmartSceneConfig) async {
        guard let whisperState = whisperState, let appSettings = appSettings else {
            print("SessionManager not configured.")
            return
        }

        // 1. Snapshot state that requires manual restoration (Whisper Model)
        let originalState = ApplicationState(
            transcriptionModelName: whisperState.currentTranscriptionModel?.name
        )

        let newSession = SmartSceneSession(
            id: UUID(),
            startTime: Date(),
            originalState: originalState
        )
        saveSession(newSession)
        
        // 2. Prepare Settings Override (Layer 2) for AppSettings
        var override = AppSettingsStore.SettingsOverride()
        
        // Language
        if let language = config.selectedLanguage {
            override.language = language
        }
        
        // AI Enhancement
        override.isAIEnhancementEnabled = config.isAIEnhancementEnabled
        if config.isAIEnhancementEnabled {
             if let promptId = config.selectedPrompt {
                 override.selectedPromptId = promptId
             }
             if let provider = config.selectedAIProvider {
                 override.selectedAIProvider = provider
                 if let model = config.selectedAIModel {
                     override.selectedAIModel = model
                 }
             }
        }
        
        // Apply Override to AppSettingsStore
        appSettings.applySmartSceneOverride(override, sceneId: config.id.uuidString)

        // 3. Apply Whisper Model Change (Destructive, must restore later)
        if let modelName = config.selectedTranscriptionModelName,
           let selectedModel = await whisperState.allAvailableModels.first(where: { $0.name == modelName }),
           whisperState.currentTranscriptionModel?.name != modelName {
            await handleModelChange(to: selectedModel)
        }
        
        await MainActor.run {
            NotificationCenter.default.post(name: .smartSceneConfigurationApplied, object: nil)
        }
    }

    func endSession() async {
        guard let session = loadSession() else { return }
        
        // 1. Clear AppSettings Override (Layer 2)
        appSettings?.clearSmartSceneOverride()

        // 2. Restore Whisper Model (Manual)
        if let whisperState = whisperState,
           let modelName = session.originalState.transcriptionModelName,
           let selectedModel = await whisperState.allAvailableModels.first(where: { $0.name == modelName }),
           whisperState.currentTranscriptionModel?.name != modelName {
            await handleModelChange(to: selectedModel)
        }

        clearSession()
    }
    
    // Whisper State Handling
    
    private func handleModelChange(to newModel: any TranscriptionModel) async {
        guard let whisperState = whisperState else { return }

        // Note: This modifies persistence in WhisperState. Ideally WhisperState should also support overrides.
        // For now, we accept this side effect and rely on restoreState to fix it.
        await whisperState.setDefaultTranscriptionModel(newModel)

        switch newModel.provider {
        case .local:
            await whisperState.cleanupModelResources()
            if let localModel = await whisperState.availableModels.first(where: { $0.name == newModel.name }) {
                do {
                    try await whisperState.loadModel(localModel)
                } catch {
                    print("Power Mode: Failed to load local model '\(localModel.name)': \(error)")
                }
            }
        default:
            await whisperState.cleanupModelResources()
        }
    }
    
    private func recoverSession() {
        guard let session = loadSession() else { return }
        print("Recovering abandoned Power Mode session.")
        
        // For AppSettings override, it lives in memory, so if app restarted, the override is ALREADY gone.
        // We only need to potentially restore Whisper model if it was changed persistently.
        // BUT, since WhisperState persistence is destructive, the "abandoned" state IS the persistent state now.
        // Restoring it to "originalState" found in the session file is actually CORRECT behavior!
        // It undoes the "stuck" change.
        
        Task {
            await endSession()
        }
    }

    private func saveSession(_ session: SmartSceneSession) {
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: sessionKey)
        } catch {
            print("Error saving Power Mode session: \(error)")
        }
    }
    
    private func loadSession() -> SmartSceneSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        do {
            return try JSONDecoder().decode(SmartSceneSession.self, from: data)
        } catch {
            print("Error loading Power Mode session: \(error)")
            return nil
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
