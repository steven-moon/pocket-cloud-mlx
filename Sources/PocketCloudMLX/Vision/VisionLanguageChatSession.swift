import Foundation
import PocketCloudLogger

#if canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLX)

/// ChatSessionProtocol bridge that reuses the multimodal engine for text chat.
public final class VisionLanguageChatSession: @unchecked Sendable, ChatSessionProtocol {
    private let logger = Logger(label: "VisionLanguageChatSession")
    private let modelConfiguration: ModelConfiguration
    private let engine: VisionLanguageEngine

    private init(modelConfiguration: ModelConfiguration, engine: VisionLanguageEngine) {
        self.modelConfiguration = modelConfiguration
        self.engine = engine
    }

    /// Prepares a vision-language session for chat interactions.
    public static func create(
        modelConfiguration: ModelConfiguration,
        engine: VisionLanguageEngine = .shared
    ) async throws -> VisionLanguageChatSession {
        let session = VisionLanguageChatSession(modelConfiguration: modelConfiguration, engine: engine)
        try await session.initialize()
        return session
    }

    private func initialize() async throws {
        logger.info("Preparing VLM chat session", context: Logger.Context([
            "modelId": modelConfiguration.hubId
        ]))
        try await engine.prepareSession(for: modelConfiguration)
    }

    public func generateResponse(_ prompt: String) async throws -> String {
        let result = try await engine.generateText(prompt: prompt, model: modelConfiguration)
        return result.text
    }

    public func generateStream(
        prompt: String,
        parameters: GenerateParams
    ) async throws -> AsyncThrowingStream<String, any Error> {
        _ = parameters
        try await engine.prepareSession(for: modelConfiguration)
        let engine = self.engine
        let configuration = modelConfiguration

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await engine.generateText(prompt: prompt, model: configuration)
                    continuation.yield(result.text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func close() {
        logger.info("VisionLanguageChatSession closed", context: Logger.Context([
            "modelId": modelConfiguration.hubId
        ]))
    }
}

#else

/// Stubbed chat session used when the MLXVLM frameworks are unavailable.
public final class VisionLanguageChatSession: ChatSessionProtocol {
    private let logger = Logger(label: "VisionLanguageChatSession")

    public init() {}

    public static func create(
        modelConfiguration: ModelConfiguration,
        engine: VisionLanguageEngine = .shared
    ) async throws -> VisionLanguageChatSession {
        throw VisionLanguageError.featureUnavailable
    }

    public func generateResponse(_ prompt: String) async throws -> String {
        logger.error("VisionLanguageChatSession unavailable: MLXVLM not present")
        throw VisionLanguageError.featureUnavailable
    }

    public func generateStream(
        prompt: String,
        parameters: GenerateParams
    ) async throws -> AsyncThrowingStream<String, any Error> {
        _ = (prompt, parameters)
        throw VisionLanguageError.featureUnavailable
    }

    public func close() {
        logger.info("VisionLanguageChatSession closed (stub)")
    }
}

#endif
