// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Inference/InferenceEngineTypes.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - enum EngineHealth: String, CaseIterable, Sendable, Codable {
//   - struct EngineStatus: Sendable, Codable {
//   - struct DetailedEngineStatus: Sendable, Codable {
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

/// Health status of the inference engine
public enum EngineHealth: String, CaseIterable, Sendable, Codable {
  case healthy = "healthy"
  case degraded = "degraded"
  case unhealthy = "unhealthy"
  case unknown = "unknown"
  
  public var description: String {
    switch self {
    case .healthy:
      return "Engine is operating normally"
    case .degraded:
      return "Engine is operating with reduced performance"
    case .unhealthy:
      return "Engine is experiencing issues"
    case .unknown:
      return "Engine health status is unknown"
    }
  }
}

/// Engine status information
public struct EngineStatus: Sendable, Codable {
  public let isModelLoaded: Bool
  public let mlxAvailable: Bool
  public let modelConfiguration: ModelConfiguration?
  public let memoryUsageBytes: Int
  public let gpuMemoryUsageBytes: Int?
  public let lastError: String?
  
  public init(
    isModelLoaded: Bool = false,
    mlxAvailable: Bool = false,
    modelConfiguration: ModelConfiguration? = nil,
    memoryUsageBytes: Int = 0,
    gpuMemoryUsageBytes: Int? = nil,
    lastError: String? = nil
  ) {
    self.isModelLoaded = isModelLoaded
    self.mlxAvailable = mlxAvailable
    self.modelConfiguration = modelConfiguration
    self.memoryUsageBytes = memoryUsageBytes
    self.gpuMemoryUsageBytes = gpuMemoryUsageBytes
    self.lastError = lastError
  }
}

/// Enhanced engine status with health and performance information
public struct DetailedEngineStatus: Sendable, Codable {
  public let basicStatus: EngineStatus
  public let health: EngineHealth
  public let performanceMetrics: InferenceMetrics
  public let uptime: TimeInterval
  public let lastOperation: String
  
  public init(
    basicStatus: EngineStatus,
    health: EngineHealth,
    performanceMetrics: InferenceMetrics,
    uptime: TimeInterval,
    lastOperation: String
  ) {
    self.basicStatus = basicStatus
    self.health = health
    self.performanceMetrics = performanceMetrics
    self.uptime = uptime
    self.lastOperation = lastOperation
  }
  
  /// Human-readable status summary
  public var statusSummary: String {
    let healthEmoji = health == .healthy ? "✅" : health == .degraded ? "⚠️" : "❌"
    let memoryUsage = ByteCountFormatter.string(
      fromByteCount: Int64(performanceMetrics.memoryUsageBytes), countStyle: .memory)
    let loadTime = String(format: "%.2fs", performanceMetrics.modelLoadTime)
    
    return "\(healthEmoji) \(health.rawValue.capitalized) | Memory: \(memoryUsage) | Load: \(loadTime)"
  }
}
