import SwiftUI

/// APIKeyManagementView manages API keys for AI enhancement providers only.
/// This view is used within EnhancementSettingsView (AI Agents tab).
/// Transcription provider configuration is handled separately in ModelManagementView.
struct APIKeyManagementView: View {
    @EnvironmentObject private var aiService: AIService
    @State private var apiKey: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isVerifying = false
    @State private var keyEntries: [CloudAPIKeyEntry] = []
    @State private var activeKeyId: UUID?
    @State private var bedrockRegionSelection: String = "us-east-1"
    @State private var bedrockModelSelection: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with explanation
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("AI Enhancement Provider Configuration"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(LocalizedStringKey("Configure LLM providers for post-processing transcribed text. For transcription models, use the AI Models tab."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Provider Selection - AI Enhancement Providers Only
            HStack {
                Picker(LocalizedStringKey("AI Enhancement Provider"), selection: $aiService.selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                
                Spacer()
                
                if aiService.isAPIKeyValid {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(String(format: NSLocalizedString("Connected to %@", comment: "Connected to provider"), aiService.selectedProvider.rawValue))
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.secondary)
                    .cornerRadius(6)
                }
            }
            
            .onChange(of: aiService.selectedProvider) { oldValue, newValue in
                reloadKeys()
                syncBedrockRegionSelection()
            }
            
            // Model Selection
            if aiService.selectedProvider == .openRouter {
                HStack {
                    if aiService.availableModels.isEmpty {
                        Text(LocalizedStringKey("No models loaded"))
                            .foregroundColor(.secondary)
                    } else {
                        Picker(LocalizedStringKey("Model"), selection: Binding(
                            get: { aiService.currentModel },
                            set: { aiService.selectModel($0) }
                        )) {
                            ForEach(aiService.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                    
                    
                    
                    Button(action: {
                        Task {
                            await aiService.fetchOpenRouterModels()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(NSLocalizedString("Refresh models", comment: ""))
                }
            } else if !aiService.availableModels.isEmpty &&
                        aiService.selectedProvider != .custom {
                HStack {
                    Picker(LocalizedStringKey("Enhancement Model"), selection: Binding(
                        get: { aiService.currentModel },
                        set: { aiService.selectModel($0) }
                    )) {
                        ForEach(aiService.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
            }
            
            if aiService.selectedProvider == .custom {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Provider Configuration")
                            .font(.headline)
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Requires OpenAI-compatible API endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Configuration Fields
                    VStack(alignment: .leading, spacing: 8) {
                        if !aiService.isAPIKeyValid {
                            TextField(NSLocalizedString("API Endpoint URL (e.g., https://api.example.com/v1/chat/completions)", comment: ""), text: $aiService.customBaseURL)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField(NSLocalizedString("Model Name (e.g., gpt-4o-mini, claude-3-5-sonnet-20240620)", comment: ""), text: $aiService.customModel)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey("API Endpoint URL"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(aiService.customBaseURL)
                                    .font(.system(.body, design: .monospaced))
                                
                                Text(LocalizedStringKey("Model"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(aiService.customModel)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        
                        if aiService.isAPIKeyValid {
                            Text(LocalizedStringKey("API Key"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(String(repeating: "•", count: 40))
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                Button(action: {
                                    aiService.clearAPIKey()
                                }) {
                                    Label(NSLocalizedString("Remove Key", comment: ""), systemImage: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        } else {
                            Text(LocalizedStringKey("Enter your API Key"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            SecureField(NSLocalizedString("API Key", comment: ""), text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            HStack {
                            Button(action: {
                                isVerifying = true
                                aiService.saveAPIKey(apiKey) { success, errorMessage in
                                    isVerifying = false
                                    if !success {
                                        alertMessage = errorMessage ?? NSLocalizedString("Verification failed", comment: "")
                                        showAlert = true
                                    }
                                    apiKey = ""
                                }
                            }) {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text(LocalizedStringKey("Verify and Save"))
                                }
                            }
                                .disabled(aiService.customBaseURL.isEmpty || aiService.customModel.isEmpty || apiKey.isEmpty)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.03))
                .cornerRadius(12)
            } else if aiService.selectedProvider == .awsBedrock {
                let presetRegions = [
                    "us-east-1",
                    "us-east-2",
                    "us-west-1",
                    "us-west-2",
                    "eu-west-1",
                    "eu-central-1",
                    "ap-southeast-1",
                    "ap-northeast-1",
                    "ap-south-1",
                    "custom"
                ]

                let presetModels = [
                    // Claude Sonnet Series
                    "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
                    "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
                    "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
                    
                    // Claude Opus
                    "us.anthropic.claude-opus-4-20250514-v1:0",
                    
                    // Claude Haiku
                    "us.anthropic.claude-haiku-4-20250514-v1:0",
                    
                    // Other Models
                    "openai.gpt-oss-safeguard-120b",
                    "us.amazon.nova-pro-v1:0"
                ]

                VStack(alignment: .leading, spacing: 20) {
                    Text(LocalizedStringKey("AWS Bedrock Configuration"))
                        .font(.headline)
                    
                    // API Keys Management Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🔑 \(NSLocalizedString("API Keys", comment: ""))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button {
                                let _ = aiService.rotateAPIKey()
                                reloadKeys()
                            } label: {
                                Label("Next Key", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(keyEntries.count <= 1)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        if keyEntries.isEmpty {
                            Text(LocalizedStringKey("No API keys added yet. Add one below."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(keyEntries) { entry in
                                    let isActive = entry.id == activeKeyId
                                    HStack {
                                        Text(maskKey(entry.value))
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(isActive ? .primary : .secondary)
                                        
                                        if let lastUsed = entry.lastUsedAt {
                                            Text(String(format: NSLocalizedString("Last used %@", comment: ""), relativeDate(lastUsed)))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if isActive {
                                            Label(NSLocalizedString("Active", comment: ""), systemImage: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        } else {
                                            Button(NSLocalizedString("Use", comment: "")) {
                                                aiService.selectAPIKey(id: entry.id)
                                                reloadKeys()
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        
                                        Button(role: .destructive) {
                                            CloudAPIKeyManager.shared.removeKey(id: entry.id, for: aiService.selectedProvider.rawValue)
                                            reloadKeys()
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundColor(.red)
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isActive ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
                                    )
                                }
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStringKey("Add New API Key"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            SecureField(NSLocalizedString("API Key (ABSKQmVkcm9ja0FQSUtleS1...)", comment: ""), text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            HStack {
                                Button(action: {
                                    isVerifying = true
                                    // Verify with current region and model settings
                                    aiService.verifyBedrockConnection(
                                        apiKey: apiKey,
                                        region: aiService.bedrockRegion,
                                        modelId: aiService.bedrockModelId
                                    ) { success, message in
                                        isVerifying = false
                                        if success {
                                            // Just save the key, region and model are managed separately
                                            let entry = CloudAPIKeyManager.shared.addKey(apiKey, for: aiService.selectedProvider.rawValue)
                                            CloudAPIKeyManager.shared.selectKey(id: entry.id, for: aiService.selectedProvider.rawValue)
                                            apiKey = ""
                                            reloadKeys()
                                            alertMessage = NSLocalizedString("API Key verified and saved successfully!", comment: "")
                                        } else {
                                            alertMessage = "❌ " + (message ?? NSLocalizedString("Connection failed.", comment: ""))
                                        }
                                        showAlert = true
                                    }
                                }) {
                                    HStack {
                                        if isVerifying {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                                .frame(width: 16, height: 16)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                        }
                                        Text(LocalizedStringKey("Verify and Save"))
                                    }
                                }
                                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    aiService.clearAPIKey()
                                    reloadKeys()
                                } label: {
                                    Label(NSLocalizedString("Remove All", comment: ""), systemImage: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                                .disabled(keyEntries.isEmpty)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(10)
                    
                    // Configuration Section (Region + Model)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🌍 \(NSLocalizedString("Current Configuration", comment: ""))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            if aiService.isAPIKeyValid {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text(LocalizedStringKey("Connected"))
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        Text(LocalizedStringKey("Applies to the active API key above"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Picker(LocalizedStringKey("Region"), selection: $bedrockRegionSelection) {
                                ForEach(presetRegions, id: \.self) { region in
                                    Text(region == "custom" ? NSLocalizedString("Custom…", comment: "") : region).tag(region)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: bedrockRegionSelection) { _, newValue in
                                if newValue != "custom" {
                                    aiService.bedrockRegion = newValue
                                }
                            }
                            
                            if bedrockRegionSelection == "custom" {
                                TextField(NSLocalizedString("Enter region (e.g., us-west-2)", comment: ""), text: $aiService.bedrockRegion)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 220)
                            }
                        }
                        
                        Picker(LocalizedStringKey("Model"), selection: $bedrockModelSelection) {
                            ForEach(presetModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: bedrockModelSelection) { _, newValue in
                            aiService.bedrockModelId = newValue
                        }
                        
                        HStack {
                            Button(action: {
                                guard let activeKey = CloudAPIKeyManager.shared.activeKey(for: aiService.selectedProvider.rawValue) else {
                                    alertMessage = "⚠️ " + NSLocalizedString("Please add and select an API key first.", comment: "")
                                    showAlert = true
                                    return
                                }
                                
                                isVerifying = true
                                aiService.verifyBedrockConnection(
                                    apiKey: activeKey.value,
                                    region: aiService.bedrockRegion,
                                    modelId: aiService.bedrockModelId
                                ) { success, message in
                                    isVerifying = false
                                    if success {
                                        // Save the configuration
                                        aiService.saveBedrockConfig(
                                            apiKey: activeKey.value,
                                            region: aiService.bedrockRegion,
                                            modelId: aiService.bedrockModelId
                                        )
                                        alertMessage = NSLocalizedString("Connection successful! Configuration saved.", comment: "")
                                    } else {
                                        alertMessage = "❌ " + (message ?? NSLocalizedString("Connection failed.", comment: ""))
                                    }
                                    showAlert = true
                                }
                            }) {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "bolt.horizontal.circle.fill")
                                    }
                                    Text(isVerifying ? NSLocalizedString("Testing...", comment: "") : NSLocalizedString("Test Connection", comment: ""))
                                }
                            }
                            .disabled(keyEntries.isEmpty || isVerifying)
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                        }
                        
                        // Info message
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(LocalizedStringKey("The same API key works across all regions and models"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding()
                .background(Color.secondary.opacity(0.03))
                .cornerRadius(12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("API Keys")
                            .font(.headline)
                        Spacer()
                        Button {
                            aiService.rotateAPIKey()
                            reloadKeys()
                        } label: {
                            Label("Next Key", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(keyEntries.count <= 1)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if keyEntries.isEmpty {
                        Text(String(format: NSLocalizedString("No keys added yet for %@. Add one below.", comment: ""), aiService.selectedProvider.rawValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(keyEntries) { entry in
                                let isActive = entry.id == activeKeyId
                                HStack {
                                    Text(maskKey(entry.value))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(isActive ? .primary : .secondary)
                                    
                                    if let lastUsed = entry.lastUsedAt {
                                        Text(String(format: NSLocalizedString("Last used %@", comment: ""), relativeDate(lastUsed)))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isActive {
                                        Label(NSLocalizedString("Active", comment: ""), systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Button(NSLocalizedString("Use", comment: "")) {
                                            aiService.selectAPIKey(id: entry.id)
                                            reloadKeys()
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    
                                    Button(role: .destructive) {
                                        CloudAPIKeyManager.shared.removeKey(id: entry.id, for: aiService.selectedProvider.rawValue)
                                        reloadKeys()
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.red)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isActive ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("Add New API Key"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField(NSLocalizedString("API Key", comment: ""), text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(.body, design: .monospaced))
                        
                        HStack {
                            Button(action: {
                                isVerifying = true
                                aiService.saveAPIKey(apiKey) { success, errorMessage in
                                    isVerifying = false
                                    if !success {
                                        alertMessage = errorMessage ?? NSLocalizedString("Verification failed", comment: "")
                                        showAlert = true
                                    }
                                    apiKey = ""
                                    reloadKeys()
                                }
                            }) {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text(LocalizedStringKey("Verify and Save"))
                                }
                            }
                            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                aiService.clearAPIKey()
                                reloadKeys()
                            } label: {
                                Label(NSLocalizedString("Remove All", comment: ""), systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                            .disabled(keyEntries.isEmpty)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text((aiService.selectedProvider == .groq || aiService.selectedProvider == .gemini || aiService.selectedProvider == .cerebras) ? NSLocalizedString("Free", comment: "") : NSLocalizedString("Paid", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        if aiService.selectedProvider != .custom {
                            Button {
                                let url = switch aiService.selectedProvider {
                                case .groq:
                                    URL(string: "https://console.groq.com/keys")!
                                case .openAI:
                                    URL(string: "https://platform.openai.com/api-keys")!
                                case .gemini:
                                    URL(string: "https://makersuite.google.com/app/apikey")!
                                case .anthropic:
                                    URL(string: "https://console.anthropic.com/settings/keys")!
                                case .custom:
                                    URL(string: "")! // not used
                                case .openRouter:
                                    URL(string: "https://openrouter.ai/keys")!
                                case .cerebras:
                                    URL(string: "https://cloud.cerebras.ai/")!
                                case .awsBedrock:
                                    URL(string: "https://console.aws.amazon.com/iam/home#/security_credentials")!
                                }
                                NSWorkspace.shared.open(url)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(LocalizedStringKey("Get API Key"))
                                        .foregroundColor(.accentColor)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .alert(NSLocalizedString("Error", comment: ""), isPresented: $showAlert) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            reloadKeys()
            syncBedrockRegionSelection()
            syncBedrockModelSelection()
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let gigabytes = Double(bytes) / 1_000_000_000
        return String(format: "%.1f GB", gigabytes)
    }
    
    private func reloadKeys() {
        keyEntries = aiService.currentKeyEntries()
        activeKeyId = CloudAPIKeyManager.shared.activeKey(for: aiService.selectedProvider.rawValue)?.id
    }

    private func syncBedrockRegionSelection() {
        let presets = [
            "us-east-1",
            "us-east-2",
            "us-west-1",
            "us-west-2",
            "eu-west-1",
            "eu-central-1",
            "ap-southeast-1",
            "ap-northeast-1",
            "ap-south-1"
        ]
        if presets.contains(aiService.bedrockRegion) {
            bedrockRegionSelection = aiService.bedrockRegion
        } else {
            bedrockRegionSelection = "custom"
        }
    }

    private func syncBedrockModelSelection() {
        let presets = [
            "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
            "us.anthropic.claude-opus-4-20250514-v1:0",
            "openai.gpt-oss-safeguard-120b",
            "us.amazon.nova-pro-v1:0"
        ]
        if presets.contains(aiService.bedrockModelId) {
            bedrockModelSelection = aiService.bedrockModelId
        } else {
            // Default to first preset if current model is not in the list
            bedrockModelSelection = presets.first ?? "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
            aiService.bedrockModelId = bedrockModelSelection
        }
    }
    
    private func maskKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 8 { return String(repeating: "•", count: trimmed.count) }
        let start = trimmed.prefix(4)
        let end = trimmed.suffix(4)
        return "\(start)\(String(repeating: "•", count: max(0, trimmed.count - 8)))\(end)"
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
