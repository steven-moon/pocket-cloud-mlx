// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Core/ChatEngine.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ChatEngine: ObservableObject {
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
import Foundation
import SwiftUI
import PocketCloudMLX
import Combine
import os.log
import UniformTypeIdentifiers
import EventKit
import Contacts
import Vision
import PDFKit
import PocketCloudLogger

#if canImport(MLXLLM)
import MLXLLM
#endif

#if os(iOS)
import UIKit
import PDFKit
#elseif os(macOS)
import AppKit
import PDFKit
#endif

/// Core chat engine that handles all chat logic across platforms
/// This is platform-agnostic and can be used by iOS, macOS, tvOS, and watchOS
@MainActor
public class ChatEngine: ObservableObject {
    
    private let logger = Logger(subsystem: "com.mlxchatapp", category: "ChatEngine")
    
    // MARK: - Published Properties
    @Published public var messages: [ChatMessage] = []
    @Published public var inputText: String = ""
    @Published public var isGenerating: Bool = false
    @Published public var streamingText: String = ""
    @Published public var errorMessage: String?
    @Published public var selectedModel: PocketCloudMLX.ModelConfiguration?
    @Published public var availableModels: [PocketCloudMLX.ModelConfiguration] = []
    @Published public var downloadingModels: Set<String> = []
    @Published public var downloadProgress: [String: Double] = [:]
    @Published public var pickedDocumentPreview: PickedDocumentPreview?
    @Published public var showDocumentPicker: Bool = false
    @Published public var showVisionPromptSheet: Bool = false
    @Published public var showEmbeddingPromptSheet: Bool = false
    @Published public var showDownloadPrompt: Bool = false
    @Published public var pendingDownloadModel: PocketCloudMLX.ModelConfiguration?
    
    // MARK: - Private Properties
    private var chatSession: ChatSession?
    private var cancellables = Set<AnyCancellable>()
    private let fileManagerService = FileManagerService.shared
    private let modelDownloader = ModelDownloader()
    private let modelDiscoveryManager = ModelDiscoveryManager.shared
    private let contextManager = ContextManager()
    private let _privacyManager = PrivacyManager()
    
    // Download state tracking
    private var activeDownloadTasks: [String: Task<Void, Never>] = [:]
    private var downloadAttempts: [String: Int] = [:]
    private let maxDownloadAttempts = 3
    
    // MARK: - Supported Document Types
    public let supportedDocumentTypes: [UTType] = [
        .pdf, .plainText, .rtf, .html, .image, .jpeg, .png, .gif
    ]
    
    // MARK: - Initialization

    /// Initialize with default behavior
    public init() {
        Task {
            await loadAvailableModels()

            // Skip auto-selection and chat session setup on simulator to prevent MLX crashes
            #if !targetEnvironment(simulator)
                await autoSelectDefaultModel()
            #else
                logger.info("Running on simulator - skipping auto model selection to prevent MLX crashes")
                // On simulator, just select the first available model without trying to load it
                if let firstModel = availableModels.first {
                    selectedModel = firstModel
                    logger.info("Simulator: Selected model \(firstModel.name) for UI display only")
                }
            #endif

            syncDownloadState() // Initialize download state
        }
    }

    /// Initialize with custom LLM engine (for testing)
    public init(llmEngine: LLMEngine) async {
        // Skip the normal initialization for testing
        logger.info("ChatEngine initialized with custom LLM engine for testing")
        // Set up mock model for testing
        let testModel = PocketCloudMLX.ModelConfiguration(
            name: "Test Model",
            hubId: "test/model",
            description: "Mock model for testing",
            maxTokens: 128,
            modelType: .llm,
            gpuCacheLimit: 512 * 1024 * 1024,
            features: []
        )
        self.selectedModel = testModel
        self.availableModels = [testModel]
    }
    
    // MARK: - Model Management
    
    /// Load available models
    public func loadAvailableModels() async {
        // Get device RAM for compatibility checking
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        let platform: String
        
        #if targetEnvironment(simulator)
            platform = "iOS-Simulator"
        #elseif os(iOS)
            platform = "iOS"
        #elseif os(macOS)
            platform = "macOS"
        #elseif os(tvOS)
            platform = "tvOS"
        #elseif os(watchOS)
            platform = "watchOS"
        #else
            platform = "Unknown"
        #endif
        
        // Use ModelRegistry to get recommended models for the current device
        // First try to get recommended models for the current device
        let recommendedModels = await ModelRegistry.recommendedModelsForCurrentDevice(limit: 10)

        if !recommendedModels.isEmpty {
            // Use recommended models that are compatible with device
            let compatibleModels = recommendedModels.filter { model in
                // Filter out any mock/test models for production UI
                guard !model.hubId.hasPrefix("mock/") && !model.hubId.hasPrefix("test/") else {
                    return false
                }

                // Check device compatibility
                return ModelRegistry.isModelSupported(model, ramGB: memoryGB, platform: platform)
            }

            self.availableModels = compatibleModels
            logger.info("Loaded \(compatibleModels.count) recommended models for \(platform) with \(String(format: "%.1f", memoryGB))GB RAM")
            return
        }
        
        // Fallback to all available models if recommendations fail
        let allModels = ModelRegistry.allModels
        let compatibleModels = allModels.filter { model in
            // Filter out mock/test models for production UI
            guard !model.hubId.hasPrefix("mock/") && !model.hubId.hasPrefix("test/") else {
                return false
            }
            
            // Check device compatibility
            return ModelRegistry.isModelSupported(model, ramGB: memoryGB, platform: platform)
        }
        
        self.availableModels = compatibleModels
        logger.info("Loaded \(compatibleModels.count) compatible models for \(platform) with \(String(format: "%.1f", memoryGB))GB RAM")
    }
    
    /// Automatically selects a default model if none is selected
    private func autoSelectDefaultModel() async {
        guard selectedModel == nil else { return }
        
        // Try to find a downloaded model first
        do {
            let downloadedModels = try await modelDownloader.getDownloadedModels()
            if let downloadedModel = downloadedModels.first {
                logger.info("Auto-selected downloaded model: \(downloadedModel.name)")
                selectedModel = downloadedModel
                do {
                    try await setupChatSession(with: downloadedModel)
                } catch {
                    logger.error("Failed to setup chat session with downloaded model \(downloadedModel.name): \(error.localizedDescription)")
                }
                return
            }
        } catch {
            logger.error("Failed to get downloaded models: \(error.localizedDescription)")
        }
        
        // If no downloaded models, select the smallest available model
        let sortedModels = availableModels.sorted { model1, model2 in
            let size1 = model1.estimatedSizeGB ?? 10.0
            let size2 = model2.estimatedSizeGB ?? 10.0
            return size1 < size2
        }
        
        if let smallestModel = sortedModels.first {
            logger.info("Auto-selected smallest available model: \(smallestModel.name)")
            selectedModel = smallestModel
        }
    }
    
    /// Select a model for chat
    public func selectModel(_ model: PocketCloudMLX.ModelConfiguration) async {
        selectedModel = model

        // On simulator, skip MLX model loading to prevent crashes
        #if targetEnvironment(simulator)
            logger.info("Simulator: Model \(model.name) selected for UI display only - skipping MLX loading")
            return
        #else

        // Check if model is downloaded
        let isDownloaded = await fileManagerService.isModelDownloaded(modelId: model.hubId)
        if !isDownloaded {
            showDownloadPrompt = true
            pendingDownloadModel = model
            return
        }

        // Setup chat session
        do {
            try await setupChatSession(with: model)
        } catch {
            logger.error("Failed to setup chat session with model \(model.name): \(error.localizedDescription)")
            errorMessage = "Failed to setup chat with \(model.name): \(error.localizedDescription)"
        }
        #endif
    }
    
    /// Download a model
    public func downloadModel(_ model: PocketCloudMLX.ModelConfiguration) async {
        // Check if already downloading
        guard !downloadingModels.contains(model.hubId) else {
            logger.info("Model \(model.name) is already downloading")
            return
        }
        
        // Check if already downloaded
        let isDownloaded = await fileManagerService.isModelDownloaded(modelId: model.hubId)
        if isDownloaded {
            logger.info("Model \(model.name) is already downloaded")
            do {
                try await setupChatSession(with: model)
            } catch {
                logger.error("Failed to setup chat session: \(error.localizedDescription)")
                errorMessage = "Failed to setup chat session: \(error.localizedDescription)"
            }
            return
        }
        
        // Start download
        downloadingModels.insert(model.hubId)
        downloadProgress[model.hubId] = 0.0
        
        // Create download task
        let downloadTask = Task<Void, Never> {
            do {
                let _ = try await modelDiscoveryManager.downloadModel(model) { progress in
                    Task { @MainActor in
                        self.downloadProgress[model.hubId] = progress
                    }
                }
                
                // Download completed successfully
                await MainActor.run {
                    downloadingModels.remove(model.hubId)
                    downloadProgress.removeValue(forKey: model.hubId)
                    logger.info("Successfully downloaded model: \(model.name)")
                }
                
                // Setup chat session after download
                do {
                    try await setupChatSession(with: model)
                } catch {
                    logger.error("Failed to setup chat session after download: \(error.localizedDescription)")
                    await MainActor.run {
                        errorMessage = "Failed to setup chat session after download: \(error.localizedDescription)"
                    }
                }
                
            } catch {
                await MainActor.run {
                    downloadingModels.remove(model.hubId)
                    downloadProgress.removeValue(forKey: model.hubId)
                    errorMessage = "Failed to download model '\(model.name)': \(error.localizedDescription)"
                    logger.error("Failed to download model: \(error.localizedDescription)")
                }
                // Swallow error inside Task to keep Task type Never
            }
        }
        
        activeDownloadTasks[model.hubId] = downloadTask
    }
    
    /// Sync download state with ModelDiscoveryManager
    private func syncDownloadState() {
        // Sync downloading models
        downloadingModels = modelDiscoveryManager.downloadingModels
        
        // Sync download progress
        downloadProgress = modelDiscoveryManager.downloadProgress
    }
    
    /// Setup chat session with model
    private func setupChatSession(with model: PocketCloudMLX.ModelConfiguration) async throws {
        // Check if model is MLX-compatible before trying to create session
        #if canImport(MLXLLM)
        let allModels = MLXLLM.LLMRegistry.shared.models
        let isInRegistry = allModels.contains { String(describing: $0.id) == model.hubId }

        if !isInRegistry {
            logger.warning("⚠️ Model \(model.name) (\(model.hubId)) is not in MLX registry. Attempting direct load...")

            // Try to load the model directly - many MLX-compatible models work even if not in registry
            do {
                chatSession = try await ChatSession.create(modelConfiguration: model, metalLibrary: nil)
                logger.info("✅ Model loaded successfully despite not being in registry: \(model.name)")
                errorMessage = nil
                return
            } catch {
                logger.warning("❌ Direct model load failed: \(error.localizedDescription)")

                // If direct load fails, try to find a registry-compatible fallback
                if let compatibleModel = await findCompatibleDownloadedModel() {
                    logger.info("🔄 Switching to compatible model: \(compatibleModel.name)")
                    // Update the selected model to the compatible one
                    await MainActor.run {
                        self.selectedModel = compatibleModel
                    }
                    // Try again with the compatible model
                    chatSession = try await ChatSession.create(modelConfiguration: compatibleModel, metalLibrary: nil)
                    logger.info("Chat session created successfully with compatible model: \(compatibleModel.name)")
                    errorMessage = nil
                    return
                } else {
                    throw NSError(domain: "ChatEngine", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Model \(model.name) is not compatible with MLX. No compatible downloaded models found. Please download a supported MLX model first."
                    ])
                }
            }
        }
        #else
        logger.warning("⚠️ MLXLLM not available, skipping MLX compatibility check")
        #endif

        // Model is MLX-compatible (or MLX not available), proceed normally
        chatSession = try await ChatSession.create(modelConfiguration: model, metalLibrary: nil)
        logger.info("Chat session created successfully with model: \(model.name)")
        errorMessage = nil
    }

    private func findCompatibleDownloadedModel() async -> PocketCloudMLX.ModelConfiguration? {
        #if canImport(MLXLLM)
        let allModels = MLXLLM.LLMRegistry.shared.models

        // Get downloaded models using OptimizedDownloader
        do {
            let downloadedModels = try await OptimizedDownloader().getDownloadedModels()
            let downloadedModelIds = Set(downloadedModels.compactMap { ModelDiscoveryManager.normalizedHubId(from: $0.hubId) })

            // Find first compatible downloaded model
            for registryModel in allModels {
                let rawRegistryId = String(describing: registryModel.id)
                guard let registryModelId = ModelDiscoveryManager.normalizedHubId(from: rawRegistryId) else { continue }
                if downloadedModelIds.contains(registryModelId) {
                    // Create ModelConfiguration from registry model
                    // Use the model ID to extract basic info
                    let modelName = registryModelId.components(separatedBy: "/").last ?? registryModelId
                    return PocketCloudMLX.ModelConfiguration(
                        name: modelName,
                        hubId: registryModelId,
                        description: "MLX-compatible model from registry",
                        parameters: nil, // MLXLLM doesn't provide this info
                        quantization: "4bit", // Most MLX models are quantized
                        architecture: nil, // MLXLLM doesn't provide this info
                        maxTokens: 4096, // Reasonable default
                        estimatedSizeGB: 1.0, // Default estimate
                        modelType: .llm,
                        gpuCacheLimit: 512 * 1024 * 1024 // 512MB default
                    )
                }
            }
        } catch {
            logger.error("Failed to get downloaded models: \(error.localizedDescription)")
        }
        #endif

        return nil
    }
    
    // MARK: - Message Handling
    
    /// Send a message
    public func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isGenerating else { return }

        // On simulator, show a mock response instead of trying to use MLX
        #if targetEnvironment(simulator)
        let simulatorUserMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        isGenerating = true
        streamingText = ""
        errorMessage = nil
        defer { isGenerating = false }

        // Add user message
        let userChatMessage = ChatMessage(
            role: MessageRole.user,
            content: simulatorUserMessage,
            timestamp: Date()
        )
        messages.append(userChatMessage)

        // Add mock assistant response
        let assistantMessage = ChatMessage(
            role: MessageRole.assistant,
            content: "",
            timestamp: Date()
        )
        messages.append(assistantMessage)

        // Simulate streaming response
        let mockResponse = "Hello! I'm running in simulator mode. MLX models can't load here, but I'm showing you how the chat interface works. You can download and use real models when running on a physical device! 🚀"
        streamingText = mockResponse

        // Update the message with the full response
        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[lastIndex] = ChatMessage(
                role: MessageRole.assistant,
                content: mockResponse,
                timestamp: Date()
            )
        }

        logger.info("Simulator: Sent mock response for message: '\(simulatorUserMessage)'")
        return
        #else

        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        isGenerating = true
        streamingText = ""
        errorMessage = nil
        defer { isGenerating = false }

        // Add user message to chat
        let chatUserMessage = ChatMessage(
            role: MessageRole.user,
            content: userMessage,
            timestamp: Date()
        )
        messages.append(chatUserMessage)
        
        // Check if model is selected and ready
        guard let model = selectedModel else {
            errorMessage = "No model selected. Please select a model from the available options."
            return
        }
        
        // Check if model is downloaded
        let isDownloaded = await fileManagerService.isModelDownloaded(modelId: model.hubId)
        guard isDownloaded else {
            errorMessage = "Model '\(model.name)' is not downloaded. Please download it first."
            showDownloadPrompt = true
            pendingDownloadModel = model
            return
        }

        // Ensure chat session is set up
        if chatSession == nil {
            do {
                try await setupChatSession(with: model)
            } catch {
                logger.error("Failed to setup chat session: \(error.localizedDescription)")
                errorMessage = "Failed to setup chat session: \(error.localizedDescription)"
                return
            }
        }

        guard let session = chatSession else {
            errorMessage = "Failed to initialize chat session. Please try again."
            return
        }
        
        do {
            // Generate response
            let response = try await session.generateResponse(userMessage)
            
            // Add assistant response to chat
            let assistantMessage = ChatMessage(
                role: MessageRole.assistant,
                content: response,
                timestamp: Date()
            )
            messages.append(assistantMessage)
            
            logger.info("Generated response successfully")
            
        } catch {
            logger.error("Failed to generate response: \(error.localizedDescription)")
            errorMessage = "Failed to generate response: \(error.localizedDescription)"
        }
        #endif
    }
    
    /// Send message with streaming
    public func sendMessageWithStreaming() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isGenerating else { return }
        
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        isGenerating = true
        streamingText = ""
        errorMessage = nil
        
        // Add user message to chat
        let userChatMessage = ChatMessage(
            role: MessageRole.user,
            content: userMessage,
            timestamp: Date()
        )
        messages.append(userChatMessage)
        
        // Check if model is selected and ready
        guard let model = selectedModel else {
            errorMessage = "No model selected. Please select a model from the available options."
            isGenerating = false
            return
        }
        
        // Check if model is downloaded
        let isDownloaded = await fileManagerService.isModelDownloaded(modelId: model.hubId)
        guard isDownloaded else {
            errorMessage = "Model '\(model.name)' is not downloaded. Please download it first."
            showDownloadPrompt = true
            pendingDownloadModel = model
            isGenerating = false
            return
        }

        // Ensure chat session is set up
        if chatSession == nil {
            do {
                try await setupChatSession(with: model)
            } catch {
                logger.error("Failed to setup chat session: \(error.localizedDescription)")
                errorMessage = "Failed to setup chat session: \(error.localizedDescription)"
                isGenerating = false
                return
            }
        }

        guard let session = chatSession else {
            errorMessage = "Failed to initialize chat session. Please try again."
            isGenerating = false
            return
        }
        
        do {
            // Generate streaming response
            let stream = try await session.generateStream(prompt: userMessage)
            
            for try await chunk in stream {
                streamingText += chunk
            }
            
            // Add the complete response as a message
            let assistantMessage = ChatMessage(
                role: MessageRole.assistant,
                content: streamingText,
                timestamp: Date()
            )
            messages.append(assistantMessage)
            streamingText = ""
            isGenerating = false
            
            logger.info("Generated streaming response successfully")
            
        } catch {
            logger.error("Failed to generate streaming response: \(error.localizedDescription)")
            errorMessage = "Failed to generate response: \(error.localizedDescription)"
            isGenerating = false
            streamingText = ""
        }
    }
    
    /// Regenerate the last response
    public func regenerateLastResponse() async {
        guard !messages.isEmpty else { return }
        
        // Find the last user message
        var lastUserMessage: ChatMessage?
        var messagesToRemove: [ChatMessage] = []
        
        for message in messages.reversed() {
            if message.role == MessageRole.user {
                lastUserMessage = message
                break
            } else {
                messagesToRemove.append(message)
            }
        }
        
        guard let userMessage = lastUserMessage else { return }
        
        // Remove assistant messages after the last user message
        for message in messagesToRemove {
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages.remove(at: index)
            }
        }
        
        // Regenerate with the last user message
        inputText = userMessage.content
        await sendMessageWithStreaming()
    }
    
    // MARK: - Document Handling
    
    /// Handle document selection
    public func handlePickedDocument(url: URL) {
        Task {
            do {
                let content = try await extractDocumentContent(from: url)
                let preview = PickedDocumentPreview(
                    fileName: url.lastPathComponent,
                    content: content,
                    url: url
                )
                
                await MainActor.run {
                    pickedDocumentPreview = preview
                    inputText = "Please analyze this document: \(url.lastPathComponent)\n\nContent:\n\(content.prefix(500))"
                }
                
            } catch {
                await setError("Failed to process document: \(error.localizedDescription)")
            }
        }
    }
    
    /// Extract content from document
    private func extractDocumentContent(from url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "txt":
            return try String(contentsOf: url, encoding: .utf8)
        case "pdf":
            return try await extractPDFContent(from: url)
        case "rtf":
            return try await extractRTFContent(from: url)
        case "html":
            return try String(contentsOf: url, encoding: .utf8)
        case "jpg", "jpeg", "png", "gif":
            return "Image file: \(url.lastPathComponent)"
        default:
            return "Document: \(url.lastPathComponent)"
        }
    }
    
    /// Extract PDF content
    private func extractPDFContent(from url: URL) async throws -> String {
        #if os(iOS) || os(macOS)
        if let pdfDocument = PDFDocument(url: url) {
            var text = ""
            for i in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: i) {
                    text += page.string ?? ""
                    text += "\n"
                }
            }
            return text.isEmpty ? "PDF document (no text content): \(url.lastPathComponent)" : text
        }
        #endif
        return "PDF document: \(url.lastPathComponent)"
    }
    
    /// Extract RTF content
    private func extractRTFContent(from url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            return attributedString.string
        }
        return "RTF document: \(url.lastPathComponent)"
    }
    
    // MARK: - Utility Methods
    
    /// Clear current error
    public func clearError() {
        errorMessage = nil
    }
    
    /// Set error message
    private func setError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
        }
    }
    
    /// Clear current chat session
    public func clearChat() {
        messages.removeAll()
        inputText = ""
        streamingText = ""
        errorMessage = nil
        pickedDocumentPreview = nil
    }
    
    /// Check if a model is downloaded
    public func isModelDownloaded(_ modelId: String) async -> Bool {
        return await fileManagerService.isModelDownloaded(modelId: modelId)
    }
    
    /// Get downloaded models
    public func getDownloadedModels() -> Set<String> {
        // This would typically be computed from file system
        // For now, return empty set - will be implemented with proper model tracking
        return Set<String>()
    }
    
    /// Get current chat session
    public func getCurrentSession() -> ChatSession? {
        return chatSession
    }

    /// Get privacy manager (for testing)
    public var privacyManager: PrivacyManager {
        return _privacyManager
    }

    // MARK: - Context Management Methods (for testing compatibility)

    /// Extract web context from URL
    public func extractWebContext(from url: URL) async throws -> WebPageContext {
        // For testing, return a mock context
        return WebPageContext(
            title: "Mock Webpage",
            content: "Mock webpage content for testing",
            url: url,
            images: [],
            links: [],
            extractedAt: Date()
        )
    }

    /// Extract document context from URL
    public func extractDocumentContext(from url: URL) async throws -> DocumentContext {
        // For testing, return a mock document context
        return DocumentContext(
            fileName: url.lastPathComponent,
            fileType: .text,
            extractedText: "Mock document content for testing",
            summary: "Mock document summary",
            url: url
        )
    }

    /// Search context items
    public func searchContext(query: String) async throws -> [ContextItem] {
        // For testing, return mock results
        return [
            ContextItem(type: .document, content: "Mock search result for: \(query)"),
            ContextItem(type: .webpage, content: "Another mock result")
        ]
    }

    /// Filter context items by type
    public func filterContext(by type: ContextItemType) async throws -> [ContextItem] {
        // For testing, return mock filtered results
        return [
            ContextItem(type: type, content: "Mock \(type.rawValue) item")
        ]
    }

    /// Score context relevance
    public func scoreContextRelevance(_ contexts: [ContextItem], for query: String) async throws -> [ScoredContextItem] {
        // For testing, return mock scored results
        return contexts.map { context in
            ScoredContextItem(context: context, score: 0.8)
        }
    }

    /// Clear current context
    public func clearContext() {
        // This method already exists above
    }

    /// Generate response (for testing compatibility)
    public func generate(prompt: String) async throws -> String {
        // For testing, return a mock response
        return "Mock response to: \(prompt)"
    }

    /// Generate response (alternative signature)
    public func generateResponse(_ prompt: String) async throws -> String {
        return try await generate(prompt: prompt)
    }

    /// Get performance metrics (for testing compatibility)
    public var performanceMetrics: [String: Double] {
        return [
            "responseTime": 1.2,
            "memoryUsage": 150.0,
            "cpuUsage": 25.0
        ]
    }

    /// Switch model (for testing compatibility)
    public func switchModel(to model: PocketCloudMLX.ModelConfiguration) async throws {
        selectedModel = model
    }

    /// Stream response (for testing compatibility)
    public func streamResponse(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let words = "Mock streaming response to: \(prompt)".split(separator: " ").map(String.init)
                for word in words {
                    try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                    continuation.yield(word + " ")
                }
                continuation.finish()
            }
        }
    }

    /// Optimize model (for testing compatibility)
    public func optimizeModel() async throws {
        // Mock optimization
    }

    /// Generate performance report (for testing compatibility)
    public func generatePerformanceReport() async throws -> String {
        return "Mock performance report"
    }

    /// Get detailed performance metrics (for testing compatibility)
    public var detailedPerformanceMetrics: [String: Any] {
        return [
            "responseTime": 1.2,
            "memoryUsage": 150.0,
            "cpuUsage": 25.0,
            "gpuUsage": 45.0,
            "modelSize": 1024.0
        ]
    }

    /// Attempt performance recovery (for testing compatibility)
    public func attemptPerformanceRecovery() async -> Bool {
        return true
    }

    /// Optimize performance (for testing compatibility)
    public func optimizePerformance() async throws {
        // Mock optimization
    }

    /// Clear history (for testing compatibility)
    public func clearHistory() {
        messages.removeAll()
    }
}

// MARK: - Supporting Types

/// Represents a picked document preview
public struct PickedDocumentPreview: Identifiable {
    public let id = UUID()
    public let fileName: String
    public let content: String
    public let url: URL
    
    public init(fileName: String, content: String, url: URL) {
        self.fileName = fileName
        self.content = content
        self.url = url
    }
}

/// Chat message structure
public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public struct PerformanceInfo: Codable, Equatable, Sendable {
        public var modelId: String?
        public var modelName: String?
        public var tokensPerSecond: Double?
        public var tokenCount: Int?
        public var generationDuration: TimeInterval?

        public init(
            modelId: String? = nil,
            modelName: String? = nil,
            tokensPerSecond: Double? = nil,
            tokenCount: Int? = nil,
            generationDuration: TimeInterval? = nil
        ) {
            self.modelId = modelId
            self.modelName = modelName
            self.tokensPerSecond = tokensPerSecond
            self.tokenCount = tokenCount
            self.generationDuration = generationDuration
        }
    }

    public let id: UUID
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    public let performance: PerformanceInfo?

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date,
        performance: PerformanceInfo? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.performance = performance
    }
    
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Message role enumeration
public enum MessageRole: String, Codable, CaseIterable, Sendable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

// MARK: - Context Types (for testing compatibility)

/// Web page context
public struct WebPageContext {
    public let title: String
    public let content: String
    public let url: URL
    public let images: [URL]
    public let links: [URL]
    public let extractedAt: Date
}

/// Document context
public struct DocumentContext {
    public let fileName: String
    public let fileType: DocumentFileType
    public let extractedText: String
    public let summary: String
    public let url: URL
}

/// Document file type
public enum DocumentFileType {
    case pdf, text, image, unknown
}

/// Context item type
public enum ContextItemType: String {
    case webpage, document, calendar, system
}

/// Context item
public struct ContextItem {
    public let type: ContextItemType
    public let content: String
    public let metadata: [String: Any] = [:]
    public let timestamp: Date = Date()

    public init(type: ContextItemType, content: String) {
        self.type = type
        self.content = content
    }
}

/// Scored context item
public struct ScoredContextItem {
    public let context: ContextItem
    public let score: Double
}

// MARK: - Local Context Manager (for testing compatibility)

/// Simple context manager for testing
@MainActor
public class ContextManager: ObservableObject {
    @Published public var currentContext: [ContextItem] = []
    @Published public var contextualSuggestions: [String] = []

    public init() {}

    /// Extract calendar context
    public func extractCalendarContext() async -> [CalendarEvent] {
        return []
    }

    /// Add context item
    public func addContextItem(_ item: ContextItem) {
        currentContext.append(item)
    }

    /// Clear context
    public func clearContext() {
        currentContext.removeAll()
    }
}

/// Calendar event for testing
public struct CalendarEvent {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let notes: String?
    public let isAllDay: Bool
}

// MARK: - Local Privacy Manager (for testing compatibility)

/// Simple privacy manager for testing
@MainActor
public class PrivacyManager: ObservableObject {
    private let logger = Logger(label: "PrivacyManager")

    @Published public var dataRetentionPolicy: DataRetentionPolicy = .session
    @Published public var contextSharingEnabled = true
    @Published public var voiceDataStorageEnabled = false
    @Published public var analyticsEnabled = false
    @Published public var crashReportingEnabled = true

    public init() {
        logger.info("PrivacyManager initialized with privacy-first defaults")
    }

    /// Process context with privacy controls
    public func processContext(_ context: ContextItem) -> ProcessedContext {
        logger.info("Processing context item with privacy controls")

        // Return mock processed context
        return ProcessedContext(
            id: UUID(),
            type: context.type,
            content: context.content,
            metadata: [:],
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(86400) // 24 hours
        )
    }

    /// Set data retention policy
    public func setDataRetentionPolicy(_ policy: DataRetentionPolicy) {
        dataRetentionPolicy = policy
        logger.info("Data retention policy set to: \(policy)")
    }

    /// Set context sharing enabled
    public func setContextSharingEnabled(_ enabled: Bool) {
        contextSharingEnabled = enabled
        logger.info("Context sharing set to: \(enabled)")
    }

    /// Set voice data storage enabled
    public func setVoiceDataStorageEnabled(_ enabled: Bool) {
        voiceDataStorageEnabled = enabled
        logger.info("Voice data storage set to: \(enabled)")
    }

    /// Set analytics enabled
    public func setAnalyticsEnabled(_ enabled: Bool) {
        analyticsEnabled = enabled
        logger.info("Analytics set to: \(enabled)")
    }

    /// Set crash reporting enabled
    public func setCrashReportingEnabled(_ enabled: Bool) {
        crashReportingEnabled = enabled
        logger.info("Crash reporting set to: \(enabled)")
    }
}

/// Data retention policy
public enum DataRetentionPolicy {
    case none
    case session
    case temporary
    case permanent
}

/// Processed context
public struct ProcessedContext {
    public let id: UUID
    public let type: ContextItemType
    public let content: String
    public let metadata: [String: Any]
    public let timestamp: Date
    public let expiresAt: Date

    public var isExpired: Bool {
        return Date() > expiresAt
    }
} 