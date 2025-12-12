// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUITests/MLXChatAppPerformanceTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class MLXChatAppPerformanceTests: XCTestCase {
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

/// Performance tests for MLX Chat App with real models
/// Measures response times, memory usage, and system performance
@MainActor
final class MLXChatAppPerformanceTests: XCTestCase {
    var chatEngine: ChatEngine!
    var adapterManager: LoRAAdapterManager!
    var testModel: ModelConfiguration!
    var performanceMetrics: PerformanceMetrics!

    override func setUp() async throws {
        chatEngine = await ChatEngine()
        adapterManager = LoRAAdapterManager.shared
        performanceMetrics = PerformanceMetrics()

        testModel = ModelConfiguration(
            name: "Qwen2-0.5B-Instruct",
            hubId: "Qwen/Qwen2-0.5B-Instruct",
            description: "Fast performance test model",
            maxTokens: 512,
            modelType: .llm,
            gpuCacheLimit: 128 * 1024 * 1024,
            features: [.streamingGeneration, .conversationMemory]
        )
    }

    override func tearDown() async throws {
        chatEngine = nil
        adapterManager = nil
        testModel = nil
        performanceMetrics = nil
    }

    // MARK: - Response Time Benchmarks

    /// Test cold start response time (first message after model load)
    func testColdStartResponseTime() async throws {
        print("🕒 Testing cold start response time...")

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let startTime = Date()

            Task {
                chatEngine.selectedModel = testModel
                let response = try await chatEngine.generate(prompt: "Hello, this is a performance test.")
                let endTime = Date()

                let coldStartTime = endTime.timeIntervalSince(startTime)
                performanceMetrics.coldStartTime = coldStartTime

                print("⚡ Cold start time: \(String(format: "%.2f", coldStartTime)) seconds")
                print("📏 Response length: \(response.count) characters")
            }
        }

        // Assert reasonable performance
        XCTAssertLessThan(performanceMetrics.coldStartTime, 10.0,
                         "Cold start should be under 10 seconds")
        XCTAssertGreaterThan(performanceMetrics.coldStartTime, 0.1,
                            "Cold start should be measurable")
    }

    /// Test warm response times (subsequent messages)
    func testWarmResponseTimes() async throws {
        print("🔥 Testing warm response times...")

        chatEngine.selectedModel = testModel

        // Warm up with first message
        _ = try await chatEngine.generate(prompt: "Warm up message.")

        // Measure subsequent responses
        var responseTimes: [TimeInterval] = []

        for i in 1...5 {
            let startTime = Date()
            let response = try await chatEngine.generate(prompt: "Test message \(i)")
            let endTime = Date()

            let responseTime = endTime.timeIntervalSince(startTime)
            responseTimes.append(responseTime)

            print("⚡ Response \(i) time: \(String(format: "%.2f", responseTime)) seconds")
        }

        let averageTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let minTime = responseTimes.min()!
        let maxTime = responseTimes.max()!

        performanceMetrics.averageResponseTime = averageTime
        performanceMetrics.minResponseTime = minTime
        performanceMetrics.maxResponseTime = maxTime

        print("📊 Average response time: \(String(format: "%.2f", averageTime)) seconds")
        print("📊 Min response time: \(String(format: "%.2f", minTime)) seconds")
        print("📊 Max response time: \(String(format: "%.2f", maxTime)) seconds")

        // Assert performance targets
        XCTAssertLessThan(averageTime, 2.0, "Average response should be under 2 seconds")
        XCTAssertLessThan(maxTime, 5.0, "Max response should be under 5 seconds")
    }

    /// Test streaming response performance
    func testStreamingPerformance() async throws {
        print("🌊 Testing streaming response performance...")

        chatEngine.selectedModel = testModel

        let testPrompt = "Write a short paragraph about artificial intelligence."
        var chunkCount = 0
        var totalLength = 0
        let startTime = Date()

        let stream = try await chatEngine.generateStream(prompt: testPrompt)

        for try await chunk in stream {
            chunkCount += 1
            totalLength += chunk.count
        }

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)

        let throughput = Double(totalLength) / totalTime // characters per second

        performanceMetrics.streamingThroughput = throughput
        performanceMetrics.streamingChunkCount = chunkCount

        print("📊 Streaming performance:")
        print("   Chunks: \(chunkCount)")
        print("   Total length: \(totalLength) characters")
        print("   Total time: \(String(format: "%.2f", totalTime)) seconds")
        print("   Throughput: \(String(format: "%.1f", throughput)) chars/second")

        // Assert streaming performance
        XCTAssertGreaterThan(chunkCount, 5, "Should have multiple streaming chunks")
        XCTAssertGreaterThan(throughput, 50.0, "Should have reasonable streaming throughput")
    }

    // MARK: - Memory Usage Tests

    /// Test memory usage during model operations
    func testMemoryUsage() async throws {
        print("🧠 Testing memory usage...")

        chatEngine.selectedModel = testModel

        // Measure memory before
        let memoryBefore = getCurrentMemoryUsage()

        // Load and use model
        _ = try await chatEngine.generate(prompt: "Test memory usage with this longer prompt that should cause some memory allocation and processing.")

        // Measure memory after
        let memoryAfter = getCurrentMemoryUsage()

        let memoryDelta = memoryAfter - memoryBefore
        performanceMetrics.memoryUsage = memoryAfter
        performanceMetrics.memoryDelta = memoryDelta

        print("📊 Memory usage:")
        print("   Before: \(ByteCountFormatter.string(fromByteCount: Int64(memoryBefore), countStyle: .memory))")
        print("   After: \(ByteCountFormatter.string(fromByteCount: Int64(memoryAfter), countStyle: .memory))")
        print("   Delta: \(ByteCountFormatter.string(fromByteCount: Int64(memoryDelta), countStyle: .memory))")

        // Assert reasonable memory usage
        XCTAssertLessThan(memoryAfter, 4 * 1024 * 1024 * 1024, "Should use less than 4GB memory")
    }

    /// Test memory cleanup after operations
    func testMemoryCleanup() async throws {
        print("🧹 Testing memory cleanup...")

        chatEngine.selectedModel = testModel

        // Generate some conversation history
        for i in 1...3 {
            _ = try await chatEngine.generate(prompt: "Conversation message \(i)")
        }

        let memoryWithHistory = getCurrentMemoryUsage()

        // Clear conversation
        await chatEngine.clearHistory()

        let memoryAfterCleanup = getCurrentMemoryUsage()
        let cleanupDelta = memoryWithHistory - memoryAfterCleanup

        performanceMetrics.memoryAfterCleanup = memoryAfterCleanup
        performanceMetrics.cleanupDelta = cleanupDelta

        print("📊 Memory cleanup:")
        print("   With history: \(ByteCountFormatter.string(fromByteCount: Int64(memoryWithHistory), countStyle: .memory))")
        print("   After cleanup: \(ByteCountFormatter.string(fromByteCount: Int64(memoryAfterCleanup), countStyle: .memory))")
        print("   Freed: \(ByteCountFormatter.string(fromByteCount: Int64(cleanupDelta), countStyle: .memory))")

        // Assert cleanup effectiveness
        XCTAssertGreaterThan(cleanupDelta, 0, "Should free some memory after cleanup")
    }

    // MARK: - LoRA Adapter Performance Tests

    /// Test LoRA adapter application performance
    func testLoRAAdapterApplicationPerformance() async throws {
        print("🔌 Testing LoRA adapter application performance...")

        // Skip if no adapters available
        await adapterManager.loadAdapters()

        guard let testAdapter = adapterManager.downloadedAdapters.first else {
            throw XCTSkip("No downloaded LoRA adapter available - run adapter tests first")
        }

        chatEngine.selectedModel = testModel

        // Measure base performance
        let startBase = Date()
        _ = try await chatEngine.generate(prompt: "Base performance test")
        let endBase = Date()
        let baseTime = endBase.timeIntervalSince(startBase)

        // Apply adapter
        try await adapterManager.applyAdapter(testAdapter)

        // Measure adapter performance
        let startAdapter = Date()
        _ = try await chatEngine.generate(prompt: "Adapter performance test")
        let endAdapter = Date()
        let adapterTime = endAdapter.timeIntervalSince(startAdapter)

        // Calculate overhead
        let adapterOverhead = adapterTime - baseTime
        let overheadPercentage = (adapterOverhead / baseTime) * 100

        performanceMetrics.adapterOverhead = adapterOverhead
        performanceMetrics.adapterOverheadPercentage = overheadPercentage

        print("📊 LoRA adapter performance:")
        print("   Base time: \(String(format: "%.2f", baseTime)) seconds")
        print("   Adapter time: \(String(format: "%.2f", adapterTime)) seconds")
        print("   Overhead: \(String(format: "%.2f", adapterOverhead)) seconds (\(String(format: "%.1f", overheadPercentage))%)")

        // Assert reasonable adapter overhead
        XCTAssertLessThan(overheadPercentage, 50.0, "Adapter overhead should be less than 50%")
    }

    /// Test adapter switching performance
    func testAdapterSwitchingPerformance() async throws {
        print("🔄 Testing adapter switching performance...")

        await adapterManager.loadAdapters()

        let adapters = adapterManager.downloadedAdapters
        guard adapters.count >= 2 else {
            throw XCTSkip("Need at least 2 downloaded adapters for switching test")
        }

        chatEngine.selectedModel = testModel

        var switchingTimes: [TimeInterval] = []

        for i in 0..<min(3, adapters.count) {
            let adapter = adapters[i]

            let startTime = Date()
            try await adapterManager.applyAdapter(adapter)
            _ = try await chatEngine.generate(prompt: "Switch test \(i)")
            let endTime = Date()

            let switchingTime = endTime.timeIntervalSince(startTime)
            switchingTimes.append(switchingTime)

            print("🔄 Adapter switch \(i+1): \(String(format: "%.2f", switchingTime)) seconds")
        }

        let averageSwitchTime = switchingTimes.reduce(0, +) / Double(switchingTimes.count)
        performanceMetrics.averageSwitchTime = averageSwitchTime

        print("📊 Average adapter switch time: \(String(format: "%.2f", averageSwitchTime)) seconds")

        // Assert reasonable switching time
        XCTAssertLessThan(averageSwitchTime, 3.0, "Adapter switching should be under 3 seconds")
    }

    // MARK: - Document Processing Performance

    /// Test document processing performance
    func testDocumentProcessingPerformance() async throws {
        print("📄 Testing document processing performance...")

        // Create test documents of different sizes
        let smallContent = "This is a small test document."
        let mediumContent = String(repeating: "This is a medium test document with more content. ", count: 100)
        let largeContent = String(repeating: "This is a large test document with substantial content for performance testing. ", count: 500)

        let testDocuments = [
            ("small", smallContent),
            ("medium", mediumContent),
            ("large", largeContent)
        ]

        for (size, content) in testDocuments {
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("perf-test-\(size).txt")

            try content.write(to: testFile, atomically: true, encoding: .utf8)

            let startTime = Date()
            await chatEngine.handlePickedDocument(url: testFile)
            let endTime = Date()

            let processingTime = endTime.timeIntervalSince(startTime)

            print("📄 \(size) document processing: \(String(format: "%.3f", processingTime)) seconds")

            // Cleanup
            try? FileManager.default.removeItem(at: testFile)

            // Assert reasonable processing times
            XCTAssertLessThan(processingTime, 2.0, "\(size) document processing should be under 2 seconds")
        }
    }

    // MARK: - System Resource Tests

    /// Test concurrent operations performance
    func testConcurrentOperations() async throws {
        print("⚡ Testing concurrent operations...")

        chatEngine.selectedModel = testModel

        // Run multiple operations concurrently
        async let operation1 = chatEngine.generate(prompt: "Concurrent test 1")
        async let operation2 = chatEngine.generate(prompt: "Concurrent test 2")
        async let operation3 = chatEngine.generate(prompt: "Concurrent test 3")

        let startTime = Date()
        let (response1, response2, response3) = try await (operation1, operation2, operation3)
        let endTime = Date()

        let concurrentTime = endTime.timeIntervalSince(startTime)
        let serialTimeEstimate = performanceMetrics.averageResponseTime * 3
        let speedup = serialTimeEstimate / concurrentTime

        performanceMetrics.concurrentTime = concurrentTime
        performanceMetrics.concurrencySpeedup = speedup

        print("📊 Concurrent operations:")
        print("   Concurrent time: \(String(format: "%.2f", concurrentTime)) seconds")
        print("   Serial estimate: \(String(format: "%.2f", serialTimeEstimate)) seconds")
        print("   Speedup: \(String(format: "%.1f", speedup))x")

        // Verify all responses were generated
        XCTAssertFalse(response1.isEmpty, "Response 1 should not be empty")
        XCTAssertFalse(response2.isEmpty, "Response 2 should not be empty")
        XCTAssertFalse(response3.isEmpty, "Response 3 should not be empty")
    }

    // MARK: - Helper Methods

    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

/// Performance metrics data structure
struct PerformanceMetrics {
    var coldStartTime: TimeInterval = 0
    var averageResponseTime: TimeInterval = 0
    var minResponseTime: TimeInterval = 0
    var maxResponseTime: TimeInterval = 0
    var streamingThroughput: Double = 0
    var streamingChunkCount: Int = 0
    var memoryUsage: UInt64 = 0
    var memoryDelta: Int64 = 0
    var memoryAfterCleanup: UInt64 = 0
    var cleanupDelta: Int64 = 0
    var adapterOverhead: TimeInterval = 0
    var adapterOverheadPercentage: Double = 0
    var averageSwitchTime: TimeInterval = 0
    var concurrentTime: TimeInterval = 0
    var concurrencySpeedup: Double = 0

    func summary() -> String {
        return """
        Performance Summary:
        Cold Start: \(String(format: "%.2f", coldStartTime))s
        Average Response: \(String(format: "%.2f", averageResponseTime))s
        Streaming Throughput: \(String(format: "%.1f", streamingThroughput)) chars/s
        Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory))
        Adapter Overhead: \(String(format: "%.1f", adapterOverheadPercentage))%
        Concurrency Speedup: \(String(format: "%.1f", concurrencySpeedup))x
        """
    }
}
