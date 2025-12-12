// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUITests/MLXChatAppAdvancedFeaturesTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class MLXChatAppAdvancedFeaturesTests: XCTestCase {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
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
import SwiftUI
@testable import MLXChatApp
@testable import MLXEngine

/// Comprehensive test suite for MLX Chat App advanced features
/// Tests LoRA adapter management, model integration, and real-world functionality
@MainActor
final class MLXChatAppAdvancedFeaturesTests: XCTestCase {
    var chatEngine: ChatEngine!
    var adapterManager: LoRAAdapterManager!
    var testModel: ModelConfiguration!

    override func setUp() async throws {
        // Setup test environment
        chatEngine = await ChatEngine()
        adapterManager = LoRAAdapterManager.shared

        // Use a small test model that can be downloaded quickly
        testModel = ModelConfiguration(
            name: "TinyLlama-1.1B-Chat-v1.0",
            hubId: "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
            description: "Lightweight test model for CI/CD",
            maxTokens: 2048,
            modelType: .llm,
            gpuCacheLimit: 256 * 1024 * 1024,
            features: [.streamingGeneration, .conversationMemory]
        )

        // Set up HuggingFace token if available
        setupHuggingFaceToken()
    }

    override func tearDown() async throws {
        // Clean up after tests
        chatEngine = nil
        adapterManager = nil
        testModel = nil

        // Clean up any downloaded models/adapters
        try? await cleanupTestFiles()
    }

    // MARK: - Environment Setup

    private func setupHuggingFaceToken() {
        // Check for HuggingFace token in environment variables
        if let token = ProcessInfo.processInfo.environment["HUGGINGFACE_TOKEN"] {
            UserDefaults.standard.set(token, forKey: "huggingFaceToken")
            print("✅ HuggingFace token configured for testing")
        } else {
            print("⚠️  No HuggingFace token found - some tests may be skipped")
        }
    }

    private func cleanupTestFiles() async throws {
        // Clean up test models and adapters
        let fileManager = FileManagerService.shared
        let modelsDir = try fileManager.getModelsDirectory()
        let adaptersDir = modelsDir.appendingPathComponent("adapters")

        if FileManager.default.fileExists(atPath: adaptersDir.path) {
            try FileManager.default.removeItem(at: adaptersDir)
        }
    }

    // MARK: - LoRA Adapter Management Tests

    /// Test LoRA adapter discovery and loading
    func testLoRAAdapterDiscovery() async throws {
        print("🧪 Testing LoRA adapter discovery...")

        // Load available adapters
        await adapterManager.loadAdapters()

        // Verify adapters were loaded
        XCTAssertFalse(adapterManager.availableAdapters.isEmpty,
                      "Should have discovered available adapters")

        // Check that we have at least one adapter
        let adapters = adapterManager.availableAdapters
        XCTAssertGreaterThan(adapters.count, 0, "Should have at least one adapter")

        // Verify adapter structure
        if let firstAdapter = adapters.first {
            XCTAssertFalse(firstAdapter.name.isEmpty, "Adapter should have a name")
            XCTAssertFalse(firstAdapter.description.isEmpty, "Adapter should have a description")
            XCTAssertNotNil(firstAdapter.config, "Adapter should have configuration")
        }

        print("✅ LoRA adapter discovery test passed")
    }

    /// Test LoRA adapter download functionality
    func testLoRAAdapterDownload() async throws {
        print("🧪 Testing LoRA adapter download...")

        // Skip if no HuggingFace token
        guard UserDefaults.standard.string(forKey: "huggingFaceToken") != nil else {
            throw XCTSkip("HuggingFace token required for adapter download tests")
        }

        // Load available adapters first
        await adapterManager.loadAdapters()

        // Find a small adapter to download for testing
        guard let testAdapter = adapterManager.availableAdapters.first(where: { adapter in
            adapter.size < 100 * 1024 * 1024 // Less than 100MB for testing
        }) else {
            throw XCTSkip("No suitable test adapter found")
        }

        print("📥 Downloading adapter: \(testAdapter.name)")

        // Download the adapter
        try await adapterManager.downloadAdapter(testAdapter) { progress in
            print("Download progress: \(Int(progress * 100))%")
        }

        // Verify adapter was downloaded
        XCTAssertTrue(testAdapter.isDownloaded, "Adapter should be marked as downloaded")
        XCTAssertNotNil(testAdapter.localPath, "Adapter should have local path")

        // Verify adapter appears in downloaded list
        await adapterManager.loadAdapters() // Refresh
        XCTAssertTrue(adapterManager.downloadedAdapters.contains(where: { $0.id == testAdapter.id }),
                     "Adapter should appear in downloaded list")

        print("✅ LoRA adapter download test passed")
    }

    /// Test LoRA adapter application to chat session
    func testLoRAAdapterApplication() async throws {
        print("🧪 Testing LoRA adapter application...")

        // First ensure we have a downloaded adapter
        await adapterManager.loadAdapters()

        guard let downloadedAdapter = adapterManager.downloadedAdapters.first else {
            throw XCTSkip("No downloaded adapter available - run download test first")
        }

        // Select the test model in chat engine
        chatEngine.selectedModel = testModel

        // Apply the adapter
        try await adapterManager.applyAdapter(downloadedAdapter)

        // Verify adapter is active
        XCTAssertEqual(adapterManager.activeAdapter?.id, downloadedAdapter.id,
                      "Adapter should be active")

        print("✅ LoRA adapter application test passed")
    }

    /// Test LoRA adapter compatibility checking
    func testLoRAAdapterCompatibility() async throws {
        print("🧪 Testing LoRA adapter compatibility...")

        await adapterManager.loadAdapters()

        // Test with compatible model
        chatEngine.selectedModel = testModel

        for adapter in adapterManager.downloadedAdapters {
            let isCompatible = adapterManager.isAdapterCompatible(adapter, with: testModel)
            if isCompatible {
                print("✅ Adapter '\(adapter.name)' is compatible with \(testModel.name)")
            }
        }

        print("✅ LoRA adapter compatibility test passed")
    }

    // MARK: - Model Integration Tests

    /// Test model download and loading
    func testModelDownloadAndLoading() async throws {
        print("🧪 Testing model download and loading...")

        // Skip if no HuggingFace token
        guard UserDefaults.standard.string(forKey: "huggingFaceToken") != nil else {
            throw XCTSkip("HuggingFace token required for model download tests")
        }

        // Create model downloader
        let modelDownloader = ModelDownloader()

        print("📥 Downloading test model: \(testModel.name)")

        // Download the model
        let modelsDir = try FileManagerService.shared.getModelsDirectory()
        let modelDir = modelsDir.appendingPathComponent(testModel.hubId)

        try await modelDownloader.downloadModel(
            from: URL(string: "https://huggingface.co/\(testModel.hubId)/resolve/main")!,
            to: modelDir
        ) { progress in
            print("Model download progress: \(Int(progress * 100))%")
        }

        // Verify model was downloaded
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelDir.path),
                     "Model directory should exist")

        print("✅ Model download test passed")
    }

    /// Test chat functionality with downloaded model
    func testChatWithModel() async throws {
        print("🧪 Testing chat functionality...")

        // Select the test model
        chatEngine.selectedModel = testModel

        // Send a test message
        let testPrompt = "Hello, this is a test message for the MLX Chat App."
        let response = try await chatEngine.generate(prompt: testPrompt)

        // Verify response
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
        XCTAssertGreaterThan(response.count, 10, "Response should be substantial")

        // Verify message history
        let messages = chatEngine.messages
        XCTAssertEqual(messages.count, 2, "Should have user and assistant messages")
        XCTAssertEqual(messages[0].content, testPrompt, "First message should be user prompt")
        XCTAssertEqual(messages[1].content, response, "Second message should be assistant response")

        print("✅ Chat functionality test passed")
        print("🤖 Response preview: \(response.prefix(100))...")
    }

    /// Test streaming chat functionality
    func testStreamingChat() async throws {
        print("🧪 Testing streaming chat functionality...")

        chatEngine.selectedModel = testModel

        let testPrompt = "Tell me about artificial intelligence in 3 sentences."
        var receivedChunks = [String]()
        var finalResponse = ""

        let stream = try await chatEngine.generateStream(prompt: testPrompt)

        for try await chunk in stream {
            receivedChunks.append(chunk)
            finalResponse += chunk
        }

        // Verify streaming worked
        XCTAssertFalse(receivedChunks.isEmpty, "Should receive streaming chunks")
        XCTAssertFalse(finalResponse.isEmpty, "Final response should not be empty")

        print("✅ Streaming chat test passed")
        print("📊 Received \(receivedChunks.count) chunks, total length: \(finalResponse.count)")
    }

    // MARK: - UI Component Tests

    /// Test LoRA adapter view model functionality
    func testLoRAAdapterViewModel() async throws {
        print("🧪 Testing LoRA adapter view model...")

        let viewModel = LoRAAdapterViewModel()

        // Test loading
        await viewModel.loadAdapters()

        // Verify state updates
        XCTAssertFalse(viewModel.availableAdapters.isEmpty,
                      "ViewModel should have available adapters")

        // Test filtering
        viewModel.searchText = "medical"
        let filteredAdapters = viewModel.filteredAdapters()

        // Verify filtering works
        for adapter in filteredAdapters {
            let matchesSearch = adapter.name.localizedCaseInsensitiveContains("medical") ||
                               adapter.description.localizedCaseInsensitiveContains("medical")
            XCTAssertTrue(matchesSearch, "Filtered results should match search term")
        }

        print("✅ LoRA adapter view model test passed")
    }

    /// Test chat engine document processing
    func testDocumentProcessing() async throws {
        print("🧪 Testing document processing...")

        // Create a test document
        let testContent = "This is a test document for MLX Chat App processing."
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test-document.txt")

        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        // Process the document
        await chatEngine.handlePickedDocument(url: testFile)

        // Verify document was processed
        XCTAssertNotNil(chatEngine.pickedDocumentPreview, "Document preview should be set")
        XCTAssertEqual(chatEngine.pickedDocumentPreview?.content, testContent,
                      "Document content should be extracted correctly")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)

        print("✅ Document processing test passed")
    }

    // MARK: - Integration Tests

    /// Comprehensive integration test
    func testFullIntegrationFlow() async throws {
        print("🧪 Testing full integration flow...")

        // Skip if no HuggingFace token
        guard UserDefaults.standard.string(forKey: "huggingFaceToken") != nil else {
            throw XCTSkip("HuggingFace token required for full integration tests")
        }

        // 1. Load adapters
        await adapterManager.loadAdapters()
        XCTAssertFalse(adapterManager.availableAdapters.isEmpty,
                      "Should have available adapters")

        // 2. Download a small adapter
        if let smallAdapter = adapterManager.availableAdapters.first(where: { $0.size < 50 * 1024 * 1024 }) {
            try await adapterManager.downloadAdapter(smallAdapter) { progress in
                print("Integration test download progress: \(Int(progress * 100))%")
            }
            XCTAssertTrue(smallAdapter.isDownloaded, "Adapter should be downloaded")
        }

        // 3. Test chat functionality
        chatEngine.selectedModel = testModel
        let testResponse = try await chatEngine.generate(prompt: "Integration test message")
        XCTAssertFalse(testResponse.isEmpty, "Should get response from model")

        print("✅ Full integration flow test passed")
    }

    /// Test performance and memory usage
    func testPerformanceMetrics() async throws {
        print("🧪 Testing performance metrics...")

        chatEngine.selectedModel = testModel

        // Measure chat response time
        let startTime = Date()
        let response = try await chatEngine.generate(prompt: "Performance test message")
        let endTime = Date()

        let responseTime = endTime.timeIntervalSince(startTime)
        print("⚡ Response time: \(String(format: "%.2f", responseTime)) seconds")
        print("📏 Response length: \(response.count) characters")

        // Basic performance assertions
        XCTAssertLessThan(responseTime, 30.0, "Response should be reasonably fast")
        XCTAssertGreaterThan(response.count, 0, "Response should not be empty")

        print("✅ Performance metrics test passed")
    }

    // MARK: - Error Handling Tests

    /// Test error handling for invalid adapters
    func testErrorHandling() async throws {
        print("🧪 Testing error handling...")

        // Test with invalid adapter
        let invalidAdapter = LoRAAdapter(
            id: "invalid-adapter",
            name: "Invalid Adapter",
            description: "This adapter doesn't exist",
            author: "test",
            baseModel: "invalid/model",
            size: 0,
            downloadURL: URL(string: "https://invalid-url.com"),
            localPath: nil,
            config: LoRAAdapterConfig(
                name: "Invalid Adapter",
                description: "This adapter doesn't exist",
                author: "test",
                baseModel: "invalid/model",
                r: 8,
                alpha: 16,
                dropout: 0.1
            )
        )

        // Should handle error gracefully
        do {
            try await adapterManager.downloadAdapter(invalidAdapter) { _ in }
            XCTFail("Should have thrown an error for invalid adapter")
        } catch {
            print("✅ Correctly handled error: \(error.localizedDescription)")
        }

        print("✅ Error handling test passed")
    }
}

// MARK: - Test Helpers

extension MLXChatAppAdvancedFeaturesTests {
    /// Helper to wait for async operations in tests
    func waitForAsync(_ operation: @escaping () async throws -> Void) async throws {
        try await operation()
    }

    /// Helper to verify model files exist
    func verifyModelFiles(at path: URL) throws {
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: path.path),
                     "Model directory should exist")

        let contents = try fileManager.contentsOfDirectory(atPath: path.path)
        XCTAssertFalse(contents.isEmpty, "Model directory should not be empty")

        print("📁 Model files verified: \(contents.count) files")
    }
}

// MARK: - Test Configuration

extension ProcessInfo {
    /// Check if we're running in CI environment
    var isCI: Bool {
        environment["CI"] == "true"
    }

    /// Check if real model tests are enabled
    var shouldRunRealModelTests: Bool {
        environment["RUN_REAL_MODEL_TESTS"] == "true"
    }

    /// Get HuggingFace token from environment
    var huggingFaceToken: String? {
        environment["HUGGINGFACE_TOKEN"]
    }
}
