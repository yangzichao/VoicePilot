import SwiftUI

struct SmartScenesSettingsSection: View {
    @ObservedObject private var smartScenesManager = SmartScenesManager.shared
    @AppStorage("smartScenesUIFlag") private var smartScenesUIFlag = false
    @AppStorage(SmartSceneDefaults.autoRestoreKey) private var powerModeAutoRestoreEnabled = false
    @State private var showDisableAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.square.fill.on.square")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Scenes")
                        .font(.headline)
                    Text("Turn on Smart Scenes to automatically apply custom configurations based on the app or website you are using.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("Enable Smart Scenes", isOn: toggleBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if smartScenesUIFlag {
                Divider()
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                
                HStack(spacing: 8) {
                    Toggle(isOn: $powerModeAutoRestoreEnabled) {
                        Text("Auto-Restore Preferences")
                    }
                    .toggleStyle(.switch)
                    
                    InfoTip(
                        title: "Auto-Restore Preferences",
                        message: "After each recording session, revert enhancement and transcription preferences to whatever was configured before the smart scene was activated."
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: smartScenesUIFlag)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false, useAccentGradientWhenSelected: true))
        .alert("Smart Scenes Still Active", isPresented: $showDisableAlert) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Smart Scenes can't be disabled while any configuration is still enabled. Disable or remove your smart scenes first.")
        }
    }
    
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { smartScenesUIFlag },
            set: { newValue in
                if newValue {
                    smartScenesUIFlag = true
                } else if smartScenesManager.configurations.noneEnabled {
                    smartScenesUIFlag = false
                } else {
                    showDisableAlert = true
                }
            }
        )
    }
    
}

private extension Array where Element == SmartSceneConfig {
    var noneEnabled: Bool {
        allSatisfy { !$0.isEnabled }
    }
}

enum SmartSceneDefaults {
    static let autoRestoreKey = "powerModeAutoRestoreEnabled"
}
