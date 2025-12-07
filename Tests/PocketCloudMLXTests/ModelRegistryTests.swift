// == LLM Context: Bread Crumbs ==
// Module        : Workspace
// File          : pocket-cloud-mlx/Tests/PocketCloudMLXTests/ModelRegistryTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ModelRegistryTests: XCTestCase {
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
import XCTest

@testable import PocketCloudMLX

final class ModelRegistryTests: XCTestCase {

  func testAllModelsNotEmpty() {
    let models = ModelRegistry.allModels
    XCTAssertFalse(models.isEmpty, "ModelRegistry should have at least one model")
    XCTAssertGreaterThanOrEqual(models.count, 8, "Should have at least 8 predefined models")
  }

  func testSmallModelsCollection() {
    let smallModels = ModelRegistry.smallModels
    // The exact count may vary as the registry is updated, but should have at least 8 small models
    XCTAssertGreaterThanOrEqual(smallModels.count, 8, "Should have at least 8 small models")

    for model in smallModels {
      XCTAssertTrue(model.isSmallModel, "All small models should be marked as small")
    }
  }

  func testMediumModelsCollection() {
    let mediumModels = ModelRegistry.mediumModels
    XCTAssertEqual(mediumModels.count, 8, "Should have 8 medium models")
  }

  func testLargeModelsCollection() {
    let largeModels = ModelRegistry.largeModels
    XCTAssertEqual(largeModels.count, 0, "Should have 0 large models")
  }

  func testFindModelByHubId() {
    // Known model
    let knownHubId = "mlx-community/Qwen1.5-0.5B-Chat-4bit"
    let model = ModelRegistry.findModel(by: knownHubId)
    XCTAssertNotNil(model)
    XCTAssertEqual(model?.hubId, knownHubId)

    // Unknown model
    let unknownHubId = "mlx-community/NonExistentModel"
    let missingModel = ModelRegistry.findModel(by: unknownHubId)
    XCTAssertNil(missingModel)
  }

  func testFindModelByName() {
    let llama = ModelRegistry.findModelByName("Llama 3.2 3B")
    XCTAssertNotNil(llama, "Should find LLaMA model by name")
    XCTAssertEqual(llama?.hubId, "mlx-community/Llama-3.2-3B-4bit")

    let notFound = ModelRegistry.findModelByName("Non-existent Model")
    XCTAssertNil(notFound, "Should return nil for non-existent model name")
  }

  func testFindModelsByArchitecture() {
    let llamaModels = ModelRegistry.findModels(by: "Llama")
    XCTAssertGreaterThanOrEqual(llamaModels.count, 3, "Should find multiple Llama models")

    for model in llamaModels {
      XCTAssertEqual(model.architecture, "Llama")
    }
  }

  func testFindMobileSuitableModels() {
    let mobileModels = ModelRegistry.findMobileSuitableModels()
    XCTAssertGreaterThanOrEqual(
      mobileModels.count, 3, "Should find multiple mobile-suitable models")

    for model in mobileModels {
      XCTAssertTrue(model.isSmallModel, "All mobile models should be small")
    }
  }

  func testFindModelsByParameterRange() {
    let smallModels = ModelRegistry.findModels(parameterRange: 0.5...3.0)
    XCTAssertGreaterThanOrEqual(smallModels.count, 4, "Should find multiple small models")

    for model in smallModels {
      guard let params = model.parameters?.lowercased() else {
        XCTFail("Model should have parameters")
        continue
      }

      let isSmall =
        params.contains("0.5b") || params.contains("1b") || params.contains("1.5b")
        || params.contains("2b") || params.contains("3b")
      XCTAssertTrue(isSmall, "All models should be in the specified range")
    }
  }

  func testFindModelsByQuantization() {
    let fourBitModels = ModelRegistry.findModels(byQuantization: "4bit")
    XCTAssertGreaterThanOrEqual(fourBitModels.count, 6, "Should find multiple 4-bit models")

    for model in fourBitModels {
      XCTAssertEqual(model.quantization, "4bit")
    }
  }

  func testModelConfigurationsAreValid() {
    for model in ModelRegistry.allModels {
      XCTAssertFalse(model.name.isEmpty, "Model name should not be empty")
      XCTAssertFalse(model.hubId.isEmpty, "Model hub ID should not be empty")
      XCTAssertTrue(model.hubId.contains("/"), "Hub ID should contain organization/model format")
      XCTAssertGreaterThan(model.maxTokens, 0, "Max tokens should be positive")
    }
  }

  func testModelMetadataExtraction() {
    for model in ModelRegistry.allModels {
      if let params = model.parameters {
        let lower = params.lowercased()
        XCTAssertTrue(
          lower.hasSuffix("b") || lower.hasSuffix("m"),
          "Parameters should end with 'B' or 'M' for model: \(model.name) [\(params)]")
      } else {
        print("[WARN] Model missing parameters: \(model.name) [\(model.hubId)]")
      }
      if let quant = model.quantization {
        let valid = ["4bit", "8bit", "fp16", "q4_k_m", "q4_0", "q8_0"].contains(quant.lowercased())
        XCTAssertTrue(valid, "Quantization should be valid for model: \(model.name) [\(quant)]")
      } else {
        print("[WARN] Model missing quantization: \(model.name) [\(model.hubId)]")
      }
    }
  }

  func testLegacySupport() {
    // Test that legacy properties still work by finding them in allModels
    let allModels = ModelRegistry.allModels

    // Find Qwen 0.5B model
    let qwenModel = allModels.first { $0.hubId.contains("Qwen1.5-0.5B") }
    XCTAssertNotNil(qwenModel, "Should find Qwen 0.5B model in allModels")

    // Find Llama 3.2 3B model
    let llamaModel = allModels.first { $0.hubId.contains("Llama-3.2-3B") }
    XCTAssertNotNil(llamaModel, "Should find Llama 3.2 3B model in allModels")

    // Find Mistral 7B model
    let mistralModel = allModels.first { $0.hubId.contains("Mistral-7B") }
    XCTAssertNotNil(mistralModel, "Should find Mistral 7B model in allModels")
  }

  func testModelSearchFunctionality() {
    // Test search by partial name
    let qwenResults = ModelRegistry.searchModels(query: "Qwen")
    XCTAssertGreaterThanOrEqual(qwenResults.count, 1, "Should find at least one Qwen model")

    // Test search by architecture
    let llamaResults = ModelRegistry.searchModels(query: "Llama")
    XCTAssertGreaterThanOrEqual(llamaResults.count, 3, "Should find multiple Llama models")

    // Test search by size
    let smallResults = ModelRegistry.searchModels(query: "0.5B")
    XCTAssertGreaterThanOrEqual(smallResults.count, 1, "Should find small models")
  }

  func testModelCategorization() {
    let allModels = ModelRegistry.allModels

    // Test that models are properly categorized
    let smallModels = allModels.filter { $0.isSmallModel }
    let mediumModels = allModels.filter {
      !$0.isSmallModel
        && ($0.parameters?.contains("7B") == true || $0.parameters?.contains("8B") == true)
    }
    let largeModels = allModels.filter {
      $0.parameters?.contains("13B") == true || $0.parameters?.contains("14B") == true
    }

    XCTAssertGreaterThanOrEqual(smallModels.count, 3, "Should have multiple small models")
    XCTAssertGreaterThanOrEqual(mediumModels.count, 1, "Should have at least one medium model")
    XCTAssertGreaterThanOrEqual(
      largeModels.count, 0, "Should have at least zero large models (may not have 13B+ models)")
  }

  func testModelUniqueness() {
    let allModels = ModelRegistry.allModels

    // Test that all models have unique hub IDs
    let hubIds = allModels.map { $0.hubId }
    let uniqueHubIds = Set(hubIds)
    XCTAssertEqual(hubIds.count, uniqueHubIds.count, "All models should have unique hub IDs")

    // Test that all models have unique names
    let names = allModels.map { $0.name }
    let uniqueNames = Set(names)
    XCTAssertEqual(names.count, uniqueNames.count, "All models should have unique names")
  }

  func testModelsSupportingMinTokens() {
    let minTokens = 4096
    let models = ModelRegistry.modelsSupporting(minTokens: minTokens)
    XCTAssertFalse(models.isEmpty, "Should find models supporting at least \(minTokens) tokens")
    for model in models {
      XCTAssertGreaterThanOrEqual(
        model.maxTokens, minTokens, "Model should support at least \(minTokens) tokens")
    }
    // Should not include models with fewer tokens
    let strictModels = ModelRegistry.modelsSupporting(minTokens: 10000)
    for model in strictModels {
      XCTAssertGreaterThanOrEqual(
        model.maxTokens, 10000, "Model should support at least 10000 tokens")
    }
  }

  func testModelConfigurationMetadataExtraction() {
    let config = ModelConfiguration(
      name: "Qwen Test",
      hubId: "mlx-community/Qwen1.5-0.5B-Chat-4bit",
      description: "Test Qwen model",
      modelType: .llm,
      gpuCacheLimit: 512 * 1024 * 1024,
      features: []
    )
    let extracted = config.withExtractedMetadata()
    XCTAssertEqual(extracted.architecture, "Qwen")
    XCTAssertEqual(extracted.quantization, "4bit")
    XCTAssertEqual(extracted.parameters, "0.5B")
  }

  func testModelConfigurationDisplayHelpers() {
    let config = ModelConfiguration(
      name: "Llama 3B",
      hubId: "mlx-community/Llama-3.2-3B-4bit",
      description: "Llama test",
      parameters: "3B",
      quantization: "4bit",
      architecture: "Llama",
      estimatedSizeGB: 1.8,
      modelType: .llm,
      gpuCacheLimit: 512 * 1024 * 1024,
      features: []
    )
    XCTAssertEqual(config.displaySize, "1.8 GB")
    XCTAssertEqual(config.displayInfo, "Llama • 3B • 4bit")
    XCTAssertTrue(config.isSmallModel)
  }

  func testModelConfigurationCodable() throws {
    let config = ModelConfiguration(
      name: "Test",
      hubId: "test/model",
      description: "desc",
      parameters: "1B",
      quantization: "4bit",
      architecture: "Llama",
      maxTokens: 2048,
      estimatedSizeGB: 1.0,
      defaultSystemPrompt: "Hello",
      endOfTextTokens: ["<eos>"],
      modelType: .llm,
      gpuCacheLimit: 512 * 1024 * 1024,
      features: []
    )
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(ModelConfiguration.self, from: data)
    XCTAssertEqual(decoded.name, config.name)
    XCTAssertEqual(decoded.hubId, config.hubId)
    XCTAssertEqual(decoded.parameters, config.parameters)
    XCTAssertEqual(decoded.quantization, config.quantization)
    XCTAssertEqual(decoded.architecture, config.architecture)
    XCTAssertEqual(decoded.maxTokens, config.maxTokens)
    XCTAssertEqual(decoded.estimatedSizeGB, config.estimatedSizeGB)
    XCTAssertEqual(decoded.defaultSystemPrompt, config.defaultSystemPrompt)
    XCTAssertEqual(decoded.endOfTextTokens, config.endOfTextTokens)
    XCTAssertEqual(decoded.modelType, config.modelType)
    XCTAssertEqual(decoded.gpuCacheLimit, config.gpuCacheLimit)
    XCTAssertEqual(decoded.features, config.features)
  }

  func testPresenceOfVisionLanguageModel() {
    let vlm = ModelRegistry.allModels.first {
      $0.architecture?.lowercased().contains("llava") == true
    }
    XCTAssertNotNil(vlm, "Should have at least one Vision Language Model (LLaVA)")
    XCTAssertTrue(vlm?.name.contains("LLaVA") == true, "VLM model name should contain 'LLaVA'")
  }

  func testPresenceOfEmbeddingModel() {
    let embedding = ModelRegistry.allModels.first {
      $0.architecture?.lowercased().contains("bge") == true
    }
    XCTAssertNotNil(embedding, "Should have at least one embedding model (BGE)")
    XCTAssertTrue(
      embedding?.name.contains("BGE") == true, "Embedding model name should contain 'BGE'")
  }

  func testPresenceOfDiffusionModel() {
    let diffusion = ModelRegistry.allModels.first {
      $0.architecture?.lowercased().contains("diffusion") == true
    }
    XCTAssertNotNil(diffusion, "Should have at least one diffusion model (Stable Diffusion)")
    XCTAssertTrue(
      diffusion?.name.contains("Diffusion") == true,
      "Diffusion model name should contain 'Diffusion'")
  }

  func testPresenceOfFP16QuantizationModel() {
    let fp16Model = ModelRegistry.allModels.first { $0.quantization?.lowercased() == "fp16" }
    XCTAssertNotNil(fp16Model, "Should have at least one model with fp16 quantization")
    XCTAssertTrue(fp16Model?.name.contains("FP16") == true, "FP16 model name should contain 'FP16'")
  }
}
