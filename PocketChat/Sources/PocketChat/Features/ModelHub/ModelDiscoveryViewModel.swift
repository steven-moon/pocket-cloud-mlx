// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryViewModel.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ModelDiscoveryViewModel: ObservableObject {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryDebugView.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryView.swift
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
import os.log
#if canImport(MLXLLM)
import MLXLLM
#endif

/// ViewModel for managing model discovery and downloads
@MainActor
class ModelDiscoveryViewModel: ObservableObject {
    private let logger = Logger(label: "ModelDiscoveryViewModel")

    @Published var models: [HuggingFaceModel] = [] {
        didSet { logger.debug("🔍 DIAGNOSTIC: models changed, count: \(oldValue.count) → \(models.count)") }
    }
    @Published var isLoading = false {
        didSet { logger.debug("🔍 DIAGNOSTIC: isLoading changed: \(oldValue) → \(isLoading)") }
    }
    @Published var isLoadingMore = false {
        didSet { logger.debug("🔍 DIAGNOSTIC: isLoadingMore changed: \(oldValue) → \(isLoadingMore)") }
    }
    @Published var hasMoreResults = false {
        didSet { logger.debug("🔍 DIAGNOSTIC: hasMoreResults changed: \(oldValue) → \(hasMoreResults)") }
    }
    @Published var hasValidToken = false {
        didSet { logger.debug("🔍 DIAGNOSTIC: hasValidToken changed: \(oldValue) → \(hasValidToken)") }
    }
    @Published var onlyCompatible: Bool = true {
        didSet { logger.debug("🔍 DIAGNOSTIC: onlyCompatible changed: \(oldValue) → \(onlyCompatible)") }
    }
    @Published var sortOption: SortOption = .relevance {
        didSet { logger.debug("🔍 DIAGNOSTIC: sortOption changed: \(oldValue) → \(sortOption)") }
    }
    enum Section { case downloaded, discover }
    @Published var section: Section = .downloaded {
        didSet { logger.debug("🔍 DIAGNOSTIC: section changed: \(oldValue) → \(section)") }
    }
    enum TypeFilter: String, CaseIterable { case all, text, vision, audio, embedding }
    @Published var typeFilter: TypeFilter = .text {
        didSet { logger.debug("🔍 DIAGNOSTIC: typeFilter changed: \(oldValue) → \(typeFilter)") }
    }
    
    let huggingFaceAPI = HuggingFaceAPI.shared
    let modelManager = ModelDiscoveryManager.shared
    private var currentPage = 0
    private let pageSize = 50 // Increased from 20 to 50 for better model discovery
    private var currentSearchQuery = ""
    private var currentFilter: ModelFilter = .all
    
    // Get supported models from centralized ModelRegistry
    private var supportedModels: [HuggingFaceModel] {
        // Convert ModelConfiguration from ModelRegistry to HuggingFaceModel format
        return ModelRegistry.allModels.map { config in
            // Determine pipeline tag based on model type
            let pipelineTag: String
            switch config.modelType {
            case .llm:
                pipelineTag = "text-generation"
            case .vlm:
                pipelineTag = "image-text-to-text"
            case .embedding:
                pipelineTag = "feature-extraction"
            case .diffusion:
                pipelineTag = "text-to-image"
            @unknown default:
                pipelineTag = "text-generation"
            }

            // Extract author from hubId (e.g., "mlx-community/model-name" -> "mlx-community")
            let author = config.hubId.components(separatedBy: "/").first

            let tags = ["mlx", config.architecture ?? ""].filter { !$0.isEmpty }

            // Create HuggingFaceModel from ModelConfiguration
            return HuggingFaceModel(
                id: config.hubId,
                modelId: nil,
                author: author,
                downloads: nil,
                likes: nil,
                tags: tags,
                pipeline_tag: pipelineTag,
                createdAt: nil,
                lastModified: nil,
                private_: nil,
                gated: nil,
                disabled: nil,
                sha: nil,
                library_name: "mlx",
                safetensors: nil,
                usedStorage: nil,
                trendingScore: nil,
                cardData: nil,
                siblings: nil,
                config: nil,
                transformersInfo: nil,
                spaces: nil,
                modelIndex: nil,
                widgetData: nil
            )
        }
    }

    /// Apply any cached metadata without triggering new network requests.
    private func applyCachedMetadata(_ models: [HuggingFaceModel]) async -> [HuggingFaceModel] {
        var enriched: [HuggingFaceModel] = []
        enriched.reserveCapacity(models.count)

        for model in models {
            if let metadata = await HuggingFaceMetadataCache.shared.getMetadata(for: model.id) {
                enriched.append(Self.merge(model, with: metadata))
            } else {
                enriched.append(model)
            }
        }

        return enriched
    }

    /// Schedules a metadata refresh so the UI picks up live download counts and publish dates.
    private func refreshMetadata(for models: [HuggingFaceModel]) {
        guard !models.isEmpty else { return }

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            for model in models {
                await self.fetchAndApplyMetadata(for: model.id)
                // Space out requests to avoid hitting rate limits on Hugging Face.
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }

    /// Fetch metadata for one model and merge it into the published list.
    private func fetchAndApplyMetadata(for modelId: String) async {
        let cache = HuggingFaceMetadataCache.shared
        var metadata = await cache.getMetadata(for: modelId)

        if metadata == nil {
            await cache.updateMetadata(for: modelId)
            metadata = await cache.getMetadata(for: modelId)
        }

        guard let metadata else { return }

        await MainActor.run { [weak self] in
            guard let self else { return }
            guard let index = self.models.firstIndex(where: { $0.id == modelId }) else { return }
            let current = self.models[index]
            self.models[index] = Self.merge(current, with: metadata)
        }
    }

    /// Combine a baseline model item with cached metadata from Hugging Face.
    private static func merge(_ model: HuggingFaceModel, with metadata: CachedModelMetadata) -> HuggingFaceModel {
        HuggingFaceModel(
            id: model.id,
            modelId: model.modelId,
            author: model.author ?? metadata.author,
            downloads: metadata.downloads.map { Double($0) } ?? model.downloads,
            likes: metadata.likes.map { Double($0) } ?? model.likes,
            tags: metadata.tags ?? model.tags,
            pipeline_tag: model.pipeline_tag,
            createdAt: metadata.createdAt ?? model.createdAt,
            lastModified: metadata.lastModified ?? model.lastModified,
            private_: metadata.private_ ?? model.private_,
            gated: metadata.gated ?? model.gated,
            disabled: metadata.disabled ?? model.disabled,
            sha: metadata.sha ?? model.sha,
            library_name: metadata.libraryName ?? model.library_name,
            safetensors: model.safetensors,
            usedStorage: metadata.usedStorage ?? model.usedStorage,
            trendingScore: metadata.trendingScore ?? model.trendingScore,
            cardData: model.cardData,
            siblings: model.siblings,
            config: model.config,
            transformersInfo: model.transformersInfo,
            spaces: model.spaces,
            modelIndex: model.modelIndex,
            widgetData: model.widgetData
        )
    }
    
    init() {
        checkTokenValidity()
    }
    
    /// Search for models with the given query and filter - using hardcoded list
    func searchModels(query: String, filter: ModelFilter) async {
        currentSearchQuery = query
        currentFilter = filter
        currentPage = 0
        isLoading = true

        // Use supported models list and apply any cached metadata before filtering
        var filteredModels = await applyCachedMetadata(supportedModels)

        // Apply search query filter
        if !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            filteredModels = filteredModels.filter { model in
                model.id.lowercased().contains(lowercasedQuery) ||
                model.author?.lowercased().contains(lowercasedQuery) == true ||
                model.extractArchitecture()?.lowercased().contains(lowercasedQuery) == true
            }
        }

        // Apply type filter
        filteredModels = applyTypeFilter(filteredModels)

        // Apply compatibility filter if enabled
        if onlyCompatible {
            let deviceCaps = ModelDiscoveryService.detectDeviceCapabilities()
            filteredModels = filteredModels.filter { model in
                // Estimate model size from parameters
                let params = model.extractParameters() ?? "3B"
                let sizeGB = estimateModelSizeGB(params)
                // Allow models that fit in 70% of device RAM
                return sizeGB < (deviceCaps.memoryGB * 0.7)
            }
        }

        // Apply category filter (Small, Medium, Large, Popular, Recent, MLX)
        filteredModels = applyCategoryFilter(filteredModels, filter: filter)

        // Sort locally and ensure UI updates immediately
        let sorted = applySorting(filteredModels)
        models = sorted
        hasMoreResults = false // No pagination with hardcoded list
        isLoading = false

        // Refresh metadata in the background so download counts & publish dates update once fetched
        refreshMetadata(for: sorted)
    }
    
    private func estimateModelSizeGB(_ params: String) -> Double {
        let cleaned = params.uppercased()
            .replacingOccurrences(of: "B", with: "")
            .replacingOccurrences(of: "M", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        if let value = Double(cleaned) {
            if params.uppercased().contains("M") {
                // Convert millions to GB at 4bit (0.5 bytes per param)
                return (value * 1_000_000 * 0.5) / (1024 * 1024 * 1024)
            } else {
                // Billions at 4bit
                return (value * 1_000_000_000 * 0.5) / (1024 * 1024 * 1024)
            }
        }
        return 3.0 // Default 3GB if can't parse
    }

    /// Parse parameter value from string (e.g., "3B" -> 3.0, "135M" -> 0.135)
    private func parseParameterValue(_ params: String?) -> Double? {
        guard let params = params else { return nil }

        let cleaned = params.uppercased()
            .replacingOccurrences(of: "B", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")

        if cleaned.contains("M") {
            // Handle millions (e.g., "135M" -> 0.135B)
            let numStr = cleaned.replacingOccurrences(of: "M", with: "")
            if let value = Double(numStr) {
                return value / 1000.0 // Convert to billions
            }
        } else {
            // Handle billions (e.g., "3" or "3.0" -> 3.0B)
            if let value = Double(cleaned) {
                return value
            }
        }

        return nil
    }

    /// Apply category filter (Small, Medium, Large, Popular, Recent, MLX)
    private func applyCategoryFilter(_ models: [HuggingFaceModel], filter: ModelFilter) -> [HuggingFaceModel] {
        switch filter {
        case .all:
            return models

        case .mlx:
            // Filter models with "mlx" in their ID or tags
            return models.filter { model in
                model.id.lowercased().contains("mlx") ||
                model.tags?.contains(where: { $0.lowercased().contains("mlx") }) == true
            }

        case .popular:
            // Filter models with downloads >= 1000 or with high trending scores
            return models.filter { model in
                if let downloads = model.downloads {
                    return downloads >= 1000
                }
                // Include models with high trending score as fallback
                if let score = model.trendingScore {
                    return score > 0.5
                }
                return false
            }

        case .recent:
            // Filter models created after 2024
            return models.filter { model in
                if let createdAt = model.createdAt {
                    return createdAt.contains("2024") || createdAt.contains("2025")
                }
                return false
            }

        case .small:
            // Filter models with parameters < 3B
            return models.filter { model in
                if let paramValue = parseParameterValue(model.extractParameters()) {
                    return paramValue < 3.0
                }
                return false
            }

        case .medium:
            // Filter models with parameters 3B-7B
            return models.filter { model in
                if let paramValue = parseParameterValue(model.extractParameters()) {
                    return paramValue >= 3.0 && paramValue <= 7.0
                }
                return false
            }

        case .large:
            // Filter models with parameters > 7B
            return models.filter { model in
                if let paramValue = parseParameterValue(model.extractParameters()) {
                    return paramValue > 7.0
                }
                return false
            }
        }
    }

    /// Load more results for pagination - not needed with hardcoded list
    func loadMoreResults() async {
        // No-op since we're using a hardcoded list without pagination
        hasMoreResults = false
        isLoadingMore = false
    }
    
    /// Download a model via the shared download manager (persists across views)
    func downloadModel(_ model: HuggingFaceModel) async {
        logger.warning("🔍 DIAGNOSTIC: downloadModel called for: \(model.id)")
        await modelManager.startDownload(for: model)
        logger.warning("🔍 DIAGNOSTIC: startDownload returned for: \(model.id)")
    }

    /// Force a refresh of downloaded models from disk (for Downloaded tab)
    func refreshDownloadedFromDisk() async {
        await modelManager.refreshDownloadedModels()
    }
    
    /// Check if HuggingFace token is valid
    func checkTokenValidity() {
        Task {
            if let token = UserDefaults.standard.string(forKey: "huggingFaceToken"),
               !token.isEmpty {
                do {
                    let username = try await huggingFaceAPI.validateToken(token: token)
                    hasValidToken = username != nil
                } catch {
                    hasValidToken = false
                }
            } else {
                hasValidToken = false
            }
        }
    }
    
    /// Build search query combining user input and filter
    private func buildSearchQuery(query: String, filter: ModelFilter) -> String {
        var searchTerms: [String] = []
        
        // Add user query
        if !query.isEmpty {
            searchTerms.append(query)
        }
        
        // Add filter query
        if !filter.searchQuery.isEmpty {
            searchTerms.append(filter.searchQuery)
        }
        
        // Always prioritize MLX models
        if filter != .mlx {
            searchTerms.append("mlx")
        }
        
        return searchTerms.joined(separator: " ")
    }

    // MARK: - Sorting & Compatibility helpers
    enum SortOption: String, CaseIterable { case relevance, sizeAsc, sizeDesc, downloadsDesc, nameAsc }
    private func applySorting(_ items: [HuggingFaceModel]) -> [HuggingFaceModel] {
        switch sortOption {
        case .relevance: return items
        case .nameAsc: return items.sorted { ($0.id) < ($1.id) }
        case .downloadsDesc: return items.sorted { ($0.downloads ?? 0) > ($1.downloads ?? 0) }
        case .sizeAsc: return items.sorted { sizeForModelId($0.id) < sizeForModelId($1.id) }
        case .sizeDesc: return items.sorted { sizeForModelId($0.id) > sizeForModelId($1.id) }
        }
    }
    private func sizeForModelId(_ id: String) -> Double {
        if let bytes = modelManager.totalBytesByModel[id], bytes > 0 {
            return Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        }
        if let m = models.first(where: { $0.id == id }) { return estimatedSizeGB(m) }
        return 9999
    }
    private func estimatedSizeGB(_ model: HuggingFaceModel) -> Double {
        // Use parseParameterValue for consistent parsing
        let base = parseParameterValue(model.extractParameters()) ?? 3.0

        let q = model.extractQuantization()?.lowercased() ?? ""
        let mult: Double
        if q.contains("4") { mult = 0.25 }
        else if q.contains("6") { mult = 0.375 }
        else if q.contains("8") { mult = 0.5 }
        else if q.contains("16") { mult = 1.0 }
        else { mult = 0.8 }
        return base * mult
    }
    private func currentDeviceInfo() -> (Double, String) {
        // Use consistent device detection with DeviceAnalyzer
        let deviceAnalyzer = DeviceAnalyzer()
        _ = deviceAnalyzer.detectDeviceCategory()
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)

        #if targetEnvironment(simulator)
        return (memoryGB, "iOS-Simulator")
        #elseif os(iOS)
        return (memoryGB, "iOS")
        #elseif os(macOS)
        return (memoryGB, "macOS")
        #elseif os(tvOS)
        return (memoryGB, "tvOS")
        #elseif os(watchOS)
        return (memoryGB, "watchOS")
        #else
        return (memoryGB, "Unknown")
        #endif
    }

    private func applyTypeFilter(_ items: [HuggingFaceModel]) -> [HuggingFaceModel] {
        switch typeFilter {
        case .all: return items
        case .text:
            return items.filter { ($0.pipeline_tag?.lowercased().contains("text") == true) || ($0.extractArchitecture() != nil) }
        case .vision:
            return items.filter { $0.pipeline_tag?.lowercased().contains("image") == true || $0.extractArchitecture()?.lowercased().contains("llava") == true }
        case .audio:
            return items.filter { ($0.pipeline_tag?.lowercased().contains("audio") == true) || ($0.pipeline_tag?.lowercased().contains("speech") == true) }
        case .embedding:
            return items.filter { $0.pipeline_tag?.lowercased().contains("embedding") == true || ($0.extractArchitecture()?.lowercased().contains("bge") == true) }
        }
    }

    private func summaryToHF(_ s: ModelDiscoveryService.ModelSummary) -> HuggingFaceModel {
        HuggingFaceModel(
            id: s.id,
            modelId: nil,
            author: s.author,
            downloads: Double(s.downloads),
            likes: Double(s.likes),
            tags: s.tags,
            pipeline_tag: s.pipelineTag,
            createdAt: s.createdAt != nil ? ISO8601DateFormatter().string(from: s.createdAt!) : nil,
            lastModified: s.updatedAt != nil ? ISO8601DateFormatter().string(from: s.updatedAt!) : nil,
            private_: nil,
            gated: nil,
            disabled: nil,
            sha: nil,
            library_name: s.tags.contains("mlx") ? "mlx" : nil,
            safetensors: nil,
            usedStorage: nil,
            trendingScore: nil,
            cardData: nil,
            siblings: nil,
            config: nil,
            transformersInfo: nil,
            spaces: nil,
            modelIndex: nil,
            widgetData: nil
        )
    }

    /// Test method to debug model discovery for specific popular families
    func testPopularModelDiscovery() async {
        logger.info("Testing popular model discovery")

        let testQueries = [
            "llama",
            "phi",
            "mistral",
            "qwen",
            "gemma",
            "mlx"
        ]

        for query in testQueries {
            do {
                logger.debug("Testing query: '\(query)'")
                let models = try await huggingFaceAPI.searchModels(query: query, limit: 5)
                logger.debug("Found \(models.count) models for query '\(query)'")

                let mlxCompatible = models.filter { $0.hasMLXFiles() }
                logger.debug("MLX compatible: \(mlxCompatible.count) for query '\(query)'")

                for model in mlxCompatible.prefix(3) {
                    logger.debug("Compatible model: \(model.id) (tags: \(model.tags?.joined(separator: ", ") ?? "none"))")
                }

                if mlxCompatible.isEmpty {
                    logger.warning("No MLX-compatible models found for '\(query)'")
                }

            } catch {
                logger.error("Error searching '\(query)': \(error.localizedDescription)")
            }
        }
    }
    
    /// Check if a model is supported by the MLX framework
    private func isModelSupported(_ modelId: String) -> Bool {
        #if canImport(MLXLLM)
        let mlxRegistryModels = MLXLLM.LLMRegistry.shared.models
        let mlxRegistryIds = Set(mlxRegistryModels.map { String(describing: $0.id) })
        
        // Check for exact matches
        if mlxRegistryIds.contains(modelId) {
            return true
        }
        
        // Check for partial matches
        for mlxId in mlxRegistryIds {
            let mlxIdStr = String(describing: mlxId).lowercased()
            let hfIdLower = modelId.lowercased()
            
            if hfIdLower.contains(mlxIdStr) || mlxIdStr.contains(hfIdLower) {
                return true
            }
        }
        
        // Check for mlx-community prefix matches
        for mlxId in mlxRegistryIds {
            let mlxIdStr = String(describing: mlxId)
            if modelId == "mlx-community/\(mlxIdStr)" || mlxIdStr == "mlx-community/\(modelId)" {
                return true
            }
        }
        
        return false
        #else
        // If MLXLLM is not available, allow all models
        return true
        #endif
    }
}
