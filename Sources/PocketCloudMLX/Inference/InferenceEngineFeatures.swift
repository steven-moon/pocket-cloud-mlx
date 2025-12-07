// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Inference/InferenceEngineFeatures.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - extension InferenceEngineFacade {
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
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

/// Feature detection and support methods for InferenceEngine
public extension InferenceEngineFacade {
  
  /// Use this to check for LoRA, quantization, VLM, embedding, diffusion, custom prompts, or multi-modal support at runtime.
  ///
  /// Feature detection is implemented based on MLX Swift examples capabilities.
  static var supportedFeatures: Set<LLMEngineFeatures> {
    var features: Set<LLMEngineFeatures> = []

    #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
      // Core features always available with MLX
      features.insert(.streamingGeneration)
      features.insert(.conversationMemory)
      features.insert(.performanceMonitoring)
      features.insert(.customPrompts)
      features.insert(.modelCaching)
      features.insert(.customTokenizers)
      features.insert(.quantizationSupport)
      features.insert(.secureModelLoading)
      
      // Optional features based on MLX capabilities
      #if canImport(MLXVLM)
        features.insert(.visionLanguageModels)
        features.insert(.multiModalInput)
      #endif
      
      #if canImport(MLXEmbeddings)
        features.insert(.embeddingModels)
        features.insert(.batchProcessing)
      #endif
      
      #if canImport(MLXDiffusion)
        features.insert(.diffusionModels)
      #endif
      
      // LoRA support (placeholder for future implementation)
      // features.insert(.loraAdapters)
    #endif

    return features
  }
}
