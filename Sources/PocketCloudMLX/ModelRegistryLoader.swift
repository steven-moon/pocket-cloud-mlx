// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/ModelRegistryLoader.swift
// Purpose       : YAML-based model registry loader with HuggingFace metadata integration
//
// Key Types in this file:
//   - struct ModelRegistryLoader
//   - struct YAMLModelDefinition
//
// == End LLM Context Header ==

import Foundation
import Yams
import PocketCloudLogger

/// YAML model definition structure
struct YAMLModelDefinition: Codable {
    let hubId: String
    let name: String
    let description: String?
    let parameters: String?
    let quantization: String?
    let architecture: String?
    let maxTokens: Int
    let estimatedSizeGB: Double?
    let defaultSystemPrompt: String?
    let endOfTextTokens: [String]?
    let modelType: String
    let gpuCacheLimit: Int?
    let features: [String]?
    // New optional fields
    let downloads: String?
    let published: String?
}

/// Root YAML structure
struct ModelsYAML: Codable {
    let models: [YAMLModelDefinition]
}

/// Loads models from YAML configuration with HuggingFace metadata integration
private final class ModelRegistryBundleMarker {}

public struct ModelRegistryLoader {
    private static let logger = Logger(label: "ModelRegistryLoader")

    /// Load models from YAML file
    public static func loadModels() -> [ModelConfiguration] {
        guard let yamlURL = resolveModelsYAMLURL() else {
            logger.error("models.yaml not found in any bundle")
            logger.notice("Falling back to built-in emergency model list")
            return loadFallbackModels()
        }

        do {
            logger.info("Loading models from: \(yamlURL.path)")
            let yamlString = try String(contentsOf: yamlURL, encoding: .utf8)
            return try parseYAML(yamlString)
        } catch {
            logger.error("Failed to load models.yaml: \(error)")
            logger.notice("Falling back to built-in emergency model list due to parse failure")
            return loadFallbackModels()
        }
    }

    /// Parse YAML string into ModelConfiguration array
    private static func parseYAML(_ yamlString: String) throws -> [ModelConfiguration] {
        let decoder = YAMLDecoder()
        let modelsYAML = try decoder.decode(ModelsYAML.self, from: yamlString)

        logger.info("Loaded \(modelsYAML.models.count) models from YAML")

        return modelsYAML.models.compactMap { yamlModel in
            convertToModelConfiguration(yamlModel)
        }
    }

    /// Convert YAML model to ModelConfiguration
    private static func convertToModelConfiguration(_ yaml: YAMLModelDefinition) -> ModelConfiguration? {
        // Parse model type
        let modelType: ModelType
        switch yaml.modelType.lowercased() {
        case "llm":
            modelType = .llm
        case "vlm":
            modelType = .vlm
        case "embedding":
            modelType = .embedding
        case "diffusion":
            modelType = .diffusion
        default:
            logger.warning("Unknown model type '\(yaml.modelType)' for \(yaml.hubId), defaulting to llm")
            modelType = .llm
        }

        // Parse features
        let features: Set<LLMEngineFeatures> = Set(yaml.features?.compactMap { featureString in
            switch featureString.lowercased() {
            case "streaminggeneration":
                return .streamingGeneration
            case "conversationmemory":
                return .conversationMemory
            case "visionlanguagemodels":
                return .visionLanguageModels
            case "multimodalinput":
                return .multiModalInput
            case "embeddingmodels":
                return .embeddingModels
            case "batchprocessing":
                return .batchProcessing
            case "diffusionmodels":
                return .diffusionModels
            default:
                return nil
            }
        } ?? [])

        // Check for cached HuggingFace metadata
        Task {
            if await HuggingFaceMetadataCache.shared.getMetadata(for: yaml.hubId) == nil {
                // No cached metadata, fetch it in background
                Task.detached(priority: .background) {
                    await HuggingFaceMetadataCache.shared.updateMetadata(for: yaml.hubId)
                }
            }
        }

        return ModelConfiguration(
            name: yaml.name,
            hubId: yaml.hubId,
            description: yaml.description ?? "",
            parameters: yaml.parameters,
            quantization: yaml.quantization,
            architecture: yaml.architecture,
            maxTokens: yaml.maxTokens,
            estimatedSizeGB: yaml.estimatedSizeGB,
            defaultSystemPrompt: yaml.defaultSystemPrompt,
            endOfTextTokens: yaml.endOfTextTokens,
            modelType: modelType,
            gpuCacheLimit: yaml.gpuCacheLimit ?? (512 * 1024 * 1024),
            features: features
        )
    }

    /// Refresh HuggingFace metadata for all models in background
    public static func refreshMetadataInBackground(for models: [ModelConfiguration]) {
        Task.detached(priority: .background) {
            let hubIds = models.map { $0.hubId }
            await HuggingFaceMetadataCache.shared.batchUpdateMetadata(for: hubIds)
        }
    }

    /// Get enriched model with HuggingFace metadata
    public static func enrichModelWithMetadata(_ model: ModelConfiguration) async -> EnrichedModelConfiguration {
        let metadata = await HuggingFaceMetadataCache.shared.getMetadata(for: model.hubId)
        return EnrichedModelConfiguration(config: model, metadata: metadata)
    }
}

// MARK: - Resource Resolution Helpers

private extension ModelRegistryLoader {
    static func resolveModelsYAMLURL() -> URL? {
        #if SWIFT_PACKAGE
            if let url = Bundle.module.url(forResource: "models", withExtension: "yaml") {
                return url
            }
        #endif

        var visitedBundles = Set<URL>()

        let primaryBundles: [Bundle] = [
            Bundle.main,
            Bundle(for: ModelRegistryBundleMarker.self)
        ]

        let additionalBundles = Bundle.allBundles + Bundle.allFrameworks
        let allBundles = primaryBundles + additionalBundles

        for bundle in allBundles {
            let bundleURL = bundle.bundleURL
            guard visitedBundles.insert(bundleURL).inserted else {
                continue
            }

            if let url = findModelsResource(in: bundle, visitedBundles: &visitedBundles) {
                return url
            }
        }

        return nil
    }

    static func findModelsResource(in bundle: Bundle, visitedBundles: inout Set<URL>) -> URL? {
        if let directURL = bundle.url(forResource: "models", withExtension: "yaml") {
            return directURL
        }

        if let resourceURL = bundle.resourceURL {
            // Check for direct file at the root of the resource directory
            let candidateFile = resourceURL.appendingPathComponent("models.yaml")
            if FileManager.default.fileExists(atPath: candidateFile.path) {
                return candidateFile
            }

            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return nil
            }

            for item in contents {
                if item.pathExtension == "yaml", item.lastPathComponent == "models.yaml" {
                    return item
                }

                if item.pathExtension == "bundle", let nestedBundle = Bundle(url: item) {
                    let nestedURL = nestedBundle.bundleURL
                    guard visitedBundles.insert(nestedURL).inserted else {
                        continue
                    }

                    if let url = findModelsResource(in: nestedBundle, visitedBundles: &visitedBundles) {
                        return url
                    }
                }
            }
        }

        return nil
    }

    static func loadFallbackModels() -> [ModelConfiguration] {
        guard let fallback = try? parseYAML(fallbackModelsYAML) else {
            logger.critical("Failed to load fallback models; returning empty list")
            return []
        }

        return fallback
    }

    static let fallbackModelsYAML = """
models:
  - hubId: mlx-community/Llama-3.2-1B-Instruct-4bit
    name: Llama 3.2 1B Instruct
    description: Emergency fallback model shipped inside the app bundle.
    parameters: "1B"
    quantization: 4bit
    architecture: Llama
    maxTokens: 4096
    estimatedSizeGB: 0.6
    modelType: llm
    gpuCacheLimit: 536870912
  - hubId: mlx-community/Mistral-7B-Instruct-v0.3-4bit
    name: Mistral 7B Instruct
    description: Emergency fallback mid-size model for general chat.
    parameters: "7B"
    quantization: 4bit
    architecture: Mistral
    maxTokens: 8192
    estimatedSizeGB: 4.2
    defaultSystemPrompt: You are a helpful assistant.
    endOfTextTokens: ["</s>"]
    modelType: llm
    gpuCacheLimit: 2147483648
  - hubId: mlx-community/bge-small-en-v1.5-4bit
    name: BGE Small EN v1.5
    description: Emergency fallback embedding model for semantic search.
    parameters: "384M"
    quantization: 4bit
    architecture: BGE
    maxTokens: 512
    estimatedSizeGB: 0.2
    modelType: embedding
    gpuCacheLimit: 536870912
    features: ["embeddingModels", "batchProcessing"]
"""
}

/// Model configuration enriched with HuggingFace metadata
public struct EnrichedModelConfiguration {
    public let config: ModelConfiguration
    public let metadata: CachedModelMetadata?

    // Convenience accessors
    public var downloads: Int? { metadata?.downloads }
    public var downloadsAllTime: Int? { metadata?.downloadsAllTime }
    public var likes: Int? { metadata?.likes }
    public var trendingScore: Double? { metadata?.trendingScore }
    public var tags: [String]? { metadata?.tags }
    public var isGated: Bool { metadata?.gated ?? false }
    public var isPrivate: Bool { metadata?.private_ ?? false }
    public var lastModified: String? { metadata?.lastModified }
    public var createdAt: String? { metadata?.createdAt }
}
