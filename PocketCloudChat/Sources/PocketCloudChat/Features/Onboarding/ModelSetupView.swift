// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Onboarding/ModelSetupView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModelSetupView: View {
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
import PocketCloudMLX
#if canImport(MLXLLM)
import MLXLLM
#endif
import PocketCloudLogger

// Use the standardized Logger from ai-dev-logger
private let logger = Logger(label: "ModelSetupView")

// MARK: - Helper Functions

/// Estimate model size based on parameters and quantization (robust parsing)
private func estimateModelSizeGB(_ model: ModelDiscoveryService.ModelSummary) -> Double {
    // Prefer the maximum parsed params across both parameters and full name to avoid undercount (e.g. Qwen3 vs 30B)
    let rawParams = model.parameters ?? ""
    let fullName = model.name
    let lowerName = fullName.lowercased()

    func extractMaxBillions(in text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let ns = text as NSString
        let pattern = "(?i)([0-9]+(?:\\.[0-9]+)?)\\s*([BM])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, options: [], range: range)
        var best: Double = 0
        for m in matches {
            if m.numberOfRanges == 3 {
                let num = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let unit = ns.substring(with: m.range(at: 2)).uppercased()
                let billions = unit == "M" ? (num / 1000.0) : num
                best = max(best, billions)
            }
        }
        return best > 0 ? best : nil
    }

    // Handle patterns like "8x7B" (Mixture-of-Experts) conservatively as product
    let compactParams = (rawParams.isEmpty ? fullName : rawParams).replacingOccurrences(of: " ", with: "").uppercased()
    if compactParams.contains("X") {
        let parts = compactParams.split(separator: "x").map(String.init)
        if parts.count == 2, let left = Double(parts[0]) {
            let rightNum = parts[1].replacingOccurrences(of: "B", with: "").replacingOccurrences(of: "M", with: "")
            if let right = Double(rightNum) {
                // Treat as left * right billions (convert M to B if needed)
                let billions = parts[1].contains("M") ? (left * right / 1000.0) : (left * right)
                let params = Int(billions * 1_000_000_000)
                return estimatedGB(fromParameters: params, quantization: model.quantization)
            }
        }
    }

    // Generic regex for numbers with optional decimal followed by B/M
    if let best = max(extractMaxBillions(in: rawParams) ?? 0, extractMaxBillions(in: fullName) ?? 0) as Double?, best > 0 {
        let params = Int(best * 1_000_000_000)
        return estimatedGB(fromParameters: params, quantization: model.quantization)
    }

    // Last-ditch: infer from common size hints in name
    if lowerName.contains("70b") { return estimatedGB(fromParameters: 70_000_000_000, quantization: model.quantization) }
    if lowerName.contains("65b") { return estimatedGB(fromParameters: 65_000_000_000, quantization: model.quantization) }
    if lowerName.contains("34b") { return estimatedGB(fromParameters: 34_000_000_000, quantization: model.quantization) }
    if lowerName.contains("30b") { return estimatedGB(fromParameters: 30_000_000_000, quantization: model.quantization) }
    if lowerName.contains("32b") { return estimatedGB(fromParameters: 32_000_000_000, quantization: model.quantization) }
    if lowerName.contains("20b") { return estimatedGB(fromParameters: 20_000_000_000, quantization: model.quantization) }
    if lowerName.contains("14b") { return estimatedGB(fromParameters: 14_000_000_000, quantization: model.quantization) }
    if lowerName.contains("13b") { return estimatedGB(fromParameters: 13_000_000_000, quantization: model.quantization) }
    if lowerName.contains("8b")  { return estimatedGB(fromParameters: 8_000_000_000,  quantization: model.quantization) }
    if lowerName.contains("7b")  { return estimatedGB(fromParameters: 7_000_000_000,  quantization: model.quantization) }
    if lowerName.contains("4b")  { return estimatedGB(fromParameters: 4_000_000_000,  quantization: model.quantization) }
    if lowerName.contains("3b")  { return estimatedGB(fromParameters: 3_000_000_000,  quantization: model.quantization) }
    if lowerName.contains("1b")  { return estimatedGB(fromParameters: 1_000_000_000,  quantization: model.quantization) }

    // Sensible small-model default
    return 3.0
}

/// Convert parameter count and quantization into an estimated on-disk size (GB)
private func estimatedGB(fromParameters params: Int, quantization: String?) -> Double {
    let q = (quantization ?? "4bit").lowercased()
    let bytesPerParam: Double
    if q.contains("2") { bytesPerParam = 0.25 }
    else if q.contains("3") { bytesPerParam = 0.375 }
    else if q.contains("4") { bytesPerParam = 0.5 }
    else if q.contains("8") { bytesPerParam = 1.0 }
    else { bytesPerParam = 0.8 }
    return (Double(params) * bytesPerParam) / (1024 * 1024 * 1024)
}

/// Convert ModelSummary to ModelConfiguration for compatibility with ModelDiscoveryManager
private func convertToModelConfiguration(_ summary: ModelDiscoveryService.ModelSummary) -> ModelConfiguration {
    return ModelConfiguration(
        name: summary.name,
        hubId: summary.id,
        description: summary.modelDescription ?? "",
        parameters: summary.parameters,
        quantization: summary.quantization,
        architecture: summary.architecture,
        maxTokens: 4096, // Default value
        estimatedSizeGB: estimateModelSizeGB(summary),
        defaultSystemPrompt: nil,
        endOfTextTokens: nil,
        modelType: .llm,
        gpuCacheLimit: 512 * 1024 * 1024, // Default 512MB
        features: []
    )
}

private func summaryToHuggingFaceModel(_ summary: ModelDiscoveryService.ModelSummary) -> HuggingFaceModel {
    HuggingFaceModel(
        id: summary.id,
        modelId: nil,
        author: summary.author,
        downloads: Double(summary.downloads),
        likes: Double(summary.likes),
        tags: summary.tags,
        pipeline_tag: summary.pipelineTag,
        createdAt: summary.createdAt != nil ? ISO8601DateFormatter().string(from: summary.createdAt!) : nil,
        lastModified: summary.updatedAt != nil ? ISO8601DateFormatter().string(from: summary.updatedAt!) : nil,
        private_: nil,
        gated: nil,
        disabled: nil,
        sha: nil,
        library_name: summary.tags.contains("mlx") ? "mlx" : nil,
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

// MARK: - Model Setup

struct ModelSetupView: View {
    private let modelManager = ModelDiscoveryManager.shared
    @State private var selectedModel: ModelDiscoveryService.ModelSummary?
    @State private var downloadProgress: Double = 0
    @State private var isDownloading = false
    @State private var downloadCompleted = false
    @State private var isLoading = true
    @State private var recommendedModels: [ModelDiscoveryService.ModelSummary] = []
    @State private var errorMessage: String?
    @EnvironmentObject var styleManager: StyleManager
    @State private var showTokenSheet = false
    @AppStorage("huggingFaceToken") private var huggingFaceToken: String = ""

    let onContinue: () -> Void
    
    var body: some View {
        print("🔍 DEBUG: ModelSetupView body rendering - print statement")
        logger.debug("ModelSetupView body rendering")
        return ScrollView {
            VStack(spacing: 16) {
                // Action buttons section
                VStack(spacing: 12) {
                    if isDownloading, let current = selectedModel {
                        Text("Downloading \(current.name)…")
                            .font(.caption)
                            .foregroundColor(styleManager.tokens.secondaryForeground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 12) {
                        Button("Skip for now") {
                            onContinue()
                        }
                        .buttonStyle(.bordered)

                        Button(huggingFaceToken.isEmpty ? "Set Hugging Face Token" : "Change Hugging Face Token") {
                            showTokenSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(huggingFaceToken.isEmpty ? styleManager.tokens.accent : styleManager.tokens.success)
                        .foregroundColor(styleManager.tokens.onPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(styleManager.tokens.surface.opacity(0.9))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Model list section
                LazyVStack(spacing: 12) {
                    if !isLoading && recommendedModels.isEmpty {
                        VStack(spacing: 12) {
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(styleManager.tokens.secondaryForeground)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            } else {
                                Text("No recommended models available right now.")
                                    .font(.subheadline)
                                    .foregroundColor(styleManager.tokens.secondaryForeground)
                            }
                            HStack(spacing: 12) {
                                Button("Retry") { loadRecommendedModels() }
                                    .buttonStyle(.bordered)
                                Button("Skip for now") { onContinue() }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.top, 24)
                    }
                    ForEach(recommendedModels, id: \.id) { model in
                        let normalizedId = modelManager.normalizedHubId(for: model.id) ?? model.id
                        let isSelected = selectedModel?.id == model.id
                        let managerProgress = modelManager.downloadProgress[model.id] ?? 0
                        let progressValue = isSelected ? max(downloadProgress, managerProgress) : managerProgress
                        let alreadyDownloaded = modelManager.containsDownloadedModel(id: model.id)
                        let isDownloaded = alreadyDownloaded || (downloadCompleted && isSelected)
                        let cancelAction: (() -> Void)? = (isSelected && isDownloading) ? {
                            Task { await modelManager.cancelDownload(modelId: model.id) }
                        } : nil
                        let deleteAction: (() -> Void)? = isDownloaded ? {
                            Task { await modelManager.deleteDownloadedFiles(modelId: model.id) }
                        } : nil

                        ModelCardView(
                            model: summaryToHuggingFaceModel(model),
                            isDownloading: isSelected && isDownloading,
                            downloadProgress: progressValue,
                            isDownloaded: isDownloaded,
                            downloadError: modelManager.downloadErrors[model.id] ?? modelManager.downloadErrors[normalizedId],
                            onDownload: {
                                selectedModel = model
                                downloadModel(model)
                            },
                            onCancel: cancelAction,
                            onDelete: deleteAction,
                            onUse: {
                                selectedModel = model
                                let normalizedId = modelManager.normalizedHubId(for: model.id) ?? model.id
                                UserDefaults.standard.set(normalizedId, forKey: "lastSelectedModelHubId")
                                NotificationCenter.default.post(name: .activateModel, object: normalizedId)
                                NotificationCenter.default.post(name: .switchToChat, object: nil)
                                onContinue()
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: styleManager.tokens.cornerRadius.lg)
                                .stroke(styleManager.tokens.accent, lineWidth: isSelected ? 2 : 0)
                        )
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                        .task { await modelManager.prefetchTotalBytes(for: model.id) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: selectedModel?.id) { _, newId in
            // Reset transient download flags when user changes selection
            isDownloading = false
            if let newId {
                downloadCompleted = modelManager.containsDownloadedModel(id: newId)
            } else {
                downloadCompleted = false
            }
        }

        .sheet(isPresented: $showTokenSheet) { HuggingFaceTokenView() }
        .background(styleManager.tokens.background)
        .onAppear {
            logger.info("🚀 ModelSetupView appeared - logging is working!")
            loadRecommendedModels()
        }
    }
    
    private func loadRecommendedModels() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Curated whitelist from our registry: small, MLX-compatible text models
                let allowedHubIds = Set(ModelRegistry.smallModels.map { $0.hubId })

                // First attempt: query HF then intersect with our curated whitelist
                let discovered = try await ModelDiscoveryService.recommendedMLXModelsForCurrentDevice(limit: 40)

                // Keep only curated, text-generation models
                let textGenerationModels = discovered.filter { model in
                    guard allowedHubIds.contains(model.id) else { return false }

                    // Extra safety: exclude non-text pipelines
                    let name = model.name.lowercased()
                    let desc = model.modelDescription?.lowercased() ?? ""
                    if name.contains("llava") || name.contains("vision") || desc.contains("vision") { return false }
                    if name.contains("bge") || desc.contains("embedding") { return false }
                    if name.contains("whisper") || desc.contains("speech") || desc.contains("audio") { return false }
                    return true
                }

                // Fallback: if HF returns nothing intersecting our whitelist, build from registry directly (no network)
                let candidates: [ModelDiscoveryService.ModelSummary]
                if textGenerationModels.isEmpty {
                    let curated = ModelRegistry.onboardingModels
                    candidates = curated.map { cfg in
                        ModelDiscoveryService.ModelSummary(
                            id: cfg.hubId,
                            name: cfg.name,
                            author: nil,
                            downloads: 0,
                            likes: 0,
                            architecture: cfg.architecture,
                            parameters: cfg.parameters,
                            quantization: cfg.quantization,
                            modelDescription: cfg.description,
                            createdAt: nil,
                            updatedAt: nil,
                            tags: ["mlx", "text-generation"],
                            pipelineTag: "text-generation",
                            modelIndex: [:]
                        )
                    }
                } else {
                    candidates = textGenerationModels
                }

                // Filter out unsupported models before presenting to user
                #if canImport(MLXLLM)
                let mlxRegistryModels = MLXLLM.LLMRegistry.shared.models
                let mlxRegistryIds = Set(mlxRegistryModels.map { String(describing: $0.id) })
                
                let supportedCandidates = candidates.filter { model in
                    let hfId = model.id
                    
                    // Check for exact matches
                    if mlxRegistryIds.contains(hfId) {
                        return true
                    }
                    
                    // Check for partial matches
                    for mlxId in mlxRegistryIds {
                        let mlxIdStr = String(describing: mlxId).lowercased()
                        let hfIdLower = hfId.lowercased()
                        
                        if hfIdLower.contains(mlxIdStr) || mlxIdStr.contains(hfIdLower) {
                            return true
                        }
                    }
                    
                    // Check for mlx-community prefix matches
                    for mlxId in mlxRegistryIds {
                        let mlxIdStr = String(describing: mlxId)
                        if hfId == "mlx-community/\(mlxIdStr)" || mlxIdStr == "mlx-community/\(hfId)" {
                            return true
                        }
                    }
                    
                    return false
                }
                #else
                let supportedCandidates = candidates
                #endif

                // Prefer small text models by size; use robust estimator and enforce a strict cap
                // Cap defaults: <=3GB on <=16GB RAM devices, else <=4GB
                let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
                let sizeCapGB: Double = memoryGB <= 16 ? 3.0 : 4.0
                logger.info("Model filtering caps", context: Logger.Context([
                    "deviceMemoryGB": String(format: "%.1f", memoryGB),
                    "sizeCapGB": String(format: "%.1f", sizeCapGB)
                ]))

                // Score by estimated size first, later refined by exact byte totals when available
                var scored: [(ModelDiscoveryService.ModelSummary, Double)] = []
                for m in supportedCandidates {
                    let sizeGB: Double
                    if let exact = modelManager.totalBytesByModel[m.id] {
                        sizeGB = Double(exact) / 1_073_741_824.0
                    } else {
                        sizeGB = estimateModelSizeGB(m)
                    }
                    scored.append((m, sizeGB))
                    logger.debug("Scored model", context: Logger.Context([
                        "id": m.id,
                        "name": m.name,
                        "parameters": m.parameters ?? "unknown",
                        "quantization": m.quantization ?? "unknown",
                        "estimatedSizeGB": String(format: "%.2f", sizeGB)
                    ]))
                }

                // Also exclude very large parameter counts (>8B) regardless of size estimate
                func isSmallParams(_ m: ModelDiscoveryService.ModelSummary) -> Bool {
                    let combined = ((m.parameters ?? "") + " " + m.name)
                    let ns = combined as NSString
                    let pattern = "(?i)([0-9]+(?:\\.[0-9]+)?)\\s*([BM])"
                    guard let regex = try? NSRegularExpression(pattern: pattern) else { return true }
                    let range = NSRange(location: 0, length: ns.length)
                    let matches = regex.matches(in: combined, options: [], range: range)
                    var maxBillions: Double = 0
                    for m in matches {
                        if m.numberOfRanges == 3 {
                            let num = Double(ns.substring(with: m.range(at: 1))) ?? 0
                            let unit = ns.substring(with: m.range(at: 2)).uppercased()
                            let billions = unit == "M" ? (num / 1000.0) : num
                            maxBillions = max(maxBillions, billions)
                        }
                    }
                    return maxBillions == 0 ? true : (maxBillions <= 8.0)
                }

                // Strict filter: enforce cap and parameter ceiling, and drop obviously huge repos
                let filtered = scored.compactMap { (m, sizeGB) -> ModelDiscoveryService.ModelSummary? in
                    let smallParams = isSmallParams(m)
                    // If we have exact total bytes and they're clearly over cap, exclude
                    let include = sizeGB <= sizeCapGB && smallParams
                    logger.debug("Filter decision", context: Logger.Context([
                        "id": m.id,
                        "name": m.name,
                        "sizeGB": String(format: "%.2f", sizeGB),
                        "smallParams": String(smallParams),
                        "include": String(include)
                    ]))
                    return include ? m : nil
                }
                .sorted { a, b in
                    let sa = scored.first(where: { $0.0.id == a.id })?.1 ?? estimateModelSizeGB(a)
                    let sb = scored.first(where: { $0.0.id == b.id })?.1 ?? estimateModelSizeGB(b)
                    return sa < sb
                }

                // Final list: prefer filtered, else take smallest curated candidates
                let finalModels = filtered.isEmpty ? Array(scored.sorted { $0.1 < $1.1 }.prefix(8).map { $0.0 }) : Array(filtered.prefix(8))

                logger.info("Filtering complete", context: Logger.Context([
                    "candidates": String(candidates.count),
                    "kept": String(filtered.count),
                    "shown": String(min(8, filtered.count))
                ]))

                await MainActor.run {
                    self.recommendedModels = finalModels
                    self.isLoading = false

                    // Auto-select the smallest recommended model
                    if let first = finalModels.first { self.selectedModel = first }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to discover models: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func downloadModel(_ model: ModelDiscoveryService.ModelSummary) {
        print("🎯 DOWNLOAD FUNCTION CALLED - print statement for model: \(model.name)")
        logger.info("🔄 Starting download", context: Logger.Context([
            "model": model.name,
            "id": model.id
        ]))

        isDownloading = true
        downloadProgress = 0
        downloadCompleted = false

        Task {
            do {
                // Use the ModelDiscoveryManager for consistent downloading
                let config = convertToModelConfiguration(model)
                logger.info("🔄 Converted to ModelConfiguration", context: Logger.Context([
                    "name": config.name,
                    "hubId": config.hubId,
                    "parameters": config.parameters ?? "unknown",
                    "estimatedSizeGB": String(format: "%.1f", config.estimatedSizeGB ?? 0)
                ]))

                logger.info("🔄 Calling modelManager.downloadModel")

                let _ = try await modelManager.downloadModel(config) { progress in
                    logger.debug("🔄 Download progress update", context: Logger.Context([
                        "progress": String(format: "%.1f%%", progress * 100),
                        "model": model.name
                    ]))
                    Task { @MainActor in
                        self.downloadProgress = progress
                    }
                }

                logger.info("🔄 Download completed successfully", context: Logger.Context([
                    "model": model.name,
                    "id": model.id
                ]))

                await MainActor.run {
                    self.isDownloading = false
                    self.downloadCompleted = true
                }

                // Persist selection for Chat to pick up
                let normalizedId = modelManager.normalizedHubId(for: model.id) ?? model.id
                UserDefaults.standard.set(normalizedId, forKey: "lastSelectedModelHubId")

                logger.info("✅ Model download completed and saved to UserDefaults", context: Logger.Context([
                    "model": model.name,
                    "normalizedId": normalizedId,
                    "persistedKey": "lastSelectedModelHubId"
                ]))
                
                // IMPORTANT: Force a refresh of downloaded models to ensure chat view sees it
                logger.info("🔄 Refreshing downloaded models list to ensure chat view can find the model")
                NotificationCenter.default.post(name: .refreshDownloadedModels, object: normalizedId)

                // Immediately activate the model in Chat and switch to Chat tab
                NotificationCenter.default.post(name: .activateModel, object: normalizedId)
                NotificationCenter.default.post(name: .switchToChat, object: nil)

                // Auto-close onboarding shortly after to bring user to chat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onContinue()
                }

            } catch {
                logger.error("❌ Download failed", context: Logger.Context([
                    "model": model.name,
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ]))

                await MainActor.run {
                    self.isDownloading = false
                    self.errorMessage = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    
}


#Preview {
    ModelSetupView(onContinue: {})
        .environmentObject(StyleManager())
} 
