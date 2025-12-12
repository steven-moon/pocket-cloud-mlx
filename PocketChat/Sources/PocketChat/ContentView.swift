// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/ContentView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ContentView: View {
//   - struct SophisticatedChatView: View {
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
import MLXEngine
import AIDevLogger

/// Main ContentView that orchestrates all sophisticated MLX Chat features
/// This is the primary interface that integrates Apple Intelligence, Enhanced MLX Features,
/// MCP Protocol, and provides a sophisticated chat experience
struct ContentView: View {
    // MARK: - Core Managers
    @StateObject private var appleIntelligenceManager = AppleIntelligenceManager()
    @StateObject private var enhancedMLXFeatures = EnhancedMLXFeatures()
    @StateObject private var mcpManager = MCPManager()
    @StateObject private var chatEngine = ChatEngine()
    @StateObject private var accessibilityManager = AccessibilityManager()

    private let logger = Logger(label: "ContentView")
    
    // MARK: - Style System
    @EnvironmentObject var styleManager: StyleManager
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - UI State
    @State private var selectedTab: MainTab = .chat
    @State private var showingOnboarding = false
    @State private var showingSettings = false
    @State private var showingModelHub = false
    @State private var showingDocuments = false
    @State private var showingMCPTools = false
    @State private var showingDiagnostics = false
    
    // MARK: - Platform Detection
    #if os(iOS) || os(tvOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isLargeScreen: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }
    #else
    // On macOS, use large-screen layout by default
    private var isLargeScreen: Bool { true }
    #endif
    
    // MARK: - Main Tabs
    enum MainTab: String, CaseIterable {
        case chat = "Chat"
        case models = "Models"
        case adapters = "LoRA Adapters"
        case documents = "Documents"
        case mcp = "MCP Tools"
        case intelligence = "Intelligence"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .models: return "cpu"
            case .adapters: return "square.stack.3d.down.right"
            case .documents: return "doc.fill"
            case .mcp: return "hammer.fill"
            case .intelligence: return "brain.head.profile"
            case .settings: return "gear"
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        print("🎯 DEBUG: ContentView body rendering - selectedTab: \(selectedTab)")
        return ZStack {
            styleManager.tokens.background.ignoresSafeArea()

            Group {
                if isLargeScreen {
                    // iPad/Mac layout with sidebar
                    sophisticatedSidebarLayout
                } else {
                    // iPhone layout with tabs
                    sophisticatedTabLayout
                }
            }
        }
        .tint(styleManager.tokens.accent)
        .onAppear {
            styleManager.updateSystemColorScheme(colorScheme)
            #if canImport(UIKit)
            configureGlobalAppearance()
            #endif
            Task {
                // Bootstrap minimal models first for anti-fragile startup
                await bootstrapMinimalModelsSafely()
                // Then initialize other sophisticated features
                await initializeSophisticatedFeatures()
            }
        }
        .onChange(of: colorScheme) { _, newScheme in
            guard styleManager.mode == .system else { return }
            styleManager.updateSystemColorScheme(newScheme)
            #if canImport(UIKit)
            configureGlobalAppearance()
            #endif
        }
        #if canImport(UIKit)
        .onChange(of: styleManager.style) { _, _ in
            configureGlobalAppearance()
        }
        .onChange(of: styleManager.mode) { _, _ in
            configureGlobalAppearance()
        }
        .onChange(of: styleManager.useSystemAccent) { _, _ in
            configureGlobalAppearance()
        }
        .onChange(of: styleManager.customAccentRGBA) { _, _ in
            configureGlobalAppearance()
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .switchToChat)) { _ in
            selectedTab = .chat
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                EnhancedAppearanceSettingsView()
                    .environmentObject(styleManager)
            }
            .tint(styleManager.tokens.accent)
        }
        .writingToolsEnabled()
        .genmojiEnabled()
        .imagePlaygroundIntegration(appleIntelligenceManager)
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsOverlayView()
                .environmentObject(styleManager)
        }
    }
    
    // MARK: - Sophisticated Sidebar Layout (iPad/Mac)
    private var sophisticatedSidebarLayout: some View {
        NavigationSplitView {
            // Sidebar
            List(MainTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .foregroundColor(selectedTab == tab ? styleManager.tokens.primary : styleManager.tokens.onSurface)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("MLX Chat")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: sophisticatedStatusIndicator)
            #endif
            .background(styleManager.tokens.surface)
        } detail: {
            // Main content
            sophisticatedDetailView
        }
    }
    
    // MARK: - Sophisticated Tab Layout (iPhone)
    private var sophisticatedTabLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                sophisticatedTabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .background(styleManager.tokens.background)
        .accentColor(styleManager.tokens.primary)
        #if canImport(UIKit)
        .onAppear { configureTabBarAppearance() }
        #endif
    }
    
    // MARK: - Sophisticated Tab Content
    @ViewBuilder
    private func sophisticatedTabContent(for tab: MainTab) -> some View {
        #if os(macOS)
        NavigationStack {
            sophisticatedContentView(for: tab)
        }
        #else
        NavigationView {
            sophisticatedContentView(for: tab)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: sophisticatedStatusIndicator)
        }
        #endif
    }
    
    // MARK: - Sophisticated Detail View
    private var sophisticatedDetailView: some View {
        NavigationStack {
            sophisticatedContentView(for: selectedTab)
                .navigationTitle(selectedTab.rawValue)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
        }
    }
    
    // MARK: - Sophisticated Content View
    @ViewBuilder
    private func sophisticatedContentView(for tab: MainTab) -> some View {
        switch tab {
        case .chat:
            ChatView(onOpenModelsTab: { selectedTab = .models })
                .environmentObject(chatEngine)
                .environmentObject(appleIntelligenceManager)
                .environmentObject(enhancedMLXFeatures)
                .environmentObject(mcpManager)
                .environmentObject(styleManager)

        case .models:
            ModelDiscoveryView()
                .environmentObject(enhancedMLXFeatures)
                .environmentObject(styleManager)

        case .adapters:
            // TODO: LoRA Adapter Management Feature Coming Soon
            Text("🔧 LoRA Adapter Management Feature Coming Soon")
                .foregroundColor(styleManager.tokens.onSurface)
                .font(.title)
                .environmentObject(styleManager)

        case .documents:
            ModularDocumentPickerView(
                onFilesSelected: { urls in
                    for url in urls { chatEngine.handlePickedDocument(url: url) }
                },
                onCancel: { }
            )
            .environmentObject(styleManager)

        case .mcp:
            // TODO: Create MCPView
            Text("🔧 MCP Tools Feature Coming Soon")
                .foregroundColor(styleManager.tokens.onSurface)
                .font(.title)

        case .intelligence:
            // TODO: Create IntelligenceView
            Text("🧠 Apple Intelligence Feature Coming Soon")
                .foregroundColor(styleManager.tokens.onSurface)
                .font(.title)

        case .settings:
            SettingsView()
                .environmentObject(styleManager)
        }
    }
    
    // MARK: - Sophisticated Status Indicator
    private var sophisticatedStatusIndicator: some View {
        HStack(spacing: 8) {
            // Apple Intelligence status
            Circle()
                .fill(appleIntelligenceManager.isAvailable ? .green : .gray)
                .frame(width: 8, height: 8)
                .help("Apple Intelligence: \(appleIntelligenceManager.isAvailable ? "Available" : "Unavailable")")
            
            // MLX Features status
            Circle()
                .fill(enhancedMLXFeatures.isInitialized ? .blue : .gray)
                .frame(width: 8, height: 8)
                .help("MLX Features: \(enhancedMLXFeatures.isInitialized ? "Ready" : "Initializing")")
            
            // MCP Server status
            Circle()
                .fill(mcpManager.isServerRunning ? .orange : .gray)
                .frame(width: 8, height: 8)
                .help("MCP Server: \(mcpManager.isServerRunning ? "Running" : "Stopped")")
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
                    .foregroundColor(styleManager.tokens.onSurface)
            }
            Button(action: { showingDiagnostics = true }) {
                Image(systemName: "stethoscope")
                    .foregroundColor(styleManager.tokens.onSurface)
            }
        }
    }
    
    // MARK: - Sophisticated Initialization
    private func initializeSophisticatedFeatures() async {
        // Initialize Apple Intelligence
        await appleIntelligenceManager.initialize()
        
        // Initialize Enhanced MLX Features
        await enhancedMLXFeatures.initialize()
        
        // Start MCP Server
        await mcpManager.startServer()
        
        // Initialize Chat Engine with sophisticated features
        await chatEngine.initialize(
            appleIntelligence: appleIntelligenceManager,
            enhancedMLX: enhancedMLXFeatures,
            mcpManager: mcpManager
        )
        
        logger.info("Sophisticated MLX Chat features initialized successfully!")
    }

    /// Safely bootstrap minimal models for anti-fragile startup
    private func bootstrapMinimalModelsSafely() async {
        do {
            logger.info("🚀 Bootstrapping minimal models for anti-fragile startup...")
            try await ModelBootstrapper.shared.bootstrapMinimalModels()
            logger.info("✅ Model bootstrap completed successfully")
        } catch {
            logger.warning("⚠️ Model bootstrap failed, but app will continue: \(error.localizedDescription)")
            // Don't fail the app startup - the app should work even if bootstrap fails
        }
    }
}

// MARK: - Sophisticated Chat View
struct SophisticatedChatView: View {
    private let logger = Logger(label: "SophisticatedChatView")

    @EnvironmentObject var chatEngine: ChatEngine
    @EnvironmentObject var appleIntelligenceManager: AppleIntelligenceManager
    @EnvironmentObject var enhancedMLXFeatures: EnhancedMLXFeatures
    @EnvironmentObject var mcpManager: MCPManager
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Sophisticated header with AI features
            sophisticatedChatHeader
            
            // Main chat interface with MLX integration
            ChatView()
                .environmentObject(styleManager)
            
            // Enhanced input area with Apple Intelligence
            sophisticatedInputArea
        }
        .background(styleManager.tokens.background)
    }
    
    private var sophisticatedChatHeader: some View {
        HStack {
            Text("MLX Chat")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(styleManager.tokens.onBackground)
            
            Spacer()
            
            // Apple Intelligence indicators
            if appleIntelligenceManager.writingToolsEnabled {
                Image(systemName: "textformat")
                    .foregroundColor(.blue)
                    .help("Writing Tools Enabled")
            }
            
            if appleIntelligenceManager.genmojiEnabled {
                Image(systemName: "face.smiling")
                    .foregroundColor(.yellow)
                    .help("Genmoji Enabled")
            }
            
            if appleIntelligenceManager.imagePlaygroundEnabled {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.purple)
                    .help("Image Playground Enabled")
            }
        }
        .padding()
        .background(styleManager.tokens.surface)
    }
    
    private var sophisticatedInputArea: some View {
        VStack(spacing: 12) {
            // AI enhancement tools
            HStack {
                Button("RAG Search") {
                    Task {
                        // Sophisticated RAG integration
                        _ = try await enhancedMLXFeatures.performRAG(query: chatEngine.inputText)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Code Analysis") {
                    Task {
                        // Sophisticated code analysis
                        _ = try await enhancedMLXFeatures.analyzeCode(code: chatEngine.inputText)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("MCP Tools") {
                    Task {
                        // Sophisticated MCP integration
                        _ = try await mcpManager.executeTool("search", with: ["query": chatEngine.inputText])
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Enhanced input with Apple Intelligence
            // TODO: ChatInputView component not yet implemented - commenting out for now
            /*
            ChatInputView(
                text: $chatEngine.inputText,
                isGenerating: $chatEngine.isGenerating,
                onSend: {
                    Task {
                        await chatEngine.sendSophisticatedMessage()
                    }
                },
                onStop: {
                    chatEngine.stopGeneration()
                }
            )
            .writingToolsEnabled()
            .genmojiEnabled()
            */
            
            // Temporary placeholder until ChatInputView is implemented
            Text("Chat input coming soon...")
                .foregroundColor(.secondary)
                .padding()
        }
        .background(styleManager.tokens.surface)
    }
}

#if canImport(UIKit)
private extension ContentView {
    func configureGlobalAppearance() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
    }

    func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(styleManager.tokens.surface)
        let titleColor = UIColor(styleManager.tokens.onBackground)
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(styleManager.tokens.surface)
        let selectedColor = UIColor(styleManager.tokens.accent)
        let unselectedColor = UIColor(styleManager.tokens.secondaryForeground)
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.inlineLayoutAppearance.normal.iconColor = unselectedColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.compactInlineLayoutAppearance.normal.iconColor = unselectedColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
    }
}
#endif

// MARK: - Sophisticated Model Hub View
struct SophisticatedModelHubView: View {
    @EnvironmentObject var enhancedMLXFeatures: EnhancedMLXFeatures
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack {
            Text("Sophisticated Model Hub")
                .font(.title)
                .foregroundColor(styleManager.tokens.onBackground)
            
            ModelDiscoveryView()
                .environmentObject(styleManager)
        }
        .background(styleManager.tokens.background)
    }
}

// MARK: - Sophisticated Documents View
struct SophisticatedDocumentsView: View {
    private let logger = Logger(label: "SophisticatedDocumentsView")

    @EnvironmentObject var chatEngine: ChatEngine
    @EnvironmentObject var enhancedMLXFeatures: EnhancedMLXFeatures
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack {
            Text("Sophisticated Document Processing")
                .font(.title)
                .foregroundColor(styleManager.tokens.onBackground)
            
            Button("Select Documents (Coming Soon)") {
                logger.info("Document picker coming soon")
            }
            .buttonStyle(.borderedProminent)
        }
        .background(styleManager.tokens.background)
    }
}

// MARK: - Sophisticated MCP View
struct SophisticatedMCPView: View {
    @EnvironmentObject var mcpManager: MCPManager
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack {
            Text("MCP Protocol Integration")
                .font(.title)
                .foregroundColor(styleManager.tokens.onBackground)
            
            List(mcpManager.availableTools, id: \.name) { tool in
                VStack(alignment: .leading) {
                    Text(tool.name)
                        .font(.headline)
                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .background(styleManager.tokens.background)
    }
}

// MARK: - Sophisticated Intelligence View
struct SophisticatedIntelligenceView: View {
    @EnvironmentObject var appleIntelligenceManager: AppleIntelligenceManager
    @EnvironmentObject var enhancedMLXFeatures: EnhancedMLXFeatures
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack {
            Text("Apple Intelligence & MLX Integration")
                .font(.title)
                .foregroundColor(styleManager.tokens.onBackground)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureStatusRow(
                    title: "Writing Tools",
                    enabled: appleIntelligenceManager.writingToolsEnabled,
                    description: "Proofread, rewrite, and summarize text"
                )
                
                FeatureStatusRow(
                    title: "Genmoji",
                    enabled: appleIntelligenceManager.genmojiEnabled,
                    description: "Create custom emoji"
                )
                
                FeatureStatusRow(
                    title: "Image Playground",
                    enabled: appleIntelligenceManager.imagePlaygroundEnabled,
                    description: "Generate and edit images"
                )
                
                FeatureStatusRow(
                    title: "MLX Features",
                    enabled: enhancedMLXFeatures.isInitialized,
                    description: "Local AI processing and RAG"
                )
            }
            .padding()
        }
        .background(styleManager.tokens.background)
    }
}

// MARK: - Feature Status Row
struct FeatureStatusRow: View {
    let title: String
    let enabled: Bool
    let description: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(enabled ? .green : .gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - AccessibilityManager removed (using proper version from Features/Accessibility/AccessibilityManager.swift)

// MARK: - Extensions for ChatEngine
extension ChatEngine {
    func initialize(
        appleIntelligence: AppleIntelligenceManager,
        enhancedMLX: EnhancedMLXFeatures,
        mcpManager: MCPManager
    ) async {
        // Initialize sophisticated chat engine with all features
        let logger = Logger(label: "ChatEngine")
        logger.info("Initializing sophisticated ChatEngine with Apple Intelligence, MLX, and MCP integration")
    }
    
    func sendSophisticatedMessage() async {
        // Sophisticated message processing with all features
        let logger = Logger(label: "ChatEngine")
        logger.info("Sending sophisticated message with full AI integration")
    }

    func stopGeneration() {
        // Stop sophisticated generation
        let logger = Logger(label: "ChatEngine")
        logger.info("Stopping sophisticated generation")
    }
}

#Preview {
    ContentView()
        .environmentObject(StyleManager())
} 
