// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Settings/EnhancedAppearanceSettingsView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct EnhancedAppearanceSettingsView: View {
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
import Combine



struct EnhancedAppearanceSettingsView: View {
    @EnvironmentObject private var styleManager: StyleManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedStyle: AppStyle = .minimal
    @State private var selectedMode: ThemeMode = .system
    @State private var showingAdvancedSettings = false
    @State private var previewText = "The quick brown fox jumps over the lazy dog."
    @State private var animationDuration: Double = 0.3
    @State private var enableAnimations = true
    @State private var highContrastMode = false
    @State private var reducedMotion = false
    @State private var customAccentColor = Color.blue
    @State private var useSystemAccent = true
    @State private var showingColorPicker = false
    @State private var initialStyle: AppStyle = .minimal
    @State private var initialMode: ThemeMode = .system
    @State private var initialUseSystemAccent = true
    @State private var initialCustomAccent = Color.blue
    @State private var didLoadInitialValues = false
    
    // Device detection for adaptive layout
    private var isLargeScreen: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    private var adaptivePadding: CGFloat {
        isLargeScreen ? 32 : 16
    }
    
    private var adaptiveSpacing: CGFloat {
        isLargeScreen ? 48 : 32
    }
    
    var body: some View { mainContent }
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: adaptiveSpacing) {
                // Hero section
                heroSection
                
                // Style selection
                styleSelectionSection
                
                // Theme mode selection
                themeModeSection
                
                // Preview section
                previewSection
                
                // Advanced settings
                advancedSettingsSection
                
                // Accent color control
                accentSection
                
                // Accessibility options
                accessibilitySection
                
                // Performance metrics
                performanceSection
            }
            .padding(.horizontal, adaptivePadding)
            .padding(.vertical, isLargeScreen ? 24 : 16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    styleManager.tokens.background,
                    styleManager.tokens.surface.opacity(0.3),
                    styleManager.tokens.secondary.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Appearance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    restoreInitialSelections()
                    dismiss()
                }
                    .foregroundColor(styleManager.tokens.accent)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    applySettings()
                    dismiss()
                }
                .foregroundColor(styleManager.tokens.accent)
                .fontWeight(.semibold)
            }
        }
        #elseif os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Cancel") {
                    restoreInitialSelections()
                    dismiss()
                }
                    .foregroundColor(styleManager.tokens.accent)
            }
            ToolbarItem(placement: .automatic) {
                Button("Done") {
                    applySettings()
                    dismiss()
                }
                .foregroundColor(styleManager.tokens.accent)
                .fontWeight(.semibold)
            }
        }
        #endif
        .onAppear(perform: initializeSelections)
        .onDisappear { applySettings() }
        .onChange(of: selectedStyle) { _, newStyle in
            guard didLoadInitialValues else { return }
            applySettings(style: newStyle, mode: selectedMode)
        }
        .onChange(of: selectedMode) { _, newMode in
            guard didLoadInitialValues else { return }
            applySettings(style: selectedStyle, mode: newMode)
        }
        .onReceive(styleManager.$tokens) { tokens in
            guard didLoadInitialValues, useSystemAccent else { return }
            customAccentColor = tokens.accent
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $customAccentColor)
        }
    }
    
    private func initializeSelections() {
        selectedStyle = styleManager.style
        selectedMode = styleManager.mode
        useSystemAccent = styleManager.useSystemAccent
        customAccentColor = styleManager.tokens.accent
        initialStyle = styleManager.style
        initialMode = styleManager.mode
        initialUseSystemAccent = styleManager.useSystemAccent
        initialCustomAccent = styleManager.tokens.accent
        didLoadInitialValues = true
    }

    private func restoreInitialSelections() {
        guard didLoadInitialValues else { return }
        didLoadInitialValues = false
        selectedStyle = initialStyle
        selectedMode = initialMode
        useSystemAccent = initialUseSystemAccent
        customAccentColor = initialCustomAccent
        didLoadInitialValues = true
        applySettings(style: initialStyle, mode: initialMode)
        if initialUseSystemAccent {
            styleManager.useSystemAccent = true
        } else {
            styleManager.setCustomAccent(initialCustomAccent)
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 24) {
            // Hero icon with animated gradient
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
                    .frame(width: 80, height: 80)
                    .shadow(color: styleManager.tokens.accent.opacity(0.2), radius: 16, x: 0, y: 8)
                
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(styleManager.tokens.accent)
            }
            
            VStack(spacing: 12) {
                Text("Customize Appearance")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(styleManager.tokens.onBackground)
                
                Text("Personalize your chat experience with themes, colors, and accessibility options")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Current style indicator
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Current Style")
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                    Text(styleManager.style.rawValue.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(styleManager.tokens.accent)
                }
                
                Rectangle()
                    .fill(styleManager.tokens.secondary.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                VStack(spacing: 4) {
                    Text("Theme Mode")
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                    Text(styleManager.mode.rawValue.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(styleManager.tokens.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(styleManager.tokens.surface)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    private var styleSelectionSection: some View {
        sectionContainer(title: "Style Selection", icon: "paintbrush") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: isLargeScreen ? 3 : 2), spacing: 16) {
                ForEach(AppStyle.allCases, id: \.self) { style in
                    styleCard(style: style)
                }
            }
        }
    }
    
    private func styleCard(style: AppStyle) -> some View {
        VStack(spacing: 12) {
            // Style preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(previewGradient(for: style))
                    .frame(height: 60)
                
                VStack(spacing: 2) {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 16, height: 16)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 24, height: 3)
                        .cornerRadius(1.5)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 20, height: 2)
                        .cornerRadius(1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedStyle == style ? styleManager.tokens.accent : Color.clear, lineWidth: 2)
            )
            
            // Style info
            VStack(spacing: 4) {
                Text(style.rawValue.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(styleManager.tokens.onSurface)
                
                Text(styleDescription(for: style))
                    .font(.system(size: 12))
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            // Selection indicator
            if selectedStyle == style {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(styleManager.tokens.accent)
                    Text("Selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(styleManager.tokens.accent)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(styleManager.tokens.surface)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedStyle == style ? styleManager.tokens.accent : styleManager.tokens.secondary.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(selectedStyle == style ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedStyle)
        .onTapGesture {
            withAnimation(.easeInOut(duration: animationDuration)) {
                selectedStyle = style
            }
        }
    }
    
    private var themeModeSection: some View {
        sectionContainer(title: "Theme Mode", icon: "moon") {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        themeModeButton(mode: mode)
                    }
                }
                
                // Theme mode description
                Text(themeModeDescription(for: selectedMode))
                    .font(.system(size: 14))
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private func themeModeButton(mode: ThemeMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: animationDuration)) {
                selectedMode = mode
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: themeModeIcon(for: mode))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(selectedMode == mode ? styleManager.tokens.onPrimary : styleManager.tokens.onSurface)
                
                Text(mode.rawValue.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedMode == mode ? styleManager.tokens.onPrimary : styleManager.tokens.onSurface)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedMode == mode ? styleManager.tokens.accent : styleManager.tokens.surface)
                    .shadow(color: (selectedMode == mode ? styleManager.tokens.accent : Color.black).opacity(0.1), 
                           radius: selectedMode == mode ? 8 : 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var previewSection: some View {
        sectionContainer(title: "Preview", icon: "eye") {
            VStack(spacing: 16) {
                // Live preview with current tokens
                previewCard
                
                // Preview text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview Text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(styleManager.tokens.onSurface)
                    
                    TextField("Enter preview text", text: $previewText)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(styleManager.tokens.surface)
                                .stroke(styleManager.tokens.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var previewCard: some View {
        VStack(spacing: 12) {
            // Chat message preview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chat Preview")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(styleManager.tokens.onSurface)
                    
                    Text(previewText)
                        .font(.system(size: 14))
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                }
                
                Spacer()
                
                // Mock send button
                Button(action: {}) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(styleManager.tokens.accent)
                }
                .disabled(true)
            }
            
            // Color palette preview
            HStack(spacing: 8) {
                ForEach([
                    ("accent", styleManager.tokens.accent),
                    ("secondary", styleManager.tokens.secondary),
                    ("success", styleManager.tokens.success),
                    ("error", styleManager.tokens.error),
                    ("info", styleManager.tokens.info)
                ], id: \.0) { (name, color) in
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(styleManager.tokens.secondary.opacity(0.3), lineWidth: 0.5)
                        )
                }
                
                Spacer()
                
                Text("Color Palette")
                    .font(.system(size: 12))
                    .foregroundColor(styleManager.tokens.secondaryForeground)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(styleManager.tokens.surface)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var advancedSettingsSection: some View {
        sectionContainer(title: "Advanced Settings", icon: "slider.horizontal.3") {
            VStack(spacing: 16) {
                // Animation settings
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Animations")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(styleManager.tokens.onSurface)
                        Text("Smooth transitions between themes")
                            .font(.system(size: 12))
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $enableAnimations)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: styleManager.tokens.accent))
                }
                
                // Animation duration
                if enableAnimations {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Animation Duration")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(styleManager.tokens.onSurface)
                            Spacer()
                            Text("\(animationDuration, specifier: "%.1f")s")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(styleManager.tokens.accent)
                        }
                        
                        Slider(value: $animationDuration, in: 0.1...1.0, step: 0.1)
                            .accentColor(styleManager.tokens.accent)
                    }
                }
                
                // Custom accent color
                Button(action: {
                    showingColorPicker = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Accent Color")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(styleManager.tokens.onSurface)
                            Text("Override theme accent color")
                                .font(.system(size: 12))
                                .foregroundColor(styleManager.tokens.secondaryForeground)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(customAccentColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(styleManager.tokens.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var accessibilitySection: some View {
        sectionContainer(title: "Accessibility", icon: "accessibility") {
            VStack(spacing: 16) {
                // High contrast mode
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("High Contrast Mode")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(styleManager.tokens.onSurface)
                        Text("Increased contrast for better readability")
                            .font(.system(size: 12))
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $highContrastMode)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: styleManager.tokens.accent))
                }
                
                // Reduced motion
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reduce Motion")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(styleManager.tokens.onSurface)
                        Text("Minimize animations for motion sensitivity")
                            .font(.system(size: 12))
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $reducedMotion)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: styleManager.tokens.accent))
                }
                
                // Accessibility recommendation
                if highContrastMode || reducedMotion {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 16))
                            .foregroundColor(styleManager.tokens.success)
                        
                        Text("Accessibility features enabled")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(styleManager.tokens.success)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(styleManager.tokens.success.opacity(0.1))
                    )
                }
            }
        }
    }
    
    private var performanceSection: some View {
        sectionContainer(title: "Performance", icon: "speedometer") {
            VStack(spacing: 16) {
                // Cache statistics (mock data - cacheStats not available in current StyleManager)
                let mockCacheSize = 6
                let mockHitRate = 0.87
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Theme Cache")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(styleManager.tokens.onSurface)
                        Text("\(mockCacheSize) cached themes")
                            .font(.system(size: 12))
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Hit Rate")
                            .font(.system(size: 12))
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                        Text("\(Int(mockHitRate * 100))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(styleManager.tokens.accent)
                    }
                }
                
                // Performance tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Tips")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(styleManager.tokens.onSurface)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        performanceTip(icon: "checkmark.circle", text: "Theme caching is enabled")
                        performanceTip(icon: "checkmark.circle", text: "Common themes are preloaded")
                        performanceTip(icon: reducedMotion ? "checkmark.circle" : "info.circle", 
                                     text: reducedMotion ? "Reduced motion saves battery" : "Consider reducing motion on older devices")
                    }
                }
            }
        }
    }

    // MARK: - Accent Section
    private var accentSection: some View {
        sectionContainer(title: "Accent Color", icon: "paintbrush.pointed") {
            VStack(spacing: 16) {
                Toggle(isOn: $useSystemAccent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use System Accent Color")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(styleManager.tokens.onSurface)
                        Text("Follow macOS/iOS accent color")
                            .font(.system(size: 12))
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: styleManager.tokens.accent))
                .onChange(of: useSystemAccent) { _, newValue in
                    guard didLoadInitialValues else { return }
                    styleManager.useSystemAccent = newValue
                    if newValue {
                        customAccentColor = styleManager.tokens.accent
                    }
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Custom Accent Color")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(styleManager.tokens.onSurface)
                        Spacer()
                        Circle().fill(customAccentColor)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(styleManager.tokens.secondary.opacity(0.3), lineWidth: 1))
                        Button("Pick…") { showingColorPicker = true }
                            .buttonStyle(.bordered)
                            .disabled(useSystemAccent)
                    }
                    HStack {
                        Button("Apply Custom Accent") {
                            styleManager.setCustomAccent(customAccentColor)
                            useSystemAccent = false
                            styleManager.useSystemAccent = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(useSystemAccent)
                        Spacer()
                        if !useSystemAccent {
                            Text("Custom accent persists across launches")
                                .font(.system(size: 11))
                                .foregroundColor(styleManager.tokens.secondaryForeground)
                        }
                    }
                }
            }
        }
    }
    
    private func performanceTip(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(icon.contains("checkmark") ? styleManager.tokens.success : styleManager.tokens.info)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(styleManager.tokens.secondaryForeground)
        }
    }
    
    // MARK: - Helper Methods
    
    private func applySettings(style: AppStyle? = nil, mode: ThemeMode? = nil) {
        let targetStyle = style ?? selectedStyle
        let targetMode = mode ?? selectedMode
        withAnimation(enableAnimations ? .easeInOut(duration: animationDuration) : .none) {
            styleManager.setStyle(targetStyle)
            styleManager.setMode(targetMode)
        }
    }
    
    private func previewGradient(for style: AppStyle) -> LinearGradient {
        switch style {
        case .minimal:
            return LinearGradient(gradient: Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vibrant:
            return LinearGradient(gradient: Gradient(colors: [.purple.opacity(0.6), .blue.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .glass:
            return LinearGradient(gradient: Gradient(colors: [.indigo.opacity(0.4), .purple.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .modern:
            return LinearGradient(gradient: Gradient(colors: [.teal.opacity(0.5), .green.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .skeuomorphic:
            return LinearGradient(gradient: Gradient(colors: [.orange.opacity(0.5), .red.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gradient:
            return LinearGradient(gradient: Gradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .playful:
            return LinearGradient(gradient: Gradient(colors: [.pink.opacity(0.6), .yellow.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .professional:
            return LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.5), .gray.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func styleDescription(for style: AppStyle) -> String {
        switch style {
        case .minimal: return "Clean and simple design"
        case .vibrant: return "Bold colors and effects"
        case .glass: return "Sophisticated and refined"
        case .modern: return "Contemporary and sleek"
        case .skeuomorphic: return "Comfortable and inviting"
        case .gradient: return "Dynamic gradient styling"
        case .playful: return "Energetic and whimsical"
        case .professional: return "Polished and business ready"
        }
    }
    
    private func themeModeIcon(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "gear"
        }
    }
    
    private func themeModeDescription(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return "Always use light appearance"
        case .dark: return "Always use dark appearance"
        case .system: return "Match system appearance settings"
        }
    }
    
    // Helper function to create consistent section containers
    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(styleManager.tokens.accent)
                
                Text(title)
                    .font(isLargeScreen ? .title2.bold() : .title3.bold())
                    .foregroundColor(styleManager.tokens.onSurface)
                
                Spacer()
            }
            
            content()
        }
        .padding(isLargeScreen ? 32 : 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(styleManager.tokens.surface)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(styleManager.tokens.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Color Picker View

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var styleManager: StyleManager
    
    var body: some View {
        #if os(macOS)
        NavigationStack { mainContent }
        #else
        NavigationView { mainContent }
        #endif
    }
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            ColorPicker("Select Accent Color", selection: $selectedColor)
                .padding()
            
            // Preview with selected color
            VStack(spacing: 16) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(styleManager.tokens.onSurface)
                
                HStack(spacing: 16) {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accent Color")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(selectedColor)
                        
                        Text("This color will be used for highlights and interactive elements")
                            .font(.system(size: 12))
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(styleManager.tokens.surface)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            
            Spacer()
        }
        .padding()
        .navigationTitle("Custom Color")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) }
        }
        #elseif os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .automatic) { Button("Done") { dismiss() }.fontWeight(.semibold) }
        }
        #endif
    }
}

#if DEBUG
#Preview {
    EnhancedAppearanceSettingsView()
        .environmentObject(StyleManager())
}
#endif 
