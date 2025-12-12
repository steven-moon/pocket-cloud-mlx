// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUnitTests/PerformanceMonitoringTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class PerformanceMonitoringTests: XCTestCase {
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

/// Unit tests for MLX Engine performance monitoring and metrics
/// Tests performance tracking, benchmarking, memory usage, and optimization
class PerformanceMonitoringTests: XCTestCase {

    private var chatEngine: ChatEngine!
    private var mockLLMEngine: MockLLMEngine!
    private var performanceMonitor: PerformanceMonitor!
    private let testTimeout: TimeInterval = 30.0

    override func setUp() async throws {
        // Use real engine by default, only use mock if explicitly requested
        let useMockTests = ProcessInfo.processInfo.environment["FORCE_MOCK_TESTS"] == "true"

        if useMockTests {
            mockLLMEngine = MockLLMEngine()
            mockLLMEngine.supportedFeatures = [.performanceMonitoring]
            chatEngine = try await ChatEngine(llmEngine: mockLLMEngine)
        } else {
            // Use real MLX engine for testing
            let config = ModelConfiguration(
                name: "SmolLM2 Test",
                hubId: "mlx-community/SmolLM2-360M-Instruct",
                description: "Real MLX model for testing (DEFAULT)",
                modelType: .llm,
                gpuCacheLimit: 512 * 1024 * 1024,
                features: [.performanceMonitoring]
            )
            let realEngine = try await InferenceEngine.loadModel(config) { _ in }
            chatEngine = try await ChatEngine(llmEngine: realEngine)
        }
        performanceMonitor = PerformanceMonitor()
    }

    override func tearDown() async throws {
        await chatEngine?.cancelAllTasks()
        chatEngine = nil
        mockLLMEngine = nil
        performanceMonitor = nil
    }

    // MARK: - Performance Metrics Collection

    func testPerformanceMetricsCollection() async throws {
        let prompt = "Test performance metrics"

        _ = try await chatEngine.generateResponse(prompt)
        let metrics = chatEngine.performanceMetrics

        XCTAssertNotNil(metrics)
        XCTAssertGreaterThan(metrics.lastGenerationTime, 0)
        XCTAssertGreaterThan(metrics.tokensGenerated, 0)
        XCTAssertGreaterThan(metrics.tokensPerSecond, 0)
        XCTAssertTrue(mockLLMEngine.performanceMetricsCollected)
    }

    func testMetricsAccuracy() async throws {
        let prompts = ["Short", "This is a longer prompt for testing", "Very long prompt with lots of content for performance measurement and accuracy validation"]
        var totalTokens = 0
        var totalTime: TimeInterval = 0

        for prompt in prompts {
            let startTime = Date()
            let response = try await chatEngine.generateResponse(prompt)
            let endTime = Date()

            totalTime += endTime.timeIntervalSince(startTime)
            totalTokens += response.split(separator: " ").count
        }

        let metrics = chatEngine.performanceMetrics
        let averageTokensPerSecond = Double(totalTokens) / totalTime

        XCTAssertGreaterThan(metrics.tokensPerSecond, 0)
        XCTAssertLessThan(abs(metrics.tokensPerSecond - averageTokensPerSecond), 5.0) // Within 5 TPS tolerance
    }

    func testMemoryUsageTracking() async throws {
        let prompt = "Memory usage test"

        _ = try await chatEngine.generateResponse(prompt)
        let metrics = chatEngine.performanceMetrics

        XCTAssertGreaterThan(metrics.memoryUsageBytes, 0)
        XCTAssertGreaterThanOrEqual(metrics.gpuMemoryUsageBytes ?? 0, 0)
        XCTAssertTrue(mockLLMEngine.memoryUsageTracked)
    }

    func testCacheHitRateCalculation() async throws {
        // Generate multiple similar prompts to test caching
        let basePrompt = "Test caching with similar prompt"
        var responses: [String] = []

        for i in 1...5 {
            let prompt = "\(basePrompt) iteration \(i)"
            let response = try await chatEngine.generateResponse(prompt)
            responses.append(response)
        }

        let metrics = chatEngine.performanceMetrics

        XCTAssertGreaterThanOrEqual(metrics.cacheHitRate, 0.0)
        XCTAssertLessThanOrEqual(metrics.cacheHitRate, 1.0)
        XCTAssertTrue(mockLLMEngine.cachePerformanceTracked)
    }

    func testModelWarmingMetrics() async throws {
        let model = ModelConfiguration(
            name: "Test Model",
            hubId: "test/model",
            description: "Test model for warming",
            maxTokens: 128,
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: [.performanceMonitoring]
        )

        try await chatEngine.switchModel(to: model)
        let metrics = chatEngine.performanceMetrics

        XCTAssertNotNil(metrics.modelLoadTime)
        XCTAssertGreaterThan(metrics.modelLoadTime, 0)
        XCTAssertTrue(mockLLMEngine.modelWarmingTracked)
    }

    // MARK: - Performance Benchmarking

    func testBasicBenchmarking() async throws {
        let prompts = ["Hello", "How are you?", "What's the weather?"]
        let startTime = Date()

        for prompt in prompts {
            _ = try await chatEngine.generateResponse(prompt)
        }

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        let averageTime = totalTime / Double(prompts.count)

        XCTAssertGreaterThan(averageTime, 0)
        XCTAssertLessThan(averageTime, 10.0) // Should complete within 10 seconds
        XCTAssertTrue(mockLLMEngine.basicBenchmarkingPerformed)
    }

    func testConcurrentPerformance() async throws {
        let prompts = (1...10).map { "Concurrent test prompt \($0)" }
        let startTime = Date()

        // Execute all prompts concurrently
        try await withThrowingTaskGroup(of: String.self) { group in
            for prompt in prompts {
                group.addTask {
                    try await self.chatEngine.generateResponse(prompt)
                }
            }

            for try await _ in group {
                // Consume results
            }
        }

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        let throughput = Double(prompts.count) / totalTime

        XCTAssertGreaterThan(throughput, 0)
        XCTAssertLessThan(totalTime, 30.0) // Should complete within 30 seconds
        XCTAssertTrue(mockLLMEngine.concurrentBenchmarkingPerformed)
    }

    func testStreamingPerformance() async throws {
        let prompt = "Stream a long response for performance testing"
        var chunkCount = 0
        var totalCharacters = 0
        let startTime = Date()

        for try await chunk in chatEngine.streamResponse(prompt) {
            chunkCount += 1
            totalCharacters += chunk.count
            if chunkCount >= 20 { // Collect first 20 chunks
                break
            }
        }

        let endTime = Date()
        let streamingTime = endTime.timeIntervalSince(startTime)
        let charsPerSecond = Double(totalCharacters) / streamingTime

        XCTAssertGreaterThan(chunkCount, 0)
        XCTAssertGreaterThan(totalCharacters, 0)
        XCTAssertGreaterThan(charsPerSecond, 0)
        XCTAssertLessThan(streamingTime, 15.0) // Should complete within 15 seconds
        XCTAssertTrue(mockLLMEngine.streamingBenchmarkingPerformed)
    }

    // MARK: - Memory Optimization

    func testMemoryOptimizationTriggering() async throws {
        // Generate enough content to potentially trigger optimization
        for i in 1...5 {
            let prompt = "Memory intensive prompt \(i) with lots of content that might trigger optimization mechanisms in the MLX engine performance monitoring system"
            _ = try await chatEngine.generateResponse(prompt)
        }

        try await chatEngine.optimizeModel()
        XCTAssertTrue(mockLLMEngine.memoryOptimizationTriggered)
    }

    func testMemoryPressureHandling() async throws {
        mockLLMEngine.shouldSimulateMemoryPressure = true

        let prompt = "Test memory pressure handling"
        _ = try await chatEngine.generateResponse(prompt)

        XCTAssertTrue(mockLLMEngine.memoryPressureHandled)
        XCTAssertTrue(mockLLMEngine.cacheOptimizationTriggered)
    }

    func testGPUCacheManagement() async throws {
        let largePrompt = String(repeating: "Large prompt ", count: 100)
        _ = try await chatEngine.generateResponse(largePrompt)

        let metrics = chatEngine.performanceMetrics

        XCTAssertGreaterThanOrEqual(metrics.gpuMemoryUsageBytes ?? 0, 0)
        XCTAssertLessThanOrEqual(metrics.gpuMemoryUsageBytes ?? 0, 8 * 1024 * 1024 * 1024) // Max 8GB
        XCTAssertTrue(mockLLMEngine.gpuCacheManaged)
    }

    // MARK: - Performance Thresholds

    func testPerformanceThresholdValidation() async throws {
        let slowPrompt = "This is a very long prompt that should take longer to process and test performance thresholds for the MLX engine response times and latency measurements"

        let startTime = Date()
        _ = try await chatEngine.generateResponse(slowPrompt)
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)

        let metrics = chatEngine.performanceMetrics

        // Validate reasonable performance thresholds
        XCTAssertLessThan(processingTime, 30.0) // Max 30 seconds
        XCTAssertGreaterThan(metrics.tokensPerSecond, 5.0) // Min 5 tokens/second
        XCTAssertGreaterThan(metrics.memoryUsageBytes, 0)
        XCTAssertTrue(mockLLMEngine.performanceThresholdsValidated)
    }

    func testPerformanceRegressionDetection() async throws {
        let baselinePrompt = "Baseline performance test"
        let regressionPrompt = "Regression test with similar complexity"

        // Establish baseline
        let baselineStart = Date()
        _ = try await chatEngine.generateResponse(baselinePrompt)
        let baselineTime = Date().timeIntervalSince(baselineStart)

        // Test for regression
        let regressionStart = Date()
        _ = try await chatEngine.generateResponse(regressionPrompt)
        let regressionTime = Date().timeIntervalSince(regressionStart)

        // Regression should not be more than 50% slower
        XCTAssertLessThan(regressionTime, baselineTime * 1.5)
        XCTAssertTrue(mockLLMEngine.regressionDetectionPerformed)
    }

    // MARK: - Resource Monitoring

    func testResourceUsageTracking() async throws {
        let initialMetrics = chatEngine.performanceMetrics

        // Perform some operations
        for i in 1...3 {
            _ = try await chatEngine.generateResponse("Resource tracking test \(i)")
        }

        let finalMetrics = chatEngine.performanceMetrics

        // Memory usage should be tracked
        XCTAssertGreaterThanOrEqual(finalMetrics.memoryUsageBytes, initialMetrics.memoryUsageBytes)
        XCTAssertTrue(mockLLMEngine.resourceUsageTracked)
    }

    func testQueueLengthMonitoring() async throws {
        // Simulate queue buildup
        let prompts = (1...3).map { "Queue test \($0)" }

        async let responses = try await withThrowingTaskGroup(of: String.self) { group in
            for prompt in prompts {
                group.addTask {
                    try await self.chatEngine.generateResponse(prompt)
                }
            }

            var results: [String] = []
            for try await response in group {
                results.append(response)
            }
            return results
        }

        let metrics = chatEngine.performanceMetrics

        XCTAssertGreaterThanOrEqual(metrics.queueLength, 0)
        XCTAssertEqual(responses.count, prompts.count)
        XCTAssertTrue(mockLLMEngine.queueLengthMonitored)
    }

    func testSystemResourceMonitoring() async throws {
        _ = try await chatEngine.generateResponse("System monitoring test")

        XCTAssertTrue(mockLLMEngine.systemResourcesMonitored)
        XCTAssertNotNil(mockLLMEngine.cpuUsage)
        XCTAssertGreaterThanOrEqual(mockLLMEngine.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(mockLLMEngine.cpuUsage, 100.0)
    }

    // MARK: - Performance Reporting

    func testPerformanceReportGeneration() async throws {
        // Generate some performance data
        for i in 1...3 {
            _ = try await chatEngine.generateResponse("Performance report test \(i)")
        }

        let report = try await chatEngine.generatePerformanceReport()

        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("Performance Report"))
        XCTAssertTrue(report.contains("Average Response Time") || report.contains("Tokens/Second"))
        XCTAssertTrue(mockLLMEngine.performanceReportGenerated)
    }

    func testDetailedPerformanceMetrics() async throws {
        let prompt = "Detailed performance analysis test"

        _ = try await chatEngine.generateResponse(prompt)
        let detailedMetrics = chatEngine.detailedPerformanceMetrics

        XCTAssertNotNil(detailedMetrics)
        XCTAssertGreaterThanOrEqual(detailedMetrics.totalRequests, 1)
        XCTAssertGreaterThanOrEqual(detailedMetrics.averageLatency, 0)
        XCTAssertGreaterThanOrEqual(detailedMetrics.peakMemoryUsage, 0)
        XCTAssertTrue(mockLLMEngine.detailedMetricsCollected)
    }

    // MARK: - Error Handling & Recovery

    func testPerformanceErrorHandling() async throws {
        mockLLMEngine.shouldThrowPerformanceError = true

        do {
            _ = try await chatEngine.generateResponse("Performance error test")
            XCTFail("Expected performance error")
        } catch {
            XCTAssertTrue(error is PerformanceError)
            XCTAssertTrue(mockLLMEngine.performanceErrorHandled)
        }
    }

    func testPerformanceRecovery() async throws {
        mockLLMEngine.shouldSimulatePerformanceIssue = true

        do {
            _ = try await chatEngine.generateResponse("Performance issue test")
        } catch {
            // Attempt recovery
            let recovered = await chatEngine.attemptPerformanceRecovery()
            XCTAssertTrue(recovered)
            XCTAssertTrue(mockLLMEngine.performanceRecoveryAttempted)
        }
    }

    // MARK: - Benchmark Suite

    func testComprehensiveBenchmarkSuite() async throws {
        let benchmarkSuite = PerformanceBenchmarkSuite()

        let results = try await benchmarkSuite.runComprehensiveBenchmarks(chatEngine: chatEngine)

        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.values.allSatisfy { $0.averageTokensPerSecond > 0 })
        XCTAssertTrue(mockLLMEngine.benchmarkSuiteExecuted)
    }

    func testPerformanceComparison() async throws {
        let model1 = ModelConfiguration(
            name: "Model 1",
            hubId: "model1",
            description: "First model for comparison",
            maxTokens: 128,
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: [.performanceMonitoring]
        )

        let model2 = ModelConfiguration(
            name: "Model 2",
            hubId: "model2",
            description: "Second model for comparison",
            maxTokens: 128,
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: [.performanceMonitoring]
        )

        let prompt = "Performance comparison test"

        // Test Model 1
        try await chatEngine.switchModel(to: model1)
        let start1 = Date()
        _ = try await chatEngine.generateResponse(prompt)
        let time1 = Date().timeIntervalSince(start1)

        // Test Model 2
        try await chatEngine.switchModel(to: model2)
        let start2 = Date()
        _ = try await chatEngine.generateResponse(prompt)
        let time2 = Date().timeIntervalSince(start2)

        // Both should complete in reasonable time
        XCTAssertLessThan(time1, 15.0)
        XCTAssertLessThan(time2, 15.0)
        XCTAssertTrue(mockLLMEngine.performanceComparisonCompleted)
    }

    // MARK: - Optimization Testing

    func testPerformanceOptimization() async throws {
        let prompt = "Optimization test prompt"

        // Baseline performance
        let baselineStart = Date()
        _ = try await chatEngine.generateResponse(prompt)
        let baselineTime = Date().timeIntervalSince(baselineStart)

        // Apply optimization
        try await chatEngine.optimizePerformance()

        // Optimized performance
        let optimizedStart = Date()
        _ = try await chatEngine.generateResponse(prompt)
        let optimizedTime = Date().timeIntervalSince(optimizedStart)

        // Optimization should improve or maintain performance
        XCTAssertLessThanOrEqual(optimizedTime, baselineTime * 1.1) // Allow 10% tolerance
        XCTAssertTrue(mockLLMEngine.performanceOptimizationApplied)
    }

    func testAdaptivePerformance() async throws {
        // Simulate varying loads
        let lightPrompt = "Light load"
        let heavyPrompt = String(repeating: "Heavy load test ", count: 50)

        _ = try await chatEngine.generateResponse(lightPrompt)
        _ = try await chatEngine.generateResponse(heavyPrompt)

        XCTAssertTrue(mockLLMEngine.adaptivePerformanceEnabled)
        XCTAssertTrue(mockLLMEngine.loadBalancingPerformed)
    }
}

// MARK: - Supporting Types and Extensions

enum PerformanceError: Error {
    case monitoringFailed
    case optimizationFailed
    case resourceExhausted
}

struct PerformanceBenchmarkSuite {
    func runComprehensiveBenchmarks(chatEngine: ChatEngine) async throws -> [String: PerformanceResults] {
        let benchmarks = [
            "basic": ["Hello", "How are you?"],
            "medium": ["Explain machine learning", "What is AI?"],
            "complex": ["Write a detailed essay about artificial intelligence"]
        ]

        var results: [String: PerformanceResults] = [:]

        for (level, prompts) in benchmarks {
            var totalTime: TimeInterval = 0
            var totalTokens = 0

            for prompt in prompts {
                let startTime = Date()
                let response = try await chatEngine.generateResponse(prompt)
                let endTime = Date()

                totalTime += endTime.timeIntervalSince(startTime)
                totalTokens += response.split(separator: " ").count
            }

            let averageTime = totalTime / Double(prompts.count)
            let averageTokensPerSecond = Double(totalTokens) / totalTime

            results[level] = PerformanceResults(
                averageResponseTime: averageTime,
                averageTokensPerSecond: averageTokensPerSecond,
                totalRequests: prompts.count
            )
        }

        return results
    }
}

struct PerformanceResults {
    let averageResponseTime: TimeInterval
    let averageTokensPerSecond: Double
    let totalRequests: Int
}

extension MockLLMEngine {
    var performanceMetricsCollected: Bool {
        get { return objc_getAssociatedObject(self, &performanceMetricsCollectedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &performanceMetricsCollectedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var memoryUsageTracked: Bool {
        get { return objc_getAssociatedObject(self, &memoryUsageTrackedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &memoryUsageTrackedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var cachePerformanceTracked: Bool {
        get { return objc_getAssociatedObject(self, &cachePerformanceTrackedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &cachePerformanceTrackedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var modelWarmingTracked: Bool {
        get { return objc_getAssociatedObject(self, &modelWarmingTrackedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &modelWarmingTrackedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var basicBenchmarkingPerformed: Bool {
        get { return objc_getAssociatedObject(self, &basicBenchmarkingPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &basicBenchmarkingPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var concurrentBenchmarkingPerformed: Bool {
        get { return objc_getAssociatedObject(self, &concurrentBenchmarkingPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &concurrentBenchmarkingPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var streamingBenchmarkingPerformed: Bool {
        get { return objc_getAssociatedObject(self, &streamingBenchmarkingPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &streamingBenchmarkingPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var memoryOptimizationTriggered: Bool {
        get { return objc_getAssociatedObject(self, &memoryOptimizationTriggeredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &memoryOptimizationTriggeredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var memoryPressureHandled: Bool {
        get { return objc_getAssociatedObject(self, &memoryPressureHandledKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &memoryPressureHandledKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var cacheOptimizationTriggered: Bool {
        get { return objc_getAssociatedObject(self, &cacheOptimizationTriggeredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &cacheOptimizationTriggeredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var gpuCacheManaged: Bool {
        get { return objc_getAssociatedObject(self, &gpuCacheManagedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &gpuCacheManagedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var performanceThresholdsValidated: Bool {
        get { return objc_getAssociatedObject(self, &performanceThresholdsValidatedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &performanceThresholdsValidatedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var regressionDetectionPerformed: Bool {
        get { return objc_getAssociatedObject(self, &regressionDetectionPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &regressionDetectionPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var resourceUsageTracked: Bool {
        get { return objc_getAssociatedObject(self, &resourceUsageTrackedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &resourceUsageTrackedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var queueLengthMonitored: Bool {
        get { return objc_getAssociatedObject(self, &queueLengthMonitoredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &queueLengthMonitoredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var systemResourcesMonitored: Bool {
        get { return objc_getAssociatedObject(self, &systemResourcesMonitoredKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &systemResourcesMonitoredKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var cpuUsage: Double {
        get { return objc_getAssociatedObject(self, &cpuUsageKey) as? Double ?? 0.0 }
        set { objc_setAssociatedObject(self, &cpuUsageKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var performanceReportGenerated: Bool {
        get { return objc_getAssociatedObject(self, &performanceReportGeneratedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &performanceReportGeneratedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var detailedMetricsCollected: Bool {
        get { return objc_getAssociatedObject(self, &detailedMetricsCollectedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &detailedMetricsCollectedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var performanceErrorHandled: Bool {
        get { return objc_getAssociatedObject(self, &performanceErrorHandledKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &performanceErrorHandledKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var performanceRecoveryAttempted: Bool {
        get { return objc_getAssociatedObject(self, &performanceRecoveryAttemptedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &performanceRecoveryAttemptedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var benchmarkSuiteExecuted: Bool {
        get { return objc_getAssociatedObject(self, &benchmarkSuiteExecutedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &benchmarkSuiteExecutedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var performanceComparisonCompleted: Bool {
        get { return objc_getAssociatedObject(self, &performanceComparisonCompletedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &performanceComparisonCompletedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var performanceOptimizationApplied: Bool {
        get { return objc_getAssociatedObject(self, &performanceOptimizationAppliedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &performanceOptimizationAppliedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var adaptivePerformanceEnabled: Bool {
        get { return objc_getAssociatedObject(self, &adaptivePerformanceEnabledKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &adaptivePerformanceEnabledKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var loadBalancingPerformed: Bool {
        get { return objc_getAssociatedObject(self, &loadBalancingPerformedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &loadBalancingPerformedKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// Associated object keys
private var performanceMetricsCollectedKey: UInt8 = 0
private var memoryUsageTrackedKey: UInt8 = 0
private var cachePerformanceTrackedKey: UInt8 = 0
private var modelWarmingTrackedKey: UInt8 = 0
private var basicBenchmarkingPerformedKey: UInt8 = 0
private var concurrentBenchmarkingPerformedKey: UInt8 = 0
private var streamingBenchmarkingPerformedKey: UInt8 = 0
private var memoryOptimizationTriggeredKey: UInt8 = 0
private var memoryPressureHandledKey: UInt8 = 0
private var cacheOptimizationTriggeredKey: UInt8 = 0
private var gpuCacheManagedKey: UInt8 = 0
private var performanceThresholdsValidatedKey: UInt8 = 0
private var regressionDetectionPerformedKey: UInt8 = 0
private var resourceUsageTrackedKey: UInt8 = 0
private var queueLengthMonitoredKey: UInt8 = 0
private var systemResourcesMonitoredKey: UInt8 = 0
private var cpuUsageKey: UInt8 = 0
private var performanceReportGeneratedKey: UInt8 = 0
private var detailedMetricsCollectedKey: UInt8 = 0
private var performanceErrorHandledKey: UInt8 = 0
private var performanceRecoveryAttemptedKey: UInt8 = 0
private var benchmarkSuiteExecutedKey: UInt8 = 0
private var performanceComparisonCompletedKey: UInt8 = 0
private var performanceOptimizationAppliedKey: UInt8 = 0
private var adaptivePerformanceEnabledKey: UInt8 = 0
private var loadBalancingPerformedKey: UInt8 = 0
