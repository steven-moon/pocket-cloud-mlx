// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/ChatOperations.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ChatOperations {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):

//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import PocketCloudLogger
import PocketCloudMLX

struct GenerationMetrics: Equatable {
    let modelHubId: String
    let modelName: String
    let estimatedTokenCount: Int
    let elapsed: TimeInterval

    var tokensPerSecond: Double {
        guard elapsed > 0, estimatedTokenCount > 0 else { return 0 }
        return Double(estimatedTokenCount) / elapsed
    }

    var shortModelName: String {
        if let last = modelHubId.split(separator: "/").last {
            return String(last)
        }
        return modelName
    }

    func performanceInfo() -> ChatMessage.PerformanceInfo {
        ChatMessage.PerformanceInfo(
            modelId: modelHubId,
            modelName: modelName,
            tokensPerSecond: tokensPerSecond,
            tokenCount: estimatedTokenCount,
            generationDuration: elapsed
        )
    }
}

/// Handles chat operations including message sending, streaming, and regeneration
@MainActor
final class ChatOperations {

    // Dependencies
    private var chatSessionManager: ChatSessionManager { ChatSessionManager.shared }

    // State that this component manages
    private var messages: [ChatMessage] = []
    private var isGenerating: Bool = false
    private var streamingText: String = ""
    private var errorMessage: String?
    private var currentGenerationTask: Task<Void, Never>?

    // Callbacks for UI updates
    var onMessagesUpdated: (([ChatMessage]) -> Void)?
    var onGenerationStateChanged: ((Bool) -> Void)?
    var onStreamingTextUpdated: ((String) -> Void)?
    var onErrorMessageUpdated: ((String?) -> Void)?
    var onStreamingMetricsUpdated: ((ChatMessage.PerformanceInfo?) -> Void)?

    init() {}

    private func estimateTokenCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let whitespaceTokens = text.split { $0.isWhitespace }.count
        let punctuationTokens = text.filter { ".!?;:".contains($0) }.count
        let charEstimate = Int((Double(text.count) / 4.0).rounded(.up))
        let combined = max(whitespaceTokens + punctuationTokens / 4, charEstimate)
        return max(combined, 1)
    }

    private func emitMetrics(_ metrics: GenerationMetrics) {
        onStreamingMetricsUpdated?(metrics.performanceInfo())
    }

    private func clearMetrics() {
        onStreamingMetricsUpdated?(nil)
    }

    private func updateAssistantMessage(
        at index: Int,
        content: String,
        originalTimestamp: Date,
        performance: ChatMessage.PerformanceInfo?
    ) {
        let previousId = messages[index].id
        messages[index] = ChatMessage(
            id: previousId,
            role: .assistant,
            content: content,
            timestamp: originalTimestamp,
            performance: performance
        )
        onMessagesUpdated?(messages)
    }

    // MARK: - Message Sending

    func sendMessage(text: String, selectedModel: ModelConfiguration?) async {
        let messageText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !messageText.isEmpty, !isGenerating else {
            // Removed debug logging for cancelled send - too verbose
            return
        }

        AppLogger.shared.info("ChatOperations", "Starting message send with text length: \(messageText.count) characters")
        log("SEND_START", ["text": messageText.prefix(50).description])

        // Clear input and add user message
        messages.append(ChatMessage(role: .user, content: messageText, timestamp: Date()))

        // Check if model is selected and available
        guard let model = selectedModel else {
            let errorMsg = "🤖 No model selected. Please select a model from the dropdown first."
            let errorMessage = ChatMessage(role: .assistant, content: errorMsg, timestamp: Date())
            messages.append(errorMessage)
            log("SEND_ERROR", ["reason": "no_model_selected"])
            clearMetrics()
            return
        }

        log("SEND_MODEL", ["model": model.hubId])

        // Add placeholder for assistant message
        let assistantMessage = ChatMessage(role: .assistant, content: "", timestamp: Date())
        messages.append(assistantMessage)
        onMessagesUpdated?(messages)

        currentGenerationTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performGeneration(with: messageText, model: model)
            await MainActor.run {
                self.currentGenerationTask = nil
            }
        }
        currentGenerationTask = task
        await task.value
    }

    private func performGeneration(with messageText: String, model: ModelConfiguration) async {
        do {
            var fullResponse = ""
            let generationStart = Date()

            // Ensure we have a valid chat session - use the manager to prevent race conditions
            _ = chatSessionManager.getCurrentSession()
            do {
                // Check if we already have a session for this model
                if chatSessionManager.getCurrentSession() != nil {
                    AppLogger.shared.info("ChatOperations", "✅ Using existing session for model: \(model.name)")
                    // Note: We can't directly assign ChatSessionProtocol to ChatSession
                    // This will need to be handled differently in the future
                } else {
                    AppLogger.shared.info("ChatOperations", "No compatible session available, initializing with \(model.name)")
                    log("INIT", [
                        "selected": model.hubId,
                        "downloaded": "yes" // Assumed since we got here
                    ])

                    // Use the session manager to get/create session
                    log("SESSION_CREATE_START", ["model": model.hubId])
                    _ = try await chatSessionManager.ensureSession(for: model)

                    log("SESSION_CREATE_SUCCESS", ["model": model.hubId])
                    AppLogger.shared.info("ChatOperations", "✅ Successfully initialized chat session with \(model.name)")
                    log("SESSION_READY", ["model": model.hubId])
                }
            } catch {
                AppLogger.shared.error("ChatOperations", "Failed to initialize chat session: \(error)")
                log("SESSION_ERROR", ["model": model.hubId, "error": error.localizedDescription])
                if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                    let originalTimestamp = messages[lastIndex].timestamp
                    updateAssistantMessage(
                        at: lastIndex,
                        content: "❌ Failed to initialize \(model.name): \(error.localizedDescription)",
                        originalTimestamp: originalTimestamp,
                        performance: nil
                    )
                }
                return
            }

            log("SESSION_READY_FOR_GENERATE", ["model": model.hubId])
            isGenerating = true
            onGenerationStateChanged?(isGenerating)

            log("STREAM_START", ["model": model.hubId, "prompt_length": String(messageText.count)])

            // Clear the placeholder message before streaming
            if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                let placeholderTimestamp = messages[lastIndex].timestamp
                updateAssistantMessage(
                    at: lastIndex,
                    content: "🤔 Thinking...",
                    originalTimestamp: placeholderTimestamp,
                    performance: nil
                )
            }

            emitMetrics(GenerationMetrics(
                modelHubId: model.hubId,
                modelName: model.name,
                estimatedTokenCount: 0,
                elapsed: 0
            ))

            if let sessionProtocol = chatSessionManager.getCurrentSession() {
                let stream = try await sessionProtocol.generateStream(prompt: messageText, parameters: GenerateParams())
                for try await chunk in stream {
                    if Task.isCancelled {
                        log("STREAM_CANCELLED", ["reason": "user_cancelled"])
                        break
                    }
                    log("STREAM_CHUNK", ["chunk_length": String(chunk.count), "chunk_preview": chunk.prefix(20).description])
                    fullResponse += chunk
                    streamingText = fullResponse
                    onStreamingTextUpdated?(streamingText)
                    let elapsed = Date().timeIntervalSince(generationStart)
                    let estimatedTokens = estimateTokenCount(for: fullResponse)
                    let metrics = GenerationMetrics(
                        modelHubId: model.hubId,
                        modelName: model.name,
                        estimatedTokenCount: estimatedTokens,
                        elapsed: elapsed
                    )
                    emitMetrics(metrics)

                    // Update the last message with streaming content
                    if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                        let originalTimestamp = messages[lastIndex].timestamp
                        updateAssistantMessage(
                            at: lastIndex,
                            content: fullResponse,
                            originalTimestamp: originalTimestamp,
                            performance: metrics.performanceInfo()
                        )
                    }
                }
            }

            if Task.isCancelled {
                isGenerating = false
                streamingText = ""
                onGenerationStateChanged?(isGenerating)
                onStreamingTextUpdated?(streamingText)
                clearMetrics()
                log("STREAM_STOPPED", ["chars": String(fullResponse.count)])
                return
            }

            log("STREAM_END", ["chars": String(fullResponse.count), "final_response": fullResponse.prefix(50).description])

            // Fallback: if stream yielded nothing, try non-streaming generate once
            if fullResponse.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                log("STREAM_EMPTY", ["model": model.hubId])
                do {
                    log("FALLBACK_START", ["model": model.hubId])
                    if let sessionProtocol = chatSessionManager.getCurrentSession() {
                        let fallback = try await sessionProtocol.generateResponse(messageText)
                        log("FALLBACK_SUCCESS", ["response_length": String(fallback.count), "response_preview": fallback.prefix(50).description])
                        let elapsed = Date().timeIntervalSince(generationStart)
                        let estimatedTokens = estimateTokenCount(for: fallback)
                        let metrics = GenerationMetrics(
                            modelHubId: model.hubId,
                            modelName: model.name,
                            estimatedTokenCount: estimatedTokens,
                            elapsed: elapsed
                        )
                        emitMetrics(metrics)
                        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                            let originalTimestamp = messages[lastIndex].timestamp
                            updateAssistantMessage(
                                at: lastIndex,
                                content: fallback,
                                originalTimestamp: originalTimestamp,
                                performance: metrics.performanceInfo()
                            )
                        }
                    } else {
                        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                            let originalTimestamp = messages[lastIndex].timestamp
                            updateAssistantMessage(
                                at: lastIndex,
                                content: "❌ No session available for fallback generation",
                                originalTimestamp: originalTimestamp,
                                performance: nil
                            )
                        }
                    }
                } catch {
                    log("FALLBACK_FAILED", ["error": error.localizedDescription])
                    // Replace placeholder with explicit error to avoid blank bubble
                    if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                        messages[lastIndex] = ChatMessage(
                            id: messages[lastIndex].id,
                            role: .assistant,
                            content: "❌ No response generated (stream empty). \(error.localizedDescription)",
                            timestamp: messages[lastIndex].timestamp
                        )
                        onMessagesUpdated?(messages)
                    }
                    throw error
                }
            }

            isGenerating = false
            streamingText = ""
            onGenerationStateChanged?(isGenerating)
            onStreamingTextUpdated?(streamingText)
            let finalElapsed = Date().timeIntervalSince(generationStart)
            let finalTokens = estimateTokenCount(for: fullResponse)
            let finalMetrics = GenerationMetrics(
                modelHubId: model.hubId,
                modelName: model.name,
                estimatedTokenCount: finalTokens,
                elapsed: finalElapsed
            )
            emitMetrics(finalMetrics)
            if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                let originalTimestamp = messages[lastIndex].timestamp
                updateAssistantMessage(
                    at: lastIndex,
                    content: fullResponse,
                    originalTimestamp: originalTimestamp,
                    performance: finalMetrics.performanceInfo()
                )
            }
            log("SEND_SUCCESS", ["final_chars": String(fullResponse.count)])
            AppLogger.shared.info("ChatOperations", "Generated response of \(fullResponse.count) characters")
            clearMetrics()

        } catch {
            if (error as? CancellationError) != nil {
                log("STREAM_CANCELLED_ERROR", ["reason": "user_cancelled"])
                isGenerating = false
                streamingText = ""
                onGenerationStateChanged?(isGenerating)
                onStreamingTextUpdated?(streamingText)
                clearMetrics()
                return
            }
            isGenerating = false
            streamingText = ""
            onGenerationStateChanged?(isGenerating)
            onStreamingTextUpdated?(streamingText)
            log("STREAM_FAIL", ["error": error.localizedDescription])

            // Replace the placeholder with error message
            if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                let errorMsg = "Sorry, I encountered an error: \(error.localizedDescription)"
                let originalTimestamp = messages[lastIndex].timestamp
                updateAssistantMessage(
                    at: lastIndex,
                    content: errorMsg,
                    originalTimestamp: originalTimestamp,
                    performance: nil
                )
            }

            AppLogger.shared.error("ChatOperations", "Generation failed: \(error.localizedDescription)")
            clearMetrics()
        }
    }

    // MARK: - Regeneration

    func regenerateLastResponse() {
        // Find the last assistant message and the user prompt that preceded it
        guard let lastMessageIndex = messages.lastIndex(where: { $0.role == .assistant }),
              lastMessageIndex > 0 else {
            AppLogger.shared.error("ChatOperations", "Cannot regenerate: no assistant message found or no preceding user message")
            return
        }

        // Find the user message that prompted this response
        var userPrompt = ""
        for i in stride(from: lastMessageIndex - 1, through: 0, by: -1) {
            if messages[i].role == .user {
                userPrompt = messages[i].content
                break
            }
        }

        guard !userPrompt.isEmpty else {
            AppLogger.shared.error("ChatOperations", "Cannot regenerate: no user prompt found")
            return
        }

        // Remove the current assistant response
        messages.remove(at: lastMessageIndex)

        // Add placeholder for new assistant message
        let assistantMessage = ChatMessage(role: .assistant, content: "", timestamp: Date())
        messages.append(assistantMessage)
        onMessagesUpdated?(messages)

        currentGenerationTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRegeneration(for: userPrompt)
            await MainActor.run {
                self.currentGenerationTask = nil
            }
        }
        currentGenerationTask = task
    }

    private func performRegeneration(for prompt: String) async {
        guard chatSessionManager.getCurrentSession() != nil else {
            AppLogger.shared.warning("ChatOperations", "No chat session available for regeneration")
            return
        }

        let activeModel = chatSessionManager.getCurrentModel()
        let generationStart = Date()

        isGenerating = true
        streamingText = ""
        onGenerationStateChanged?(isGenerating)
        onStreamingTextUpdated?(streamingText)

        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            let placeholderTimestamp = messages[lastIndex].timestamp
            updateAssistantMessage(
                at: lastIndex,
                content: "🤔 Thinking...",
                originalTimestamp: placeholderTimestamp,
                performance: nil
            )
        }

        if let model = activeModel {
            emitMetrics(GenerationMetrics(
                modelHubId: model.hubId,
                modelName: model.name,
                estimatedTokenCount: 0,
                elapsed: 0
            ))
        } else {
            clearMetrics()
        }

        do {
            var fullResponse = ""

            if let sessionProtocol = chatSessionManager.getCurrentSession() {
                let stream = try await sessionProtocol.generateStream(prompt: prompt, parameters: GenerateParams())
                for try await chunk in stream {
                    if Task.isCancelled {
                        AppLogger.shared.info("ChatOperations", "Regeneration cancelled")
                        break
                    }
                    fullResponse += chunk
                    streamingText = fullResponse
                    onStreamingTextUpdated?(streamingText)
                    if let model = activeModel {
                        let elapsed = Date().timeIntervalSince(generationStart)
                        let estimatedTokens = estimateTokenCount(for: fullResponse)
                        let metrics = GenerationMetrics(
                            modelHubId: model.hubId,
                            modelName: model.name,
                            estimatedTokenCount: estimatedTokens,
                            elapsed: elapsed
                        )
                        emitMetrics(metrics)
                        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                            let originalTimestamp = messages[lastIndex].timestamp
                            updateAssistantMessage(
                                at: lastIndex,
                                content: fullResponse,
                                originalTimestamp: originalTimestamp,
                                performance: metrics.performanceInfo()
                            )
                        }
                    }

                    // If we don't have model metadata, still update content without performance info
                    if activeModel == nil, let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                        let originalTimestamp = messages[lastIndex].timestamp
                        updateAssistantMessage(
                            at: lastIndex,
                            content: fullResponse,
                            originalTimestamp: originalTimestamp,
                            performance: nil
                        )
                    }
                }
            } else {
                AppLogger.shared.warning("ChatOperations", "No session available for streaming")
                fullResponse = "❌ No chat session available for streaming"
            }

            if Task.isCancelled {
                isGenerating = false
                streamingText = ""
                onGenerationStateChanged?(isGenerating)
                onStreamingTextUpdated?(streamingText)
                clearMetrics()
                return
            }

            if fullResponse.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                do {
                    if let sessionProtocol = chatSessionManager.getCurrentSession() {
                        let fallback = try await sessionProtocol.generateResponse(prompt)
                        fullResponse = fallback
                        let estimatedTokens = estimateTokenCount(for: fallback)
                        let elapsed = Date().timeIntervalSince(generationStart)
                        let metrics = activeModel.map {
                            GenerationMetrics(
                                modelHubId: $0.hubId,
                                modelName: $0.name,
                                estimatedTokenCount: estimatedTokens,
                                elapsed: elapsed
                            )
                        }
                        if let metrics { emitMetrics(metrics) }
                        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                            let originalTimestamp = messages[lastIndex].timestamp
                            updateAssistantMessage(
                                at: lastIndex,
                                content: fallback,
                                originalTimestamp: originalTimestamp,
                                performance: metrics?.performanceInfo()
                            )
                        }
                    } else {
                        fullResponse = "❌ No session available for fallback generation"
                        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                            let originalTimestamp = messages[lastIndex].timestamp
                            updateAssistantMessage(
                                at: lastIndex,
                                content: "❌ No session available for fallback generation",
                                originalTimestamp: originalTimestamp,
                                performance: nil
                            )
                        }
                    }
                } catch {
                    if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                        let originalTimestamp = messages[lastIndex].timestamp
                        updateAssistantMessage(
                            at: lastIndex,
                            content: "❌ No response generated (stream empty). \(error.localizedDescription)",
                            originalTimestamp: originalTimestamp,
                            performance: nil
                        )
                    }
                    throw error
                }
            }

            isGenerating = false
            streamingText = ""
            onGenerationStateChanged?(isGenerating)
            onStreamingTextUpdated?(streamingText)
            if let model = activeModel {
                let elapsed = Date().timeIntervalSince(generationStart)
                let tokens = estimateTokenCount(for: fullResponse)
                let metrics = GenerationMetrics(
                    modelHubId: model.hubId,
                    modelName: model.name,
                    estimatedTokenCount: tokens,
                    elapsed: elapsed
                )
                if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                    let originalTimestamp = messages[lastIndex].timestamp
                    updateAssistantMessage(
                        at: lastIndex,
                        content: fullResponse,
                        originalTimestamp: originalTimestamp,
                        performance: metrics.performanceInfo()
                    )
                }
                emitMetrics(metrics)
            }
            AppLogger.shared.info("ChatOperations", "Regenerated response of \(fullResponse.count) characters")
            clearMetrics()

        } catch {
            if (error as? CancellationError) != nil {
                isGenerating = false
                streamingText = ""
                onGenerationStateChanged?(isGenerating)
                onStreamingTextUpdated?(streamingText)
                clearMetrics()
                return
            }
            isGenerating = false
            streamingText = ""
            onGenerationStateChanged?(isGenerating)
            onStreamingTextUpdated?(streamingText)

            // Replace the placeholder with error message
            if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                let errorMsg = "Sorry, I encountered an error during regeneration: \(error.localizedDescription)"
                let originalTimestamp = messages[lastIndex].timestamp
                updateAssistantMessage(
                    at: lastIndex,
                    content: errorMsg,
                    originalTimestamp: originalTimestamp,
                    performance: nil
                )
            }

            AppLogger.shared.error("ChatOperations", "Regeneration failed: \(error.localizedDescription)")
            clearMetrics()
        }
    }

    // MARK: - Control

    func stopGeneration() {
        isGenerating = false
        streamingText = ""
        onGenerationStateChanged?(isGenerating)
        onStreamingTextUpdated?(streamingText)
        currentGenerationTask?.cancel()
        currentGenerationTask = nil
        clearMetrics()
    }

    // MARK: - State Management

    func getMessages() -> [ChatMessage] {
        return messages
    }

    func setMessages(_ newMessages: [ChatMessage]) {
        messages = newMessages
        onMessagesUpdated?(messages)
    }

    func clearMessages() {
        messages.removeAll()
        onMessagesUpdated?(messages)
    }

    func addMessage(role: MessageRole, content: String) {
        let message = ChatMessage(role: role, content: content, timestamp: Date())
        messages.append(message)
        onMessagesUpdated?(messages)
    }

    // MARK: - Message Properties

    /// Compatibility property for message count
    var messageCount: Int {
        return messages.count
    }

    /// Compatibility property for last message
    var lastMessage: ChatMessage? {
        return messages.last
    }

    /// Remove the last message if present
    func removeLastMessage() {
        _ = messages.popLast()
        onMessagesUpdated?(messages)
    }

    func getIsGenerating() -> Bool {
        return isGenerating
    }

    func getStreamingText() -> String {
        return streamingText
    }

    func setErrorMessage(_ message: String?) {
        errorMessage = message
        onErrorMessageUpdated?(errorMessage)
    }

    // MARK: - Legacy API

    // Legacy overload for tests calling sendMessage(_ prompt: String)
    func sendMessage(_ prompt: String) async {
        await sendMessage(text: prompt, selectedModel: .none)
    }

    private func log(_ event: String, _ kv: [String: String]) {
        let text = kv.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        // Forward to workspace Logger for unified capture
        AppLogger.shared.info("ChatOperations", "Event: \(event) - \(text)")
    }
}
