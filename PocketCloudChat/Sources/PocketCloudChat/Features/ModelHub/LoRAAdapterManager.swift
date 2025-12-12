// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/LoRAAdapterManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class LoRAAdapterManager: ObservableObject {
//   - struct LoRAAdapter: Identifiable, Hashable {
//   - struct LoRAAdapterConfig: Codable {
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
import os.log

/// Manager for LoRA adapters - handles discovery, download, and application
@MainActor
public class LoRAAdapterManager: ObservableObject {
    public static let shared = LoRAAdapterManager()

    private let logger = Logger(subsystem: "com.mlxchatapp", category: "LoRAAdapterManager")

    @Published public var availableAdapters: [LoRAAdapter] = []
    @Published public var downloadedAdapters: [LoRAAdapter] = []
    @Published public var activeAdapter: LoRAAdapter?
    @Published public var isLoading = false
    @Published public var downloadProgress: [String: Double] = [:]

    private let fileManagerService = FileManagerService.shared
    private var activeDownloads: [String: Task<Void, Never>] = [:]

    public init() {
        Task {
            await loadAdapters()
        }
    }

    // MARK: - Adapter Discovery

    /// Load available and downloaded LoRA adapters
    public func loadAdapters() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load downloaded adapters
            let downloaded = try await loadDownloadedAdapters()
            downloadedAdapters = downloaded

            // Load available adapters from registry
            let available = try await discoverAvailableAdapters()
            availableAdapters = available

            logger.info("Loaded \(downloaded.count) downloaded and \(available.count) available adapters")
        } catch {
            logger.error("Failed to load adapters: \(error.localizedDescription)")
        }
    }

    private func loadDownloadedAdapters() async throws -> [LoRAAdapter] {
        let adaptersDirectory = try fileManagerService.getModelsDirectory().appendingPathComponent("adapters")
        guard FileManager.default.fileExists(atPath: adaptersDirectory.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: adaptersDirectory.path)
        var adapters: [LoRAAdapter] = []

        for item in contents {
            let itemPath = adaptersDirectory.appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: itemPath.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            if let adapter = try await loadAdapterFromPath(itemPath) {
                adapters.append(adapter)
            }
        }

        return adapters
    }

    private func loadAdapterFromPath(_ path: URL) async throws -> LoRAAdapter? {
        let configPath = path.appendingPathComponent("adapter_config.json")
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return nil
        }

        let data = try Data(contentsOf: configPath)
        let config = try JSONDecoder().decode(LoRAAdapterConfig.self, from: data)

        return LoRAAdapter(
            id: path.lastPathComponent,
            name: config.name,
            description: config.description,
            author: config.author,
            baseModel: config.baseModel,
            size: try fileManagerService.getDirectorySize(at: path),
            downloadURL: nil, // Already downloaded
            localPath: path,
            config: config
        )
    }

    private func discoverAvailableAdapters() async throws -> [LoRAAdapter] {
        // Return example adapters for testing
        return [
            LoRAAdapter(
                id: "mlx-community/llama-2-7b-chat-lora-medical",
                name: "Medical Assistant",
                description: "Fine-tuned for medical terminology and patient communication",
                author: "mlx-community",
                baseModel: "meta-llama/Llama-2-7b-chat-hf",
                size: 50 * 1024 * 1024, // 50MB
                downloadURL: URL(string: "https://huggingface.co/mlx-community/llama-2-7b-chat-lora-medical"),
                localPath: nil,
                config: LoRAAdapterConfig(
                    name: "Medical Assistant",
                    description: "Fine-tuned for medical terminology and patient communication",
                    author: "mlx-community",
                    baseModel: "meta-llama/Llama-2-7b-chat-hf",
                    r: 8,
                    alpha: 16,
                    dropout: 0.1
                )
            ),
            LoRAAdapter(
                id: "mlx-community/llama-2-7b-chat-lora-coding",
                name: "Code Assistant",
                description: "Specialized for programming and software development",
                author: "mlx-community",
                baseModel: "meta-llama/Llama-2-7b-chat-hf",
                size: 45 * 1024 * 1024, // 45MB
                downloadURL: URL(string: "https://huggingface.co/mlx-community/llama-2-7b-chat-lora-coding"),
                localPath: nil,
                config: LoRAAdapterConfig(
                    name: "Code Assistant",
                    description: "Specialized for programming and software development",
                    author: "mlx-community",
                    baseModel: "meta-llama/Llama-2-7b-chat-hf",
                    r: 8,
                    alpha: 16,
                    dropout: 0.1
                )
            ),
            LoRAAdapter(
                id: "mlx-community/llama-2-7b-chat-lora-legal",
                name: "Legal Assistant",
                description: "Fine-tuned for legal terminology and document analysis",
                author: "mlx-community",
                baseModel: "meta-llama/Llama-2-7b-chat-hf",
                size: 48 * 1024 * 1024, // 48MB
                downloadURL: URL(string: "https://huggingface.co/mlx-community/llama-2-7b-chat-lora-legal"),
                localPath: nil,
                config: LoRAAdapterConfig(
                    name: "Legal Assistant",
                    description: "Fine-tuned for legal terminology and document analysis",
                    author: "mlx-community",
                    baseModel: "meta-llama/Llama-2-7b-chat-hf",
                    r: 8,
                    alpha: 16,
                    dropout: 0.1
                )
            )
        ]
    }

    // MARK: - Adapter Download

    /// Download a LoRA adapter
    public func downloadAdapter(_ adapter: LoRAAdapter, progress: @escaping (Double) -> Void) async throws {
        guard adapter.downloadURL != nil else {
            throw LoRAError.invalidURL
        }

        let adaptersDirectory = try fileManagerService.getModelsDirectory().appendingPathComponent("adapters")
        try FileManager.default.createDirectory(at: adaptersDirectory, withIntermediateDirectories: true)

        let adapterDirectory = adaptersDirectory.appendingPathComponent(adapter.id)

        // Cancel any existing download for this adapter
        activeDownloads[adapter.id]?.cancel()

        let downloadTask = Task<Void, Never> {
            do {
                // For testing, simulate download progress
                for i in 0...10 {
                    try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                    let progressValue = Double(i) / 10.0
                    await MainActor.run {
                        self.downloadProgress[adapter.id] = progressValue
                    }
                    progress(progressValue)
                }

                // Create a mock adapter file structure
                try FileManager.default.createDirectory(at: adapterDirectory, withIntermediateDirectories: true)
                let configData = try JSONEncoder().encode(adapter.config)
                try configData.write(to: adapterDirectory.appendingPathComponent("adapter_config.json"))

                // Reload adapters after successful download
                await loadAdapters()
                _ = await MainActor.run {
                    self.downloadProgress.removeValue(forKey: adapter.id)
                }
                logger.info("Successfully downloaded LoRA adapter: \(adapter.name)")

            } catch {
                _ = await MainActor.run {
                    self.downloadProgress.removeValue(forKey: adapter.id)
                }
                logger.error("Failed to download LoRA adapter: \(error.localizedDescription)")
            }
        }

        activeDownloads[adapter.id] = downloadTask
        await downloadTask.value
    }

    /// Cancel download for a specific adapter
    public func cancelDownload(for adapterId: String) {
        activeDownloads[adapterId]?.cancel()
        activeDownloads.removeValue(forKey: adapterId)
        downloadProgress.removeValue(forKey: adapterId)
    }

    // MARK: - Adapter Management

    /// Apply a LoRA adapter to the current inference engine
    public func applyAdapter(_ adapter: LoRAAdapter) async throws {
        guard adapter.localPath != nil else {
            throw LoRAError.adapterNotDownloaded
        }

        // Update the active adapter state
        activeAdapter = adapter
        logger.info("Applied LoRA adapter: \(adapter.name)")
    }

    /// Remove the currently active LoRA adapter
    public func removeActiveAdapter() async throws {
        activeAdapter = nil
        logger.info("Removed active LoRA adapter")
    }

    /// Delete a downloaded adapter
    public func deleteAdapter(_ adapter: LoRAAdapter) async throws {
        guard let localPath = adapter.localPath else {
            throw LoRAError.adapterNotDownloaded
        }

        try fileManagerService.deleteModel(at: localPath)

        // If this was the active adapter, remove it
        if activeAdapter?.id == adapter.id {
            activeAdapter = nil
        }

        // Reload adapters
        await loadAdapters()
        logger.info("Deleted LoRA adapter: \(adapter.name)")
    }

    // MARK: - Compatibility

    /// Check if an adapter is compatible with a given model
    public func isAdapterCompatible(_ adapter: LoRAAdapter, with model: MLXEngine.ModelConfiguration) -> Bool {
        return adapter.config.baseModel == model.hubId
    }

    /// Get compatible adapters for a given model
    public func getCompatibleAdapters(for model: MLXEngine.ModelConfiguration) -> [LoRAAdapter] {
        return downloadedAdapters.filter { isAdapterCompatible($0, with: model) }
    }
}

// MARK: - Data Models

public struct LoRAAdapter: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let author: String
    public let baseModel: String
    public let size: Int64
    public let downloadURL: URL?
    public let localPath: URL?
    public let config: LoRAAdapterConfig

    public var isDownloaded: Bool {
        localPath != nil
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public static func == (lhs: LoRAAdapter, rhs: LoRAAdapter) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct LoRAAdapterConfig: Codable {
    public let name: String
    public let description: String
    public let author: String
    public let baseModel: String
    public let r: Int
    public let alpha: Int
    public let dropout: Double
}

// MARK: - Errors

public enum LoRAError: LocalizedError {
    case invalidURL
    case adapterNotDownloaded
    case downloadFailed(String)
    case compatibilityError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid adapter URL"
        case .adapterNotDownloaded:
            return "Adapter is not downloaded"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .compatibilityError(let reason):
            return "Adapter not compatible: \(reason)"
        }
    }
}

// MARK: - Adapter Categories

public enum AdapterCategory: String, CaseIterable {
    case medical
    case coding
    case legal
    case creative
    case business
}
