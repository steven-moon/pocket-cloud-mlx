// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUnitTests/VisionLanguageTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class VisionLanguageTests: XCTestCase {
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

/// Unit tests for Vision Language Model integration
/// Tests image understanding, multimodal input, and vision capabilities
class VisionLanguageTests: XCTestCase {

    private var chatEngine: ChatEngine!
    private var mockLLMEngine: MockLLMEngine!
    private let testTimeout: TimeInterval = 30.0

    override func setUp() async throws {
        // Use real engine by default, only use mock if explicitly requested
        let useMockTests = ProcessInfo.processInfo.environment["FORCE_MOCK_TESTS"] == "true"

        if useMockTests {
            mockLLMEngine = MockLLMEngine()
            mockLLMEngine.supportedFeatures = [.visionLanguageModels, .multiModalInput]
            chatEngine = try await ChatEngine(llmEngine: mockLLMEngine)
        } else {
            // Use real MLX engine for testing (vision features may not be available)
            let config = ModelConfiguration(
                name: "SmolLM2 Test",
                hubId: "mlx-community/SmolLM2-360M-Instruct",
                description: "Real MLX model for testing (DEFAULT)",
                modelType: .llm,
                gpuCacheLimit: 512 * 1024 * 1024,
                features: [.visionLanguageModels, .multiModalInput]
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

    // MARK: - Vision Model Loading

    func testVisionLanguageModelLoading() async throws {
        try await chatEngine.loadVisionLanguageModel()
        XCTAssertTrue(mockLLMEngine.visionModelLoaded)
        XCTAssertEqual(mockLLMEngine.loadedVisionModelName, "default-vision-model")
    }

    func testVisionModelCompatibility() async throws {
        mockLLMEngine.shouldThrowVisionError = true

        do {
            try await chatEngine.loadVisionLanguageModel()
            XCTFail("Expected vision error")
        } catch let error as VisionError {
            XCTAssertEqual(error, .modelNotSupported)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testVisionModelWithCustomConfiguration() async throws {
        let config = VisionConfiguration(
            modelName: "custom-vision-model",
            maxImageSize: 1024,
            supportedFormats: [.jpeg, .png]
        )

        try await chatEngine.loadVisionLanguageModel(config: config)

        XCTAssertTrue(mockLLMEngine.visionModelLoaded)
        XCTAssertEqual(mockLLMEngine.visionConfig?.modelName, "custom-vision-model")
        XCTAssertEqual(mockLLMEngine.visionConfig?.maxImageSize, 1024)
    }

    // MARK: - Image Analysis

    func testImageAnalysisWithTextPrompt() async throws {
        let testImage = UIImage(systemName: "star")!
        let prompt = "Describe this image in detail"

        let result = try await chatEngine.analyzeImage(image: testImage, prompt: prompt)

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("star") || result.contains("geometric"))
        XCTAssertTrue(mockLLMEngine.visionAnalysisPerformed)
        XCTAssertEqual(mockLLMEngine.lastAnalyzedImage, testImage)
        XCTAssertEqual(mockLLMEngine.lastVisionPrompt, prompt)
    }

    func testImageAnalysisWithoutPrompt() async throws {
        let testImage = UIImage(systemName: "circle")!

        let result = try await chatEngine.analyzeImage(image: testImage)

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(mockLLMEngine.visionAnalysisPerformed)
        XCTAssertEqual(mockLLMEngine.lastAnalyzedImage, testImage)
    }

    func testMultipleImageAnalysis() async throws {
        let images = [
            UIImage(systemName: "star")!,
            UIImage(systemName: "circle")!,
            UIImage(systemName: "square")!
        ]

        var results: [String] = []

        for image in images {
            let result = try await chatEngine.analyzeImage(image: image, prompt: "What shape is this?")
            results.append(result)
        }

        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertFalse(result.isEmpty)
        }
        XCTAssertEqual(mockLLMEngine.visionAnalysisCount, 3)
    }

    // MARK: - Multimodal Input

    func testMultimodalTextAndImage() async throws {
        let text = "Explain what you see in this image"
        let image = UIImage(systemName: "person.wave")!

        let response = try await chatEngine.generateWithMultimodalInput(text: text, image: image)

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(mockLLMEngine.multimodalProcessingUsed)
        XCTAssertEqual(mockLLMEngine.lastMultimodalText, text)
        XCTAssertEqual(mockLLMEngine.lastMultimodalImage, image)
    }

    func testMultimodalMultipleImages() async throws {
        let text = "Compare these two images"
        let image1 = UIImage(systemName: "sun.max")!
        let image2 = UIImage(systemName: "moon")!

        let response = try await chatEngine.generateWithMultimodalInput(
            text: text,
            images: [image1, image2]
        )

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(mockLLMEngine.multimodalProcessingUsed)
        XCTAssertEqual(mockLLMEngine.lastMultimodalText, text)
        XCTAssertEqual(mockLLMEngine.multimodalImageCount, 2)
    }

    // MARK: - Vision Streaming

    func testVisionStreamingResponse() async throws {
        let image = UIImage(systemName: "heart")!
        let prompt = "Describe this symbol"
        var receivedChunks: [String] = []
        let expectation = XCTestExpectation(description: "Vision streaming response")

        let task = Task {
            var chunkCount = 0
            for try await chunk in chatEngine.streamVisionResponse(image: image, prompt: prompt) {
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
        XCTAssertTrue(receivedChunks.count >= 3)
        XCTAssertTrue(mockLLMEngine.visionStreamingUsed)
        XCTAssertEqual(mockLLMEngine.lastStreamedVisionImage, image)
    }

    func testVisionStreamingWithComplexPrompt() async throws {
        let image = UIImage(systemName: "car")!
        let prompt = "Analyze this vehicle: color, make, model, condition, and estimate value"

        var fullResponse = ""
        for try await chunk in chatEngine.streamVisionResponse(image: image, prompt: prompt) {
            fullResponse += chunk
        }

        XCTAssertFalse(fullResponse.isEmpty)
        XCTAssertTrue(fullResponse.count > 50) // Detailed analysis expected
        XCTAssertTrue(mockLLMEngine.visionStreamingUsed)
    }

    // MARK: - Image Format Support

    func testSupportedImageFormats() async throws {
        let testFormats: [ImageFormat] = [.jpeg, .png, .heic, .tiff]

        for format in testFormats {
            let mockImage = UIImage(systemName: "star")!
            let prompt = "Analyze this \(format.rawValue) image"

            let result = try await chatEngine.analyzeImage(
                image: mockImage,
                prompt: prompt,
                format: format
            )

            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(mockLLMEngine.visionAnalysisPerformed)
        }
    }

    func testUnsupportedImageFormat() async throws {
        let unsupportedFormat = ImageFormat(rawValue: "bmp")!
        let image = UIImage(systemName: "star")!

        do {
            _ = try await chatEngine.analyzeImage(
                image: image,
                format: unsupportedFormat
            )
            XCTFail("Expected format error")
        } catch let error as VisionError {
            XCTAssertEqual(error, .unsupportedFormat)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Image Size Handling

    func testLargeImageHandling() async throws {
        // Create a large mock image
        let largeImage = UIImage(systemName: "rectangle.fill")!

        let result = try await chatEngine.analyzeImage(
            image: largeImage,
            prompt: "Describe this large image"
        )

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(mockLLMEngine.visionAnalysisPerformed)
        XCTAssertTrue(mockLLMEngine.imageResizingPerformed)
    }

    func testImageSizeLimits() async throws {
        let oversizedImage = UIImage(systemName: "square")!
        mockLLMEngine.shouldThrowImageSizeError = true

        do {
            _ = try await chatEngine.analyzeImage(image: oversizedImage)
            XCTFail("Expected size limit error")
        } catch let error as VisionError {
            XCTAssertEqual(error, .imageTooLarge)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Vision Model Performance

    func testVisionModelPerformance() async throws {
        let image = UIImage(systemName: "star")!
        let prompt = "Quick analysis"

        let startTime = Date()
        let result = try await chatEngine.analyzeImage(image: image, prompt: prompt)
        let processingTime = Date().timeIntervalSince(startTime)

        XCTAssertFalse(result.isEmpty)
        XCTAssertLessThan(processingTime, 10.0) // Should complete within 10 seconds
        XCTAssertTrue(mockLLMEngine.visionPerformanceMeasured)
    }

    func testVisionModelMemoryUsage() async throws {
        let image = UIImage(systemName: "photo")!

        let result = try await chatEngine.analyzeImage(image: image)

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(mockLLMEngine.visionMemoryUsageTracked)
        XCTAssertGreaterThan(mockLLMEngine.visionMemoryUsage, 0)
    }

    // MARK: - Error Handling

    func testVisionErrorRecovery() async throws {
        mockLLMEngine.shouldThrowVisionError = true

        do {
            _ = try await chatEngine.analyzeImage(image: UIImage(systemName: "star")!)
            XCTFail("Expected vision error")
        } catch {
            // Verify error recovery
            let recovered = await chatEngine.attemptVisionRecovery()
            XCTAssertTrue(recovered)
            XCTAssertTrue(mockLLMEngine.visionRecoveryAttempted)
        }
    }

    func testNetworkErrorHandling() async throws {
        mockLLMEngine.shouldThrowNetworkError = true

        do {
            _ = try await chatEngine.analyzeImage(image: UIImage(systemName: "star")!)
            XCTFail("Expected network error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .connectionFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Integration Tests

    func testVisionWithRegularChat() async throws {
        // Test switching between regular chat and vision
        let textMessage = "Hello"
        let textResponse = try await chatEngine.generateResponse(textMessage)
        XCTAssertFalse(textResponse.isEmpty)

        // Then test vision
        let image = UIImage(systemName: "star")!
        let visionResponse = try await chatEngine.analyzeImage(image: image)
        XCTAssertFalse(visionResponse.isEmpty)

        // Verify both modes work
        XCTAssertTrue(mockLLMEngine.regularChatUsed)
        XCTAssertTrue(mockLLMEngine.visionAnalysisPerformed)
    }

    func testVisionWithStreamingChat() async throws {
        let image = UIImage(systemName: "message")!
        let prompt = "Analyze this chat interface"

        var receivedChunks: [String] = []
        let expectation = XCTestExpectation(description: "Vision streaming in chat")

        let task = Task {
            var chunkCount = 0
            for try await chunk in chatEngine.streamVisionResponse(image: image, prompt: prompt) {
                receivedChunks.append(chunk)
                chunkCount += 1
                if chunkCount >= 5 {
                    expectation.fulfill()
                    break
                }
            }
        }

        await fulfillment(of: [expectation], timeout: testTimeout)

        XCTAssertFalse(receivedChunks.isEmpty)
        XCTAssertTrue(mockLLMEngine.visionStreamingUsed)
    }

    // MARK: - Advanced Vision Features

    func testObjectDetection() async throws {
        let image = UIImage(systemName: "person.and.person")!

        let objects = try await chatEngine.detectObjects(in: image)

        XCTAssertFalse(objects.isEmpty)
        XCTAssertTrue(objects.contains { $0.label.contains("person") })
        XCTAssertTrue(mockLLMEngine.objectDetectionUsed)
    }

    func testImageClassification() async throws {
        let image = UIImage(systemName: "car")!

        let classifications = try await chatEngine.classifyImage(image)

        XCTAssertFalse(classifications.isEmpty)
        XCTAssertTrue(classifications.first?.confidence ?? 0 > 0)
        XCTAssertTrue(mockLLMEngine.imageClassificationUsed)
    }

    func testTextRecognition() async throws {
        // Create an image with text would be ideal, but for testing we'll use mock
        let imageWithText = UIImage(systemName: "text.bubble")!

        let recognizedText = try await chatEngine.recognizeText(in: imageWithText)

        XCTAssertFalse(recognizedText.isEmpty)
        XCTAssertTrue(mockLLMEngine.textRecognitionUsed)
    }

    func testImageGenerationFromText() async throws {
        let prompt = "Generate an image of a sunset over mountains"

        let generatedImage = try await chatEngine.generateImage(from: prompt)

        XCTAssertNotNil(generatedImage)
        XCTAssertTrue(mockLLMEngine.imageGenerationUsed)
        XCTAssertEqual(mockLLMEngine.lastImageGenerationPrompt, prompt)
    }

    func testImageVariation() async throws {
        let sourceImage = UIImage(systemName: "star")!

        let variation = try await chatEngine.generateImageVariation(of: sourceImage)

        XCTAssertNotNil(variation)
        XCTAssertTrue(mockLLMEngine.imageVariationUsed)
        XCTAssertEqual(mockLLMEngine.lastVariationSourceImage, sourceImage)
    }

    // MARK: - Privacy & Security

    func testVisionPrivacyControls() async throws {
        chatEngine.privacyManager.contextSharingEnabled = false
        let image = UIImage(systemName: "star")!

        do {
            _ = try await chatEngine.analyzeImage(image: image)
            XCTFail("Expected privacy error")
        } catch let error as PrivacyError {
            XCTAssertEqual(error, .sharingDisabled)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testImageDataSanitization() async throws {
        let imageWithMetadata = UIImage(systemName: "photo")!
        mockLLMEngine.shouldContainMetadata = true

        let result = try await chatEngine.analyzeImage(image: imageWithMetadata)

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(mockLLMEngine.metadataSanitized)
    }

    // MARK: - Performance Benchmarks

    func testVisionPerformanceBenchmark() async throws {
        let image = UIImage(systemName: "star")!
        let prompt = "Performance test"

        let startTime = Date()
        _ = try await chatEngine.analyzeImage(image: image, prompt: prompt)
        let processingTime = Date().timeIntervalSince(startTime)

        // Vision analysis should complete in reasonable time
        XCTAssertLessThan(processingTime, 15.0)
        XCTAssertTrue(mockLLMEngine.visionBenchmarkCompleted)
    }

    func testVisionThroughputTest() async throws {
        let images = (1...5).map { _ in UIImage(systemName: "star")! }
        let prompt = "Analyze this image"

        var totalTime: TimeInterval = 0
        var results: [String] = []

        for image in images {
            let startTime = Date()
            let result = try await chatEngine.analyzeImage(image: image, prompt: prompt)
            let processingTime = Date().timeIntervalSince(startTime)

            totalTime += processingTime
            results.append(result)
        }

        let averageTime = totalTime / Double(images.count)

        XCTAssertEqual(results.count, images.count)
        XCTAssertLessThan(averageTime, 10.0) // Average under 10 seconds
        XCTAssertTrue(mockLLMEngine.visionThroughputTested)
    }
}

// MARK: - Supporting Types

enum VisionError: Error {
    case modelNotSupported
    case imageTooLarge
    case unsupportedFormat
    case processingFailed
}

enum ImageFormat: String {
    case jpeg
    case png
    case heic
    case tiff
    case bmp
}

struct VisionConfiguration {
    let modelName: String
    let maxImageSize: Int
    let supportedFormats: [ImageFormat]
}

enum NetworkError: Error {
    case connectionFailed
}

enum PrivacyError: Error {
    case sharingDisabled
}

struct DetectedObject {
    let label: String
    let confidence: Double
    let boundingBox: CGRect
}

struct ClassificationResult {
    let label: String
    let confidence: Double
}

// MARK: - Mock Extensions

extension MockLLMEngine {
    var visionModelLoaded: Bool {
        get { return objc_getAssociatedObject(self, &visionModelLoadedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionModelLoadedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var loadedVisionModelName: String? {
        get { return objc_getAssociatedObject(self, &loadedVisionModelNameKey) as? String }
        set { objc_setAssociatedObject(self, &loadedVisionModelNameKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionConfig: VisionConfiguration? {
        get { return objc_getAssociatedObject(self, &visionConfigKey) as? VisionConfiguration }
        set { objc_setAssociatedObject(self, &visionConfigKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionAnalysisPerformed: Bool {
        get { return objc_getAssociatedObject(self, &visionAnalysisPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionAnalysisPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastAnalyzedImage: UIImage? {
        get { return objc_getAssociatedObject(self, &lastAnalyzedImageKey) as? UIImage }
        set { objc_setAssociatedObject(self, &lastAnalyzedImageKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastVisionPrompt: String? {
        get { return objc_getAssociatedObject(self, &lastVisionPromptKey) as? String }
        set { objc_setAssociatedObject(self, &lastVisionPromptKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionAnalysisCount: Int {
        get { return objc_getAssociatedObject(self, &visionAnalysisCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &visionAnalysisCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var multimodalProcessingUsed: Bool {
        get { return objc_getAssociatedObject(self, &multimodalProcessingUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &multimodalProcessingUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastMultimodalText: String? {
        get { return objc_getAssociatedObject(self, &lastMultimodalTextKey) as? String }
        set { objc_setAssociatedObject(self, &lastMultimodalTextKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastMultimodalImage: UIImage? {
        get { return objc_getAssociatedObject(self, &lastMultimodalImageKey) as? UIImage }
        set { objc_setAssociatedObject(self, &lastMultimodalImageKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var multimodalImageCount: Int {
        get { return objc_getAssociatedObject(self, &multimodalImageCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &multimodalImageCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionStreamingUsed: Bool {
        get { return objc_getAssociatedObject(self, &visionStreamingUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionStreamingUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastStreamedVisionImage: UIImage? {
        get { return objc_getAssociatedObject(self, &lastStreamedVisionImageKey) as? UIImage }
        set { objc_setAssociatedObject(self, &lastStreamedVisionImageKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionPerformanceMeasured: Bool {
        get { return objc_getAssociatedObject(self, &visionPerformanceMeasuredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionPerformanceMeasuredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionMemoryUsageTracked: Bool {
        get { return objc_getAssociatedObject(self, &visionMemoryUsageTrackedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionMemoryUsageTrackedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionMemoryUsage: Int {
        get { return objc_getAssociatedObject(self, &visionMemoryUsageKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &visionMemoryUsageKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionRecoveryAttempted: Bool {
        get { return objc_getAssociatedObject(self, &visionRecoveryAttemptedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionRecoveryAttemptedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var regularChatUsed: Bool {
        get { return objc_getAssociatedObject(self, &regularChatUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &regularChatUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var objectDetectionUsed: Bool {
        get { return objc_getAssociatedObject(self, &objectDetectionUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &objectDetectionUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var imageClassificationUsed: Bool {
        get { return objc_getAssociatedObject(self, &imageClassificationUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &imageClassificationUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var textRecognitionUsed: Bool {
        get { return objc_getAssociatedObject(self, &textRecognitionUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &textRecognitionUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var imageGenerationUsed: Bool {
        get { return objc_getAssociatedObject(self, &imageGenerationUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &imageGenerationUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastImageGenerationPrompt: String? {
        get { return objc_getAssociatedObject(self, &lastImageGenerationPromptKey) as? String }
        set { objc_setAssociatedObject(self, &lastImageGenerationPromptKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var imageVariationUsed: Bool {
        get { return objc_getAssociatedObject(self, &imageVariationUsedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &imageVariationUsedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var lastVariationSourceImage: UIImage? {
        get { return objc_getAssociatedObject(self, &lastVariationSourceImageKey) as? UIImage }
        set { objc_setAssociatedObject(self, &lastVariationSourceImageKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var imageResizingPerformed: Bool {
        get { return objc_getAssociatedObject(self, &imageResizingPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &imageResizingPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionBenchmarkCompleted: Bool {
        get { return objc_getAssociatedObject(self, &visionBenchmarkCompletedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionBenchmarkCompletedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var visionThroughputTested: Bool {
        get { return objc_getAssociatedObject(self, &visionThroughputTestedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &visionThroughputTestedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var metadataSanitized: Bool {
        get { return objc_getAssociatedObject(self, &metadataSanitizedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &metadataSanitizedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// Associated object keys
private var visionModelLoadedKey: UInt8 = 0
private var loadedVisionModelNameKey: UInt8 = 0
private var visionConfigKey: UInt8 = 0
private var visionAnalysisPerformedKey: UInt8 = 0
private var lastAnalyzedImageKey: UInt8 = 0
private var lastVisionPromptKey: UInt8 = 0
private var visionAnalysisCountKey: UInt8 = 0
private var multimodalProcessingUsedKey: UInt8 = 0
private var lastMultimodalTextKey: UInt8 = 0
private var lastMultimodalImageKey: UInt8 = 0
private var multimodalImageCountKey: UInt8 = 0
private var visionStreamingUsedKey: UInt8 = 0
private var lastStreamedVisionImageKey: UInt8 = 0
private var visionPerformanceMeasuredKey: UInt8 = 0
private var visionMemoryUsageTrackedKey: UInt8 = 0
private var visionMemoryUsageKey: UInt8 = 0
private var visionRecoveryAttemptedKey: UInt8 = 0
private var regularChatUsedKey: UInt8 = 0
private var objectDetectionUsedKey: UInt8 = 0
private var imageClassificationUsedKey: UInt8 = 0
private var textRecognitionUsedKey: UInt8 = 0
private var imageGenerationUsedKey: UInt8 = 0
private var lastImageGenerationPromptKey: UInt8 = 0
private var imageVariationUsedKey: UInt8 = 0
private var lastVariationSourceImageKey: UInt8 = 0
private var imageResizingPerformedKey: UInt8 = 0
private var visionBenchmarkCompletedKey: UInt8 = 0
private var visionThroughputTestedKey: UInt8 = 0
private var metadataSanitizedKey: UInt8 = 0
