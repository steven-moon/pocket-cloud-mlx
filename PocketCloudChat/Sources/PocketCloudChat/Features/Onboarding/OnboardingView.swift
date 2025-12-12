// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/OnboardingView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct OnboardingView: View {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/ModelRecommendation.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/OnboardingStepView.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/ModelSetupView.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import SwiftUI
import PocketCloudMLX
import PocketCloudLogger

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var showingModelSelection = false
    @State private var selectedModel: String = ""
    // Temporary style selections bound to the picker
    @State private var tempStyle: AppStyle = .modern
    @State private var tempThemeMode: ThemeMode = .system
    @Binding var isPresented: Bool
    @EnvironmentObject var styleManager: StyleManager

    private static let logger = Logger(label: "OnboardingView")

    private let steps = [
        "Welcome to MLX Chat",
        "Choose Your Style",
        "Select Your Model",
        "You're All Set!"
    ]
    
    var body: some View {
        #if os(macOS)
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced progress indicator
                VStack(spacing: 16) {
                    HStack {
                            ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentStep ? styleManager.tokens.accent : styleManager.tokens.secondary.opacity(0.3))
                                .frame(width: 12, height: 12)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                            
                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(index < currentStep ? styleManager.tokens.accent : styleManager.tokens.secondary.opacity(0.3))
                                    .frame(height: 2)
                                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Text("Step \(currentStep + 1) of \(steps.count)")
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                }
                .padding(.vertical, 24)
                .background(styleManager.tokens.surface)
                
                // Main content
                ScrollView {
                    VStack(spacing: 32) {
                        // Title
                        Text(steps[currentStep])
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(styleManager.tokens.onBackground)
                            .multilineTextAlignment(.center)
                            .padding(.top, 32)
                        
                        // Step content
                        Group {
                            switch currentStep {
                            case 0:
                                welcomeStep
                            case 1:
                                styleSelectionStep
                            case 2:
                                modelSelectionStep
                            case 3:
                                completionStep
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .background(styleManager.tokens.background)
                
                // Navigation buttons (hidden on model step to allow child's pinned bar)
                if currentStep != 2 {
                    HStack(spacing: 16) {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation(.easeInOut(duration: 0.3)) { currentStep -= 1 }
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(styleManager.tokens.accent)
                        }
                        Spacer()
                        Button(currentStep < steps.count - 1 ? "Next" : "Get Started") {
                            if currentStep < steps.count - 1 {
                                withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
                            } else {
                                isPresented = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                    .background(styleManager.tokens.surface)
                }
            }
        }
        .background(styleManager.tokens.background.ignoresSafeArea())
        #else
        // iOS: Full screen onboarding without NavigationView constraints
        VStack(spacing: 0) {
            // Enhanced progress indicator
            VStack(spacing: 16) {
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? styleManager.tokens.accent : styleManager.tokens.secondary.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                        
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? styleManager.tokens.accent : styleManager.tokens.secondary.opacity(0.3))
                                .frame(height: 2)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Text("Step \(currentStep + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(styleManager.tokens.surface)
            
            // Main content - full width
            ScrollView {
                VStack(spacing: 32) {
                    // Title
                    Text(steps[currentStep])
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(styleManager.tokens.onBackground)
                        .multilineTextAlignment(.center)
                        .padding(.top, 32)
                    
                    // Step content
                    Group {
                        switch currentStep {
                        case 0:
                            welcomeStep
                        case 1:
                            styleSelectionStep
                        case 2:
                            modelSelectionStep
                        case 3:
                            completionStep
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity) // Force full width
                }
            }
            .background(styleManager.tokens.background)
            .frame(maxWidth: .infinity) // Force full width
            
            // Navigation buttons (hidden on model step to allow child's pinned bar)
            if currentStep != 2 {
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(styleManager.tokens.accent)
                    }
                    
                    Spacer()
                    
                    Button(currentStep < steps.count - 1 ? "Next" : "Get Started") {
                        if currentStep < steps.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } else {
                            isPresented = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentStep == 2 && selectedModel.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(styleManager.tokens.surface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Force full screen
        .background(styleManager.tokens.background.ignoresSafeArea())
        #endif
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            // App icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                styleManager.tokens.accent.opacity(0.3),
                                styleManager.tokens.secondary.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: styleManager.tokens.accent.opacity(0.2), radius: 20, x: 0, y: 10)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(styleManager.tokens.accent)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to MLX Chat")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(styleManager.tokens.onBackground)
                    .multilineTextAlignment(.center)
                
                Text("Your AI assistant powered by Apple's MLX framework. Experience local, private, and powerful AI conversations.")
                    .font(.body)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Feature highlights
            VStack(spacing: 16) {
                featureRow("🔒", "Private", "All processing happens locally on your device")
                featureRow("⚡", "Fast", "Optimized for Apple Silicon performance")
                featureRow("🎨", "Beautiful", "Customize your experience with multiple themes")
            }
        }
    }
    
        private var styleSelectionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(styleManager.tokens.accent)

                Text("Choose how MLX Chat looks and feels")
                    .font(.body)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
            }

            // Sophisticated style picker with visual previews
            stylePickerContent()
                .padding(20)
                .background(styleManager.tokens.surface)
                .cornerRadius(20)
                .shadow(color: styleManager.tokens.accent.opacity(0.1), radius: 12, x: 0, y: 4)
        }
    }

    private func stylePickerContent() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            styleGridSection()
            colorSchemeSection()
        }
    }

    private func styleGridSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Branding Style")
                .font(.subheadline.bold())
                .foregroundColor(styleManager.tokens.onBackground)

            let columns = [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AppStyle.allCases, id: \.self) { style in
                    styleButton(for: style)
                }
            }
        }
    }

    private func styleButton(for style: AppStyle) -> some View {
        let isSelected = tempStyle == style
        return Button(action: {
            tempStyle = style
            styleManager.setStyle(style)
        }) {
            stylePreviewCard(for: style, isSelected: isSelected)
                .frame(width: 140, height: 80)
        }
        .buttonStyle(.plain)
    }

    private func colorSchemeSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Scheme")
                .font(.subheadline.bold())
                .foregroundColor(styleManager.tokens.onBackground)

            VStack(spacing: 12) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    colorSchemeButton(for: mode)
                }
            }
        }
    }

    private func colorSchemeButton(for mode: ThemeMode) -> some View {
        let isSelected = tempThemeMode == mode
        return Button(action: {
            tempThemeMode = mode
            styleManager.setMode(mode)
        }) {
            HStack(alignment: .center, spacing: 16) {
                colorSchemeSwatch(for: mode, isSelected: isSelected)
                    .frame(width: 28, height: 28)

                Text(mode.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(styleManager.tokens.onBackground)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(styleManager.tokens.accent)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isSelected ? styleManager.tokens.accent.opacity(0.08) : styleManager.tokens.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? styleManager.tokens.accent.opacity(0.3) : styleManager.tokens.borderColor.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Style Preview Components

    private func stylePreviewCard(for style: AppStyle, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                let previewTokens = previewTokens(for: style, mode: tempThemeMode)

                RoundedRectangle(cornerRadius: 16)
                    .fill(previewTokens.background)
                    .frame(height: 50)
                    .shadow(color: isSelected ? styleManager.tokens.accent.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
                    .overlay(
                        VStack(spacing: 4) {
                            // Header bar
                            Rectangle()
                                .fill(previewTokens.accent)
                                .frame(height: 8)
                                .cornerRadius(4)

                            // Content preview
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(previewTokens.secondary)
                                    .frame(width: 12, height: 12)

                                Rectangle()
                                    .fill(previewTokens.onBackground.opacity(0.3))
                                    .frame(height: 4)
                                    .cornerRadius(2)

                                Rectangle()
                                    .fill(previewTokens.onBackground.opacity(0.2))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                    .frame(maxWidth: 20)
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(6)
                    )

                // Selection indicator
                if isSelected {
                    Circle()
                        .fill(styleManager.tokens.accent)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 8, y: -8)
                }
            }

            Text(style.rawValue.capitalized)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? styleManager.tokens.accent : styleManager.tokens.onBackground)
                .lineLimit(1)
        }
    }

    private func colorSchemeSwatch(for mode: ThemeMode, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(mode == .dark ? Color.black : Color.white)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            // Mini preview of colors
            VStack(spacing: 1) {
                Rectangle()
                    .fill(mode == .dark ? styleManager.tokens.accent.opacity(0.8) : styleManager.tokens.primary.opacity(0.8))
                    .frame(height: 4)

                HStack(spacing: 1) {
                    Rectangle()
                        .fill(mode == .dark ? styleManager.tokens.secondary.opacity(0.6) : styleManager.tokens.surface.opacity(0.8))
                        .frame(width: 8, height: 3)

                    Rectangle()
                        .fill(mode == .dark ? styleManager.tokens.onBackground.opacity(0.4) : styleManager.tokens.onBackground.opacity(0.6))
                        .frame(width: 8, height: 3)
                }
            }
            .padding(2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? styleManager.tokens.accent : Color.clear, lineWidth: 2)
                .padding(-2)
        )
    }

    private func previewTokens(for style: AppStyle, mode: ThemeMode) -> ThemeTokens {
        // Generate preview tokens based on style and mode
        switch (style, mode) {
        case (.minimal, .dark):
            return ThemeTokens(
                background: Color.white.opacity(0.95),
                surface: Color.gray.opacity(0.1),
                primary: .blue,
                secondary: Color(.systemGray),
                accent: .blue,
                error: .red,
                success: .green,
                warning: .orange,
                info: .blue,
                onPrimary: .white,
                onSecondary: .white,
                onBackground: .white,
                onSurface: .white,
                secondaryForeground: .white
            )
        case (.vibrant, _):
            return ThemeTokens(
                background: Color.white.opacity(0.95),
                surface: Color.gray.opacity(0.1),
                primary: .purple,
                secondary: .orange,
                accent: .purple,
                error: .red,
                success: .green,
                warning: .orange,
                info: .purple,
                onPrimary: .white,
                onSecondary: .white,
                onBackground: .primary,
                onSurface: .primary,
                secondaryForeground: .white
            )
        default:
            return styleManager.tokens
        }
    }
    
    private var modelSelectionStep: some View {
        ModelSetupView(onContinue: {
            isPresented = false
            // Persist onboarding completion
            AppState().completeOnboarding()
        })
            .environmentObject(styleManager)
        .onAppear {
            Self.logger.debug("🔍 OnboardingView appeared, currentStep = \(currentStep)")
        }
    }
    
    private var completionStep: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .green.opacity(0.3),
                                .green.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .green.opacity(0.2), radius: 20, x: 0, y: 10)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 16) {
                Text("Perfect! You're all set up and ready to start chatting with your AI assistant.")
                    .font(.body)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
                
                if !selectedModel.isEmpty {
                    VStack(spacing: 8) {
                        Text("Selected Configuration:")
                            .font(.caption)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                        
                        HStack {
                            Text("Model: \(selectedModel)")
                            Spacer()
                            Text("Style: \(styleManager.style.rawValue.capitalized)")
                        }
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.onSurface)
                        .padding(12)
                        .background(styleManager.tokens.surface)
                        .cornerRadius(8)
                    }
                }
            }
            
            VStack(spacing: 12) {
                Text("What's Next?")
                    .font(.headline)
                    .foregroundColor(styleManager.tokens.onBackground)
                
                VStack(spacing: 8) {
                    nextStepRow("💬", "Start a conversation")
                    nextStepRow("📄", "Upload documents for analysis")
                    nextStepRow("🎨", "Customize your theme anytime in Settings")
                }
            }
        }
    }
    
    private func featureRow(_ icon: String, _ title: String, _ description: String) -> some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(styleManager.tokens.onBackground)
                Text(description)
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
            }
            
            Spacer()
        }
        .padding(12)
        .background(styleManager.tokens.surface)
        .cornerRadius(8)
    }
    
    private func nextStepRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 16))
            Text(title)
                .font(.subheadline)
                .foregroundColor(styleManager.tokens.onBackground)
            Spacer()
        }
    }
    
    private var availableModels: [String] {
        return [
            "Llama 3.2 3B",
            "Llama 3.1 8B", 
            "Mistral 7B",
            "Qwen 2.5 7B"
        ]
    }
    
    private func modelDescription(for model: String) -> String {
        switch model {
        case "Llama 3.2 3B":
            return "Fast and efficient • 2.1 GB • Recommended for mobile"
        case "Llama 3.1 8B":
            return "Balanced performance • 4.8 GB • Great for most tasks"
        case "Mistral 7B":
            return "Creative and analytical • 4.1 GB • Excellent for writing"
        case "Qwen 2.5 7B":
            return "Versatile and smart • 4.3 GB • Good all-around choice"
        default:
            return "Advanced AI model"
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .environmentObject(StyleManager())
} 