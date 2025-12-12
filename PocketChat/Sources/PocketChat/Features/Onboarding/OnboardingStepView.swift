// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/OnboardingStepView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct OnboardingStepView: View {
//   - struct PersonalizationStepView: View {
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

/// Standard onboarding step view with consistent layout
struct OnboardingStepView: View {
    let title: String
    let subtitle: String
    let imageName: String
    let buttonText: String
    let buttonAction: () -> Void
    
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack(spacing: 48) {
            // Icon
            Image(systemName: imageName)
                .font(.system(size: 120))
                .foregroundColor(styleManager.tokens.accent)
                .padding(.top, 80)
            
            // Content
            VStack(spacing: 24) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(styleManager.tokens.onBackground)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.title3)
                    .foregroundColor(styleManager.tokens.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Spacer()
            
            // Button
            Button(action: buttonAction) {
                Text(buttonText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(styleManager.tokens.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding(24)
        .background(styleManager.tokens.background)
    }
}

/// Personalization step view with style options
struct PersonalizationStepView: View {
    @Binding var tempStyle: AppStyle
    @Binding var tempMode: ThemeMode
    let buttonText: String
    let buttonAction: () -> Void
    
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack(spacing: 48) {
            // Header
            VStack(spacing: 24) {
                Image(systemName: "palette")
                    .font(.system(size: 120))
                    .foregroundColor(styleManager.tokens.accent)
                    .padding(.top, 80)
                
                Text("Choose Your Style")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(styleManager.tokens.onBackground)
                    .multilineTextAlignment(.center)
                
                Text("Personalize your chat experience")
                    .font(.title3)
                    .foregroundColor(styleManager.tokens.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Style options
            VStack(spacing: 32) {
                // Color scheme selection
                VStack(spacing: 16) {
                    Text("Color Scheme")
                        .font(.headline)
                        .foregroundColor(styleManager.tokens.onBackground)
                    
                    HStack(spacing: 20) {
                        colorOptionCard(mode: .light)
                        colorOptionCard(mode: .dark)
                    }
                }
                
                // Style kind selection
                VStack(spacing: 16) {
                    Text("Style Theme")
                        .font(.headline)
                        .foregroundColor(styleManager.tokens.onBackground)
                    
                    HStack(spacing: 20) {
                        styleOptionCard(style: .modern)
                        styleOptionCard(style: .glass)
                    }
                }
            }
            
            Spacer()
            
            // Button
            Button(action: buttonAction) {
                Text(buttonText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(styleManager.tokens.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding(24)
        .background(styleManager.tokens.background)
    }
    
    private func colorOptionCard(mode: ThemeMode) -> some View {
        let isSelected = tempMode == mode
        
        return Button(action: {
            tempMode = mode
        }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(mode == .dark ? Color.black : Color.white)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(mode == .dark ? Color.white : Color.black, lineWidth: 1)
                    )
                    .overlay(
                        VStack(spacing: 4) {
                            Circle()
                                .fill(mode == .dark ? Color.white : Color.black)
                                .frame(width: 16, height: 16)
                            Rectangle()
                                .fill(mode == .dark ? Color.white : Color.black)
                                .frame(width: 32, height: 4)
                                .cornerRadius(2)
                        }
                    )
                
                Text(mode.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(isSelected ? styleManager.tokens.accent : styleManager.tokens.onBackground)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .frame(width: 80)
            .padding(8)
            .background(isSelected ? styleManager.tokens.accent.opacity(0.1) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func styleOptionCard(style: AppStyle) -> some View {
        let isSelected = tempStyle == style
        // Use the current styleManager tokens for preview since we don't have ThemeRegistry
        let previewTokens = styleManager.tokens
        
        return Button(action: {
            tempStyle = style
        }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(previewTokens.background)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(previewTokens.accent, lineWidth: 2)
                    )
                    .overlay(
                        VStack(spacing: 4) {
                            Circle()
                                .fill(previewTokens.accent)
                                .frame(width: 16, height: 16)
                            Rectangle()
                                .fill(previewTokens.onBackground)
                                .frame(width: 32, height: 4)
                                .cornerRadius(2)
                        }
                    )
                
                Text(style.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(isSelected ? styleManager.tokens.accent : styleManager.tokens.onBackground)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .frame(width: 80)
            .padding(8)
            .background(isSelected ? styleManager.tokens.accent.opacity(0.1) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
} 