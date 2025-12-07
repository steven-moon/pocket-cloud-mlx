// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/FileManagerService.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class FileManagerService: @unchecked Sendable {
//   - enum FileManagerError: Error, LocalizedError {
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

/// Cross-platform file management service for PocketCloudMLX
public class FileManagerService: @unchecked Sendable {
  public static let shared: FileManagerService = {
    let service = FileManagerService()
    return service
  }()
  
  private let logger: Logger = .init(label: "PocketCloudMLX.FileManagerService")

  private init() {
    // Do not log here to avoid circular dependency with AppLogger
  }

  /// Gets the models directory, creating it if it doesn't exist
  /// Uses standard HuggingFace cache location that MLX framework expects
  public func getModelsDirectory() throws -> URL {
    logger.info("📁 Getting models directory (using standard HuggingFace cache location for MLX compatibility)")

    // Use standard HuggingFace cache location that MLX framework expects
    // MLX looks for models in ~/.cache/huggingface/hub/ by default
    let homeDirectory = FileManager.default.mlxUserHomeDirectory
    let modelsDirectory = homeDirectory
      .appendingPathComponent(".cache")
      .appendingPathComponent("huggingface")
      .appendingPathComponent("hub")

    // Create directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
      try FileManager.default.createDirectory(
        at: modelsDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
      logger.info("📁 Created models directory at: \(modelsDirectory.path)")
    }

    return modelsDirectory
  }

  /// Ensures the models directory exists and returns its URL
  public func ensureModelsDirectoryExists() throws -> URL {
    return try getModelsDirectory()
  }

  /// Checks if a model is already downloaded by validating known on-disk layouts.
  public func isModelDownloaded(modelId: String) async -> Bool {
    let normalizedId = ModelConfiguration.normalizeHubId(modelId)

    do {
      let modelsDirectory = try getModelsDirectory()
      let candidates = candidateModelDirectories(for: normalizedId, modelsDirectory: modelsDirectory)

      for directory in candidates {
        if hasModelArtifacts(at: directory) {
          return true
        }
      }

      // Fall back to a full scan via the optimized downloader in case the model
      // only exists under the Hugging Face cache structure.
      let downloaded = try await OptimizedDownloader().getDownloadedModels()
      return downloaded.contains { ModelConfiguration.normalizeHubId($0.hubId) == normalizedId }
    } catch {
      logger.warning("⚠️ Failed to validate download state for \(normalizedId): \(error.localizedDescription)")
      return false
    }
  }

  /// Gets the local path for a downloaded model
  public func getModelPath(modelId: String) throws -> URL {
    let modelsDirectory = try getModelsDirectory()
    return modelsDirectory.appendingPathComponent(modelId)
  }

  /// Gets the cache directory for temporary files
  public func getCacheDirectory() throws -> URL {
    // Do not log here to avoid circular dependency with AppLogger

    let cacheDirectory = try FileManager.default.url(
      for: .cachesDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    let mlxCacheDirectory = cacheDirectory.appendingPathComponent("PocketCloudMLX")

    // Create directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: mlxCacheDirectory.path) {
      try FileManager.default.createDirectory(
        at: mlxCacheDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
      // Do not log here
    }

    return mlxCacheDirectory
  }

  /// Gets the application support directory for configuration files
  public func getApplicationSupportDirectory() throws -> URL {
    logger.info("📁 Getting Application Support directory")

    let appSupport = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    let appDirectory = appSupport.appendingPathComponent("PocketCloudMLX", isDirectory: true)

    // Create app directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: appDirectory.path) {
      try FileManager.default.createDirectory(
        at: appDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
      logger.info("📁 Created application support directory at: \(appDirectory.path)")
    }

    return appDirectory
  }

  /// Gets the temporary directory for downloads in progress
  public func getTemporaryDirectory() throws -> URL {
    logger.info("📁 Getting temporary directory")

    let tempDirectory = FileManager.default.temporaryDirectory
    let mlxTempDirectory = tempDirectory.appendingPathComponent("PocketCloudMLX")

    // Create directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: mlxTempDirectory.path) {
      try FileManager.default.createDirectory(
        at: mlxTempDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
      logger.info("📁 Created temporary directory at: \(mlxTempDirectory.path)")
    }

    return mlxTempDirectory
  }

  /// Deletes a model directory or file
  public func deleteModel(at url: URL) throws {
    logger.info("🗑️ Deleting model at \(url.lastPathComponent)")

    guard FileManager.default.fileExists(atPath: url.path) else {
      logger.warning("⚠️ File does not exist at path: \(url.path)")
      throw FileManagerError.fileNotFound(url.path)
    }

    try FileManager.default.removeItem(at: url)
  }

  /// Checks if a file exists
  public func fileExists(at url: URL) -> Bool {
    let exists = FileManager.default.fileExists(atPath: url.path)
    logger.debug("🔍 File exists at \(url.lastPathComponent): \(exists)")
    return exists
  }

  /// Gets the size of a file in bytes
  public func getFileSize(at url: URL) throws -> Int64 {
    logger.debug("📏 Getting file size for \(url.lastPathComponent)")

    guard FileManager.default.fileExists(atPath: url.path) else {
      throw FileManagerError.fileNotFound(url.path)
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let fileSize = attributes[.size] as? Int64 ?? 0

    return fileSize
  }

  /// Gets the total size of a directory in bytes
  public func getDirectorySize(at url: URL) throws -> Int64 {
    logger.info("📏 Getting directory size for \(url.lastPathComponent)")

    guard FileManager.default.fileExists(atPath: url.path) else {
      throw FileManagerError.directoryNotFound(url.path)
    }

    var totalSize: Int64 = 0
    let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
    let directoryEnumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles],
      errorHandler: nil
    )

    while let fileURL = directoryEnumerator?.nextObject() as? URL {
      let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
      if resourceValues.isRegularFile == true {
        totalSize += Int64(resourceValues.fileSize ?? 0)
      }
    }

    return totalSize
  }

  /// Moves a file or directory to a new location
  public func moveItem(from sourceURL: URL, to destinationURL: URL) throws {
    logger.info("📦 Moving item from \(sourceURL.lastPathComponent) to \(destinationURL.lastPathComponent)")

    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      throw FileManagerError.fileNotFound(sourceURL.path)
    }

    // Create destination directory if needed
    let destinationDir = destinationURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: destinationDir.path) {
      try FileManager.default.createDirectory(
        at: destinationDir,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    // Remove destination if it exists
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }

    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
  }

  /// Copies a file or directory to a new location
  public func copyItem(from sourceURL: URL, to destinationURL: URL) throws {
    logger.info("📋 Copying item from \(sourceURL.lastPathComponent) to \(destinationURL.lastPathComponent)")

    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      throw FileManagerError.fileNotFound(sourceURL.path)
    }

    // Create destination directory if needed
    let destinationDir = destinationURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: destinationDir.path) {
      try FileManager.default.createDirectory(
        at: destinationDir,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    // Remove destination if it exists
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }

    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
  }

  /// Lists all files in a directory
  public func listFiles(in directory: URL) throws -> [URL] {
    logger.debug("📂 Listing files in \(directory.lastPathComponent)")

    guard FileManager.default.fileExists(atPath: directory.path) else {
      throw FileManagerError.directoryNotFound(directory.path)
    }

    let files = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ).filter { url in
      (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }

    logger.debug("📂 Found \(files.count) files")
    return files
  }

  /// Cleans up temporary files
  public func cleanupTemporaryFiles() throws {
    logger.info("🧹 Cleaning up temporary files")

    let tempDirectory = try getTemporaryDirectory()
    let files = try listFiles(in: tempDirectory)

    var deletedCount = 0
    for file in files {
      do {
        try FileManager.default.removeItem(at: file)
        deletedCount += 1
      } catch {
        logger.warning("⚠️ Failed to delete temporary file: \(file.lastPathComponent)")
      }
    }

    logger.info("🧹 Cleaned up \(deletedCount) temporary files")
  }
}

// MARK: - Error Types

public enum FileManagerError: Error, LocalizedError {
  case directoryNotFound(String)
  case fileNotFound(String)
  case permissionDenied(String)
  case diskFull
  case unknown(Error)

  public var errorDescription: String? {
    switch self {
    case .directoryNotFound(let path):
      return "Directory not found: \(path)"
    case .fileNotFound(let path):
      return "File not found: \(path)"
    case .permissionDenied(let path):
      return "Permission denied: \(path)"
    case .diskFull:
      return "Disk full"
    case .unknown(let error):
      return "Unknown file manager error: \(error.localizedDescription)"
    }
  }
}

// MARK: - Cross-Platform Helpers

extension FileManager {
  /// Provides a cross-platform replacement for `homeDirectoryForCurrentUser`.
  var mlxUserHomeDirectory: URL {
    #if targetEnvironment(macCatalyst)
    // Mac Catalyst behaves like iOS for file system purposes.
    return urls(for: .documentDirectory, in: .userDomainMask).first ?? temporaryDirectory
    #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    return urls(for: .documentDirectory, in: .userDomainMask).first ?? temporaryDirectory
    #elseif os(macOS)
    return homeDirectoryForCurrentUser
    #else
    return urls(for: .documentDirectory, in: .userDomainMask).first ?? temporaryDirectory
    #endif
  }
}

// MARK: - Private helpers

extension FileManagerService {
  private func candidateModelDirectories(for hubId: String, modelsDirectory: URL) -> [URL] {
    var candidates: Set<URL> = []
    let components = hubId.split(separator: "/").map(String.init)
    if components.count == 2 {
      let owner = components[0]
      let repo = components[1]

      // Direct "owner/repo" layout used by PocketCloudMLX.
      let ownerRepo = modelsDirectory
        .appendingPathComponent(owner, isDirectory: true)
        .appendingPathComponent(repo, isDirectory: true)
      candidates.insert(ownerRepo)

      // Hugging Face cache layout inside the same base directory.
      let hfRoot = modelsDirectory.appendingPathComponent("models--\(owner)--\(repo)", isDirectory: true)
      candidates.insert(hfRoot)

      // Ensure we also look inside the user caches directory where Hub may store snapshots.
      if let cachesRoot = try? FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ).appendingPathComponent("huggingface")
        .appendingPathComponent("hub", isDirectory: true) {
        let cacheOwnerRepo = cachesRoot
          .appendingPathComponent(owner, isDirectory: true)
          .appendingPathComponent(repo, isDirectory: true)
        candidates.insert(cacheOwnerRepo)
        let cacheHFRoot = cachesRoot.appendingPathComponent("models--\(owner)--\(repo)", isDirectory: true)
        candidates.insert(cacheHFRoot)
      }
    } else {
      candidates.insert(modelsDirectory.appendingPathComponent(hubId, isDirectory: true))
    }

    return Array(candidates)
  }

  private func hasModelArtifacts(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      return false
    }

    guard let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return false
    }

    let tokenizerNames: Set<String> = ["tokenizer.json", "tokenizer.model", "tokenizer_config.json"]
    let weightSuffixes: [String] = [".safetensors", ".bin", ".gguf", ".npz", ".mlx"]

    var hasTokenizer = false
    var hasWeights = false

    for case let fileURL as URL in enumerator {
      let name = fileURL.lastPathComponent.lowercased()

      if tokenizerNames.contains(name) {
        hasTokenizer = true
      }

      if weightSuffixes.contains(where: { name.hasSuffix($0) }) {
        hasWeights = true
      }

      if hasTokenizer && hasWeights {
        return true
      }
    }

    return false
  }
}
