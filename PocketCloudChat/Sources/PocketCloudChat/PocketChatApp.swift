import SwiftUI
import PocketCloudUI
import PocketCloudLogger
import PocketCloudMLX

@main
struct PocketChatApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var styleManager = StyleManager()

    init() {
        AppLogger.shared.info("PocketChat", "🚀 Launching PocketChat")
        AppLogger.shared.debug("PocketChat", "🔧 Logging system initialized")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(styleManager)
                .background(styleManager.tokens.background.ignoresSafeArea())
                .tint(styleManager.tokens.accent)
                .preferredColorScheme(styleManager.preferredColorScheme)
                .onAppear {
                    refreshSystemAppearanceIfNeeded()
                }
                .task {
                    await checkDeviceCompatibility()
                    await ensureOnboardingIfNeeded()
                }
        }
        .defaultSize(width: 1100, height: 750)
    }

    private func refreshSystemAppearanceIfNeeded() {
        if styleManager.mode == .system {
            styleManager.refreshSystemAppearance()
        }
    }

    @MainActor
    private func checkDeviceCompatibility() async {
        let analyzer = DeviceAnalyzer()
        let isCompatible = analyzer.isMLXCompatible()
        let deviceInfo = analyzer.getDeviceInfo()

        appState.isDeviceCompatible = isCompatible
        appState.deviceModel = deviceInfo.model
        appState.deviceChipInfo = deviceInfo.chipInfo

        if !isCompatible {
            AppLogger.shared.warning("PocketChat", "⚠️ Device not compatible with MLX: \(deviceInfo.model) (\(deviceInfo.chipInfo))")
            appState.showCompatibilityWarning = true
            appState.deviceCompatibilityMessage = "Your device (\(deviceInfo.model) with \(deviceInfo.chipInfo)) does not support MLX. MLX requires Apple Silicon (A14+ or M1+)."
        } else {
            AppLogger.shared.info("PocketChat", "✅ Device is compatible with MLX: \(deviceInfo.model) (\(deviceInfo.chipInfo))")
        }
    }

    @MainActor
    private func ensureOnboardingIfNeeded() async {
        do {
            let downloaded = try await ModelDownloader().getDownloadedModels()
            if downloaded.isEmpty {
                AppLogger.shared.info("PocketChat", "🧭 No downloaded models found. Forcing onboarding.")
                appState.showOnboarding = true
            }
        } catch {
            AppLogger.shared.warning("PocketChat", "⚠️ Failed to check downloaded models: \(error.localizedDescription). Showing onboarding.")
            appState.showOnboarding = true
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var styleManager: StyleManager
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        ZStack {
            styleManager.tokens.background.ignoresSafeArea()

            if appState.isDeterminingOnboarding {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Preparing chat experience…")
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.showCompatibilityWarning {
                DeviceCompatibilityView(
                    deviceInfo: (appState.deviceModel, appState.deviceChipInfo)
                )
                .transition(.opacity)
            } else if appState.showOnboarding {
                OnboardingView(
                    isPresented: Binding(
                        get: { appState.showOnboarding },
                        set: { _ in appState.completeOnboarding() }
                    )
                )
                .environmentObject(styleManager)
                .transition(AnyTransition.opacity)
            } else {
                ContentView()
                    .environmentObject(styleManager)
                    .environmentObject(appState)
                    .transition(AnyTransition.opacity)
            }
        }
        .safeAreaInset(edge: .top) {
            if !appState.isDeviceCompatible && !appState.showCompatibilityWarning {
                CompatibilityWarningBanner(message: appState.deviceCompatibilityMessage)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            styleManager.updateSystemColorScheme(systemColorScheme)
            AppLogger.shared.debug("RootView", "🔍 showOnboarding = \(appState.showOnboarding), showCompatibilityWarning = \(appState.showCompatibilityWarning)")
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            guard styleManager.mode == .system else { return }
            styleManager.updateSystemColorScheme(newScheme)
        }
        .onChange(of: styleManager.mode) { _, _ in
            styleManager.updateSystemColorScheme(systemColorScheme)
        }
    }
}

private struct CompatibilityWarningBanner: View {
    @EnvironmentObject private var styleManager: StyleManager
    let message: String

    private var bannerMessage: String {
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Unsupported device detected. Not all features will be available."
        }
        return message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(styleManager.tokens.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Unsupported Device")
                    .font(styleManager.tokens.bodyFont.weight(.semibold))
                    .foregroundColor(styleManager.tokens.onBackground)

                Text(bannerMessage)
                    .font(styleManager.tokens.captionFont)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: styleManager.tokens.cornerRadius.lg)
                .fill(styleManager.tokens.surface.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: styleManager.tokens.cornerRadius.lg)
                .stroke(styleManager.tokens.warning.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: styleManager.tokens.warning.opacity(0.18), radius: 12, y: 6)
    }
}
