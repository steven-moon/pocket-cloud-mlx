// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HubApi+default.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - extension HubApi {
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
//
//  HubApi+default.swift
//  PocketCloudMLX
//
//  Created by PocketCloudMLX
//

import Foundation
@preconcurrency import Hub

/// Extension providing a default HubApi instance for downloading model files
/// This follows the official MLX Chat Example pattern and supports all platforms
extension HubApi {
    /// Default HubApi instance configured to download models to the user's Downloads directory
    /// under a 'huggingface' subdirectory, matching the MLX Chat Example pattern exactly.
    /// Automatically retrieves and uses the HuggingFace token from secure storage.
    static var `default`: HubApi {
        // Retrieve the HuggingFace token from secure storage (dynamic)
        let token = HuggingFaceAPI_Client.shared.loadHuggingFaceToken()
        
        // Debug logging
        if let token = token {
            print("🔑 HubApi.default: Token loaded successfully, length: \(token.count)")
            print("🔑 HubApi.default: Token prefix: \(String(token.prefix(10)))...")
        } else {
            print("❌ HubApi.default: No token found!")
        }
        
        // Use the standard Hugging Face cache path used by MLX examples:
        // ~/.cache/huggingface/hub
        let home = FileManager.default.mlxUserHomeDirectory
        let base = home
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub", isDirectory: true)

        let hubApi = HubApi(
            downloadBase: base,
            hfToken: token
        )
        print("🔑 HubApi.default: Created HubApi with base=\(base.path) token: \(token != nil ? "YES" : "NO")")
        return hubApi
    }
}
