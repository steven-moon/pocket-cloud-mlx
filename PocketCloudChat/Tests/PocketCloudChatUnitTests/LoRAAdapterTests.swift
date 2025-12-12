// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUnitTests/LoRAAdapterTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class LoRAAdapterTests: XCTestCase {
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
@testable import PocketChat
@testable import PocketCloudMLX

/// Unit tests for LoRA adapter functionality
/// Tests adapter loading, application, training, and management
class LoRAAdapterTests: XCTestCase {

    private var chatEngine: ChatEngine!
    private var mockLLMEngine: MockLLMEngine!
    private let testTimeout: TimeInterval = 30.0

    override func setUp() async throws {
        // Use real engine by default, only use mock if explicitly requested
        let useMockTests = ProcessInfo.processInfo.environment["FORCE_MOCK_TESTS"] == "true"

        if useMockTests {
            mockLLMEngine = MockLLMEngine()
            mockLLMEngine.supportedFeatures = [.loraAdapters, .modelTraining]
            chatEngine = try await ChatEngine(llmEngine: mockLLMEngine)
        } else {
            // Use real MLX engine for testing
            let config = ModelConfiguration(
                name: "SmolLM2 Test",
                hubId: "mlx-community/SmolLM2-360M-Instruct",
                description: "Real MLX model for testing (DEFAULT)",
                modelType: .llm,
                gpuCacheLimit: 512 * 1024 * 1024,
                features: [.loraAdapters, .modelTraining]
            )
            let realEngine = try await InferenceEngine.loadModel(config) { _ in }
            chatEngine = try await ChatEngine(llmEngine: realEngine)
        }
    }

    override func tearDown() async throws {
        await chatEngine?.cancelAllTasks()
        chatEngine = nil
        mockLLMEngine = nil
    }

    // MARK: - LoRA Adapter Loading

    func testLoRAAdapterLoading() async throws {
        let adapterURL = URL(string: "https://example.com/test-adapter.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapterURL)

        XCTAssertTrue(mockLLMEngine.loRAAdapterLoaded)
        XCTAssertEqual(mockLLMEngine.lastLoadedAdapterURL, adapterURL)
    }

    func testLoRAAdapterWithCustomBaseModel() async throws {
        let adapterURL = URL(string: "https://example.com/custom-adapter.safetensors")!
        let baseModel = ModelConfiguration(
            name: "Base Model",
            hubId: "custom/base",
            description: "Custom base model",
            maxTokens: 512,
            modelType: .llm,
            gpuCacheLimit: 1024 * 1024 * 1024,
            features: [.loraAdapters]
        )

        try await chatEngine.loadLoRAAdapter(from: adapterURL, baseModel: baseModel)

        XCTAssertTrue(mockLLMEngine.loRAAdapterLoaded)
        XCTAssertEqual(mockLLMEngine.adapterBaseModel?.name, "Base Model")
    }

    func testLoRAAdapterCompatibilityCheck() async throws {
        mockLLMEngine.shouldThrowLoRAError = true
        let incompatibleAdapterURL = URL(string: "https://example.com/incompatible-adapter.safetensors")!

        do {
            try await chatEngine.loadLoRAAdapter(from: incompatibleAdapterURL)
            XCTFail("Expected LoRAError to be thrown")
        } catch let error as LoRAError {
            XCTAssertEqual(error, .incompatibleModel)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - LoRA Adapter Application

    func testLoRAAdapterApplication() async throws {
        let adapterURL = URL(string: "https://example.com/adapter.safetensors")!
        let adapterName = "test-adapter"

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        try await chatEngine.applyLoRAAdapter(named: adapterName)

        XCTAssertTrue(mockLLMEngine.adapterAppliedDuringGeneration)
        XCTAssertEqual(mockLLMEngine.lastAppliedAdapterName, adapterName)
    }

    func testLoRAAdapterSwitching() async throws {
        let adapter1URL = URL(string: "https://example.com/adapter1.safetensors")!
        let adapter2URL = URL(string: "https://example.com/adapter2.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapter1URL)
        try await chatEngine.applyLoRAAdapter(named: "adapter1")

        try await chatEngine.loadLoRAAdapter(from: adapter2URL)
        try await chatEngine.applyLoRAAdapter(named: "adapter2")

        XCTAssertEqual(mockLLMEngine.lastAppliedAdapterName, "adapter2")
        XCTAssertTrue(mockLLMEngine.adapterSwitched)
    }

    func testLoRAAdapterWithGeneration() async throws {
        let adapterURL = URL(string: "https://example.com/adapter.safetensors")!
        let prompt = "Generate text with LoRA adapter"

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        let response = try await chatEngine.generateResponse(prompt)

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(mockLLMEngine.adapterAppliedDuringGeneration)
    }

    func testLoRAAdapterRemoval() async throws {
        let adapterURL = URL(string: "https://example.com/adapter.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        XCTAssertTrue(mockLLMEngine.loRAAdapterLoaded)

        try await chatEngine.unloadLoRAAdapter()
        XCTAssertTrue(mockLLMEngine.adapterUnloaded)
    }

    // MARK: - LoRA Training

    func testLoRATrainingInitiation() async throws {
        let trainingData = [
            "input1": "output1",
            "input2": "output2",
            "input3": "output3"
        ]

        try await chatEngine.startLoRATraining(with: trainingData)

        XCTAssertTrue(mockLLMEngine.trainingStarted)
        XCTAssertEqual(mockLLMEngine.trainingDataCount, trainingData.count)
    }

    func testLoRATrainingProgress() async throws {
        let trainingData = ["train": "data"]

        try await chatEngine.startLoRATraining(with: trainingData)

        let progress = chatEngine.trainingProgress
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
        XCTAssertTrue(mockLLMEngine.trainingProgressMonitored)
    }

    func testLoRATrainingCancellation() async throws {
        let trainingData = ["train": "data"]

        try await chatEngine.startLoRATraining(with: trainingData)
        await chatEngine.cancelTraining()

        XCTAssertTrue(mockLLMEngine.trainingCancelled)
    }

    func testLoRATrainingCompletion() async throws {
        let trainingData = ["input": "output"]
        let expectedAdapterURL = URL(string: "https://example.com/trained-adapter.safetensors")!

        mockLLMEngine.trainingCompletionURL = expectedAdapterURL
        try await chatEngine.startLoRATraining(with: trainingData)

        // Simulate training completion
        mockLLMEngine.completeTraining()

        XCTAssertTrue(mockLLMEngine.trainingCompleted)
        XCTAssertEqual(mockLLMEngine.trainedAdapterURL, expectedAdapterURL)
    }

    // MARK: - LoRA Adapter Discovery

    func testLoRAAdapterDiscovery() async throws {
        let adapters = try await chatEngine.discoverLoRAAdapters()

        XCTAssertFalse(adapters.isEmpty)
        XCTAssertTrue(mockLLMEngine.adaptersDiscovered)
        XCTAssertGreaterThan(mockLLMEngine.discoveredAdaptersCount, 0)
    }

    func testLoRAAdapterFiltering() async throws {
        let category = "medical"
        let adapters = try await chatEngine.discoverLoRAAdapters(category: category)

        XCTAssertFalse(adapters.isEmpty)
        XCTAssertTrue(mockLLMEngine.adaptersFiltered)
        XCTAssertEqual(mockLLMEngine.filterCategory, category)
    }

    func testLoRAAdapterSearch() async throws {
        let searchQuery = "medical assistant"
        let adapters = try await chatEngine.searchLoRAAdapters(query: searchQuery)

        XCTAssertFalse(adapters.isEmpty)
        XCTAssertTrue(mockLLMEngine.adaptersSearched)
        XCTAssertEqual(mockLLMEngine.searchQuery, searchQuery)
    }

    // MARK: - LoRA Adapter Metadata

    func testLoRAAdapterMetadata() async throws {
        let adapterURL = URL(string: "https://example.com/metadata-adapter.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        let metadata = try await chatEngine.getLoRAAdapterMetadata()

        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata["name"])
        XCTAssertNotNil(metadata["description"])
        XCTAssertNotNil(metadata["baseModel"])
        XCTAssertTrue(mockLLMEngine.adapterMetadataRetrieved)
    }

    func testLoRAAdapterCompatibilityInfo() async throws {
        let adapterURL = URL(string: "https://example.com/compatibility-adapter.safetensors")!
        let model = ModelConfiguration(
            name: "Test Model",
            hubId: "test/model",
            description: "Test model",
            maxTokens: 128,
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: [.loraAdapters]
        )

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        let isCompatible = try await chatEngine.isLoRAAdapterCompatible(adapterURL, with: model)

        XCTAssertTrue(isCompatible)
        XCTAssertTrue(mockLLMEngine.compatibilityChecked)
    }

    // MARK: - LoRA Performance

    func testLoRAAdapterPerformanceImpact() async throws {
        let adapterURL = URL(string: "https://example.com/performance-adapter.safetensors")!
        let prompt = "Test performance with adapter"

        // Baseline performance (no adapter)
        let baselineStart = Date()
        _ = try await chatEngine.generateResponse(prompt)
        let baselineTime = Date().timeIntervalSince(baselineStart)

        // Performance with adapter
        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        let adapterStart = Date()
        _ = try await chatEngine.generateResponse(prompt)
        let adapterTime = Date().timeIntervalSince(adapterStart)

        // Adapter should not drastically reduce performance
        XCTAssertLessThan(adapterTime, baselineTime * 3.0)
        XCTAssertTrue(mockLLMEngine.adapterPerformanceTested)
    }

    func testLoRAAdapterMemoryUsage() async throws {
        let adapterURL = URL(string: "https://example.com/memory-test-adapter.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapterURL)

        XCTAssertTrue(mockLLMEngine.adapterMemoryUsageTracked)
        XCTAssertGreaterThan(mockLLMEngine.adapterMemoryUsage, 0)
    }

    func testLoRAAdapterBenchmark() async throws {
        let adapterURL = URL(string: "https://example.com/benchmark-adapter.safetensors")!
        let prompts = ["Prompt 1", "Prompt 2", "Prompt 3"]

        try await chatEngine.loadLoRAAdapter(from: adapterURL)

        let results = try await chatEngine.benchmarkLoRAAdapter(prompts: prompts)

        XCTAssertEqual(results.count, prompts.count)
        XCTAssertTrue(mockLLMEngine.adapterBenchmarked)
    }

    // MARK: - LoRA Adapter Management

    func testMultipleAdapterManagement() async throws {
        let adapterURLs = [
            URL(string: "https://example.com/adapter1.safetensors")!,
            URL(string: "https://example.com/adapter2.safetensors")!,
            URL(string: "https://example.com/adapter3.safetensors")!
        ]

        for url in adapterURLs {
            try await chatEngine.loadLoRAAdapter(from: url)
        }

        XCTAssertEqual(mockLLMEngine.loadedAdaptersCount, adapterURLs.count)

        let loadedAdapters = try await chatEngine.listLoadedAdapters()
        XCTAssertEqual(loadedAdapters.count, adapterURLs.count)
    }

    func testAdapterPersistence() async throws {
        let adapterURL = URL(string: "https://example.com/persistent-adapter.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        try await chatEngine.saveAdapterConfiguration()

        XCTAssertTrue(mockLLMEngine.adapterConfigurationSaved)

        // Simulate app restart
        let newChatEngine = ChatEngine(llmEngine: MockLLMEngine())
        try await newChatEngine.loadAdapterConfiguration()

        XCTAssertTrue(mockLLMEngine.adapterConfigurationLoaded)
    }

    func testAdapterValidation() async throws {
        let invalidAdapterURL = URL(string: "https://example.com/invalid-adapter.txt")!

        do {
            try await chatEngine.loadLoRAAdapter(from: invalidAdapterURL)
            XCTFail("Expected validation error")
        } catch let error as LoRAError {
            XCTAssertEqual(error, .invalidFormat)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Error Handling

    func testLoRAErrorHandling() async throws {
        mockLLMEngine.shouldThrowLoRAError = true
        let adapterURL = URL(string: "https://example.com/error-adapter.safetensors")!

        do {
            try await chatEngine.loadLoRAAdapter(from: adapterURL)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is LoRAError)
            XCTAssertTrue(mockLLMEngine.errorHandled)
        }
    }

    func testLoRARecovery() async throws {
        mockLLMEngine.shouldThrowLoRAError = true

        do {
            _ = try await chatEngine.loadLoRAAdapter(from: URL(string: "https://example.com/test")!)
            XCTFail("Expected error")
        } catch {
            // Verify error recovery
            let recovered = await chatEngine.attemptLoRARecovery()
            XCTAssertTrue(recovered)
            XCTAssertTrue(mockLLMEngine.recoveryAttempted)
        }
    }

    // MARK: - Integration Tests

    func testLoRAWithStreaming() async throws {
        let adapterURL = URL(string: "https://example.com/streaming-adapter.safetensors")!
        let prompt = "Stream with LoRA adapter"

        try await chatEngine.loadLoRAAdapter(from: adapterURL)

        var receivedChunks: [String] = []
        let expectation = XCTestExpectation(description: "Streaming with adapter")

        let task = Task {
            var chunkCount = 0
            for try await chunk in chatEngine.streamResponse(prompt) {
                receivedChunks.append(chunk)
                chunkCount += 1
                if chunkCount >= 3 {
                    expectation.fulfill()
                    break
                }
            }
        }

        await fulfillment(of: [expectation], timeout: testTimeout)

        XCTAssertFalse(receivedChunks.isEmpty)
        XCTAssertTrue(mockLLMEngine.adapterUsedInStreaming)
    }

    func testLoRAWithBatchGeneration() async throws {
        let adapterURL = URL(string: "https://example.com/batch-adapter.safetensors")!
        let prompts = ["Prompt 1", "Prompt 2", "Prompt 3"]

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        let responses = try await chatEngine.generateBatch(prompts: prompts)

        XCTAssertEqual(responses.count, prompts.count)
        XCTAssertTrue(mockLLMEngine.adapterUsedInBatch)
    }

    func testLoRAWithVision() async throws {
        let adapterURL = URL(string: "https://example.com/vision-adapter.safetensors")!
        let image = UIImage(systemName: "star")!
        let prompt = "Analyze this image with LoRA adapter"

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        let response = try await chatEngine.generateWithVision(image: image, prompt: prompt)

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(mockLLMEngine.adapterUsedWithVision)
    }

    // MARK: - Advanced LoRA Features

    func testLoRAAdapterComposition() async throws {
        let adapter1URL = URL(string: "https://example.com/adapter1.safetensors")!
        let adapter2URL = URL(string: "https://example.com/adapter2.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapter1URL)
        try await chatEngine.loadLoRAAdapter(from: adapter2URL)

        try await chatEngine.composeAdapters(["adapter1", "adapter2"])

        XCTAssertTrue(mockLLMEngine.adaptersComposed)
        XCTAssertEqual(mockLLMEngine.composedAdapterCount, 2)
    }

    func testLoRAAdapterFineTuning() async throws {
        let baseAdapterURL = URL(string: "https://example.com/base-adapter.safetensors")!
        let fineTuneData = ["additional": "training data"]

        try await chatEngine.loadLoRAAdapter(from: baseAdapterURL)
        try await chatEngine.fineTuneAdapter(with: fineTuneData)

        XCTAssertTrue(mockLLMEngine.adapterFineTuned)
        XCTAssertEqual(mockLLMEngine.fineTuneDataCount, fineTuneData.count)
    }

    func testLoRAAdapterVersioning() async throws {
        let adapterURL = URL(string: "https://example.com/versioned-adapter.safetensors")!

        try await chatEngine.loadLoRAAdapter(from: adapterURL)
        try await chatEngine.createAdapterVersion("v2.0")
        try await chatEngine.switchAdapterVersion("v2.0")

        XCTAssertEqual(chatEngine.currentAdapterVersion, "v2.0")
        XCTAssertTrue(mockLLMEngine.adapterVersioned)
    }

    // MARK: - Security & Privacy

    func testLoRAAdapterSecurity() async throws {
        let adapterURL = URL(string: "https://example.com/secure-adapter.safetensors")!
        mockLLMEngine.shouldValidateSignature = true

        try await chatEngine.loadLoRAAdapter(from: adapterURL)

        XCTAssertTrue(mockLLMEngine.adapterSignatureValidated)
        XCTAssertTrue(mockLLMEngine.adapterSecurityChecked)
    }

    func testLoRAAdapterPrivacy() async throws {
        chatEngine.privacyManager.contextSharingEnabled = false
        let adapterURL = URL(string: "https://example.com/private-adapter.safetensors")!

        do {
            try await chatEngine.loadLoRAAdapter(from: adapterURL)
            XCTFail("Expected privacy error")
        } catch let error as PrivacyError {
            XCTAssertEqual(error, .sharingDisabled)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum LoRAError: Error {
    case incompatibleModel
    case invalidFormat
    case downloadFailed
    case trainingFailed
    case compositionFailed
}

enum PrivacyError: Error {
    case sharingDisabled
}

// MARK: - Mock Extensions

extension MockLLMEngine {
    var loRAAdapterLoaded: Bool {
        get { return objc_getAssociatedObject(self, &loRAAdapterLoadedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &loRAAdapterLoadedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastLoadedAdapterURL: URL? {
        get { return objc_getAssociatedObject(self, &lastLoadedAdapterURLKey) as? URL }
        set { objc_setAssociatedObject(self, &lastLoadedAdapterURLKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterBaseModel: ModelConfiguration? {
        get { return objc_getAssociatedObject(self, &adapterBaseModelKey) as? ModelConfiguration }
        set { objc_setAssociatedObject(self, &adapterBaseModelKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterAppliedDuringGeneration: Bool {
        get { return objc_getAssociatedObject(self, &adapterAppliedDuringGenerationKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterAppliedDuringGenerationKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastAppliedAdapterName: String? {
        get { return objc_getAssociatedObject(self, &lastAppliedAdapterNameKey) as? String }
        set { objc_setAssociatedObject(self, &lastAppliedAdapterNameKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterSwitched: Bool {
        get { return objc_getAssociatedObject(self, &adapterSwitchedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterSwitchedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterUnloaded: Bool {
        get { return objc_getAssociatedObject(self, &adapterUnloadedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterUnloadedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var trainingStarted: Bool {
        get { return objc_getAssociatedObject(self, &trainingStartedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &trainingStartedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var trainingDataCount: Int {
        get { return objc_getAssociatedObject(self, &trainingDataCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &trainingDataCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var trainingProgressMonitored: Bool {
        get { return objc_getAssociatedObject(self, &trainingProgressMonitoredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &trainingProgressMonitoredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var trainingCancelled: Bool {
        get { return objc_getAssociatedObject(self, &trainingCancelledKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &trainingCancelledKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var trainingCompletionURL: URL? {
        get { return objc_getAssociatedObject(self, &trainingCompletionURLKey) as? URL }
        set { objc_setAssociatedObject(self, &trainingCompletionURLKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var trainingCompleted: Bool {
        get { return objc_getAssociatedObject(self, &trainingCompletedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &trainingCompletedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var trainedAdapterURL: URL? {
        get { return objc_getAssociatedObject(self, &trainedAdapterURLKey) as? URL }
        set { objc_setAssociatedObject(self, &trainedAdapterURLKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adaptersDiscovered: Bool {
        get { return objc_getAssociatedObject(self, &adaptersDiscoveredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adaptersDiscoveredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var discoveredAdaptersCount: Int {
        get { return objc_getAssociatedObject(self, &discoveredAdaptersCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &discoveredAdaptersCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adaptersFiltered: Bool {
        get { return objc_getAssociatedObject(self, &adaptersFilteredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adaptersFilteredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var filterCategory: String? {
        get { return objc_getAssociatedObject(self, &filterCategoryKey) as? String }
        set { objc_setAssociatedObject(self, &filterCategoryKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adaptersSearched: Bool {
        get { return objc_getAssociatedObject(self, &adaptersSearchedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adaptersSearchedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var searchQuery: String? {
        get { return objc_getAssociatedObject(self, &searchQueryKey) as? String }
        set { objc_setAssociatedObject(self, &searchQueryKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterMetadataRetrieved: Bool {
        get { return objc_getAssociatedObject(self, &adapterMetadataRetrievedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterMetadataRetrievedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var compatibilityChecked: Bool {
        get { return objc_getAssociatedObject(self, &compatibilityCheckedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &compatibilityCheckedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterPerformanceTested: Bool {
        get { return objc_getAssociatedObject(self, &adapterPerformanceTestedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterPerformanceTestedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterMemoryUsageTracked: Bool {
        get { return objc_getAssociatedObject(self, &adapterMemoryUsageTrackedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterMemoryUsageTrackedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterMemoryUsage: Int {
        get { return objc_getAssociatedObject(self, &adapterMemoryUsageKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &adapterMemoryUsageKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterBenchmarked: Bool {
        get { return objc_getAssociatedObject(self, &adapterBenchmarkedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterBenchmarkedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var loadedAdaptersCount: Int {
        get { return objc_getAssociatedObject(self, &loadedAdaptersCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &loadedAdaptersCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterConfigurationSaved: Bool {
        get { return objc_getAssociatedObject(self, &adapterConfigurationSavedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterConfigurationSavedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterConfigurationLoaded: Bool {
        get { return objc_getAssociatedObject(self, &adapterConfigurationLoadedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterConfigurationLoadedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var errorHandled: Bool {
        get { return objc_getAssociatedObject(self, &errorHandledKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &errorHandledKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var recoveryAttempted: Bool {
        get { return objc_getAssociatedObject(self, &recoveryAttemptedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &recoveryAttemptedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterUsedInStreaming: Bool {
        get { return objc_getAssociatedObject(self, &adapterUsedInStreamingKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterUsedInStreamingKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterUsedInBatch: Bool {
        get { return objc_getAssociatedObject(self, &adapterUsedInBatchKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterUsedInBatchKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterUsedWithVision: Bool {
        get { return objc_getAssociatedObject(self, &adapterUsedWithVisionKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterUsedWithVisionKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adaptersComposed: Bool {
        get { return objc_getAssociatedObject(self, &adaptersComposedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adaptersComposedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var composedAdapterCount: Int {
        get { return objc_getAssociatedObject(self, &composedAdapterCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &composedAdapterCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterFineTuned: Bool {
        get { return objc_getAssociatedObject(self, &adapterFineTunedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterFineTunedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var fineTuneDataCount: Int {
        get { return objc_getAssociatedObject(self, &fineTuneDataCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &fineTuneDataCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterVersioned: Bool {
        get { return objc_getAssociatedObject(self, &adapterVersionedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterVersionedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterSignatureValidated: Bool {
        get { return objc_getAssociatedObject(self, &adapterSignatureValidatedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterSignatureValidatedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adapterSecurityChecked: Bool {
        get { return objc_getAssociatedObject(self, &adapterSecurityCheckedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adapterSecurityCheckedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// Associated object keys
private var loRAAdapterLoadedKey: UInt8 = 0
private var lastLoadedAdapterURLKey: UInt8 = 0
private var adapterBaseModelKey: UInt8 = 0
private var adapterAppliedDuringGenerationKey: UInt8 = 0
private var lastAppliedAdapterNameKey: UInt8 = 0
private var adapterSwitchedKey: UInt8 = 0
private var adapterUnloadedKey: UInt8 = 0
private var trainingStartedKey: UInt8 = 0
private var trainingDataCountKey: UInt8 = 0
private var trainingProgressMonitoredKey: UInt8 = 0
private var trainingCancelledKey: UInt8 = 0
private var trainingCompletionURLKey: UInt8 = 0
private var trainingCompletedKey: UInt8 = 0
private var trainedAdapterURLKey: UInt8 = 0
private var adaptersDiscoveredKey: UInt8 = 0
private var discoveredAdaptersCountKey: UInt8 = 0
private var adaptersFilteredKey: UInt8 = 0
private var filterCategoryKey: UInt8 = 0
private var adaptersSearchedKey: UInt8 = 0
private var searchQueryKey: UInt8 = 0
private var adapterMetadataRetrievedKey: UInt8 = 0
private var compatibilityCheckedKey: UInt8 = 0
private var adapterPerformanceTestedKey: UInt8 = 0
private var adapterMemoryUsageTrackedKey: UInt8 = 0
private var adapterMemoryUsageKey: UInt8 = 0
private var adapterBenchmarkedKey: UInt8 = 0
private var loadedAdaptersCountKey: UInt8 = 0
private var adapterConfigurationSavedKey: UInt8 = 0
private var adapterConfigurationLoadedKey: UInt8 = 0
private var errorHandledKey: UInt8 = 0
private var recoveryAttemptedKey: UInt8 = 0
private var adapterUsedInStreamingKey: UInt8 = 0
private var adapterUsedInBatchKey: UInt8 = 0
private var adapterUsedWithVisionKey: UInt8 = 0
private var adaptersComposedKey: UInt8 = 0
private var composedAdapterCountKey: UInt8 = 0
private var adapterFineTunedKey: UInt8 = 0
private var fineTuneDataCountKey: UInt8 = 0
private var adapterVersionedKey: UInt8 = 0
private var adapterSignatureValidatedKey: UInt8 = 0
private var adapterSecurityCheckedKey: UInt8 = 0
