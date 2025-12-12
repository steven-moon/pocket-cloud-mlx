// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/ChatView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ChatView: View {
//   - struct ChatHeaderView: View {
//   - struct ChatErrorView: View {
//   - struct ChatMessagesView: View {
//   - struct ChatInputBar: View {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/DocumentPickerView.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/ModelManager.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/DocumentProcessor.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/ChatOperations.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/MessageBubble.swift
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
import struct MLXEngine.ModelConfiguration
#if os(iOS) || os(macOS)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

// MARK: - Main Chat View
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var styleManager: StyleManager
    var onOpenModelsTab: (() -> Void)? = nil
    private let downloadManager = ModelDiscoveryManager.shared
    private let logger = Logger(label: "ChatView")
    @FocusState private var isInputFocused: Bool
    #if os(iOS)
    @State private var showOverflowDialog = false
    #endif
    
    var body: some View {
        mainContent
            .tint(styleManager.tokens.accent)
            .onAppear { logger.info("appear") }
    }

    // Extracted to avoid conditional-brace mismatches across platforms
    private var mainContent: some View {
        VStack(spacing: 0) {
            ChatHeaderView(
                selectedModel: viewModel.selectedModel,
                hasHistory: !viewModel.chatHistory.isEmpty,
                onOpenModelsTab: { onOpenModelsTab?() },
                onShowHistory: {
                    Task { await viewModel.loadChatHistory() }
                    viewModel.showHistorySheet = true
                },
                onStartNewChat: viewModel.startNewChat,
                onShowOverflow: {
                    #if os(iOS)
                    showOverflowDialog = true
                    #endif
                }
            )
            
            if !downloadManager.downloadingModels.isEmpty {
                ChatDownloadBanner(
                    modelIds: Array(downloadManager.downloadingModels),
                    progress: downloadManager.downloadProgress,
                    bytesDownloaded: downloadManager.downloadedBytesByModel,
                    totalBytes: downloadManager.totalBytesByModel
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if viewModel.readinessStatus.isActive {
                ChatReadinessBanner(status: viewModel.readinessStatus)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.opacity)
            }

            if let errorMessage = viewModel.errorMessage {
                ChatErrorView(message: errorMessage, onDismiss: viewModel.clearError)
            }
            
            ChatMessagesView(
                messages: viewModel.messages,
                isGenerating: viewModel.isGenerating,
                streamingText: viewModel.streamingText,
                streamingPerformance: viewModel.streamingPerformance,
                onRegenerate: viewModel.regenerateLastResponse,
                onBackgroundTap: {
                    isInputFocused = false
                    hideKeyboard()
                }
            )

            if let performance = viewModel.streamingPerformance {
                ChatStreamingMetricsFooter(performance: performance)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
            
            if let preview = viewModel.pickedDocumentPreview {
                ChatDocumentPreviewView(
                    preview: preview,
                    isGenerating: viewModel.isGenerating,
                    onSend: { Task { await viewModel.sendPickedDocumentToModel() } },
                    onClear: { viewModel.pickedDocumentPreview = nil }
                )
            }
            
            ChatInputBar(
                inputText: $viewModel.inputText,
                isGenerating: viewModel.isGenerating,
                isSendDisabled: viewModel.readinessStatus.blocksSending,
                isFocused: $isInputFocused,
                onSend: { Task { await viewModel.sendMessage() } },
                onStop: { viewModel.stopGeneration() },
                onDocument: { viewModel.showDocumentPicker = true }
            )
        }
        .background(styleManager.tokens.background)
        .overlay(alignment: .top) {
            if let toast = viewModel.activationNotice {
                Text(toast)
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
        .onAppear {
            logger.info("ChatView onAppear - scheduling model reload and session ensure")
            Task {
                let appearTaskStart = Date()
                logger.info("ChatView onAppear task started")
                await viewModel.loadAvailableModels()
                logger.info("ChatView onAppear task | loadAvailableModels finished in \(String(format: "%.2f", Date().timeIntervalSince(appearTaskStart)))s")
                // Ensure a valid model/session is active when entering Chat
                await viewModel.rehydrateSelectionAndEnsureSession()
                logger.info("ChatView onAppear task | rehydrate completed in \(String(format: "%.2f", Date().timeIntervalSince(appearTaskStart)))s")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateModel)) { note in
            let id = note.object as? String ?? "<nil>"
            logger.info("Received activate model notification with id: \(id)")
            if let idStr = note.object as? String {
                Task { await viewModel.selectModelById(idStr) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToChat)) { _ in
            // When switching back to Chat, re-ensure a working session for robustness
            Task { await viewModel.rehydrateSelectionAndEnsureSession() }
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            NavigationStack {
                ModularDocumentPickerView(
                    onFilesSelected: { urls in
                        if let firstUrl = urls.first {
                            viewModel.handlePickedDocument(url: firstUrl)
                        }
                        viewModel.showDocumentPicker = false
                    },
                    onCancel: {
                        viewModel.showDocumentPicker = false
                    }
                )
                .environmentObject(styleManager)
            }
        }
        .sheet(isPresented: $viewModel.showVisionPromptSheet) {
            ChatPromptSheet(
                title: "Describe Image (Vision)",
                placeholder: "Describe what you want to see...",
                onSubmit: { prompt in
                    Task { await viewModel.describeImage(prompt: prompt) }
                    viewModel.showVisionPromptSheet = false
                },
                onCancel: { viewModel.showVisionPromptSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showEmbeddingPromptSheet) {
            ChatPromptSheet(
                title: "Get Embedding",
                placeholder: "Enter phrase for embedding...",
                onSubmit: { phrase in
                    Task { await viewModel.generateEmbedding(phrase: phrase) }
                    viewModel.showEmbeddingPromptSheet = false
                },
                onCancel: { viewModel.showEmbeddingPromptSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showHistorySheet) {
            NavigationStack {
                ChatHistorySheet(viewModel: viewModel)
                    .environmentObject(styleManager)
            }
        }
        #if os(iOS)
        .confirmationDialog("Chat Actions", isPresented: $showOverflowDialog, titleVisibility: .visible) {
            Button("New Chat") { viewModel.startNewChat() }
            Button("Chat History") {
                Task { await viewModel.loadChatHistory() }
                viewModel.showHistorySheet = true
            }
            .disabled(viewModel.chatHistory.isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        #endif
    }
}

// MARK: - Chat Header Component
private struct ChatHeaderView: View {
    let selectedModel: ModelConfiguration?
    let hasHistory: Bool
    let onOpenModelsTab: () -> Void
    let onShowHistory: () -> Void
    let onStartNewChat: () -> Void
    let onShowOverflow: (() -> Void)?
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("MLX Chat")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(styleManager.tokens.onBackground)
                
                Spacer()
                
                // Route model selection to Models tab
                Button(action: onOpenModelsTab) {
                    HStack {
                        Image(systemName: "cpu")
                        Text(selectedModel?.name ?? "Choose Model")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(styleManager.tokens.background)
                    .foregroundColor(styleManager.tokens.onBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(styleManager.tokens.accent.opacity(0.3), lineWidth: 1)
                    )
                }

                #if os(macOS)
                Menu {
                    Button("New Chat", action: onStartNewChat)
                    Button("Chat History", action: onShowHistory)
                        .disabled(!hasHistory)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(styleManager.tokens.onBackground)
                        .padding(.leading, 8)
                }
                #else
                Button(action: { onShowOverflow?() }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(styleManager.tokens.onBackground)
                        .padding(.leading, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onShowOverflow == nil)
                #endif
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
                .background(styleManager.tokens.accent.opacity(0.2))
        }
    }
}

// MARK: - Chat History Sheet
private struct ChatHistorySheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var styleManager: StyleManager
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        historyContent
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("New Chat") {
                        viewModel.startNewChat()
                        dismiss()
                        viewModel.showHistorySheet = false
                    }
                }
                ToolbarItem(placement: .automatic) {
                    if !viewModel.chatHistory.isEmpty {
                        Button("Clear All", role: .destructive) {
                            Task { await viewModel.clearHistory() }
                        }
                    }
                }
            }
            .task { await viewModel.loadChatHistory() }
    }

    @ViewBuilder
    private var historyContent: some View {
        #if os(macOS)
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.chatHistory.isEmpty {
                    historyEmptyView
                        .padding(.top, 48)
                } else {
                    ForEach(viewModel.chatHistory) { entry in
                        Button {
                            Task {
                                await viewModel.resumeConversation(entry)
                                dismiss()
                                viewModel.showHistorySheet = false
                            }
                        } label: {
                            historyRow(for: entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.deleteHistoryEntry(entry) }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 420, minHeight: 360)
        #else
        List {
            if viewModel.chatHistory.isEmpty {
                historyEmptyView
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.chatHistory) { entry in
                    Button {
                        Task {
                            await viewModel.resumeConversation(entry)
                            dismiss()
                            viewModel.showHistorySheet = false
                        }
                    } label: {
                        historyRow(for: entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteHistoryEntry(entry) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    private var historyEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(styleManager.tokens.secondaryForeground)
            Text("No Saved Chats Yet")
                .font(.headline)
                .foregroundColor(styleManager.tokens.secondaryForeground)
            Text("Conversations will appear here once you've sent a few messages.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(styleManager.tokens.secondaryForeground)
        }
        .frame(maxWidth: .infinity)
    }

    private func historyRow(for entry: ChatHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.headline)
                .foregroundColor(styleManager.tokens.onBackground)
            Text("Updated " + Self.dateFormatter.string(from: entry.updatedAt))
                .font(.caption)
                .foregroundColor(styleManager.tokens.secondaryForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(styleManager.tokens.surface.opacity(0.4))
        )
    }
}

// MARK: - Chat Error Component
private struct ChatErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.orange)
            
            Spacer()
            
            Button("Dismiss", action: onDismiss)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Chat Messages Component
private struct ChatMessagesView: View {
    let messages: [ChatMessage]
    let isGenerating: Bool
    let streamingText: String
    let streamingPerformance: ChatMessage.PerformanceInfo?
    let onRegenerate: () -> Void
    let onBackgroundTap: () -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            isStreaming: index == messages.count - 1 && isGenerating,
                            performanceOverride: (index == messages.count - 1 && isGenerating) ? streamingPerformance : nil,
                            onRegenerate: shouldShowRegenerate(for: message, at: index) ? onRegenerate : nil
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onBackgroundTap)
            .interactiveKeyboardDismiss()
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: streamingText) { _, _ in
                guard isGenerating, let lastMessage = messages.last else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func shouldShowRegenerate(for message: ChatMessage, at index: Int) -> Bool {
        message.role == .assistant &&
        index == messages.count - 1 &&
        !isGenerating
    }
}

// MARK: - Streaming Metrics Footer
private struct ChatStreamingMetricsFooter: View {
    let performance: ChatMessage.PerformanceInfo
    @EnvironmentObject var styleManager: StyleManager

    private var modelLabel: String {
        let identifier = performance.modelName ?? performance.modelId ?? "Active Model"
        if let last = identifier.split(separator: "/").last {
            return String(last)
        }
        return identifier
    }

    private var summaryText: String? {
        var components: [String] = []

        if let tokensPerSecond = performance.tokensPerSecond, tokensPerSecond > 0.05 {
            components.append(formatTokensPerSecond(tokensPerSecond))
        }

        if let tokenCount = performance.tokenCount, tokenCount > 0 {
            components.append("\(tokenCount) tok")
        }

        if let duration = performance.generationDuration, duration > 0.05 {
            components.append(String(format: "%.1fs", duration))
        }

        return components.isEmpty ? nil : components.joined(separator: " • ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bolt.horizontal.fill")
                .foregroundColor(styleManager.tokens.accent)
                .font(.callout)

            VStack(alignment: .leading, spacing: 2) {
                Text(modelLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(styleManager.tokens.onSurface)

                Text(summaryText ?? "Streaming response…")
                    .font(.caption2)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(styleManager.tokens.surface)
        )
    }

    private func formatTokensPerSecond(_ value: Double) -> String {
        switch value {
        case ..<0.1:
            return "<0.1 tok/s"
        case ..<10:
            return String(format: "%.1f tok/s", value)
        default:
            return "\(Int(round(value))) tok/s"
        }
    }
}

// MARK: - Chat Input Component
private struct ChatInputBar: View {
    @Binding var inputText: String
    let isGenerating: Bool
    let isSendDisabled: Bool
    let isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onStop: () -> Void
    let onDocument: () -> Void
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(styleManager.tokens.accent)
            
            HStack(spacing: 12) {
                Button(action: onDocument) {
                    Image(systemName: "paperclip")
                        .font(.title2)
                        .foregroundColor(styleManager.tokens.accent)
                        .accessibilityLabel("Attach File or Document")
                }
                .disabled(isGenerating)
                
                TextField("Type your message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(styleManager.tokens.surface)
                    .cornerRadius(20)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .focused(isFocused)
                    .onSubmit {
                        guard !isGenerating, !isSendDisabled else { return }
                        onSend()
                        isFocused.wrappedValue = false
                        hideKeyboard()
                    }
                if isFocused.wrappedValue {
                    Button(action: {
                        isFocused.wrappedValue = false
                        hideKeyboard()
                    }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.title2)
                            .foregroundColor(styleManager.tokens.accent)
                            .accessibilityLabel("Hide Keyboard")
                    }
                }

                Button(action: {
                    if isGenerating {
                        onStop()
                    } else {
                        onSend()
                        isFocused.wrappedValue = false
                        hideKeyboard()
                    }
                }) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(sendButtonColor())
                }
                .disabled(sendButtonDisabled())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(styleManager.tokens.background)
    }

    private func sendButtonDisabled() -> Bool {
        if isGenerating { return false }
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = trimmedInput.isEmpty
        return isEmpty || isSendDisabled
    }

    private func sendButtonColor() -> Color {
        if isGenerating { return styleManager.tokens.accent }
        return sendButtonDisabled() ? styleManager.tokens.secondaryForeground : styleManager.tokens.accent
    }
}

// MARK: - Chat Document Preview Component
private struct ChatDocumentPreviewView: View {
    let preview: DocumentProcessor.PickedDocumentPreview
    let isGenerating: Bool
    let onSend: () -> Void
    let onClear: () -> Void
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        HStack(spacing: 12) {
            if let data = preview.imageThumbnail, let uiImage = imageFromData(data) {
                #if os(iOS)
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                #elseif os(macOS)
                Image(nsImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                #endif
            } else {
                Image(systemName: preview.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(styleManager.tokens.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(preview.fileName)
                    .font(.subheadline)
                    .foregroundColor(styleManager.tokens.onBackground)
                Text(preview.fileType)
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.secondaryForeground)
            }
            
            Spacer()
            
            if isGenerating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Button(action: onSend) {
                    Label("Send to Model", systemImage: "arrowshape.turn.up.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
            
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(styleManager.tokens.background.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    private func imageFromData(_ data: Data) -> PlatformImage? {
        #if os(iOS)
        return UIImage(data: data)
        #elseif os(macOS)
        return NSImage(data: data)
        #else
        return nil
        #endif
    }
}

// MARK: - Keyboard Helpers

#if canImport(UIKit)
private struct InteractiveKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

private extension View {
    func interactiveKeyboardDismiss() -> some View {
        modifier(InteractiveKeyboardDismissModifier())
    }
}

fileprivate func hideKeyboard() {
    DispatchQueue.main.async {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
#elseif canImport(AppKit)
private extension View {
    func interactiveKeyboardDismiss() -> some View { self }
}

fileprivate func hideKeyboard() {
    DispatchQueue.main.async {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
#else
private extension View {
    func interactiveKeyboardDismiss() -> some View { self }
}

fileprivate func hideKeyboard() {}
#endif

// MARK: - Chat Model Picker Component
private struct ChatModelPickerView: View {
    let availableModels: [ModelConfiguration]
    let downloadingModels: Set<String>
    let downloadProgress: [String: Double]
    let onSelect: (ModelConfiguration) -> Void
    @EnvironmentObject var styleManager: StyleManager

    // Access shared bytes maps for richer progress labels
    private let downloadManager = ModelDiscoveryManager.shared

    var body: some View {
        #if os(macOS)
        NavigationStack {
            List(availableModels, id: \.hubId) { model in
                ChatModelRowView(
                    model: model,
                    isDownloading: downloadingModels.contains(model.hubId),
                    progress: downloadProgress[model.hubId] ?? 0,
                    downloadedBytes: downloadManager.downloadedBytesByModel[model.hubId],
                    totalBytes: downloadManager.totalBytesByModel[model.hubId],
                    onSelect: { onSelect(model) }
                )
                .task { await downloadManager.prefetchTotalBytes(for: model.hubId) }
            }
            .navigationTitle("Select Model")
            .frame(minWidth: 640, minHeight: 360)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    CloseSheetButton()
                }
            }
        }
        #else
        NavigationView {
            List(availableModels, id: \.hubId) { model in
                ChatModelRowView(
                    model: model,
                    isDownloading: downloadingModels.contains(model.hubId),
                    progress: downloadProgress[model.hubId] ?? 0,
                    downloadedBytes: downloadManager.downloadedBytesByModel[model.hubId],
                    totalBytes: downloadManager.totalBytesByModel[model.hubId],
                    onSelect: { onSelect(model) }
                )
                .task { await downloadManager.prefetchTotalBytes(for: model.hubId) }
            }
            .navigationTitle("Select Model")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #endif
    }
}

// MARK: - Chat Model Row Component
private struct ChatModelRowView: View {
    let model: ModelConfiguration
    var isDownloading: Bool = false
    var progress: Double = 0
    var downloadedBytes: Int64? = nil
    var totalBytes: Int64? = nil
    let onSelect: () -> Void
    @EnvironmentObject var styleManager: StyleManager
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundColor(styleManager.tokens.onBackground)
                    
                    HStack(spacing: 6) {
                        Text(model.displaySize)
                            .font(.caption)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                        Text("•")
                            .font(.caption)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                        Text(model.architecture ?? "LLM")
                            .font(.caption)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                }
                
                Spacer()
                
                if isDownloading {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 140)
                        Text(progressLabel)
                            .font(.caption2)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var progressLabel: String {
        if let total = totalBytes, total > 0, let downloaded = downloadedBytes {
            return "\(formatBytes(downloaded)) / \(formatBytes(total)) (\(Int((progress * 100).rounded()))%)"
        }
        return "\(Int((progress * 100).rounded()))%"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Download Banner
private struct ChatDownloadBanner: View {
    let modelIds: [String]
    let progress: [String: Double]
    let bytesDownloaded: [String: Int64]
    let totalBytes: [String: Int64]
    @EnvironmentObject var styleManager: StyleManager
    private let manager = ModelDiscoveryManager.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(modelIds, id: \.self) { id in
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(styleManager.tokens.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Downloading \(id.components(separatedBy: "/").last ?? id)")
                            .font(.caption)
                            .foregroundColor(styleManager.tokens.onBackground)
                        ProgressView(value: progress[id] ?? 0)
                            .progressViewStyle(.linear)
                        Text(progressLabel(id))
                            .font(.caption2)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                        if let status = manager.activeDownloadFiles[id] {
                            Text(fileStatusDescription(status))
                                .font(.caption2)
                                .foregroundColor(styleManager.tokens.secondaryForeground)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button("Cancel") { Task { await manager.cancelDownload(modelId: id) } }
                        .buttonStyle(.bordered)
                }
                .padding(8)
                .background(styleManager.tokens.surface)
                .cornerRadius(8)
            }
        }
    }
    
    private func progressLabel(_ id: String) -> String {
        let p = progress[id] ?? 0
        if let total = totalBytes[id], total > 0, let downloaded = bytesDownloaded[id] {
            return "\(ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)) (\(Int((p * 100).rounded()))%)"
        }
        return "\(Int((p * 100).rounded()))%"
    }

    private func fileStatusDescription(_ status: ModelDiscoveryManager.ActiveDownloadFile) -> String {
        var parts: [String] = []
        if status.total > 0 {
            parts.append("File \(status.index)/\(status.total)")
        } else {
            parts.append("File \(status.index)")
        }
        parts.append(status.name)
        if let downloaded = status.downloadedBytes, let total = status.totalBytes, total > 0 {
            let downloadedString = ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)
            let totalString = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            parts.append("\(downloadedString) / \(totalString)")
        } else if let total = status.totalBytes, total > 0 {
            let totalString = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            parts.append(totalString)
        }
        if let progress = status.progress {
            parts.append("\(Int(progress * 100))%")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Readiness Banner
private struct ChatReadinessBanner: View {
    let status: ChatViewModel.ReadinessStatus
    @EnvironmentObject var styleManager: StyleManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                iconView
                    .frame(width: 20, height: 20)

                Text(status.message.isEmpty ? "Preparing chat session…" : status.message)
                    .font(.caption)
                    .foregroundColor(styleManager.tokens.onBackground)
                    .lineLimit(2)

                Spacer()

                if let label = progressLabel {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(styleManager.tokens.secondaryForeground)
                }
            }

            if let progressValue = status.progress {
                ProgressView(value: normalized(progressValue))
                    .progressViewStyle(.linear)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(styleManager.tokens.surface)
        )
    }

    @ViewBuilder
    private var iconView: some View {
        if status.showsActivity {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        } else if status.blocksSending {
            Image(systemName: "clock")
                .foregroundColor(styleManager.tokens.accent)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(styleManager.tokens.accent)
        }
    }

    private var progressLabel: String? {
        guard let progressValue = status.progress else { return nil }
        let normalizedValue = normalized(progressValue)
        let percentage = Int((normalizedValue * 100).rounded())
        return "\(percentage)%"
    }

    private func normalized(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}

// MARK: - Close Sheet Button
private struct CloseSheetButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("Close") { dismiss() }
        .keyboardShortcut(.cancelAction)
    }
}

// MARK: - Chat Prompt Sheet Component
private struct ChatPromptSheet: View {
    let title: String
    let placeholder: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var text: String = ""
    
    var body: some View {
        #if os(macOS)
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField(placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        #if os(iOS)
                        .background(Color(.systemGray6))
                        #elseif os(macOS)
                        .background(Color(NSColor.windowBackgroundColor))
                        #endif
                        .cornerRadius(12)
                        .lineLimit(1...5)
                        .onSubmit(submitText)
                }
                
                Spacer()
                
                Button(action: submitText) {
                    Text("Submit")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        #if os(iOS)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                   Color(.systemGray3) : Color(.systemBlue))
                        #elseif os(macOS)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                   Color(NSColor.systemGray) : Color(NSColor.systemBlue))
                        #endif
                        .cornerRadius(12)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
            #if os(iOS)
            .background(Color(.systemBackground))
            #elseif os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #endif
            .navigationTitle(title)
            .onAppear { text = "" }
        }
        #else
        NavigationView {
            VStack(spacing: 24) {
                #if os(macOS)
                HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                }
                #endif
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField(placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        #if os(iOS)
                        .background(Color(.systemGray6))
                        #elseif os(macOS)
                        .background(Color(NSColor.windowBackgroundColor))
                        #endif
                        .cornerRadius(12)
                        .lineLimit(1...5)
                        .onSubmit(submitText)
                }
                
                Spacer()
                
                Button(action: submitText) {
                    Text("Submit")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        #if os(iOS)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                   Color(.systemGray3) : Color(.systemBlue))
                        #elseif os(macOS)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                   Color(NSColor.systemGray) : Color(NSColor.systemBlue))
                        #endif
                        .cornerRadius(12)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
            #if os(iOS)
            .background(Color(.systemBackground))
            #elseif os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #endif
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel)
                    .foregroundColor(.blue)
            )
            #elseif os(macOS)
            // Toolbar disabled to avoid ambiguity; using inline Cancel button instead
            #endif
            .onAppear { text = "" }
        }
        #endif
    }
    
    private func submitText() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        onSubmit(trimmedText)
    }
}

// MARK: - Platform Image Type Alias
#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif

// MARK: - Model Configuration Extension
extension ModelConfiguration {
    var displaySize: String {
        if let sizeGB = estimatedSizeGB {
            return String(format: "%.1f GB", sizeGB)
        } else {
            return "Unknown size"
        }
    }
} 
