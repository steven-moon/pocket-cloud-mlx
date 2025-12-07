// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/OptimizedDownloader.swift
// Purpose       : Refactored composition layer for model downloading
//
// Key Types in this file:
//   - actor OptimizedDownloader
//   - actor RobustDownloadManager
//   - struct ModelInfo
//   - enum OptimizedDownloadError
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Refactoring Guide: pocket-cloud-mlx/_docs/optimized-downloader-refactoring-implementation.md
//
// Related Files (Download/ modules):
//   - ModelDownloadProtocols.swift
//   - NetworkFailureManager.swift
//   - FileIntegrityVerifier.swift
//   - HuggingFaceDirectoryManager.swift
//   - ModelMetadataManager.swift
//   - DownloadProgressNotifier.swift
//   - ModelFileCanonicalizer.swift
//   - ModelVerificationService.swift
//   - ModelDownloadCoordinator.swift
//
// Note for AI Agents:
//   - This file has been refactored from 2500+ lines into smaller modules
//   - It now acts as a composition layer that delegates to specialized services
//   - All implementation details are in the Download/ directory modules
//
// == End LLM Context Header ==
import Foundation
import PocketCloudLogger
@preconcurrency import Hub

/// Optimized model downloader using the official Hub library for reliable downloads.
/// This is compatible with the MLX Chat Example pattern and ensures proper file structure.
///
/// This actor has been refactored into smaller, focused modules in the Download/ directory.
/// It now acts as a composition layer that delegates to specialized services.
public actor OptimizedDownloader {
  private let logger = Logger(label: "OptimizedDownloader")
  private let fileManager = FileManagerService.shared
  private let downloadBase: URL
  
  // MARK: - Composed Services
  
  private let networkFailureManager: NetworkFailureManager
  private let fileVerifier: FileIntegrityVerifier
  private let hfDirectoryManager: HuggingFaceDirectoryManager
  private let metadataManager: ModelMetadataManager
  private let downloadCoordinator: ModelDownloadCoordinator
  private let verificationService: ModelVerificationService
  private let fileCanonicalizer: ModelFileCanonicalizer
  private let progressNotifier: DownloadProgressNotifier
  
  // MARK: - Initialization
  
  public init() {
    // Setup download base
    let homeDirectory = FileManager.default.mlxUserHomeDirectory
    self.downloadBase = homeDirectory
      .appendingPathComponent(".cache")
      .appendingPathComponent("huggingface")
      .appendingPathComponent("hub")
    
    // Initialize services
    self.networkFailureManager = NetworkFailureManager()
    self.fileVerifier = FileIntegrityVerifier()
    self.hfDirectoryManager = HuggingFaceDirectoryManager(logger: logger)
    self.metadataManager = ModelMetadataManager(downloadBase: downloadBase)
    self.fileCanonicalizer = ModelFileCanonicalizer()
    self.progressNotifier = DownloadProgressNotifier()
    
    let api = HuggingFaceAPI.shared
    self.downloadCoordinator = ModelDownloadCoordinator(
      fileVerifier: fileVerifier,
      metadataManager: metadataManager,
      fileCanonicalizer: fileCanonicalizer,
      hfDirectoryManager: hfDirectoryManager,
      networkFailureManager: networkFailureManager,
      progressNotifier: progressNotifier,
      huggingFaceAPI: api
    )
    
    self.verificationService = ModelVerificationService(
      fileVerifier: fileVerifier,
      metadataManager: metadataManager,
      progressNotifier: progressNotifier
    )
  }
  
  // MARK: - Public API
  
  /// Download a model with progress tracking.
  public func downloadModel(
    _ config: ModelConfiguration,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> URL {
    logger.info("📥 Starting download for model: \(config.hubId)", context: Logger.Context([
      "model": config.hubId
    ]))
    
    // Check network readiness
    let isReady = await networkFailureManager.isNetworkReady(for: config.hubId, context: "download")
    if !isReady {
      if let waitSeconds = await networkFailureManager.pendingBackoff(for: config.hubId) {
        logger.warning("⏳ Model \(config.hubId) is in network backoff. Next retry in \(waitSeconds)s", context: Logger.Context([
          "model": config.hubId,
          "wait_seconds": "\(waitSeconds)"
        ]))
        throw OptimizedDownloadError.networkUnavailable(
          "Network failures detected. Retrying in \(waitSeconds) seconds."
        )
      }
    }
    
    let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
    let modelDirectory = modelsDirectory.appendingPathComponent(config.hubId)
    let tempDirectory = try fileManager.getTemporaryDirectory()
      .appendingPathComponent(UUID().uuidString)
    
    do {
      // Delegate to coordinator
      let result = try await downloadCoordinator.downloadModel(
        config,
        to: modelDirectory,
        tempDirectory: tempDirectory,
        progress: progress
      )
      
      // Record success
      await networkFailureManager.recordSuccess(for: config.hubId)
      
      logger.info("✅ Successfully downloaded model: \(config.hubId)", context: Logger.Context([
        "model": config.hubId,
        "path": result.path
      ]))
      
      return result
      
    } catch {
      // Record failure if network-related
      if isNetworkError(error) {
        await networkFailureManager.recordFailure(for: config.hubId, context: "download", error: error)
      }
      
      logger.error("❌ Failed to download model: \(config.hubId)", context: Logger.Context([
        "model": config.hubId,
        "error": error.localizedDescription
      ]))
      
      throw error
    }
  }
  
  /// Download a model with resume capability.
  public func downloadModelWithResume(
    _ config: ModelConfiguration,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> URL {
    logger.info("📥 Starting resumable download for model: \(config.hubId)", context: Logger.Context([
      "model": config.hubId
    ]))
    
    let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
    let modelDirectory = modelsDirectory.appendingPathComponent(config.hubId)
    let tempDirectory = try fileManager.getTemporaryDirectory()
      .appendingPathComponent(UUID().uuidString)
    
    do {
      let result = try await downloadCoordinator.downloadModelWithResume(
        config,
        to: modelDirectory,
        tempDirectory: tempDirectory,
        progress: progress
      )
      
      await networkFailureManager.recordSuccess(for: config.hubId)
      
      logger.info("✅ Successfully downloaded model with resume: \(config.hubId)", context: Logger.Context([
        "model": config.hubId,
        "path": result.path
      ]))
      
      return result
      
    } catch {
      if isNetworkError(error) {
        await networkFailureManager.recordFailure(for: config.hubId, context: "resumable download", error: error)
      }
      
      logger.error("❌ Failed to download model with resume: \(config.hubId)", context: Logger.Context([
        "model": config.hubId,
        "error": error.localizedDescription
      ]))
      
      throw error
    }
  }
  
  /// Get information about a model from HuggingFace.
  public func getModelInfo(modelId: String) async throws -> ModelInfo {
    logger.debug("ℹ️ Fetching model info for: \(modelId)", context: Logger.Context([
      "model": modelId
    ]))
    
    let api = HuggingFaceAPI.shared
    let repoInfo = try await api.getModelInfo(modelId: modelId)
    
    let totalFiles = repoInfo.siblings?.count ?? 0
    let modelFiles = repoInfo.siblings?.filter { $0.rfilename.hasSuffix(".safetensors") || $0.rfilename.hasSuffix(".gguf") }.count ?? 0
    let configFiles = repoInfo.siblings?.filter { $0.rfilename.hasSuffix(".json") }.count ?? 0
    let totalSize = repoInfo.siblings?.reduce(0) { $0 + ($1.size ?? 0) } ?? 0
    let estimatedSizeGB = Double(totalSize) / (1024 * 1024 * 1024)
    let filenames = repoInfo.siblings?.map { $0.rfilename } ?? []
    
    return ModelInfo(
      modelId: modelId,
      totalFiles: totalFiles,
      modelFiles: modelFiles,
      configFiles: configFiles,
      estimatedSizeGB: estimatedSizeGB,
      filenames: filenames
    )
  }
  
  /// Check and repair a model if needed.
  public func checkAndRepairModel(
    _ config: ModelConfiguration,
    progress: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> ModelVerificationStatus {
    logger.info("🔍 Checking and repairing model: \(config.hubId)", context: Logger.Context([
      "model": config.hubId
    ]))
    
    let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
    let modelDirectory = modelsDirectory.appendingPathComponent(config.hubId)
    
    let status = try await verificationService.checkAndRepairModel(
      config,
      at: modelDirectory,
      targetDir: modelDirectory,
      progress: progress
    )
    
    logger.info("🔍 Model health check completed: \(config.hubId) -> \(status)", context: Logger.Context([
      "model": config.hubId,
      "status": "\(status)"
    ]))
    
    return status
  }
  
  /// Test automatic redownload functionality.
  public func testAutomaticRedownload(
    _ config: ModelConfiguration,
    progress: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> Bool {
    logger.info("🧪 Testing automatic redownload for: \(config.hubId)", context: Logger.Context([
      "model": config.hubId
    ]))
    
    progress("Starting test of automatic redownload...")
    
    let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
    let modelDirectory = modelsDirectory.appendingPathComponent(config.hubId)
    
    // Simulate corruption by removing a critical file
    let configPath = modelDirectory.appendingPathComponent("config.json")
    if FileManager.default.fileExists(atPath: configPath.path) {
      try FileManager.default.removeItem(at: configPath)
      progress("Simulated corruption by removing config.json")
    }
    
    // Attempt repair
    let status = try await verificationService.checkAndRepairModel(
      config,
      at: modelDirectory,
      targetDir: modelDirectory,
      progress: progress
    )
    
    let success = (status == .healthy || status == .repaired)
    progress(success ? "Test passed: model repaired successfully" : "Test failed: model could not be repaired")
    
    return success
  }
  
  /// Force redownload and repair a model.
  public func forceRedownloadAndRepair(
    _ config: ModelConfiguration,
    progress: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> Bool {
    logger.info("🔄 Force redownloading model: \(config.hubId)", context: Logger.Context([
      "model": config.hubId
    ]))
    
    progress("Starting forced redownload...")
    
    let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
    let modelDirectory = modelsDirectory.appendingPathComponent(config.hubId)
    
    // Remove existing model
    if FileManager.default.fileExists(atPath: modelDirectory.path) {
      try FileManager.default.removeItem(at: modelDirectory)
      progress("Removed existing model files")
    }
    
    // Download fresh copy
    _ = try await downloadModel(config) { downloadProgress in
      progress("Downloading: \(Int(downloadProgress * 100))%")
    }
    
    progress("Forced redownload completed successfully")
    return true
  }
  
  /// Verify and repair a model (simple version).
  public func verifyAndRepairModel(_ config: ModelConfiguration) async throws -> Bool {
    logger.info("🔧 Verifying and repairing model: \(config.hubId)", context: Logger.Context([
      "model": config.hubId
    ]))
    
    let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
    let modelDirectory = modelsDirectory.appendingPathComponent(config.hubId)
    
    let status = try await verificationService.checkAndRepairModel(
      config,
      at: modelDirectory,
      targetDir: modelDirectory
    ) { _ in }
    
    return status == .healthy || status == .repaired
  }
  
  /// Get all downloaded models.
  public func getDownloadedModels() async throws -> [ModelConfiguration] {
    logger.info("📋 Scanning for downloaded models", context: Logger.Context([:]))
    
    let models = try await downloadCoordinator.getDownloadedModels()
    
    logger.info("📋 Found \(models.count) downloaded models", context: Logger.Context([
      "count": "\(models.count)",
      "model_ids": models.map { $0.hubId }.joined(separator: ", ")
    ]))
    
    return models
  }
  
  /// Clean up incomplete downloads.
  public func cleanupIncompleteDownloads() async throws {
    logger.info("🧹 Cleaning up incomplete downloads", context: Logger.Context([:]))
    
    let tempDirectory = try fileManager.getTemporaryDirectory()
    
    guard FileManager.default.fileExists(atPath: tempDirectory.path) else {
      logger.debug("No temporary directory to clean up")
      return
    }
    
    do {
      let contents = try FileManager.default.contentsOfDirectory(
        at: tempDirectory,
        includingPropertiesForKeys: [.isDirectoryKey]
      )
      
      var cleanedCount = 0
      for url in contents {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDirectory {
          try FileManager.default.removeItem(at: url)
          cleanedCount += 1
        }
      }
      
      logger.info("🧹 Cleaned up \(cleanedCount) incomplete downloads", context: Logger.Context([
        "count": "\(cleanedCount)"
      ]))
      
    } catch {
      logger.error("❌ Failed to clean up incomplete downloads", context: Logger.Context([
        "error": error.localizedDescription
      ]))
      throw error
    }
  }
  
  // MARK: - Private Helpers
  
  private func isNetworkError(_ error: Error) -> Bool {
    if let optimizedError = error as? OptimizedDownloadError {
      if case .networkUnavailable = optimizedError { return true }
    }
    
    if error is URLError { return true }
    
    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain
  }
}

// MARK: - RobustDownloadManager

/// Robust download manager with automatic retry and corruption detection
public actor RobustDownloadManager {
  private let logger = Logger(label: "RobustDownloadManager")
  private let maxRetries = 3
  private let retryDelay: TimeInterval = 2.0
  
  /// Public initializer for cross-module access
  public init() {}
  
  /// Download with automatic retry and corruption handling
  public func downloadWithRetry(
    _ config: ModelConfiguration,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> URL {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
      do {
        logger.info("🚀 Download attempt \(attempt)/\(maxRetries) for model \(config.hubId)")
        
        let downloader = OptimizedDownloader()
        let result = try await downloader.downloadModel(config, progress: progress)
        
        logger.info("✅ Download completed successfully for model \(config.hubId)")
        return result
        
      } catch {
        lastError = error
        logger.error("❌ Download attempt \(attempt) failed for model \(config.hubId): \(error)")
        
        if attempt < maxRetries {
          logger.info("⏳ Waiting \(retryDelay) seconds before retry...")
          try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
        }
      }
    }
    
    logger.error("💥 All download attempts failed for model \(config.hubId)")
    throw lastError ?? OptimizedDownloadError.downloadFailed("Download failed after \(maxRetries) attempts")
  }
  
  /// Clean up all corrupted downloads across the system
  func cleanupAllCorruptedDownloads() async {
    logger.info("🧹 Starting system-wide cleanup of corrupted downloads")
    
    // Clean up PocketCloudMLX models directory
    let mlxModelsPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent("PocketCloudMLX/Models")
    
    if let mlxModelsPath = mlxModelsPath {
      await cleanupDirectory(mlxModelsPath, name: "PocketCloudMLX Models")
    }
    
    // Clean up HuggingFace cache
    let hfCachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent("huggingface")
    
    if let hfCachePath = hfCachePath {
      await cleanupDirectory(hfCachePath, name: "HuggingFace Cache")
    }
    
    logger.info("🧹 System-wide cleanup completed")
  }
  
  private func cleanupDirectory(_ directory: URL, name: String) async {
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    
    do {
      let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
      var cleanedCount = 0
      
      for fileURL in contents {
        let fileName = fileURL.lastPathComponent

        // Get file attributes for this specific file
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)

        // Remove suspicious files, but be more selective with .tmp files
        if fileName.hasSuffix(".part") || fileName.hasSuffix(".download") {
          try? FileManager.default.removeItem(at: fileURL)
          cleanedCount += 1
          continue
        }

        // Only remove .tmp files that are likely orphaned (older than 5 minutes)
        if fileName.hasSuffix(".tmp") {
          if let modificationDate = attributes?[.modificationDate] as? Date {
            let timeSinceModification = Date().timeIntervalSince(modificationDate)
            // Only remove .tmp files that are older than 5 minutes (likely orphaned)
            if timeSinceModification > 300 { // 5 minutes in seconds
              logger.info("🧹 Removing orphaned .tmp file: \(fileName) (age: \(Int(timeSinceModification))s)")
              try? FileManager.default.removeItem(at: fileURL)
              cleanedCount += 1
              continue
            } else {
              logger.debug("🔍 Skipping recent .tmp file: \(fileName) (age: \(Int(timeSinceModification))s)")
            }
          } else {
            // If we can't get modification date, be conservative and skip
            logger.debug("🔍 Skipping .tmp file without modification date: \(fileName)")
          }
        }

        // Check file size
        let fileSize: Int64 = attributes?[.size] as? Int64 ?? 0
        
        if fileSize < 1024 { // Less than 1KB
          try? FileManager.default.removeItem(at: fileURL)
          cleanedCount += 1
          continue
        }
        
        // Check for very recent files that might be incomplete
        if let modificationDate = attributes?[.modificationDate] as? Date {
          let timeSinceModification = Date().timeIntervalSince(modificationDate)
          if timeSinceModification < 30 { // Modified in last 30 seconds
            logger.debug("🔍 Recent file detected: \(fileName) - may be incomplete")
          }
        }
      }
      
      if cleanedCount > 0 {
        logger.info("🧹 Cleaned \(cleanedCount) suspicious files from \(name)")
      }
      
    } catch {
      logger.warning("Could not clean directory \(name): \(error)")
    }
  }
}

// MARK: - Supporting Types

/// Information about a downloaded model.
public struct ModelInfo: Sendable {
  public let modelId: String
  public let totalFiles: Int
  public let modelFiles: Int
  public let configFiles: Int
  public let estimatedSizeGB: Double
  public let filenames: [String]
}

/// Errors related to optimized model downloading.
public enum OptimizedDownloadError: Error, LocalizedError {
  case downloadFailed(String)
  case modelInfoFailed(String)
  case verificationFailed(String)
  case networkUnavailable(String)

  public var errorDescription: String? {
    switch self {
    case .downloadFailed(let message):
      return "Download failed: \(message)"
    case .modelInfoFailed(let message):
      return "Failed to get model info: \(message)"
    case .verificationFailed(let message):
      return "Model verification failed: \(message)"
    case .networkUnavailable(let message):
      return "Network unavailable: \(message)"
    }
  }
}
