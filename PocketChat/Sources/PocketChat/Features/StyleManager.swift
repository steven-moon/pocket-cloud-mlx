// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/StyleManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - typealias AppStyle = AIDevSwiftUIKit.AppStyle
//   - typealias ThemeMode = AIDevSwiftUIKit.ThemeMode
//   - typealias ThemeTokens = AIDevSwiftUIKit.ThemeTokens
//   - typealias StyleManager = AIDevSwiftUIKit.StyleManager
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - swift-uikit/Sources/SwiftUIKit/UIAIStyleManager.swift
//   - swift-uikit/Sources/SwiftUIKit/UIAIStyle.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import SwiftUI
import AIDevSwiftUIKit

// MARK: - Re-export SwiftUIKit Styling Types

public typealias AppStyle = AIDevSwiftUIKit.AppStyle
public typealias ThemeMode = AIDevSwiftUIKit.ThemeMode
public typealias ThemeTokens = AIDevSwiftUIKit.ThemeTokens
public typealias StyleManager = AIDevSwiftUIKit.StyleManager

// MARK: - Compatibility Extensions

extension ThemeTokens {
    /// Legacy alias used by existing MLXChatApp views for border strokes.
    public var borderColor: Color { outline }
    /// Legacy alias used by older components for button foregrounds.
    public var primaryForeground: Color { onPrimary }
}

extension StyleManager {
    /// Legacy helper retained for backwards compatibility with older views.
    public func setAccentColor(_ color: Color) {
        setCustomAccent(color)
    }
    /// Legacy helper retained so existing reset calls keep functioning.
    public func resetAccentToSystem() {
        useSystemAccent = true
    }
}

extension ThemeMode {
    /// Human-readable display name retained for existing UI copy.
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
