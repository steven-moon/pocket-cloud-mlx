// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/InferenceEngine.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct InferenceMetrics: Sendable, Codable {
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/Inference/InferenceEngineFeatures.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/Inference/InferenceEngineErrors.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/Inference/InferenceEngineTypes.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import PocketCloudLogger

#if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
  import MLX
  import MLXLLM
  import MLXLMCommon
#endif

/// Performance metrics for inference operations
public struct InferenceMetrics: Sendable, Codable {
  public let modelLoadTime: TimeInterval
  public let lastGenerationTime: TimeInterval
  public let tokensGenerated: Int
  public let tokensPerSecond: Double
  public let memoryUsageBytes: Int
  public let gpuMemoryUsageBytes: Int?
  public let timestamp: Date
  public let cacheHitRate: Double
  public let isModelWarmed: Bool
  public let queueLength: Int

  public init(
    modelLoadTime: TimeInterval = 0,
    lastGenerationTime: TimeInterval = 0,
    tokensGenerated: Int = 0,
    tokensPerSecond: Double = 0,
    memoryUsageBytes: Int = 0,
    gpuMemoryUsageBytes: Int? = nil,
    timestamp: Date = Date(),
    cacheHitRate: Double = 0.0,
    isModelWarmed: Bool = false,
    queueLength: Int = 0
  ) {
    self.modelLoadTime = modelLoadTime
    self.lastGenerationTime = lastGenerationTime
    self.tokensGenerated = tokensGenerated
    self.tokensPerSecond = tokensPerSecond
    self.memoryUsageBytes = memoryUsageBytes
    self.gpuMemoryUsageBytes = gpuMemoryUsageBytes
    self.timestamp = timestamp
    self.cacheHitRate = cacheHitRate
    self.isModelWarmed = isModelWarmed
    self.queueLength = queueLength
  }
}



/// Simplified inference engine facade that follows Apple's MLXChatExample pattern
/// Provides a clean interface for text generation using MLX models
public final class InferenceEngineFacade: @unchecked Sendable {
  // MARK: - Properties

  /// The MLX service that handles actual model operations
  private let mlxService = MLXService()

  /// Model configuration for this engine instance
  public let config: ModelConfiguration

  /// Logger for this engine
  private let logger = Logger(label: "InferenceEngineFacade")

  /// Performance metrics
  public private(set) var metrics = InferenceMetrics()

  /// Whether the engine has been unloaded
  public private(set) var isUnloaded = false

  // MARK: - Initialization

  /// Initialize with a model configuration
  /// - Parameter config: The model configuration to use
  public init(config: ModelConfiguration) {
    self.config = config
    logger.info("🚀 InferenceEngineFacade initialized for model: \(config.name)")
  }
  
  // MARK: - Public Methods

  /// Generate text from a prompt using one-shot completion
  /// - Parameters:
  ///   - prompt: The input prompt
  ///   - parameters: Generation parameters (optional)
  /// - Returns: Generated text response
  /// - Throws: Generation errors
  public func generate(_ prompt: String, params: GenerateParams = .init()) async throws -> String {
    guard !isUnloaded else {
      throw NSError(domain: "InferenceEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Engine is unloaded"])
    }

    logger.info("🚀 Generating response for prompt: \(prompt.prefix(50))...")

    // Convert prompt to chat messages
    let messages = [
      ChatMessage(role: .system, content: "You are a helpful assistant."),
      ChatMessage(role: .user, content: prompt)
    ]

    // Convert ModelConfiguration to MLX configuration with model type detection
    let mlxConfig = MLXLMCommon.ModelConfiguration(id: config.hubId)

    // Detect model architecture for proper loading
    let modelArchitecture = detectModelArchitecture(from: config)
    logger.info("🎯 InferenceEngine detected model architecture: \(modelArchitecture ?? "unknown") for \(config.hubId)")

    // Generate using MLX service
    logger.info("🔍 InferenceEngine about to call mlxService.generate() with config: \(mlxConfig.id)")
    let stream = try await mlxService.generate(messages: messages, configuration: mlxConfig)

    // Collect all chunks into a single response
    var fullResponse = ""
    for try await chunk in stream {
      fullResponse += chunk
    }

    logger.info("✅ Generation completed successfully")
    return fullResponse
  }

  /// Generate text from a prompt using streaming completion
  /// - Parameters:
  ///   - prompt: The input prompt
  ///   - parameters: Generation parameters (optional)
  /// - Returns: Async stream of generated text chunks
  /// - Throws: Generation errors
  public func stream(_ prompt: String, params: GenerateParams = .init()) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          guard !self.isUnloaded else {
            continuation.finish(throwing: NSError(domain: "InferenceEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Engine is unloaded"]))
            return
          }

          self.logger.info("🌊 Starting streaming generation for prompt: \(prompt.prefix(50))...")
          self.logger.info("🔍 InferenceEngine.stream() - Current working directory: \(FileManager.default.currentDirectoryPath)")
          self.logger.info("🔍 InferenceEngine.stream() - Home directory: \(FileManager.default.mlxUserHomeDirectory.path)")

          // Convert prompt to chat messages
          let messages = [
            ChatMessage(role: .system, content: "You are a helpful assistant."),
            ChatMessage(role: .user, content: prompt)
          ]

          // Convert ModelConfiguration to MLX configuration with model type detection
          let mlxConfig = MLXLMCommon.ModelConfiguration(id: self.config.hubId)
          self.logger.info("🔍 InferenceEngine.stream() - Created MLX config with ID: \(mlxConfig.id)")

          // Detect model architecture for proper loading
          let modelArchitecture = self.detectModelArchitecture(from: self.config)
          self.logger.info("🎯 InferenceEngine streaming detected model architecture: \(modelArchitecture ?? "unknown") for \(self.config.hubId)")

          // Generate using MLX service
          print("🔍 DEBUG: InferenceEngine.stream() about to call mlxService.generate() with config: \(mlxConfig.id)")
          self.logger.info("🔍 InferenceEngine.stream() about to call mlxService.generate() with config: \(mlxConfig.id)")
          let stream = try await self.mlxService.generate(messages: messages, configuration: mlxConfig)

          // Stream chunks to continuation
          for try await chunk in stream {
            if Task.isCancelled {
              self.logger.info("⚠️ InferenceEngine stream cancelled")
              break
            }
            continuation.yield(chunk)
          }

          if Task.isCancelled {
            continuation.finish()
            return
          }

          continuation.finish()
          self.logger.info("✅ Streaming generation completed successfully")
        } catch {
          if (error as? CancellationError) != nil {
            self.logger.info("⚠️ InferenceEngine stream cancelled with error")
            continuation.finish()
            return
          }
          self.logger.error("❌ Streaming failed: \(error.localizedDescription)")
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }

  /// Unload the model and free resources
  public func unload() {
    logger.info("✅ Engine unloaded - model: \(config.name)")
    mlxService.unloadAllModels()
    isUnloaded = true
  }

  /// Detect model architecture from configuration
  /// - Parameter config: The model configuration
  /// - Returns: Detected model architecture type
  private func detectModelArchitecture(from config: ModelConfiguration) -> String? {
    let modelId = config.hubId.lowercased()

    // Check for Qwen models
    if modelId.contains("qwen") {
      return "qwen2"
    }

    // Check for Llama models
    if modelId.contains("llama") {
      return "llama"
    }

    // Check for Mistral models
    if modelId.contains("mistral") {
      return "mistral"
    }

    // Check for Phi models
    if modelId.contains("phi") {
      return "phi"
    }

    // Check for Gemma models
    if modelId.contains("gemma") {
      return "gemma"
    }

    // Default fallback
    return nil
  }

  /// Load a model with the specified configuration (static factory method)
  /// - Parameters:
  ///   - config: The model configuration to load
  ///   - progress: Progress callback for model loading
  /// - Returns: A new InferenceEngineFacade instance
  /// - Throws: Model loading errors
  public static func loadModel(
    _ config: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void
  ) async throws -> Self {
    AppLogger.shared.info("InferenceEngineFacade", "🚀 Loading MLX model", context: ["model": config.name, "hubId": config.hubId])

    // Simple factory method - just create the instance
    // The actual model loading happens lazily when generate() is called
    return Self(config: config)
  }

  // MARK: - Advanced Feature Stubs (Not Implemented)

  /// Load LoRA adapter (not supported in basic version)
  public func loadLoRAAdapter(from url: URL) async throws {
    throw PocketCloudMLXError.featureNotSupported("LoRA adapters are not supported in the basic inference engine")
  }

  /// Apply LoRA adapter (not supported in basic version)
  public func applyLoRAAdapter(named name: String) throws {
    throw PocketCloudMLXError.featureNotSupported("LoRA adapters are not supported in the basic inference engine")
  }

  /// Load quantization (not supported in basic version)
  public func loadQuantization(_ quantization: String) async throws {
    throw PocketCloudMLXError.featureNotSupported("Quantization loading is not supported in the basic inference engine")
  }

  /// Load vision language model (not supported in basic version)
  public func loadVisionLanguageModel() async throws {
    throw PocketCloudMLXError.featureNotSupported("Vision language models are not supported in the basic inference engine")
  }

  /// Load embedding model (not supported in basic version)
  public func loadEmbeddingModel() async throws {
    throw PocketCloudMLXError.featureNotSupported("Embedding models are not supported in the basic inference engine")
  }

  /// Load diffusion model (not supported in basic version)
  public func loadDiffusionModel() async throws {
    throw PocketCloudMLXError.featureNotSupported("Diffusion models are not supported in the basic inference engine")
  }

  /// Set custom prompt (not supported in basic version)
  public func setCustomPrompt(_ prompt: String) throws {
    throw PocketCloudMLXError.featureNotSupported("Custom prompts are not supported in the basic inference engine")
  }

  /// Load multi-modal input (not supported in basic version)
  public func loadMultiModalInput() async throws {
    throw PocketCloudMLXError.featureNotSupported("Multi-modal input is not supported in the basic inference engine")
  }

  /// Generate image (not supported in basic version)
  public func generateImage(from prompt: String, params: GenerateParams = .init()) async throws -> Data {
    throw PocketCloudMLXError.featureNotSupported("Image generation is not supported in the basic inference engine")
  }

  /// Generate with multi-modal input (not supported in basic version)
  public func generateWithMultiModalInput(_ input: MultiModalInput) async throws -> String {
    throw PocketCloudMLXError.featureNotSupported("Multi-modal generation is not supported in the basic inference engine")
  }

  /// Search with embeddings (not implemented in basic version)
  public func searchWithEmbeddings(query: String, in documents: [String]) async throws -> [String] {
    AppLogger.shared.info("InferenceEngineFacade", "Semantic search not implemented in basic version", context: ["model": config.name])
    return ["Semantic search is not available in the current version."]
  }

  /// Get engine status (not supported in basic version)
  public var status: EngineStatus {
    // Return a basic status since we don't track detailed metrics
    return EngineStatus(
      isModelLoaded: !isUnloaded,
      mlxAvailable: false, // We'll determine this dynamically
      modelConfiguration: config,
      memoryUsageBytes: 0,
      gpuMemoryUsageBytes: nil
    )
  }

  /// Get engine health (not supported in basic version)
  public var health: EngineHealth {
    return isUnloaded ? .unhealthy : .healthy
  }
}

// MARK: - Error Types

/// Error types for MLX Engine operations
public enum PocketCloudMLXError: LocalizedError {
  case featureNotSupported(String)
  case mlxNotAvailable(String)
  case generationFailed(String)
  case modelLoadingFailed(String)
  case modelNotFound(String)

  public var errorDescription: String? {
    switch self {
    case .featureNotSupported(let message):
      return "Feature not supported: \(message)"
    case .mlxNotAvailable(let message):
      return "MLX not available: \(message)"
    case .generationFailed(let message):
      return "Generation failed: \(message)"
    case .modelLoadingFailed(let message):
      return "Model loading failed: \(message)"
    case .modelNotFound(let message):
      return "Model not found: \(message)"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .modelNotFound:
      return "Check if the model file exists and try downloading it again."
    case .modelLoadingFailed:
      return "Verify the model format is compatible and try a different model."
    case .generationFailed:
      return "Try reducing the generation parameters or use a smaller model."
    case .featureNotSupported:
      return "Check the model capabilities and try a different operation."
    case .mlxNotAvailable:
      return "Ensure MLX framework is properly installed."
    }
  }
}

// MARK: - Supporting Types for Advanced Features

/// Multi-modal input structure (stub)
public struct MultiModalInput {
  public let text: String
  public let imageData: Data?
  public let imageURL: URL?

  public init(text: String, imageData: Data? = nil, imageURL: URL? = nil) {
    self.text = text
    self.imageData = imageData
    self.imageURL = imageURL
  }

  public static func text(_ text: String) -> MultiModalInput {
    return MultiModalInput(text: text)
  }
}

// MARK: - Public Type Alias
/// Main inference engine type - provides backward compatibility
public typealias InferenceEngine = InferenceEngineFacade
