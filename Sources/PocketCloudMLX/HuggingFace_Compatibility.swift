// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFace_Compatibility.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - enum DeviceCompatibilityCategory: String, CaseIterable, Codable {
//   - class DeviceCompatibilityAnalyzer {
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

// For device memory detection
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#endif

#if canImport(MLXLLM)
import MLXLLM
#endif

// MARK: - Device Compatibility Types

/// Device categories for model recommendations
public enum DeviceCompatibilityCategory: String, CaseIterable, Codable {
    case highEnd = "high_end"
    case midRange = "mid_range"
    case lowEnd = "low_end"
    case simulator = "simulator"

    public var displayName: String {
        switch self {
        case .highEnd: return "High-End Device"
        case .midRange: return "Mid-Range Device"
        case .lowEnd: return "Low-End Device"
        case .simulator: return "Simulator"
        }
    }

    public var description: String {
        switch self {
        case .highEnd: return "Latest devices with 8GB+ RAM"
        case .midRange: return "Modern devices with 4-8GB RAM"
        case .lowEnd: return "Older devices with <4GB RAM"
        case .simulator: return "iOS Simulator environment"
        }
    }

    public var maxMemoryGB: Double {
        switch self {
        case .highEnd: return 16.0  // Can handle large models
        case .midRange: return 8.0   // Medium models
        case .lowEnd: return 4.0     // Small models only
        case .simulator: return 32.0 // Simulator can handle anything
        }
    }
}

// MARK: - Device Analyzer

/// Analyzes device capabilities for model compatibility filtering
public class DeviceCompatibilityAnalyzer {
    private var cachedDeviceCategory: DeviceCompatibilityCategory?

    public init() {}

    public func detectDeviceCategory() -> DeviceCompatibilityCategory {
        if let cached = cachedDeviceCategory {
            return cached
        }

        #if targetEnvironment(simulator)
        cachedDeviceCategory = .simulator
        return .simulator
        #else

        // Get system memory
        let memoryGB = estimateDeviceMemory()

        // Categorize based on memory
        if memoryGB >= 12.0 {
            cachedDeviceCategory = .highEnd
        } else if memoryGB >= 6.0 {
            cachedDeviceCategory = .midRange
        } else {
            cachedDeviceCategory = .lowEnd
        }

        return cachedDeviceCategory!
        #endif
    }

    private func estimateDeviceMemory() -> Double {
        #if targetEnvironment(simulator)
        return 32.0 // Simulator can handle anything
        #else

        // Use sysctl to get hardware memory size
        var size = UInt64(0)
        var sizeOfSize = MemoryLayout<UInt64>.size

        if sysctlbyname("hw.memsize", &size, &sizeOfSize, nil, 0) == 0 {
            let memoryGB = Double(size) / (1024 * 1024 * 1024)
            return memoryGB
        }

        // Fallback estimation
        return 8.0 // Default to mid-range
        #endif
    }

    public func isModelCompatible(_ model: HuggingFaceModel_Data) -> Bool {
        let deviceCategory = detectDeviceCategory()

        // Extract model size from metadata or tags
        let estimatedSizeGB = estimateModelSize(model)

        // Check if model fits in device memory
        return estimatedSizeGB <= deviceCategory.maxMemoryGB
    }

    private func estimateModelSize(_ model: HuggingFaceModel_Data) -> Double {
        // Extract size from model ID or tags
        let id = model.id.lowercased()

        // Check for size indicators in model name
        if id.contains("3b") || id.contains("3-b") {
            return 6.0  // 3B parameters ≈ 6GB
        } else if id.contains("7b") || id.contains("7-b") {
            return 14.0 // 7B parameters ≈ 14GB
        } else if id.contains("13b") || id.contains("13-b") {
            return 26.0 // 13B parameters ≈ 26GB
        } else if id.contains("30b") || id.contains("30-b") {
            return 60.0 // 30B parameters ≈ 60GB
        } else if id.contains("70b") || id.contains("70-b") {
            return 140.0 // 70B parameters ≈ 140GB
        }

        // Check for quantization indicators
        if id.contains("4bit") || id.contains("q4") {
            // 4-bit quantized models use about 25% of original size
            return 2.0  // Conservative estimate for smaller models
        }

        // Default to small model size for unknown models
        return 2.0
    }
}
