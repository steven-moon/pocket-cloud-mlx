// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUnitTests/ContextManagementTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ContextManagementTests: XCTestCase {
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

/// Unit tests for MLX Engine context management
/// Tests document processing, web context extraction, and context handling
class ContextManagementTests: XCTestCase {

    private var chatEngine: ChatEngine!
    private var mockLLMEngine: MockLLMEngine!
    private var contextManager: ContextManager!
    private let testTimeout: TimeInterval = 30.0

    override func setUp() async throws {
        // Use real engine by default, only use mock if explicitly requested
        let useMockTests = ProcessInfo.processInfo.environment["FORCE_MOCK_TESTS"] == "true"

        if useMockTests {
            mockLLMEngine = MockLLMEngine()
            chatEngine = try await ChatEngine(llmEngine: mockLLMEngine)
        } else {
            // Use real MLX engine for testing
            let config = ModelConfiguration(
                name: "SmolLM2 Test",
                hubId: "mlx-community/SmolLM2-360M-Instruct",
                description: "Real MLX model for testing (DEFAULT)",
                modelType: .llm,
                gpuCacheLimit: 512 * 1024 * 1024,
                features: []
            )
            let realEngine = try await InferenceEngine.loadModel(config) { _ in }
            chatEngine = try await ChatEngine(llmEngine: realEngine)
        }
        contextManager = ContextManager()
    }

    override func tearDown() async throws {
        await chatEngine?.cancelAllTasks()
        chatEngine = nil
        mockLLMEngine = nil
        contextManager = nil
    }

    // MARK: - Document Processing

    func testPDFDocumentProcessing() async throws {
        let pdfURL = URL(string: "https://example.com/test.pdf")!

        let documentContext = try await chatEngine.extractDocumentContext(from: pdfURL)

        XCTAssertNotNil(documentContext)
        XCTAssertEqual(documentContext.fileType, .pdf)
        XCTAssertFalse(documentContext.extractedText.isEmpty)
        XCTAssertFalse(documentContext.summary.isEmpty)
        XCTAssertTrue(mockLLMEngine.pdfProcessed)
    }

    func testTextDocumentProcessing() async throws {
        let textURL = URL(string: "https://example.com/test.txt")!

        let documentContext = try await chatEngine.extractDocumentContext(from: textURL)

        XCTAssertNotNil(documentContext)
        XCTAssertEqual(documentContext.fileType, .text)
        XCTAssertFalse(documentContext.extractedText.isEmpty)
        XCTAssertFalse(documentContext.summary.isEmpty)
        XCTAssertTrue(mockLLMEngine.textDocumentProcessed)
    }

    func testImageDocumentProcessing() async throws {
        let imageURL = URL(string: "https://example.com/test.jpg")!

        let documentContext = try await chatEngine.extractDocumentContext(from: imageURL)

        XCTAssertNotNil(documentContext)
        XCTAssertEqual(documentContext.fileType, .image)
        XCTAssertFalse(documentContext.extractedText.isEmpty)
        XCTAssertTrue(mockLLMEngine.imageDocumentProcessed)
        XCTAssertTrue(mockLLMEngine.ocrPerformed)
    }

    func testUnsupportedDocumentFormat() async throws {
        let unsupportedURL = URL(string: "https://example.com/test.xyz")!

        do {
            _ = try await chatEngine.extractDocumentContext(from: unsupportedURL)
            XCTFail("Expected unsupported format error")
        } catch let error as ContextError {
            XCTAssertEqual(error, .unsupportedFormat)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Web Context Extraction

    func testWebPageContextExtraction() async throws {
        let webURL = URL(string: "https://example.com/article")!

        let webContext = try await chatEngine.extractWebContext(from: webURL)

        XCTAssertNotNil(webContext)
        XCTAssertFalse(webContext.title.isEmpty)
        XCTAssertFalse(webContext.content.isEmpty)
        XCTAssertTrue(webContext.extractedAt.timeIntervalSinceNow > -1)
        XCTAssertTrue(mockLLMEngine.webPageScraped)
    }

    func testWebPageWithImages() async throws {
        let webURL = URL(string: "https://example.com/image-article")!

        let webContext = try await chatEngine.extractWebContext(from: webURL)

        XCTAssertNotNil(webContext)
        XCTAssertFalse(webContext.images.isEmpty)
        XCTAssertTrue(mockLLMEngine.webImagesExtracted)
    }

    func testWebPageWithLinks() async throws {
        let webURL = URL(string: "https://example.com/linked-article")!

        let webContext = try await chatEngine.extractWebContext(from: webURL)

        XCTAssertNotNil(webContext)
        XCTAssertFalse(webContext.links.isEmpty)
        XCTAssertTrue(mockLLMEngine.webLinksExtracted)
    }

    func testInvalidWebURL() async throws {
        let invalidURL = URL(string: "https://invalid-domain-that-does-not-exist.com")!

        do {
            _ = try await chatEngine.extractWebContext(from: invalidURL)
            XCTFail("Expected network error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .connectionFailed)
        } catch {
            // Network errors are expected for invalid URLs
            XCTAssertTrue(mockLLMEngine.networkRequestFailed)
        }
    }

    // MARK: - Context Item Management

    func testContextItemCreation() async throws {
        let content = "Test context content"
        let metadata = ["source": "test", "priority": "high"]

        let contextItem = ContextItem(
            type: .document,
            content: content,
            metadata: metadata
        )

        XCTAssertEqual(contextItem.type, .document)
        XCTAssertEqual(contextItem.content, content)
        XCTAssertEqual(contextItem.metadata["source"] as? String, "test")
        XCTAssertEqual(contextItem.metadata["priority"] as? String, "high")
        XCTAssertTrue(contextItem.timestamp.timeIntervalSinceNow > -1)
    }

    func testContextItemAddition() async throws {
        let contextItem = ContextItem(type: .webpage, content: "Test webpage content")

        contextManager.addContextItem(contextItem)

        XCTAssertTrue(contextManager.currentContext.contains(contextItem))
        XCTAssertEqual(contextManager.currentContext.count, 1)
    }

    func testContextItemRemoval() async throws {
        let contextItem1 = ContextItem(type: .document, content: "Document 1")
        let contextItem2 = ContextItem(type: .webpage, content: "Webpage 2")

        contextManager.addContextItem(contextItem1)
        contextManager.addContextItem(contextItem2)

        XCTAssertEqual(contextManager.currentContext.count, 2)

        contextManager.clearContext()

        XCTAssertTrue(contextManager.currentContext.isEmpty)
    }

    // MARK: - Contextual Suggestions

    func testContextualSuggestionsGeneration() async throws {
        let webpageContext = ContextItem(type: .webpage, content: "Article about AI")
        let documentContext = ContextItem(type: .document, content: "Research paper on ML")

        contextManager.addContextItem(webpageContext)
        contextManager.addContextItem(documentContext)

        let suggestions = contextManager.contextualSuggestions

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.count <= 5) // Limited to 5 suggestions
        XCTAssertTrue(suggestions.contains { $0.contains("Summarize") })
    }

    func testWebpageSuggestions() async throws {
        let webpageContext = ContextItem(type: .webpage, content: "News article content")

        contextManager.addContextItem(webpageContext)

        let suggestions = contextManager.contextualSuggestions

        XCTAssertTrue(suggestions.contains("Summarize this webpage"))
        XCTAssertTrue(suggestions.contains("What are the key points?"))
    }

    func testDocumentSuggestions() async throws {
        let documentContext = ContextItem(type: .document, content: "Technical document")

        contextManager.addContextItem(documentContext)

        let suggestions = contextManager.contextualSuggestions

        XCTAssertTrue(suggestions.contains("Summarize this document"))
        XCTAssertTrue(suggestions.contains("Extract key information"))
    }

    func testCalendarSuggestions() async throws {
        let calendarContext = ContextItem(type: .calendar, content: "Meeting scheduled")

        contextManager.addContextItem(calendarContext)

        let suggestions = contextManager.contextualSuggestions

        XCTAssertTrue(suggestions.contains("What's on my schedule?"))
        XCTAssertTrue(suggestions.contains("Prepare for upcoming meetings"))
    }

    // MARK: - Context Processing

    func testContextProcessingWithPrivacy() async throws {
        chatEngine.privacyManager.setContextSharingEnabled(true)

        let contextItem = ContextItem(type: .webpage, content: "Content with email@example.com")

        let processedContext = chatEngine.privacyManager.processContext(contextItem)

        XCTAssertEqual(processedContext.type, .webpage)
        XCTAssertFalse(processedContext.content.contains("@"))
        XCTAssertTrue(mockLLMEngine.contextProcessedWithPrivacy)
    }

    func testContextExpiration() async throws {
        let contextItem = ContextItem(type: .system, content: "Temporary content")

        let processedContext = chatEngine.privacyManager.processContext(contextItem)

        XCTAssertTrue(processedContext.expiresAt.timeIntervalSinceNow > 0)
        XCTAssertFalse(processedContext.isExpired)
    }

    func testExpiredContextDetection() async throws {
        let pastDate = Date().addingTimeInterval(-86400) // 24 hours ago
        let expiredContext = ProcessedContext(
            id: UUID(),
            type: .webpage,
            content: "Expired content",
            metadata: [:],
            timestamp: pastDate,
            expiresAt: pastDate
        )

        XCTAssertTrue(expiredContext.isExpired)
    }

    // MARK: - Calendar Context

    func testCalendarEventExtraction() async throws {
        let calendarEvents = try await contextManager.extractCalendarContext()

        // Note: This test may vary based on system calendar permissions
        // In a real environment, this would test actual calendar access
        XCTAssertNotNil(calendarEvents)
        XCTAssertTrue(mockLLMEngine.calendarAccessed)
    }

    func testCalendarEventProcessing() async throws {
        let testEvent = CalendarEvent(
            title: "Test Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Office",
            notes: "Discuss project",
            isAllDay: false
        )

        let contextItem = ContextItem(
            type: .calendar,
            content: "Meeting: \(testEvent.title) at \(testEvent.location ?? "Unknown")"
        )

        contextManager.addContextItem(contextItem)

        XCTAssertTrue(contextManager.currentContext.contains(contextItem))
        XCTAssertTrue(mockLLMEngine.calendarEventProcessed)
    }

    // MARK: - Context Search and Filtering

    func testContextSearch() async throws {
        let doc1 = ContextItem(type: .document, content: "Machine learning algorithms")
        let doc2 = ContextItem(type: .webpage, content: "Weather forecast today")
        let doc3 = ContextItem(type: .document, content: "Neural network architectures")

        contextManager.addContextItem(doc1)
        contextManager.addContextItem(doc2)
        contextManager.addContextItem(doc3)

        let searchResults = try await chatEngine.searchContext(query: "machine learning")

        XCTAssertFalse(searchResults.isEmpty)
        XCTAssertTrue(searchResults.contains { $0.content.contains("Machine learning") })
        XCTAssertTrue(mockLLMEngine.contextSearched)
    }

    func testContextFiltering() async throws {
        let webpageContext = ContextItem(type: .webpage, content: "Web article")
        let documentContext = ContextItem(type: .document, content: "Document content")
        let calendarContext = ContextItem(type: .calendar, content: "Calendar event")

        contextManager.addContextItem(webpageContext)
        contextManager.addContextItem(documentContext)
        contextManager.addContextItem(calendarContext)

        let webpageResults = try await chatEngine.filterContext(by: .webpage)
        let documentResults = try await chatEngine.filterContext(by: .document)

        XCTAssertEqual(webpageResults.count, 1)
        XCTAssertEqual(documentResults.count, 1)
        XCTAssertTrue(webpageResults.first?.type == .webpage)
        XCTAssertTrue(documentResults.first?.type == .document)
        XCTAssertTrue(mockLLMEngine.contextFiltered)
    }

    // MARK: - Context Integration

    func testContextWithGeneration() async throws {
        let contextItem = ContextItem(type: .document, content: "Important background information")

        contextManager.addContextItem(contextItem)

        let prompt = "Based on the context, explain the main topic"
        let response = try await chatEngine.generateResponse(prompt)

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(mockLLMEngine.contextUsedInGeneration)
    }

    func testContextWithStreaming() async throws {
        let contextItem = ContextItem(type: .webpage, content: "Streaming context")

        contextManager.addContextItem(contextItem)

        var receivedChunks: [String] = []
        let expectation = XCTestExpectation(description: "Streaming with context")

        let task = Task {
            var chunkCount = 0
            for try await chunk in chatEngine.streamResponse("Stream with context") {
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
        XCTAssertTrue(mockLLMEngine.contextUsedInStreaming)
    }

    // MARK: - Context Persistence

    func testContextPersistence() async throws {
        let contextItem = ContextItem(type: .document, content: "Persistent content")

        contextManager.addContextItem(contextItem)

        // Simulate persistence
        try await chatEngine.saveContext()

        XCTAssertTrue(mockLLMEngine.contextPersisted)

        // Simulate loading
        try await chatEngine.loadContext()

        XCTAssertTrue(mockLLMEngine.contextLoaded)
    }

    func testContextExport() async throws {
        let contextItem1 = ContextItem(type: .webpage, content: "Export test 1")
        let contextItem2 = ContextItem(type: .document, content: "Export test 2")

        contextManager.addContextItem(contextItem1)
        contextManager.addContextItem(contextItem2)

        let exportedData = try await chatEngine.exportContext()

        XCTAssertFalse(exportedData.isEmpty)
        XCTAssertTrue(exportedData.contains("Export test 1"))
        XCTAssertTrue(exportedData.contains("Export test 2"))
        XCTAssertTrue(mockLLMEngine.contextExported)
    }

    // MARK: - Error Handling

    func testDocumentProcessingError() async throws {
        mockLLMEngine.shouldThrowDocumentError = true
        let docURL = URL(string: "https://example.com/error-doc.pdf")!

        do {
            _ = try await chatEngine.extractDocumentContext(from: docURL)
            XCTFail("Expected document error")
        } catch let error as ContextError {
            XCTAssertEqual(error, .processingFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testWebContextError() async throws {
        mockLLMEngine.shouldThrowWebError = true
        let webURL = URL(string: "https://example.com/error-page")!

        do {
            _ = try await chatEngine.extractWebContext(from: webURL)
            XCTFail("Expected web error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .connectionFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testContextRecovery() async throws {
        mockLLMEngine.shouldThrowContextError = true

        do {
            _ = try await chatEngine.extractWebContext(from: URL(string: "https://example.com/test")!)
        } catch {
            // Attempt recovery
            let recovered = await chatEngine.attemptContextRecovery()
            XCTAssertTrue(recovered)
            XCTAssertTrue(mockLLMEngine.contextRecoveryAttempted)
        }
    }

    // MARK: - Advanced Context Features

    func testContextSummarization() async throws {
        let longContent = String(repeating: "This is a long document with lots of content that needs to be summarized. ", count: 50)
        let contextItem = ContextItem(type: .document, content: longContent)

        let summary = try await chatEngine.summarizeContext(contextItem)

        XCTAssertFalse(summary.isEmpty)
        XCTAssertLessThan(summary.count, longContent.count)
        XCTAssertTrue(summary.count < 500) // Summary should be concise
        XCTAssertTrue(mockLLMEngine.contextSummarized)
    }

    func testContextComparison() async throws {
        let context1 = ContextItem(type: .document, content: "Document about AI")
        let context2 = ContextItem(type: .webpage, content: "Article about ML")

        let comparison = try await chatEngine.compareContexts(context1, context2)

        XCTAssertFalse(comparison.isEmpty)
        XCTAssertTrue(comparison.contains("AI") || comparison.contains("ML"))
        XCTAssertTrue(mockLLMEngine.contextsCompared)
    }

    func testContextRelevanceScoring() async throws {
        let contexts = [
            ContextItem(type: .document, content: "Machine learning algorithms"),
            ContextItem(type: .webpage, content: "Weather forecast"),
            ContextItem(type: .document, content: "Neural networks and deep learning")
        ]

        let query = "machine learning"
        let scoredContexts = try await chatEngine.scoreContextRelevance(contexts, for: query)

        XCTAssertEqual(scoredContexts.count, contexts.count)

        // First context should have highest relevance score
        XCTAssertGreaterThan(scoredContexts[0].score, scoredContexts[1].score)
        XCTAssertTrue(mockLLMEngine.contextRelevanceScored)
    }
}

// MARK: - Supporting Types

enum ContextError: Error {
    case unsupportedFormat
    case processingFailed
    case accessDenied
    case notFound
}

enum NetworkError: Error {
    case connectionFailed
    case timeout
    case invalidResponse
}

// MARK: - Mock Extensions

extension MockLLMEngine {
    var pdfProcessed: Bool {
        get { return objc_getAssociatedObject(self, &pdfProcessedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &pdfProcessedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var textDocumentProcessed: Bool {
        get { return objc_getAssociatedObject(self, &textDocumentProcessedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &textDocumentProcessedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var imageDocumentProcessed: Bool {
        get { return objc_getAssociatedObject(self, &imageDocumentProcessedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &imageDocumentProcessedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var ocrPerformed: Bool {
        get { return objc_getAssociatedObject(self, &ocrPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &ocrPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var webPageScraped: Bool {
        get { return objc_getAssociatedObject(self, &webPageScrapedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &webPageScrapedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var webImagesExtracted: Bool {
        get { return objc_getAssociatedObject(self, &webImagesExtractedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &webImagesExtractedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var webLinksExtracted: Bool {
        get { return objc_getAssociatedObject(self, &webLinksExtractedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &webLinksExtractedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var networkRequestFailed: Bool {
        get { return objc_getAssociatedObject(self, &networkRequestFailedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &networkRequestFailedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextProcessedWithPrivacy: Bool {
        get { return objc_getAssociatedObject(self, &contextProcessedWithPrivacyKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextProcessedWithPrivacyKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var calendarAccessed: Bool {
        get { return objc_getAssociatedObject(self, &calendarAccessedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &calendarAccessedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var calendarEventProcessed: Bool {
        get { return objc_getAssociatedObject(self, &calendarEventProcessedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &calendarEventProcessedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextSearched: Bool {
        get { return objc_getAssociatedObject(self, &contextSearchedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextSearchedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextFiltered: Bool {
        get { return objc_getAssociatedObject(self, &contextFilteredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextFilteredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextUsedInGeneration: Bool {
        get { return objc_getAssociatedObject(self, &contextUsedInGenerationKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextUsedInGenerationKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextUsedInStreaming: Bool {
        get { return objc_getAssociatedObject(self, &contextUsedInStreamingKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextUsedInStreamingKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextPersisted: Bool {
        get { return objc_getAssociatedObject(self, &contextPersistedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextPersistedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextLoaded: Bool {
        get { return objc_getAssociatedObject(self, &contextLoadedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextLoadedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextExported: Bool {
        get { return objc_getAssociatedObject(self, &contextExportedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextExportedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextSummarized: Bool {
        get { return objc_getAssociatedObject(self, &contextSummarizedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextSummarizedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextsCompared: Bool {
        get { return objc_getAssociatedObject(self, &contextsComparedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextsComparedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextRelevanceScored: Bool {
        get { return objc_getAssociatedObject(self, &contextRelevanceScoredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextRelevanceScoredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var shouldThrowDocumentError: Bool {
        get { return objc_getAssociatedObject(self, &shouldThrowDocumentErrorKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &shouldThrowDocumentErrorKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var shouldThrowWebError: Bool {
        get { return objc_getAssociatedObject(self, &shouldThrowWebErrorKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &shouldThrowWebErrorKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var shouldThrowContextError: Bool {
        get { return objc_getAssociatedObject(self, &shouldThrowContextErrorKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &shouldThrowContextErrorKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var contextRecoveryAttempted: Bool {
        get { return objc_getAssociatedObject(self, &contextRecoveryAttemptedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &contextRecoveryAttemptedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// Associated object keys
private var pdfProcessedKey: UInt8 = 0
private var textDocumentProcessedKey: UInt8 = 0
private var imageDocumentProcessedKey: UInt8 = 0
private var ocrPerformedKey: UInt8 = 0
private var webPageScrapedKey: UInt8 = 0
private var webImagesExtractedKey: UInt8 = 0
private var webLinksExtractedKey: UInt8 = 0
private var networkRequestFailedKey: UInt8 = 0
private var contextProcessedWithPrivacyKey: UInt8 = 0
private var calendarAccessedKey: UInt8 = 0
private var calendarEventProcessedKey: UInt8 = 0
private var contextSearchedKey: UInt8 = 0
private var contextFilteredKey: UInt8 = 0
private var contextUsedInGenerationKey: UInt8 = 0
private var contextUsedInStreamingKey: UInt8 = 0
private var contextPersistedKey: UInt8 = 0
private var contextLoadedKey: UInt8 = 0
private var contextExportedKey: UInt8 = 0
private var contextSummarizedKey: UInt8 = 0
private var contextsComparedKey: UInt8 = 0
private var contextRelevanceScoredKey: UInt8 = 0
private var shouldThrowDocumentErrorKey: UInt8 = 0
private var shouldThrowWebErrorKey: UInt8 = 0
private var shouldThrowContextErrorKey: UInt8 = 0
private var contextRecoveryAttemptedKey: UInt8 = 0
