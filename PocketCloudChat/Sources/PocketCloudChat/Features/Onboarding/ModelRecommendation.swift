// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/ModelRecommendation.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModelRecommendation: Identifiable, Codable {
//   - enum DeviceCategory: String, CaseIterable, Codable {
//   - class DeviceAnalyzer {
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
import SwiftUI
import PocketCloudMLX
import Foundation
import PocketCloudUI

#if canImport(MLXLLM)
import MLXLLM
#endif
#if os(iOS)
import UIKit
#endif

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Model Recommendation Types

/// Device-specific model recommendation
struct ModelRecommendation: Identifiable, Codable {
    let id: String
    let name: String
    let hubId: String
    let description: String
    let parameters: String
    let quantization: String
    let estimatedSizeGB: Double
    let deviceCategory: DeviceCategory
    let performanceRating: Int // 1-5 stars
    let isRecommended: Bool
    let estimatedTokensPerSecond: Double
    let memoryRequirementGB: Double
    
    var displayName: String {
        return name.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
    
    var sizeDescription: String {
        return String(format: "%.1f GB", estimatedSizeGB)
    }
    
    var parametersDescription: String {
        return parameters.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// Device categories for model recommendations
enum DeviceCategory: String, CaseIterable, Codable {
    case highEnd = "high_end"
    case midRange = "mid_range"
    case lowEnd = "low_end"
    case simulator = "simulator"

    var displayName: String {
        switch self {
        case .highEnd: return "High-End Device"
        case .midRange: return "Mid-Range Device"
        case .lowEnd: return "Low-End Device"
        case .simulator: return "Simulator"
        }
    }

    var description: String {
        switch self {
        case .highEnd: return "Latest devices with 8GB+ RAM"
        case .midRange: return "Modern devices with 4-8GB RAM"
        case .lowEnd: return "Older devices with <4GB RAM"
        case .simulator: return "iOS Simulator environment"
        }
    }

    /// Recommended model configurations for this device category (Text Generation models only)
    /// Only returns models that are actually supported by the MLX library
    var recommendedModels: [ModelRecommendation] {
        let baseModels = baseRecommendedModels()
        #if canImport(MLXLLM)
        let mlxRegistryModels = MLXLLM.LLMRegistry.shared.models
        let mlxRegistryIds = Set(mlxRegistryModels.map { String(describing: $0.id) })

        let filteredModels = baseModels.filter { model in
            let isCompatible = mlxRegistryIds.contains { mlxId in
                let hubId = model.hubId
                let mlxIdStr = String(describing: mlxId)
                return hubId.contains(mlxIdStr) || mlxIdStr.contains(hubId) ||
                       hubId.replacingOccurrences(of: "mlx-community/", with: "").contains(mlxIdStr) ||
                       mlxIdStr.contains(hubId.replacingOccurrences(of: "mlx-community/", with: ""))
            }
            return isCompatible
        }

        print("🎯 Device category \(self.displayName): \(baseModels.count) base models, \(filteredModels.count) MLX-compatible")
        return filteredModels.isEmpty ? baseModels : filteredModels // Fallback if all filtered out
        #else
        return baseModels
        #endif
    }

    private func baseRecommendedModels() -> [ModelRecommendation] {
        switch self {
        case .highEnd:
            return [
                ModelRecommendation(
                    id: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                    name: "Qwen2.5-7B-Instruct",
                    hubId: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                    description: "High-quality 7B parameter model with excellent reasoning capabilities",
                    parameters: "7B",
                    quantization: "4-bit",
                    estimatedSizeGB: 4.2,
                    deviceCategory: .highEnd,
                    performanceRating: 4,
                    isRecommended: false,
                    estimatedTokensPerSecond: 35.0,
                    memoryRequirementGB: 6.0
                ),
                ModelRecommendation(
                    id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                    name: "Llama-3.2-3B-Instruct",
                    hubId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                    description: "Meta's latest 3B model with good performance and quality",
                    parameters: "3B",
                    quantization: "4-bit",
                    estimatedSizeGB: 1.8,
                    deviceCategory: .highEnd,
                    performanceRating: 3,
                    isRecommended: false,
                    estimatedTokensPerSecond: 45.0,
                    memoryRequirementGB: 3.5
                ),
                // Default recommended model for high-end devices
                ModelRecommendation(
                    id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    name: "Qwen2.5-0.5B-Instruct",
                    hubId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    description: "Fast and efficient 0.5B model, perfect for quick responses and testing",
                    parameters: "0.5B",
                    quantization: "4-bit",
                    estimatedSizeGB: 0.3,
                    deviceCategory: .highEnd,
                    performanceRating: 5,
                    isRecommended: true,
                    estimatedTokensPerSecond: 80.0,
                    memoryRequirementGB: 1.0
                )
            ]
        case .midRange:
            return [
                ModelRecommendation(
                    id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                    name: "Qwen2.5-3B-Instruct",
                    hubId: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                    description: "Excellent 3B model with great balance of quality and performance",
                    parameters: "3B",
                    quantization: "4-bit",
                    estimatedSizeGB: 1.8,
                    deviceCategory: .midRange,
                    performanceRating: 4,
                    isRecommended: false,
                    estimatedTokensPerSecond: 42.0,
                    memoryRequirementGB: 3.2
                ),
                ModelRecommendation(
                    id: "mlx-community/Phi-3.5-mini-instruct-4bit",
                    name: "Phi-3.5-mini-instruct",
                    hubId: "mlx-community/Phi-3.5-mini-instruct-4bit",
                    description: "Microsoft's efficient 3.8B model with strong reasoning",
                    parameters: "3.8B",
                    quantization: "4-bit",
                    estimatedSizeGB: 2.2,
                    deviceCategory: .midRange,
                    performanceRating: 3,
                    isRecommended: false,
                    estimatedTokensPerSecond: 38.0,
                    memoryRequirementGB: 3.8
                ),
                // Default recommended model for mid-range devices
                ModelRecommendation(
                    id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    name: "Qwen2.5-0.5B-Instruct",
                    hubId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    description: "Fast and efficient 0.5B model, perfect for quick responses and testing",
                    parameters: "0.5B",
                    quantization: "4-bit",
                    estimatedSizeGB: 0.3,
                    deviceCategory: .midRange,
                    performanceRating: 5,
                    isRecommended: true,
                    estimatedTokensPerSecond: 80.0,
                    memoryRequirementGB: 1.0
                )
            ]
        case .lowEnd:
            return [
                ModelRecommendation(
                    id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                    name: "Qwen2.5-1.5B-Instruct",
                    hubId: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                    description: "Lightweight 1.5B model perfect for older devices",
                    parameters: "1.5B",
                    quantization: "4-bit",
                    estimatedSizeGB: 0.9,
                    deviceCategory: .lowEnd,
                    performanceRating: 4,
                    isRecommended: false,
                    estimatedTokensPerSecond: 55.0,
                    memoryRequirementGB: 2.0
                ),
                // Default recommended model for low-end devices
                ModelRecommendation(
                    id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    name: "Qwen2.5-0.5B-Instruct",
                    hubId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    description: "Ultra-lightweight 0.5B model, fastest and most compatible",
                    parameters: "0.5B",
                    quantization: "4-bit",
                    estimatedSizeGB: 0.3,
                    deviceCategory: .lowEnd,
                    performanceRating: 5,
                    isRecommended: true,
                    estimatedTokensPerSecond: 80.0,
                    memoryRequirementGB: 1.0
                )
            ]
        case .simulator:
            return [
                // Default recommended model for simulator
                ModelRecommendation(
                    id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    name: "Qwen2.5-0.5B-Instruct",
                    hubId: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                    description: "Ultra-lightweight model perfect for simulator testing",
                    parameters: "0.5B",
                    quantization: "4-bit",
                    estimatedSizeGB: 0.3,
                    deviceCategory: .simulator,
                    performanceRating: 5,
                    isRecommended: true,
                    estimatedTokensPerSecond: 80.0,
                    memoryRequirementGB: 1.0
                )
            ]
        }
    }
}

// MARK: - Device Analyzer

/// Analyzes device capabilities for model recommendations
class DeviceAnalyzer {

    /// Enhanced device capability analysis
    struct DeviceCapabilities {
        let memoryGB: Double
        let cpuCores: Int
        let gpuCores: Int
        let modelIdentifier: String
        let isAppleSilicon: Bool
        let performanceScore: Double
    }

    func detectDeviceCategory() -> DeviceCategory {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        let capabilities = analyzeDeviceCapabilities()

        // Calculate performance score based on multiple factors
        let memoryScore = min(capabilities.memoryGB / 8.0, 1.0) * 40
        let cpuScore = min(Double(capabilities.cpuCores) / 8.0, 1.0) * 30
        let gpuScore = min(Double(capabilities.gpuCores) / 512.0, 1.0) * 30

        let totalScore = memoryScore + cpuScore + gpuScore

        if totalScore >= 70 {
            return .highEnd
        } else if totalScore >= 45 {
            return .midRange
        } else {
            return .lowEnd
        }
        #endif
    }

    func analyzeDeviceCapabilities() -> DeviceCapabilities {
        #if os(iOS)
        let memoryGB = estimateDeviceMemory()
        let (cpuCores, gpuCores) = getCPUAndGPUCores()
        let modelIdentifier = getDeviceModelIdentifier()
        let isAppleSilicon = isAppleSiliconDevice()

        // Calculate performance score
        let performanceScore = calculateiOSPerformanceScore(memoryGB: memoryGB, cpuCores: cpuCores, gpuCores: gpuCores, modelIdentifier: modelIdentifier)

        return DeviceCapabilities(
            memoryGB: memoryGB,
            cpuCores: cpuCores,
            gpuCores: gpuCores,
            modelIdentifier: modelIdentifier,
            isAppleSilicon: isAppleSilicon,
            performanceScore: performanceScore
        )
        #elseif os(macOS)
        let memoryGB = estimateDeviceMemory()
        let (cpuCores, gpuCores) = getCPUAndGPUCores()
        let modelIdentifier = getMacModelIdentifier()
        let isAppleSilicon = isAppleSiliconMac()

        // Calculate performance score
        let performanceScore = calculateMacPerformanceScore(memoryGB: memoryGB, cpuCores: cpuCores, gpuCores: gpuCores, isAppleSilicon: isAppleSilicon)

        return DeviceCapabilities(
            memoryGB: memoryGB,
            cpuCores: cpuCores,
            gpuCores: gpuCores,
            modelIdentifier: modelIdentifier,
            isAppleSilicon: isAppleSilicon,
            performanceScore: performanceScore
        )
        #else
        return DeviceCapabilities(
            memoryGB: 8.0,
            cpuCores: 4,
            gpuCores: 256,
            modelIdentifier: "unknown",
            isAppleSilicon: false,
            performanceScore: 50.0
        )
        #endif
    }

    private func calculateiOSPerformanceScore(memoryGB: Double, cpuCores: Int, gpuCores: Int, modelIdentifier: String) -> Double {
        // iOS performance scoring based on known device capabilities
        var score = 0.0

        // Memory scoring (0-40 points)
        if memoryGB >= 8 { score += 40 }
        else if memoryGB >= 6 { score += 35 }
        else if memoryGB >= 4 { score += 25 }
        else if memoryGB >= 3 { score += 15 }
        else { score += 5 }

        // CPU scoring (0-30 points)
        if cpuCores >= 6 { score += 30 }
        else if cpuCores >= 4 { score += 25 }
        else if cpuCores >= 2 { score += 15 }
        else { score += 5 }

        // GPU scoring (0-30 points)
        if gpuCores >= 512 { score += 30 }
        else if gpuCores >= 384 { score += 25 }
        else if gpuCores >= 256 { score += 20 }
        else if gpuCores >= 128 { score += 15 }
        else { score += 5 }

        return score
    }

    private func calculateMacPerformanceScore(memoryGB: Double, cpuCores: Int, gpuCores: Int, isAppleSilicon: Bool) -> Double {
        var score = 0.0

        // Memory scoring (0-40 points)
        if memoryGB >= 32 { score += 40 }
        else if memoryGB >= 16 { score += 35 }
        else if memoryGB >= 8 { score += 30 }
        else if memoryGB >= 4 { score += 20 }
        else { score += 10 }

        // CPU scoring (0-30 points) - Macs have more cores
        if cpuCores >= 12 { score += 30 }
        else if cpuCores >= 8 { score += 25 }
        else if cpuCores >= 6 { score += 20 }
        else if cpuCores >= 4 { score += 15 }
        else { score += 5 }

        // GPU scoring (0-30 points) - Macs have dedicated GPUs
        if gpuCores >= 1024 { score += 30 }
        else if gpuCores >= 768 { score += 25 }
        else if gpuCores >= 512 { score += 20 }
        else if gpuCores >= 256 { score += 15 }
        else { score += 5 }

        // Apple Silicon bonus
        if isAppleSilicon { score += 10 }

        return score
    }
    
    private func estimateDeviceMemory() -> Double {
        #if targetEnvironment(simulator)
        return 16.0 // Assume simulator has plenty of memory
        #else
        // Get total physical memory
        var size = UInt64(0)
        var sizeOfSize = MemoryLayout<UInt64>.size

        if sysctlbyname("hw.memsize", &size, &sizeOfSize, nil, 0) == 0 {
            return Double(size) / (1024 * 1024 * 1024)
        }

        return 4.0 // Fallback
        #endif
    }

    private func getCPUAndGPUCores() -> (cpuCores: Int, gpuCores: Int) {
        #if os(iOS)
        // Get CPU cores
        var cpuCores: Int = 0
        var size = MemoryLayout<Int>.size
        if sysctlbyname("hw.ncpu", &cpuCores, &size, nil, 0) != 0 {
            cpuCores = ProcessInfo.processInfo.processorCount
        }

        // Get GPU cores (approximate based on device)
        let gpuCores = estimateGPUCores()
        return (cpuCores, gpuCores)
        #elseif os(macOS)
        let cpuCores = ProcessInfo.processInfo.processorCount
        let gpuCores = estimateMacGPUCores()
        return (cpuCores, gpuCores)
        #else
        return (4, 256)
        #endif
    }

    private func estimateGPUCores() -> Int {
        #if os(iOS)
        // iOS GPU core estimation based on device model
        let modelIdentifier = getDeviceModelIdentifier()

        // A-series chips
        if modelIdentifier.contains("iPhone15") || modelIdentifier.contains("iPhone14") {
            return 512 // A16/A15 Bionic
        } else if modelIdentifier.contains("iPhone13") || modelIdentifier.contains("iPad14") {
            return 384 // A15 Bionic
        } else if modelIdentifier.contains("iPhone12") || modelIdentifier.contains("iPad13") {
            return 320 // A14 Bionic
        } else if modelIdentifier.contains("iPhone11") || modelIdentifier.contains("iPad12") {
            return 256 // A13 Bionic
        } else if modelIdentifier.contains("iPhone10") || modelIdentifier.contains("iPad11") {
            return 192 // A12 Bionic
        } else {
            return 256 // Default
        }
        #else
        return 256
        #endif
    }

    private func estimateMacGPUCores() -> Int {
        #if os(macOS)
        // Get GPU info
        var gpuCores = 256 // Default

        // Try to get actual GPU core count
        if let gpuInfo = getMacGPUInfo() {
            gpuCores = gpuInfo.coreCount
        }

        return gpuCores
        #else
        return 256
        #endif
    }

    private func getDeviceModelIdentifier() -> String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #else
        return "unknown"
        #endif
    }

    private func getMacModelIdentifier() -> String {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return model.withUnsafeBufferPointer { buffer -> String in
            guard let base = buffer.baseAddress else { return "unknown" }
            return base.withMemoryRebound(to: UInt8.self, capacity: buffer.count) {
                String(decodingCString: $0, as: UTF8.self)
            }
        }
        #else
        return "unknown"
        #endif
    }

    private func isAppleSiliconDevice() -> Bool {
        #if os(iOS)
        let modelIdentifier = getDeviceModelIdentifier()
        return modelIdentifier.hasPrefix("iPhone14") ||
               modelIdentifier.hasPrefix("iPhone15") ||
               modelIdentifier.hasPrefix("iPad14") ||
               modelIdentifier.hasPrefix("iPad15")
        #else
        return false
        #endif
    }

    private func isAppleSiliconMac() -> Bool {
        #if os(macOS)
        #if arch(arm64)
        return !isRunningUnderRosetta()
        #else
        var arm64Capability: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.optional.arm64", &arm64Capability, &size, nil, 0) == 0,
           arm64Capability == 1 {
            return !isRunningUnderRosetta()
        }
        return false
        #endif
        #else
        return false
        #endif
    }

    private func isRunningUnderRosetta() -> Bool {
        #if os(macOS)
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0) == 0 {
            return translated == 1
        }
        return false
        #else
        return false
        #endif
    }

    /// Check if device supports MLX framework
    /// MLX requires Apple Silicon (A14+ on iOS/iPadOS, M1+ on macOS)
    func isMLXCompatible() -> Bool {
        #if targetEnvironment(simulator)
        // Simulator is not compatible with MLX
        return false
        #elseif os(iOS)
        let modelIdentifier = getDeviceModelIdentifier()

        // iPhone models with A14 or later (iPhone 12 and newer)
        // Model identifiers: iPhone12,x = iPhone 11, iPhone13,x = iPhone 12, etc.
        if modelIdentifier.hasPrefix("iPhone") {
            if let numberRange = modelIdentifier.range(of: "\\d+", options: .regularExpression),
               let majorVersion = Int(modelIdentifier[numberRange]) {
                // iPhone13,x and later have A14+ (iPhone 12 and newer)
                return majorVersion >= 13
            }
        }

        // iPad models with M1, M2, M3, M4 or A14+ chips
        // iPad Pro with M1: iPad13,x (2021)
        // iPad Air with M1: iPad13,16+ (2022)
        // iPad mini with A15: iPad14,1-2 (2021)
        if modelIdentifier.hasPrefix("iPad") {
            if let numberRange = modelIdentifier.range(of: "\\d+", options: .regularExpression),
               let majorVersion = Int(modelIdentifier[numberRange]) {
                // iPad13,x and later have M1 or A14+ chips
                return majorVersion >= 13
            }
        }

        // Unknown device - assume not compatible for safety
        return false
        #elseif os(macOS)
        // Check for Apple Silicon on macOS
        return isAppleSiliconMac()
        #else
        return false
        #endif
    }

    /// Get user-friendly device information for compatibility messages
    func getDeviceInfo() -> (model: String, chipInfo: String) {
        #if os(iOS)
        let modelIdentifier = getDeviceModelIdentifier()
        let deviceName = getDeviceNameFromIdentifier(modelIdentifier)

        // Try to determine chip
        var chipInfo = "Unknown Chip"
        if modelIdentifier.hasPrefix("iPhone") {
            if let numberRange = modelIdentifier.range(of: "\\d+", options: .regularExpression),
               let majorVersion = Int(modelIdentifier[numberRange]) {
                switch majorVersion {
                case 15...: chipInfo = "A17 Pro or later"
                case 14...: chipInfo = "A15/A16 Bionic"
                case 13...: chipInfo = "A14 Bionic"
                case 12...: chipInfo = "A13 Bionic"
                case 11...: chipInfo = "A12 Bionic"
                default: chipInfo = "A11 or earlier"
                }
            }
        } else if modelIdentifier.hasPrefix("iPad") {
            if let numberRange = modelIdentifier.range(of: "\\d+", options: .regularExpression),
               let majorVersion = Int(modelIdentifier[numberRange]) {
                switch majorVersion {
                case 14...: chipInfo = "M2 or A15 Bionic"
                case 13...: chipInfo = "M1 or M2"
                default: chipInfo = "A12X or earlier"
                }
            }
        }

        return (deviceName, chipInfo)
        #elseif os(macOS)
        let modelIdentifier = getMacModelIdentifier()
        var chipInfo = "Intel"
        if modelIdentifier.contains("M4") {
            chipInfo = "M4"
        } else if modelIdentifier.contains("M3") {
            chipInfo = "M3"
        } else if modelIdentifier.contains("M2") {
            chipInfo = "M2"
        } else if modelIdentifier.contains("M1") {
            chipInfo = "M1"
        }
        return (modelIdentifier, chipInfo)
        #else
        return ("Unknown Device", "Unknown Chip")
        #endif
    }

    private func getDeviceNameFromIdentifier(_ identifier: String) -> String {
        // This is a simplified mapping - you could expand this with a full device database
        if identifier.hasPrefix("iPhone") {
            return "iPhone"
        } else if identifier.hasPrefix("iPad") {
            return "iPad"
        }
        return identifier
    }

    private func getMacGPUInfo() -> (coreCount: Int, name: String)? {
        #if os(macOS)
        // This is a simplified approach - in a real app you'd use IOKit
        // For now, return reasonable defaults based on common configurations
        let cpuCores = ProcessInfo.processInfo.processorCount

        if cpuCores >= 12 { // High-end Macs
            return (1024, "High-end GPU")
        } else if cpuCores >= 8 { // Mid-range Macs
            return (768, "Mid-range GPU")
        } else if cpuCores >= 6 { // Lower mid-range
            return (512, "Standard GPU")
        } else { // Base configurations
            return (256, "Basic GPU")
        }
        #else
        return nil
        #endif
    }
}

// MARK: - Model Recommendation Card

/// Card component for displaying model recommendations
struct ModelRecommendationCard: View {
    let recommendation: ModelRecommendation
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(recommendation.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(styleManager.tokens.onBackground)
                        
                        Spacer()
                        
                        if recommendation.isRecommended {
                            recommendedBadge
                        }
                    }
                    
                    Text(recommendation.description)
                        .font(.subheadline)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                        .multilineTextAlignment(.leading)
                }
                
                // Specs
                VStack(alignment: .leading, spacing: 8) {
                    specRow(title: "Parameters", value: recommendation.parametersDescription)
                    specRow(title: "Size", value: recommendation.sizeDescription)
                    specRow(title: "Quantization", value: recommendation.quantization)
                    specRow(title: "Speed", value: "\(Int(recommendation.estimatedTokensPerSecond)) tokens/sec")
                }
                
                // Performance rating
                HStack {
                    Text("Performance")
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= recommendation.performanceRating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= recommendation.performanceRating ? styleManager.tokens.accent : styleManager.tokens.secondaryForeground.opacity(0.3))
                        }
                    }
                }
            }
            .padding(16)
            .background(isSelected ? styleManager.tokens.accent.opacity(0.1) : styleManager.tokens.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? styleManager.tokens.accent : styleManager.tokens.secondaryForeground.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var recommendedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("Recommended")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(styleManager.tokens.accent)
        .cornerRadius(12)
    }
    
    private func specRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(styleManager.tokens.secondaryForeground)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(styleManager.tokens.onBackground)
        }
    }
} 
