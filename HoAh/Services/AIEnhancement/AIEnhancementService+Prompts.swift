import Foundation

@MainActor
extension AIEnhancementService {
    func addPrompt(title: String, promptText: String, icon: PromptIcon = "doc.text.fill", description: String? = nil, triggerWords: [String] = [], useSystemInstructions: Bool = true, kind: PromptKind) {
        let newPrompt = CustomPrompt(title: title, promptText: promptText, isActive: true, icon: icon, description: description, isPredefined: false, triggerWords: triggerWords, useSystemInstructions: useSystemInstructions)
        switch kind {
        case .active:
            activePrompts.append(newPrompt)
            if selectedPromptId == nil {
                selectedPromptId = newPrompt.id
            }
        case .trigger:
            triggerPrompts.append(newPrompt)
        }
    }

    func updatePrompt(_ prompt: CustomPrompt) {
        if let index = activePrompts.firstIndex(where: { $0.id == prompt.id }) {
            activePrompts[index] = prompt
            return
        }
        if let index = triggerPrompts.firstIndex(where: { $0.id == prompt.id }) {
            triggerPrompts[index] = prompt
        }
    }

    func deletePrompt(_ prompt: CustomPrompt) {
        if activePrompts.contains(where: { $0.id == prompt.id }) {
            activePrompts.removeAll { $0.id == prompt.id }
            if selectedPromptId == prompt.id {
                selectedPromptId = activePrompts.first?.id
            }
        } else if triggerPrompts.contains(where: { $0.id == prompt.id }) {
            triggerPrompts.removeAll { $0.id == prompt.id }
        }
    }

    func setActivePrompt(_ prompt: CustomPrompt) {
        guard activePrompts.contains(where: { $0.id == prompt.id }) else { return }
        selectedPromptId = prompt.id
    }

    func resetPromptToDefault(_ prompt: CustomPrompt) {
        guard prompt.isPredefined,
              let template = PredefinedPrompts.createDefaultPrompts().first(where: { $0.id == prompt.id }) else { return }
        
        if let index = activePrompts.firstIndex(where: { $0.id == prompt.id }) {
            let restoredPrompt = CustomPrompt(
                id: template.id,
                title: template.title,
                promptText: template.promptText,
                isActive: activePrompts[index].isActive,
                icon: template.icon,
                description: template.description,
                isPredefined: true,
                triggerWords: template.triggerWords,
                useSystemInstructions: template.useSystemInstructions
            )
            activePrompts[index] = restoredPrompt
            if selectedPromptId == nil {
                selectedPromptId = restoredPrompt.id
            }
            return
        }
        
        if let index = triggerPrompts.firstIndex(where: { $0.id == prompt.id }) {
            let restoredPrompt = CustomPrompt(
                id: template.id,
                title: template.title,
                promptText: template.promptText,
                isActive: triggerPrompts[index].isActive,
                icon: template.icon,
                description: template.description,
                isPredefined: true,
                triggerWords: template.triggerWords,
                useSystemInstructions: template.useSystemInstructions
            )
            triggerPrompts[index] = restoredPrompt
        }
    }

    func resetPredefinedPrompts() {
        let templates = PredefinedPrompts.createDefaultPrompts()
        let (defaultActive, defaultTrigger) = templates.partitionedByTriggerWords()

        var updatedActive = activePrompts
        var updatedTrigger = triggerPrompts

        for template in defaultActive {
            if let index = updatedActive.firstIndex(where: { $0.id == template.id }) {
                let existing = updatedActive[index]
                updatedActive[index] = CustomPrompt(
                    id: template.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existing.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: template.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
            } else {
                updatedActive.append(template)
            }
        }

        for template in defaultTrigger {
            if let index = updatedTrigger.firstIndex(where: { $0.id == template.id }) {
                let existing = updatedTrigger[index]
                updatedTrigger[index] = CustomPrompt(
                    id: template.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existing.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: template.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
            } else {
                updatedTrigger.append(template)
            }
        }

        activePrompts = updatedActive
        triggerPrompts = updatedTrigger

        if selectedPromptId == nil || !activePrompts.contains(where: { $0.id == selectedPromptId }) {
            selectedPromptId = activePrompts.first?.id
        }
    }

    func initializePredefinedPrompts() {
        let predefinedTemplates = PredefinedPrompts.createDefaultPrompts()
        let templateIDs = Set(predefinedTemplates.map { $0.id })
        let (defaultActive, defaultTrigger) = predefinedTemplates.partitionedByTriggerWords()

        // Force migration: If a prompt is currently in activePrompts but its template is now in defaultTrigger, move it.
        // This handles cases like the "Terminal" prompt moving from manual to trigger-only.
        let defaultTriggerIDs = Set(defaultTrigger.map { $0.id })
        let migratingPrompts = activePrompts.filter { $0.isPredefined && defaultTriggerIDs.contains($0.id) }
        activePrompts.removeAll { $0.isPredefined && defaultTriggerIDs.contains($0.id) }
        triggerPrompts.append(contentsOf: migratingPrompts)

        // Remove predefined prompts that are no longer part of the shipped set
        activePrompts.removeAll { prompt in
            prompt.isPredefined && !templateIDs.contains(prompt.id)
        }
        triggerPrompts.removeAll { prompt in
            prompt.isPredefined && !templateIDs.contains(prompt.id)
        }
        
        // Normalize any misplaced prompts (move trigger-word prompts into trigger collection)
        let (normalizedActive, migratedToTrigger) = activePrompts.partitionedByTriggerWords()
        activePrompts = normalizedActive
        if !migratedToTrigger.isEmpty {
            triggerPrompts.append(contentsOf: migratedToTrigger)
        }

        for template in defaultActive {
            if let existingIndex = activePrompts.firstIndex(where: { $0.id == template.id }) {
                let existingPrompt = activePrompts[existingIndex]
                let mergedPrompt = CustomPrompt(
                    id: existingPrompt.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existingPrompt.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: existingPrompt.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
                activePrompts[existingIndex] = mergedPrompt
            } else {
                activePrompts.append(template)
            }
        }

        for template in defaultTrigger {
            if let existingIndex = triggerPrompts.firstIndex(where: { $0.id == template.id }) {
                let existingPrompt = triggerPrompts[existingIndex]
                let mergedPrompt = CustomPrompt(
                    id: existingPrompt.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existingPrompt.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: existingPrompt.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
                triggerPrompts[existingIndex] = mergedPrompt
            } else {
                triggerPrompts.append(template)
            }
        }

        // Migrate TODO preset to trigger collection and ensure it has trigger words
        if let todoTemplate = predefinedTemplates.first(where: { $0.id == PredefinedPrompts.todoPromptId }) {
            if let idx = activePrompts.firstIndex(where: { $0.id == todoTemplate.id }) {
                let prompt = activePrompts.remove(at: idx)
                let migrated = CustomPrompt(
                    id: prompt.id,
                    title: todoTemplate.title,
                    promptText: prompt.promptText,
                    isActive: prompt.isActive,
                    icon: prompt.icon,
                    description: prompt.description,
                    isPredefined: prompt.isPredefined,
                    triggerWords: todoTemplate.triggerWords,
                    useSystemInstructions: prompt.useSystemInstructions
                )
                if !triggerPrompts.contains(where: { $0.id == prompt.id }) {
                    triggerPrompts.append(migrated)
                }
            }
            if let idx = triggerPrompts.firstIndex(where: { $0.id == todoTemplate.id }) {
                let prompt = triggerPrompts[idx]
                if prompt.triggerWords.isEmpty {
                    let updated = CustomPrompt(
                        id: prompt.id,
                        title: todoTemplate.title,
                        promptText: prompt.promptText,
                        isActive: prompt.isActive,
                        icon: prompt.icon,
                        description: prompt.description,
                        isPredefined: prompt.isPredefined,
                        triggerWords: todoTemplate.triggerWords,
                        useSystemInstructions: prompt.useSystemInstructions
                    )
                    triggerPrompts[idx] = updated
                }
            }
        }
    }
}
