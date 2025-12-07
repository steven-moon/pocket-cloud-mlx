// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/ModelDownloadProtocols.swift
// Purpose       : Protocol definitions for model download system components
//
// Key Types in this file:
//   - protocol NetworkFailureHandling
//   - protocol FileIntegrityVerification
//   - protocol HuggingFaceDirectoryManagement
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation

// MARK: - Network Failure Handling

/// Protocol for managing network failures and retry logic
public protocol NetworkFailureHandling: Actor {
    /// Records a successful network operation
    func recordSuccess(for hubId: String)
    
    /// Records a network failure
    func recordFailure(for hubId: String, context: String, error: Error)
    
    /// Checks if network is ready for the given model
    func isNetworkReady(for hubId: String, context: String) -> Bool
    
    /// Gets pending backoff time in seconds
    func pendingBackoff(for hubId: String) -> Int?
    
    /// Determines if an error is network-related
    func isNetworkError(_ error: Error) -> Bool
}

// MARK: - File Integrity Verification

/// Represents file integrity expectations
public struct FileIntegrityExpectation: Sendable {
    public let expectedSize: Int64?
    public let expectedSHA256: String?
    
    public init(expectedSize: Int64?, expectedSHA256: String?) {
        self.expectedSize = expectedSize
        self.expectedSHA256 = expectedSHA256
    }
}

/// Protocol for file integrity verification
public protocol FileIntegrityVerification: Actor {
    /// Validates a downloaded file against expectations
    func validateFile(
        fileName: String,
        destination: URL,
        expectation: FileIntegrityExpectation?
    ) throws -> (passed: Bool, fileSize: Int64, failureReason: String?)
    
    /// Determines if hash verification should be performed
    func shouldVerifyHash(for fileName: String, fileSize: Int64) -> Bool
    
    /// Gets tolerance for file size comparison
    func fileSizeTolerance(for expectedSize: Int64) -> Int64
}

// MARK: - HuggingFace Directory Management

/// Protocol for managing HuggingFace cache directory structure
public protocol HuggingFaceDirectoryManagement: Actor {
    /// Gets the HuggingFace cache root directory
    func cacheRoot() -> URL
    
    /// Gets the model root directory (models--owner--repo)
    func modelRoot(for hubId: String) -> URL?
    
    /// Gets the snapshot directory for a model
    func snapshotDirectory(for hubId: String, resolveExisting: Bool) -> URL?
    
    /// Gets the refs directory for a model
    func refsDirectory(for hubId: String) -> URL?
    
    /// Gets the legacy directory format (owner/repo)
    func legacyDirectory(for hubId: String) -> URL?
    
    /// Normalizes snapshot references (main -> actual hash)
    func normalizeSnapshotReferences(for hubId: String)
    
    /// Copies downloaded files to HuggingFace cache structure
    func copyToHFDirectory(from sourceDir: URL, hubId: String) async
    
    /// Extracts HuggingFace model ID from filesystem path
    func extractModelId(from path: String) -> String
}

// MARK: - Model File Canonicalization

/// Protocol for canonicalizing model file structure
public protocol ModelFileCanonicalization: Actor {
    /// Creates canonical filenames that loaders expect
    func canonicalizeFiles(at directory: URL) async
    
    /// Flattens single-file directories
    func flattenSingleFileDirectories(at directory: URL)
}

// MARK: - Download Progress Notification

/// Protocol for posting download progress notifications
public protocol DownloadProgressNotification {
    /// Posts verification progress notification
    func postVerificationProgress(_ hubId: String, event: String, info: [String: Any])
    
    /// Posts download progress notification
    func postDownloadProgress(_ hubId: String, event: String, info: [String: Any])
}

// MARK: - Model Metadata Management

/// Protocol for caching and retrieving model metadata
public protocol ModelMetadataManagement: Actor {
    /// Caches model metadata to disk
    func cacheMetadata(_ metadata: [ModelFileMetadata], hubId: String)
    
    /// Loads cached metadata from disk
    func loadCachedMetadata(for hubId: String) -> [ModelFileMetadata]?
    
    /// Gets cached integrity expectations
    func cachedIntegrityExpectations(for hubId: String) -> [String: FileIntegrityExpectation]
}
