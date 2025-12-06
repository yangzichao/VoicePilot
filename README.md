<div align="center">
  <img src="VoicePilot/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>VoicePilot</h1>
  <p>Voice-to-text for macOS, focused on fast local/LLM transcription and lightweight UI.</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

---

VoicePilot is a macOS voice input app: speak, get text, then optionally run it through AI agents (default, polish, or custom) to clean or act on the transcript. It supports multilingual Whisper and can run fully local (cloud is opt-in). This fork stays fully open—no paywall, no external download links.


## Features

- 🎙️ **Voice in → multi-language transcript out**: Fast capture and transcription with auto language detection.
- 🛠️ **Customizable agents**: Default/Polish or your own agents with safe trigger phrases; optional per use.
- 🔒 **Local-first path**: Use local AI models for transcription and local prompts/agents for post-process; cloud providers are opt-in.
- ⚡ **Lightweight focus**: Trimmed extras; core flow is voice → transcript (+ optional AI).
- 💸 **No subscriptions/paywalls**: Fully open-source; no unlocks required.

## Requirements

- macOS 14.0 or later

## Contributing

PRs are welcome. Please skim [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR or issue.

## License

This project is licensed under the GNU General Public License v3.0 – see [LICENSE](LICENSE).

## Support

Open an issue with clear steps to reproduce, macOS version, and model/provider settings you used.

## Acknowledgments

- Original app by Pax (VoiceInk/VoicePilot) – thanks for open sourcing and the GPL license.
- Core tech: [whisper.cpp](https://github.com/ggerganov/whisper.cpp), [FluidAudio](https://github.com/FluidInference/FluidAudio)
- Dependencies we rely on: [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin), [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit), [Swift Atomics](https://github.com/apple/swift-atomics)
