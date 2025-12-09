<div align="center">
  <img src="HoAh/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>HoAh (吼蛙)</h1>
  <p>Faithful, fast local multilingual transcription. AI Agents on demand.</p>
  <p>忠实、快速的本地多语言转录。AI Agents 按需处理。</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

**English | [简体中文](#中文)** · [Website / 项目主页](https://yangzichao.github.io/hoah-dictation/)

---

<details open id="english">
<summary><strong>English</strong></summary>

**HoAh** is a refined speech-to-text tool for macOS. Workflow:
1. **Speech**: Record your voice.
2. **Text**: Fast, local transcription via Whisper.
3. **Structure**: **AI Agents** (LLMs) turn raw text into formatted emails, meeting notes, code snippets, or polished prose.

It supports multiple languages, custom agent prompts, and runs fully local by default. No subscriptions—just your voice and (optionally) an API key.

### Features
- **Adaptive Agents**: Keep a **Primary Role** or auto-switch via **App Triggers** based on your active window.
- **Local & Cloud Intelligence**: Run local Whisper models or connect to cloud providers.
- **Lightweight Focus**: Voice → transcript (+ optional AI), nothing extra.
- **Forever Free**: Fully open-source. No subscriptions or paywalls.

### Examples
HoAh’s philosophy: **Transcription captures reality; Agents polish it.**

**Example: Professional Mode (High-EQ)**
- **Raw**: “Hey, I can’t do this today. The client is being annoying and changed their mind again. It’s not my fault the deadline is missed.”
- **Polish**: “I cannot complete this today. The client changed their requirements again, so it is not my fault the deadline is missed.” (clean but blunt)
- **Professional**: “I will be unable to complete this task today due to recent changes in the client’s requirements. Given these adjustments, we may need to revisit the timeline to ensure we meet expectations.” (diplomatic, solution-oriented)

### Requirements
- macOS 14.0 or later

### Contributing
PRs welcome. Please skim [CONTRIBUTING.md](CONTRIBUTING.md) first.

### License
Licensed under GNU GPL v3.0 – see [LICENSE](LICENSE).

### Support
Open an issue with clear repro steps, macOS version, and model/provider settings.

### Acknowledgments
- Original app by Pax (VoiceInk) – thanks for the GPL base.
- Core tech: [whisper.cpp](https://github.com/ggerganov/whisper.cpp), [FluidAudio](https://github.com/FluidInference/FluidAudio)
- Dependencies: [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin), [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit), [Swift Atomics](https://github.com/apple/swift-atomics)

</details>

<details id="中文">
<summary><strong>简体中文</strong></summary>

**HoAh** 是一款为 macOS 精心打造的语音转文字工具。它的工作流简单而强大：
1. **语音**：录制你的声音。
2. **文本**：通过本地 Whisper 模型快速转录。
3. **结构化**：**AI Agents** (LLM) 瞬间将原始文本处理为格式规范的邮件、会议纪要、代码片段或润色后的文章。

它支持多种语言、自定义 Agent 提示词（Prompts），并且默认完全本地运行。无需订阅，只需你的声音和（可选的）API Key。

### 功能特性
- **自适应 Agents**：锁定一个 **主角色**，或使用 **App 触发器** 根据你当前活动的窗口自动切换模式。
- **本地与云端智能**：既可以运行本地 Whisper 模型，也可以连接云端 AI 提供商。
- **轻量专注**：剔除冗余，专注于核心流程：语音 → 转录 (+ 可选 AI)。
- **永久免费**：完全开源。无订阅费，无付费墙。

### 场景示例
HoAh 的理念：**转录忠实还原，Agent 负责加工。**

**示例：职场模式 (Professional)**
- **语音输入 (Raw)**：“哎，今天这活儿我干不了。客户太烦人了，一直改主意。最后没按期完成又不怪我。”
- **润色后 (Polish)**：“今天我无法完成这项工作。客户反复修改需求，所以没能按时完成并不是我的错。”（通顺但生硬）
- **职场模式 (Professional)**：“由于客户近期对需求进行了调整，我今天可能无法完成该任务。鉴于这些变动，建议我们重新评估项目时间表，以确保最终交付符合预期。”（委婉、专业、解决问题导向）

### 系统要求
- macOS 14.0 或更高版本

### 贡献
欢迎提交 PR。请先浏览 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 许可证
本项目采用 GNU General Public License v3.0 – 详见 [LICENSE](LICENSE)。

### 支持
如有问题，请提交 Issue，并提供清晰的复现步骤、macOS 版本以及使用的模型/提供商设置。

### 致谢
- 原应用来自 Pax (VoiceInk) – 感谢其开源及 GPL 许可。
- 核心技术：[whisper.cpp](https://github.com/ggerganov/whisper.cpp), [FluidAudio](https://github.com/FluidInference/FluidAudio)
- 依赖库：[Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin), [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit), [Swift Atomics](https://github.com/apple/swift-atomics)

</details>
