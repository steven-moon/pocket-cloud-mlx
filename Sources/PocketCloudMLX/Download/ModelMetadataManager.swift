// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/ModelMetadataManager.swift
// Purpose       : Caches and retrieves model file metadata
//
// Key Types in this file:
//   - actor ModelMetadataManager
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation

/// Manages caching and retrieval of model file metadata
public actor ModelMetadataManager: ModelMetadataManagement {
    private let downloadBase: URL
    
    public init(downloadBase: URL) {
        self.downloadBase = downloadBase
    }
    
    // MARK: - ModelMetadataManagement Protocol
    
    public func cacheMetadata(_ metadata: [ModelFileMetadata], hubId: String) {
        guard let cacheURL = metadataCacheURL(for: hubId) else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(metadata)
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // Silent failure for caching
        }
    }
    
    public func loadCachedMetadata(for hubId: String) -> [ModelFileMetadata]? {
        guard let cacheURL = metadataCacheURL(for: hubId) else { return nil }
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let records = try JSONDecoder().decode([ModelFileMetadata].self, from: data)
            return records
        } catch {
            return nil
        }
    }
    
    public func cachedIntegrityExpectations(for hubId: String) -> [String: FileIntegrityExpectation] {
        guard let cached = loadCachedMetadata(for: hubId) else { return [:] }
        return Dictionary(uniqueKeysWithValues: cached.map { record in
            (record.fileName, FileIntegrityExpectation(expectedSize: record.size, expectedSHA256: record.sha256))
        })
    }
    
    // MARK: - Private Helpers
    
    private func metadataCacheURL(for hubId: String) -> URL? {
        let sanitizedId = ModelConfiguration.normalizeHubId(hubId)
        guard !sanitizedId.isEmpty else { return nil }
        let cacheDirectory = downloadBase.appendingPathComponent(sanitizedId, isDirectory: true)
        return cacheDirectory.appendingPathComponent(".mlx-metadata.json", isDirectory: false)
    }
}
