// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModelDiscoveryView: View {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryDebugView.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryViewModel.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import SwiftUI
import os.log
import PocketCloudMLX
#if os(macOS)
import AppKit
#endif

/// Main model discovery view for browsing and downloading HuggingFace models
struct ModelDiscoveryView: View {
    @StateObject private var viewModel = ModelDiscoveryViewModel()
    @StateObject private var downloadManager = ModelDiscoveryManager.shared
    @StateObject private var downloadState = ModelDownloadStateObserver()
    @State private var searchText = ""
    @State private var selectedFilter: ModelFilter = .all
    @State private var showingFilters = false
    @State private var showingTokenSettings = false
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: HuggingFaceModel? = nil
    @State private var toastMessage: String? = nil
    @State private var hasAutoSelectedSection = false
    @EnvironmentObject var styleManager: StyleManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private static let log = Logger(subsystem: "com.mlxchatapp", category: "ModelHub")

    private var modelGridColumns: [GridItem] {
        let sizeClass = horizontalSizeClass ?? .regular
        let minimumWidth: CGFloat
        if sizeClass == .compact {
            minimumWidth = 300
        } else {
            minimumWidth = 340
        }
        return [
            GridItem(.adaptive(minimum: minimumWidth, maximum: 440), spacing: 16, alignment: .top)
        ]
    }
    
    var body: some View {
        Self.log.info("🔍 ModelDiscoveryView body rendering")

        return mainContent
            .tint(styleManager.tokens.accent)
    }
    
    private func showToast(_ text: String) {
        toastMessage = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { toastMessage = nil }
        }
    }

    func configureInitialSectionIfNeeded() {
        guard !hasAutoSelectedSection else { return }

        if downloadManager.downloadedModelIds.isEmpty {
            viewModel.section = .discover
        } else {
            viewModel.section = .downloaded
        }

        hasAutoSelectedSection = true
    }

    @ViewBuilder
    private func sectionContent(proxy: ScrollViewProxy) -> some View {
        if viewModel.section == .downloaded {
            downloadedListView
        } else if viewModel.isLoading && viewModel.models.isEmpty {
            loadingView
        } else if viewModel.models.isEmpty && !searchText.isEmpty {
            emptySearchView
        } else if viewModel.models.isEmpty {
            emptyStateView
        } else {
            modelListView(proxy: proxy)
            if viewModel.hasMoreResults {
                loadMoreView
            }
        }
    }

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    searchAndFilterBar

                    Picker("Section", selection: $viewModel.section) {
                        Text("Downloaded").tag(ModelDiscoveryViewModel.Section.downloaded)
                        Text("Discover").tag(ModelDiscoveryViewModel.Section.discover)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ModelHubDownloadBar(downloadState: downloadState, hasValidToken: viewModel.hasValidToken)
                        .environmentObject(styleManager)
                        .padding(.horizontal)

                    sectionContent(proxy: proxy)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(styleManager.tokens.background.ignoresSafeArea())
            .navigationTitle("Model Hub")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingTokenSettings = true }) {
                        Image(systemName: "key.fill")
                            .foregroundColor(viewModel.hasValidToken ? .green : .orange)
                    }
                }
                #elseif os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingTokenSettings = true }) {
                        Image(systemName: "key.fill")
                            .foregroundColor(viewModel.hasValidToken ? .green : .orange)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingTokenSettings) {
                HuggingFaceTokenView()
            }
            .onChange(of: showingTokenSettings) { _, isShowing in
                if !isShowing {
                    // Re-check token validity after dismissing token settings
                    viewModel.checkTokenValidity()
                }
            }
            .refreshable {
                await viewModel.searchModels(query: searchText, filter: selectedFilter)
            }
            .onAppear {
                Task { @MainActor in
                    configureInitialSectionIfNeeded()
                }
                viewModel.checkTokenValidity()
                Task {
                    await viewModel.refreshDownloadedFromDisk()
                    await viewModel.searchModels(query: searchText, filter: selectedFilter)
                }
            }
            .onChange(of: downloadManager.downloadedModelIds) { _, _ in
                Task { @MainActor in
                    configureInitialSectionIfNeeded()
                }
            }
            .overlay(alignment: .top) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.caption)
                        .foregroundColor(styleManager.tokens.onPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10).fill(styleManager.tokens.accent)
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .confirmationDialog(
                "Delete Model",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                if let model = modelToDelete {
                    Button("Delete", role: .destructive) {
                        Task {
                            await downloadManager.deleteDownloadedFiles(modelId: model.id)
                            showToast("Deleted model: \(model.id.components(separatedBy: "/").last ?? model.id)")
                            modelToDelete = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    modelToDelete = nil
                }
            } message: {
                if let model = modelToDelete {
                    Text("Are you sure you want to delete '\(model.id.components(separatedBy: "/").last ?? model.id)'? This will permanently remove the model and all its files.")
                }
            }
        }
    }
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                TextField("Search models...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(styleManager.tokens.onBackground)
                    .onSubmit {
                        Task {
                            await viewModel.searchModels(query: searchText, filter: selectedFilter)
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        Task {
                            await viewModel.searchModels(query: "", filter: selectedFilter)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(styleManager.tokens.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(styleManager.tokens.accent.opacity(0.15), lineWidth: 1)
            )
            
            // Compatibility toggle and sorting
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    compatibilityToggleControl
                    Spacer(minLength: 12)
                    typePickerControl
                        .frame(maxWidth: 180, alignment: .leading)
                    sortPickerControl
                        .frame(maxWidth: 180, alignment: .leading)
                }
                .fixedSize(horizontal: true, vertical: false)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        compatibilityToggleControl
                            .gridCellColumns(2)
                    }
                    GridRow {
                        typePickerControl
                            .frame(maxWidth: .infinity, alignment: .leading)
                        sortPickerControl
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ModelFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.displayName,
                            isSelected: selectedFilter == filter,
                            action: {
                                selectedFilter = filter
                                Task {
                                    await viewModel.searchModels(query: searchText, filter: filter)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(styleManager.tokens.background)
    }

    private var compatibilityToggleControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $viewModel.onlyCompatible) {
                Text("Only compatible for this device")
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.onBackground)
            }
            .toggleStyle(ThemedToggleStyle(tokens: styleManager.tokens))
            .onChange(of: viewModel.onlyCompatible) { _, _ in
                Task { await viewModel.searchModels(query: searchText, filter: selectedFilter) }
            }
        }
    }

    private var typePickerControl: some View {
        Picker("Type", selection: $viewModel.typeFilter) {
            Text("Text").tag(ModelDiscoveryViewModel.TypeFilter.text)
            Text("Vision").tag(ModelDiscoveryViewModel.TypeFilter.vision)
            Text("Audio").tag(ModelDiscoveryViewModel.TypeFilter.audio)
            Text("Embed").tag(ModelDiscoveryViewModel.TypeFilter.embedding)
            Text("All").tag(ModelDiscoveryViewModel.TypeFilter.all)
        }
        .pickerStyle(.menu)
        .onChange(of: viewModel.typeFilter) { _, _ in
            Task { await viewModel.searchModels(query: searchText, filter: selectedFilter) }
        }
    }

    private var sortPickerControl: some View {
        Picker("Sort", selection: $viewModel.sortOption) {
            ForEach(ModelDiscoveryViewModel.SortOption.allCases, id: \.self) { opt in
                Text(label(for: opt)).tag(opt)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: viewModel.sortOption) { _, newOption in
            withAnimation {
                switch newOption {
                case .relevance:
                    break
                case .nameAsc:
                    viewModel.models.sort { $0.id < $1.id }
                case .downloadsDesc:
                    viewModel.models.sort { ($0.downloads ?? 0) > ($1.downloads ?? 0) }
                case .sizeAsc:
                    viewModel.models.sort {
                        let a = viewModel.modelManager.totalBytesByModel[$0.id] ?? 0
                        let b = viewModel.modelManager.totalBytesByModel[$1.id] ?? 0
                        return a < b
                    }
                case .sizeDesc:
                    viewModel.models.sort {
                        let a = viewModel.modelManager.totalBytesByModel[$0.id] ?? 0
                        let b = viewModel.modelManager.totalBytesByModel[$1.id] ?? 0
                        return a > b
                    }
                }
            }
        }
    }

    private func label(for option: ModelDiscoveryViewModel.SortOption) -> String {
        switch option {
        case .relevance: return "Relevance"
        case .sizeAsc: return "Size ↑"
        case .sizeDesc: return "Size ↓"
        case .downloadsDesc: return "Popularity"
        case .nameAsc: return "Name A–Z"
        }
    }

    // Small helper chip
    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(styleManager.tokens.surface.opacity(0.6))
            .foregroundColor(styleManager.tokens.secondaryForeground)
            .clipShape(Capsule())
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching for models...")
                .foregroundColor(styleManager.tokens.secondaryForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(styleManager.tokens.secondaryForeground)
            Text("No models found")
                .font(.title2)
                .fontWeight(.medium)
            Text("Try adjusting your search terms or filters")
                .foregroundColor(styleManager.tokens.secondaryForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(styleManager.tokens.secondaryForeground)
            Text("Discover AI Models")
                .font(.title2)
                .fontWeight(.medium)
            Text("Search for MLX-compatible models from HuggingFace Hub")
                .foregroundColor(styleManager.tokens.secondaryForeground)
                .multilineTextAlignment(.center)
            Button("Search for models") {
                searchText = "mlx"
                Task {
                    await viewModel.searchModels(query: "mlx", filter: selectedFilter)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(styleManager.tokens.accent)
            .foregroundColor(styleManager.tokens.onPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func modelListView(proxy: ScrollViewProxy) -> some View {
        LazyVGrid(columns: modelGridColumns, alignment: .leading, spacing: 16, pinnedViews: []) {
            ForEach(viewModel.models) { model in
                ModelCardView(
                    model: model,
                    isDownloading: downloadManager.downloadingModels.contains(model.id),
                    downloadProgress: downloadManager.downloadProgress[model.id] ?? 0,
                    isDownloaded: downloadManager.containsDownloadedModel(id: model.id),
                    downloadError: downloadState.downloadErrors[model.id],
                    onDownload: {
                        withAnimation { proxy.scrollTo(model.id, anchor: .top) }
                        showToast("Download started: \(model.id.components(separatedBy: "/").last ?? model.id)")
                        Task { await viewModel.downloadModel(model) }
                    },
                    onCancel: {
                        Task { await downloadManager.cancelDownload(modelId: model.id) }
                    },
                    onDelete: {
                        modelToDelete = model
                        showingDeleteConfirmation = true
                    }
                )
                .id(model.id)
                .task { await downloadManager.prefetchTotalBytes(for: model.id) }
                        .onChange(of: downloadManager.downloadedModelIds) { _, newIds in
                            if let normalized = downloadManager.normalizedHubId(for: model.id), newIds.contains(normalized) {
                                UserDefaults.standard.set(normalized, forKey: "lastSelectedModelHubId")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    .padding(.top, 4)
    .padding(.bottom, 8)
    }

    private var downloadedListView: some View {
        // Filter out artifacts that are missing the expected owner/model structure.
        let downloadedIds = Array(downloadManager.downloadedModelIds)
            .filter(ModelDiscoveryManager.isValidHubId)
            .sorted()

        return Group {
            if downloadedIds.isEmpty {
                Text("No downloaded models yet.")
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            } else {
                LazyVGrid(columns: modelGridColumns, alignment: .leading, spacing: 16) {
                    ForEach(downloadedIds, id: \.self) { id in
                        let model = viewModel.models.first(where: { downloadManager.normalizedHubId(for: $0.id) == id }) ?? HuggingFaceModel(id: id)
                        let downloadError = downloadState.downloadErrors[model.id] ?? downloadState.downloadErrors[id]
                        ModelCardView(
                            model: model,
                            isDownloading: false,
                            downloadProgress: 1.0,
                            isDownloaded: true,
                            downloadError: downloadError,
                            onDownload: {},
                            onDelete: {
                                modelToDelete = HuggingFaceModel(id: id)
                                showingDeleteConfirmation = true
                            },
                            onUse: {
                                let normalized = downloadManager.normalizedHubId(for: id) ?? id
                                Self.log.info("USE_TAP id=\(normalized, privacy: .public)")
                                UserDefaults.standard.set(normalized, forKey: "lastSelectedModelHubId")
                                Self.log.info("POST_ACTIVATE_MODEL id=\(normalized, privacy: .public)")
                                NotificationCenter.default.post(name: .activateModel, object: normalized)
                                Self.log.info("POST_SWITCH_TO_CHAT")
                                NotificationCenter.default.post(name: .switchToChat, object: nil)
                            }
                        )
                        .id(id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    private var loadMoreView: some View {
        HStack {
            if viewModel.isLoadingMore {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: styleManager.tokens.accent))
            } else {
                Button("Load More") {
                    Task { await viewModel.loadMoreResults() }
                }
                .buttonStyle(.bordered)
                .tint(styleManager.tokens.accent)
                .foregroundColor(styleManager.tokens.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

/// Filter options for model discovery
enum ModelFilter: CaseIterable {
    case all, mlx, popular, recent, small, medium, large
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .mlx: return "MLX"
        case .popular: return "Popular"
        case .recent: return "Recent"
        case .small: return "Small (<3B)"
        case .medium: return "Medium (3-7B)"
        case .large: return "Large (>7B)"
        }
    }
    
    var searchQuery: String {
        switch self {
        case .all: return ""
        case .mlx: return "mlx"
        case .popular: return "downloads:>1000"
        case .recent: return "created:>2024"
        case .small: return "parameters:<3B"
        case .medium: return "parameters:3B-7B"
        case .large: return "parameters:>7B"
        }
    }
}

/// Filter chip component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? styleManager.tokens.accent : styleManager.tokens.surface)
                .foregroundColor(isSelected ? styleManager.tokens.onPrimary : styleManager.tokens.onBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? styleManager.tokens.accent : styleManager.tokens.secondaryForeground.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Toggle style that keeps track/background contrast aligned with the active theme tokens.
struct ThemedToggleStyle: ToggleStyle {
    let tokens: ThemeTokens
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 12)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isOn ? tokens.accent.opacity(0.35) : tokens.surface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tokens.accent.opacity(configuration.isOn ? 0.6 : 0.25), lineWidth: 1)
                    )
                Circle()
                    .fill(configuration.isOn ? tokens.accent : tokens.secondaryForeground.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .padding(3)
                    .shadow(color: Color.black.opacity(0.12), radius: configuration.isOn ? 1.8 : 1, x: 0, y: configuration.isOn ? 1.2 : 0.6)
            }
            .frame(width: 50, height: 30)
            .animation(.easeInOut(duration: 0.18), value: configuration.isOn)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                configuration.isOn.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
        .accessibilityAction {
            configuration.isOn.toggle()
        }
    }
}

#Preview {
    ModelDiscoveryView()
}
