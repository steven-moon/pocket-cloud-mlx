import Foundation

#if canImport(CoreImage)
import CoreImage
#endif

public struct VisionLanguageResult: Sendable {
    public let text: String
    public let prompt: String
    public let modelId: String
    public let duration: TimeInterval
    public let tokensPerSecond: Double?
    public let tokenCount: Int?

    public init(
        text: String,
        prompt: String,
        modelId: String,
        duration: TimeInterval,
        tokensPerSecond: Double? = nil,
        tokenCount: Int? = nil
    ) {
        self.text = text
        self.prompt = prompt
        self.modelId = modelId
        self.duration = duration
        self.tokensPerSecond = tokensPerSecond
        self.tokenCount = tokenCount
    }
}

public enum VisionLanguageError: LocalizedError {
    case imageDataUnavailable
    case unsupportedImage
    case featureUnavailable

    public var errorDescription: String? {
        switch self {
        case .imageDataUnavailable:
            return "Unable to access image data for analysis."
        case .unsupportedImage:
            return "The selected file could not be decoded as an image."
        case .featureUnavailable:
            return "Vision-language analysis is not available in this build."
        }
    }
}

#if canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLX) && canImport(CoreImage)
import CoreGraphics
import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXVLM
import PocketCloudLogger

/// High-level facade that wraps MLX's VLM infrastructure for image + prompt analysis.
public actor VisionLanguageEngine {
    public static let shared = VisionLanguageEngine()

    private let logger = Logger(label: "VisionLanguageEngine")
    private var containers: [String: ModelContainer] = [:]

    private let defaultSystemPrompt = "You are an image understanding model capable of describing the salient features of any image."
    private let defaultResize = CGSize(width: 448, height: 448)

    private struct SessionContext {
        let hubId: String
        let model: ModelConfiguration?
        let configuration: MLXLMCommon.ModelConfiguration
        let session: MLXLMCommon.ChatSession

        var fallbackPrompt: String {
            if let model, let systemPrompt = model.defaultSystemPrompt {
                return systemPrompt
            }
            return configuration.defaultPrompt
        }
    }

    public init() {}

    /// Run vision language inference using raw image data.
    public func describeImage(
        data: Data,
        prompt: String?,
        model: ModelConfiguration? = nil
    ) async throws -> VisionLanguageResult {
        try await describeImageInternal(data: data, prompt: prompt, model: model)
    }

    /// Run vision language inference using an image URL.
    public func describeImage(
        url: URL,
        prompt: String?,
        model: ModelConfiguration? = nil
    ) async throws -> VisionLanguageResult {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            throw VisionLanguageError.imageDataUnavailable
        }
        return try await describeImageInternal(data: data, prompt: prompt, model: model)
    }

    /// Run text-only generation using the multimodal session.
    public func generateText(
        prompt: String,
        model: ModelConfiguration? = nil
    ) async throws -> VisionLanguageResult {
        let sanitizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = try await resolveSessionContext(for: model)
        let resolvedPrompt = sanitizedPrompt.isEmpty ? context.fallbackPrompt : sanitizedPrompt

        logger.info("Starting VLM text generation", context: Logger.Context([
            "modelId": context.hubId,
            "promptLength": "\(resolvedPrompt.count)"
        ]))

        MLXRandom.seed(UInt64(Date().timeIntervalSinceReferenceDate * 1000))
        let start = Date()
        let response = try await context.session.respond(to: resolvedPrompt, image: nil)
        let duration = Date().timeIntervalSince(start)

        logger.info("Completed VLM text generation", context: Logger.Context([
            "modelId": context.hubId,
            "durationMs": "\(Int(duration * 1000))"
        ]))

        return VisionLanguageResult(
            text: response,
            prompt: resolvedPrompt,
            modelId: context.hubId,
            duration: duration
        )
    }

    /// Warm the underlying MLX session so the next request avoids cold starts.
    public func prepareSession(for model: ModelConfiguration? = nil) async throws {
        _ = try await resolveSessionContext(for: model)
    }

    // MARK: - Core Implementation

    private func describeImageInternal(
        data: Data,
        prompt: String?,
        model: ModelConfiguration?
    ) async throws -> VisionLanguageResult {
        let ciImage = try makeCIImage(from: data)
        let context = try await resolveSessionContext(for: model)

        let resolvedPrompt: String
        if let userPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !userPrompt.isEmpty {
            resolvedPrompt = userPrompt
        } else {
            resolvedPrompt = context.fallbackPrompt
        }

        logger.info("Starting VLM inference", context: Logger.Context([
            "modelId": context.hubId,
            "promptLength": "\(resolvedPrompt.count)"
        ]))

        MLXRandom.seed(UInt64(Date().timeIntervalSinceReferenceDate * 1000))
        let start = Date()
        let response = try await context.session.respond(
            to: resolvedPrompt,
            image: MLXLMCommon.UserInput.Image.ciImage(ciImage)
        )
        let duration = Date().timeIntervalSince(start)

        logger.info("Completed VLM inference", context: Logger.Context([
            "modelId": context.hubId,
            "durationMs": "\(Int(duration * 1000))"
        ]))

        return VisionLanguageResult(
            text: response,
            prompt: resolvedPrompt,
            modelId: context.hubId,
            duration: duration
        )
    }

    // MARK: - Loading Helpers

    private func resolveSessionContext(for model: ModelConfiguration?) async throws -> SessionContext {
        let targetModel = model ?? ModelRegistry.defaultModel(for: .vlm)
        let hubId = targetModel?.hubId ?? VLMRegistry.qwen2VL2BInstruct4Bit.name

        let configuration = resolveConfiguration(for: hubId)
        let container = try await loadContainer(for: hubId, configuration: configuration)
    let session = loadSession(for: hubId, container: container)

        return SessionContext(
            hubId: hubId,
            model: targetModel,
            configuration: configuration,
            session: session
        )
    }

    private func loadContainer(
        for hubId: String,
        configuration: MLXLMCommon.ModelConfiguration
    ) async throws -> ModelContainer {
        if let cached = containers[hubId] {
            return cached
        }

        logger.info("Loading VLM container", context: Logger.Context(["modelId": hubId]))
        let container = try await VLMModelFactory.shared.loadContainer(configuration: configuration) { progress in
            AppLogger.shared.info("VisionLanguageEngine", "Downloading VLM", context: [
                "model": hubId,
                "fraction": String(format: "%.2f", progress.fractionCompleted)
            ])
        }
        containers[hubId] = container
        return container
    }

    private func loadSession(
        for hubId: String,
        container: ModelContainer
    ) -> MLXLMCommon.ChatSession {
        let processing = MLXLMCommon.UserInput.Processing(resize: defaultResize)
        let session = MLXLMCommon.ChatSession(
            container,
            instructions: defaultSystemPrompt,
            generateParameters: MLXLMCommon.GenerateParameters(maxTokens: 800, temperature: 0.7, topP: 0.9),
            processing: processing
        )
        return session
    }

    private func resolveConfiguration(for hubId: String) -> MLXLMCommon.ModelConfiguration {
        if VLMRegistry.shared.contains(id: hubId) {
            return VLMRegistry.shared.configuration(id: hubId)
        }
        logger.warning("Falling back to ad-hoc configuration for VLM", context: Logger.Context(["modelId": hubId]))
        return MLXLMCommon.ModelConfiguration(id: hubId)
    }

    private func makeCIImage(from data: Data) throws -> CIImage {
        guard let image = CIImage(data: data) else {
            throw VisionLanguageError.unsupportedImage
        }
        return image
    }
}
#else
/// Stub implementation used when MLXVLM is not available for the current build configuration.
public actor VisionLanguageEngine {
    public static let shared = VisionLanguageEngine()

    public init() {}

    public func describeImage(
        data: Data,
        prompt: String?,
        model: ModelConfiguration? = nil
    ) async throws -> VisionLanguageResult {
        throw VisionLanguageError.featureUnavailable
    }

    public func describeImage(
        url: URL,
        prompt: String?,
        model: ModelConfiguration? = nil
    ) async throws -> VisionLanguageResult {
        throw VisionLanguageError.featureUnavailable
    }

    public func generateText(
        prompt: String,
        model: ModelConfiguration? = nil
    ) async throws -> VisionLanguageResult {
        throw VisionLanguageError.featureUnavailable
    }

    public func prepareSession(for model: ModelConfiguration? = nil) async throws {
        throw VisionLanguageError.featureUnavailable
    }
}
#endif
