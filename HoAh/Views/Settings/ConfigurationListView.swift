import SwiftUI

/// Displays a simple list of AI Enhancement configuration profiles
/// Allows selecting, editing, and deleting configurations
struct ConfigurationListView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var validationService: ConfigurationValidationService
    @State private var showingAddSheet = false
    @State private var configToEdit: AIEnhancementConfiguration?
    @State private var configToDelete: AIEnhancementConfiguration?
    @State private var showDeleteConfirmation = false
    @State private var pendingConfigToEnable: AIEnhancementConfiguration?
    @State private var showEnablePrompt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(NSLocalizedString("AI Configurations", comment: ""))
                    .font(.headline)

                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("Add Configuration", comment: ""))
            }

            // Configuration List
            if appSettings.aiEnhancementConfigurations.isEmpty {
                Text(NSLocalizedString("No configurations. Click + to add one.", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(appSettings.aiEnhancementConfigurations) { config in
                        AIConfigurationRow(
                            configuration: config,
                            isActive: appSettings.activeAIConfigurationId == config.id,
                            isValidating: validationService.validatingConfigId == config.id,
                            showSuccess: validationService.lastSuccessConfigId == config.id,
                            validationError: validationService.validatingConfigId == nil && validationService.validationError != nil ? validationService.validationError : nil,
                            onSelect: {
                                if appSettings.isAIEnhancementEnabled {
                                    validationService.switchToConfiguration(id: config.id)
                                } else {
                                    pendingConfigToEnable = config
                                    showEnablePrompt = true
                                }
                            },
                            onEdit: {
                                configToEdit = config
                            },
                            onDelete: {
                                configToDelete = config
                                showDeleteConfirmation = true
                            },
                            onDismissError: {
                                validationService.clearError()
                            },
                            onRetry: {
                                validationService.switchToConfiguration(id: config.id)
                            }
                        )

                        if config.id != appSettings.aiEnhancementConfigurations.last?.id {
                            Divider()
                                .padding(.leading, 32)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ConfigurationEditSheet(mode: .add)
        }
        .sheet(item: $configToEdit) { config in
            ConfigurationEditSheet(mode: .edit(config))
        }
        .alert(NSLocalizedString("Delete Configuration", comment: ""), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                configToDelete = nil
            }
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                if let config = configToDelete {
                    appSettings.deleteConfiguration(id: config.id)
                }
                configToDelete = nil
            }
        } message: {
            if let config = configToDelete {
                Text(String(format: NSLocalizedString("Are you sure you want to delete \"%@\"?", comment: ""), config.name))
            }
        }
        .alert(NSLocalizedString("Enable AI Enhancement?", comment: ""), isPresented: $showEnablePrompt) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                pendingConfigToEnable = nil
            }
            Button(NSLocalizedString("Enable", comment: "")) {
                if let config = pendingConfigToEnable {
                    appSettings.isAIEnhancementEnabled = true
                    validationService.switchToConfiguration(id: config.id)
                }
                pendingConfigToEnable = nil
            }
        } message: {
            Text(NSLocalizedString("AI Enhancement is off. Turn it on and use this configuration?", comment: ""))
        }
    }
}

/// Simple row for an AI configuration with validation state
private struct AIConfigurationRow: View {
    let configuration: AIEnhancementConfiguration
    let isActive: Bool
    let isValidating: Bool
    let showSuccess: Bool
    let validationError: ConfigurationValidationError?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDismissError: () -> Void
    let onRetry: () -> Void

    @State private var isHovered = false
    @State private var showErrorPopover = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection/validation indicator
            Group {
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                } else if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }

            // Provider icon
            Image(systemName: configuration.providerIcon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Name and summary
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(configuration.name)
                        .font(.body)
                        .lineLimit(1)

                    if !configuration.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    // Validation error indicator
                    if validationError != nil {
                        Button {
                            showErrorPopover = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showErrorPopover) {
                            ValidationErrorPopover(
                                error: validationError!,
                                onDismiss: {
                                    showErrorPopover = false
                                    onDismissError()
                                },
                                onRetry: {
                                    showErrorPopover = false
                                    onRetry()
                                }
                            )
                        }
                    }
                }

                Text(configuration.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons (visible on hover)
            if isHovered && !isValidating {
                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .onTapGesture {
            if configuration.isValid && !isValidating {
                onSelect()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onSelect()
            } label: {
                Label(NSLocalizedString("Set as Active", comment: ""), systemImage: "checkmark.circle")
            }
            .disabled(!configuration.isValid || isActive || isValidating)

            Button {
                onEdit()
            } label: {
                Label(NSLocalizedString("Edit", comment: ""), systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash")
            }
        }
    }
}

/// Popover showing validation error with recovery options
private struct ValidationErrorPopover: View {
    let error: ConfigurationValidationError
    let onDismiss: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(NSLocalizedString("Validation Failed", comment: ""))
                    .font(.headline)
            }
            
            Text(error.errorDescription ?? "")
                .font(.body)
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button(NSLocalizedString("Dismiss", comment: "")) {
                    onDismiss()
                }
                .buttonStyle(.borderless)
                
                Button(NSLocalizedString("Retry", comment: "")) {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 280)
    }
}
