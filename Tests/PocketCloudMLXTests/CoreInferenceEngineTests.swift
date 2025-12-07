// == LLM Context: Bread Crumbs ==
// Module        : Workspace
// File          : pocket-cloud-mlx/Tests/PocketCloudMLXTests/CoreInferenceEngineTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class CoreInferenceEngineTests: XCTestCase {
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

final class CoreInferenceEngineTests: XCTestCase {

    func testInferenceEngineFacadeInitialization() {
        // Test that the engine can be initialized with a model configuration
        let config = ModelConfiguration(
            name: "Test Model",
            hubId: "test-model",
            description: "Test model for unit tests",
            parameters: "1B",
            quantization: "4bit",
            architecture: "llama",
            maxTokens: 128,
            estimatedSizeGB: 1.0,
            modelType: .llm
        )

        let engine = InferenceEngineFacade(config: config)

        XCTAssertEqual(engine.config.name, "Test Model")
        XCTAssertEqual(engine.config.hubId, "test-model")
        XCTAssertFalse(engine.isUnloaded)
    }

    func testInferenceEngineFacadeUnload() {
        // Test that the engine can be unloaded
        let config = ModelConfiguration(
            name: "Test Model",
            hubId: "test-model",
            description: "Test model for unit tests",
            parameters: "1B",
            quantization: "4bit",
            architecture: "llama",
            maxTokens: 128,
            estimatedSizeGB: 1.0,
            modelType: .llm
        )

        let engine = InferenceEngineFacade(config: config)

        // Initially not unloaded
        XCTAssertFalse(engine.isUnloaded)

        // Unload the engine
        engine.unload()

        // Should now be unloaded
        XCTAssertTrue(engine.isUnloaded)
    }

    func testChatMessageCreation() {
        // Test ChatMessage creation
        let systemMessage = ChatMessage(role: .system, content: "You are a helpful assistant")
        XCTAssertEqual(systemMessage.role, .system)
        XCTAssertEqual(systemMessage.content, "You are a helpful assistant")

        let userMessage = ChatMessage(role: .user, content: "Hello")
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(userMessage.content, "Hello")

        let assistantMessage = ChatMessage(role: .assistant, content: "Hi there!")
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.content, "Hi there!")
    }

    func testChatMessageEquality() {
        // Test ChatMessage equality
        let message1 = ChatMessage(role: .user, content: "Hello", timestamp: Date())
        let message2 = ChatMessage(role: .user, content: "Hello", timestamp: Date())

        // Messages should be different due to different UUIDs
        XCTAssertNotEqual(message1, message2)

        // But they should have the same content
        XCTAssertEqual(message1.content, message2.content)
        XCTAssertEqual(message1.role, message2.role)
    }

    func testStaticLoadModel() async throws {
        // Test the static loadModel method
        let config = ModelConfiguration(
            name: "Test Model",
            hubId: "test-model",
            description: "Test model for unit tests",
            parameters: "1B",
            quantization: "4bit",
            architecture: "llama",
            maxTokens: 128,
            estimatedSizeGB: 1.0,
            modelType: .llm
        )

        let engine = try await InferenceEngine.loadModel(config, progress: { _ in })

        XCTAssertEqual(engine.config.name, "Test Model")
        XCTAssertEqual(engine.config.hubId, "test-model")
        XCTAssertFalse(engine.isUnloaded)
    }
}
