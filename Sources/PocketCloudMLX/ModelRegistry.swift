// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/ModelRegistry.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModelRegistry
//
// == End LLM Context Header ==

import Foundation

public extension ModelType {
  /// Human-readable description of the model type
  var description: String {
    switch self {
    case .llm:
      return "Text generation and conversation"
    case .vlm:
      return "Image understanding and analysis"
    case .embedding:
      return "Text embedding and semantic search"
    case .diffusion:
      return "Image generation from text"
    @unknown default:
      return "Specialized model category"
    }
  }

  /// Required engine features for this model type
  var requiredFeatures: Set<LLMEngineFeatures> {
    switch self {
    case .llm:
      return [.streamingGeneration, .conversationMemory]
    case .vlm:
      return [.visionLanguageModels, .multiModalInput, .streamingGeneration]
    case .embedding:
      return [.embeddingModels, .batchProcessing]
    case .diffusion:
      return [.diffusionModels, .multiModalInput]
    @unknown default:
      return []
    }
  }
}

/// YAML-backed collection of MLX-compatible models
public struct ModelRegistry {

  // MARK: Model Discovery & Filtering

  public struct SearchCriteria {
    public let query: String?
    public let maxParameters: String?
    public let minParameters: String?
    public let architecture: String?
    public let quantization: String?
    public let maxSizeGB: Double?
    public let modelType: ModelType?
    public let isSmallModel: Bool?

    public init(
      query: String? = nil,
      maxParameters: String? = nil,
      minParameters: String? = nil,
      architecture: String? = nil,
      quantization: String? = nil,
      maxSizeGB: Double? = nil,
      modelType: ModelType? = nil,
      isSmallModel: Bool? = nil
    ) {
      self.query = query
      self.maxParameters = maxParameters
      self.minParameters = minParameters
      self.architecture = architecture
      self.quantization = quantization
      self.maxSizeGB = maxSizeGB
      self.modelType = modelType
      self.isSmallModel = isSmallModel
    }
  }

  public enum UseCase {
    case mobileDevelopment
    case desktopDevelopment
    case highQualityGeneration
    case fastInference
    case visionTasks
    case embeddingTasks
    case imageGeneration
  }

  // MARK: Public API

  public static var allModels: [ModelConfiguration] { cachedModels }

  public static func searchModels(criteria: SearchCriteria) -> [ModelConfiguration] {
    allModels.filter { model in
      if let query = criteria.query, !query.isEmpty {
        let needle = query.lowercased()
        let haystack = "\(model.name) \(model.description) \(model.architecture ?? "")"
          .lowercased()
        if !haystack.contains(needle) && !model.hubId.lowercased().contains(needle) {
          return false
        }
      }

      if let maxParams = criteria.maxParameters,
        let modelValue = model.parameters.map(extractParameterValue),
        modelValue > extractParameterValue(maxParams)
      {
        return false
      }

      if let minParams = criteria.minParameters,
        let modelValue = model.parameters.map(extractParameterValue),
        modelValue < extractParameterValue(minParams)
      {
        return false
      }

      if let architecture = criteria.architecture,
        model.architecture?.lowercased() != architecture.lowercased()
      {
        return false
      }

      if let quantization = criteria.quantization,
        model.quantization?.lowercased() != quantization.lowercased()
      {
        return false
      }

      if let maxSize = criteria.maxSizeGB,
        let size = model.estimatedSizeGB,
        size > maxSize
      {
        return false
      }

      if let type = criteria.modelType, model.modelType != type {
        return false
      }

      if let small = criteria.isSmallModel, model.isSmallModel != small {
        return false
      }

      return true
    }
  }

  public static func searchModels(query: String, type: ModelType) -> [ModelConfiguration] {
    searchModels(criteria: SearchCriteria(query: query, modelType: type))
  }

  public static func searchModels(query: String) -> [ModelConfiguration] {
    searchModels(criteria: SearchCriteria(query: query))
  }

  public static func getModelType(_ model: ModelConfiguration) -> ModelType {
    model.modelType
  }

  public static func getRecommendedModels(for useCase: UseCase) -> [ModelConfiguration] {
    switch useCase {
    case .mobileDevelopment:
      return searchModels(criteria: SearchCriteria(maxSizeGB: 1.0, modelType: .llm, isSmallModel: true))
    case .desktopDevelopment:
      return searchModels(criteria: SearchCriteria(maxSizeGB: 4.0, modelType: .llm))
    case .highQualityGeneration:
      return searchModels(criteria: SearchCriteria(minParameters: "7B", modelType: .llm))
    case .fastInference:
      return searchModels(criteria: SearchCriteria(maxParameters: "3B", isSmallModel: true))
    case .visionTasks:
      return searchModels(criteria: SearchCriteria(modelType: .vlm))
    case .embeddingTasks:
      return searchModels(criteria: SearchCriteria(modelType: .embedding))
    case .imageGeneration:
      return searchModels(criteria: SearchCriteria(modelType: .diffusion))
    }
  }

  public static func getModelsForDevice(memoryGB: Double, isMobile: Bool = false)
    -> [ModelConfiguration]
  {
    let maxModelSize = isMobile ? min(memoryGB * 0.3, 2.0) : min(memoryGB * 0.5, 8.0)
    return searchModels(criteria: SearchCriteria(maxSizeGB: maxModelSize, isSmallModel: isMobile))
  }

  public static func getBestModel(
    for _: String,
    maxTokens: Int = 1000,
    maxSizeGB: Double? = nil,
    preferSpeed: Bool = false
  ) -> ModelConfiguration? {
    let models = maxSizeGB.map { size in
      allModels.filter { $0.estimatedSizeGB ?? 0 <= size }
    } ?? allModels

    let scored = models.map { model -> (ModelConfiguration, Double) in
      var score = 0.0

      if model.maxTokens >= maxTokens {
        score += 10.0
      } else {
        score -= Double(maxTokens - model.maxTokens) * 0.1
      }

      if let size = model.estimatedSizeGB {
        score += preferSpeed ? (10.0 - size) * 2.0 : (10.0 - size)
      }

      if let params = model.parameters {
        let value = extractParameterValue(params)
        score += preferSpeed ? (10.0 - value) * 2.0 : value * 0.5
      }

      return (model, score)
    }

    return scored.max(by: { $0.1 < $1.1 })?.0
  }

  public static func defaultModel(
    for type: ModelType,
    preferSmallerModels: Bool = true
  ) -> ModelConfiguration? {
    let candidates = allModels.filter { $0.modelType == type }
    guard !candidates.isEmpty else { return nil }

    let sorted = candidates.sorted { lhs, rhs in
      let lhsSize = lhs.estimatedSizeGB ?? (preferSmallerModels ? .greatestFiniteMagnitude : 0)
      let rhsSize = rhs.estimatedSizeGB ?? (preferSmallerModels ? .greatestFiniteMagnitude : 0)
      if lhsSize != rhsSize {
        return preferSmallerModels ? lhsSize < rhsSize : lhsSize > rhsSize
      }

      let lhsParams = extractParameterValue(lhs.parameters ?? "")
      let rhsParams = extractParameterValue(rhs.parameters ?? "")
      if lhsParams != rhsParams {
        return preferSmallerModels ? lhsParams < rhsParams : lhsParams > rhsParams
      }

      return lhs.name < rhs.name
    }

    return sorted.first
  }

  public static func findModel(by hubId: String) -> ModelConfiguration? {
    allModels.first { $0.hubId == hubId }
  }

  public static func findModelByName(_ name: String) -> ModelConfiguration? {
    allModels.first { $0.name == name }
  }

  public static func findModels(by architecture: String) -> [ModelConfiguration] {
    allModels.filter { $0.architecture?.lowercased() == architecture.lowercased() }
  }

  public static func findMobileSuitableModels() -> [ModelConfiguration] {
    allModels.filter { $0.isSmallModel }
  }

  public static var smallModels: [ModelConfiguration] {
    allModels.filter { $0.isSmallModel }
  }

  public static var mediumModels: [ModelConfiguration] {
    allModels.filter { model in
      guard let params = model.parameters else { return false }
      let value = extractParameterValue(params)
      return value >= 3.0 && value < 8.0
    }
  }

  public static var largeModels: [ModelConfiguration] {
    allModels.filter { model in
      guard let params = model.parameters else { return false }
      return extractParameterValue(params) >= 8.0
    }
  }

  public static func findModels(parameterRange: ClosedRange<Double>) -> [ModelConfiguration] {
    allModels.filter { model in
      guard let params = model.parameters else { return false }
      let value = extractParameterValue(params)
      return parameterRange.contains(value)
    }
  }

  public static func findModels(byQuantization quantization: String) -> [ModelConfiguration] {
    allModels.filter { $0.quantization?.lowercased() == quantization.lowercased() }
  }

  public static func refreshMetadata() {
    ModelRegistryLoader.refreshMetadataInBackground(for: allModels)
  }

  public static func enrichedModel(for hubId: String) async -> EnrichedModelConfiguration? {
    guard let model = findModel(by: hubId) else { return nil }
    return await ModelRegistryLoader.enrichModelWithMetadata(model)
  }

  public static func modelsSupporting(minTokens: Int) -> [ModelConfiguration] {
    allModels.filter { $0.maxTokens >= minTokens }
  }

  public static func recommendedModelsForCurrentDevice(limit: Int = 3) async -> [ModelConfiguration]
  {
    guard !allModels.isEmpty else { return [] }

    let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
    #if os(iOS)
      let platform = "iOS"
    #elseif os(macOS)
      let platform = "macOS"
    #elseif os(tvOS)
      let platform = "tvOS"
    #elseif os(watchOS)
      let platform = "watchOS"
    #elseif os(visionOS)
      let platform = "visionOS"
    #else
      let platform = "Unknown"
    #endif

    let supported = allModels.filter {
      isModelSupported($0, ramGB: memoryGB, platform: platform)
    }

    let prioritized = supported.sorted { lhs, rhs in
      let lhsScore = recommendationScore(for: lhs)
      let rhsScore = recommendationScore(for: rhs)
      if lhsScore != rhsScore {
        return lhsScore > rhsScore
      }
      return lhs.name < rhs.name
    }

    let fallback = allModels.sorted { recommendationScore(for: $0) > recommendationScore(for: $1) }
    let pool = prioritized.isEmpty ? fallback : prioritized
    return Array(pool.prefix(min(limit, pool.count)))
  }

  public static func isModelSupported(_ model: ModelConfiguration, ramGB: Double, platform _: String)
    -> Bool
  {
    model.estimatedMemoryGB < ramGB * 0.8
  }

  public static var textGenerationModels: [ModelConfiguration] {
    allModels.filter { $0.modelType == .llm }
  }

  public static var onboardingModels: [ModelConfiguration] {
    textGenerationModels.sorted { lhs, rhs in
      let lhsSize = lhs.estimatedSizeGB ?? .greatestFiniteMagnitude
      let rhsSize = rhs.estimatedSizeGB ?? .greatestFiniteMagnitude
      if lhsSize != rhsSize {
        return lhsSize < rhsSize
      }

      let lhsParams = extractParameterValue(lhs.parameters ?? "")
      let rhsParams = extractParameterValue(rhs.parameters ?? "")
      if lhsParams != rhsParams {
        return lhsParams < rhsParams
      }

      return lhs.name < rhs.name
    }
  }

  public static var visionModels: [ModelConfiguration] {
    allModels.filter { $0.modelType == .vlm }
  }

  public static var embeddingModels: [ModelConfiguration] {
    allModels.filter { $0.modelType == .embedding }
  }

  public static var diffusionModels: [ModelConfiguration] {
    allModels.filter { $0.modelType == .diffusion }
  }

  // MARK: Private Helpers

  private static let cachedModels: [ModelConfiguration] = {
    let models = ModelRegistryLoader.loadModels()
    if !models.isEmpty {
      ModelRegistryLoader.refreshMetadataInBackground(for: models)
    }
    return models
  }()

  private static func extractParameterValue(_ paramString: String) -> Double {
    let trimmed = paramString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else { return 0.0 }

    let valueString = trimmed.replacingOccurrences(
      of: "[^0-9.]+",
      with: "",
      options: .regularExpression
    )

    guard var value = Double(valueString) else { return 0.0 }

    if trimmed.contains("m") {
      value /= 1000.0
    }

    return value
  }

  private static func recommendationScore(for model: ModelConfiguration) -> Double {
    var score = 0.0

    if let size = model.estimatedSizeGB {
      score += max(0, 10.0 - size * 2.5)
    }

    if let params = model.parameters {
      let value = extractParameterValue(params)
      score += max(0, 6.0 - value)
    }

    if model.isSmallModel {
      score += 2.0
    }

    if model.modelType == .llm {
      score += 1.0
    }

    return score
  }
}
