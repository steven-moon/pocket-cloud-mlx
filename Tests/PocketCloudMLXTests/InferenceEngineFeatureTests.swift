// == LLM Context: Bread Crumbs ==
// Module        : Workspace
// File          : pocket-cloud-mlx/Tests/PocketCloudMLXTests/InferenceEngineFeatureTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class InferenceEngineFeatureTests: XCTestCase {
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

#if canImport(MLX)
import MLX
#endif

/// Tests for InferenceEngine feature detection and advanced capabilities
@MainActor
final class InferenceEngineFeatureTests: XCTestCase {
    private var engine: InferenceEngine!
    
    override func setUp() async throws {
        let config = ModelConfiguration(
            name: "Feature Test Model",
            hubId: "mock/feature-model",
            description: "Test model for feature testing",
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: []
        )

        engine = try await InferenceEngine.loadModel(config) { _ in }
    }
    
    override func tearDown() async throws {
        engine?.unload()
        engine = nil
    }
    
    // MARK: - Feature Detection Tests
    
    func testSupportedFeaturesNotEmpty() {
        let features = InferenceEngine.supportedFeatures
        XCTAssertFalse(features.isEmpty, "Supported features should not be empty")
    }
    
    func testCoreFeatureSupport() {
        let features = InferenceEngine.supportedFeatures
        
        // Core features should always be available
        XCTAssertTrue(features.contains(.streamingGeneration), "Streaming generation should be supported")
        XCTAssertTrue(features.contains(.conversationMemory), "Conversation memory should be supported")
        XCTAssertTrue(features.contains(.performanceMonitoring), "Performance monitoring should be supported")
        XCTAssertTrue(features.contains(.customPrompts), "Custom prompts should be supported")
    }
    
    func testMLXSpecificFeatures() {
        let features = InferenceEngine.supportedFeatures
        
        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
        // MLX-specific features should be available when MLX is imported
        XCTAssertTrue(features.contains(.modelCaching), "Model caching should be supported with MLX")
        XCTAssertTrue(features.contains(.customTokenizers), "Custom tokenizers should be supported with MLX")
        XCTAssertTrue(features.contains(.quantizationSupport), "Quantization should be supported with MLX")
        XCTAssertTrue(features.contains(.secureModelLoading), "Secure model loading should be supported with MLX")
        #endif
    }
    
    func testOptionalFeatures() {
        let features = InferenceEngine.supportedFeatures
        
        #if canImport(MLXVLM)
        XCTAssertTrue(features.contains(.visionLanguageModels), "VLM should be supported when MLXVLM is available")
        XCTAssertTrue(features.contains(.multiModalInput), "Multi-modal input should be supported when MLXVLM is available")
        #endif
        
        #if canImport(MLXEmbedders)
        XCTAssertTrue(features.contains(.embeddingModels), "Embedding models should be supported when MLXEmbedders is available")
        XCTAssertTrue(features.contains(.batchProcessing), "Batch processing should be supported when MLXEmbedders is available")
        #endif
        
        #if canImport(StableDiffusion)
        XCTAssertTrue(features.contains(.diffusionModels), "Diffusion models should be supported when StableDiffusion is available")
        #endif
    }
    
    func testFeatureDetectionConsistency() {
        // Test that feature detection is consistent across multiple calls
        let features1 = InferenceEngine.supportedFeatures
        let features2 = InferenceEngine.supportedFeatures
        
        XCTAssertEqual(features1, features2, "Feature detection should be consistent")
    }
    
    // MARK: - LoRA Adapter Tests
    
    func testLoRAAdapterNotSupported() async throws {
        let features = InferenceEngine.supportedFeatures
        
        if !features.contains(.loraAdapters) {
            // Test that LoRA methods throw appropriate errors when not supported
            let testURL = URL(fileURLWithPath: "/tmp/test-lora.bin")
            
            do {
                try await engine.loadLoRAAdapter(from: testURL)
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.contains("LoRA adapters"), "Error message should mention LoRA adapters")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
            
            do {
                try engine.applyLoRAAdapter(named: "test-adapter")
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.contains("LoRA adapters"), "Error message should mention LoRA adapters")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Quantization Tests
    
    func testQuantizationSupport() async throws {
        let features = InferenceEngine.supportedFeatures
        
        if features.contains(.quantizationSupport) {
            // Test that quantization methods can be called (even if not implemented)
            do {
                try await engine.loadQuantization("4bit")
                XCTFail("Should have thrown not implemented error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                let lower = message.lowercased()
                XCTAssertTrue(
                    lower.contains("not implemented") || lower.contains("not supported"),
                    "Error message should mention feature not available"
                )
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        } else {
            do {
                try await engine.loadQuantization("4bit")
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.lowercased().contains("quantization"), "Error message should mention quantization")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Vision Language Model Tests
    
    func testVisionLanguageModelSupport() async throws {
        let features = InferenceEngine.supportedFeatures
        
        if features.contains(.visionLanguageModels) {
            // Test that VLM methods can be called (even if not implemented)
            do {
                try await engine.loadVisionLanguageModel()
                XCTFail("Should have thrown not implemented error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                let lower = message.lowercased()
                XCTAssertTrue(
                    lower.contains("not implemented") || lower.contains("not supported"),
                    "Error message should mention feature not available"
                )
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        } else {
            do {
                try await engine.loadVisionLanguageModel()
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.lowercased().contains("vision"), "Error message should mention vision-language")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Embedding Model Tests
    
    func testEmbeddingModelSupport() async throws {
        let features = InferenceEngine.supportedFeatures
        
        if features.contains(.embeddingModels) {
            // Test that embedding methods can be called (even if not implemented)
            do {
                try await engine.loadEmbeddingModel()
                XCTFail("Should have thrown not implemented error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.contains("not implemented"), "Error message should mention not implemented")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        } else {
            do {
                try await engine.loadEmbeddingModel()
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.contains("Embedding"), "Error message should mention embedding")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Diffusion Model Tests
    
    func testDiffusionModelSupport() async throws {
        let features = InferenceEngine.supportedFeatures
        
        if features.contains(.diffusionModels) {
            // Test that diffusion methods can be called (even if not implemented)
            do {
                try await engine.loadDiffusionModel()
                XCTFail("Should have thrown not implemented error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.contains("not implemented"), "Error message should mention not implemented")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        } else {
            do {
                try await engine.loadDiffusionModel()
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.contains("Diffusion"), "Error message should mention diffusion")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Custom Prompts Tests
    
    func testCustomPromptSupport() throws {
        let features = InferenceEngine.supportedFeatures
        
        if features.contains(.customPrompts) {
            // Test that custom prompt methods can be called (even if not implemented)
            do {
                try engine.setCustomPrompt("You are a helpful assistant")
                XCTFail("Should have thrown not implemented error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                let lower = message.lowercased()
                XCTAssertTrue(
                    lower.contains("not implemented") || lower.contains("not supported"),
                    "Error message should mention feature not available"
                )
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        } else {
            do {
                try engine.setCustomPrompt("You are a helpful assistant")
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.lowercased().contains("custom"), "Error message should mention custom prompts")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Multi-Modal Input Tests
    
    func testMultiModalInputSupport() async throws {
        let features = InferenceEngine.supportedFeatures
        
        if features.contains(.multiModalInput) {
            // Test that multi-modal methods can be called (even if not implemented)
            do {
                try await engine.loadMultiModalInput()
                XCTFail("Should have thrown not implemented error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                let lower = message.lowercased()
                XCTAssertTrue(
                    lower.contains("not implemented") || lower.contains("not supported"),
                    "Error message should mention feature not available"
                )
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        } else {
            do {
                try await engine.loadMultiModalInput()
                XCTFail("Should have thrown feature not supported error")
            } catch PocketCloudMLXError.featureNotSupported(let message) {
                XCTAssertTrue(message.lowercased().contains("multi"), "Error message should mention multi-modal")
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Health Monitoring Tests
    
    func testEngineHealthMonitoring() {
        // Test that engine health can be monitored
        let health = engine.health
        XCTAssertNotEqual(health, .unhealthy, "Engine should be healthy after successful loading")
        
        // Test health after unloading
        engine.unload()
        let unhealthyHealth = engine.health
        XCTAssertEqual(unhealthyHealth, .unhealthy, "Engine should be unhealthy after unloading")
    }
    
    // MARK: - Performance Tests
    
    func testFeatureDetectionPerformance() {
        // Test that feature detection is fast
        let startTime = Date()
        let iterations = 1000
        
        for _ in 0..<iterations {
            _ = InferenceEngine.supportedFeatures
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should be able to do 1000 feature detections in under 1 second
        XCTAssertLessThan(duration, 1.0, "Feature detection should be fast")
    }
} 
