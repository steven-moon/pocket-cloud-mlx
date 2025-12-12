// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/ModelManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ModelManager: ObservableObject {
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
import MLXEngine
import AIDevLogger
import Combine

/// Manages model operations including loading, selection, and downloading
@MainActor
final class ModelManager: ObservableObject {
    private let logger = Logger(label: "ModelManager")

    // Published state
    @Published var availableModels: [ModelConfiguration] = []
    @Published var downloadedModels: Set<String> = []
    @Published var downloadingModels: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var selectedModel: ModelConfiguration?
    @Published var errorMessage: String?
    @Published var showDownloadPrompt: Bool = false
    @Published var pendingDownloadModel: ModelConfiguration?

    // Private state
    private let modelDownloader = ModelDownloader()
    private let fileManagerService = FileManagerService.shared
    private var cancellables: Set<AnyCancellable> = []

    // Use the singleton ChatSessionManager to prevent race conditions
    private var chatSessionManager: ChatSessionManager { ChatSessionManager.shared }

    private func normalizedHubId(_ hubId: String) -> String {
        ModelDiscoveryManager.normalizedHubId(from: hubId) ?? hubId
    }

    // Callbacks for UI updates
    var onDownloadStateChanged: ((Set<String>, [String: Double], Bool, ModelConfiguration?) -> Void)?

    init() {
        Task {
            await loadAvailableModels()
            await checkDownloadedModels()
            // If a saved selection exists and is downloaded, init session immediately
            if let savedId = UserDefaults.standard.string(forKey: "lastSelectedModelHubId") {
                let normalizedSaved = self.normalizedHubId(savedId)
                if let model = self.availableModels.first(where: { self.normalizedHubId($0.hubId) == normalizedSaved }) {
                self.selectedModel = model
                    if self.downloadedModels.contains(normalizedSaved) {
                        await initializeChatSession(with: model)
                    }
                }
            }
        }

        // Observe downloaded model set to auto-select a usable model
        ModelDiscoveryManager.shared.$downloadedModelIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloaded in
                guard let self else { return }
                // If the currently selected model just finished downloading, initialize the session
                if let current = self.selectedModel, downloaded.contains(self.normalizedHubId(current.hubId)) {
                    Task { await self.initializeChatSession(with: current) }
                }
                // Do not auto-switch to a different model here. Respect explicit user choice.
            }
            .store(in: &cancellables)
    }

    // MARK: - Model Loading

    func loadAvailableModels() async {
        logger.info("Starting to load available models")
        do {
            // Prefer Hugging Face device-aware recommendations first
            // Increase limit for high-memory devices like M1 MacBook Pro with 64GB RAM
            let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
            let modelLimit = memoryGB >= 32 ? 50 : 20 // Show more models on high-memory devices
            
            logger.info("Fetching recommended MLX models from HuggingFace (limit: \(modelLimit))")
            let summaries = try await ModelDiscoveryService.recommendedMLXModelsForCurrentDevice(limit: modelLimit)
            logger.info("Received \(summaries.count) model recommendations from HuggingFace")
            var converted: [ModelConfiguration] = summaries.compactMap { summary -> ModelConfiguration? in
                // Filter out known embedding-only models (e.g., BGE) for chat
                let isEmbedding = (summary.architecture?.lowercased().contains("bge") == true)
                    || (summary.pipelineTag?.lowercased().contains("embedding") == true)
                if isEmbedding { return nil }
                let normalizedId = normalizedHubId(summary.id)
                return ModelConfiguration(
                    name: summary.name,
                    hubId: normalizedId,
                    description: summary.modelDescription ?? "No description available",
                    parameters: summary.parameters,
                    quantization: summary.quantization,
                    architecture: summary.architecture,
                    maxTokens: 4096,
                    estimatedSizeGB: nil,
                    defaultSystemPrompt: nil,
                    endOfTextTokens: nil,
                    modelType: .llm,
                    gpuCacheLimit: 512 * 1024 * 1024,
                    features: []
                )
            }

            // Fallback to registry if HF returns nothing (or all filtered)
            if converted.isEmpty {
                logger.info("No models from HuggingFace, falling back to ModelRegistry")
                #if targetEnvironment(simulator)
                let platform = "iOS-Simulator"
                #elseif os(iOS)
                let platform = "iOS"
                #elseif os(macOS)
                let platform = "macOS"
                #else
                let platform = "Unknown"
                #endif
                converted = ModelRegistry.allModels.filter { model in
                    guard !model.hubId.hasPrefix("mock/") && !model.hubId.hasPrefix("test/") else { return false }
                    // Avoid BGE/embedders here as well
                    let arch = model.architecture?.lowercased() ?? ""
                    let isEmbedding = arch.contains("bge")
                    guard !isEmbedding else { return false }
                    return ModelRegistry.isModelSupported(model, ramGB: memoryGB, platform: platform)
                }
                logger.info("Loaded \(converted.count) models from ModelRegistry fallback")
            }

            // If we still have very few models, add more from the registry to ensure variety
            if converted.count < 15 && memoryGB >= 16 {
                logger.info("Adding more models from registry to ensure variety")
                let additionalModels = ModelRegistry.allModels.filter { model in
                    // Don't duplicate models we already have
                    !converted.contains { normalizedHubId($0.hubId) == normalizedHubId(model.hubId) } &&
                    // Filter out test/mock models
                    !model.hubId.hasPrefix("mock/") && !model.hubId.hasPrefix("test/") &&
                    // Avoid embedding models
                    !(model.architecture?.lowercased().contains("bge") == true) &&
                    // Check device compatibility
                    ModelRegistry.isModelSupported(model, ramGB: memoryGB, platform: "macOS")
                }
                
                // Add up to 20 more models to reach a good variety
                let modelsToAdd = Array(additionalModels.prefix(20))
                converted.append(contentsOf: modelsToAdd)
                logger.info("Added \(modelsToAdd.count) additional models from registry")
            }

            // Sort: downloaded first, then by estimated size ascending when available
            let sortedModels = converted.sorted { model1, model2 in
                let model1Downloaded = downloadedModels.contains(normalizedHubId(model1.hubId))
                let model2Downloaded = downloadedModels.contains(normalizedHubId(model2.hubId))
                if model1Downloaded != model2Downloaded { return model1Downloaded }
                let size1 = model1.estimatedSizeGB ?? 10.0
                let size2 = model2.estimatedSizeGB ?? 10.0
                return size1 < size2
            }

            self.availableModels = sortedModels
            logger.info("Final model count: \(sortedModels.count) models loaded")

            if self.selectedModel == nil {
                // If there is a previously saved selection and it's present, use it
                if let savedId = UserDefaults.standard.string(forKey: "lastSelectedModelHubId") {
                    let normalizedSaved = normalizedHubId(savedId)
                    if let saved = sortedModels.first(where: { normalizedHubId($0.hubId) == normalizedSaved }) {
                        self.selectedModel = saved
                    }
                }

                if self.selectedModel == nil,
                   let firstDownloaded = sortedModels.first(where: { downloadedModels.contains(normalizedHubId($0.hubId)) }) {
                    self.selectedModel = firstDownloaded
                } else if self.selectedModel == nil,
                          let smallFirst = sortedModels.first(where: { ($0.estimatedSizeGB ?? 10.0) <= 6.0 }) {
                    self.selectedModel = smallFirst
                } else if self.selectedModel == nil {
                    self.selectedModel = sortedModels.first
                }
            }
        } catch {
            logger.error("Failed to load available models: \(error.localizedDescription)")
            self.availableModels = []
        }
    }

    func checkDownloadedModels() async {
        do {
            logger.info("🔍 Starting checkDownloadedModels scan...")
            let downloaded = try await modelDownloader.getDownloadedModels()
            let downloadedIds = Set(downloaded.map { normalizedHubId($0.hubId) })
            self.downloadedModels = downloadedIds
            
            logger.info("✅ Found \(downloadedIds.count) downloaded models", context: Logger.Context([
                "modelIds": downloadedIds.joined(separator: ", ")
            ]))
            
            // Log each detected model for debugging
            for model in downloaded {
                logger.debug("  📦 Detected model", context: Logger.Context([
                    "name": model.name,
                    "hubId": model.hubId,
                    "normalized": normalizedHubId(model.hubId)
                ]))
            }
        } catch {
            logger.error("❌ Failed to check downloaded models", context: Logger.Context([
                "error": error.localizedDescription,
                "errorType": String(describing: type(of: error))
            ]))
            self.downloadedModels = []
        }
    }

    // MARK: - Model Selection

    func selectModel(_ model: ModelConfiguration, forInitialSetup: Bool = false) async {
        if forInitialSetup {
            logger.info("Initial setup selecting model: \(model.name) (\(model.hubId))")
        }

        if !model.supportsChat {
            logger.warning("Vision or non-chat model selected; blocking chat activation", context: Logger.Context([
                "hubId": model.hubId,
                "modelType": String(describing: model.modelType)
            ]))
            errorMessage = "\(model.name) is a vision-first model. Use the Documents tab to analyze images, then switch back to a chat model for conversations."
            return
        }

        // Always persist the explicit selection and clear auto-errors
        selectedModel = model
        let normalizedId = normalizedHubId(model.hubId)
        UserDefaults.standard.set(normalizedId, forKey: "lastSelectedModelHubId")
        logger.info("Selected model: \(model.name) (\(normalizedId))")
        // Removed debug logging for model details to reduce noise
        log("SELECT_MODEL", ["hubId": normalizedId])
        errorMessage = nil

        // Refresh downloaded set before deciding
        await checkDownloadedModels()

        // Also trust the shared download manager’s view (may be fresher than disk scan)
        let managerDownloaded = ModelDiscoveryManager.shared.containsDownloadedModel(id: model.hubId)
        let diskDownloaded = await fileManagerService.isModelDownloaded(modelId: normalizedId)
        let isDownloaded = downloadedModels.contains(normalizedId) || managerDownloaded || diskDownloaded

        // Only initialize if the selected model is actually on disk (or recently finished per manager)
        if isDownloaded {
            log("INIT_SESSION", ["hubId": normalizedId])
            await initializeChatSession(with: model)
        } else {
            // Prompt user to download explicitly
            errorMessage = "Model '\(model.name)' is not downloaded. Please download it first."
        }
    }

    /// Select by hub id, even if not in current recommendations, by constructing a minimal configuration
    func selectModelById(_ hubId: String, forInitialSetup: Bool = false) async {
        let normalizedId = normalizedHubId(hubId)
        if let existing = availableModels.first(where: { normalizedHubId($0.hubId) == normalizedId }) {
            await selectModel(existing, forInitialSetup: forInitialSetup)
            return
        }
        // Build a minimal model configuration so ChatSession can attempt to load
        let config: ModelConfiguration
        if let registryModel = ModelRegistry.findModel(by: normalizedId) {
            config = registryModel
        } else {
            config = ModelConfiguration(
                name: normalizedId.components(separatedBy: "/").last ?? normalizedId,
                hubId: normalizedId,
                description: "",
                maxTokens: 4096,
                estimatedSizeGB: nil,
                defaultSystemPrompt: nil
            )
        }
        // Insert to available list so UI can show it
        availableModels.insert(config, at: 0)
        await selectModel(config, forInitialSetup: forInitialSetup)
    }

    // MARK: - Model Downloading

    func downloadModel(_ model: ModelConfiguration) async {
        guard !downloadingModels.contains(model.hubId) else { return }

        let normalizedId = normalizedHubId(model.hubId)

        downloadingModels.insert(model.hubId)
        downloadProgress[model.hubId] = 0.0

        do {
            // Route through shared ModelDiscoveryManager to surface byte counts in UI
            let manager = ModelDiscoveryManager.shared
            _ = try await manager.downloadModel(model) { [self] progress in
                Task { @MainActor in
                    self.downloadProgress[model.hubId] = progress
                }
            }

            downloadedModels.insert(normalizedId)
            logger.info("Successfully downloaded model: \(model.name)")
            // Make newly downloaded model the active selection if none selected
            if self.selectedModel == nil || !(self.downloadedModels.contains(normalizedHubId(self.selectedModel!.hubId))) {
                self.selectedModel = model
                UserDefaults.standard.set(normalizedId, forKey: "lastSelectedModelHubId")
                await initializeChatSession(with: model)
            }

        } catch {
            logger.error("Failed to download model \(model.name): \(error)")
            errorMessage = "Failed to download \(model.name): \(error.localizedDescription)"
        }

        downloadingModels.remove(model.hubId)
        downloadProgress.removeValue(forKey: model.hubId)

        // Update downloaded status
        await checkDownloadedModels()
    }

    // MARK: - Session Management

    /// Intelligent chat session initialization with error handling
    private func initializeChatSession(with model: ModelConfiguration) async {
        do {
            // Check if model loading is already in progress
            if chatSessionManager.isModelLoading() {
                logger.info("⚠️ Model loading already in progress, waiting...")
                // Wait a bit for loading to complete
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }

            _ = try await chatSessionManager.ensureSession(for: model)
            logger.info("✅ Initialized chat session with model: \(model.name)")
            log("SESSION_READY", ["hubId": model.hubId])
            errorMessage = nil
        } catch {
            logger.error("Failed to initialize chat session: \(error)")
            errorMessage = "❌ Failed to load \(model.name): \(error.localizedDescription)"
            log("SESSION_ERROR", ["hubId": model.hubId, "error": error.localizedDescription])

            // Suggest alternative models
            await suggestAlternativeModels(failedModel: model)
        }
    }

    /// Intelligent fallback when model download fails
    private func handleDownloadFailure(_ failedModel: ModelConfiguration) async {
        logger.warning("Handling download failure for \(failedModel.name)")

        // Check if we have any downloaded models to fall back to
    let downloadedModelConfigs = availableModels.filter { downloadedModels.contains(normalizedHubId($0.hubId)) }

        if let fallbackModel = downloadedModelConfigs.first {
            logger.info("Falling back to downloaded model: \(fallbackModel.name)")
            errorMessage = "⚠️ \(failedModel.name) download failed. Using \(fallbackModel.name) instead."

            // Switch to the fallback model
            selectedModel = fallbackModel
            await initializeChatSession(with: fallbackModel)
        } else {
            // No downloaded models available - suggest smaller alternatives
            await suggestAlternativeModels(failedModel: failedModel)
        }
    }

    /// Intelligent model suggestion when primary model fails
    private func suggestAlternativeModels(failedModel: ModelConfiguration) async {
        logger.info("Suggesting alternatives for failed model: \(failedModel.name)")

        // Find smaller, more likely to work models
        let smallerModels = availableModels.filter { model in
            let failedSize = failedModel.estimatedSizeGB ?? 10.0
            let candidateSize = model.estimatedSizeGB ?? 10.0
            return candidateSize < failedSize && model.hubId != failedModel.hubId
        }.sorted { model1, model2 in
            let size1 = model1.estimatedSizeGB ?? 10.0
            let size2 = model2.estimatedSizeGB ?? 10.0
            return size1 < size2
        }

        if let suggestedModel = smallerModels.first {
            logger.info("Suggesting alternative model: \(suggestedModel.name)")
            errorMessage = "💡 \(failedModel.name) failed. Try \(suggestedModel.name) instead (smaller, more reliable)."

            // Auto-switch to the suggested model
            selectedModel = suggestedModel
            await selectModel(suggestedModel)
        } else {
            // No alternatives available
            errorMessage = "❌ \(failedModel.name) failed and no alternatives available. Please check your connection and try again."
            logger.error("No alternative models available for \(failedModel.name)")
        }
    }

    // MARK: - Download Management

    func cancelAllDownloads() async {
        downloadingModels.removeAll()
        downloadProgress.removeAll()
        showDownloadPrompt = false
        onDownloadStateChanged?(downloadingModels, downloadProgress, showDownloadPrompt, pendingDownloadModel)

        // Note: This would need to be implemented by the parent model manager
        // For now, just log
        logger.info("All downloads cancelled")
    }

    func cancelDownload(for modelId: String) {
        downloadingModels.remove(modelId)
        downloadProgress.removeValue(forKey: modelId)
        onDownloadStateChanged?(downloadingModels, downloadProgress, showDownloadPrompt, pendingDownloadModel)
    }

    func cancelDownloadPrompt() {
        showDownloadPrompt = false
        pendingDownloadModel = nil
        onDownloadStateChanged?(downloadingModels, downloadProgress, showDownloadPrompt, pendingDownloadModel)
    }

    func getDownloadStatus(for model: ModelConfiguration) -> String {
        if downloadingModels.contains(model.hubId) {
            if let p = downloadProgress[model.hubId] {
                let percent = Int((p * 100).rounded())
                return "Downloading (\(percent)%)"
            }
            return "Downloading..."
        }
        // Note: This would need to check with the parent model manager
        return "Ready to download"
    }

    private func log(_ event: String, _ kv: [String: String]) {
        let text = kv.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        // Forward to workspace Logger for unified capture
        logger.info("Event: \(event) - \(text)")
    }
}
