import SwiftUI

struct OnboardingModelDownloadView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var whisperState: WhisperState
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0
    @State private var isDownloadingTurbo = false
    @State private var isTurboReady = false
    @State private var showTutorial = false
    @State private var hasSelectedAnyModel = false
    @State private var isAppleAvailableCached: Bool = false
    
    private let turboModel = PredefinedModels.models.first { $0.name == "ggml-large-v3-turbo-q5_0" } as! LocalModel
    private let scribeModel = PredefinedModels.models.first { $0.name == "scribe_v2" }
    
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
                        
                        Text(LocalizedStringKey("onboarding_model_subtitle"))
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    // Cards
                    VStack(spacing: 20) {
                        whisperTurboCard
                        scribeCard
                        appleCard
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
                            .background(hasSelectedAnyModel ? Color.accentColor : Color.gray)
                            .cornerRadius(25)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!hasSelectedAnyModel)
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
                        isTurboReady
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
    
    private var scribeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("onboarding_model_scribe_title"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(LocalizedStringKey("onboarding_model_scribe_body"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            
            Text(LocalizedStringKey("onboarding_model_scribe_note"))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            HStack {
                Spacer()
                Button(action: handleScribeLater) {
                    Text(LocalizedStringKey("onboarding_model_scribe_later"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.25))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var appleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("onboarding_model_apple_title"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(LocalizedStringKey("onboarding_model_apple_body"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            
            Text(LocalizedStringKey("onboarding_model_apple_note"))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            HStack {
                Spacer()
                Button(action: handleAppleSelection) {
                    Text(LocalizedStringKey("onboarding_model_apple_use_anyway"))
                        .font(.subheadline.bold())
                        .foregroundColor(isAppleAvailableCached ? .black : .white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isAppleAvailableCached ? Color.white : Color.white.opacity(0.2))
                        .cornerRadius(20)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.25))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Actions
    
    private func checkInitialState() {
        isTurboReady = whisperState.availableModels.contains(where: { $0.name == turboModel.name })
        hasSelectedAnyModel = whisperState.currentTranscriptionModel != nil
        isAppleAvailableCached = whisperState.isNativeAppleTranscriptionAvailable()
    }
    
    private func handleTurboSelection() {
        if isTurboReady {
            if let modelToSet = whisperState.allAvailableModels.first(where: { $0.name == turboModel.name }) {
                Task {
                    await whisperState.setDefaultTranscriptionModel(modelToSet)
                    withAnimation {
                        hasSelectedAnyModel = true
                    }
                }
            }
        } else {
            withAnimation {
                isDownloadingTurbo = true
            }
            Task {
                await whisperState.downloadModel(turboModel)
                isTurboReady = whisperState.availableModels.contains(where: { $0.name == turboModel.name })
                if isTurboReady,
                   let modelToSet = whisperState.allAvailableModels.first(where: { $0.name == turboModel.name }) {
                    await whisperState.setDefaultTranscriptionModel(modelToSet)
                    withAnimation {
                        isDownloadingTurbo = false
                        hasSelectedAnyModel = true
                    }
                } else {
                    withAnimation {
                        isDownloadingTurbo = false
                    }
                }
            }
        }
    }
    
    private func handleAppleSelection() {
        Task {
            if let appleModel = await whisperState.allAvailableModels.first(where: { $0.provider == .nativeApple }) {
                await whisperState.setDefaultTranscriptionModel(appleModel)
            }
            await MainActor.run {
                withAnimation {
                    hasSelectedAnyModel = true
                    showTutorial = true
                }
            }
        }
    }
    
    private func handleScribeLater() {
        withAnimation {
            hasSelectedAnyModel = true
            showTutorial = true
        }
    }
}
