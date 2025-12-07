// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/ModelDownloadCoordinator.swift
// Purpose       : Coordinates model file downloads with progress tracking
//
// Key Types in this file:
//   - actor ModelDownloadCoordinator
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation
import PocketCloudLogger
@preconcurrency import Hub

/// Coordinates model downloads with progress tracking and file management
public actor ModelDownloadCoordinator {
    private let logger = Logger(label: "ModelDownloadCoordinator")
    private let fileVerifier: FileIntegrityVerifier
    private let metadataManager: ModelMetadataManager
    private let fileCanonicalizer: ModelFileCanonicalizer
    private let hfDirectoryManager: HuggingFaceDirectoryManager
    private let networkFailureManager: NetworkFailureManager
    private let progressNotifier: DownloadProgressNotifier
    private let huggingFaceAPI: HuggingFaceAPI
    
    public init(
        fileVerifier: FileIntegrityVerifier,
        metadataManager: ModelMetadataManager,
        fileCanonicalizer: ModelFileCanonicalizer,
        hfDirectoryManager: HuggingFaceDirectoryManager,
        networkFailureManager: NetworkFailureManager,
        progressNotifier: DownloadProgressNotifier,
        huggingFaceAPI: HuggingFaceAPI
    ) {
        self.fileVerifier = fileVerifier
        self.metadataManager = metadataManager
        self.fileCanonicalizer = fileCanonicalizer
        self.hfDirectoryManager = hfDirectoryManager
        self.networkFailureManager = networkFailureManager
        self.progressNotifier = progressNotifier
        self.huggingFaceAPI = huggingFaceAPI
    }
    
    // MARK: - Public API
    
    /// Downloads a model to the specified directory
    public func downloadModel(
        _ config: ModelConfiguration,
        to modelDirectory: URL,
        tempDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        logger.info("🚀 Starting download for \(config.hubId)")
        
        // Check network readiness
        guard await networkFailureManager.isNetworkReady(for: config.hubId, context: "download start") else {
            let waitSeconds = await networkFailureManager.pendingBackoff(for: config.hubId) ?? 0
            throw OptimizedDownloadError.networkUnavailable("Network backoff active (retry in ~\(waitSeconds)s)")
        }
        
        // Fetch model metadata
        let metadataRecords = try await fetchModelMetadata(for: config.hubId)
        await networkFailureManager.recordSuccess(for: config.hubId)
        
        // Cache metadata
        await metadataManager.cacheMetadata(metadataRecords, hubId: config.hubId)
        
        // Filter files to download
        let filteredRecords = filterEssentialFiles(metadataRecords)
        guard !filteredRecords.isEmpty else {
            throw OptimizedDownloadError.downloadFailed("No files to download after filtering")
        }
        
        logger.info("📦 Downloading \(filteredRecords.count) files for \(config.hubId)")
        
        // Calculate total size
        let knownSizeTotal = filteredRecords.compactMap(\.size).reduce(Int64(0), +)
        let pendingUnknownCount = filteredRecords.filter { $0.size == nil }.count
        let expectedTotalBytes: Int64? = pendingUnknownCount == 0 ? knownSizeTotal : nil
        
        // Build integrity expectations
        let integrityExpectations = Dictionary(uniqueKeysWithValues: filteredRecords.map { record in
            (record.fileName, FileIntegrityExpectation(expectedSize: record.size, expectedSHA256: record.sha256))
        })
        
        // Post start notification
        var startInfo: [String: Any] = [
            "totalFiles": filteredRecords.count,
            "knownBytes": knownSizeTotal
        ]
        if let expectedTotal = expectedTotalBytes {
            startInfo["expectedTotalBytes"] = expectedTotal
        }
        progressNotifier.postDownloadProgress(config.hubId, event: "start", info: startInfo)
        
        // Download files
        let allFiles = filteredRecords.map { $0.fileName }
        var downloadedBytesSoFar: Int64 = 0
        var completedFiles = 0
        
        for (index, record) in filteredRecords.enumerated() {
            let fileName = record.fileName
            let destination = tempDirectory.appendingPathComponent(fileName)
            
            logger.info("📥 [\(index + 1)/\(filteredRecords.count)] Downloading \(fileName)")
            
            // Ensure parent directory exists
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            // Download the file
            let currentCompletedFiles = completedFiles
            let totalFileCount = filteredRecords.count
            let currentDownloadedBytesSoFar = downloadedBytesSoFar
            try await huggingFaceAPI.downloadModel(
                modelId: config.hubId,
                fileName: fileName,
                to: destination
            ) { fileProgress, bytesDownloaded, totalBytesForFile in
                // Calculate overall progress
                let totalSoFar = currentDownloadedBytesSoFar + bytesDownloaded
                
                if let expectedTotal = expectedTotalBytes {
                    let overallProgress = Double(totalSoFar) / Double(expectedTotal)
                    Task { @MainActor in
                        progress(overallProgress)
                    }
                } else {
                    // Use file-based progress
                    let fileBasedProgress = Double(currentCompletedFiles) / Double(totalFileCount) + 
                                          fileProgress / Double(totalFileCount)
                    Task { @MainActor in
                        progress(fileBasedProgress)
                    }
                }
            }
            
            // Validate downloaded file
            let expectation = integrityExpectations[fileName]
            do {
                let validationResult = try await fileVerifier.validateFile(
                    fileName: fileName,
                    destination: destination,
                    expectation: expectation
                )
                
                if !validationResult.passed {
                    logger.warning("⚠️ File validation failed for \(fileName): \(validationResult.failureReason ?? "unknown")")
                }
                
                downloadedBytesSoFar += validationResult.fileSize
            } catch {
                logger.warning("⚠️ Could not validate \(fileName): \(error)")
                // Continue anyway - file was downloaded
                if let size = record.size {
                    downloadedBytesSoFar += size
                }
            }
            
            completedFiles += 1
            
            progressNotifier.postDownloadProgress(config.hubId, event: "file_complete", info: [
                "fileName": fileName,
                "completedFiles": completedFiles,
                "totalFiles": filteredRecords.count
            ])
        }
        
        // Post completion notification
        progressNotifier.postDownloadProgress(config.hubId, event: "complete", info: [
            "completedFiles": completedFiles,
            "totalFiles": filteredRecords.count,
            "overallTotalBytes": expectedTotalBytes ?? downloadedBytesSoFar
        ])
        
        // Validate all files exist
        logger.info("🔍 Validating downloaded files...")
        for fileName in allFiles {
            let filePath = tempDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                throw OptimizedDownloadError.downloadFailed("Downloaded file missing: \(fileName)")
            }
        }
        
        // Move files to final location
        try await moveFilesToFinalLocation(
            files: allFiles,
            from: tempDirectory,
            to: modelDirectory
        )
        
        // Canonicalize files
        await fileCanonicalizer.canonicalizeFiles(at: modelDirectory)
        
        // Copy to HuggingFace cache structure
        await hfDirectoryManager.copyToHFDirectory(from: modelDirectory, hubId: config.hubId)
        
        progress(1.0)
        logger.info("✅ Download completed for \(config.hubId)")
        
        return modelDirectory
    }
    
    /// Downloads a model with resume capability (currently delegates to regular download)
    public func downloadModelWithResume(
        _ config: ModelConfiguration,
        to modelDirectory: URL,
        tempDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // For now, delegate to regular download
        // TODO: Implement true resume capability with partial file support
        return try await downloadModel(config, to: modelDirectory, tempDirectory: tempDirectory, progress: progress)
    }
    
    // MARK: - Private Helpers
    
    private func fetchModelMetadata(for hubId: String) async throws -> [ModelFileMetadata] {
        // Try to use cached metadata first
        if let cached = await metadataManager.loadCachedMetadata(for: hubId) {
            logger.info("📄 Using cached metadata for \(hubId)")
            return cached
        }
        
        // Fetch from API
        do {
            let records = try await huggingFaceAPI.listModelFilesDetailed(modelId: hubId)
            return records
        } catch let hfError as HuggingFaceError {
            if case .notFound(let message) = hfError {
                logger.error("❌ Repository not found: \(hubId) - \(message)")
                await networkFailureManager.recordSuccess(for: hubId)
            } else {
                await networkFailureManager.recordFailure(
                    for: hubId,
                    context: "metadata fetch",
                    error: hfError
                )
            }
            throw hfError
        } catch {
            await networkFailureManager.recordFailure(
                for: hubId,
                context: "metadata fetch",
                error: error
            )
            throw error
        }
    }
    
    private func filterEssentialFiles(_ records: [ModelFileMetadata]) -> [ModelFileMetadata] {
        return records.filter { record in
            let name = record.fileName.lowercased()
            
            // Skip hidden, temporary, and git files
            if name.hasPrefix(".") || name.contains("/.") { return false }
            if name.hasSuffix(".tmp") || name.hasSuffix(".temp") { return false }
            if name.hasPrefix(".git") || name.contains("/.git") { return false }
            
            // Skip README and documentation
            if name.hasPrefix("readme") { return false }
            if name.hasSuffix(".md") && !name.contains("model") { return false }
            
            // Skip sample/example files
            if name.contains("sample") || name.contains("example") { return false }
            
            // Skip unnecessary image files
            if name.hasSuffix(".png") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") { return false }
            
            // Skip license files that aren't needed for inference
            if name == "license" || name == "license.txt" { return false }
            
            // Include essential model files
            let essentialExtensions: [String] = [
                ".json", ".safetensors", ".bin", ".gguf", ".mlx", ".npz",
                ".model", ".vocab", ".txt", ".py"
            ]
            
            for ext in essentialExtensions {
                if name.hasSuffix(ext) { return true }
            }
            
            // Include if it contains "config", "tokenizer", or "model" in name
            if name.contains("config") || name.contains("tokenizer") || name.contains("model") {
                return true
            }
            
            return false
        }
    }
    
    private func moveFilesToFinalLocation(
        files: [String],
        from tempDir: URL,
        to modelDir: URL
    ) async throws {
        let fm = FileManager.default
        
        // Ensure model directory exists
        let parentDirectory = modelDir.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDirectory.path) {
            try fm.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        }
        
        // Remove existing model directory
        if fm.fileExists(atPath: modelDir.path) {
            try fm.removeItem(at: modelDir)
        }
        
        // Create fresh model directory
        try fm.createDirectory(at: modelDir, withIntermediateDirectories: true)
        
        // Copy files individually
        for fileName in files {
            let sourcePath = tempDir.appendingPathComponent(fileName)
            let destPath = modelDir.appendingPathComponent(fileName)
            
            // Create subdirectories if needed
            let destParent = destPath.deletingLastPathComponent()
            if !fm.fileExists(atPath: destParent.path) {
                try fm.createDirectory(at: destParent, withIntermediateDirectories: true)
            }
            
            try fm.copyItem(at: sourcePath, to: destPath)
        }
        
        logger.info("📦 Moved \(files.count) files to \(modelDir.lastPathComponent)")
    }
    
    // MARK: - Model Discovery
    
    /// Scans for downloaded models and returns their configurations
    public func getDownloadedModels() async throws -> [ModelConfiguration] {
        let fileManager = FileManagerService.shared
        let modelsDirectory = try fileManager.ensureModelsDirectoryExists()
        
        logger.info("🔍 Scanning for downloaded models in: \(modelsDirectory.path)")
        
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            logger.warning("⚠️ Models directory does not exist: \(modelsDirectory.path)")
            return []
        }

        // Walk the tree and collect parent directories of weight files
        var candidateDirs = Set<URL>()
        if let enumerator = FileManager.default.enumerator(at: modelsDirectory, includingPropertiesForKeys: [.isDirectoryKey]) {
            while let itemURL = enumerator.nextObject() as? URL {
                let name = itemURL.lastPathComponent.lowercased()
                if name.hasSuffix(".safetensors") || name.hasSuffix(".bin") || name.hasSuffix(".gguf") || name.hasSuffix(".npz") || name.hasSuffix(".mlx") {
                    candidateDirs.insert(itemURL.deletingLastPathComponent())
                }
            }
        }
        
        logger.info("📦 Found \(candidateDirs.count) candidate directories with weight files")

        var results: [ModelConfiguration] = []
        for dir in candidateDirs {
            // Confirm tokenizer exists somewhere under the same directory
            var hasTokenizer = false
            if let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) {
                while let file = e.nextObject() as? URL {
                    let n = file.lastPathComponent.lowercased()
                    if n == "tokenizer.json" || n == "tokenizer.model" || n == "tokenizer_config.json" {
                        hasTokenizer = true
                        break
                    }
                }
            }
            guard hasTokenizer else { 
                logger.debug("⏭️ Skipping directory (no tokenizer): \(dir.path)")
                continue 
            }

            // Compute hubId as relative path from modelsDirectory (owner/model)
            let dirPath = dir.path
            var rel = dirPath.replacingOccurrences(of: modelsDirectory.path + "/", with: "")
            if rel.hasPrefix("/") { rel.removeFirst() }
            // Skip root if it resolved empty
            guard !rel.isEmpty else { 
                logger.debug("⏭️ Skipping directory (empty relative path): \(dir.path)")
                continue 
            }

            // Extract proper HuggingFace model ID from filesystem paths
            let hubId = extractHuggingFaceModelId(from: rel)
            
            logger.debug("✅ Found valid model", context: Logger.Context([
                "directory": dir.lastPathComponent,
                "relativePath": rel,
                "extractedHubId": hubId
            ]))

            let config = ModelConfiguration(name: dir.lastPathComponent, hubId: hubId, description: "Downloaded model")
            results.append(config)
        }

        // Stable, de-duplicated ordering
        let uniqueByHubId = Dictionary(grouping: results, by: { $0.hubId }).compactMap { $0.value.first }
        let sortedResults = uniqueByHubId.sorted { $0.hubId < $1.hubId }
        
        logger.info("✅ getDownloadedModels completed", context: Logger.Context([
            "totalFound": String(sortedResults.count),
            "models": sortedResults.map { $0.hubId }.joined(separator: ", ")
        ]))
        
        return sortedResults
    }
    
    /// Helper to extract HuggingFace model ID from filesystem path
    private func extractHuggingFaceModelId(from relativePath: String) -> String {
        // Handle HuggingFace cache structure: models--owner--repo/snapshots/main or revision/
        if relativePath.contains("models--") {
            let components = relativePath.components(separatedBy: "/")
            if let modelComponent = components.first(where: { $0.hasPrefix("models--") }) {
                // Convert models--owner--repo to owner/repo
                let parts = modelComponent.replacingOccurrences(of: "models--", with: "").components(separatedBy: "--")
                if parts.count >= 2 {
                    return "\(parts[0])/\(parts[1])"
                }
            }
        }
        
        // Otherwise use the relative path as-is (owner/repo format)
        return relativePath
    }
}
