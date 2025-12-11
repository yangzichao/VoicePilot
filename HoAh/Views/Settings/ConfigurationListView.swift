import SwiftUI

/// Displays a simple list of AI Enhancement configuration profiles
/// Allows selecting, editing, and deleting configurations
struct ConfigurationListView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @State private var showingAddSheet = false
    @State private var configToEdit: AIEnhancementConfiguration?
    @State private var configToDelete: AIEnhancementConfiguration?
    @State private var showDeleteConfirmation = false

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
                            onSelect: {
                                appSettings.setActiveConfiguration(id: config.id)
                            },
                            onEdit: {
                                configToEdit = config
                            },
                            onDelete: {
                                configToDelete = config
                                showDeleteConfirmation = true
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
    }
}

/// Simple row for an AI configuration
private struct AIConfigurationRow: View {
    let configuration: AIEnhancementConfiguration
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isActive ? .accentColor : .secondary)
                .font(.system(size: 16))

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
                }

                Text(configuration.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons (visible on hover)
            if isHovered {
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
            if configuration.isValid {
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
            .disabled(!configuration.isValid || isActive)

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
