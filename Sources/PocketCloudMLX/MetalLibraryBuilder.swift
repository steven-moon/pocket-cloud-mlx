// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/MetalLibraryBuilder.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct MetalLibraryBuilder {
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
import Metal
import MetalKit

/// Metal library builder that automatically compiles Metal shaders and provides fallback mechanisms
/// for different development environments and hardware configurations.
public struct MetalLibraryBuilder {
  private static let logger = Logger(label: "MetalLibraryBuilder")

  private class BundleFinder {}

  /// Custom bundle accessor that avoids conflicts with other packages
  private static var mlxEngineBundle: Bundle {
    #if SWIFT_PACKAGE
    // Use Bundle(for:) approach to avoid conflicts with other packages' Bundle.module
    return Bundle(for: BundleFinder.self)
    #else
    return Bundle(for: BundleFinder.self)
    #endif
  }

  /// Metal library compilation status
  public enum CompilationStatus {
    case success(MTLLibrary)
    case failure(Error)
    case notSupported(String)
  }

  /// Metal library compilation errors
  public enum CompilationError: LocalizedError {
    case deviceNotFound
    case compilationFailed(String)
    case libraryNotFound
    case unsupportedPlatform

    public var errorDescription: String? {
      switch self {
      case .deviceNotFound:
        return "Metal device not found"
      case .compilationFailed(let message):
        return "Metal library compilation failed: \(message)"
      case .libraryNotFound:
        return "Metal library not found"
      case .unsupportedPlatform:
        return "Metal not supported on this platform"
      }
    }
  }

  /// Builds the Metal library with automatic fallback mechanisms
  /// - Returns: Compilation status with the compiled library or error information
  public static func buildLibrary() -> CompilationStatus {
    // Check if Metal is supported
    guard let device = MTLCreateSystemDefaultDevice() else {
      return .failure(CompilationError.deviceNotFound)
    }

    // Try to find precompiled library first
    if let precompiledLibrary = findPrecompiledLibrary(device: device) {
      return .success(precompiledLibrary)
    }

    // Try to compile from source
    if let compiledLibrary = compileFromSource(device: device) {
      return .success(compiledLibrary)
    }

    // Try to use embedded library (only if it passes validation)
    if let embeddedLibrary = createEmbeddedLibrary(device: device) {
      return .success(embeddedLibrary)
    }

    return .failure(CompilationError.libraryNotFound)
  }

  /// Finds precompiled Metal library in the bundle
  private static func findPrecompiledLibrary(device: MTLDevice) -> MTLLibrary? {
    let logger = self.logger

    var candidates: [URL] = []
    var seenPaths = Set<String>()

    func appendCandidate(_ url: URL?) {
      guard let url else { return }
      let path = url.path
      guard !path.isEmpty, !seenPaths.contains(path) else { return }
      seenPaths.insert(path)
      candidates.append(url)
    }

    appendCandidate(mlxEngineBundle.url(forResource: "default", withExtension: "metallib"))

    if let localCmlxBundleURL = mlxEngineBundle.url(forResource: "mlx-swift_Cmlx", withExtension: "bundle"),
       let cmlxBundle = Bundle(url: localCmlxBundleURL) {
      appendCandidate(cmlxBundle.url(forResource: "default", withExtension: "metallib"))
    }

    appendCandidate(Bundle.main.url(forResource: "default", withExtension: "metallib"))

    if let mainCmlxBundleURL = Bundle.main.url(forResource: "mlx-swift_Cmlx", withExtension: "bundle"),
       let mainCmlxBundle = Bundle(url: mainCmlxBundleURL) {
      appendCandidate(mainCmlxBundle.url(forResource: "default", withExtension: "metallib"))
    }

    for bundle in Bundle.allBundles + Bundle.allFrameworks {
      appendCandidate(bundle.url(forResource: "default", withExtension: "metallib"))
      if let cmlxBundleURL = bundle.url(forResource: "mlx-swift_Cmlx", withExtension: "bundle"),
         let cmlxBundle = Bundle(url: cmlxBundleURL) {
        appendCandidate(cmlxBundle.url(forResource: "default", withExtension: "metallib"))
      }
    }

    let fallbackPaths = [
      "./default.metallib",
      "../Resources/default.metallib",
      "/tmp/default.metallib",
      FileManager.default.currentDirectoryPath + "/Sources/PocketCloudMLX/Resources/default.metallib",
      Bundle.main.bundlePath + "/default.metallib"
    ]

    for path in fallbackPaths {
      if FileManager.default.fileExists(atPath: path) {
        appendCandidate(URL(fileURLWithPath: path))
      }
    }

    if candidates.isEmpty {
      logger.warning("No candidate default.metallib locations discovered")
    } else {
      logger.debug("Discovered \(candidates.count) candidate default.metallib locations")
    }

    for candidate in candidates {
      do {
        let library = try device.makeLibrary(URL: candidate)
        if validateLibrary(library) {
          logger.info("Using Metal library at \(candidate.path)")
          return library
        } else {
          logger.warning("Metal library at \(candidate.path) missing required functions; skipping")
        }
      } catch {
        logger.warning("Failed to load Metal library at \(candidate.path): \(error)")
      }
    }

    logger.error("Unable to locate a valid default.metallib with required kernels")
    return nil
  }

  /// Compiles Metal library from source files
  private static func compileFromSource(device: MTLDevice) -> MTLLibrary? {
    // Get Metal source files from MLX package
    let metalSources = findMetalSourceFiles()

    guard !metalSources.isEmpty else {
      logger.warning("No Metal source files found")
      return nil
    }

    logger.info("Compiling Metal library from \(metalSources.count) source files")

    // Compile all Metal sources
    var compiledSources: [String] = []

    for sourceFile in metalSources {
      if let compiledSource = compileMetalSource(sourceFile, device: device) {
        compiledSources.append(compiledSource)
      }
    }

    guard !compiledSources.isEmpty else {
      logger.error("No Metal sources compiled successfully")
      return nil
    }

    // Combine all compiled sources
    let combinedSource = compiledSources.joined(separator: "\n\n")

    do {
      let library = try device.makeLibrary(source: combinedSource, options: nil)
      if validateLibrary(library) {
        logger.info("Successfully compiled Metal library from source with required kernels")
        return library
      } else {
        logger.warning("Compiled Metal library is missing required kernels; discarding")
        return nil
      }
    } catch {
      logger.error("Failed to compile Metal library: \(error)")
      return nil
    }
  }

  /// Creates a minimal embedded Metal library for basic operations
  private static func createEmbeddedLibrary(device: MTLDevice) -> MTLLibrary? {
    let minimalMetalSource = """
      #include <metal_stdlib>
      using namespace metal;

      // Basic matrix multiplication kernel
      kernel void matmul(device const float* A,
                        device const float* B,
                        device float* C,
                        constant uint& M,
                        constant uint& N,
                        constant uint& K,
                        uint2 gid [[thread_position_in_grid]]) {
          uint row = gid.x;
          uint col = gid.y;
          
          if (row >= M || col >= N) return;
          
          float sum = 0.0f;
          for (uint k = 0; k < K; k++) {
              sum += A[row * K + k] * B[k * N + col];
          }
          C[row * N + col] = sum;
      }

      // Basic unary operations
      kernel void unary_add(device const float* input,
                           device float* output,
                           constant float& value,
                           uint gid [[thread_position_in_grid]]) {
          output[gid] = input[gid] + value;
      }

      kernel void unary_mul(device const float* input,
                           device float* output,
                           constant float& value,
                           uint gid [[thread_position_in_grid]]) {
          output[gid] = input[gid] * value;
      }
      """

    do {
      let library = try device.makeLibrary(source: minimalMetalSource, options: nil)
      if validateLibrary(library) {
        logger.info("Created minimal embedded Metal library")
        return library
      } else {
        logger.warning("Embedded Metal library missing required kernels; ignoring")
        return nil
      }
    } catch {
      logger.error("Failed to create embedded Metal library: \(error)")
      return nil
    }
  }

  /// Finds Metal source files in the MLX package
  private static func findMetalSourceFiles() -> [String] {
    let mlxPath = ".build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal"
    let examplesPath = ".build/checkouts/mlx-swift/Source/Cmlx/mlx/examples/extensions"

    var metalFiles: [String] = []

    // Find all .metal files
    let fileManager = FileManager.default
    let currentPath = fileManager.currentDirectoryPath

    // Search in mlx-generated/metal directory
    let mlxFullPath = "\(currentPath)/\(mlxPath)"
    if fileManager.fileExists(atPath: mlxFullPath) {
      metalFiles.append(contentsOf: findMetalFiles(in: mlxFullPath))
    }

    // Search in examples directory
    let examplesFullPath = "\(currentPath)/\(examplesPath)"
    if fileManager.fileExists(atPath: examplesFullPath) {
      metalFiles.append(contentsOf: findMetalFiles(in: examplesFullPath))
    }

    return metalFiles
  }

  /// Recursively finds .metal files in a directory
  private static func findMetalFiles(in directory: String) -> [String] {
    let fileManager = FileManager.default
    var metalFiles: [String] = []

    do {
      let contents = try fileManager.contentsOfDirectory(atPath: directory)

      for item in contents {
        let fullPath = "\(directory)/\(item)"
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
          if isDirectory.boolValue {
            metalFiles.append(contentsOf: findMetalFiles(in: fullPath))
          } else if item.hasSuffix(".metal") {
            metalFiles.append(fullPath)
          }
        }
      }
    } catch {
      logger.warning("Error searching directory \(directory): \(error)")
    }

    return metalFiles
  }

  /// Compiles a single Metal source file
  private static func compileMetalSource(_ filePath: String, device: MTLDevice) -> String? {
    do {
      let source = try String(contentsOfFile: filePath, encoding: .utf8)
      logger.info("Compiling: \(filePath)")
      return source
    } catch {
      logger.warning("Failed to read Metal source file \(filePath): \(error)")
      return nil
    }
  }

  /// Validates Metal library functionality
  public static func validateLibrary(_ library: MTLLibrary) -> Bool {
    // Check if essential functions are available
    let essentialFunctions = [
      "matmul",
      "unary_add",
      "unary_mul"
    ]

    var missing: [String] = []

    for functionName in essentialFunctions {
      if library.makeFunction(name: functionName) == nil {
        missing.append(functionName)
      }
    }

    let sdpaAttentionCandidates = [
      "sdpa_vector_float_80_80",
      "sdpa_vector_float_64_64",
      "sdpa_vector_float_96_96",
      "sdpa_vector_float_128_128",
      "sdpa_vector_float_256_256"
    ]

    let hasSupportedSDPA = sdpaAttentionCandidates.contains { candidate in
      library.makeFunction(name: candidate) != nil
    }

    if !hasSupportedSDPA {
      missing.append("sdpa_vector_* (supported variant)")
    }

    if !missing.isEmpty {
      logger.warning("Metal library is missing required functions: \(missing.joined(separator: ", "))")
      return false
    }

    logger.info("Metal library validation passed")
    return true
  }

  /// Gets Metal device information for diagnostics
  public static func getDeviceInfo() -> [String: Any] {
    guard let device = MTLCreateSystemDefaultDevice() else {
      return ["error": "No Metal device found"]
    }

    return [
      "name": device.name,
      "registryID": device.registryID,
      "maxThreadsPerThreadgroup": device.maxThreadsPerThreadgroup,
      "maxThreadgroupMemoryLength": device.maxThreadgroupMemoryLength,
      "hasUnifiedMemory": device.hasUnifiedMemory,
      "recommendedMaxWorkingSetSize": device.recommendedMaxWorkingSetSize,
      "maxBufferLength": device.maxBufferLength,
    ]
  }
}
