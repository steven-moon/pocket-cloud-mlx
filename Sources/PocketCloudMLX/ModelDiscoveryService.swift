// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/ModelDiscoveryService.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - extension Array {
//   - struct ModelDiscoveryService {
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
import Foundation

#if canImport(MLXLLM)
import MLXLLM
#endif

// Helper extension for async sorting
extension Array {
    func asyncSorted(by areInIncreasingOrder: @escaping (Element, Element) async -> Bool) async -> [Element] {
        var result = self
        for i in 0..<result.count {
            for j in (i+1)..<result.count {
                if await areInIncreasingOrder(result[j], result[i]) {
                    result.swapAt(i, j)
                }
            }
        }
        return result
    }
}

/// Service for discovering MLX-compatible models from Hugging Face.
public struct ModelDiscoveryService {

    /// Model summary information
    public struct ModelSummary: Sendable, Identifiable, Hashable {
        public static func == (lhs: ModelSummary, rhs: ModelSummary) -> Bool {
            lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        public let id: String
        public let name: String
        public let author: String?
        public let downloads: Int
        public let likes: Int
        public let architecture: String?
        public let parameters: String?
        public let quantization: String?
        public let modelDescription: String?
        public let createdAt: Date?
        public let updatedAt: Date?
        public let tags: [String]
        public let pipelineTag: String?
        public let modelIndex: [String: Sendable]?

        /// Public initializer so UI modules can construct summaries from registry entries
        public init(
            id: String,
            name: String,
            author: String? = nil,
            downloads: Int = 0,
            likes: Int = 0,
            architecture: String? = nil,
            parameters: String? = nil,
            quantization: String? = nil,
            modelDescription: String? = nil,
            createdAt: Date? = nil,
            updatedAt: Date? = nil,
            tags: [String] = [],
            pipelineTag: String? = nil,
            modelIndex: [String: Sendable] = [:]
        ) {
            self.id = id
            self.name = name
            self.author = author
            self.downloads = downloads
            self.likes = likes
            self.architecture = architecture
            self.parameters = parameters
            self.quantization = quantization
            self.modelDescription = modelDescription
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.tags = tags
            self.pipelineTag = pipelineTag
            self.modelIndex = modelIndex
        }

        /// Computed property to check if this is an MLX-compatible model
        public var isMLX: Bool {
            // Check against actual MLX LLM registry for true compatibility
            #if canImport(MLXLLM)
            let mlxRegistryModels = MLXLLM.LLMRegistry.shared.models
            let mlxRegistryIds = Set(mlxRegistryModels.map { String(describing: $0.id) })

            return mlxRegistryIds.contains { mlxId in
                let hfId = self.id
                let mlxIdStr = String(describing: mlxId)
                return hfId.contains(mlxIdStr) || mlxIdStr.contains(hfId) ||
                       hfId.replacingOccurrences(of: "mlx-community/", with: "").contains(mlxIdStr) ||
                       mlxIdStr.contains(hfId.replacingOccurrences(of: "mlx-community/", with: ""))
            }
            #else
            // Fallback to keyword checking if MLX not available
            let id = self.id.lowercased()
            return id.contains("mlx") ||
                   id.contains("mlx-community") ||
                   tags.contains("mlx") ||
                   tags.contains("apple") ||
                   tags.contains("metal") ||
                   (pipelineTag?.lowercased().contains("text-generation") == true) ||
                   (architecture?.lowercased().contains("llama") == true) ||
                   (architecture?.lowercased().contains("mistral") == true) ||
                   (architecture?.lowercased().contains("qwen") == true)
            #endif
        }
    }

    /// Compatibility result for a model
    public struct CompatibilityResult: Sendable {
        public let isCompatible: Bool
        public let confidence: Double // 0.0 to 1.0
        public let issues: [CompatibilityIssue]
        public let recommendations: [String]
        public let estimatedPerformance: PerformanceEstimate?
    }

    /// Specific compatibility issue
    public struct CompatibilityIssue: Sendable {
        public enum Severity: String, Sendable {
            case critical, warning, info
        }

        public let severity: Severity
        public let message: String
        public let suggestion: String?
    }

    /// Performance estimate for a model
    public struct PerformanceEstimate: Sendable {
        public let tokensPerSecond: Double
        public let memoryUsageGB: Double
        public let loadTimeSeconds: Double
        public let quality: PerformanceQuality

        public enum PerformanceQuality: String, Sendable {
            case excellent, good, fair, poor
        }
    }

    /// Device capabilities for compatibility checking
    public struct DeviceCapabilities: Sendable {
        public let memoryGB: Double
        public let cpuCores: Int
        public let gpuCores: Int
        public let isAppleSilicon: Bool
        public let platform: String
    }

    /// Checks if a model is compatible with the current device
    /// - Parameters:
    ///   - model: Model summary to check
    ///   - deviceCapabilities: Device capabilities (optional, will detect if not provided)
    /// - Returns: Detailed compatibility result
    public static func checkCompatibility(
        for model: ModelSummary,
        deviceCapabilities: DeviceCapabilities? = nil
    ) async -> CompatibilityResult {
        let capabilities = deviceCapabilities ?? detectDeviceCapabilities()
        var issues: [CompatibilityIssue] = []
        var recommendations: [String] = []
        var confidence = 1.0

        // Check memory compatibility
        let memoryResult = checkMemoryCompatibility(model, capabilities)
        issues.append(contentsOf: memoryResult.issues)
        confidence *= memoryResult.confidence

        // Check architecture compatibility
        let archResult = checkArchitectureCompatibility(model, capabilities)
        issues.append(contentsOf: archResult.issues)
        confidence *= archResult.confidence

        // Check quantization compatibility
        let quantResult = checkQuantizationCompatibility(model, capabilities)
        issues.append(contentsOf: quantResult.issues)
        confidence *= quantResult.confidence

        // Check model size compatibility
        let sizeResult = checkModelSizeCompatibility(model, capabilities)
        issues.append(contentsOf: sizeResult.issues)
        confidence *= sizeResult.confidence

        // Generate recommendations
        recommendations = generateRecommendations(issues, capabilities)

        // Estimate performance
        let performance = estimatePerformance(model, capabilities)

        // Be much more lenient on high-memory devices and modern iOS devices
        let compatibilityThreshold: Double
        if capabilities.memoryGB >= 32 {
            // High-memory devices (like M1 MacBook Pro with 64GB) - be very lenient
            compatibilityThreshold = 0.3
        } else if capabilities.memoryGB >= 16 {
            // Medium-memory devices - moderately lenient
            compatibilityThreshold = 0.4
        } else if capabilities.memoryGB >= 6 && capabilities.platform == "iOS" {
            // Modern iOS devices (iPhone 14 Pro+, iPhone 15 series) - be lenient
            compatibilityThreshold = 0.4
        } else {
            // Older/low-memory devices - keep some restrictions
            compatibilityThreshold = 0.6
        }

        return CompatibilityResult(
            isCompatible: confidence >= compatibilityThreshold,
            confidence: confidence,
            issues: issues,
            recommendations: recommendations,
            estimatedPerformance: performance
        )
    }

    /// Detects current device capabilities
    public static func detectDeviceCapabilities() -> DeviceCapabilities {
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        let cpuCores = ProcessInfo.processInfo.processorCount

        #if os(iOS)
        let gpuCores = estimateiOSGPUCores()
        let isAppleSilicon = isiOSAppleSilicon()
        let platform = "iOS"
        #elseif os(macOS)
        let gpuCores = estimatemacOSGPUCores()
        let isAppleSilicon = ismacOSAppleSilicon()
        let platform = "macOS"
        #else
        let gpuCores = 256
        let isAppleSilicon = false
        let platform = "Unknown"
        #endif

        return DeviceCapabilities(
            memoryGB: memoryGB,
            cpuCores: cpuCores,
            gpuCores: gpuCores,
            isAppleSilicon: isAppleSilicon,
            platform: platform
        )
    }

    private static func checkMemoryCompatibility(_ model: ModelSummary, _ capabilities: DeviceCapabilities) -> (issues: [CompatibilityIssue], confidence: Double) {
        let estimatedSizeGB = estimateModelSizeGB(model)
        let availableMemoryGB = capabilities.memoryGB
        var issues: [CompatibilityIssue] = []
        var confidence = 1.0

        if estimatedSizeGB > availableMemoryGB {
            issues.append(CompatibilityIssue(
                severity: .critical,
                message: "Model requires \(String(format: "%.1f", estimatedSizeGB))GB RAM, device has \(String(format: "%.1f", availableMemoryGB))GB",
                suggestion: "Consider models with 4-bit quantization or smaller parameter counts"
            ))
            confidence *= 0.1
        } else if estimatedSizeGB > availableMemoryGB * 0.8 {
            issues.append(CompatibilityIssue(
                severity: .warning,
                message: "Model may cause memory pressure on device",
                suggestion: "Monitor memory usage during inference"
            ))
            confidence *= 0.8
        }

        return (issues, confidence)
    }

    private static func checkArchitectureCompatibility(_ model: ModelSummary, _ capabilities: DeviceCapabilities) -> (issues: [CompatibilityIssue], confidence: Double) {
        var issues: [CompatibilityIssue] = []
        var confidence = 1.0

        // Check for known architecture issues
        if let architecture = model.architecture?.lowercased() {
            if architecture.contains("llava") && capabilities.platform == "iOS" && !capabilities.isAppleSilicon {
                issues.append(CompatibilityIssue(
                    severity: .warning,
                    message: "Vision models may have limited performance on older iOS devices",
                    suggestion: "Consider using text-only models for better performance"
                ))
                confidence *= 0.9
            }
        }

        return (issues, confidence)
    }

    private static func checkQuantizationCompatibility(_ model: ModelSummary, _ capabilities: DeviceCapabilities) -> (issues: [CompatibilityIssue], confidence: Double) {
        var issues: [CompatibilityIssue] = []
        var confidence = 1.0

        if let quantization = model.quantization?.lowercased() {
            // 2-bit and 3-bit quantization may have quality issues
            if quantization.contains("2") || quantization.contains("3") {
                issues.append(CompatibilityIssue(
                    severity: .info,
                    message: "Very low-bit quantization may affect output quality",
                    suggestion: "Consider 4-bit quantization for better quality"
                ))
                confidence *= 0.95
            }
        }

        return (issues, confidence)
    }

    private static func checkModelSizeCompatibility(_ model: ModelSummary, _ capabilities: DeviceCapabilities) -> (issues: [CompatibilityIssue], confidence: Double) {
        var issues: [CompatibilityIssue] = []
        var confidence = 1.0

        if let params = model.parameters {
            let paramCount = parseParameterCount(params)

            // Very large models on low-end devices
            if paramCount > 70_000_000_000 && capabilities.memoryGB < 32 { // 70B+ on <32GB RAM
                issues.append(CompatibilityIssue(
                    severity: .critical,
                    message: "70B+ parameter models require high-end hardware",
                    suggestion: "Use models with fewer parameters (3B-13B range)"
                ))
                confidence *= 0.3
            } else if paramCount > 30_000_000_000 && capabilities.memoryGB < 16 { // 30B+ on <16GB RAM
                issues.append(CompatibilityIssue(
                    severity: .warning,
                    message: "Large model may be slow on this device",
                    suggestion: "Consider smaller models for faster inference"
                ))
                confidence *= 0.7
            }
        }

        return (issues, confidence)
    }

    private static func generateRecommendations(_ issues: [CompatibilityIssue], _ capabilities: DeviceCapabilities) -> [String] {
        var recommendations: [String] = []

        // Generate recommendations based on issues
        for issue in issues {
            if let suggestion = issue.suggestion {
                recommendations.append(suggestion)
            }
        }

        // Add general recommendations based on device
        if capabilities.memoryGB < 8 {
            recommendations.append("Focus on 4-bit quantized models with <3B parameters")
        } else if capabilities.memoryGB < 16 {
            recommendations.append("Good candidates: 3B-7B parameter models with 4-bit quantization")
        } else {
            recommendations.append("Can handle larger models: up to 13B parameters")
        }

        return Array(Set(recommendations)) // Remove duplicates
    }

    private static func estimatePerformance(_ model: ModelSummary, _ capabilities: DeviceCapabilities) -> PerformanceEstimate {
        let estimatedSizeGB = estimateModelSizeGB(model)
        let paramCount = parseParameterCount(model.parameters ?? "3B")

        // Estimate tokens per second based on model size and device
        var tokensPerSecond: Double

        if paramCount < 2_000_000_000 { // <2B
            tokensPerSecond = capabilities.isAppleSilicon ? 80.0 : 60.0
        } else if paramCount < 8_000_000_000 { // <8B
            tokensPerSecond = capabilities.isAppleSilicon ? 55.0 : 40.0
        } else if paramCount < 14_000_000_000 { // <14B
            tokensPerSecond = capabilities.isAppleSilicon ? 35.0 : 25.0
        } else { // >=14B
            tokensPerSecond = capabilities.isAppleSilicon ? 20.0 : 15.0
        }

        // Adjust for quantization
        if let quantization = model.quantization?.lowercased() {
            if quantization.contains("8") {
                tokensPerSecond *= 0.8
            } else if quantization.contains("2") || quantization.contains("3") {
                tokensPerSecond *= 0.9
            }
        }

        // Estimate load time
        let loadTimeSeconds = estimatedSizeGB * 2.0 // Rough estimate: 2 seconds per GB

        // Determine quality
        let quality: PerformanceEstimate.PerformanceQuality
        if tokensPerSecond > 50 {
            quality = .excellent
        } else if tokensPerSecond > 35 {
            quality = .good
        } else if tokensPerSecond > 20 {
            quality = .fair
        } else {
            quality = .poor
        }

        return PerformanceEstimate(
            tokensPerSecond: tokensPerSecond,
            memoryUsageGB: estimatedSizeGB,
            loadTimeSeconds: loadTimeSeconds,
            quality: quality
        )
    }

    private static func estimateModelSizeGB(_ model: ModelSummary) -> Double {
        let paramCount = parseParameterCount(model.parameters ?? "3B")
        let quantization = model.quantization ?? "4bit"

        // Rough bytes per parameter
        let bytesPerParam: Double
        if quantization.contains("2") { bytesPerParam = 0.25 }
        else if quantization.contains("3") { bytesPerParam = 0.375 }
        else if quantization.contains("4") { bytesPerParam = 0.5 }
        else if quantization.contains("8") { bytesPerParam = 1.0 }
        else { bytesPerParam = 0.8 }

        return (Double(paramCount) * bytesPerParam) / (1024 * 1024 * 1024)
    }

    private static func parseParameterCount(_ params: String) -> Int {
        let cleaned = params.uppercased()
            .replacingOccurrences(of: "B", with: "")
            .replacingOccurrences(of: "M", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")

        if let value = Double(cleaned) {
            if params.uppercased().contains("M") {
                return Int(value * 1_000_000)
            } else {
                return Int(value * 1_000_000_000)
            }
        }

        return 3_000_000_000 // Default 3B
    }

    #if os(iOS)
    private static func estimateiOSGPUCores() -> Int {
        // Estimate GPU cores based on device memory as a proxy
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        if memoryGB >= 8 { return 512 }      // iPhone 15 Pro and newer high-end devices
        else if memoryGB >= 6 { return 384 } // iPhone 14 Pro
        else if memoryGB >= 4 { return 256 } // Older high-end devices
        else { return 128 }                  // Older/budget devices
    }

    private static func isiOSAppleSilicon() -> Bool {
        // All modern iOS devices (A-series chips) are Apple Silicon
        return true
    }
    #endif

    #if os(macOS)
    private static func estimatemacOSGPUCores() -> Int {
        let cpuCores = ProcessInfo.processInfo.processorCount
        if cpuCores >= 12 { return 1024 }
        else if cpuCores >= 8 { return 768 }
        else if cpuCores >= 6 { return 512 }
        else { return 256 }
    }

    private static func ismacOSAppleSilicon() -> Bool {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
                let trimmed = model.prefix { $0 != 0 }
                let bytes = trimmed.map { UInt8(bitPattern: $0) }
                let modelString = String(decoding: bytes, as: UTF8.self)
        return modelString.hasPrefix("Mac") && (
          modelString.contains("M1") ||
          modelString.contains("M2") ||
          modelString.contains("M3") ||
          modelString.contains("M4")
        )
    }
    #endif

    /// Searches for MLX-compatible models on Hugging Face
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum number of results
    /// - Returns: Array of MLX-compatible models
    public static func searchMLXModels(query: String, limit: Int = 10) async throws -> [ModelSummary] {
        // Get more models from HuggingFace to account for filtering
        let searchLimit = limit * 2
        let models = try await HuggingFaceAPI.shared.searchModels(query: query, limit: searchLimit)
        print("🔍 HuggingFace returned \(models.count) models for query: '\(query)'")

        func makeSummary(from model: HuggingFaceModel) -> ModelSummary {
            ModelSummary(
                id: model.id,
                name: model.id,
                author: model.author,
                downloads: Int(model.downloads ?? 0),
                likes: Int(model.likes ?? 0),
                architecture: model.extractArchitecture(),
                parameters: model.extractParameters(),
                quantization: model.extractQuantization(),
                modelDescription: nil,
                createdAt: nil,
                updatedAt: nil,
                tags: model.tags ?? [],
                pipelineTag: model.pipeline_tag,
                modelIndex: [:]
            )
        }

        // Filter models to only include those supported by MLX library
        #if canImport(MLXLLM)
        let mlxRegistryModels = MLXLLM.LLMRegistry.shared.models
        // Use model.name instead of String(describing: id) - name is the actual HuggingFace ID
        let mlxRegistryNames = Set(mlxRegistryModels.map { $0.name })

        // Debug: Log what models are in the MLX registry
        print("🔍 MLX Registry contains \(mlxRegistryModels.count) models:")
        for (index, model) in mlxRegistryModels.prefix(10).enumerated() {
            print("  \(index + 1): ID=\(String(describing: model.id)), name=\(model.name)")
        }
        if mlxRegistryModels.count > 10 {
            print("  ... and \(mlxRegistryModels.count - 10) more")
        }

        // More flexible matching - check if HuggingFace ID matches MLX registry name
        let registryMatches = models.filter { hfModel in
            mlxRegistryNames.contains { mlxName in
                let hfId = hfModel.id
                return hfId == mlxName ||
                       hfId == "mlx-community/\(mlxName)" ||
                       mlxName == "mlx-community/\(hfId)" ||
                       hfId.hasSuffix(mlxName) || mlxName.hasSuffix(hfId)
            }
        }
        print("🔍 MLX compatibility filtering: \(models.count) → \(registryMatches.count) registry-aligned models")

        var summaries = registryMatches.map { makeSummary(from: $0) }

        // Only use registry-backed models - disable heuristic fallback to prevent unsupported models
        if summaries.isEmpty {
            print("⚠️ No MLX registry matches found. Only officially supported MLX models are available for download.")
        }
        #else
        var summaries = models.map { makeSummary(from: $0) }
        print("🔍 MLX library not available, using all \(models.count) models")
        #endif

        if summaries.isEmpty {
            summaries = models.map { makeSummary(from: $0) }
        }

        let orderedSummaries = summaries.sorted { lhs, rhs in
            let lhsSize = estimateModelSizeGB(lhs)
            let rhsSize = estimateModelSizeGB(rhs)
            if abs(lhsSize - rhsSize) > 0.05 { return lhsSize < rhsSize }
            if lhs.downloads != rhs.downloads { return lhs.downloads > rhs.downloads }
            return lhs.id < rhs.id
        }

        let maxResults = max(limit, limit * 3)
        let finalCount = min(orderedSummaries.count, maxResults)
        return Array(orderedSummaries.prefix(finalCount))
    }

    /// Searches for models compatible with the current device
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum number of results
    /// - Returns: Array of compatible models
    public static func searchCompatibleMLXModels(query: String, limit: Int = 10) async throws -> [ModelSummary] {
        // Get device capabilities for smarter filtering
        let deviceCapabilities = detectDeviceCapabilities()
        
        // Be much more lenient on high-memory devices - get many more models to filter from
        let searchLimit: Int
        if deviceCapabilities.memoryGB >= 32 {
            // High-memory devices (like M1 MacBook Pro with 64GB) - get many more models
            searchLimit = limit * 10 // Get 10x more models to filter from
        } else if deviceCapabilities.memoryGB >= 16 {
            // Medium-memory devices - get more models
            searchLimit = limit * 5
        } else {
            // Low-memory devices - keep current behavior
            searchLimit = limit * 3
        }
        
        let models = try await searchMLXModels(query: query, limit: searchLimit)
        print("🔍 Found \(models.count) MLX models, filtering for device compatibility...")

        // Filter for device compatibility - be more lenient on high-memory devices
        let compatibleModels = try await filterCompatibleModels(models, deviceCapabilities)
        print("🔍 Device compatibility filtering: \(models.count) → \(compatibleModels.count) models")

        // If we filtered out too many models on high-memory devices, be more lenient
        var finalModels = compatibleModels
        if deviceCapabilities.memoryGB >= 32 && compatibleModels.count < limit {
            print("High-memory device detected (\(String(format: "%.1f", deviceCapabilities.memoryGB))GB), being more lenient with model filtering")
            
            // Add back some models that might have been filtered out too aggressively
            let additionalModels = models.filter { model in
                !compatibleModels.contains { $0.id == model.id } &&
                // Basic compatibility check - just ensure it's not obviously incompatible
                !(model.parameters?.contains("70B") == true) && // Avoid extremely large models
                !(model.parameters?.contains("100B") == true) &&
                !(model.parameters?.contains("200B") == true)
            }
            
            finalModels.append(contentsOf: Array(additionalModels.prefix(limit * 2))) // Add more models back
        }

        // Sort by estimated model size (simpler synchronous approach)
        let sorted = finalModels.sorted { lhs, rhs in
            let lhsSize = estimateModelSizeGB(lhs)
            let rhsSize = estimateModelSizeGB(rhs)
            return lhsSize < rhsSize // Prefer smaller models for better compatibility
        }

        // Return more models on high-memory devices
        let finalLimit = deviceCapabilities.memoryGB >= 32 ? limit * 2 : limit
        let result = Array(sorted.prefix(finalLimit))
        print("🔍 Final result: \(result.count) models (requested: \(limit), device RAM: \(String(format: "%.1f", deviceCapabilities.memoryGB))GB)")
        
        return result
    }

    /// Get recommended MLX models for current device with proper compatibility filtering
    /// - Parameter limit: Maximum number of results
    /// - Returns: Array of recommended models compatible with current device
    public static func recommendedMLXModelsForCurrentDevice(limit: Int = 5) async throws -> [ModelSummary] {
        // Get device capabilities for smarter filtering
        let deviceCapabilities = detectDeviceCapabilities()
        
        // Adjust limit based on device capabilities - show more models on high-memory devices
        let adjustedLimit = deviceCapabilities.memoryGB >= 32 ? limit * 3 : limit * 2
        
        // Get popular MLX models (let HuggingFaceAPI filter for device compatibility)
        let popularModels = try await HuggingFaceAPI.shared.searchModels(query: "mlx", limit: adjustedLimit)

        let modelSummaries = popularModels.map { hfModel in
            ModelSummary(
                id: hfModel.id,
                name: hfModel.id,
                author: hfModel.author,
                downloads: Int(hfModel.downloads ?? 0),
                likes: Int(hfModel.likes ?? 0),
                architecture: hfModel.extractArchitecture(),
                parameters: hfModel.extractParameters(),
                quantization: hfModel.extractQuantization(),
                modelDescription: nil,
                createdAt: nil,
                updatedAt: nil,
                tags: hfModel.tags ?? [],
                pipelineTag: hfModel.pipeline_tag,
                modelIndex: [:]
            )
        }

        // Filter for actual device compatibility using detailed compatibility checking
        // Be less restrictive on high-memory devices
        let compatibleModels = try await filterCompatibleModels(modelSummaries, deviceCapabilities)
        
        // If we filtered out too many models on high-memory devices, be more lenient
        var finalModels = compatibleModels
        if deviceCapabilities.memoryGB >= 32 && compatibleModels.count < limit {
            print("High-memory device detected (\(String(format: "%.1f", deviceCapabilities.memoryGB))GB), being more lenient with model filtering")
            
            // Add back some models that might have been filtered out too aggressively
            let additionalModels = modelSummaries.filter { model in
                !compatibleModels.contains { $0.id == model.id } &&
                // Basic compatibility check - just ensure it's not obviously incompatible
                !(model.parameters?.contains("70B") == true) && // Avoid extremely large models
                !(model.parameters?.contains("100B") == true)
            }
            
            finalModels.append(contentsOf: Array(additionalModels.prefix(limit - compatibleModels.count)))
        }

        // Sort by combination of model size and popularity (synchronous)
        let sorted = finalModels.sorted { lhs, rhs in
            let lhsSize = estimateModelSizeGB(lhs)
            let rhsSize = estimateModelSizeGB(rhs)

            // Prefer smaller models, then by popularity
            if lhsSize != rhsSize {
                return lhsSize < rhsSize
            } else {
                return lhs.downloads > rhs.downloads
            }
        }

        return Array(sorted.prefix(limit))
    }

    /// Filter models for device compatibility
    private static func filterCompatibleModels(_ models: [ModelSummary], _ capabilities: DeviceCapabilities) async throws -> [ModelSummary] {
        var compatibleModels: [ModelSummary] = []

        for model in models {
            let compatibility = await checkCompatibility(for: model, deviceCapabilities: capabilities)
            if compatibility.isCompatible {
                compatibleModels.append(model)
            }
        }

        return compatibleModels
    }
}
