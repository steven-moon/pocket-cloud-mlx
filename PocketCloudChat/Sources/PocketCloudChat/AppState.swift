// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/AppState.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class AppState: ObservableObject {
//   - extension Notification.Name {
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
import Foundation
import PocketCloudMLX

@MainActor
class AppState: ObservableObject {
    // Default to hiding onboarding until we have real state
    @Published var showOnboarding: Bool = false
    @Published var isDeterminingOnboarding: Bool = true

    // Device compatibility tracking
    @Published var showCompatibilityWarning: Bool = false
    @Published var isDeviceCompatible: Bool = true
    @Published var deviceCompatibilityMessage: String = ""
    @Published var deviceModel: String = "Unknown"
    @Published var deviceChipInfo: String = "Unknown"

    init() {
        // Determine at startup whether we should show onboarding.
        // If there are downloaded models and onboarding was completed, skip onboarding.
        Task { @MainActor in
            defer { self.isDeterminingOnboarding = false }
            do {
                let downloaded = try await ModelDownloader().getDownloadedModels()
                let alreadyCompleted = UserDefaults.standard.bool(forKey: "onboarding_completed")
                if alreadyCompleted && !downloaded.isEmpty {
                    self.showOnboarding = false
                } else {
                    self.showOnboarding = true
                }
            } catch {
                // If detection fails, keep onboarding visible to guide the user.
                self.showOnboarding = true
            }
        }
    }

    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
    }

    func dismissCompatibilityWarning() {
        showCompatibilityWarning = false
    }
} 

extension Notification.Name {
    static let switchToChat = Notification.Name("SwitchToChatTab")
    static let activateModel = Notification.Name("ActivateModelFromHub")
    static let refreshDownloadedModels = Notification.Name("RefreshDownloadedModels")
}
