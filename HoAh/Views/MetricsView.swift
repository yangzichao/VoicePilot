import SwiftUI
import SwiftData
import Charts
import KeyboardShortcuts

struct MetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transcription.timestamp) private var transcriptions: [Transcription]
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    
    var body: some View {
        VStack(spacing: 0) {
            MetricsContent(
                transcriptions: Array(transcriptions)
            )

            if !transcriptions.isEmpty {
                Divider()
                    .padding(.top, 8)

                TranscriptionHistoryView()
            }
        }
        .background(Color(.controlBackgroundColor))
    }
}
