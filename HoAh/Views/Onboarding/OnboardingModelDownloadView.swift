import SwiftUI

struct OnboardingModelDownloadView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var whisperState: WhisperState
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0
    @State private var isDownloadingTurbo = false
    @State private var isTurboDownloaded = false
    @State private var isTurboSelected = false
    @State private var showTutorial = false
    
    private var canContinue: Bool {
        isTurboDownloaded && isTurboSelected
    }
    
    private let turboModel = PredefinedModels.models.first { $0.name == "ggml-large-v3-turbo-q5_0" } as! LocalModel
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                // Reusable background
                OnboardingBackgroundView()
                
                VStack(spacing: 32) {
                    // Title and description
                    VStack(spacing: 12) {
                        Text(LocalizedStringKey("onboarding_model_title"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 6) {
                            Text(LocalizedStringKey("onboarding_model_subtitle"))
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            
                            Text("Download the local Whisper model to continue. Apple Speech is not used by default; cloud models can be configured later.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                            .multilineTextAlignment(.center)
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    // Cards
                    VStack(spacing: 20) {
                        whisperTurboCard
                    }
                    .frame(maxWidth: min(geometry.size.width * 0.8, 700))
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    // Continue button – only enabled once a model is selected
                    Button(action: {
                        withAnimation {
                            showTutorial = true
                        }
                    }) {
                        Text(LocalizedStringKey("onboarding_continue"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(canContinue ? Color.accentColor : Color.gray)
                            .cornerRadius(25)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canContinue)
                    .opacity(opacity)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(width: min(geometry.size.width * 0.9, 800))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            
            if showTutorial {
                OnboardingTutorialView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            animateIn()
            checkInitialState()
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1
            opacity = 1
        }
    }
    
    // MARK: - Cards
    
    private var whisperTurboCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("onboarding_model_whisper_title"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(LocalizedStringKey("onboarding_model_whisper_body"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            
            Text(String(format: NSLocalizedString("onboarding_model_whisper_note", comment: ""), turboModel.size))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            if isDownloadingTurbo {
                DownloadProgressView(
                    modelName: turboModel.name,
                    downloadProgress: whisperState.downloadProgress
                )
            }
            
            HStack {
                Spacer()
                Button(action: handleTurboSelection) {
                    Text(
                        isTurboDownloaded
                        ? NSLocalizedString("onboarding_model_whisper_use", comment: "")
                        : NSLocalizedString("onboarding_model_whisper_download_and_use", comment: "")
                    )
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isDownloadingTurbo)
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Actions
    
    private func checkInitialState() {
        isTurboDownloaded = whisperState.availableModels.contains(where: { $0.name == turboModel.name })
        isTurboSelected = whisperState.currentTranscriptionModel?.name == turboModel.name
    }
    
    private func handleTurboSelection() {
        if isTurboDownloaded {
            if let modelToSet = whisperState.allAvailableModels.first(where: { $0.name == turboModel.name }) {
                Task {
                    await whisperState.setDefaultTranscriptionModel(modelToSet)
                    await MainActor.run {
                        withAnimation {
                            isTurboSelected = true
                        }
                    }
                }
            }
        } else {
            withAnimation {
                isDownloadingTurbo = true
            }
            Task {
                await whisperState.downloadModel(turboModel)
                let downloaded = whisperState.availableModels.contains(where: { $0.name == turboModel.name })
                if downloaded,
                   let modelToSet = whisperState.allAvailableModels.first(where: { $0.name == turboModel.name }) {
                    await whisperState.setDefaultTranscriptionModel(modelToSet)
                    await MainActor.run {
                        withAnimation {
                            isDownloadingTurbo = false
                            isTurboDownloaded = true
                            isTurboSelected = true
                        }
                    }
                } else {
                    await MainActor.run {
                        withAnimation {
                            isDownloadingTurbo = false
                            isTurboDownloaded = false
                            isTurboSelected = false
                        }
                    }
                }
            }
        }
    }
}
