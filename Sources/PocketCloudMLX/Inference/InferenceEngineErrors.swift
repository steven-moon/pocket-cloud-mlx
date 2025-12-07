// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Inference/InferenceEngineErrors.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - enum InferenceEngineError: LocalizedError, Equatable {
//   - struct InferenceDiagnostics: Codable, Sendable {
//   - enum ErrorRecoveryStrategy {
//   - enum ModelHealthStatus: Equatable {
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
import PocketCloudLogger

/// Error types for the Inference Engine
public enum InferenceEngineError: LocalizedError, Equatable {
  case modelNotFound(String)
  case modelLoadingFailed(String)
  case generationFailed(String)
  case invalidParameters(String)
  case resourceExhausted(String)
  case modelCorrupted(String)
  case unsupportedOperation(String)
  case networkError(String)
  case diskSpaceError(String)
  case memoryError(String)
  case gpuError(String)
  case timeout(String)

  public var errorDescription: String? {
    switch self {
    case .modelNotFound(let details):
      return "Model not found: \(details)"
    case .modelLoadingFailed(let details):
      return "Model loading failed: \(details)"
    case .generationFailed(let details):
      return "Generation failed: \(details)"
    case .invalidParameters(let details):
      return "Invalid parameters: \(details)"
    case .resourceExhausted(let details):
      return "Resource exhausted: \(details)"
    case .modelCorrupted(let details):
      return "Model corrupted: \(details)"
    case .unsupportedOperation(let details):
      return "Unsupported operation: \(details)"
    case .networkError(let details):
      return "Network error: \(details)"
    case .diskSpaceError(let details):
      return "Disk space error: \(details)"
    case .memoryError(let details):
      return "Memory error: \(details)"
    case .gpuError(let details):
      return "GPU error: \(details)"
    case .timeout(let details):
      return "Operation timeout: \(details)"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .modelNotFound:
      return "Check if the model file exists and try downloading it again."
    case .modelLoadingFailed:
      return "Verify the model format is compatible and try a different model."
    case .generationFailed:
      return "Try reducing the generation parameters or use a smaller model."
    case .invalidParameters:
      return "Check the parameter values and ensure they are within valid ranges."
    case .resourceExhausted:
      return "Free up system resources or use a smaller model."
    case .modelCorrupted:
      return "Download the model again as it may be corrupted."
    case .unsupportedOperation:
      return "Check the model capabilities and try a different operation."
    case .networkError:
      return "Check your internet connection and try again."
    case .diskSpaceError:
      return "Free up disk space and try again."
    case .memoryError:
      return "Close other applications or use a smaller model."
    case .gpuError:
      return "Check GPU compatibility or try CPU mode."
    case .timeout:
      return "Try again with a shorter timeout or simpler operation."
    }
  }

  public var isRecoverable: Bool {
    switch self {
    case .modelNotFound, .networkError, .diskSpaceError, .timeout:
      return true
    case .modelLoadingFailed, .generationFailed, .resourceExhausted,
         .modelCorrupted, .invalidParameters, .memoryError, .gpuError:
      return false
    case .unsupportedOperation:
      return false // Usually requires different model/capabilities
    }
  }

  public static func == (lhs: InferenceEngineError, rhs: InferenceEngineError) -> Bool {
    switch (lhs, rhs) {
    case (.modelNotFound(let lhsMsg), .modelNotFound(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.modelLoadingFailed(let lhsMsg), .modelLoadingFailed(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.generationFailed(let lhsMsg), .generationFailed(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.invalidParameters(let lhsMsg), .invalidParameters(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.resourceExhausted(let lhsMsg), .resourceExhausted(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.modelCorrupted(let lhsMsg), .modelCorrupted(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.unsupportedOperation(let lhsMsg), .unsupportedOperation(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.networkError(let lhsMsg), .networkError(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.diskSpaceError(let lhsMsg), .diskSpaceError(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.memoryError(let lhsMsg), .memoryError(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.gpuError(let lhsMsg), .gpuError(let rhsMsg)):
      return lhsMsg == rhsMsg
    case (.timeout(let lhsMsg), .timeout(let rhsMsg)):
      return lhsMsg == rhsMsg
    default:
      return false
    }
  }
}

/// Diagnostics information for debugging inference issues
public struct InferenceDiagnostics: Codable, Sendable {
  public let timestamp: Date
  public let modelInfo: ModelInfo
  public let systemInfo: SystemInfo
  public let errorHistory: [ErrorEntry]
  public let performanceMetrics: PerformanceInfo

  public struct ModelInfo: Codable, Sendable {
    public let name: String
    public let hubId: String
    public let parameters: String?
    public let quantization: String?
    public let architecture: String?
    public let fileSize: Int64?
    public let lastModified: Date?
  }

  public struct SystemInfo: Codable, Sendable {
    public let osVersion: String
    public let cpuInfo: String
    public let memorySize: Int64
    public let gpuInfo: String?
    public let mlxVersion: String?
  }

  public struct ErrorEntry: Codable, Sendable {
    public let timestamp: Date
    public let error: String
    public let context: [String: String]
  }

  public struct PerformanceInfo: Codable, Sendable {
    public let averageResponseTime: TimeInterval
    public let peakMemoryUsage: Int64
    public let cacheHitRate: Double
    public let totalRequests: Int
  }

  public init(
    timestamp: Date = Date(),
    modelInfo: ModelInfo,
    systemInfo: SystemInfo,
    errorHistory: [ErrorEntry] = [],
    performanceMetrics: PerformanceInfo
  ) {
    self.timestamp = timestamp
    self.modelInfo = modelInfo
    self.systemInfo = systemInfo
    self.errorHistory = errorHistory
    self.performanceMetrics = performanceMetrics
  }
}

/// Error recovery strategies
public enum ErrorRecoveryStrategy {
  case retry(Int, TimeInterval)  // retry count, delay between retries
  case fallback(String)          // fallback model/operation
  case degrade(String)          // degraded mode description
  case abort(String)            // abort with reason

  public var description: String {
    switch self {
    case .retry(let count, let delay):
      return "Retry \(count) times with \(delay)s delay"
    case .fallback(let fallback):
      return "Fallback to: \(fallback)"
    case .degrade(let description):
      return "Degrade mode: \(description)"
    case .abort(let reason):
      return "Abort: \(reason)"
    }
  }
}

/// Model health checker
public final class ModelHealthChecker: @unchecked Sendable {
  private let logger = Logger(label: "ModelHealthChecker")

  public init() {}

  /// Check model health and return diagnostics
  public func checkModelHealth(modelPath: URL) async throws -> ModelHealthStatus {
    logger.info("🔍 Checking model health for: \(modelPath.lastPathComponent)")

    var issues: [String] = []

    // Check file existence
    guard FileManager.default.fileExists(atPath: modelPath.path) else {
      throw InferenceEngineError.modelNotFound("Model file does not exist: \(modelPath.path)")
    }

    // Check file size
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
      let fileSize = attributes[.size] as? Int64 ?? 0

      if fileSize == 0 {
        issues.append("Model file is empty (0 bytes)")
      } else if fileSize < 1024 * 1024 { // Less than 1MB
        issues.append("Model file is unusually small (\(fileSize) bytes)")
      }

      logger.info("📏 Model file size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
    } catch {
      issues.append("Cannot read model file attributes: \(error.localizedDescription)")
    }

    // Check file permissions
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
      if let permissions = attributes[.posixPermissions] as? Int {
        if permissions & 0o400 == 0 { // No read permission
          issues.append("Model file is not readable")
        }
      }
    } catch {
      issues.append("Cannot check file permissions: \(error.localizedDescription)")
    }

    // Try to read first few bytes to check if file is accessible
    do {
      let handle = try FileHandle(forReadingFrom: modelPath)
      let data = handle.readData(ofLength: 1024)
      try handle.close()

      if data.isEmpty {
        issues.append("Cannot read model file content")
      } else {
        logger.info("✅ Model file is readable and contains \(data.count) bytes of header data")
      }
    } catch {
      issues.append("Error reading model file: \(error.localizedDescription)")
    }

    let status: ModelHealthStatus = issues.isEmpty ? .healthy : .issues(issues)
    logger.info("🏥 Model health check result: \(status.description)")

    return status
  }

  /// Get recommended recovery strategy for an error
  public func getRecoveryStrategy(for error: InferenceEngineError) -> ErrorRecoveryStrategy {
    switch error {
    case .modelNotFound:
      return .retry(3, 1.0)
    case .networkError:
      return .retry(5, 2.0)
    case .modelCorrupted:
      return .fallback("Use a different model version")
    case .memoryError:
      return .degrade("Reduce batch size or use smaller model")
    case .gpuError:
      return .degrade("Switch to CPU mode")
    case .timeout:
      return .retry(2, 5.0)
    case .diskSpaceError:
      return .abort("Insufficient disk space")
    case .generationFailed, .modelLoadingFailed, .resourceExhausted, .unsupportedOperation, .invalidParameters:
      return .abort("Fatal error requiring manual intervention")
    }
  }
}

/// Model health status
public enum ModelHealthStatus: Equatable {
  case healthy
  case issues([String])

  public var description: String {
    switch self {
    case .healthy:
      return "Model is healthy"
    case .issues(let issues):
      return "Model has \(issues.count) issue(s): \(issues.joined(separator: "; "))"
    }
  }

  public var isHealthy: Bool {
    switch self {
    case .healthy: return true
    case .issues: return false
    }
  }
}
