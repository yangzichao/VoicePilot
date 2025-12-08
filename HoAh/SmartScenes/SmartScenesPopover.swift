import SwiftUI

struct SmartScenesPopover: View {
    @ObservedObject var smartScenesManager = SmartScenesManager.shared
    @State private var selectedConfig: SmartSceneConfig?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("Select Smart Scene"))
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)
                .padding(.top, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollView {
                let enabledConfigs = smartScenesManager.configurations.filter { $0.isEnabled }
                VStack(alignment: .leading, spacing: 4) {
                    if enabledConfigs.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 16))
                            Text(LocalizedStringKey("No Smart Scenes Available"))
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(enabledConfigs) { config in
                            SmartSceneRow(
                                config: config,
                                isSelected: selectedConfig?.id == config.id,
                                action: {
                                    smartScenesManager.setActiveConfiguration(config)
                                    selectedConfig = config
                                    applySelectedConfiguration()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(width: 180)
        .frame(maxHeight: 340)
        .padding(.vertical, 8)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .onAppear {
            selectedConfig = smartScenesManager.activeConfiguration
        }
        .onChange(of: smartScenesManager.activeConfiguration) { newValue in
            selectedConfig = newValue
        }
    }
    
    private func applySelectedConfiguration() {
        Task {
            if let config = selectedConfig {
                await SmartSceneSessionManager.shared.beginSession(with: config)
            }
        }
    }
}

struct SmartSceneRow: View {
    let config: SmartSceneConfig
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(config.emoji)
                    .font(.system(size: 14))

                Text(config.name)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 13))
                    .lineLimit(1)

                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
} 
