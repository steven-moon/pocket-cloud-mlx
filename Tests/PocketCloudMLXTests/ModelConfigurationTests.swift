// == LLM Context: Bread Crumbs ==
// Module        : Workspace
// File          : pocket-cloud-mlx/Tests/PocketCloudMLXTests/ModelConfigurationTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ModelConfigurationTests: XCTestCase {
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

/// Tests for ModelConfiguration creation, validation, and metadata extraction
/// This consolidates ModelConfiguration tests from multiple files
@MainActor
final class ModelConfigurationTests: XCTestCase {

    // MARK: - Basic Configuration Tests

    func testModelConfigurationCreation() {
        let config = ModelConfiguration(
            name: "Test Model",
            hubId: "mock/test-model",
            description: "A test model",
            parameters: "3B",
            quantization: "4bit",
            architecture: "Llama",
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: []
        )

        XCTAssertEqual(config.name, "Test Model")
        XCTAssertEqual(config.hubId, "mock/test-model")
        XCTAssertEqual(config.parameters, "3B")
        XCTAssertEqual(config.quantization, "4bit")
        XCTAssertEqual(config.architecture, "Llama")
    }

    func testModelConfigurationWithDefaults() {
        let config = ModelConfiguration(
            name: "Test Model",
            hubId: "mock/test-model"
        )

        XCTAssertEqual(config.name, "Test Model")
        XCTAssertEqual(config.hubId, "mock/test-model")
        XCTAssertEqual(config.modelType, .llm) // Default value
        XCTAssertEqual(config.gpuCacheLimit, 512 * 1024 * 1024) // Default value
        XCTAssertTrue(config.features.isEmpty)
    }

    // MARK: - Metadata Extraction Tests

    func testModelConfigurationMetadataExtraction() {
        var config = ModelConfiguration(
            name: "Test",
            hubId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: []
        )
        config.extractMetadataFromId()
        XCTAssertEqual(config.parameters, "3B")
        XCTAssertEqual(config.quantization, "4bit")
        XCTAssertEqual(config.architecture, "Llama")
    }

    func testModelConfigurationSmallModelDetection() {
        var smallModel = ModelConfiguration(
            name: "Small",
            hubId: "mock/1B-model",
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: []
        )
        var largeModel = ModelConfiguration(
            name: "Large",
            hubId: "mock/7B-model",
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: []
        )
        smallModel.extractMetadataFromId()
        largeModel.extractMetadataFromId()
        XCTAssertTrue(smallModel.isSmallModel)
        XCTAssertFalse(largeModel.isSmallModel)
    }

    func testModelConfigurationParameterExtraction() {
        let testCases = [
            ("qwen-0.5b", "0.5B"),
            ("llama-1b", "1B"),
            ("mistral-1.5b", "1.5B"),
            ("phi-2b", "2B"),
            ("llama-3b", "3B"),
            ("qwen-7b", "7B"),
            ("llama-13b", "13B"),
        ]

        for (modelId, expected) in testCases {
            var config = ModelConfiguration(
                name: "Test",
                hubId: modelId,
                modelType: .llm
            )
            config.extractMetadataFromId()
            XCTAssertEqual(config.parameters, expected, "Failed for model ID: \(modelId)")
        }
    }

    func testModelConfigurationArchitectureExtraction() {
        let testCases = [
            ("llama-model", "Llama"),
            ("qwen-model", "Qwen"),
            ("mistral-model", "Mistral"),
            ("phi-model", "Phi"),
            ("gemma-model", "Gemma"),
        ]

        for (modelId, expected) in testCases {
            var config = ModelConfiguration(
                name: "Test",
                hubId: modelId,
                modelType: .llm
            )
            config.extractMetadataFromId()
            XCTAssertEqual(config.architecture, expected, "Failed for model ID: \(modelId)")
        }
    }

    func testModelConfigurationQuantizationExtraction() {
        let testCases = [
            ("model-4bit", "4bit"),
            ("model-q4", "4bit"),
            ("model-8bit", "8bit"),
            ("model-q8", "8bit"),
            ("model-fp16", "fp16"),
            ("model-fp32", "fp32"),
        ]

        for (modelId, expected) in testCases {
            var config = ModelConfiguration(
                name: "Test",
                hubId: modelId,
                modelType: .llm
            )
            config.extractMetadataFromId()
            XCTAssertEqual(config.quantization, expected, "Failed for model ID: \(modelId)")
        }
    }

    // MARK: - Validation Tests

    func testModelConfigurationValidation() {
        // Valid configuration
        let validConfig = ModelConfiguration(
            name: "Valid Model",
            hubId: "mlx-community/valid-model",
            modelType: .llm
        )

        XCTAssertFalse(validConfig.name.isEmpty)
        XCTAssertFalse(validConfig.hubId.isEmpty)
        XCTAssertTrue(validConfig.hubId.contains("/"))

        // Invalid configurations should still be creatable but may cause issues
        let invalidConfig = ModelConfiguration(
            name: "",
            hubId: "",
            modelType: .llm
        )

        XCTAssertTrue(invalidConfig.name.isEmpty)
        XCTAssertTrue(invalidConfig.hubId.isEmpty)
    }

    // MARK: - Codable Tests

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

    // MARK: - Display Helpers Tests

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

    // MARK: - Metadata Extraction Tests

    func testModelConfigurationWithExtractedMetadata() {
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

    // MARK: - Model Type Tests

    func testModelConfigurationModelTypes() {
        let llmConfig = ModelConfiguration(
            name: "LLM Model",
            hubId: "test/llm-model",
            modelType: .llm
        )

        let vlmConfig = ModelConfiguration(
            name: "VLM Model",
            hubId: "test/vlm-model",
            modelType: .vlm
        )

        let embedderConfig = ModelConfiguration(
            name: "Embedder Model",
            hubId: "test/embedder-model",
            modelType: .embedding
        )

        let diffusionConfig = ModelConfiguration(
            name: "Diffusion Model",
            hubId: "test/diffusion-model",
            modelType: .diffusion
        )

        XCTAssertEqual(llmConfig.modelType, .llm)
        XCTAssertEqual(vlmConfig.modelType, .vlm)
        XCTAssertEqual(embedderConfig.modelType, .embedding)
        XCTAssertEqual(diffusionConfig.modelType, .diffusion)
    }
}
