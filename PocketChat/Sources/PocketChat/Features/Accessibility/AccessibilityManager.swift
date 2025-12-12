// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Accessibility/AccessibilityManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class AccessibilityManager: ObservableObject {
//   - enum AccessibilityElement {
//   - enum AccessibilityMessageRole {
//   - struct AccessibilityAuditResult: Identifiable {
//   - extension View {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):

//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import SwiftUI

/// Manages accessibility features and provides accessibility utilities
@MainActor
public class AccessibilityManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isReduceMotionEnabled: Bool = false
    @Published public var isHighContrastEnabled: Bool = false
    @Published public var isDynamicTypeEnabled: Bool = true
    @Published public var accessibilityAuditResults: [AccessibilityAuditResult] = []
    
    // MARK: - Initialization
    
    public init() {
        updateAccessibilityStatus()
    }
    
    // MARK: - Public Methods
    
    /// Update accessibility settings based on system preferences
    public func updateAccessibilityStatus() {
        // These will be updated through environment values in SwiftUI
        isDynamicTypeEnabled = true
    }
    
    /// Get accessibility label for a given element
    public func accessibilityLabel(for element: AccessibilityElement) -> String {
        switch element {
        case .chatMessage(let role, let content):
            return "\(role == .user ? "You said" : "Assistant replied"): \(content)"
        case .sendButton(let isEmpty):
            return isEmpty ? "Send button, disabled" : "Send message"
        case .modelCard(let name, let parameters):
            return "Model: \(name), Parameters: \(parameters ?? "unknown")"
        case .documentPicker:
            return "Document picker, tap to select files"
        case .styleSelector(let styleName):
            return "Style: \(styleName), double tap to select"
        case .progressBar(let progress):
            return "Download progress: \(Int(progress * 100)) percent"
        }
    }
    
    /// Get accessibility hint for a given element
    public func accessibilityHint(for element: AccessibilityElement) -> String? {
        switch element {
        case .chatMessage:
            return "Double tap to copy message"
        case .sendButton(let isEmpty):
            return isEmpty ? "Enter text to enable sending" : "Double tap to send message"
        case .modelCard:
            return "Double tap to view model details"
        case .documentPicker:
            return "Double tap to open document picker"
        case .styleSelector:
            return "Double tap to change app appearance"
        case .progressBar:
            return nil
        }
    }
    
    /// Get accessibility value for a given element
    public func accessibilityValue(for element: AccessibilityElement) -> String? {
        switch element {
        case .progressBar(let progress):
            return "\(Int(progress * 100)) percent"
        case .styleSelector(let styleName):
            return "Selected: \(styleName)"
        default:
            return nil
        }
    }
    
    /// Get scaled font size based on accessibility settings
    public func scaledFontSize(for baseSize: CGFloat) -> CGFloat {
        // Simple scaling for accessibility
        return baseSize * (isDynamicTypeEnabled ? 1.2 : 1.0)
    }
    
    /// Get appropriate color contrast based on accessibility settings
    public func adjustedColor(_ color: Color, for background: Color) -> Color {
        guard isHighContrastEnabled else { return color }
        
        // Increase contrast for better accessibility
        return color.opacity(0.9)
    }
    
    /// Perform accessibility audit on the current interface
    public func performAccessibilityAudit() {
        var results: [AccessibilityAuditResult] = []
        
        // Check for common accessibility issues
        if !isDynamicTypeEnabled {
            results.append(AccessibilityAuditResult(
                severity: .warning,
                title: "Dynamic Type Disabled",
                description: "Text may not scale properly for users with vision impairments",
                recommendation: "Enable Dynamic Type support in your text views"
            ))
        }
        
        if isHighContrastEnabled {
            results.append(AccessibilityAuditResult(
                severity: .info,
                title: "High Contrast Mode Active",
                description: "User prefers high contrast for better visibility",
                recommendation: "Ensure all UI elements have sufficient contrast"
            ))
        }
        
        if isReduceMotionEnabled {
            results.append(AccessibilityAuditResult(
                severity: .info,
                title: "Reduce Motion Enabled",
                description: "User prefers minimal animations",
                recommendation: "Disable or reduce animations when possible"
            ))
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.accessibilityAuditResults = results
        }
    }
    
    /// Get accessibility-friendly animation duration
    public func animationDuration(base: Double = 0.3) -> Double {
        return isReduceMotionEnabled ? 0.0 : base
    }
    
    /// Get accessibility-friendly animation
    public func accessibilityFriendlyAnimation<V: Equatable>(_ animation: Animation, value: V) -> Animation? {
        return isReduceMotionEnabled ? nil : animation
    }
}

// MARK: - Accessibility Element Types

public enum AccessibilityElement {
    case chatMessage(role: AccessibilityMessageRole, content: String)
    case sendButton(isEmpty: Bool)
    case modelCard(name: String, parameters: String?)
    case documentPicker
    case styleSelector(styleName: String)
    case progressBar(progress: Double)
}

// Simple MessageRole enum for accessibility - compatible with main ChatEngine.MessageRole
public enum AccessibilityMessageRole {
    case user
    case assistant
    case system
}

// MARK: - Accessibility Audit Results

public struct AccessibilityAuditResult: Identifiable {
    public let id = UUID()
    public let severity: Severity
    public let title: String
    public let description: String
    public let recommendation: String
    
    public enum Severity {
        case error, warning, info
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
}

// MARK: - Accessibility Modifiers

public extension View {
    /// Add comprehensive accessibility support to a view
    func accessibilityEnhanced(
        _ element: AccessibilityElement,
        manager: AccessibilityManager
    ) -> some View {
        var view = self.accessibilityLabel(manager.accessibilityLabel(for: element))
        
        if let hint = manager.accessibilityHint(for: element) {
            view = view.accessibilityHint(hint)
        }
        
        if let value = manager.accessibilityValue(for: element) {
            view = view.accessibilityValue(value)
        }
        
        return view
    }
    
    /// Apply Dynamic Type scaling to text
    func dynamicTypeScaled(_ accessibilityManager: AccessibilityManager) -> some View {
        self.scaleEffect(
            accessibilityManager.isDynamicTypeEnabled ? 1.2 : 1.0,
            anchor: .topLeading
        )
    }
    
    /// Apply reduce motion friendly animations
    func reduceMotionFriendly<V: Equatable>(
        _ animation: Animation,
        value: V,
        manager: AccessibilityManager
    ) -> some View {
        self.animation(
            manager.accessibilityFriendlyAnimation(animation, value: value),
            value: value
        )
    }
    
    /// Apply high contrast adjustments
    func highContrastAdjusted(
        foreground: Color,
        background: Color,
        manager: AccessibilityManager
    ) -> some View {
        self
            .foregroundColor(manager.adjustedColor(foreground, for: background))
            .background(manager.isHighContrastEnabled ? background.opacity(0.9) : background)
    }
} 