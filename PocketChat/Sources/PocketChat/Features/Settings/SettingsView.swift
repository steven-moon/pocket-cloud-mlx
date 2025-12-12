// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Settings/SettingsView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct SettingsView: View {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Settings/EnhancedAppearanceSettingsView.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import SwiftUI


/// Central Settings hub
struct SettingsView: View {
    @EnvironmentObject private var styleManager: StyleManager
    @EnvironmentObject private var appState: AppState
    
    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
    
    var body: some View {
        content
    }
    
    private var content: some View {
        List {
            Section(header: Text("General").foregroundColor(styleManager.tokens.secondaryForeground)) {
                HStack {
                    Text("Version")
                        .foregroundColor(styleManager.tokens.onSurface)
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                }
            }
            
            Section(header: Text("Personalization").foregroundColor(styleManager.tokens.secondaryForeground)) {
                NavigationLink(destination: EnhancedAppearanceSettingsView().environmentObject(styleManager)) {
                    Label("Appearance", systemImage: "paintbrush")
                        .foregroundColor(styleManager.tokens.onSurface)
                }
            }
            
            Section(header: Text("Onboarding").foregroundColor(styleManager.tokens.secondaryForeground)) {
                Button(action: redoOnboarding) {
                    Label("Redo Onboarding", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundColor(styleManager.tokens.accent)
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .background(styleManager.tokens.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }
    
    private func redoOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboarding_completed")
        DispatchQueue.main.async {
            appState.showOnboarding = true
        }
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .environmentObject(StyleManager())
        .environmentObject(AppState())
}
#endif


