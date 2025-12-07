// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/HuggingFaceDirectoryManager.swift
// Purpose       : Manages HuggingFace cache directory structure and operations
//
// Key Types in this file:
//   - actor HuggingFaceDirectoryManager
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation
import PocketCloudLogger

/// Manages HuggingFace cache directory structure
public actor HuggingFaceDirectoryManager: HuggingFaceDirectoryManagement {
    private let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    // MARK: - HuggingFaceDirectoryManagement Protocol
    
    public func cacheRoot() -> URL {
        FileManager.default.mlxUserHomeDirectory
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
    }
    
    public func modelRoot(for hubId: String) -> URL? {
        guard let (owner, repo) = hubComponents(for: hubId) else { return nil }
        let root = cacheRoot()
        guard !root.path.isEmpty else { return nil }
        return root.appendingPathComponent("models--\(owner)--\(repo)", isDirectory: true)
    }
    
    public func snapshotDirectory(for hubId: String, resolveExisting: Bool = true) -> URL? {
        guard let modelRoot = modelRoot(for: hubId) else { return nil }
        let snapshotsRoot = modelRoot.appendingPathComponent("snapshots", isDirectory: true)
        let mainDir = snapshotsRoot.appendingPathComponent("main", isDirectory: true)
        
        guard resolveExisting else { return mainDir }
        
        let fm = FileManager.default
        
        // Check refs/main for current revision
        if let revision = currentRevisionName(for: hubId), !revision.isEmpty {
            let revisionDir = snapshotsRoot.appendingPathComponent(revision, isDirectory: true)
            if fm.fileExists(atPath: revisionDir.path) {
                return revisionDir
            }
        }
        
        // Check if main directory exists
        if fm.fileExists(atPath: mainDir.path) {
            return mainDir
        }
        
        // Check snapshots root
        guard fm.fileExists(atPath: snapshotsRoot.path) else {
            return mainDir
        }
        
        // Find latest snapshot
        if let fallback = latestSnapshotDirectory(at: snapshotsRoot) {
            updateRefsMain(for: hubId, pointingTo: fallback.lastPathComponent)
            logger.info("🔖 Using fallback snapshot \(fallback.lastPathComponent) for \(hubId)")
            return fallback
        }
        
        return mainDir
    }
    
    public func refsDirectory(for hubId: String) -> URL? {
        guard let modelRoot = modelRoot(for: hubId) else { return nil }
        return modelRoot.appendingPathComponent("refs", isDirectory: true)
    }
    
    public func legacyDirectory(for hubId: String) -> URL? {
        guard let (owner, repo) = hubComponents(for: hubId) else { return nil }
        let root = cacheRoot()
        guard !root.path.isEmpty else { return nil }
        return root
            .appendingPathComponent(owner, isDirectory: true)
            .appendingPathComponent(repo, isDirectory: true)
    }
    
    public func normalizeSnapshotReferences(for hubId: String) {
        guard let modelRoot = modelRoot(for: hubId) else { return }
        let snapshotsRoot = modelRoot.appendingPathComponent("snapshots", isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: snapshotsRoot.path) else { return }
        
        let mainDir = snapshotsRoot.appendingPathComponent("main", isDirectory: true)
        if fm.fileExists(atPath: mainDir.path) {
            // If main is a real directory, update refs to point to it
            updateRefsMain(for: hubId, pointingTo: "main")
            return
        }
        
        // Try to use current revision from refs
        if let currentRevision = currentRevisionName(for: hubId) {
            let revisionDir = snapshotsRoot.appendingPathComponent(currentRevision, isDirectory: true)
            if fm.fileExists(atPath: revisionDir.path) {
                return // Already properly referenced
            }
        }
        
        // Fallback to latest snapshot
        guard let fallback = latestSnapshotDirectory(at: snapshotsRoot) else { return }
        updateRefsMain(for: hubId, pointingTo: fallback.lastPathComponent)
        logger.info("🔖 Updated refs/main to fallback snapshot \(fallback.lastPathComponent) for \(hubId)")
    }
    
    public func copyToHFDirectory(from sourceDir: URL, hubId: String) async {
        guard let snapshotDir = snapshotDirectory(for: hubId, resolveExisting: false),
              let modelRoot = modelRoot(for: hubId),
              let legacyDir = legacyDirectory(for: hubId) else {
            logger.warning("⚠️ Unable to resolve HF cache directories for \(hubId)")
            return
        }
        
        let fm = FileManager.default
        logger.info("🔄 Starting structured HF copy for \(hubId)")
        
        guard fm.fileExists(atPath: sourceDir.path) else {
            logger.error("❌ Source directory does not exist: \(sourceDir.path)")
            return
        }
        
        var sourceContents: [String] = []
        do {
            flattenSingleFileDirectories(at: sourceDir)
            sourceContents = try fm.contentsOfDirectory(atPath: sourceDir.path)
        } catch {
            logger.error("❌ Could not enumerate source directory: \(error)")
            return
        }
        
        guard !sourceContents.isEmpty else {
            logger.error("❌ Source directory is empty: \(sourceDir.path)")
            return
        }
        
        // Prepare snapshot directory
        do {
            if fm.fileExists(atPath: modelRoot.path) {
                try fm.removeItem(at: modelRoot)
                logger.info("🗑️ Removed existing HF model root: \(modelRoot.path)")
            }
            try fm.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
            logger.info("📁 Created snapshot directory: \(snapshotDir.path)")
        } catch {
            logger.error("❌ Failed to prepare HF directories: \(error)")
            return
        }
        
        // Copy files to snapshot directory
        var copiedCount = 0
        for sourceItem in sourceContents {
            let sourcePath = sourceDir.appendingPathComponent(sourceItem)
            let targetPath = snapshotDir.appendingPathComponent(sourceItem)
            
            do {
                if fm.fileExists(atPath: targetPath.path) {
                    try fm.removeItem(at: targetPath)
                }
                try fm.copyItem(at: sourcePath, to: targetPath)
                copiedCount += 1
            } catch {
                logger.warning("⚠️ Failed to copy \(sourceItem): \(error)")
            }
        }
        
        logger.info("✅ Copied \(copiedCount)/\(sourceContents.count) items to HF snapshot")
        
        // Update refs/main
        updateRefsMain(for: hubId, pointingTo: snapshotDir.lastPathComponent)
        
        // Also copy to legacy directory for compatibility
        do {
            if fm.fileExists(atPath: legacyDir.path) {
                try fm.removeItem(at: legacyDir)
            }
            try fm.createDirectory(at: legacyDir.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: snapshotDir, to: legacyDir)
            logger.info("📁 Created legacy directory copy at: \(legacyDir.path)")
        } catch {
            logger.debug("⚠️ Could not create legacy copy: \(error)")
        }
    }
    
    public func extractModelId(from path: String) -> String {
        // Handle filesystem paths like: models--mlx-community--Qwen1.5-0.5B-Chat-4bit/snapshots/local
        // Convert to: mlx-community/Qwen1.5-0.5B-Chat-4bit
        
        if path.contains("models--") && path.contains("--") {
            let components = path.split(separator: "/")
            if let firstComponent = components.first,
               firstComponent.hasPrefix("models--") && firstComponent.contains("--") {
                
                let withoutPrefix = firstComponent.dropFirst("models--".count)
                let modelId = withoutPrefix.replacingOccurrences(of: "--", with: "/")
                return modelId
            }
        }
        
        return path
    }
    
    // MARK: - Private Helpers
    
    private func hubComponents(for hubId: String) -> (owner: String, repo: String)? {
        let cleaned = ModelConfiguration.normalizeHubId(hubId)
        let parts = cleaned.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
    
    private func currentRevisionName(for hubId: String) -> String? {
        guard let refsDir = refsDirectory(for: hubId) else { return nil }
        let mainRef = refsDir.appendingPathComponent("main", isDirectory: false)
        guard FileManager.default.fileExists(atPath: mainRef.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: mainRef)
            let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        } catch {
            return nil
        }
    }
    
    private func updateRefsMain(for hubId: String, pointingTo revision: String) {
        guard let refsDir = refsDirectory(for: hubId) else { return }
        let fm = FileManager.default
        
        do {
            try fm.createDirectory(at: refsDir, withIntermediateDirectories: true)
            let mainRef = refsDir.appendingPathComponent("main", isDirectory: false)
            try revision.write(to: mainRef, atomically: true, encoding: .utf8)
            logger.debug("🔖 refs/main for \(hubId) now points to \(revision)")
        } catch {
            logger.warning("⚠️ Failed to update refs/main: \(error)")
        }
    }
    
    private func latestSnapshotDirectory(at snapshotsRoot: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: snapshotsRoot,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        let candidates: [(URL, Date?)] = contents.compactMap { url in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
            return (url, creationDate)
        }
        
        guard !candidates.isEmpty else { return nil }
        
        return candidates.sorted { lhs, rhs in
            guard let lhsDate = lhs.1, let rhsDate = rhs.1 else {
                return lhs.1 != nil
            }
            return lhsDate > rhsDate
        }.first?.0
    }
    
    private func flattenSingleFileDirectories(at directory: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        var directoriesToFlatten: [(parent: URL, child: URL)] = []
        
        for case let itemURL as URL in enumerator {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            guard let contents = try? fm.contentsOfDirectory(at: itemURL, includingPropertiesForKeys: nil),
                  contents.count == 1,
                  let singleItem = contents.first else { continue }
            
            if singleItem.lastPathComponent == itemURL.lastPathComponent {
                directoriesToFlatten.append((parent: itemURL, child: singleItem))
            }
        }
        
        for (parent, child) in directoriesToFlatten {
            do {
                let tempURL = parent.deletingLastPathComponent()
                    .appendingPathComponent(UUID().uuidString)
                try fm.moveItem(at: child, to: tempURL)
                try fm.removeItem(at: parent)
                try fm.moveItem(at: tempURL, to: parent)
                logger.debug("📁 Flattened single-file directory: \(parent.lastPathComponent)")
            } catch {
                logger.warning("⚠️ Failed to flatten directory \(parent.lastPathComponent): \(error)")
            }
        }
    }
}
