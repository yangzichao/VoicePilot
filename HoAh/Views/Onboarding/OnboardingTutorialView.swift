import SwiftUI
import KeyboardShortcuts

struct OnboardingTutorialView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var whisperState: WhisperState
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Reusable background
                OnboardingBackgroundView()
                ScrollView {
                    HStack(spacing: 0) {
                        // Left side - Tutorial instructions
                        VStack(alignment: .leading, spacing: 40) {
                        // Title and description
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedStringKey("onboarding_tutorial_title"))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(LocalizedStringKey("onboarding_tutorial_subtitle"))
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(4)
                        }
                        
                        // Keyboard shortcut display
                        HStack(spacing: 12) {
                            Text(LocalizedStringKey("onboarding_tutorial_shortcut_label"))
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            
                            shortcutDisplay
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 20) {
                            instructionStep(
                                number: 1,
                                text: NSLocalizedString("onboarding_tutorial_step1", comment: "")
                            )
                            instructionStep(
                                number: 2,
                                text: NSLocalizedString("onboarding_tutorial_step2", comment: "")
                            )
                            instructionStep(
                                number: 3,
                                text: NSLocalizedString("onboarding_tutorial_step3", comment: "")
                            )
                        }
                        
                        // AI Post-processing intro
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizedStringKey("onboarding_tutorial_ai_title"))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(LocalizedStringKey("onboarding_tutorial_ai_intro"))
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStringKey("onboarding_tutorial_ai_point1"))
                                Text(LocalizedStringKey("onboarding_tutorial_ai_point2"))
                                Text(LocalizedStringKey("onboarding_tutorial_ai_point3"))
                            }
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            
                            Text(LocalizedStringKey("onboarding_tutorial_ai_footer"))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                            Spacer()
                            
                            // Continue button
                            Button(action: {
                                hasCompletedOnboarding = true
                            }) {
                                Text(LocalizedStringKey("onboarding_tutorial_complete"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 200, height: 50)
                                    .background(Color.accentColor)
                                    .cornerRadius(25)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            SkipButton(text: NSLocalizedString("onboarding_tutorial_skip", comment: "")) {
                                hasCompletedOnboarding = true
                            }
                        }
                        .padding(60)
                        .frame(width: geometry.size.width * 0.5)
                        
                        // Right side - Static example preview
                        VStack {
                            exampleCard
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(60)
                        .frame(width: geometry.size.width * 0.5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        }
        .onAppear {
            animateIn()
        }
    }
    
    // Static example based on README scenario
    private var exampleCard: some View {
        let rawChinese = "“那个……我觉得就是，嗯，今天下午的那个 meeting 吧，可能得推迟一下，因为那个…… PPT 还没做完，data 还有点问题。”"
        let rawEnglish = "\"Um… I think we might need to postpone this afternoon's meeting, because the slides aren't finished and some of the data is still wrong.\""
        let baseChinese = "那个……我觉得就是，嗯，今天下午的那个 meeting 吧，可能得推迟一下，因为那个…… PPT 还没做完，data 还有点问题。"
        let baseEnglish = "Um… I think we might need to postpone this afternoon's meeting, because the slides aren't finished and some of the data is still wrong."
        let polishChinese = "我觉得今天下午的 meeting 可能得推迟一下，因为 PPT 还没做完，data 还有点问题。"
        let polishEnglish = "I think we should postpone this afternoon's meeting because the slides aren't finished and some of the data still needs fixing."
        let emailChinese = "主题：关于推迟今日 Meeting 的通知\n正文：大家好，由于 PPT 尚未定稿且 data 需进一步核实，建议推迟原定于今天下午的 Meeting。确认时间后将另行通知。"
        let emailEnglish = "Subject: Request to postpone today's meeting\nBody: Hi everyone, since the slides are not finalized and some of the data still needs verification, I'd like to postpone this afternoon's meeting. I'll send an updated time once it's confirmed."

        let isChineseInterface = Locale.current.identifier.hasPrefix("zh")
        
        return VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("onboarding_tutorial_example_title"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Group {
                Text(LocalizedStringKey("onboarding_tutorial_example_raw_title"))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(isChineseInterface ? rawChinese : rawEnglish)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Group {
                Text(LocalizedStringKey("onboarding_tutorial_example_transcript_title"))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(isChineseInterface ? baseChinese : baseEnglish)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Group {
                Text(LocalizedStringKey("onboarding_tutorial_example_ai_title"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(LocalizedStringKey("onboarding_tutorial_example_polish_label"))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Text(isChineseInterface ? polishChinese : polishEnglish)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(LocalizedStringKey("onboarding_tutorial_example_email_label"))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Text(isChineseInterface ? emailChinese : emailEnglish)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Text(LocalizedStringKey("onboarding_tutorial_summary"))
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(24)
        .background(Color.black.opacity(0.35))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var shortcutDisplay: some View {
        Group {
            if hotkeyManager.selectedHotkey1 == .custom,
               let shortcut = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) {
                KeyboardShortcutView(shortcut: shortcut)
                    .scaleEffect(1.2)
            } else if hotkeyManager.selectedHotkey1 != .none && hotkeyManager.selectedHotkey1 != .custom {
                Text(hotkeyManager.selectedHotkey1.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("Right Option (⌥)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private func instructionStep(number: Int, text: String) -> some View {
        HStack(spacing: 20) {
            Text("\(number)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
                .overlay(
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
            
            Text(text)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1
            opacity = 1
        }
    }
} 
