// == LLM Context: Bread Crumbs ==
// Module        : Workspace
// File          : pocket-cloud-mlx/Tests/PocketCloudMLXTests/ModelManagerTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ModelManagerTests: XCTestCase {
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
import XCTest

@testable import PocketCloudMLX

final class ModelManagerTests: XCTestCase {
  var fileManagerService: FileManagerService!

  override func setUp() {
    super.setUp()
    fileManagerService = FileManagerService.shared
  }

  override func tearDown() {
    fileManagerService = nil
    super.tearDown()
  }

  func testGetModelsDirectory() throws {
    // Just test that we can get the models directory without errors
    let directory = try fileManagerService.getModelsDirectory()
    XCTAssertNotNil(directory, "Directory should not be nil")

    // Test that it's a valid URL
    XCTAssertTrue(directory.isFileURL, "Should be a file URL")

    // Test that the directory exists
    XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path),
                  "Directory should exist after getModelsDirectory()")
  }

  func testModelsDirectoryExists() throws {
    let modelsDirectory = try fileManagerService.getModelsDirectory()
    XCTAssertTrue(FileManager.default.fileExists(atPath: modelsDirectory.path))
  }

  func testDeleteModel() throws {
    let modelsDirectory = try fileManagerService.getModelsDirectory()
    let testModelDirectory = modelsDirectory.appendingPathComponent("test-model")
    try FileManager.default.createDirectory(
      at: testModelDirectory, withIntermediateDirectories: true)
    XCTAssertTrue(FileManager.default.fileExists(atPath: testModelDirectory.path))
    try fileManagerService.deleteModel(at: testModelDirectory)
    XCTAssertFalse(FileManager.default.fileExists(atPath: testModelDirectory.path))
  }

  // Note: ModelConfiguration tests moved to ModelConfigurationTests.swift
  // Note: Download tests moved to ModelDownloadConsolidatedTests.swift
}
