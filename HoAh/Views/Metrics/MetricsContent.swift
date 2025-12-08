import SwiftUI

struct MetricsContent: View {
    let transcriptions: [Transcription]
    @State private var showKeyboardShortcuts = false

    var body: some View {
        Group {
            if transcriptions.isEmpty {
                emptyStateView
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 24) {
                            metricsSection

                            Spacer(minLength: 20)

                            HStack {
                                Spacer()
                                footerActionsView
                            }
                        }
                        .frame(minHeight: geometry.size.height - 56)
                        .padding(.vertical, 28)
                        .padding(.horizontal, 32)
                    }
                    .background(Color(.windowBackgroundColor))
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No Transcriptions Yet")
                .font(.title3.weight(.semibold))
            Text("Start your first recording to unlock value insights.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Sections
    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
            MetricCard(
                icon: "mic.fill",
                title: "Sessions Recorded",
                value: "\(transcriptions.count)",
                detail: "HoAh sessions completed",
                color: .purple
            )
            
            MetricCard(
                icon: "text.alignleft",
                title: "Words Dictated",
                value: Formatters.formattedNumber(totalWordsTranscribed),
                detail: "words generated",
                color: Color(nsColor: .controlAccentColor)
            )
            
            MetricCard(
                icon: "speedometer",
                title: "Words Per Minute",
                value: averageWordsPerMinute > 0
                    ? String(format: "%.1f", averageWordsPerMinute)
                    : "–",
                detail: "HoAh vs. typing by hand",
                color: .yellow
            )
            
            MetricCard(
                icon: "keyboard.fill",
                title: "Keystrokes Saved",
                value: Formatters.formattedNumber(totalKeystrokesSaved),
                detail: "fewer keystrokes",
                color: .orange
            )
        }
    }
    
    private var footerActionsView: some View {
        HStack(spacing: 12) {
            KeyboardShortcutsButton(showKeyboardShortcuts: $showKeyboardShortcuts)
            CopySystemInfoButton()
        }
    }
    
    // MARK: - Computed Metrics
    
    private var totalWordsTranscribed: Int {
        transcriptions.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
    
    private var totalRecordedTime: TimeInterval {
        transcriptions.reduce(0) { $0 + $1.duration }
    }
    
    private var averageWordsPerMinute: Double {
        guard totalRecordedTime > 0 else { return 0 }
        return Double(totalWordsTranscribed) / (totalRecordedTime / 60.0)
    }
    
    private var totalKeystrokesSaved: Int {
        Int(Double(totalWordsTranscribed) * 5.0)
    }
}

private enum Formatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    static func formattedNumber(_ value: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct KeyboardShortcutsButton: View {
    @Binding var showKeyboardShortcuts: Bool

    var body: some View {
        Button(action: {
            showKeyboardShortcuts = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "command")
                    .font(.system(size: 13, weight: .medium))

                Text("Keyboard Shortcuts")
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.thinMaterial))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showKeyboardShortcuts, arrowEdge: .bottom) {
            KeyboardShortcutsListView()
        }
    }
}

private struct CopySystemInfoButton: View {
    @State private var isCopied: Bool = false

    var body: some View {
        Button(action: {
            copySystemInfo()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .rotationEffect(.degrees(isCopied ? 360 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)

                Text(isCopied ? String(localized: "Copied!") : String(localized: "Copy System Info"))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.thinMaterial))
        }
        .buttonStyle(.plain)
        .scaleEffect(isCopied ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
    }

    private func copySystemInfo() {
        SystemInfoService.shared.copySystemInfoToClipboard()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCopied = false
            }
        }
    }
}
