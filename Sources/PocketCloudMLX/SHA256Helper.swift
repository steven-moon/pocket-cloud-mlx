// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/SHA256Helper.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:

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

#if canImport(CryptoKit)
  import CryptoKit
#endif

func sha256Hex(data: Data) -> String {
  #if canImport(CryptoKit)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  #else
    // Fallback: Not available, return empty string
    return ""
  #endif
}

/// Computes a SHA-256 digest for the file at `url` without loading the entire
/// contents into memory. Throws if the file cannot be read.
func sha256Hex(forFileAt url: URL) throws -> String {
  #if canImport(CryptoKit)
    guard let stream = InputStream(url: url) else {
      throw NSError(
        domain: "SHA256Helper",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Unable to create input stream for \(url.path)"])
    }

    stream.open()
    defer { stream.close() }

    var hasher = SHA256()
    let bufferSize = 1 << 20 // 1 MB chunking keeps memory bounded
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while stream.hasBytesAvailable {
      let readCount = stream.read(&buffer, maxLength: buffer.count)
      if readCount < 0 {
        throw stream.streamError ?? NSError(
          domain: "SHA256Helper",
          code: -2,
          userInfo: [NSLocalizedDescriptionKey: "Error reading \(url.lastPathComponent)"])
      }
      if readCount == 0 {
        break
      }

      buffer.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return }
        let slice = UnsafeRawBufferPointer(start: baseAddress, count: readCount)
        hasher.update(bufferPointer: slice)
      }
    }

    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
  #else
    let data = try Data(contentsOf: url)
    return sha256Hex(data: data)
  #endif
}
