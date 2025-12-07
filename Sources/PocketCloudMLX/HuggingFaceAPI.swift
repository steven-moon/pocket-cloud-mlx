// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFaceAPI.swift
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
// MARK: - Legacy Compatibility Layer

// This file serves as a compatibility layer for backward compatibility.
// The actual implementation has been refactored into smaller modules:
// - HuggingFace_API.swift
// - HuggingFace_Models.swift
// - HuggingFace_Errors.swift
// - HuggingFace_Compatibility.swift

// Re-export the main API client for backward compatibility
public typealias HuggingFaceAPI = HuggingFaceAPI_Client
public typealias HuggingFaceModel = HuggingFaceModel_Data
public typealias HuggingFaceError = HuggingFaceError_Type
public typealias DeviceAnalyzer = DeviceCompatibilityAnalyzer
public typealias DeviceCategory = DeviceCompatibilityCategory