import Foundation
import SwiftUI    // Import to ensure we have access to SwiftUI types if needed

enum PredefinedPrompts {
    private static let predefinedPromptsKey = "PredefinedPrompts"
    
    // Static UUIDs for predefined prompts
    static let defaultPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let assistantPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let polishPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let summarizePromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let emailDraftPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    static let formalPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    
    static var all: [CustomPrompt] {
        // Always return the latest predefined prompts from source code
        createDefaultPrompts()
    }
    
    static func createDefaultPrompts() -> [CustomPrompt] {
        [
            // Manual presets (no trigger words; user selects explicitly)
            CustomPrompt(
                id: defaultPromptId,
                title: "Basic",
                promptText: """
You are a light transcript cleaner. Keep the original meaning, tone, and language mix; do NOT translate.
- Input can be Chinese, English, or mixed. Keep the same languages and code-mix.
- Remove obvious fillers/hesitations/stutters only if they don’t change meaning. Examples: 吧、啊、嗯、呃、呢、嘛、欸、喔、然后、就是、那个、这个、好像、之类的、吧吧吧；“uh”, “um”, “er”, “you know”, “like” (when not meaning “similar”), “kind of”, “sort of”; repeated syllables from stuttering.
- If the speaker self-corrects (e.g., “不是A，是B” / “I mean B”), keep the final correction and drop the earlier wording.
- Preserve technical terms, product names, URLs, code, numbers, currencies, dates, and measures exactly as spoken.
- Do not add or invent content. If the input is incomplete, leave it incomplete.
- Output only the lightly cleaned text in the original language mix.
""",
                icon: "checkmark.seal.fill",
                description: "Basic cleanup: drop fillers/stutters, keep wording and language mix intact.",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: polishPromptId,
                title: "Polish",
                promptText: """
You are polishing a transcript for clarity, concision, and correctness without changing intent. Do NOT translate.
- Input may be Chinese, English, or mixed; keep the same language mix.
- Remove fillers/hesitations/stutters only if meaning is unchanged. Examples: 吧、啊、嗯、呃、呢、嘛、欸、喔、然后、就是、那个、这个、好像、之类的、吧吧吧；“uh”, “um”, “er”, “you know”, “like” (when filler), “kind of”, “sort of”; repeated syllables/words from stuttering.
- Respect self-corrections: if the speaker revises (e.g., “不是A，是B” / “I mean B”), keep the final correction, drop the earlier wording.
- If a word seems mistranscribed (homophones/near-homophones, ASR or IME mistakes), use context to pick the most plausible correct word—preserve English proper nouns/terms as spoken.
- Improve grammar, punctuation, and flow; split run-ons; tighten wording while keeping meaning.
- Preserve technical terms, product names, URLs, code, numbers, currencies, dates, measures exactly; do not invent or omit details.
- Normalize spacing/punctuation across CJK/Latin text. If input is incomplete, leave it incomplete.
- Output only the polished text in the original language mix; no added commentary.
""",
                icon: "wand.and.stars",
                description: "Polish for clarity/conciseness; respects corrections, language mix, and technical details.",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: formalPromptId,
                title: "Formal",
                promptText: """
You rewrite the transcript into concise, formal, and polite written style while keeping the original meaning. Do NOT translate the main language; keep English proper nouns/terms exactly as spoken.
- Input may be Chinese, English, or mixed. Preserve the primary language; keep English names, brands, technical terms, URLs, code, numbers, currencies, dates, measures unchanged.
- Remove fillers/hesitations/stutters that do not affect meaning. Respect self-corrections: keep the final revision, drop the earlier wording.
- If a word seems mistranscribed (homophones/near-homophones, ASR or IME mistakes), use context to replace it with the most plausible correct word; keep English proper nouns/terms exactly as spoken.
- Fix grammar, punctuation, and sentence structure for best readability. Use formal tone and concise wording.
- For Chinese input, watch for homophone or ASR mis-hearings (e.g., 同音字/近音字). Use context to replace mistranscribed words with the most plausible correct words; do not change English terms.
- For English input, ensure clarity and formality; preserve English proper nouns as-is.
- Do not invent or omit facts. If something is ambiguous, choose the most contextually likely wording without adding new information.
- Output only the finalized formal text in the original language mix (with English nouns preserved).
""",
                icon: "doc.text.magnifyingglass",
                description: "Formal rewrite: polite, concise, fixes homophone/ASR slips, preserves English nouns and details.",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),

            // Auto-trigger presets (activated via trigger words)
            CustomPrompt(
                id: summarizePromptId,
                title: "Summarize",
                promptText: """
Create a crisp summary in 3–5 bullet points.
- Fix obvious mistranscriptions (homophones/near-homophones, ASR/IME slips) using context; keep English proper nouns/brands/technical terms exactly as spoken.
- Preserve key numbers, dates, names, decisions, and action items. Do not add or omit facts.
- Keep wording brief and readable; no extra commentary.
""",
                icon: "text.alignleft",
                description: "Auto-activates on summary cues; concise bullets with context-aware corrections.",
                isPredefined: true,
                triggerWords: ["summarize my conversation", "give me a summary of this conversation"],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: emailDraftPromptId,
                title: "Email Draft",
                promptText: """
Rewrite as a concise, polite, professional email with a clear greeting and sign-off.
- Maintain the original language (Chinese/English/mixed) unless the user explicitly asked to translate.
- Fix obvious mistranscriptions (homophones/near-homophones, ASR/IME slips) using context; keep English names/brands/technical terms exactly as spoken.
- Keep all facts intact (people, dates, numbers, commitments). Do not add or remove information.
- Tone: professional, courteous, readable; keep it brief and structured.
""",
                icon: "envelope.fill",
                description: "Auto-activates on email cues; polite, concise email with context-aware corrections.",
                isPredefined: true,
                triggerWords: ["draft an email reply", "compose an email reply", "write an email reply"],
                useSystemInstructions: true
            ),

            // Assistant remains available for freeform Q&A (manual)
            CustomPrompt(
                id: assistantPromptId,
                title: "Assistant",
                promptText: AIPrompts.assistantMode,
                icon: "bubble.left.and.bubble.right.fill",
                description: "AI assistant that provides direct answers to queries",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: false
            )
        ]
    }
}
