import Foundation
import AppKit

@MainActor
extension AIEnhancementService {
    fileprivate func waitForRateLimit() async throws {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < rateLimitInterval {
                try await Task.sleep(nanoseconds: UInt64((rateLimitInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }

    fileprivate func getSystemMessage(for mode: EnhancementPrompt) async -> String {
        let selectedTextContext: String
        // Only fetch selected text if enabled and process is trusted
        if useSelectedTextContext && AXIsProcessTrusted() {
            if let selectedText = await SelectedTextService.fetchSelectedText(), !selectedText.isEmpty {
                selectedTextContext = "\n\n<CURRENTLY_SELECTED_TEXT>\n\(selectedText)\n</CURRENTLY_SELECTED_TEXT>"
            } else {
                selectedTextContext = ""
            }
        } else {
            selectedTextContext = ""
        }

        let clipboardContext = if useClipboardContext,
                              let clipboardText = lastCapturedClipboard,
                              !clipboardText.isEmpty {
            "\n\n<CLIPBOARD_CONTEXT>\n\(clipboardText)\n</CLIPBOARD_CONTEXT>"
        } else {
            ""
        }

        let screenCaptureContext = if useScreenCaptureContext,
                                   let capturedText = screenCaptureService.lastCapturedText,
                                   !capturedText.isEmpty {
            "\n\n<CURRENT_WINDOW_CONTEXT>\n\(capturedText)\n</CURRENT_WINDOW_CONTEXT>"
        } else {
            ""
        }

        let userProfileSection = if !userProfileContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            "\n\n<USER_PROFILE>\n\(userProfileContext.trimmingCharacters(in: .whitespacesAndNewlines))\n</USER_PROFILE>"
        } else {
            ""
        }

        let allContextSections = userProfileSection + selectedTextContext + clipboardContext + screenCaptureContext

        if let activePrompt = activePrompt {
            return activePrompt.finalPromptText + allContextSections
        } else {
            guard let fallback = activePrompts.first(where: { $0.id == PredefinedPrompts.defaultPromptId }) ?? activePrompts.first else {
                return allContextSections
            }
            return fallback.finalPromptText + allContextSections
        }
    }

    func makeRequest(text: String, mode: EnhancementPrompt) async throws -> String {
        guard let session = activeSession else {
            throw EnhancementError.notConfigured
        }

        guard !text.isEmpty else {
            return "" // Silently return empty string instead of throwing error
        }

        let formattedText = "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        let systemMessage = await getSystemMessage(for: mode)
        
        // Persist the exact payload being sent (also used for UI)
        await MainActor.run {
            self.lastSystemMessageSent = systemMessage
            self.lastUserMessageSent = formattedText
        }

        // Log the message being sent to AI enhancement
        logger.notice("AI Enhancement - System Message: \(systemMessage, privacy: .public)")
        logger.notice("AI Enhancement - User Message: \(formattedText, privacy: .public)")

        try await waitForRateLimit()

        return try await makeRequestWithRetry(systemMessage: systemMessage, formattedText: formattedText, session: session)
    }

    fileprivate func makeRequestWithRetry(systemMessage: String, formattedText: String, session: ActiveSession, maxRetries: Int = 3, initialDelay: TimeInterval = 1.0) async throws -> String {
        var retries = 0
        var currentDelay = initialDelay

        while retries < maxRetries {
            do {
                return try await performRequest(systemMessage: systemMessage, formattedText: formattedText, session: session)
            } catch let error as EnhancementError {
                switch error {
                case .networkError, .serverError, .rateLimitExceeded:
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed, retrying in \(currentDelay)s... (Attempt \(retries)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2 // Exponential backoff
                    } else {
                        logger.error("Request failed after \(maxRetries) retries.")
                        throw error
                    }
                default:
                    throw error
                }
            } catch {
                // For other errors, check if it's a network-related URLError
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost].contains(nsError.code) {
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed with network error, retrying in \(currentDelay)s... (Attempt \(retries)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2 // Exponential backoff
                    } else {
                        logger.error("Request failed after \(maxRetries) retries with network error.")
                        throw EnhancementError.networkError
                    }
                } else {
                    throw error
                }
            }
        }

        // This part should ideally not be reached, but as a fallback:
        throw EnhancementError.enhancementFailed
    }

    fileprivate func performRequest(systemMessage: String, formattedText: String, session: ActiveSession) async throws -> String {
        switch session.provider {
        case .awsBedrock:
            return try await makeBedrockRequest(systemMessage: systemMessage, userMessage: formattedText, session: session)
        case .anthropic:
            guard case .anthropic(let apiKey) = session.auth, !apiKey.isEmpty else {
                throw EnhancementError.notConfigured
            }

            let requestBody: [String: Any] = [
                "model": session.model,
                "max_tokens": 8192,
                "system": systemMessage,
                "messages": [
                    ["role": "user", "content": formattedText]
                ]
            ]

            var request = URLRequest(url: URL(string: session.provider.baseURL)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = baseTimeout
            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EnhancementError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let content = jsonResponse["content"] as? [[String: Any]],
                          let firstContent = content.first,
                          let enhancedText = firstContent["text"] as? String else {
                        throw EnhancementError.enhancementFailed
                    }

                    let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    return filteredText
                } else if httpResponse.statusCode == 429 {
                    throw EnhancementError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw EnhancementError.apiKeyInvalid
                } else if (500...599).contains(httpResponse.statusCode) {
                    throw EnhancementError.serverError
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                    throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
                }

            } catch let error as EnhancementError {
                throw error
            } catch let error as URLError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }

        default:
            guard case .bearer(let apiKey) = session.auth, !apiKey.isEmpty else {
                throw EnhancementError.notConfigured
            }

            let url = URL(string: session.provider.baseURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = baseTimeout

            let messages: [[String: Any]] = [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": formattedText]
            ]

            var requestBody: [String: Any] = [
                "model": session.model,
                "messages": messages,
                "stream": false
            ]

            // gpt-5-mini 和 gpt-5-nano 不支持 temperature 参数
            let noTemperatureModels = ["gpt-5-mini", "gpt-5-nano"]
            if !noTemperatureModels.contains(session.model) {
                requestBody["temperature"] = 0.3
            }

            if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: session.model) {
                requestBody["reasoning_effort"] = reasoningEffort
            }

            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EnhancementError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = jsonResponse["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let message = firstChoice["message"] as? [String: Any],
                          let enhancedText = message["content"] as? String else {
                        throw EnhancementError.enhancementFailed
                    }

                    let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    return filteredText
                } else if httpResponse.statusCode == 429 {
                    throw EnhancementError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw EnhancementError.apiKeyInvalid
                } else if (500...599).contains(httpResponse.statusCode) {
                    throw EnhancementError.serverError
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                    throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
                }

            } catch let error as EnhancementError {
                throw error
            } catch let error as URLError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }
        }
    }

    fileprivate func makeBedrockRequest(systemMessage: String, userMessage: String, session: ActiveSession) async throws -> String {
        // Combine system message and user message into a single prompt
        let prompt = "\(systemMessage)\n\(userMessage)"
        
        // Build messages array according to Bedrock Converse API format
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["text": prompt]
                ]
            ]
        ]
        
        // Build payload - note: modelId is NOT included in the payload body
        let payload: [String: Any] = [
            "messages": messages,
            "inferenceConfig": [
                "maxTokens": 1024,
                "temperature": 0.3
            ]
        ]
        
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        var region = session.region ?? aiService.bedrockRegion
        switch session.auth {
        case .bedrockSigV4(_, let regionOverride):
            if !regionOverride.isEmpty {
                region = regionOverride
            }
        case .bedrockBearer(_, let regionOverride):
            if !regionOverride.isEmpty {
                region = regionOverride
            }
        default:
            break
        }
        let modelId = session.model
        guard !modelId.isEmpty else {
            throw EnhancementError.notConfigured
        }
        
        // Determine authentication method and build request
        guard !region.isEmpty else { throw EnhancementError.notConfigured }
        let host = "bedrock-runtime.\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/model/\(modelId)/converse") else {
            throw EnhancementError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = baseTimeout

        switch session.auth {
        case .bedrockSigV4(let credentials, _):
            request = try AWSSigV4Signer.sign(
                request: request,
                credentials: credentials,
                region: region,
                service: "bedrock-runtime"
            )
        case .bedrockBearer(let token, _):
            guard !token.isEmpty else { throw EnhancementError.notConfigured }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .bearer(let token):
            guard !token.isEmpty else { throw EnhancementError.notConfigured }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        default:
            throw EnhancementError.notConfigured
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                if let result = Self.parseBedrockResponse(data: data) {
                    return AIEnhancementOutputFilter.filter(result.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    throw EnhancementError.enhancementFailed
                }
            } else if httpResponse.statusCode == 429 {
                throw EnhancementError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw EnhancementError.apiKeyInvalid
            } else if (500...599).contains(httpResponse.statusCode) {
                throw EnhancementError.serverError
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
            }
        } catch let error as EnhancementError {
            throw error
        } catch {
            throw EnhancementError.customError(error.localizedDescription)
        }
    }
    
    private static func parseBedrockResponse(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // If JSON parsing fails, try returning as string
            return String(data: data, encoding: .utf8)
        }
        
        // Parse Bedrock Converse API response format:
        // {"output": {"message": {"content": [{"text": "..."}], "role": "assistant"}}, ...}
        // GPT-OSS format: {"content": [{"reasoningContent": {...}}, {"text": "final answer"}]}
        if let output = json["output"] as? [String: Any],
           let message = output["message"] as? [String: Any],
           let content = message["content"] as? [[String: Any]] {
            
            // First pass: look for direct "text" field (final answer, not reasoning)
            for contentItem in content {
                if let text = contentItem["text"] as? String {
                    return text
                }
            }
            
            // Second pass: if no direct text found, check for reasoning content
            // (fallback for models that only return reasoning)
            for contentItem in content {
                if let reasoningContent = contentItem["reasoningContent"] as? [String: Any],
                   let reasoningText = reasoningContent["reasoningText"] as? [String: Any],
                   let text = reasoningText["text"] as? String {
                    return text
                }
            }
        }
        
        // Fallback: try other possible response formats
        if let text = json["output_text"] as? String { return text }
        if let text = json["outputText"] as? String { return text }
        if let text = json["completion"] as? String { return text }
        if let text = json["generated_text"] as? String { return text }
        
        if let outputs = json["outputs"] as? [[String: Any]] {
            if let first = outputs.first {
                if let text = first["text"] as? String { return text }
                if let text = first["output_text"] as? String { return text }
            }
        }
        
        return nil
    }

    func enhance(_ text: String) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()
        let enhancementPrompt: EnhancementPrompt = .transcriptionEnhancement
        let promptName = activePrompt?.title

        do {
            let result = try await makeRequest(text: text, mode: enhancementPrompt)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            return (result, duration, promptName)
        } catch {
            throw error
        }
    }

    func captureScreenContext() async {
        // Screen context capture is disabled in this fork.
    }

    func captureClipboardContext() {
        lastCapturedClipboard = NSPasteboard.general.string(forType: .string)
    }
    
    func clearCapturedContexts() {
        lastCapturedClipboard = nil
        screenCaptureService.lastCapturedText = nil
    }
}
