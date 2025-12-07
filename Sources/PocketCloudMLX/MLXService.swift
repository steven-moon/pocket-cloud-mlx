// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/MLXService.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:

//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/MLXModelSearchUtility.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/DebugUtility.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFace_Errors.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/OptimizedDownloader.swift
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/ChatSessionManager.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import PocketCloudLogger

// Import our custom AppLogger from the renamed logging module
import class PocketCloudLogger.AppLogger

#if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
  import MLX
  import MLXLLM
  import MLXLMCommon
#endif

// Import Hub for model loading
#if canImport(Hub)
  import Hub
#endif

/// A service class that manages machine learning models for text generation.
/// This class handles model loading, caching, and text generation using LLM models.
/// Follows Apple's MLXChatExample architecture pattern.
@Observable
public final class MLXService {
    /// Cache to store loaded model containers to avoid reloading.
    private let modelCache = NSCache<NSString, MLXLMCommon.ModelContainer>()

    /// Tracks the current model download progress.
    @MainActor
    public private(set) var modelDownloadProgress: Progress?

    /// Remember last logged fractions so we avoid spamming identical progress updates.
    @MainActor
    private var lastLoggedDownloadProgress: [String: Double] = [:]

    /// Logger for service operations
    private let appLogger = AppLogger.shared

    public init() {}

    /// Loads a model from the hub or retrieves it from cache.
    /// - Parameter configuration: The model configuration to load
    /// - Returns: A ModelContainer instance containing the loaded model
    /// - Throws: Errors that might occur during model loading
    private func loadModel(configuration: MLXLMCommon.ModelConfiguration) async throws -> MLXLMCommon.ModelContainer {
        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
        // Set GPU memory limit to prevent out of memory issues
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        // Return cached model if available to avoid reloading
        let cacheKeyString = String(describing: configuration.id)
        let cacheKey = cacheKeyString as NSString
        if let container = modelCache.object(forKey: cacheKey) {
            appLogger.info("✅ Using cached model: \(configuration.id)")
            return container
        }

    appLogger.info("🚀 Loading model: \(configuration.id)")
    appLogger.info("🔍 Platform: \(platformDescription)")
    let loadStart = Date()

        // Validate configuration before proceeding
    let modelIdString = cacheKeyString
        guard !modelIdString.isEmpty else {
            appLogger.error("❌ Invalid model configuration: empty ID")
            throw NSError(domain: "MLXService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid model configuration: empty ID"])
        }

        // Load model and track download progress using properly configured HubApi
        appLogger.info("🔍 Creating platform-specific HubApi for model loading...")
        let hub: HubApi
        do {
            hub = try createPlatformSpecificHubApi()
            appLogger.info("✅ Platform-specific HubApi created successfully")
        } catch {
            appLogger.error("❌ Failed to create HubApi: \(error.localizedDescription)")
            throw NSError(domain: "MLXService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create HubApi: \(error.localizedDescription)"])
        }

        // Detect model architecture and try to use appropriate loading method
        let architecture = detectModelArchitecture(from: configuration)
        appLogger.info("🔍 Loading model \(configuration.id) with detected architecture: \(architecture ?? "unknown")")
        appLogger.info("🔍 About to call LLMModelFactory.shared.loadContainer()")

        // Log the exact container loading call
        appLogger.info("🔍 Calling: LLMModelFactory.shared.loadContainer(hub: hub, configuration: \(configuration.id))")

        // For Qwen models, try to ensure proper configuration before loading
        if let arch = architecture, arch == "qwen2" {
            try await ensureQwenModelConfiguration(configuration: configuration)
        }

        let container: MLXLMCommon.ModelContainer
        if let arch = architecture {
            // Try to use specific model factory for known architectures
            do {
                container = try await loadModelWithArchitecture(configuration: configuration, architecture: arch)
            } catch {
                appLogger.warning("❌ Failed to load with specific architecture \(arch), falling back to generic loader")
                appLogger.warning("❌ Specific architecture error: \(error.localizedDescription)")
                appLogger.info("🔍 Falling back to generic LLMModelFactory.shared.loadContainer()")

                // Fallback to generic loader
                let progressLogger = appLogger
                let modelId = String(describing: configuration.id)
                container = try await LLMModelFactory.shared.loadContainer(
                    hub: hub, configuration: configuration
                ) { progress in
                    Task { @MainActor [weak self] in
                        self?.modelDownloadProgress = progress
                        guard let self else { return }
                        self.recordDownloadProgress(for: modelId, progress: progress, context: "Fallback loader", logger: progressLogger)
                    }
                }
                appLogger.info("✅ Successfully loaded with generic loader fallback")
            }
        } else {
            // Use generic loader for unknown architectures
            appLogger.info("🔍 No architecture detected, using generic loader")
            let progressLogger = appLogger
            let modelId = String(describing: configuration.id)
            container = try await LLMModelFactory.shared.loadContainer(
                hub: hub, configuration: configuration
            ) { progress in
                Task { @MainActor [weak self] in
                    self?.modelDownloadProgress = progress
                    guard let self else { return }
                    self.recordDownloadProgress(for: modelId, progress: progress, context: "Generic loader", logger: progressLogger)
                }
            }
        }

        // Cache the loaded model for future use
        appLogger.info("🔍 Caching loaded model with key: \(cacheKey)")
        modelCache.setObject(container, forKey: cacheKey)
        appLogger.info("✅ Model cached successfully")

        let loadElapsed = Date().timeIntervalSince(loadStart)
        appLogger.info("⏱️ Model load completed in \(String(format: "%.2f", loadElapsed))s for \(configuration.id)")
        await MainActor.run { [weak self] in
            self?.modelDownloadProgress = nil
            self?.lastLoggedDownloadProgress.removeValue(forKey: cacheKeyString)
        }

        appLogger.info("🎉 Model loaded successfully: \(configuration.id)")
        appLogger.info("🎉 Model loading process completed")
        return container
        #else
        appLogger.error("MLX framework not available")
        throw NSError(domain: "MLXService", code: -1, userInfo: [NSLocalizedDescriptionKey: "MLX framework not available"])
        #endif
    }


    /// Detect model architecture from configuration
    /// - Parameter config: The model configuration
    /// - Returns: Detected model architecture type
    private func detectModelArchitecture(from config: MLXLMCommon.ModelConfiguration) -> String? {
        let modelId = String(describing: config.id).lowercased()

        // Check for Qwen models
        if modelId.contains("qwen") {
            return "qwen2"
        }

        // Check for Llama models
        if modelId.contains("llama") {
            return "llama"
        }

        // Check for Mistral models
        if modelId.contains("mistral") {
            return "mistral"
        }

        // Check for Phi models
        if modelId.contains("phi") {
            return "phi"
        }

        // Check for Gemma models
        if modelId.contains("gemma") {
            return "gemma"
        }

        // Default fallback
        return nil
    }

    /// Ensure Qwen model has proper configuration before loading
    /// - Parameter configuration: The model configuration
    /// - Throws: Errors that might occur during configuration setup
    private func ensureQwenModelConfiguration(configuration: MLXLMCommon.ModelConfiguration) async throws {
        let modelId = String(describing: configuration.id)

        // Get the local model directory where MLX stores models
        let homeDirectory = FileManager.default.mlxUserHomeDirectory
        let huggingFaceModelsDir = homeDirectory
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")

        // Extract organization and model name from modelId (e.g., "mlx-community/Qwen1.5-0.5B-Chat-4bit")
        let components = modelId.components(separatedBy: "/")
        guard components.count >= 2 else {
            appLogger.warning("Invalid model ID format: \(modelId)")
            return
        }

        let organization = components[0]  // e.g., "mlx-community"
        let modelName = components[1]      // e.g., "Qwen1.5-0.5B-Chat-4bit"

        // Create model directory path
        let modelDirectory = huggingFaceModelsDir
            .appendingPathComponent(organization)
            .appendingPathComponent(modelName)

        // Create config.json if it doesn't exist or has wrong model type
        let configPath = modelDirectory.appendingPathComponent("config.json")
        appLogger.info("🔍 Ensuring Qwen configuration at path: \(configPath.path)")

        if !FileManager.default.fileExists(atPath: configPath.path) {
            // Create directory structure
            try FileManager.default.createDirectory(
                at: modelDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Create config.json with correct Qwen model type
            let qwenConfig: [String: Any] = [
                "model_type": "qwen2",
                "vocab_size": 151936,
                "hidden_size": 896,
                "intermediate_size": 4864,
                "num_attention_heads": 14,
                "num_hidden_layers": 24,
                "rms_norm_eps": 1e-06,
                "max_position_embeddings": 32768,
                "rope_theta": 1000000.0,
                "eos_token_id": 151643,
                "bos_token_id": 151643,
                "pad_token_id": 151643,
                "tie_word_embeddings": false,
                "torch_dtype": "float16",
                "transformers_version": "4.36.0",
                "_created_by": "MLXService",
                "_qwen_configured": true
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: qwenConfig, options: .prettyPrinted)
            try jsonData.write(to: configPath, options: .atomic)
            appLogger.info("✅ Created config.json for Qwen model: \(modelId)")
        } else {
            // Check if existing config.json has correct model type
            do {
                let data = try Data(contentsOf: configPath)
                if let config = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let modelType = config["model_type"] as? String,
                   modelType != "qwen2" {
                    appLogger.warning("Existing config.json has wrong model type '\(modelType)' for Qwen model, updating...")

                    // Update the config with correct model type
                    var updatedConfig = config
                    updatedConfig["model_type"] = "qwen2"
                    updatedConfig["_qwen_configured"] = true

                    let jsonData = try JSONSerialization.data(withJSONObject: updatedConfig, options: .prettyPrinted)
                    try jsonData.write(to: configPath, options: .atomic)
                    appLogger.info("✅ Updated config.json for Qwen model: \(modelId)")
                }
            } catch {
                appLogger.warning("Failed to read existing config.json for \(modelId): \(error.localizedDescription)")
            }
        }
    }

    /// Load model using architecture-specific loading method
    /// - Parameters:
    ///   - configuration: The model configuration
    ///   - architecture: The detected architecture type
    /// - Returns: A ModelContainer instance
    /// - Throws: Errors that might occur during model loading
    private func loadModelWithArchitecture(
        configuration: MLXLMCommon.ModelConfiguration,
        architecture: String
    ) async throws -> MLXLMCommon.ModelContainer {
        appLogger.info("🔍 loadModelWithArchitecture called with:")
        appLogger.info("🔍   - architecture: \(architecture)")
        appLogger.info("🔍   - model ID: \(configuration.id)")
        appLogger.info("🔍   - platform: \(platformDescription)")

        // Create platform-specific HubApi instance
        let hub = try createPlatformSpecificHubApi()
        appLogger.info("🔍 Created platform-specific HubApi instance in loadModelWithArchitecture")

        // Log cache directory information for debugging
        logCacheDirectoryInfo()

        // For Qwen models, we need to ensure the model type is properly specified
        // The issue is that MLX defaults to Llama loading for unknown architectures
        if architecture == "qwen2" {
            // Try to load Qwen model with specific configuration
            // We may need to use a different approach for Qwen models

            // First, let's try the standard approach but with better error handling
            do {
                appLogger.info("🔍 About to call LLMModelFactory.shared.loadContainer() for Qwen model")
                let progressLogger = appLogger
                let modelId = String(describing: configuration.id)
                let container = try await LLMModelFactory.shared.loadContainer(
                    hub: hub, configuration: configuration
                ) { progress in
                    Task { @MainActor [weak self] in
                        self?.modelDownloadProgress = progress
                        guard let self else { return }
                        self.recordDownloadProgress(for: modelId, progress: progress, context: "Qwen loader", logger: progressLogger)
                    }
                }
                appLogger.info("✅ Successfully loaded Qwen model: \(configuration.id)")
                return container
            } catch let error as NSError {
                // If we get the specific Llama key error, try alternative loading
                if error.localizedDescription.contains("model.embed_tokens.weight") ||
                   error.localizedDescription.contains("LlamaModel") {
                    appLogger.warning("Qwen model loaded as Llama, trying alternative approach")
                    throw error // Re-throw for now, will be caught and fallback used
                } else {
                    throw error
                }
            }
        }

        // For other architectures, try the generic loader first
        appLogger.info("🔍 About to call LLMModelFactory.shared.loadContainer() for generic model")
        let progressLogger = appLogger
        let modelId = String(describing: configuration.id)
        return try await LLMModelFactory.shared.loadContainer(
            hub: hub, configuration: configuration
        ) { progress in
            Task { @MainActor [weak self] in
                self?.modelDownloadProgress = progress
                guard let self else { return }
                self.recordDownloadProgress(for: modelId, progress: progress, context: "Architecture loader", logger: progressLogger)
            }
        }
    }

    /// Generates text based on the provided messages using the specified model configuration.
    /// - Parameters:
    ///   - messages: Array of chat messages including user, assistant, and system messages
    ///   - configuration: The model configuration to use for generation
    /// - Returns: An AsyncStream of generated text tokens
    /// - Throws: Errors that might occur during generation
    public func generate(
        messages: [ChatMessage],
        configuration: MLXLMCommon.ModelConfiguration
    ) async throws -> AsyncThrowingStream<String, Error> {
        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)

        appLogger.info("🔍 MLXService.generate() called with model: \(configuration.id)")
        appLogger.info("🔍 Current working directory: \(FileManager.default.currentDirectoryPath)")
        appLogger.info("🔍 Home directory: \(FileManager.default.mlxUserHomeDirectory.path)")
        appLogger.info("🔍 Application Support directory: \(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path ?? "N/A")")
        appLogger.info("🔍 Caches directory: \(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? "N/A")")

        // Check environment variables
        appLogger.info("🔍 Environment variables:")
        for (key, value) in ProcessInfo.processInfo.environment {
            if key.contains("HUGGING") || key.contains("TRANSFORMER") || key.contains("MLX") || key.contains("CACHE") {
                appLogger.info("🔍   \(key)=\(value)")
            }
        }
        // Detect model architecture to ensure proper loading
        let architecture = detectModelArchitecture(from: configuration)
        appLogger.info("Detected model architecture: \(architecture ?? "unknown") for model: \(configuration.id)")

    // Load or retrieve model from cache
    let containerLoadStart = Date()
    let modelContainer = try await loadModel(configuration: configuration)
    let containerLoadElapsed = Date().timeIntervalSince(containerLoadStart)
    appLogger.info("⏱️ Model container ready in \(String(format: "%.2f", containerLoadElapsed))s for \(configuration.id)")

        // Map ChatMessage to MLX Chat.Message
        let chat = messages.map { message in
            let role: MLXLMCommon.Chat.Message.Role =
                switch message.role {
                case .assistant: .assistant
                case .user: .user
                case .system: .system
                }

            return MLXLMCommon.Chat.Message(
                role: role,
                content: message.content,
                images: [],  // TODO: Add image support
                videos: []   // TODO: Add video support
            )
        }

        // Prepare input for model processing
        let userInput = MLXLMCommon.UserInput(
            chat: chat,
            processing: .init(resize: .init(width: 1024, height: 1024))
        )

        // Generate response using the model and return as AsyncThrowingStream
        return AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                let generationStart = Date()
                var tokenCount = 0
                do {
                    appLogger.info("🌊 Preparing generation context for \(configuration.id)")
                    let contextStart = Date()
                    let generationStream = try await modelContainer.perform { (context: MLXLMCommon.ModelContext) in
                        let lmInput = try await context.processor.prepare(input: userInput)
                        let parameters = MLXLMCommon.GenerateParameters(temperature: 0.7)
                        return try MLXLMCommon.generate(
                            input: lmInput, parameters: parameters, context: context
                        )
                    }
                    let contextElapsed = Date().timeIntervalSince(contextStart)
                    appLogger.info("✅ Model context ready in \(String(format: "%.2f", contextElapsed))s for \(configuration.id)")

                    for try await generation in generationStream {
                        if Task.isCancelled {
                            appLogger.info("⚠️ Generation stream cancelled for \(configuration.id)")
                            break
                        }

                        guard let chunk = Self.extractGeneratedChunk(from: generation) else {
                            appLogger.debug("ℹ️ Skipping non-text generation event: \(String(describing: generation))")
                            continue
                        }

                        tokenCount += 1
                        if tokenCount == 1 {
                            appLogger.info("📝 First token for \(configuration.id): \(chunk.prefix(80))")
                        } else if tokenCount % 25 == 0 {
                            appLogger.info("📝 Generated \(tokenCount) tokens so far for \(configuration.id)")
                        }
                        continuation.yield(chunk)
                    }

                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    let totalElapsed = Date().timeIntervalSince(generationStart)
                    appLogger.info("✅ Generation completed for \(configuration.id) in \(String(format: "%.2f", totalElapsed))s (tokens=\(tokenCount))")
                    continuation.finish()
                } catch {
                    if (error as? CancellationError) != nil {
                        appLogger.info("⚠️ Generation cancelled for model \(configuration.id)")
                        continuation.finish()
                        return
                    }
                    let elapsed = Date().timeIntervalSince(generationStart)
                    appLogger.error("❌ Generation failed for model \(configuration.id) after \(String(format: "%.2f", elapsed))s: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        #else
        appLogger.error("MLX framework not available for generation")
        throw NSError(domain: "MLXService", code: -1, userInfo: [NSLocalizedDescriptionKey: "MLX framework not available"])
        #endif
    }

    /// Unloads all cached models to free memory
    public func unloadAllModels() {
        modelCache.removeAllObjects()
        appLogger.info("All cached models unloaded")
    }

    /// Gets the count of currently cached models
    public var cachedModelCount: Int {
        // NSCache doesn't provide a direct count, but we can estimate
        return 0 // TODO: Implement proper cache counting if needed
    }

    // MARK: - Helper Methods

    /// Get platform description for logging
    private var platformDescription: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Unknown Platform"
        #endif
    }

    /// Log cache directory information for debugging
    private func logCacheDirectoryInfo() {
        do {
            let cacheDir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let hfCacheDir = cacheDir.appendingPathComponent("huggingface").appendingPathComponent("hub")
            appLogger.info("🔍 Cache directory: \(cacheDir.path)")
            appLogger.info("🔍 HuggingFace cache directory: \(hfCacheDir.path)")
            appLogger.info("🔍 Cache directory exists: \(FileManager.default.fileExists(atPath: hfCacheDir.path))")
        } catch {
            appLogger.error("❌ Failed to get cache directory: \(error.localizedDescription)")
        }
    }

    /// Create platform-specific HubApi instance
    private func createPlatformSpecificHubApi() throws -> HubApi {
        // Use the shared file-manager helper so the directory logic stays consistent
    var cacheDir = try FileManagerService.shared.ensureModelsDirectoryExists()

        appLogger.info("🔍 HubApi will access models in: \(cacheDir.path)")
        appLogger.info("🔍 Model format: models--org--model-name (standard HuggingFace)")

        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        // iOS family should keep large caches out of iCloud backups
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
    try? cacheDir.setResourceValues(resourceValues)
        #endif

        let token = HuggingFaceAPI_Client.shared.loadHuggingFaceToken()
        return HubApi(downloadBase: cacheDir, hfToken: token)
    }

    /// Extracts the textual chunk from MLX streaming events.
    /// MLX returns enums such as `chunk(String)`; we reflect to grab the payload
    /// and fall back to parsing the description when needed.
    private static func extractGeneratedChunk(from generation: Any) -> String? {
        if let text = generation as? String {
            return text
        }

        let mirror = Mirror(reflecting: generation)

        if mirror.displayStyle == .enum {
            for child in mirror.children {
                if let label = child.label, label.lowercased().contains("chunk") {
                    if let text = child.value as? String {
                        return text
                    }

                    let nestedMirror = Mirror(reflecting: child.value)
                    for nested in nestedMirror.children {
                        if let text = nested.value as? String {
                            return text
                        }
                    }
                }
            }
        }

        // Fallback: parse description like `chunk("hello")`
        let description = String(describing: generation)
        if let parsed = parseChunkDescription(description) {
            return parsed
        }

        return nil
    }

    private static func parseChunkDescription(_ description: String) -> String? {
    let prefix = "chunk(\""
    let suffix = "\")"
    guard description.hasPrefix(prefix), description.hasSuffix(suffix) else { return nil }

    let start = description.index(description.startIndex, offsetBy: prefix.count)
    let end = description.index(description.endIndex, offsetBy: -suffix.count)
    guard start <= end else { return nil }
    let raw = String(description[start..<end])
        // Decode escaped sequences via JSON decoder for reliability
        let jsonEncoded = "\"\(raw)\""
        if let data = jsonEncoded.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }

        return raw
    }

    @MainActor
    private func recordDownloadProgress(for modelId: String, progress: Progress, context: String, logger: AppLogger) {
        let fractionFromCounts: Double
        if progress.totalUnitCount > 0 {
            fractionFromCounts = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
        } else {
            fractionFromCounts = progress.fractionCompleted
        }

        let clampedFraction = fractionFromCounts.isFinite ? max(0, min(1, fractionFromCounts)) : 0
        let lastLogged = lastLoggedDownloadProgress[modelId] ?? -1
        if clampedFraction + 0.0001 < lastLogged {
            lastLoggedDownloadProgress[modelId] = -1
        }

        let shouldLog: Bool
        if lastLogged < 0 {
            shouldLog = true
        } else if clampedFraction >= 1.0 {
            shouldLog = true
        } else {
            shouldLog = (clampedFraction - lastLogged) >= 0.05
        }

        guard shouldLog else { return }

        lastLoggedDownloadProgress[modelId] = clampedFraction
        let percent = clampedFraction * 100
        let completed = progress.completedUnitCount
        let total = progress.totalUnitCount
        let state: String
        if progress.isFinished {
            state = "finished"
        } else if progress.isPaused {
            state = "paused"
        } else {
            state = "active"
        }

        logger.info("📦 \(context) progress: \(String(format: "%.1f", percent))% (completed=\(completed) total=\(total)) state=\(state)")

        let description = progress.localizedDescription ?? ""
        let additional = progress.localizedAdditionalDescription ?? ""
        if !description.isEmpty || !additional.isEmpty {
            logger.info("📦 \(context) details: \(description) \(additional)")
        }
    }
}

// MLXService primarily operates on the main actor; mark unchecked sendable for closure captures until refactored.
extension MLXService: @unchecked Sendable {}
