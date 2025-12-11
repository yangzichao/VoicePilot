import Foundation
import SwiftUI
import OSLog

/// Central store for all application settings
/// This is the single source of truth for user-configurable settings
/// All UI components should read from and write to this store
///
/// State Management Rule: To modify any application setting, update properties in this store.
/// Do not use @AppStorage or direct UserDefaults access elsewhere in the app.
@MainActor
class AppSettingsStore: ObservableObject {
    
    // MARK: - Data Structures

    struct SettingsOverride {
        var language: String?
        var isAIEnhancementEnabled: Bool?
        var selectedPromptId: String?
        var selectedAIProvider: String?
        var selectedAIModel: String?
    }
    
    // MARK: - Published Properties
    
    // Application Settings
    
    /// Whether the user has completed the onboarding flow
    @Published var hasCompletedOnboarding: Bool {
        didSet { saveSettings() }
    }
    
    // Storage for Interface Language
    @Published private var _appInterfaceLanguage: String
    
    /// Interface language: "system", "en", or "zh-Hans"
    var appInterfaceLanguage: String {
        get { activeOverride?.language ?? _appInterfaceLanguage }
        set {
            _appInterfaceLanguage = newValue
            validateLanguage()
            saveSettings()
        }
    }
    
    /// Whether the app runs in menu bar only mode (hides dock icon)
    @Published var isMenuBarOnly: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether the audio transcription tool is enabled
    @Published var isTranscribeAudioEnabled: Bool {
        didSet { saveSettings() }
    }
    
    // Recorder Settings
    
    /// Recorder type: "mini" or "notch"
    @Published var recorderType: String {
        didSet { 
            validateRecorderType()
            saveSettings() 
        }
    }
    
    /// Whether to preserve transcript in clipboard after recording
    @Published var preserveTranscriptInClipboard: Bool {
        didSet { saveSettings() }
    }
    
    // Hotkey Settings
    
    /// Primary hotkey option
    @Published var selectedHotkey1: String {
        didSet { 
            validateHotkeys()
            saveSettings() 
        }
    }
    
    /// Secondary hotkey option
    @Published var selectedHotkey2: String {
        didSet { 
            validateHotkeys()
            saveSettings() 
        }
    }
    
    /// Whether middle-click toggle is enabled
    @Published var isMiddleClickToggleEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Middle-click activation delay in milliseconds (0-5000)
    @Published var middleClickActivationDelay: Int {
        didSet { 
            validateDelay()
            saveSettings() 
        }
    }
    
    // Audio Settings
    
    /// Whether sound feedback is enabled
    @Published var isSoundFeedbackEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to mute system audio during recording
    @Published var isSystemMuteEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to pause media playback during recording
    @Published var isPauseMediaEnabled: Bool {
        didSet { saveSettings() }
    }
    
    // AI Enhancement Settings
    
    // Storage for AI Enhancement
    @Published private var _isAIEnhancementEnabled: Bool
    
    /// Whether AI enhancement is enabled
    var isAIEnhancementEnabled: Bool {
        get { activeOverride?.isAIEnhancementEnabled ?? _isAIEnhancementEnabled }
        set {
            _isAIEnhancementEnabled = newValue
            handleAIEnhancementChange()
            saveSettings()
        }
    }
    
    // Storage for Selected Prompt ID
    @Published private var _selectedPromptId: String?
    
    /// Selected prompt ID (UUID string)
    var selectedPromptId: String? {
        get { activeOverride?.selectedPromptId ?? _selectedPromptId }
        set {
            _selectedPromptId = newValue
            saveSettings()
        }
    }
    
    /// Whether to use clipboard context in AI enhancement
    @Published var useClipboardContext: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to use screen capture context in AI enhancement
    @Published var useScreenCaptureContext: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to use selected text context in AI enhancement
    @Published var useSelectedTextContext: Bool {
        didSet { saveSettings() }
    }
    
    /// User profile context for AI enhancement
    @Published var userProfileContext: String {
        didSet { saveSettings() }
    }
    
    /// Whether prompt triggers are enabled
    @Published var arePromptTriggersEnabled: Bool {
        didSet { saveSettings() }
    }
    
    // Smart Scene State (runtime, not persisted directly)
    
    /// Currently active Smart Scene ID
    @Published var activeSmartSceneId: String? = nil
    
    /// Active override settings from Smart Scene (Layer 2)
    @Published var activeOverride: SettingsOverride? = nil {
        didSet { objectWillChange.send() }
    }
    
    // AI Provider Settings
    
    // Storage for Selected AI Provider
    @Published private var _selectedAIProvider: String
    
    /// Selected AI provider
    var selectedAIProvider: String {
        get { activeOverride?.selectedAIProvider ?? _selectedAIProvider }
        set {
            _selectedAIProvider = newValue
            validateProvider()
            saveSettings()
        }
    }
    
    /// AWS Bedrock region
    @Published var bedrockRegion: String {
        didSet { saveSettings() }
    }
    
    /// AWS Bedrock model ID
    @Published var bedrockModelId: String {
        didSet { saveSettings() }
    }
    
    // Storage for Selected Models
    @Published private var _selectedModels: [String: String]
    
    /// Selected models per provider (provider name -> model name)
    var selectedModels: [String: String] {
        get {
             // Synthesize override model into the map if present
             if let overrideModel = activeOverride?.selectedAIModel, let provider = activeOverride?.selectedAIProvider {
                 var models = _selectedModels
                 models[provider] = overrideModel
                 return models
             }
             return _selectedModels
        }
        set {
            _selectedModels = newValue
            saveSettings()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether the recorder is properly configured with at least one hotkey
    var isRecorderConfigured: Bool {
        return selectedHotkey1 != "none" || selectedHotkey2 != "none"
    }

    // Publishers for override-aware properties (use backing storage publishers)
    var appInterfaceLanguagePublisher: Published<String>.Publisher { $_appInterfaceLanguage }
    var isAIEnhancementEnabledPublisher: Published<Bool>.Publisher { $_isAIEnhancementEnabled }
    var selectedPromptIdPublisher: Published<String?>.Publisher { $_selectedPromptId }
    var selectedAIProviderPublisher: Published<String>.Publisher { $_selectedAIProvider }
    var selectedModelsPublisher: Published<[String: String]>.Publisher { $_selectedModels }
    
    // MARK: - AI Enhancement Configuration Profiles
    
    /// List of saved AI Enhancement configuration profiles
    @Published var aiEnhancementConfigurations: [AIEnhancementConfiguration] = [] {
        didSet { saveSettings() }
    }
    
    /// ID of the currently active AI Enhancement configuration
    @Published var activeAIConfigurationId: UUID? = nil {
        didSet { saveSettings() }
    }
    
    /// Whether legacy AI provider settings have been migrated
    @Published var hasCompletedAIConfigMigration: Bool = false {
        didSet { saveSettings() }
    }
    
    /// Currently active AI Enhancement configuration (computed)
    var activeAIConfiguration: AIEnhancementConfiguration? {
        guard let activeId = activeAIConfigurationId else { return nil }
        return aiEnhancementConfigurations.first { $0.id == activeId }
    }
    
    /// Valid configurations only (for quick-switch UI)
    var validAIConfigurations: [AIEnhancementConfiguration] {
        aiEnhancementConfigurations.filter { $0.isValid }
    }
    
    /// Publishers for configuration changes
    var aiEnhancementConfigurationsPublisher: Published<[AIEnhancementConfiguration]>.Publisher { $aiEnhancementConfigurations }
    var activeAIConfigurationIdPublisher: Published<UUID?>.Publisher { $activeAIConfigurationId }
    
    // MARK: - Storage
    
    private let storage: SettingsStorage
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AppSettingsStore")
    
    // MARK: - Initialization
    
    /// Initializes the settings store with the specified storage backend
    /// - Parameter storage: Storage implementation (defaults to UserDefaultsStorage)
    init(storage: SettingsStorage = UserDefaultsStorage()) {
        self.storage = storage
        
        // Load settings from storage or use defaults
        let state = storage.load() ?? AppSettingsState()
        
        // Initialize all @Published properties
        self.hasCompletedOnboarding = state.hasCompletedOnboarding
        self._appInterfaceLanguage = state.appInterfaceLanguage // Initialize storage
        self.isMenuBarOnly = state.isMenuBarOnly
        self.isTranscribeAudioEnabled = state.isTranscribeAudioEnabled
        self.recorderType = state.recorderType
        self.preserveTranscriptInClipboard = state.preserveTranscriptInClipboard
        self.selectedHotkey1 = state.selectedHotkey1
        self.selectedHotkey2 = state.selectedHotkey2
        self.isMiddleClickToggleEnabled = state.isMiddleClickToggleEnabled
        self.middleClickActivationDelay = state.middleClickActivationDelay
        self.isSoundFeedbackEnabled = state.isSoundFeedbackEnabled
        self.isSystemMuteEnabled = state.isSystemMuteEnabled
        self.isPauseMediaEnabled = state.isPauseMediaEnabled
        self._isAIEnhancementEnabled = state.isAIEnhancementEnabled // Initialize storage
        self._selectedPromptId = state.selectedPromptId // Initialize storage
        self.useClipboardContext = state.useClipboardContext
        self.useScreenCaptureContext = state.useScreenCaptureContext
        self.useSelectedTextContext = state.useSelectedTextContext
        self.userProfileContext = state.userProfileContext
        self.arePromptTriggersEnabled = state.arePromptTriggersEnabled
        self._selectedAIProvider = state.selectedAIProvider // Initialize storage
        self.bedrockRegion = state.bedrockRegion
        self.bedrockModelId = state.bedrockModelId
        self._selectedModels = state.selectedModels // Initialize storage
        self.aiEnhancementConfigurations = state.aiEnhancementConfigurations
        self.activeAIConfigurationId = state.activeAIConfigurationId
        self.hasCompletedAIConfigMigration = state.hasCompletedAIConfigMigration
        
        // Validate AI configurations on load
        validateAIConfigurations()
        
        logger.info("AppSettingsStore initialized")
    }
    
    // MARK: - Validation Methods
    
    /// Validates language setting and corrects if invalid
    private func validateLanguage() {
        let validLanguages = ["system", "en", "zh-Hans"]
        if !validLanguages.contains(appInterfaceLanguage) {
            logger.warning("Invalid language '\(self.appInterfaceLanguage)', resetting to 'system'")
            appInterfaceLanguage = "system"
        }
    }
    
    /// Validates recorder type and corrects if invalid
    private func validateRecorderType() {
        if recorderType != "mini" && recorderType != "notch" {
            logger.warning("Invalid recorder type '\(self.recorderType)', resetting to 'mini'")
            recorderType = "mini"
        }
    }
    
    /// Validates hotkey settings and resolves conflicts
    /// Ensures hotkey1 and hotkey2 are not the same (except "none")
    private func validateHotkeys() {
        // Check for conflicts between hotkey1 and hotkey2
        if selectedHotkey1 != "none" && 
           selectedHotkey2 != "none" && 
           selectedHotkey1 == selectedHotkey2 {
            logger.warning("Hotkey conflict detected, disabling hotkey2")
            selectedHotkey2 = "none"
        }
    }
    
    /// Validates AI Enhancement configurations on load
    /// Ensures active configuration is valid, selects fallback if needed
    private func validateAIConfigurations() {
        // Log validation status for each configuration
        for config in aiEnhancementConfigurations {
            if !config.isValid {
                logger.warning("Invalid AI configuration '\(config.name)': \(config.validationErrors.joined(separator: ", "))")
            }
        }
        
        // Check if active configuration exists and is valid
        if let activeId = activeAIConfigurationId {
            if let activeConfig = aiEnhancementConfigurations.first(where: { $0.id == activeId }) {
                if !activeConfig.isValid {
                    logger.warning("Active AI configuration '\(activeConfig.name)' is invalid, selecting fallback")
                    selectFallbackConfiguration()
                }
            } else {
                logger.warning("Active AI configuration ID not found, selecting fallback")
                selectFallbackConfiguration()
            }
        }
    }
    
    /// Selects a fallback configuration when the active one is invalid or missing
    private func selectFallbackConfiguration() {
        if let firstValid = validAIConfigurations.first {
            activeAIConfigurationId = firstValid.id
            logger.info("Selected fallback AI configuration: \(firstValid.name)")
        } else {
            activeAIConfigurationId = nil
            logger.info("No valid AI configurations available")
        }
    }
    
    /// Validates delay and corrects if out of range (0-5000ms)
    private func validateDelay() {
        if middleClickActivationDelay < 0 {
            logger.warning("Negative delay detected, setting to 0")
            middleClickActivationDelay = 0
        } else if middleClickActivationDelay > 5000 {
            logger.warning("Delay too large, setting to 5000")
            middleClickActivationDelay = 5000
        }
    }
    
    /// Validates AI provider and corrects if invalid
    /// Note: Custom and ElevenLabs have been removed from AIProvider enum
    private func validateProvider() {
        let validProviders = ["AWS Bedrock", "Cerebras", "GROQ", "Gemini", "Anthropic", 
                             "OpenAI", "OpenRouter"]
        if !validProviders.contains(selectedAIProvider) {
            // Migrate legacy providers to Gemini
            if selectedAIProvider == "Custom" || selectedAIProvider == "ElevenLabs" {
                logger.warning("Legacy provider '\(self.selectedAIProvider)' no longer supported, migrating to 'Gemini'")
            } else {
                logger.warning("Invalid provider '\(self.selectedAIProvider)', resetting to 'Gemini'")
            }
            selectedAIProvider = "Gemini"
        }
    }
    
    /// Handles AI enhancement state change
    /// Ensures consistent state (e.g., disables triggers when AI is disabled)
    private func handleAIEnhancementChange() {
        // Cannot enable AI Enhancement without a valid configuration
        if _isAIEnhancementEnabled && validAIConfigurations.isEmpty {
            logger.warning("Cannot enable AI Enhancement: no valid configurations available")
            _isAIEnhancementEnabled = false
            return
        }
        
        // If enabling AI but no active configuration, select the first valid one
        if _isAIEnhancementEnabled && activeAIConfigurationId == nil {
            if let firstValid = validAIConfigurations.first {
                activeAIConfigurationId = firstValid.id
                logger.info("Auto-selected AI configuration: \(firstValid.name)")
            }
        }
        
        // If enabling AI but no prompt selected, log warning
        // Coordinator will handle selecting default prompt
        if _isAIEnhancementEnabled && selectedPromptId == nil {
            logger.info("AI enabled without prompt, coordinator will select default")
        }
        
        // If disabling AI, also disable prompt triggers
        if !_isAIEnhancementEnabled && arePromptTriggersEnabled {
            logger.info("Disabling prompt triggers with AI enhancement")
            arePromptTriggersEnabled = false
        }
    }

    // MARK: - Batch Update Methods
    
    /// Updates AI settings atomically to avoid intermediate invalid states
    /// - Parameters:
    ///   - enabled: Whether to enable AI enhancement
    ///   - promptId: The prompt ID to use (optional)
    func updateAISettings(enabled: Bool, promptId: String?) {
        var finalPromptId = promptId
        
        // Validate: if enabling, should have a prompt
        if enabled && finalPromptId == nil {
            logger.warning("Enabling AI without prompt, coordinator should provide default")
        }
        
        // Atomic update (no intermediate state)
        isAIEnhancementEnabled = enabled
        selectedPromptId = finalPromptId
        
        logger.info("AI settings updated: enabled=\(enabled), promptId=\(finalPromptId ?? "nil")")
    }
    
    /// Updates hotkey settings with automatic conflict resolution
    /// - Parameters:
    ///   - hotkey1: Primary hotkey
    ///   - hotkey2: Secondary hotkey
    func updateHotkeySettings(hotkey1: String, hotkey2: String) {
        var finalHotkey2 = hotkey2
        
        // Resolve conflicts: hotkey1 and hotkey2 cannot be the same
        if hotkey1 != "none" && hotkey2 != "none" && hotkey1 == hotkey2 {
            logger.warning("Hotkey conflict, setting hotkey2 to none")
            finalHotkey2 = "none"
        }
        
        // Atomic update
        selectedHotkey1 = hotkey1
        selectedHotkey2 = finalHotkey2
        
        logger.info("Hotkey settings updated: hotkey1=\(hotkey1), hotkey2=\(finalHotkey2)")
    }
    
    /// Resets all system settings to defaults while preserving AI configurations
    /// - Note: Preserves API keys, models, providers, prompts, user profile, AND shortcuts.
    func resetSystemSettings() {
        // 1. Create a fresh state with default values
        var newState = AppSettingsState()
        
        // 2. RESTORE settings that should NOT be reset
        
        // A. Identity & Keys (Preserve Provider & Model selections from STORAGE)
        newState.selectedAIProvider = self._selectedAIProvider 
        newState.selectedModels = self._selectedModels
        newState.bedrockRegion = self.bedrockRegion
        newState.bedrockModelId = self.bedrockModelId
        
        // B. AI State (Preserve Selected Prompt only, Reset ENABLE switch)
        // Note: isAIEnhancementEnabled defaults to FALSE in new state, which is desired.
        newState.selectedPromptId = self._selectedPromptId
        
        // C. User Content (Preserve User Profile Context)
        newState.userProfileContext = self.userProfileContext
        
        // D. Shortcuts & Triggers (PRESERVE User's Control Scheme)
        newState.selectedHotkey1 = self.selectedHotkey1
        newState.selectedHotkey2 = self.selectedHotkey2
        newState.isMiddleClickToggleEnabled = self.isMiddleClickToggleEnabled
        newState.middleClickActivationDelay = self.middleClickActivationDelay
        
        // E. App State (Preserve Onboarding status)
        newState.hasCompletedOnboarding = self.hasCompletedOnboarding
        
        // 3. Apply the new state
        // This effectively resets ONLY:
        // - Language
        // - Interface Style (Dock icon, Recorder type)
        // - Audio/Recording Behaviors (Sound feedback, Mute, Pause media, Clipboard preservation)
        // - Context Awareness Toggles (Clipboard/Screen/Selection usage defaults to OFF)
        
        applyState(newState)
        saveSettings()
        
        logger.info("System settings reset to defaults. Preserved: AI Config, User Profile, Shortcuts.")
        
        // 4. Post notification for UI updates
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    // MARK: - AI Configuration Management
    
    /// Adds a new AI Enhancement configuration
    func addConfiguration(_ config: AIEnhancementConfiguration) {
        aiEnhancementConfigurations.append(config)
        logger.info("Added AI configuration: \(config.name)")
    }
    
    /// Updates an existing AI Enhancement configuration
    func updateConfiguration(_ config: AIEnhancementConfiguration) {
        if let index = aiEnhancementConfigurations.firstIndex(where: { $0.id == config.id }) {
            aiEnhancementConfigurations[index] = config
            logger.info("Updated AI configuration: \(config.name)")
        }
    }
    
    /// Deletes an AI Enhancement configuration
    func deleteConfiguration(id: UUID) {
        aiEnhancementConfigurations.removeAll { $0.id == id }
        
        // If deleted config was active, select another valid one
        if activeAIConfigurationId == id {
            activeAIConfigurationId = validAIConfigurations.first?.id
            logger.info("Active config deleted, selected fallback: \(self.activeAIConfigurationId?.uuidString ?? "none")")
        }
        logger.info("Deleted AI configuration: \(id)")
    }
    
    /// Sets the active AI Enhancement configuration
    func setActiveConfiguration(id: UUID) {
        guard aiEnhancementConfigurations.contains(where: { $0.id == id }) else {
            logger.warning("Cannot set active config: ID not found")
            return
        }
        activeAIConfigurationId = id
        logger.info("Set active AI configuration: \(id)")
    }
    
    // MARK: - Smart Scene Management
    
    /// Applies a temporary override for Smart Scenes (Layer 2)
    /// This does NOT modify persistent settings
    func applySmartSceneOverride(_ override: SettingsOverride, sceneId: String) {
        logger.info("Applying Smart Scene override: \(sceneId)")
        self.activeOverride = override
        self.activeSmartSceneId = sceneId
        
        // Notify changes that might be observed via non-binding paths
        if override.language != nil {
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }
    
    /// Clears the temporary override (Layer 2)
    func clearSmartSceneOverride() {
        guard let sceneId = activeSmartSceneId else { return }
        logger.info("Clearing Smart Scene override: \(sceneId)")
        
        self.activeOverride = nil
        self.activeSmartSceneId = nil
        
        // Notify to clear any language overrides
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    // MARK: - Private Methods
    
    /// Loads settings from state, applying validation and safe defaults if needed
    /// - Parameter state: The state to load
    private func loadFromState(_ state: AppSettingsState) {
        // Validate before loading
        let validation = state.validate()
        if !validation.isValid {
            logger.warning("Invalid settings detected: \(validation.errors.joined(separator: ", "))")
            let safeState = state.withSafeDefaults()
            applyState(safeState)
        } else {
            applyState(state)
        }
    }
    
    /// Applies state to all published properties
    /// Note: This updates storage properties directly to avoid triggering saveSettings() multiple times via setters
    /// - Parameter state: The state to apply
    private func applyState(_ state: AppSettingsState) {
        hasCompletedOnboarding = state.hasCompletedOnboarding
        _appInterfaceLanguage = state.appInterfaceLanguage // Storage
        isMenuBarOnly = state.isMenuBarOnly
        isTranscribeAudioEnabled = state.isTranscribeAudioEnabled
        recorderType = state.recorderType
        preserveTranscriptInClipboard = state.preserveTranscriptInClipboard
        selectedHotkey1 = state.selectedHotkey1
        selectedHotkey2 = state.selectedHotkey2
        isMiddleClickToggleEnabled = state.isMiddleClickToggleEnabled
        middleClickActivationDelay = state.middleClickActivationDelay
        isSoundFeedbackEnabled = state.isSoundFeedbackEnabled
        isSystemMuteEnabled = state.isSystemMuteEnabled
        isPauseMediaEnabled = state.isPauseMediaEnabled
        _isAIEnhancementEnabled = state.isAIEnhancementEnabled // Storage
        _selectedPromptId = state.selectedPromptId // Storage
        useClipboardContext = state.useClipboardContext
        useScreenCaptureContext = state.useScreenCaptureContext
        useSelectedTextContext = state.useSelectedTextContext
        userProfileContext = state.userProfileContext
        arePromptTriggersEnabled = state.arePromptTriggersEnabled
        _selectedAIProvider = state.selectedAIProvider // Storage
        bedrockRegion = state.bedrockRegion
        bedrockModelId = state.bedrockModelId
        _selectedModels = state.selectedModels // Storage
        aiEnhancementConfigurations = state.aiEnhancementConfigurations
        activeAIConfigurationId = state.activeAIConfigurationId
        hasCompletedAIConfigMigration = state.hasCompletedAIConfigMigration
    }
    
    // MARK: - Persistence
    
    /// Saves current settings to storage
    private func saveSettings() {
        let state = currentState()
        storage.save(state)
    }
    
    /// Creates an AppSettingsState from current property values
    /// - Returns: Current state snapshot using underlying STORAGE values (ignoring overrides)
    private func currentState() -> AppSettingsState {
        return AppSettingsState(
            hasCompletedOnboarding: hasCompletedOnboarding,
            appInterfaceLanguage: _appInterfaceLanguage,
            isMenuBarOnly: isMenuBarOnly,
            isTranscribeAudioEnabled: isTranscribeAudioEnabled,
            recorderType: recorderType,
            preserveTranscriptInClipboard: preserveTranscriptInClipboard,
            selectedHotkey1: selectedHotkey1,
            selectedHotkey2: selectedHotkey2,
            isMiddleClickToggleEnabled: isMiddleClickToggleEnabled,
            middleClickActivationDelay: middleClickActivationDelay,
            isSoundFeedbackEnabled: isSoundFeedbackEnabled,
            isSystemMuteEnabled: isSystemMuteEnabled,
            isPauseMediaEnabled: isPauseMediaEnabled,
            isAIEnhancementEnabled: _isAIEnhancementEnabled,
            selectedPromptId: _selectedPromptId,
            useClipboardContext: useClipboardContext,
            useScreenCaptureContext: useScreenCaptureContext,
            useSelectedTextContext: useSelectedTextContext,
            userProfileContext: userProfileContext,
            arePromptTriggersEnabled: arePromptTriggersEnabled,
            selectedAIProvider: _selectedAIProvider,
            bedrockRegion: bedrockRegion,
            bedrockModelId: bedrockModelId,
            selectedModels: _selectedModels,
            aiEnhancementConfigurations: aiEnhancementConfigurations,
            activeAIConfigurationId: activeAIConfigurationId,
            hasCompletedAIConfigMigration: hasCompletedAIConfigMigration
        )
    }
}
