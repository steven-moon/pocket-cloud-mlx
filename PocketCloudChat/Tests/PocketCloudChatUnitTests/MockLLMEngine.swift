// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUnitTests/MockLLMEngine.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - enum MockLLMError: Error, LocalizedError {
//   - extension ChatMessage {
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
import PocketCloudMLX
import os.log

/// Mock LLM Engine for testing purposes
/// This class implements the LLMEngine protocol and provides mock responses for testing
public final class MockLLMEngine: LLMEngine {
    private let logger = os.Logger(subsystem: "com.mlxchatapp.tests", category: "MockLLMEngine")

    // MARK: - Mock Properties

    /// Whether to simulate errors during generation
    public var shouldThrowError: Bool = false

    /// Mock response text to return
    public var mockResponse: String = "This is a mock response from the LLM engine."

    /// Whether to simulate streaming responses
    public var shouldStream: Bool = true

    /// Delay before returning mock responses (in seconds)
    public var responseDelay: TimeInterval = 0.1

    // MARK: - Initialization

    public init() {
        logger.info("MockLLMEngine initialized")
    }

    // MARK: - LLMEngine Protocol Implementation

    /// Mock implementation of loadModel
    public static func loadModel(
        _ config: ModelConfiguration,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> MockLLMEngine {
        let logger = Logger(label: "MockLLMEngine.loadModel")

        logger.info("Mock loading model: \(config.name)")

        // Simulate loading progress
        for i in 0...10 {
            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000)) // 0.1 seconds
            let progressValue = Double(i) / 10.0
            progress(progressValue)
        }

        logger.info("Mock model loaded successfully")
        return MockLLMEngine()
    }

    /// Mock implementation of generate
    public func generate(_ prompt: String, params: GenerateParams) async throws -> String {
        logger.info("Mock generating response for prompt: \(prompt.prefix(50))...")

        // Simulate processing delay
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        // Throw error if configured to do so
        if shouldThrowError {
            throw MockLLMError.generationFailed("Mock generation error")
        }

        // Return mock response
        let response = "\(mockResponse) [Generated for: \(prompt.prefix(20))...]"
        logger.info("Mock generation complete")
        return response
    }

    /// Mock implementation of stream
    public func stream(_ prompt: String, params: GenerateParams) -> AsyncThrowingStream<String, Error> {
        logger.info("Mock streaming response for prompt: \(prompt.prefix(50))...")

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Throw error if configured to do so
                    if shouldThrowError {
                        throw MockLLMError.streamingFailed("Mock streaming error")
                    }

                    if shouldStream {
                        // Simulate streaming chunks
                        let words = mockResponse.split(separator: " ").map(String.init)
                        for (index, word) in words.enumerated() {
                            if responseDelay > 0 {
                                try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
                            }

                            continuation.yield(word + " ")

                            // Yield metadata for last chunk
                            if index == words.count - 1 {
                                continuation.yield("[END]")
                            }
                        }
                    } else {
                        // Single chunk response
                        if responseDelay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
                        }
                        continuation.yield(mockResponse)
                    }

                    continuation.finish()
                    logger.info("Mock streaming complete")

                } catch {
                    continuation.finish(throwing: error)
                    logger.error("Mock streaming failed: \(error)")
                }
            }
        }
    }

    /// Mock implementation of unload
    public func unload() {
        logger.info("Mock model unloaded")
    }
}

// MARK: - Mock Error Types

public enum MockLLMError: Error, LocalizedError {
    case generationFailed(String)
    case streamingFailed(String)
    case modelNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return "Mock generation failed: \(message)"
        case .streamingFailed(let message):
            return "Mock streaming failed: \(message)"
        case .modelNotFound(let modelId):
            return "Mock model not found: \(modelId)"
        }
    }
}

// MARK: - Supporting Types

/// Mock Chat Session for testing
public final class MockChatSession {
    private let logger = os.Logger(subsystem: "com.mlxchatapp.tests", category: "MockChatSession")

    public var messages: [ChatMessage] = []
    public var isActive: Bool = true

    public init() {
        logger.info("MockChatSession initialized")
    }

    public func generateResponse(_ prompt: String) async throws -> String {
        let response = "Mock response to: \(prompt)"
        logger.info("Generated mock response")
        return response
    }

    public func generateStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let words = "Mock streaming response to: \(prompt)".split(separator: " ").map(String.init)
                for word in words {
                    try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000)) // 0.05 seconds
                    continuation.yield(word + " ")
                }
                continuation.finish()
            }
        }
    }

    public func addMessage(_ message: ChatMessage) {
        messages.append(message)
        logger.info("Added message to mock session")
    }

    public func clearMessages() {
        messages.removeAll()
        logger.info("Cleared mock session messages")
    }
}

// MARK: - Chat Message Extension

extension ChatMessage {
    public static func mock(user content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content, timestamp: Date())
    }

    public static func mock(assistant content: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: content, timestamp: Date())
    }
}
