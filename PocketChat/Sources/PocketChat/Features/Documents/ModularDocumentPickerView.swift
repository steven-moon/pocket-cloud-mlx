// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Documents/ModularDocumentPickerView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModularDocumentPickerView: View {
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
import UniformTypeIdentifiers
import AIDevLogger
import AIDevSwiftUIKit
#if os(iOS)
import PhotosUI
import UIKit
#endif

/// ModularDocumentPickerView demonstrating the new modular architecture
/// This replaces the monolithic 1,081-line DocumentPickerView.swift with a clean, modular design
public struct ModularDocumentPickerView: View {
    private let logger = Logger(label: "ModularDocumentPickerView")

    // MARK: - State Management
    @StateObject private var documentEngine = DocumentEngine()
    @StateObject private var contextManager = DocumentContextManager()
    @EnvironmentObject private var styleManager: StyleManager
    
    // MARK: - Styling
    private var tokens: ThemeTokens { styleManager.tokens }
    private var primaryColor: Color { tokens.accent }
    private var backgroundColor: Color { tokens.background }
    private var surfaceColor: Color { tokens.surface }
    private var textColor: Color { tokens.onBackground }
    private var secondaryTextColor: Color { tokens.secondaryForeground }
    private var errorColor: Color { tokens.error }
    
    // Callbacks
    let onFilesSelected: ([URL]) -> Void
    let onCancel: () -> Void
    
    // MARK: - UI State
    @State private var showingDocumentDetail: DocumentFile?
    @State private var searchText: String = ""
    @State private var showingFilters: Bool = false
    @State private var viewMode: ViewMode = .grid
#if os(iOS)
    @State private var isShowingFileImporter: Bool = false
    @State private var isShowingCameraCapture: Bool = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
#endif
    
    // MARK: - Platform Detection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    private var isLargeScreen: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    private var isAppleTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }
    
    private var isAppleWatch: Bool {
        #if os(watchOS)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - View Modes
    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
        
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }
    
    // MARK: - Initialization
    public init(
        onFilesSelected: @escaping ([URL]) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.onFilesSelected = onFilesSelected
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    public var body: some View {
        mainContent
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            if documentEngine.documentLibrary.isEmpty && documentEngine.selectedFiles.isEmpty {
                emptyStateView
            } else {
                mainContentView
            }
        }
        .background(backgroundColor)
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            toolbarContent
            #elseif os(macOS)
            ToolbarItem(placement: .automatic) {
                Button("Cancel") { handleCancel() }
                    .foregroundColor(primaryColor)
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Select All", action: selectAll)
                    Button("Clear Selection", action: documentEngine.clearSelection)
                    Divider()
                    Button("Sort by Name") { documentEngine.sortOrder = .name }
                    Button("Sort by Date") { documentEngine.sortOrder = .dateAdded }
                    Button("Sort by Size") { documentEngine.sortOrder = .size }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(primaryColor)
                }
            }
            #endif
        }
        .searchable(text: $searchText, prompt: "Search documents...")
        .onChange(of: searchText) { _, newValue in
            documentEngine.searchText = newValue
        }
        .sheet(item: $showingDocumentDetail) { document in
            ModularDocumentDetailView(document: document)
        }
        .sheet(isPresented: $showingFilters) {
            DocumentFiltersView(documentEngine: documentEngine)
        }
        .onAppear { setupInitialState() }
#if os(iOS)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: documentEngine.allowsMultipleSelection
        ) { result in
            handleFileImportResult(result)
        }
        .onChange(of: photoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await handlePhotoPickerSelection(newItems)
            }
        }
        .sheet(isPresented: $isShowingCameraCapture) {
            CameraCaptureView { url in
                defer { isShowingCameraCapture = false }
                guard let url else { return }
                Task {
                    await importSelectedURLs([url])
                }
            }
            .ignoresSafeArea()
        }
#endif
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hero section
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(primaryColor.opacity(0.1))
                        .frame(width: heroIconSize, height: heroIconSize)
                    
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: heroIconSize * 0.4, weight: .semibold))
                        .foregroundColor(primaryColor)
                }
                .shadow(color: primaryColor.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Text
                VStack(spacing: 8) {
                    Text("Add Documents")
                        .font(heroTitleFont)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    
                    Text("Select files to share in your conversation")
                        .font(heroSubtitleFont)
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                
                // Statistics badges
                statisticsBadges
            }
            
            // Drag & drop + quick actions
            dropZoneSection(includeQuickActions: !isAppleWatch)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    DocumentCategorySelector(documentEngine: documentEngine)
                    controlsBar

                    if !documentEngine.selectedFiles.isEmpty {
                        selectedFilesSection
                    }

                    documentsSection
                    actionButtonsSection
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }

            Divider()
                .background(primaryColor.opacity(0.2))

            dropZoneSection(includeQuickActions: !isAppleWatch)
                .padding(.vertical, 24)
                .background(surfaceColor.opacity(isAppleTV ? 1 : 0.9))
                .padding(.bottom, viewBottomPadding)
        }
    }
    
    // MARK: - Statistics Badges
    private var statisticsBadges: some View {
        HStack(spacing: isLargeScreen ? 32 : 16) {
            statisticsBadge("15+", "File Types", "doc.richtext")
            statisticsBadge("Multi", "Selection", "checkmark.square")
            if !isAppleWatch {
                statisticsBadge("Drag", "Drop", "square.and.arrow.down")
            }
        }
    }
    
    private func statisticsBadge(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: isAppleTV ? 20 : 16, weight: .medium))
                .foregroundColor(primaryColor)
            
            Text(value)
                .font(badgeValueFont)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            Text(label)
                .font(badgeLabelFont)
                .foregroundColor(secondaryTextColor)
        }
        .padding(.horizontal, isAppleTV ? 20 : 12)
        .padding(.vertical, isAppleTV ? 12 : 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(surfaceColor)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Quick Action Buttons
    private var quickActionButtons: some View {
        quickActionButtonRow.padding(.horizontal)
    }

    private var quickActionButtonRow: some View {
        HStack(spacing: 16) {
            #if os(iOS)
            quickActionFileImporterButton
            if !isAppleTV {
                quickActionPhotosPicker
                quickActionCameraButton
            }
            #else
            quickActionButton("Browse Files", "folder", primaryColor) {
                Task {
                    let exported = await documentEngine.importFromDeviceSource(.files)
                    guard !exported.isEmpty else { return }
                    await MainActor.run {
                        handleFilesSelected(exported)
                    }
                }
            }
            
            if !isAppleTV {
                quickActionButton("Photos", "photo", tokens.secondary) {
                    Task {
                        let exported = await documentEngine.importFromDeviceSource(.photoLibrary)
                        guard !exported.isEmpty else { return }
                        await MainActor.run {
                            handleFilesSelected(exported)
                        }
                    }
                }
                
                quickActionButton("Camera", "camera", tokens.success) {
                    Task {
                        let exported = await documentEngine.importFromDeviceSource(.camera)
                        guard !exported.isEmpty else { return }
                        await MainActor.run {
                            handleFilesSelected(exported)
                        }
                    }
                }
            }
            #endif
        }
    }
    
    private func quickActionButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionTile(title, icon, color)
        }
        .buttonStyle(.plain)
    }

    private func quickActionTile(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: isAppleTV ? 28 : 20, weight: .medium))
                .foregroundColor(color)
            
            Text(title)
                .font(actionButtonFont)
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isAppleTV ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(surfaceColor)
                .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
        )
    }

#if os(iOS)
    private var quickActionFileImporterButton: some View {
        Button {
            isShowingFileImporter = true
        } label: {
            quickActionTile("Browse Files", "folder", primaryColor)
        }
        .buttonStyle(.plain)
    }
    
    private var quickActionPhotosPicker: some View {
        PhotosPicker(
            selection: $photoPickerItems,
            maxSelectionCount: maxPhotoSelectionCount,
            matching: .any(of: [.images, .videos])
        ) {
            quickActionTile("Photos", "photo", tokens.secondary)
        }
    }
    
    private var quickActionCameraButton: some View {
        Button {
            guard isCameraAvailable else { return }
            isShowingCameraCapture = true
        } label: {
            quickActionTile("Camera", "camera", tokens.success)
                .opacity(isCameraAvailable ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isCameraAvailable)
    }
    
    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    private var allowedImportTypes: [UTType] {
        let types = documentEngine.selectedCategory.supportedTypes
        return types.isEmpty ? DocumentCategory.all.supportedTypes : types
    }
    
    private var maxPhotoSelectionCount: Int {
        documentEngine.allowsMultipleSelection ? 10 : 1
    }
    
    @MainActor
    private func importSelectedURLs(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        let existingIDs = Set(documentEngine.selectedFiles.map { $0.id })
        await documentEngine.addFiles(urls)
        let newFiles = documentEngine.selectedFiles.filter { !existingIDs.contains($0.id) }
        guard !newFiles.isEmpty else { return }
        let exported = newFiles.compactMap { $0.url }
        handleFilesSelected(exported)
    }
    
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                await importSelectedURLs(urls)
            }
        case .failure(let error):
            logger.error("File import failed: \(error.localizedDescription)")
        }
    }
    
    private func handlePhotoPickerSelection(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var urls: [URL] = []
        for item in items {
            if let assetURL = try? await item.loadTransferable(type: URL.self) {
                urls.append(assetURL)
                continue
            }
            if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "dat"
                do {
                    let fileURL = try persistTemporaryData(data, preferredExtension: ext)
                    urls.append(fileURL)
                } catch {
                    logger.error("Failed to persist photo picker data: \(error.localizedDescription)")
                }
            }
        }
        if !urls.isEmpty {
            await importSelectedURLs(urls)
        }
        await MainActor.run {
            photoPickerItems.removeAll()
        }
    }
    
    private func persistTemporaryData(_ data: Data, preferredExtension: String) throws -> URL {
        let sanitizedExtension = preferredExtension.isEmpty ? "dat" : preferredExtension
        let filename = "\(UUID().uuidString).\(sanitizedExtension)"
    var tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    try data.write(to: tempURL, options: [.atomic])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try tempURL.setResourceValues(values)
    return tempURL
    }
#endif

    private func makeDropZone() -> DocumentDragDropZone {
        DocumentDragDropZone(
            supportedTypes: documentEngine.supportedTypes,
            displayFormats: documentEngine.selectedCategory.displayFormats,
            onPerformDrop: { providers in
                await documentEngine.extractFileURLs(from: providers)
            },
            onFilesDropped: { urls in
                guard !urls.isEmpty else { return }
                Task {
                    await documentEngine.addFiles(urls)
                    let exported = await documentEngine.exportSelectedFiles()
                    await MainActor.run {
                        handleFilesSelected(exported)
                    }
                }
            },
            onRequestImport: {
                Task {
                    let exported = await documentEngine.importFromDeviceSource(.files)
                    guard !exported.isEmpty else { return }
                    await MainActor.run {
                        handleFilesSelected(exported)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func dropZoneSection(includeQuickActions: Bool) -> some View {
        #if os(macOS)
        VStack(spacing: 16) {
            makeDropZone()
            if includeQuickActions {
                quickActionButtonRow
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 40)
#elseif os(iOS)
        VStack(spacing: 16) {
            if includeQuickActions {
                quickActionButtons
            }
        }
        .padding(.horizontal, 20)
        #else
        VStack(spacing: 16) {
            makeDropZone()
            if includeQuickActions {
                quickActionButtons
            }
        }
        .padding(.horizontal, isAppleTV ? 60 : 20)
        #endif
    }
    
    // MARK: - Controls Bar
    private var controlsBar: some View {
        HStack {
            // Search status
            if !searchText.isEmpty {
                Text("\(documentEngine.filteredDocuments.count) results")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
            
            Spacer()
            
            // View mode toggle (not on Watch)
            if !isAppleWatch {
                viewModeToggle
            }
            
            // Filters button
            Button(action: { showingFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(primaryColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }
    
    private var viewModeToggle: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Image(systemName: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 100)
    }
    
    // MARK: - Selected Files Section
    private var selectedFilesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Selected (\(documentEngine.selectedFiles.count))")
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Spacer()
                
                Button("Clear") {
                    documentEngine.clearSelection()
                }
                .font(.caption)
                .foregroundColor(errorColor)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(documentEngine.selectedFiles) { file in
                        DocumentFileCard(
                            document: file,
                            isSelected: true,
                            showDetails: false,
                            onTap: {
                                showingDocumentDetail = file
                            },
                            onRemove: {
                                documentEngine.removeFile(file)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Documents Section
    private var documentsSection: some View {
        Group {
            if documentEngine.filteredDocuments.isEmpty {
                emptyDocumentsPlaceholder
            } else if viewMode == .grid {
                documentsGrid
            } else {
                documentsList
            }
        }
    }

    private var emptyDocumentsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(secondaryTextColor)

            Text("No documents match your filters yet.")
                .font(.callout)
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var documentsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: gridColumns)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(documentEngine.filteredDocuments) { document in
                DocumentFileCard(
                    document: document,
                    isSelected: documentEngine.selectedFiles.contains(document),
                    onTap: {
                        toggleSelection(document)
                    },
                    onRemove: documentEngine.allowsMultipleSelection ? {
                        Task {
                            await documentEngine.deleteDocument(document)
                        }
                    } : nil
                )
            }
        }
    }
    
    private var documentsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(documentEngine.filteredDocuments) { document in
                DocumentFileCardCompact(
                    document: document,
                    isSelected: documentEngine.selectedFiles.contains(document),
                    onTap: {
                        toggleSelection(document)
                    },
                    onRemove: documentEngine.allowsMultipleSelection ? {
                        Task {
                            await documentEngine.deleteDocument(document)
                        }
                    } : nil
                )
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(primaryColor.opacity(0.2))
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    handleCancel()
                }
                .font(tokens.bodyFont.weight(.medium))
                .foregroundColor(secondaryTextColor)
                
                Spacer()
                
                Button(action: handleConfirm) {
                    Text(confirmButtonTitle)
                        .font(tokens.headlineFont.weight(.semibold))
                        .foregroundColor(tokens.onPrimary)
                        .padding(.horizontal, tokens.spacing.lg)
                        .padding(.vertical, tokens.spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: tokens.cornerRadius.lg)
                                .fill(confirmButtonEnabled ? primaryColor : primaryColor.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .opacity(confirmButtonEnabled ? 1 : 0.7)
                .allowsHitTesting(confirmButtonEnabled)
            }
            .padding()
        }
    }
    
    // MARK: - Toolbar Content
    #if os(iOS)
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                handleCancel()
            }
            .foregroundColor(primaryColor)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("Select All", action: selectAll)
                Button("Clear Selection", action: documentEngine.clearSelection)
                Divider()
                Button("Sort by Name") { documentEngine.sortOrder = .name }
                Button("Sort by Date") { documentEngine.sortOrder = .dateAdded }
                Button("Sort by Size") { documentEngine.sortOrder = .size }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(primaryColor)
            }
        }
    }
    #endif
    
    // MARK: - Computed Properties
    private var navigationTitle: String {
        if documentEngine.selectedFiles.isEmpty {
            return "Documents"
        } else {
            return "\(documentEngine.selectedFiles.count) Selected"
        }
    }

    private var confirmButtonTitle: String {
        let count = documentEngine.selectedFiles.count
        switch count {
        case 0:
            return "Add Files"
        case 1:
            return "Add 1 File"
        default:
            return "Add \(count) Files"
        }
    }

    private var confirmButtonEnabled: Bool {
        !documentEngine.selectedFiles.isEmpty
    }

    private var contentHorizontalPadding: CGFloat {
        if isAppleTV { return 64 }
        if isLargeScreen { return 28 }
        return 20
    }

    private var viewBottomPadding: CGFloat {
        #if os(iOS)
        return 0
        #else
        return 8
        #endif
    }
    
    private var gridColumns: Int {
        if isAppleWatch {
            return 1
        } else if isAppleTV {
            return 4
        } else if isLargeScreen {
            return 3
        } else {
            return 2
        }
    }
    
    private var heroIconSize: CGFloat {
        if isAppleWatch {
            return 60
        } else if isAppleTV {
            return 120
        } else if isLargeScreen {
            return 100
        } else {
            return 80
        }
    }
    
    private var heroTitleFont: Font {
        if isAppleWatch {
            return .headline
        } else if isAppleTV {
            return .largeTitle.bold()
        } else if isLargeScreen {
            return .title.bold()
        } else {
            return .title2.bold()
        }
    }
    
    private var heroSubtitleFont: Font {
        if isAppleWatch {
            return .caption
        } else if isAppleTV {
            return .title3
        } else {
            return .body
        }
    }
    
    private var badgeValueFont: Font {
        if isAppleTV {
            return .title3.bold()
        } else {
            return .caption.bold()
        }
    }
    
    private var badgeLabelFont: Font {
        if isAppleTV {
            return .body
        } else {
            return .caption2
        }
    }
    
    private var actionButtonFont: Font {
        if isAppleTV {
            return .body
        } else {
            return .caption
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        // Configure document engine for this session
        documentEngine.setMultipleSelection(true)
        documentEngine.setCategory(.all)
    }
    
    private func toggleSelection(_ document: DocumentFile) {
        if documentEngine.selectedFiles.contains(document) {
            documentEngine.removeFile(document)
        } else {
            if documentEngine.allowsMultipleSelection {
                documentEngine.selectedFiles.append(document)
            } else {
                documentEngine.selectedFiles = [document]
            }
        }
    }
    
    private func selectAll() {
        documentEngine.selectedFiles = documentEngine.filteredDocuments
    }
    
    private func handleFilesSelected(_ urls: [URL]) {
        onFilesSelected(urls)
        if !documentEngine.allowsMultipleSelection && !urls.isEmpty {
            dismiss()
        }
    }
    
    private func handleConfirm() {
        let urls = documentEngine.selectedFiles.compactMap { $0.url }
        onFilesSelected(urls)
        dismiss()
    }
    
    private func handleCancel() {
        onCancel()
        dismiss()
    }
}

// MARK: - Supporting Views

struct DocumentCategorySelector: View {
    @ObservedObject var documentEngine: DocumentEngine
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DocumentCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: documentEngine.selectedCategory == category,
                        onTap: {
                            documentEngine.setCategory(category)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryButton: View {
    let category: DocumentCategory
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject private var styleManager: StyleManager
    
    var body: some View {
        Button(action: onTap) {
            let tokens = styleManager.tokens
            let foreground = isSelected ? tokens.onPrimary : tokens.onSurface
            let background = isSelected ? tokens.accent : tokens.surface
            let shadowColor = tokens.accent.opacity(isSelected ? 0.35 : 0.12)
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(background)
                    .shadow(
                        color: shadowColor,
                        radius: isSelected ? 6 : 2,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct DocumentFiltersView: View {
    @ObservedObject var documentEngine: DocumentEngine
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var styleManager: StyleManager
    
    var body: some View {
        #if os(macOS)
        NavigationStack {
            VStack {
                Text("Document Filters")
                    .font(styleManager.tokens.headlineFont.weight(.bold))
                    .foregroundColor(styleManager.tokens.onBackground)
                
                // Filter options would go here
                Text("Sort and filter options")
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #else
        NavigationView {
            VStack {
                Text("Document Filters")
                    .font(styleManager.tokens.headlineFont.weight(.bold))
                    .foregroundColor(styleManager.tokens.onBackground)
                
                // Filter options would go here
                Text("Sort and filter options")
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
        #endif
    }
}

struct ModularDocumentDetailView: View {
    let document: DocumentFile
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var styleManager: StyleManager
    
    var body: some View {
        #if os(macOS)
        NavigationStack {
            VStack {
                Text("Document Details")
                    .font(styleManager.tokens.headlineFont.weight(.bold))
                    .foregroundColor(styleManager.tokens.onBackground)
                
                Text(document.name)
                    .font(styleManager.tokens.bodyFont.weight(.semibold))
                    .foregroundColor(styleManager.tokens.onBackground)
                
                Text(document.formattedSize)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Details")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #else
        NavigationView {
            VStack {
                Text("Document Details")
                    .font(styleManager.tokens.headlineFont.weight(.bold))
                    .foregroundColor(styleManager.tokens.onBackground)
                
                Text(document.name)
                    .font(styleManager.tokens.bodyFont.weight(.semibold))
                    .foregroundColor(styleManager.tokens.onBackground)
                
                Text(document.formattedSize)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
        #endif
    }
}

// MARK: - Context Manager
class DocumentContextManager: ObservableObject {
    @Published var recentDocuments: [DocumentFile] = []
    @Published var suggestedActions: [DocumentAction] = []
    
    func addRecentDocument(_ document: DocumentFile) {
        recentDocuments.insert(document, at: 0)
        if recentDocuments.count > 10 {
            recentDocuments.removeLast()
        }
    }
}

struct DocumentAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

#if os(iOS)
private struct CameraCaptureView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIImagePickerController
    let onCapture: (URL?) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (URL?) -> Void
        
        init(onCapture: @escaping (URL?) -> Void) {
            self.onCapture = onCapture
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.imageURL] as? URL {
                onCapture(url)
            } else if let image = info[.originalImage] as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.9) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(UUID().uuidString).jpg")
                do {
                    try data.write(to: tempURL, options: [.atomic])
                    onCapture(tempURL)
                } catch {
                    onCapture(nil)
                }
            } else {
                onCapture(nil)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            picker.dismiss(animated: true)
        }
    }
}
#endif

// MARK: - Preview
#if DEBUG
struct ModularDocumentPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ModularDocumentPickerView(
            onFilesSelected: { urls in
                Logger(label: "Preview").info("Files selected count: \(urls.count)")
            },
            onCancel: {
                Logger(label: "Preview").info("Cancelled")
            }
        )
        .previewDisplayName("Modular Document Picker")
        .environmentObject(StyleManager())
    }
}
#endif 
