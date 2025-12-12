// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/DeviceCompatibilityView.swift
// Purpose       : Display device compatibility warning for devices that don't support MLX
//
// Key Types in this file:
//   - struct DeviceCompatibilityView: View {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//
// Related Files:
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/ModelRecommendation.swift (DeviceAnalyzer)
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/AppState.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import SwiftUI
import PocketCloudUI

/// View displayed when device doesn't support MLX framework
struct DeviceCompatibilityView: View {
    @EnvironmentObject var styleManager: StyleManager
    @EnvironmentObject var appState: AppState

    let deviceInfo: (model: String, chipInfo: String)

    var body: some View {
        ZStack {
            styleManager.tokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Warning Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(styleManager.tokens.warning)
                    .padding(.bottom, 32)

                // Title
                Text("Device Not Compatible")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(styleManager.tokens.onBackground)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                // Subtitle
                Text("MLX Engine requires Apple Silicon")
                    .font(.title3)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // Device Info Card
                VStack(alignment: .leading, spacing: 16) {
                    // Current Device Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Device")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                            .textCase(.uppercase)

                        HStack {
                            Image(systemName: "iphone")
                                .foregroundColor(styleManager.tokens.error)
                            Text(deviceInfo.model)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(styleManager.tokens.onBackground)
                        }

                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(styleManager.tokens.error)
                            Text(deviceInfo.chipInfo)
                                .font(.body)
                                .foregroundColor(styleManager.tokens.onBackground)
                        }
                    }
                    .padding(.bottom, 8)

                    Divider()
                        .background(styleManager.tokens.secondaryForeground.opacity(0.3))

                    // Required Specs Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Required")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                            .textCase(.uppercase)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(styleManager.tokens.success)
                            Text("Apple Silicon Chip")
                                .font(.body)
                                .foregroundColor(styleManager.tokens.onBackground)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(styleManager.tokens.success)
                                Text("Compatible Devices:")
                                    .font(.body)
                                    .foregroundColor(styleManager.tokens.onBackground)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                bulletPoint("iPhone 12 or newer (A14+)")
                                bulletPoint("iPad with M1/M2/M3/M4")
                                bulletPoint("iPad Pro 2021 or newer")
                                bulletPoint("iPad Air 2022 or newer")
                                bulletPoint("iPad mini 2021 or newer")
                                bulletPoint("Mac with M1/M2/M3/M4")
                            }
                            .padding(.leading, 28)
                        }
                    }
                }
                .padding(24)
                .background(styleManager.tokens.surface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(styleManager.tokens.secondaryForeground.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // Info Text
                Text("The MLX framework requires Apple Silicon processors to run machine learning models efficiently. Your device does not have the required hardware.")
                    .font(.body)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // Dismiss Button
                Button(action: {
                    appState.dismissCompatibilityWarning()
                }) {
                    Text("I Understand")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(styleManager.tokens.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Additional Help Text
                Text("The app may crash when attempting to load models on incompatible devices.")
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 80)
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("•")
                .font(.body)
                .foregroundColor(styleManager.tokens.secondaryForeground)
            Text(text)
                .font(.caption)
                .foregroundColor(styleManager.tokens.secondaryForeground)
        }
    }
}

#Preview {
    DeviceCompatibilityView(deviceInfo: ("iPad Pro", "A12X Bionic"))
        .environmentObject(StyleManager())
        .environmentObject(AppState())
}
