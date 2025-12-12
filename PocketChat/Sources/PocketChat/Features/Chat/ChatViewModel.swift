// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/ChatViewModel.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ChatViewModel: ObservableObject {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/ChatView.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/DocumentPickerView.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/ModelManager.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/DocumentProcessor.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/ChatOperations.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import AIDevLogger
@preconcurrency import MLXEngine
import Combine
import UniformTypeIdentifiers // Added for UTType

#if os(iOS)
import UIKit
import PDFKit
#elseif os(macOS)
import AppKit
import PDFKit
#endif

@MainActor
class ChatViewModel: ObservableObject {
    private let logger = Logger(label: "ChatViewModel")
    
    // MARK: - Component Managers

    private let modelManager = ModelManager()
    private let chatOperations = ChatOperations()
    private let documentProcessor = DocumentProcessor()

    struct ReadinessStatus: Equatable {
        let isActive: Bool
        let message: String
        let progress: Double?
        let showsActivity: Bool

        static let inactive = ReadinessStatus(isActive: false, message: "", progress: nil, showsActivity: false)

        static func active(message: String, progress: Double?, showsActivity: Bool) -> ReadinessStatus {
            ReadinessStatus(isActive: true, message: message, progress: progress, showsActivity: showsActivity)
        }
    }
    // MARK: - Published State (Delegated to Components)

    // Model state
    @Published var availableModels: [ModelConfiguration] = []
    @Published var selectedModel: ModelConfiguration?
    @Published var downloadedModels: Set<String> = []
    @Published var downloadingModels: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]

    // Chat state
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var streamingText: String = ""
    @Published var streamingPerformance: ChatMessage.PerformanceInfo?
    @Published var readinessStatus: ReadinessStatus = .inactive

    // UI state
    @Published var errorMessage: String?
    @Published var showDownloadPrompt: Bool = false
    @Published var pendingDownloadModel: ModelConfiguration?
    @Published var activationNotice: String?
    
    // New state for Vision and Embedding prompt sheets
    @Published var showVisionPromptSheet: Bool = false
    @Published var showEmbeddingPromptSheet: Bool = false
    
    // Document picker state
    @Published var showDocumentPicker: Bool = false

    // History state
    @Published var showHistorySheet: Bool = false
    @Published var chatHistory: [ChatHistoryEntry] = []
    
    // Preview info for picked document
    @Published var pickedDocumentPreview: DocumentProcessor.PickedDocumentPreview?
    
    // Private state
    private var currentGenerationTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var hasPerformedInitialSetup: Bool = false
    private var readinessCompletionWorkItem: DispatchWorkItem?
    private let readinessMinimumDisplayDuration: TimeInterval = 1.8
    private var readinessVisibleUntil: Date?
    private let historyStore = ChatHistoryStore.shared
    private var activeHistoryEntryID: UUID?
    
    init() {
        setupComponentCallbacks()
        setupNotificationObservers()
        Task { await ensureInitialSetup() }
        Task { await loadChatHistory() }
    }
    
    private func setupNotificationObservers() {
        // Listen for notification to refresh downloaded models
        NotificationCenter.default.publisher(for: .refreshDownloadedModels)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let modelId = notification.object as? String {
                    self.logger.info("🔄 Received refresh notification for model", context: Logger.Context([
                        "modelId": modelId
                    ]))
                }
                Task {
                    await self.modelManager.checkDownloadedModels()
                    // After refreshing, rehydrate to activate if the model is now available
                    await self.rehydrateSelectionAndEnsureSession(shouldUpdateReadiness: false)
                }
            }
            .store(in: &cancellables)
    }

    private func normalizedHubId(_ id: String) -> String {
        ModelDiscoveryManager.normalizedHubId(from: id) ?? id
    }

    func ensureInitialSetup() async {
        guard !hasPerformedInitialSetup else { return }
        hasPerformedInitialSetup = true

        let start = Date()
        logger.info("Initial setup started")

        updateReadiness(message: "Loading available models…", progress: 0.2, showsActivity: true)
        await modelManager.loadAvailableModels()
        logDuration("Loaded available models", since: start)

        updateReadiness(message: "Checking downloaded models…", progress: 0.45, showsActivity: true)
        await modelManager.checkDownloadedModels()
        logDuration("Checked downloaded models", since: start)

        updateReadiness(message: "Restoring chat session…", progress: 0.7, showsActivity: true)
        await rehydrateSelectionAndEnsureSession(shouldUpdateReadiness: true)
        logDuration("Rehydrated selection and ensured session", since: start)

        if ChatSessionManager.shared.getCurrentSession() != nil {
            await markReady()
        }

        logDuration("Initial setup completed", since: start)
    }

    /// Rehydrate saved selection and ensure a working session.
    /// This makes Chat resilient when switching tabs or after app relaunch.
    func rehydrateSelectionAndEnsureSession(shouldUpdateReadiness: Bool = false) async {
        let start = Date()
        logger.info("Rehydrate selection started | shouldUpdateReadiness=\(shouldUpdateReadiness)")
        defer { logDuration("Rehydrate selection completed", since: start) }

        // 1) If there is a saved selection, prefer it
        if let savedId = UserDefaults.standard.string(forKey: "lastSelectedModelHubId"), !savedId.isEmpty {
            let normalizedSaved = normalizedHubId(savedId)
            let currentNormalized = selectedModel.map { normalizedHubId($0.hubId) }

            // If current selection differs or is missing, select by id (will initialize if downloaded)
            if currentNormalized != Optional(normalizedSaved) {
                if shouldUpdateReadiness {
                    updateReadiness(message: "Loading saved model…", progress: 0.75, showsActivity: true)
                }
                await selectModelById(normalizedSaved, forInitialSetup: shouldUpdateReadiness)
                return
            }

            // If selection matches, ensure an active session exists
            if let current = selectedModel {
                do {
                    if shouldUpdateReadiness {
                        updateReadiness(message: "Preparing chat session…", progress: 0.82, showsActivity: true)
                    }
                    try await ensureSessionOffMainActor(for: current)
                    errorMessage = nil
                    showActivationToast(for: normalizedSaved)
                } catch {
                    // If ensuring the session fails, fall back to a smaller downloaded model
                    await modelManager.checkDownloadedModels()
                    let smallerDownloaded = availableModels
                        .filter {
                            downloadedModels.contains(normalizedHubId($0.hubId)) &&
                            normalizedHubId($0.hubId) != normalizedSaved
                        }
                        .sorted { ($0.estimatedSizeGB ?? 10.0) < ($1.estimatedSizeGB ?? 10.0) }
                        .first
                    if let fallback = smallerDownloaded {
                        if shouldUpdateReadiness {
                            updateReadiness(message: "Switching to \(fallback.name)…", progress: 0.82, showsActivity: true)
                        }
                        await selectModel(fallback, forInitialSetup: shouldUpdateReadiness)
                    } else {
                        // No downloaded alternatives; keep the error visible
                        errorMessage = "Failed to load \(current.name). Please try downloading a smaller model."
                        if shouldUpdateReadiness {
                            updateReadiness(message: "Select a model to begin", progress: nil, showsActivity: false)
                        }
                    }
                }
            }
            return
        }

        // 2) No saved selection: pick a downloaded model if available, else smallest available
        await modelManager.checkDownloadedModels()
        if let firstDownloaded = availableModels.first(where: { downloadedModels.contains(normalizedHubId($0.hubId)) }) {
            if shouldUpdateReadiness {
                updateReadiness(message: "Activating \(firstDownloaded.name)…", progress: 0.82, showsActivity: true)
            }
            await selectModel(firstDownloaded, forInitialSetup: shouldUpdateReadiness)
            return
        }

        // 3) As a last resort, if we have any models, select the smallest by estimated size
        if let smallest = availableModels.sorted(by: { ($0.estimatedSizeGB ?? 10.0) < ($1.estimatedSizeGB ?? 10.0) }).first {
            if shouldUpdateReadiness {
                updateReadiness(message: "Activating \(smallest.name)…", progress: 0.82, showsActivity: true)
            }
            await selectModel(smallest, forInitialSetup: shouldUpdateReadiness)
        } else if shouldUpdateReadiness {
            updateReadiness(message: "Select a model to begin", progress: nil, showsActivity: false)
        }
    }

    private func updateReadiness(message: String, progress: Double?, showsActivity: Bool) {
        logger.notice("Readiness update | message='\(message)' progress=\(progress ?? -1) activity=\(showsActivity)")
        let progressText = progress.map { String(format: "%.2f", $0) } ?? "nil"
        AppLogger.shared.info(
            "ChatReadiness",
            "status=\(message) progress=\(progressText) activity=\(showsActivity)"
        )
        readinessCompletionWorkItem?.cancel()
        readinessCompletionWorkItem = nil

        let minimumVisibleUntil = Date().addingTimeInterval(readinessMinimumDisplayDuration)
        if let currentVisibleUntil = readinessVisibleUntil {
            readinessVisibleUntil = max(currentVisibleUntil, minimumVisibleUntil)
        } else {
            readinessVisibleUntil = minimumVisibleUntil
        }

        readinessStatus = .active(message: message, progress: progress, showsActivity: showsActivity)
    }

    private func markReady() async {
        let start = Date()
        logger.info("Mark ready started")
        readinessCompletionWorkItem?.cancel()
        updateReadiness(message: "Ready to chat", progress: 1.0, showsActivity: false)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.readinessStatus = .inactive
            self.readinessVisibleUntil = nil
        }
        readinessCompletionWorkItem = workItem

        let targetDate = readinessVisibleUntil ?? Date().addingTimeInterval(readinessMinimumDisplayDuration)
        let remaining = max(0, targetDate.timeIntervalSinceNow)

        if remaining > 0 {
            let nanoseconds = UInt64(remaining * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }

        if !workItem.isCancelled {
            DispatchQueue.main.async(execute: workItem)
        }

        logDuration("Mark ready completed", since: start)
    }

    private func logDuration(_ message: String, since startDate: Date) {
        let elapsed = Date().timeIntervalSince(startDate)
        logger.info("\(message) | elapsed=\(String(format: "%.2f", elapsed))s")
    }

    // Offload session verification so the main actor can keep handling UI work.
    private func ensureSessionOffMainActor(for model: ModelConfiguration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    _ = try await ChatSessionManager.shared.ensureSession(for: model)
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    continuation.resume(returning: ())
                } catch is CancellationError {
                    continuation.resume(throwing: CancellationError())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Activation Toast
    private func showTransientNotice(_ message: String, duration: TimeInterval = 1.5) {
        activationNotice = message
        Task { [weak self] in
            let delay = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                guard let self, self.activationNotice == message else { return }
                self.activationNotice = nil
            }
        }
    }

    private func showActivationToast(for hubId: String) {
        let identifier = hubId.components(separatedBy: "/").last ?? hubId
        showTransientNotice("Activated: \(identifier)")
    }

    private func setupComponentCallbacks() {
        // Model manager callbacks
        modelManager.$availableModels.assign(to: &$availableModels)
        modelManager.$selectedModel.assign(to: &$selectedModel)
        modelManager.$downloadedModels.assign(to: &$downloadedModels)
        modelManager.$downloadingModels.assign(to: &$downloadingModels)
        modelManager.$downloadProgress.assign(to: &$downloadProgress)
        modelManager.$errorMessage.assign(to: &$errorMessage)
        modelManager.$showDownloadPrompt.assign(to: &$showDownloadPrompt)
        modelManager.$pendingDownloadModel.assign(to: &$pendingDownloadModel)

        // Chat operations callbacks
        chatOperations.onMessagesUpdated = { [weak self] messages in
            guard let self else { return }
            self.messages = messages
            if !self.isGenerating {
                self.scheduleHistoryPersist()
            }
        }
        chatOperations.onGenerationStateChanged = { [weak self] isGenerating in
            guard let self else { return }
            self.isGenerating = isGenerating
            if !isGenerating {
                self.scheduleHistoryPersist()
            }
        }
        chatOperations.onStreamingTextUpdated = { [weak self] streamingText in
            self?.streamingText = streamingText
        }
        chatOperations.onStreamingMetricsUpdated = { [weak self] performance in
            self?.streamingPerformance = performance
        }
        chatOperations.onErrorMessageUpdated = { [weak self] errorMessage in
            self?.errorMessage = errorMessage
        }

        // Document processor callbacks
        documentProcessor.onMessagesUpdated = { [weak self] messages in
            guard let self else { return }
            self.messages = messages
            if !self.isGenerating {
                self.scheduleHistoryPersist()
            }
        }
        documentProcessor.onGenerationStateChanged = { [weak self] isGenerating in
            guard let self else { return }
            self.isGenerating = isGenerating
            if !isGenerating {
                self.scheduleHistoryPersist()
            }
        }
        documentProcessor.onErrorMessageUpdated = { [weak self] errorMessage in
            self?.errorMessage = errorMessage
        }
    }

    // MARK: - Model Management (Delegated)

    func loadAvailableModels() async {
        await modelManager.loadAvailableModels()
    }

    func checkDownloadedModels() async {
        await modelManager.checkDownloadedModels()
    }
    
    func selectModel(_ model: ModelConfiguration, forInitialSetup: Bool = false) async {
        logger.info("selectModel invoked | model=\(model.hubId) initialSetup=\(forInitialSetup)")
        if forInitialSetup {
            updateReadiness(message: "Activating \(model.name)…", progress: 0.88, showsActivity: true)
        }

        await modelManager.selectModel(model, forInitialSetup: forInitialSetup)

        let normalizedId = normalizedHubId(model.hubId)
        // If the session is active for this model, show activation toast
        if let cur = ChatSessionManager.shared.getCurrentModel(), normalizedHubId(cur.hubId) == normalizedId {
            showActivationToast(for: normalizedId)
        }

        if !forInitialSetup, ChatSessionManager.shared.getCurrentSession() != nil {
            await markReady()
        }
    }

    func selectModelById(_ hubId: String, forInitialSetup: Bool = false) async {
        logger.info("selectModelById invoked | id=\(hubId) initialSetup=\(forInitialSetup)")
        let normalizedId = normalizedHubId(hubId)
        if forInitialSetup {
            updateReadiness(message: "Activating \(normalizedId.components(separatedBy: "/").last ?? normalizedId)…", progress: 0.88, showsActivity: true)
        }

        await modelManager.selectModelById(normalizedId, forInitialSetup: forInitialSetup)
        if let cur = ChatSessionManager.shared.getCurrentModel(), normalizedHubId(cur.hubId) == normalizedId {
            showActivationToast(for: normalizedId)
        }

        if !forInitialSetup, ChatSessionManager.shared.getCurrentSession() != nil {
            await markReady()
        }
    }

    func downloadModel(_ model: ModelConfiguration) async {
        await modelManager.downloadModel(model)
    }

    // MARK: - Chat Operations (Delegated)
    
    func sendMessage() async {
        if pickedDocumentPreview != nil {
            await sendPickedDocumentToModel()
            return
        }

        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        await chatOperations.sendMessage(text: trimmedInput, selectedModel: selectedModel)
        inputText = "" // Clear input after sending
        scheduleHistoryPersist()
    }

    func regenerateLastResponse() {
        chatOperations.regenerateLastResponse()
    }

    func stopGeneration() {
        chatOperations.stopGeneration()
    }

    // MARK: - Document Processing (Delegated)

    func handlePickedDocument(url: URL) {
        documentProcessor.handlePickedDocument(url: url)
        pickedDocumentPreview = documentProcessor.pickedDocumentPreview
    }

    private func ensureVisionModelSelected() -> ModelConfiguration? {
        if let current = selectedModel, current.supportsVision {
            return current
        }

        let recommended = ModelRegistry.defaultModel(for: .vlm, preferSmallerModels: true)

        if let current = selectedModel {
            if let recommended {
                showVisionRecommendation(current: current, recommended: recommended)
            } else {
                let fallback = "Qwen-VL-2B"
                errorMessage = "\(current.name) doesn't support vision. Add or download \(fallback) to continue."
                showTransientNotice("Vision requires \(fallback)", duration: 3.0)
            }
        } else if let recommended {
            showVisionRecommendation(current: nil, recommended: recommended)
        } else {
            let fallback = "Qwen-VL-2B"
            errorMessage = "Select a vision-capable model such as \(fallback) before using image analysis."
            showTransientNotice("Vision requires \(fallback)", duration: 3.0)
        }

        return nil
    }

    private func showVisionRecommendation(current: ModelConfiguration?, recommended: ModelConfiguration) {
        let appleExample = "Qwen-VL-2B"
        let suggestion = recommended.name

        if let current {
            errorMessage = "\(current.name) doesn't support vision. Switch to \(suggestion) (Apple's sample uses \(appleExample))."
        } else {
            errorMessage = "Select a vision-capable model like \(suggestion) (e.g. \(appleExample)) before running image analysis."
        }

        showTransientNotice("Vision works best with \(suggestion)", duration: 3.0)
    }

    func sendPickedDocumentToModel() async {
        documentProcessor.setMessages(chatOperations.getMessages())
        let trimmedPrompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = trimmedPrompt.isEmpty ? nil : trimmedPrompt
        if pickedDocumentPreview?.fileType == "Image" {
            guard let visionModel = ensureVisionModelSelected() else { return }
            documentProcessor.setVisionModelOverride(visionModel)
        }
        await documentProcessor.sendPickedDocumentToModel(prompt: prompt)

        if let latestError = documentProcessor.getErrorMessage() {
            errorMessage = latestError
        } else {
            errorMessage = nil
            let updatedMessages = documentProcessor.getMessages()
            chatOperations.setMessages(updatedMessages)
            messages = updatedMessages
            inputText = ""
        }

        pickedDocumentPreview = documentProcessor.pickedDocumentPreview
        scheduleHistoryPersist()
    }

    func startNewChat() {
        chatOperations.clearMessages()
        messages = []
        streamingText = ""
        errorMessage = nil
        inputText = ""
        pickedDocumentPreview = nil
        activeHistoryEntryID = nil
    }

    func resumeConversation(_ entry: ChatHistoryEntry) async {
        chatOperations.setMessages(entry.messages)
        messages = entry.messages
        streamingText = ""
        errorMessage = nil
        inputText = ""
        pickedDocumentPreview = nil
        activeHistoryEntryID = entry.id
        if let hubId = entry.modelHubId {
            await selectModelById(hubId)
        }
    }

    func deleteHistoryEntry(_ entry: ChatHistoryEntry) async {
        await historyStore.deleteEntry(id: entry.id)
        chatHistory = await historyStore.allEntries()
        if activeHistoryEntryID == entry.id {
            activeHistoryEntryID = nil
        }
    }

    func loadChatHistory() async {
        chatHistory = await historyStore.allEntries()
    }

    func clearHistory() async {
        await historyStore.clearAll()
        chatHistory = await historyStore.allEntries()
        activeHistoryEntryID = nil
    }

    private func scheduleHistoryPersist() {
        let snapshot = chatOperations.getMessages()
        guard !snapshot.isEmpty else { return }
        let entryID = activeHistoryEntryID
        let hubId = selectedModel?.hubId
        let lastMessageID = snapshot.last?.id

        Task { await self.persistConversationSnapshot(snapshot, entryID: entryID, hubId: hubId, lastMessageID: lastMessageID) }
    }

    private func persistConversationSnapshot(
        _ snapshot: [ChatMessage],
        entryID: UUID?,
        hubId: String?,
        lastMessageID: UUID?
    ) async {
        guard !snapshot.isEmpty else { return }

        let entry = await historyStore.saveConversation(
            id: entryID,
            messages: snapshot,
            modelHubId: hubId
        )

        AppLogger.shared.info(
            "ChatHistory",
            "Saved snapshot with \(snapshot.count) messages (entry: \(entry.id))"
        )

        if let lastMessageID,
           messages.last?.id == lastMessageID,
           activeHistoryEntryID == entryID {
            activeHistoryEntryID = entry.id
        } else if entryID == nil,
                    activeHistoryEntryID == nil,
                    messages.last?.id == lastMessageID {
            activeHistoryEntryID = entry.id
        }

        chatHistory = await historyStore.allEntries()
        AppLogger.shared.info("ChatHistory", "chatHistory updated with \(chatHistory.count) entries")
    }

    func generateEmbedding(phrase: String) async {
        await documentProcessor.generateEmbedding(phrase: phrase)
    }

    func describeImage(prompt: String) async {
        documentProcessor.setMessages(chatOperations.getMessages())
        if pickedDocumentPreview?.fileType == "Image" {
            guard let visionModel = ensureVisionModelSelected() else { return }
            documentProcessor.setVisionModelOverride(visionModel)
        }
        await documentProcessor.describeImage(prompt: prompt)

        if let latestError = documentProcessor.getErrorMessage() {
            errorMessage = latestError
        } else {
            errorMessage = nil
            let updatedMessages = documentProcessor.getMessages()
            chatOperations.setMessages(updatedMessages)
            messages = updatedMessages
            inputText = ""
        }

        pickedDocumentPreview = documentProcessor.pickedDocumentPreview
    }

        // MARK: - Core API Methods

    /// Compatibility property for message count
    public var messageCount: Int {
        return chatOperations.messageCount
    }

    /// Compatibility property for last message
    public var lastMessage: ChatMessage? {
        return chatOperations.lastMessage
    }

    /// Clears all messages
    public func clearMessages() {
        chatOperations.clearMessages()
    }

    public func addMessage(role: MessageRole, content: String) {
        chatOperations.addMessage(role: role, content: content)
    }

    /// Cancels all ongoing downloads and resets download state
    public func cancelAllDownloads() async {
        await modelManager.cancelAllDownloads()
    }

    /// Cancels a specific download by model id
    public func cancelDownload(for modelId: String) {
        modelManager.cancelDownload(for: modelId)
    }

    /// Dismisses the legacy download prompt UI
    public func cancelDownloadPrompt() {
        modelManager.cancelDownloadPrompt()
    }

    /// Returns a user-friendly status string for a model's download state
    public func getDownloadStatus(for model: ModelConfiguration) -> String {
        return modelManager.getDownloadStatus(for: model)
    }

    /// Remove the last message if present
    public func removeLastMessage() {
        chatOperations.removeLastMessage()
    }

    /// Reset download attempt tracking for a model id
    public func resetDownloadAttempts(for modelId: String) {
        // This method is kept for backward compatibility
        // The actual implementation is handled by ModelManager
        logger.info("Download attempts reset for model: \(modelId)")
    }

    // MARK: - Control Operations

    /// Clears the current conversation
    func clearConversation() async {
        messages.removeAll()
        streamingText = ""
        errorMessage = nil
        streamingPerformance = nil
        // Note: We don't clear the session here as it might be reused for other conversations
        logger.info("Conversation cleared")
    }

    /// Clears any error messages
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Legacy API

    // Legacy overload for tests calling sendMessage(_ prompt: String)
    func sendMessage(_ prompt: String) async {
        inputText = prompt
        await sendMessage()
    }

    // MARK: - Debug Methods

    /// Debug method to test streaming generation and identify gibberish issues
    func debugStreamingGeneration(prompt: String) async {
        // Temporarily disabled for debugging
        logger.info("🔍 Debug streaming generation temporarily disabled")
    }
}

    // Blocks send interactions whenever we are still preparing the session.
    // Allows typing once the spinner finishes and progress reaches 100%.
    extension ChatViewModel.ReadinessStatus {
        var blocksSending: Bool {
            guard isActive else { return false }
            let normalizedProgress = progress ?? 0.0
            return showsActivity || normalizedProgress < 1.0
        }
    }
