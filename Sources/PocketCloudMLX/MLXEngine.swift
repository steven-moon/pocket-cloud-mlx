// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/PocketCloudMLX.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModelConfiguration: Codable, Sendable {
//   - enum ModelType: String, CaseIterable, Codable, Sendable {
//   - struct GenerateParams: Codable, Sendable {
//   - struct ImageGenerationParams {
//   - enum LLMEngineFeatures: String, CaseIterable, Codable, Sendable {
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/MLXModelSearchUtility.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/DebugUtility.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/MLXService.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFace_Errors.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/OptimizedDownloader.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
//
// PocketCloudMLX.swift
//
// Usage Example:
//
// import PocketCloudMLX
//
// let config = ModelConfiguration(
//     name: "Qwen 0.5B Chat",
//     hubId: "mlx-community/Qwen1.5-0.5B-Chat-4bit",
//     description: "Qwen 0.5B Chat model (4-bit quantized)",
//     parameters: "0.5B",
//     quantization: "4bit",
//     architecture: "Qwen",
//     maxTokens: 4096
// )
//
// Task {
//     let engine = try await InferenceEngine.loadModel(config) { progress in
//         print("Loading progress: \(progress * 100)%")
//     }
//     let result = try await engine.generate("Hello, world!", params: .init())
//     print(result)
// }
//

import CommonCrypto
import Foundation
import PocketCloudLogger
import MLX
import MLXLLM
import MLXLMCommon
import Metal

// Using Logging module types directly



// MARK: - Core Types

/// Configuration for MLX-based models
public struct ModelConfiguration: Codable, Sendable {
  // MARK: - Supporting Types

  public enum LoadStrategy: String, Codable, Sendable {
    case automatic
    case preferLocal
    case forceRedownload
  }

  // MARK: - Core Fields
  public let name: String
  public let hubId: String
  public let description: String
  public var parameters: String?  // Optional
  public var quantization: String?  // Optional
  public var architecture: String?  // Optional
  public let maxTokens: Int
  public let estimatedSizeGB: Double?  // Optional
  public let defaultSystemPrompt: String?  // Optional
  public let endOfTextTokens: [String]?  // Optional
  // New/advanced fields
  public let modelType: ModelType
  public let gpuCacheLimit: Int
  public let features: Set<LLMEngineFeatures>
  // Download/engine metadata (legacy/test support)
  public var engineType: String?
  public var downloadURL: String?
  public var isDownloaded: Bool?
  public var localPath: String?
  public let loadStrategy: LoadStrategy

  private enum CodingKeys: String, CodingKey {
    case name
    case hubId
    case description
    case parameters
    case quantization
    case architecture
    case maxTokens
    case estimatedSizeGB
    case defaultSystemPrompt
    case endOfTextTokens
    case modelType
    case gpuCacheLimit
    case features
    case engineType
    case downloadURL
    case isDownloaded
    case localPath
    case loadStrategy
  }

  // MARK: - Main Initializer
  public init(
    name: String,
    hubId: String,
    description: String = "",
    parameters: String? = nil,
    quantization: String? = nil,
    architecture: String? = nil,
    maxTokens: Int = 1024,
    estimatedSizeGB: Double? = nil,
    defaultSystemPrompt: String? = nil,
    endOfTextTokens: [String]? = nil,
    modelType: ModelType = .llm,
    gpuCacheLimit: Int = 512 * 1024 * 1024,
    features: Set<LLMEngineFeatures> = [],
    engineType: String? = nil,
    downloadURL: String? = nil,
    isDownloaded: Bool? = nil,
    localPath: String? = nil,
    loadStrategy: LoadStrategy = .automatic
  ) {
  let normalizedHubId = Self.sanitizeHubId(hubId)

    self.name = name
    self.hubId = normalizedHubId
    self.description = description
    self.parameters = parameters
    self.quantization = quantization
    self.architecture = architecture
    self.maxTokens = maxTokens
    self.estimatedSizeGB = estimatedSizeGB
    self.defaultSystemPrompt = defaultSystemPrompt
    self.endOfTextTokens = endOfTextTokens
    self.modelType = modelType
    self.gpuCacheLimit = gpuCacheLimit
    self.features = features
    self.engineType = engineType
    self.downloadURL = downloadURL
    self.isDownloaded = isDownloaded
    self.localPath = localPath
    self.loadStrategy = loadStrategy
  }

  // MARK: - Legacy/Minimal Initializer for Backward Compatibility
  public init(
    name: String,
    hubId: String,
    description: String = "",
    maxTokens: Int = 1024,
    estimatedSizeGB: Double? = nil,
    defaultSystemPrompt: String? = nil
  ) {
    self.init(
      name: name,
      hubId: hubId,
      description: description,
      parameters: nil,
      quantization: nil,
      architecture: nil,
      maxTokens: maxTokens,
      estimatedSizeGB: estimatedSizeGB,
      defaultSystemPrompt: defaultSystemPrompt,
      endOfTextTokens: nil,
      modelType: .llm,
      gpuCacheLimit: 512 * 1024 * 1024,
      features: [],
      engineType: nil,
      downloadURL: nil,
      isDownloaded: nil,
      localPath: nil,
      loadStrategy: .automatic
    )
  }

  // MARK: - Computed Properties for Compatibility
  public var isSmallModel: Bool {
    if let params = parameters?.lowercased() {
      return params.contains("0.5b") || params.contains("1b") || params.contains("1.5b")
        || params.contains("2b") || params.contains("3b")
    }
    return false
  }
  public var displaySize: String {
    if let size = estimatedSizeGB {
      return String(format: "%.1f GB", size)
    }
    return "Unknown"
  }
  public var displayInfo: String {
    let arch = architecture ?? "?"
    let params = parameters ?? "?"
    let quant = quantization ?? "?"
    return "\(arch) • \(params) • \(quant)"
  }
  public var supportsVision: Bool {
    modelType == .vlm || features.contains(.visionLanguageModels)
  }
  public var supportsChat: Bool {
    switch modelType {
    case .llm:
      return true
    case .vlm:
      return features.contains(.multiModalInput)
    default:
      return false
    }
  }
  public var isVisionOnly: Bool {
    supportsVision && !supportsChat
  }
  public var estimatedMemoryGB: Double {
    estimatedSizeGB ?? 0.0
  }
  public var maxSequenceLength: Int { maxTokens }
  public var maxCacheSize: Int { gpuCacheLimit }
  // Add more helpers as needed

  public func withExtractedMetadata() -> ModelConfiguration {
    var newConfig = self
    newConfig.extractMetadataFromId()
    return newConfig
  }

  public var normalizedHubId: String { hubId }

  public static func normalizeHubId(_ raw: String) -> String {
    return Self.sanitizeHubId(raw)
  }

  private static func sanitizeHubId(_ hubId: String) -> String {
    var trimmed = hubId.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return trimmed }

    if trimmed.hasPrefix("models/") {
      trimmed.removeFirst("models/".count)
    }

    if let range = trimmed.range(of: "models--") {
      let components = trimmed[range.lowerBound...].split(separator: "/")
      if let firstComponent = components.first {
        let withoutPrefix = firstComponent.dropFirst("models--".count)
        let hubParts = withoutPrefix.split(separator: "--").map(String.init)
        if hubParts.count >= 2 {
          return "\(hubParts[0])/\(hubParts[1])"
        }
      }
    }

    if let snapshotsRange = trimmed.range(of: "snapshots/") {
      trimmed = String(trimmed[..<snapshotsRange.lowerBound])
    }

    if let blobsRange = trimmed.range(of: "blobs/") {
      trimmed = String(trimmed[..<blobsRange.lowerBound])
    }

    let pathComponents = trimmed.split(separator: "/").map(String.init)
    if pathComponents.count >= 2 {
      return "\(pathComponents[0])/\(pathComponents[1])"
    }

    return trimmed
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.name = try container.decode(String.self, forKey: .name)
    let rawHubId = try container.decode(String.self, forKey: .hubId)
    self.hubId = Self.sanitizeHubId(rawHubId)
    self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    self.parameters = try container.decodeIfPresent(String.self, forKey: .parameters)
    self.quantization = try container.decodeIfPresent(String.self, forKey: .quantization)
    self.architecture = try container.decodeIfPresent(String.self, forKey: .architecture)
    self.maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 1024
    self.estimatedSizeGB = try container.decodeIfPresent(Double.self, forKey: .estimatedSizeGB)
    self.defaultSystemPrompt = try container.decodeIfPresent(String.self, forKey: .defaultSystemPrompt)
    self.endOfTextTokens = try container.decodeIfPresent([String].self, forKey: .endOfTextTokens)
    self.modelType = try container.decodeIfPresent(ModelType.self, forKey: .modelType) ?? .llm
    self.gpuCacheLimit = try container.decodeIfPresent(Int.self, forKey: .gpuCacheLimit) ?? 512 * 1024 * 1024
    self.features = try container.decodeIfPresent(Set<LLMEngineFeatures>.self, forKey: .features) ?? []
    self.engineType = try container.decodeIfPresent(String.self, forKey: .engineType)
    self.downloadURL = try container.decodeIfPresent(String.self, forKey: .downloadURL)
    self.isDownloaded = try container.decodeIfPresent(Bool.self, forKey: .isDownloaded)
    self.localPath = try container.decodeIfPresent(String.self, forKey: .localPath)
    self.loadStrategy = try container.decodeIfPresent(LoadStrategy.self, forKey: .loadStrategy) ?? .automatic
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(hubId, forKey: .hubId)
    try container.encode(description, forKey: .description)
    try container.encodeIfPresent(parameters, forKey: .parameters)
    try container.encodeIfPresent(quantization, forKey: .quantization)
    try container.encodeIfPresent(architecture, forKey: .architecture)
    try container.encode(maxTokens, forKey: .maxTokens)
    try container.encodeIfPresent(estimatedSizeGB, forKey: .estimatedSizeGB)
    try container.encodeIfPresent(defaultSystemPrompt, forKey: .defaultSystemPrompt)
    try container.encodeIfPresent(endOfTextTokens, forKey: .endOfTextTokens)
    try container.encode(modelType, forKey: .modelType)
    try container.encode(gpuCacheLimit, forKey: .gpuCacheLimit)
    try container.encode(features, forKey: .features)
    try container.encodeIfPresent(engineType, forKey: .engineType)
    try container.encodeIfPresent(downloadURL, forKey: .downloadURL)
    try container.encodeIfPresent(isDownloaded, forKey: .isDownloaded)
    try container.encodeIfPresent(localPath, forKey: .localPath)
    try container.encode(loadStrategy, forKey: .loadStrategy)
  }

  public mutating func extractMetadataFromId() {
    let id = hubId.lowercased()

    // Extract architecture (e.g., Llama, Qwen, Mistral)
    if let match = id.range(of: "(llama|qwen|mistral|gemma|phi)", options: .regularExpression) {
      architecture = String(id[match]).capitalized
    }

    // Extract parameters (e.g., 0.5B, 7B, 8x7B)
    if let match = id.range(of: "([0-9.]+(b|m))", options: .regularExpression) {
      parameters = String(id[match]).replacingOccurrences(of: "b", with: "B").replacingOccurrences(
        of: "m", with: "M")
    } else if let match = id.range(of: "([0-9]+x[0-9]+(b|m))", options: .regularExpression) {
      parameters = String(id[match]).replacingOccurrences(of: "b", with: "B").replacingOccurrences(
        of: "m", with: "M")
    }

    // Extract quantization (e.g., 4bit, 8bit, fp16)
    if let match = id.range(of: "(4bit|8bit|fp16|q4_k_m|q4_0|q8_0)", options: .regularExpression) {
      quantization = String(id[match])
    }
  }
}

// Backward-compatibility alias used for nested class typealiases
public typealias EngineModelConfiguration = ModelConfiguration

/// Model types supported by PocketCloudMLX
public enum ModelType: String, CaseIterable, Codable, Sendable {
  case llm = "llm"
  case vlm = "vlm"
  case embedding = "embedding"
  case diffusion = "diffusion"
}

/// Generation parameters for text generation
public struct GenerateParams: Codable, Sendable {
  /// Maximum number of tokens to generate
  public var maxTokens: Int

  /// Temperature for sampling (0.0 to 2.0)
  public var temperature: Double

  /// Top-p sampling parameter (0.0 to 1.0)
  public var topP: Double

  /// Top-k sampling parameter
  public var topK: Int

  /// Stop sequences
  public var stopTokens: [String]

  /// Repetition penalty
  public let repetitionPenalty: Float

  /// Initializes generation parameters
  /// - Parameters:
  ///   - maxTokens: Maximum tokens to generate
  ///   - temperature: Sampling temperature
  ///   - topP: Top-p sampling parameter
  ///   - topK: Top-k sampling parameter
  ///   - stopSequences: Stop sequences
  ///   - repetitionPenalty: Repetition penalty
  public init(
    maxTokens: Int = 128, temperature: Double = 0.7, topP: Double = 0.9, topK: Int = 40,
    stopTokens: [String] = [], repetitionPenalty: Float = 1.0
  ) {
    self.maxTokens = maxTokens
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.stopTokens = stopTokens
    self.repetitionPenalty = repetitionPenalty
  }
}

/// Image generation parameters
public struct ImageGenerationParams {
  /// Image width
  public let width: Int

  /// Image height
  public let height: Int

  /// Number of denoising steps
  public let steps: Int

  /// Guidance scale
  public let guidanceScale: Float

  /// Initializes image generation parameters
  /// - Parameters:
  ///   - width: Image width
  ///   - height: Image height
  ///   - steps: Number of denoising steps
  ///   - guidanceScale: Guidance scale
  public init(
    width: Int = 512,
    height: Int = 512,
    steps: Int = 20,
    guidanceScale: Float = 7.5
  ) {
    self.width = width
    self.height = height
    self.steps = steps
    self.guidanceScale = guidanceScale
  }
}

/// Feature flags for experimental or optional engine features.
///
/// Use these to check for support and enable/disable features at runtime.
public enum LLMEngineFeatures: String, CaseIterable, Codable, Sendable {
  /// Enable LoRA adapter support (training/inference)
  case loraAdapters
  /// Enable quantization support (4bit, 8bit, fp16, etc.)
  case quantizationSupport
  /// Enable vision-language model (VLM) support
  case visionLanguageModels
  /// Enable embedding model support (text embedding, semantic search)
  case embeddingModels
  /// Enable diffusion model support (image generation)
  case diffusionModels
  /// Enable custom system/user prompt support
  case customPrompts
  /// Enable multi-modal input (text, image, etc.)
  case multiModalInput
  /// Enable model training and fine-tuning
  case modelTraining
  /// Enable model evaluation and benchmarking
  case modelEvaluation
  /// Enable conversation memory and context management
  case conversationMemory
  /// Enable streaming text generation
  case streamingGeneration
  /// Enable batch processing for multiple inputs
  case batchProcessing
  /// Enable model caching and optimization
  case modelCaching
  /// Enable performance monitoring and metrics
  case performanceMonitoring
  /// Enable model conversion and format support
  case modelConversion
  /// Enable distributed inference across devices
  case distributedInference
  /// Enable model compression and optimization
  case modelCompression
  /// Enable custom tokenizer support
  case customTokenizers
  /// Enable model versioning and management
  case modelVersioning
  /// Enable secure model loading and validation
  case secureModelLoading
  /// Enable model explainability and interpretability
  case modelExplainability
  // Add future feature flags here
}

/// Protocol for engines capable of LLM inference.
///
/// Conformers must be concurrency-safe and support async/await.
public protocol LLMEngine: Sendable {
  /// Loads a model with the specified configuration and progress callback.
  static func loadModel(
    _ config: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void
  ) async throws -> Self
  /// Generates text from a prompt using one-shot completion.
  func generate(_ prompt: String, params: GenerateParams) async throws -> String
  /// Generates text from a prompt using streaming completion.
  func stream(_ prompt: String, params: GenerateParams) -> AsyncThrowingStream<String, Error>
  /// Unloads the model and frees associated resources.
  func unload()
}

// MARK: - File Manager Service

// MARK: - Model Downloader

/// Downloads and manages MLX models from Hugging Face Hub.
///
/// Use this actor to search for, download, and verify models.
///
/// Example:
/// ```swift
/// let downloader = ModelDownloader()
/// let models = try await downloader.searchModels(query: "qwen")
/// ```
public actor ModelDownloader {
  private let huggingFaceAPI = HuggingFaceAPI.shared
  private let fileManager = FileManagerService.shared
  private let optimizedDownloader: OptimizedDownloader
  private let logger = Logger(label: "ModelDownloader")

  public init() {
    // Use OptimizedDownloader which has been refactored to use URLSession (no Hub dependency)
    self.optimizedDownloader = OptimizedDownloader()
  }

  /// Searches for MLX-compatible models on Hugging Face Hub with device compatibility filtering
  public func searchModels(query: String, limit: Int = 50) async throws -> [ModelConfiguration] {
    // First get device-compatible models from Hugging Face API (already filtered)
    let huggingFaceModels = try await huggingFaceAPI.searchModels(query: query, limit: limit)

    logger.info("🔍 Found \(huggingFaceModels.count) device-compatible models from Hugging Face search")

    // Additional MLX compatibility filtering
    let filteredModels =
      huggingFaceModels
      .filter { model in
        // More flexible filtering - include models that might be MLX compatible
        let isMLXCompatible =
          model.tags?.contains("mlx") == true || model.id.lowercased().contains("mlx")
          || model.id.contains("mlx-community") || model.id.contains("lmstudio-community")  // Include lmstudio models
          || (model.tags?.contains("text-generation") == true
            && (model.id.lowercased().contains("mistral") || model.id.lowercased().contains("llama")
              || model.id.lowercased().contains("qwen") || model.id.lowercased().contains("phi")
              || model.id.lowercased().contains("gemma")))

        if !isMLXCompatible {
          logger.info("❌ Filtered out: \(model.id) (tags: \(model.tags?.joined(separator: ", ") ?? "none"))")
        }

        return isMLXCompatible
      }
      .map { $0.toModelConfiguration() }

    // Sort by device compatibility (smaller models first for better compatibility)
    let sortedModels = filteredModels.sorted { (lhs, rhs) -> Bool in
      let lhsSize = lhs.estimatedSizeGB ?? 0.0
      let rhsSize = rhs.estimatedSizeGB ?? 0.0
      return lhsSize < rhsSize
    }

    logger.info("✅ Kept \(sortedModels.count) MLX-compatible models, sorted by device compatibility")
    return sortedModels
  }

  /// Downloads a model to the local cache with optimized downloader if available
  public func downloadModel(
    _ config: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void
  ) async throws -> URL {
    // Generate a correlation ID for this download operation
    _ = UUID().uuidString
    logger.info("🚀 Using optimized downloader for faster downloads")
    let progressLogger = logger
    return try await optimizedDownloader.downloadModelWithResume(
      config,
      progress: { prog in
        progressLogger.info("[Progress] Downloading model...")
        progress(prog)
      })
  }

  /// Fallback download implementation using the original method (now downloads all files)
  private func downloadModelFallback(
    _ config: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void
  ) async throws -> URL {
    let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
    let modelDirectory = modelsDirectory.appendingPathComponent(config.hubId)
    try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
    // Download all files in the repo
    let allFiles = try await huggingFaceAPI.listModelFiles(modelId: config.hubId)
    if allFiles.isEmpty {
      throw NSError(
        domain: "ModelDownloader", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "No files found in model repo: \(config.hubId)"])
    }
    for (index, fileName) in allFiles.enumerated() {
      let destinationURL = modelDirectory.appendingPathComponent(fileName)
      let destinationDir = destinationURL.deletingLastPathComponent()
      if !FileManager.default.fileExists(atPath: destinationDir.path) {
        try FileManager.default.createDirectory(
          at: destinationDir, withIntermediateDirectories: true)
      }
      try await huggingFaceAPI.downloadModel(
        modelId: config.hubId,
        fileName: fileName,
        to: destinationURL
      ) { fileProgress, _, _ in
        let overallProgress = (Double(index) + fileProgress) / Double(allFiles.count)
        progress(overallProgress)
      }
    }
    // Patch: Symlink or copy model.safetensors to main.mlx if main.mlx is missing
    let mainMLXPath = modelDirectory.appendingPathComponent("main.mlx").path
    let safetensorsPath = modelDirectory.appendingPathComponent("model.safetensors").path
    if !FileManager.default.fileExists(atPath: mainMLXPath),
      FileManager.default.fileExists(atPath: safetensorsPath)
    {
      do {
        #if os(macOS) || os(Linux)
          try? FileManager.default.removeItem(atPath: mainMLXPath)
          try FileManager.default.createSymbolicLink(
            atPath: mainMLXPath, withDestinationPath: safetensorsPath)
        #else
          // On iOS/tvOS/watchOS, symlinks may not be allowed; fallback to copy
          try? FileManager.default.removeItem(atPath: mainMLXPath)
          try FileManager.default.copyItem(atPath: safetensorsPath, toPath: mainMLXPath)
        #endif
        logger.info("Patched: Linked model.safetensors to main.mlx for MLX compatibility")
      } catch {
        logger.warning("Failed to patch main.mlx symlink/copy: \(error)", context: Logger.Context(["modelDir": modelDirectory.path]))
      }
    }
    return modelDirectory
  }

  /// Gets model information before downloading (optimized version if available)
  public func getModelInfo(modelId: String) async throws -> ModelInfo? {
    return try await optimizedDownloader.getModelInfo(modelId: modelId)
  }

  /// Verifies file integrity using SHA-256 checksum
  public func verifyFileChecksum(fileURL: URL, expectedSHA256: String) async throws -> Bool {
    let calculatedSHA256 = try sha256Hex(forFileAt: fileURL)
    return calculatedSHA256.lowercased() == expectedSHA256.lowercased()
  }

  /// Gets the list of downloaded models
  public func getDownloadedModels() async throws -> [ModelConfiguration] {
    // Use optimized downloader for better model detection
    return try await optimizedDownloader.getDownloadedModels()
  }

  /// Cleans up incomplete downloads
  public func cleanupIncompleteDownloads() async throws {
    try await optimizedDownloader.cleanupIncompleteDownloads()
  }
}

/// Main PocketCloudMLX class that provides unified access to MLX-based AI models
/// with automatic Metal library compilation and robust fallback mechanisms.
public final class PocketCloudMLX: LLMEngine, @unchecked Sendable {
  private let logger = Logger(label: "PocketCloudMLX")

  public typealias ModelConfiguration = EngineModelConfiguration

  /// Engine configuration
  public let configuration: ModelConfiguration

  /// Current chat session
  private var currentSession: ChatSession?

  /// Metal library for GPU operations
  private var metalLibrary: MTLLibrary?

  /// Engine initialization status
  private var isInitialized = false

  /// Private initializer
  private init(configuration: ModelConfiguration) {
    self.configuration = configuration
  }

  // MARK: - Legacy/Compatibility API
  /// Zero-argument initializer for legacy tests and utilities
  public convenience init() {
    self.init(configuration: ModelConfiguration(name: "Placeholder", hubId: "mock/placeholder"))
  }

  /// Returns a static list of available models (legacy compatibility)
  public func getAvailableModels() -> [ModelConfiguration] {
    return ModelRegistry.allModels
  }

  /// Checks if a model has already been downloaded (legacy compatibility)
  public func isModelDownloaded(configuration: ModelConfiguration) async -> Bool {
    do {
      let downloaded = try await ModelDownloader().getDownloadedModels()
      return downloaded.contains { $0.hubId == configuration.hubId }
    } catch {
      return false
    }
  }

  /// Lightweight capability check for whether a model appears downloadable
  public func canDownloadModel(configuration: ModelConfiguration) async -> Bool {
    do {
      let info = try await ModelDownloader().getModelInfo(modelId: configuration.hubId)
      return info != nil
    } catch {
      return false
    }
  }

  /// Downloads a model using the robust download manager
  public func downloadModel(
    configuration: ModelConfiguration,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> URL {
    logger.info("🚀 Starting robust download of model: \(configuration.name) (\(configuration.hubId))")
    
    // Use the optimized downloader
    let downloader = OptimizedDownloader()
    let result = try await downloader.downloadModel(configuration, progress: progress)
    
    logger.info("✅ Model download completed successfully: \(result.path)")
    return result
  }

  /// Loads a model with the specified configuration and progress callback.
  /// - Parameters:
  ///   - config: Model configuration
  ///   - progress: Progress callback
  /// - Returns: Initialized PocketCloudMLX instance
  /// - Throws: Engine initialization errors
  public static func loadModel(
    _ config: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void
  ) async throws -> PocketCloudMLX {
    let engine = PocketCloudMLX(configuration: config)
    try await engine.initialize(progress: progress)
    return engine
  }

  /// Initializes the engine with Metal library and MLX setup
  /// - Parameter progress: Progress callback
  /// - Throws: Initialization errors
  private func initialize(progress: @escaping @Sendable (Double) -> Void) async throws {
    progress(0.1)

    // Initialize Metal library
    try initializeMetalLibrary()
    progress(0.3)

    // Set GPU cache limit for memory safety (skip on simulator)
    #if !targetEnvironment(simulator)
      MLX.GPU.set(cacheLimit: configuration.gpuCacheLimit)
    #endif
    progress(0.4)

    // Initialize MLX with the model
    try initializeMLX()
    progress(0.6)

    // Create chat session
    try await createChatSession()
    progress(0.8)

    isInitialized = true
    progress(1.0)
  }

  /// Initializes the Metal library with automatic fallback mechanisms
  private func initializeMetalLibrary() throws {
    logger.info("Initializing Metal library")

    let compilationStatus = MetalLibraryBuilder.buildLibrary()

    switch compilationStatus {
    case .success(let library):
      self.metalLibrary = library

      // Validate the library
      if MetalLibraryBuilder.validateLibrary(library) {
        logger.info("Metal library initialized successfully")
      } else {
        logger.warning("Metal library validation failed, but continuing")
      }

    case .failure(let error):
      logger.error("Metal library initialization failed: \(error)")

      // Check if we're on iOS Simulator
      #if targetEnvironment(simulator)
        throw LLMEngineError.simulatorNotSupported
      #else
        // On real hardware, try to continue without Metal
        logger.warning("Continuing without Metal acceleration")
      #endif

    case .notSupported(let reason):
      logger.warning("Metal not supported: \(reason)")
      #if targetEnvironment(simulator)
        throw LLMEngineError.simulatorNotSupported
      #else
        logger.warning("Continuing without Metal acceleration")
      #endif
    }
  }

  /// Initializes MLX with the configured model
  private func initializeMLX() throws {
    logger.info("Initializing MLX with model: \(configuration.hubId)")

    // Set up MLX configuration based on model type
    switch configuration.modelType {
    case .llm:
      try initializeLLM()
    case .vlm:
      try initializeVLM()
    case .embedding:
      try initializeEmbedding()
    case .diffusion:
      try initializeDiffusion()
    }
  }

  /// Initializes LLM model
  private func initializeLLM() throws {
    // LLM initialization is handled lazily when needed
    logger.info("LLM model ready for initialization")
  }

  /// Initializes VLM model
  private func initializeVLM() throws {
    // VLM initialization is handled lazily when needed
    logger.info("VLM model ready for initialization")
  }

  /// Initializes embedding model
  private func initializeEmbedding() throws {
    // Embedding initialization is handled lazily when needed
    logger.info("Embedding model ready for initialization")
  }

  /// Initializes diffusion model
  private func initializeDiffusion() throws {
    // Diffusion initialization is handled lazily when needed
    logger.info("Diffusion model ready for initialization")
  }

  /// Creates a chat session
  private func createChatSession() async throws {
    let session = try await ChatSession.create(
      modelConfiguration: configuration,
      metalLibrary: metalLibrary
    )
    currentSession = session
  }

  // MARK: - LLMEngine Protocol Implementation

  public func generate(_ prompt: String, params: GenerateParams) async throws -> String {
    guard isInitialized else {
      throw LLMEngineError.notInitialized
    }

    guard let session = currentSession else {
      throw LLMEngineError.notInitialized
    }

    // Generate response
    return try await session.generate(prompt: prompt, parameters: params)
  }

  public func stream(_ prompt: String, params: GenerateParams) -> AsyncThrowingStream<String, Error>
  {
    guard isInitialized, let session = currentSession else {
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: LLMEngineError.notInitialized)
      }
    }
    // Bridge async to sync using Task
    return AsyncThrowingStream { continuation in
      Task {
        do {
          let stream = try await session.generateStream(prompt: prompt, parameters: params)
          for try await token in stream {
            continuation.yield(token)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  public func unload() {
    logger.info("Unloading PocketCloudMLX")

    // Clear current session
    currentSession = nil

    // Clear Metal library
    metalLibrary = nil

    // Reset MLX GPU cache (skip on simulator)
    #if !targetEnvironment(simulator)
      MLX.GPU.clearCache()
    #endif

    isInitialized = false
    logger.info("PocketCloudMLX unloaded successfully")
  }
}

public enum LLMEngineError: Error, LocalizedError, Codable, Sendable {
  case notInitialized
  case custom(String)
  case simulatorNotSupported
  case deviceNotSupported(message: String)

  public var errorDescription: String? {
    switch self {
    case .notInitialized:
      return "Engine not initialized"
    case .custom(let msg):
      return msg
    case .simulatorNotSupported:
      return "MLX is not available on iOS Simulator. Please use a physical device or macOS."
    case .deviceNotSupported(let message):
      return message
    }
  }
}
