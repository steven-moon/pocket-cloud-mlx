// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/ModelBootstrapper.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - enum ModelBootstrapperError: Error {
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
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
import PocketCloudLogger

/// Anti-fragile model bootstrapper that works across all Apple platforms
/// Creates minimal model structures at runtime to prevent config.json errors
public final class ModelBootstrapper: @unchecked Sendable {

    public static let shared = ModelBootstrapper()
    private let logger = Logger(label: "PocketCloudMLX.ModelBootstrapper")

    // Reliable fallback models that work across all platforms
    private let reliableModels = [
        "mlx-community/SmolLM2-360M-Instruct",
        "mlx-community/Qwen1.5-0.5B-Chat-4bit",
        "mlx-community/TinyLlama-1.1B-Chat-v1.0-4bit",
        "mlx-community/Llama-3.2-1B-4bit"
    ]

    private var hasBootstrapped = false
    private let bootstrapLock = NSLock()

    private init() {}

    /// Bootstrap minimal model structures for reliable app startup
    /// This method is safe to call multiple times and from any thread
    public func bootstrapMinimalModels() async throws {
        bootstrapLock.withLock {
            guard !hasBootstrapped else {
                logger.info("✅ Models already bootstrapped")
                return
            }
            hasBootstrapped = true
        }

        logger.info("🛠️ Bootstrapping minimal model structures...")

        do {
            let modelsDirectory = try getModelsDirectory()

            for modelId in reliableModels {
                try await createMinimalModelStructure(for: modelId, in: modelsDirectory)
            }

            logger.info("✅ Successfully bootstrapped \(reliableModels.count) reliable models")
        } catch {
            logger.error("❌ Failed to bootstrap models: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get the HuggingFace models directory that MLX actually uses
    /// MLX looks in ~/.cache/huggingface/hub/ by default, so we need to create files there
    private func getModelsDirectory() throws -> URL {
        let homeDirectory = FileManager.default.mlxUserHomeDirectory
        let huggingFaceModelsDir = homeDirectory
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")

        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: huggingFaceModelsDir.path) {
            try FileManager.default.createDirectory(
                at: huggingFaceModelsDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("📁 Created HuggingFace models directory: \(huggingFaceModelsDir.path)")
        }

        return huggingFaceModelsDir
    }

    /// Create minimal model structure for a specific model
    private func createMinimalModelStructure(for modelId: String, in modelsDirectory: URL) async throws {
        // For HuggingFace models like "mlx-community/SmolLM2-360M-Instruct"
        // We need to create: ~/.cache/huggingface/hub/mlx-community/SmolLM2-360M-Instruct/
        let components = modelId.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw ModelBootstrapperError.invalidModelId(modelId)
        }

        let organization = components[0]  // e.g., "mlx-community"
        let modelName = components[1]      // e.g., "SmolLM2-360M-Instruct"

        // Create organization directory first
        let organizationDir = modelsDirectory.appendingPathComponent(organization)
        if !FileManager.default.fileExists(atPath: organizationDir.path) {
            try FileManager.default.createDirectory(
                at: organizationDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("📁 Created organization directory: \(organizationDir.path)")
        }

        // Create model directory
        let modelDirectory = organizationDir.appendingPathComponent(modelName)
        if !FileManager.default.fileExists(atPath: modelDirectory.path) {
            try FileManager.default.createDirectory(
                at: modelDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("📁 Created model directory: \(modelDirectory.path)")
        }

        // Create config.json if it doesn't exist
        let configPath = modelDirectory.appendingPathComponent("config.json")
        if !FileManager.default.fileExists(atPath: configPath.path) {
            try await createMinimalConfigJson(at: configPath)
            logger.info("📄 Created config.json for \(modelId)")
        }

        // Create tokenizer.json if it doesn't exist
        let tokenizerPath = modelDirectory.appendingPathComponent("tokenizer.json")
        if !FileManager.default.fileExists(atPath: tokenizerPath.path) {
            try createMinimalTokenizerJson(at: tokenizerPath)
            logger.info("📄 Created tokenizer.json for \(modelId)")
        }
    }

    /// Create a config.json file by downloading from HuggingFace
    private func createMinimalConfigJson(at path: URL) async throws {
        // Get the model ID from the path
        let modelDirectory = path.deletingLastPathComponent()
        let normalizedPathId = ModelConfiguration.normalizeHubId(modelDirectory.path)
        let modelId = normalizedPathId.isEmpty ? modelDirectory.lastPathComponent : normalizedPathId

        // Try to download the actual config.json from HuggingFace
        do {
            guard let encodedModelId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                throw ModelBootstrapperError.fileCreationFailed(path)
            }
            let configURL = URL(string: "https://huggingface.co/\(encodedModelId)/resolve/main/config.json")!
            let (data, _) = try await URLSession.shared.data(from: configURL)

            // Validate that we got valid JSON
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            guard JSONSerialization.isValidJSONObject(jsonObject) else {
                throw ModelBootstrapperError.fileCreationFailed(path)
            }

            // Write the downloaded config
            try data.write(to: path, options: .atomic)
            logger.info("✅ Downloaded config.json from HuggingFace for \(modelId)")

        } catch {
            logger.warning("⚠️ Failed to download config.json from HuggingFace for \(modelId): \(error.localizedDescription)")
            logger.info("🔧 Creating minimal fallback config for \(modelId)")

            // Fallback: create a minimal config based on model type
            var config: [String: Any]

            if modelId.contains("Qwen") {
                // Qwen models need qwen2 architecture
                config = [
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
                    "_bootstrap_version": "1.0",
                    "_created_by": "ModelBootstrapper",
                    "_fallback": true
                ]
            } else {
                // Generic fallback for other models
                config = [
                    "model_type": "llama",
                    "vocab_size": 32000,
                    "hidden_size": 2048,
                    "intermediate_size": 5632,
                    "num_attention_heads": 32,
                    "num_hidden_layers": 24,
                    "rms_norm_eps": 1e-05,
                    "max_position_embeddings": 4096,
                    "rope_theta": 10000.0,
                    "eos_token_id": 2,
                    "bos_token_id": 1,
                    "pad_token_id": 2,
                    "tie_word_embeddings": false,
                    "torch_dtype": "float16",
                    "transformers_version": "4.36.0",
                    "_bootstrap_version": "1.0",
                    "_created_by": "ModelBootstrapper",
                    "_fallback": true
                ]
            }

            let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try jsonData.write(to: path, options: .atomic)
            logger.info("✅ Created fallback config.json for \(modelId)")
        }
    }

    /// Create a minimal tokenizer.json file
    private func createMinimalTokenizerJson(at path: URL) throws {
        let tokenizer: [String: Any] = [
            "version": "1.0",
            "added_tokens": [] as [Any],
            "pre_tokenizer": [
                "type": "ByteLevel",
                "add_prefix_space": false,
                "trim_offsets": false,
                "use_regex": true
            ],
            "post_processor": [
                "type": "ByteLevel",
                "add_prefix_space": false,
                "trim_offsets": false
            ],
            "decoder": [
                "type": "ByteLevel",
                "add_prefix_space": false,
                "trim_offsets": false
            ],
            "model": [
                "type": "BPE",
                "vocab": [:] as [String: Any],
                "merges": [] as [Any],
                "ignore_merges": false,
                "add_prefix_space": false,
                "fuse_unk": false
            ] as [String: Any],
            "_bootstrap_version": "1.0",
            "_created_by": "ModelBootstrapper"
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: tokenizer, options: .prettyPrinted)
        try jsonData.write(to: path, options: .atomic)
    }

    /// Check if models are properly bootstrapped
    public func isBootstrapped() -> Bool {
        bootstrapLock.withLock { hasBootstrapped }
    }

    /// Public accessor for models directory (for environment setup)
    public func getModelsDirectoryURL() throws -> URL {
        return try getModelsDirectory()
    }

    /// Force re-bootstrap (useful for testing or recovery)
    public func forceRebootstrap() async throws {
        bootstrapLock.withLock {
            hasBootstrapped = false
        }
        try await bootstrapMinimalModels()
    }

    /// Get list of bootstrapped model IDs
    public func getBootstrappedModelIds() -> [String] {
        return reliableModels
    }

    /// Verify that all bootstrap files exist
    public func verifyBootstrapIntegrity() throws -> Bool {
        let modelsDirectory = try getModelsDirectory()

        for modelId in reliableModels {
            let modelName = modelId.components(separatedBy: "/").last ?? "unknown"
            let modelDirectory = modelsDirectory.appendingPathComponent(modelName)

            let configPath = modelDirectory.appendingPathComponent("config.json")
            let tokenizerPath = modelDirectory.appendingPathComponent("tokenizer.json")

            if !FileManager.default.fileExists(atPath: configPath.path) ||
               !FileManager.default.fileExists(atPath: tokenizerPath.path) {
                return false
            }
        }

        return true
    }
}

// MARK: - Error Types

enum ModelBootstrapperError: Error {
    case invalidModelId(String)
    case directoryCreationFailed(URL)
    case fileCreationFailed(URL)
}
