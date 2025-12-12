// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ModelDiscoveryManager: ObservableObject
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryViewModel.swift
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryDebugView.swift
//
// == End LLM Context Header ==
@preconcurrency import Foundation
import SwiftUI
import MLXEngine
import AIDevLogger
import os.log

@MainActor
final class ModelDiscoveryManager: ObservableObject {
    static let shared = ModelDiscoveryManager()

    let api = HuggingFaceAPI.shared
    let downloadLogger = Logger(label: "ModelDiscoveryManager.Download", level: .debug)

    // Published download state shared across the app
    @Published var downloadingModels: Set<String> = [] {
        didSet {
            downloadLogger.debug("🔍 DIAGNOSTIC: downloadingModels changed from \(oldValue.count) to \(downloadingModels.count) items")
            if oldValue != downloadingModels {
                downloadLogger.debug("🔍 DIAGNOSTIC: downloadingModels details - Added: \(downloadingModels.subtracting(oldValue)), Removed: \(oldValue.subtracting(downloadingModels))")
            }
        }
    }
    @Published var downloadProgress: [String: Double] = [:] {
        didSet {
            if downloadProgress.count != oldValue.count {
                downloadLogger.debug("🔍 DIAGNOSTIC: downloadProgress changed from \(oldValue.count) to \(downloadProgress.count) entries")
            }
        }
    }
    @Published var totalBytesByModel: [String: Int64] = [:]
    @Published var downloadedBytesByModel: [String: Int64] = [:]
    @Published var downloadedModelIds: Set<String> = [] {
        didSet {
            downloadLogger.debug("🔍 DIAGNOSTIC: downloadedModelIds changed from \(oldValue.count) to \(downloadedModelIds.count) items")
            if oldValue != downloadedModelIds {
                downloadLogger.debug("🔍 DIAGNOSTIC: downloadedModelIds details - Added: \(downloadedModelIds.subtracting(oldValue)), Removed: \(oldValue.subtracting(downloadedModelIds))")
            }
        }
    }

    func normalizedHubId(for hubId: String) -> String? {
        Self.normalizedHubId(from: hubId)
    }

    func containsDownloadedModel(id: String) -> Bool {
        guard let normalized = normalizedHubId(for: id) else { return false }
        return downloadedModelIds.contains(normalized)
    }
    struct ActiveDownloadFile: Equatable {
        let name: String
        let index: Int
        let total: Int
        let downloadedBytes: Int64?
        let totalBytes: Int64?
        let progress: Double?
    }
    struct LocalModelFile: Identifiable, Sendable {
        let id: String
        let displayName: String
        let size: Int64?

        init(path: String, displayName: String, size: Int64?) {
            self.id = path
            self.displayName = displayName
            self.size = size
        }
    }
    struct DownloadEventData: Sendable {
        let hubId: String
        let event: String
        let index: Int?
        let total: Int?
        let totalFiles: Int?
        let fileName: String?
        let downloadedBytes: Int64?
        let totalBytes: Int64?
        let fileProgress: Double?
        let overallProgress: Double?
        let overallDownloadedBytes: Int64?
        let overallTotalBytes: Int64?
        let fileSize: Int64?
    }
    @Published var activeDownloadFiles: [String: ActiveDownloadFile] = [:]
    @Published var completedFileCount: [String: Int] = [:]
    @Published var totalFileCount: [String: Int] = [:]

    // Verification state (post-download integrity checks)
    @Published var verifyingModels: Set<String> = []
    @Published var verifyScanIndex: [String: Int] = [:]
    @Published var verifyScanTotal: [String: Int] = [:]
    @Published var verifySrcBytes: [String: Int64] = [:]
    @Published var verifyTgtBytes: [String: Int64] = [:]
    @Published var verificationMessages: [String: [String]] = [:]
    @Published var verificationProgress: [String: Double] = [:]
    @Published var verifyMissingCount: [String: Int] = [:]
    @Published var verifyCorruptCount: [String: Int] = [:]
    @Published var verifyRepairedCount: [String: Int] = [:]
    @Published var verifyTotalToRepair: [String: Int] = [:]
    @Published var verifyElapsed: [String: Double] = [:]
    @Published var verifySourcePath: [String: String] = [:]
    @Published var verifyTargetPath: [String: String] = [:]

    struct DownloadErrorInfo: Equatable, Sendable {
        let message: String
        let timestamp: Date
    }
    @Published var downloadErrors: [String: DownloadErrorInfo] = [:]

    var activeTasks: [String: Task<Void, Never>] = [:]
    var lastLoggedProgress: [String: Double] = [:]
    var lastProgressTimestamp: [String: Date] = [:]
    private var observers: [NSObjectProtocol] = []
    var completedBytesAccumulated: [String: Int64] = [:]

    private init() {
        Task { @MainActor in await refreshDownloadedModels() }

        let verificationObserver = NotificationCenter.default.addObserver(
            forName: .mlxModelVerificationProgress,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let info = note.userInfo as? [String: Any],
                  let eventData = makeVerificationEventData(info: info) else { return }
            Task { @MainActor [weak self, eventData] in
                guard let self else { return }
                self.processVerificationEvent(eventData)
            }
        }
        observers.append(verificationObserver)

        let downloadObserver = NotificationCenter.default.addObserver(
            forName: .mlxModelDownloadProgress,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let info = note.userInfo as? [String: Any],
                  let payload = parseDownloadEventData(info: info) else { return }
            Task { @MainActor [weak self, payload] in
                guard let self else { return }
                self.processDownloadEvent(payload)
            }
        }
        observers.append(downloadObserver)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
