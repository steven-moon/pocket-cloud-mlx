// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/FileIntegrityVerifier.swift
// Purpose       : Validates file downloads against size and hash expectations
//
// Key Types in this file:
//   - actor FileIntegrityVerifier
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation
import CryptoKit

/// Verifies file integrity using size and SHA256 hash validation
public actor FileIntegrityVerifier: FileIntegrityVerification {
    
    public init() {}
    
    // MARK: - FileIntegrityVerification Protocol
    
    public func validateFile(
        fileName: String,
        destination: URL,
        expectation: FileIntegrityExpectation?
    ) throws -> (passed: Bool, fileSize: Int64, failureReason: String?) {
        guard FileManager.default.fileExists(atPath: destination.path) else {
            return (false, 0, "File does not exist at destination")
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Validate size if expected size is provided
        if let expectedSize = expectation?.expectedSize, expectedSize > 0 {
            let tolerance = fileSizeTolerance(for: expectedSize)
            let actualSize = fileSize
            let diff = abs(actualSize - expectedSize)
            
            if diff > tolerance {
                return (false, fileSize, "Size mismatch: expected ~\(expectedSize) bytes, got \(actualSize) bytes")
            }
        }
        
        // Validate hash if expected hash is provided and file should be verified
        if let expectedSHA = expectation?.expectedSHA256,
           shouldVerifyHash(for: fileName, fileSize: fileSize) {
            do {
                let computedHash = try computeSHA256(for: destination)
                if computedHash.lowercased() != expectedSHA.lowercased() {
                    return (false, fileSize, "Hash mismatch: expected \(expectedSHA), got \(computedHash)")
                }
            } catch {
                return (false, fileSize, "Failed to compute hash: \(error.localizedDescription)")
            }
        }
        
        return (true, fileSize, nil)
    }
    
    public func shouldVerifyHash(for fileName: String, fileSize: Int64) -> Bool {
        // Always verify safetensors and important model files
        if fileName.hasSuffix(".safetensors") { return true }
        if fileName == "pytorch_model.bin" { return true }
        if fileName.hasSuffix(".mlx") || fileName.hasSuffix(".gguf") { return true }
        
        // Verify large files (50MB+)
        let largeFileThreshold: Int64 = 50 * 1024 * 1024
        return fileSize >= largeFileThreshold
    }
    
    public func fileSizeTolerance(for expectedSize: Int64) -> Int64 {
        // Use 1% tolerance or 512KB minimum
        let percentTolerance = Int64(Double(expectedSize) * 0.01)
        let floorTolerance: Int64 = 512 * 1024
        return max(percentTolerance, floorTolerance)
    }
    
    // MARK: - Private Helpers
    
    private func computeSHA256(for fileURL: URL) throws -> String {
        let bufferSize = 1024 * 1024 // 1MB buffer
        let file = try FileHandle(forReadingFrom: fileURL)
        defer { try? file.close() }
        
        var hasher = SHA256()
        
        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.isEmpty { return false }
            hasher.update(data: data)
            return true
        }) {}
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
