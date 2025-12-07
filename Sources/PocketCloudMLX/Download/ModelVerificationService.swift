// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/ModelVerificationService.swift
// Purpose       : Verifies and repairs downloaded models
//
// Key Types in this file:
//   - actor ModelVerificationService
//   - enum ModelVerificationStatus
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation
import PocketCloudLogger

/// Model verification status after download/repair
public enum ModelVerificationStatus: Sendable {
    case healthy
    case repaired
    case needsRedownload
}

/// Verifies and repairs downloaded models
public actor ModelVerificationService {
    private let logger = Logger(label: "ModelVerificationService")
    private let fileVerifier: FileIntegrityVerifier
    private let metadataManager: ModelMetadataManager
    private let progressNotifier: DownloadProgressNotifier
    
    public init(
        fileVerifier: FileIntegrityVerifier,
        metadataManager: ModelMetadataManager,
        progressNotifier: DownloadProgressNotifier
    ) {
        self.fileVerifier = fileVerifier
        self.metadataManager = metadataManager
        self.progressNotifier = progressNotifier
    }
    
    // MARK: - Public API
    
    /// Checks and repairs a model, returning health status
    public func checkAndRepairModel(
        _ config: ModelConfiguration,
        at sourceDir: URL,
        targetDir: URL,
        progress: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> ModelVerificationStatus {
        progress("Starting model health check...")
        
        let result = await verifyModelFiles(at: sourceDir, targetDir: targetDir, config: config)
        
        switch result {
        case .healthy:
            progress("Model is healthy ✅")
            return .healthy
            
        case .missingFiles(let files):
            progress("Found \(files.count) missing files, attempting repair...")
            let repaired = try await repairMissingFiles(
                files,
                sourceDir: sourceDir,
                targetDir: targetDir,
                config: config
            )
            if repaired {
                progress("Successfully repaired missing files ✅")
                return .repaired
            } else {
                progress("Could not repair all missing files ⚠️")
                return .needsRedownload
            }
            
        case .corruptFiles(let files):
            progress("Found \(files.count) corrupt files, attempting repair...")
            let repaired = try await repairCorruptFiles(
                files,
                sourceDir: sourceDir,
                targetDir: targetDir,
                config: config
            )
            if repaired {
                progress("Successfully repaired corrupt files ✅")
                return .repaired
            } else {
                progress("Could not repair all corrupt files ⚠️")
                return .needsRedownload
            }
            
        case .needsRedownload:
            progress("Model requires complete redownload")
            return .needsRedownload
        }
    }
    
    /// Verifies model integrity
    public func verifyModel(_ config: ModelConfiguration, at directory: URL) async throws -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else {
            logger.warning("⚠️ Model directory does not exist: \(directory.path)")
            return false
        }
        
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return false
        }
        
        var hasConfig = false
        var hasTokenizer = false
        var hasWeights = false
        
        let configNames = ["config.json", "generation_config.json", "mlx_config.json"]
        let tokenizerNames = ["tokenizer.json", "tokenizer.model", "tokenizer_config.json"]
        
        while let fileURL = enumerator.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent.lowercased()
            
            if configNames.contains(fileName) { hasConfig = true }
            if tokenizerNames.contains(fileName) { hasTokenizer = true }
            if fileName.hasSuffix(".safetensors") || fileName.hasSuffix(".bin") ||
               fileName.hasSuffix(".gguf") || fileName.hasSuffix(".mlx") {
                hasWeights = true
            }
        }
        
        let isValid = hasTokenizer && hasWeights
        logger.info("Model verification: config=\(hasConfig), tokenizer=\(hasTokenizer), weights=\(hasWeights)")
        return isValid
    }
    
    /// Checks if a model directory is complete
    public func isModelDirectoryComplete(_ directory: URL) async -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        // Check for essential files
        let requiredFiles = ["config.json", "tokenizer.json"]
        let fm = FileManager.default
        
        var hasRequiredFiles = true
        for fileName in requiredFiles {
            let filePath = directory.appendingPathComponent(fileName)
            if !fm.fileExists(atPath: filePath.path) {
                // Try alternate names
                if fileName == "config.json" {
                    let alternates = ["model_config.json", "generation_config.json"]
                    let hasAlternate = alternates.contains { alt in
                        fm.fileExists(atPath: directory.appendingPathComponent(alt).path)
                    }
                    if !hasAlternate {
                        hasRequiredFiles = false
                        break
                    }
                } else if fileName == "tokenizer.json" {
                    let alternates = ["tokenizer.model", "tokenizer_config.json"]
                    let hasAlternate = alternates.contains { alt in
                        fm.fileExists(atPath: directory.appendingPathComponent(alt).path)
                    }
                    if !hasAlternate {
                        hasRequiredFiles = false
                        break
                    }
                } else {
                    hasRequiredFiles = false
                    break
                }
            }
        }
        
        if !hasRequiredFiles {
            return false
        }
        
        // Check for weight files
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return false
        }
        
        var hasWeights = false
        while let fileURL = enumerator.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent.lowercased()
            if fileName.hasSuffix(".safetensors") || fileName.hasSuffix(".bin") ||
               fileName.hasSuffix(".gguf") || fileName.hasSuffix(".mlx") || fileName.hasSuffix(".npz") {
                hasWeights = true
                break
            }
        }
        
        return hasWeights
    }
    
    // MARK: - Private Helpers
    
    private enum ModelVerificationResult {
        case healthy
        case missingFiles([String])
        case corruptFiles([String])
        case needsRedownload
    }
    
    private func verifyModelFiles(
        at sourceDir: URL,
        targetDir: URL,
        config: ModelConfiguration
    ) async -> ModelVerificationResult {
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: targetDir.path) else {
            return .needsRedownload
        }
        
        // Get cached integrity expectations
        let expectations = await metadataManager.cachedIntegrityExpectations(for: config.hubId)
        
        // Scan for files that should exist
        guard let sourceFiles = try? fm.contentsOfDirectory(atPath: sourceDir.path) else {
            return .needsRedownload
        }
        
        var missingFiles: [String] = []
        var corruptFiles: [String] = []
        
        for fileName in sourceFiles {
            let targetPath = targetDir.appendingPathComponent(fileName)
            
            if !fm.fileExists(atPath: targetPath.path) {
                missingFiles.append(fileName)
                continue
            }
            
            // Verify integrity if we have expectations
            if let expectation = expectations[fileName] {
                do {
                    let result = try await fileVerifier.validateFile(
                        fileName: fileName,
                        destination: targetPath,
                        expectation: expectation
                    )
                    if !result.passed {
                        corruptFiles.append(fileName)
                    }
                } catch {
                    corruptFiles.append(fileName)
                }
            }
        }
        
        if missingFiles.isEmpty && corruptFiles.isEmpty {
            return .healthy
        } else if !missingFiles.isEmpty {
            return .missingFiles(missingFiles)
        } else {
            return .corruptFiles(corruptFiles)
        }
    }
    
    private func repairMissingFiles(
        _ missingFiles: [String],
        sourceDir: URL,
        targetDir: URL,
        config: ModelConfiguration
    ) async throws -> Bool {
        let fm = FileManager.default
        var repairedCount = 0
        
        progressNotifier.postVerificationProgress(config.hubId, event: "repair_start", info: [
            "missingCount": missingFiles.count
        ])
        
        for fileName in missingFiles {
            let sourcePath = sourceDir.appendingPathComponent(fileName)
            let targetPath = targetDir.appendingPathComponent(fileName)
            
            guard fm.fileExists(atPath: sourcePath.path) else {
                logger.warning("⚠️ Cannot repair \(fileName) - source file missing")
                continue
            }
            
            do {
                if fm.fileExists(atPath: targetPath.path) {
                    try fm.removeItem(at: targetPath)
                }
                try fm.copyItem(at: sourcePath, to: targetPath)
                repairedCount += 1
                logger.info("✅ Repaired missing file: \(fileName)")
            } catch {
                logger.error("❌ Failed to repair \(fileName): \(error)")
            }
        }
        
        progressNotifier.postVerificationProgress(config.hubId, event: "repair_complete", info: [
            "repairedCount": repairedCount,
            "totalCount": missingFiles.count
        ])
        
        return repairedCount == missingFiles.count
    }
    
    private func repairCorruptFiles(
        _ corruptFiles: [String],
        sourceDir: URL,
        targetDir: URL,
        config: ModelConfiguration
    ) async throws -> Bool {
        // For corrupt files, we need to redownload them
        // This is a placeholder - actual implementation would trigger redownload
        logger.warning("⚠️ Corrupt file repair requires redownload: \(corruptFiles.joined(separator: ", "))")
        return false
    }
}
