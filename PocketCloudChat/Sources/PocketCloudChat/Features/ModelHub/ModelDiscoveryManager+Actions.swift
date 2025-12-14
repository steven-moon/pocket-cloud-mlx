import Foundation
import PocketCloudMLX
import PocketCloudLogger
#if canImport(MLXLLM)
import MLXLLM
#endif

@MainActor
extension ModelDiscoveryManager {
    func startDownload(for model: HuggingFaceModel) async {
        downloadLogger.warning("🔍 DIAGNOSTIC: startDownload called for: \(model.id)")

        // Validate that the model is supported by MLX before allowing download
        guard await isModelSupportedByMLX(model) else {
            downloadLogger.error("❌ Model \(model.id) is not supported by MLX. Download cancelled.")
            await MainActor.run {
                self.setDownloadError(
                    DownloadErrorInfo(
                        message: "This model is not supported by MLX. Only models officially supported by the MLX framework can be downloaded.",
                        timestamp: Date()
                    ),
                    for: model.id
                )
            }
            return
        }

        downloadLogger.warning("🔍 DIAGNOSTIC: downloadingModels contains \(downloadingModels.count) items: \(downloadingModels)")

        guard !downloadingModels.contains(model.id) else {
            downloadLogger.error("🔍 DIAGNOSTIC: Model \(model.id) is ALREADY in downloadingModels! Returning early without starting download.")
            return
        }

        downloadLogger.warning("🔍 DIAGNOSTIC: Adding \(model.id) to downloadingModels")
        downloadingModels.insert(model.id)
        downloadLogger.warning("🔍 DIAGNOSTIC: Setting downloadProgress to 0")
        downloadProgress[model.id] = 0
        downloadLogger.warning("🔍 DIAGNOSTIC: Setting downloadedBytesByModel to 0")
        downloadedBytesByModel[model.id] = 0
        clearDownloadError(for: model.id)
        downloadLogger.warning("🔍 DIAGNOSTIC: Clearing activeDownloadFiles")
        activeDownloadFiles.removeValue(forKey: model.id)
        completedFileCount[model.id] = 0
        totalFileCount.removeValue(forKey: model.id)
        completedBytesAccumulated[model.id] = 0
        downloadLogger.warning("🔍 DIAGNOSTIC: About to log 'Initiating download'")
        downloadLogger.info("📥 Initiating download", context: Logger.Context(["hubId": model.id]))
        downloadLogger.warning("🔍 DIAGNOSTIC: After logging 'Initiating download', about to create Tasks")

        // Pre-compute total bytes where possible
        downloadLogger.warning("🔍 DIAGNOSTIC: Creating Task for pre-computing total bytes")
        Task { [weak self] in
            guard let self else {
                self?.downloadLogger.warning("🔍 DIAGNOSTIC: Pre-compute Task - self is nil")
                return
            }
            self.downloadLogger.warning("🔍 DIAGNOSTIC: Pre-compute Task executing")
            do {
                let files = try await api.listModelFiles(modelId: model.id)
                var total: Int64 = 0
                for file in files {
                    do {
                        let size = try await api.getFileSize(modelId: model.id, fileName: file)
                        total += size
                    } catch { continue }
                }
                await MainActor.run { if total > 0 { self.totalBytesByModel[model.id] = total } }
            } catch {
                // best-effort
            }
        }

        // Run the downloader; its Task is independent of the view lifecycle
        downloadLogger.warning("🔍 DIAGNOSTIC: Creating main download Task")
        let task = Task { [weak self] in
            guard let self else {
                self?.downloadLogger.warning("🔍 DIAGNOSTIC: Main download Task - self is nil")
                return
            }
            self.downloadLogger.warning("🔍 DIAGNOSTIC: Main download Task executing for \(model.id)")
            do {
                self.downloadLogger.warning("🔍 DIAGNOSTIC: About to call model.toModelConfiguration() for \(model.id)")
                let config = model.toModelConfiguration()
                self.downloadLogger.warning("🔍 DIAGNOSTIC: toModelConfiguration() returned, config.hubId=\(config.hubId)")
                self.downloadLogger.warning("🔍 DIAGNOSTIC: About to call downloadWithRetries for \(model.id)")
                _ = try await self.downloadWithRetries(config) { [weak self] pct in
                    Task { @MainActor in
                        guard let self else { return }
                        self.downloadProgress[model.id] = pct
                        if let total = self.totalBytesByModel[model.id] {
                            let downloaded = Int64(Double(total) * pct)
                            self.downloadedBytesByModel[model.id] = downloaded
                        }
                        self.logProgressIfNeeded(for: model.id, progress: pct)
                        // When progress reaches 100%, surface a verification indicator in UI
                        if pct >= 0.999 && !self.verifyingModels.contains(model.id) {
                            self.verifyingModels.insert(model.id)
                        }
                    }
                }
                await MainActor.run {
                    self.downloadingModels.remove(model.id)
                    self.downloadProgress.removeValue(forKey: model.id)
                    self.downloadedBytesByModel.removeValue(forKey: model.id)
                    if let normalized = Self.normalizedHubId(from: model.id) {
                        self.downloadedModelIds.insert(normalized)
                    } else {
                        self.downloadedModelIds.insert(model.id)
                    }
                    self.verifyingModels.remove(model.id)
                    self.activeDownloadFiles.removeValue(forKey: model.id)
                    self.completedFileCount.removeValue(forKey: model.id)
                    self.totalFileCount.removeValue(forKey: model.id)
                    self.completedBytesAccumulated.removeValue(forKey: model.id)
                    self.clearDownloadError(for: model.id)
                }
                self.downloadLogger.info("✅ Download complete", context: Logger.Context(["hubId": model.id]))
                self.lastLoggedProgress.removeValue(forKey: model.id)
                self.lastProgressTimestamp.removeValue(forKey: model.id)
            } catch {
                self.downloadLogger.error("❌ Download failed: \(error.localizedDescription)", context: Logger.Context(["hubId": model.id]))
                // Intentionally ignore the result of MainActor.run
                _ = await MainActor.run {
                    self.downloadingModels.remove(model.id)
                    self.verifyingModels.remove(model.id)
                    self.activeDownloadFiles.removeValue(forKey: model.id)
                    self.completedFileCount.removeValue(forKey: model.id)
                    self.totalFileCount.removeValue(forKey: model.id)
                    self.completedBytesAccumulated.removeValue(forKey: model.id)
                    self.setDownloadError(
                        DownloadErrorInfo(
                            message: error.localizedDescription,
                            timestamp: Date()
                        ),
                        for: model.id
                    )
                }
                self.lastLoggedProgress.removeValue(forKey: model.id)
                self.lastProgressTimestamp.removeValue(forKey: model.id)
            }
        }
        downloadLogger.warning("🔍 DIAGNOSTIC: Storing task in activeTasks for \(model.id)")
        activeTasks[model.id] = task
        downloadLogger.warning("🔍 DIAGNOSTIC: startDownload function ENDING for \(model.id)")
    }

    func downloadModel(_ config: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let id = config.hubId
        if !downloadingModels.contains(id) {
            downloadingModels.insert(id)
            downloadProgress[id] = 0
        }
        activeDownloadFiles.removeValue(forKey: id)
        completedFileCount[id] = 0
        totalFileCount.removeValue(forKey: id)
        completedBytesAccumulated[id] = 0
        clearDownloadError(for: id)
        downloadLogger.info("📥 Initiating configuration download", context: Logger.Context(["hubId": id, "strategy": config.loadStrategy.rawValue]))
        do {
            let url = try await downloadWithRetries(config) { [weak self] pct in
                Task { @MainActor in
                    guard let self else { return }
                    self.downloadProgress[id] = pct
                    progress(pct)
                    if let total = self.totalBytesByModel[id] {
                        self.downloadedBytesByModel[id] = Int64(Double(total) * pct)
                    }
                    self.logProgressIfNeeded(for: id, progress: pct)
                    if pct >= 0.999 && !self.verifyingModels.contains(id) {
                        self.verifyingModels.insert(id)
                    }
                }
            }
            await MainActor.run {
                self.downloadingModels.remove(id)
                self.downloadProgress.removeValue(forKey: id)
                self.downloadedBytesByModel.removeValue(forKey: id)
                self.verifyingModels.remove(id)
                self.activeDownloadFiles.removeValue(forKey: id)
                self.completedFileCount.removeValue(forKey: id)
                self.totalFileCount.removeValue(forKey: id)
                self.completedBytesAccumulated.removeValue(forKey: id)
                self.clearDownloadError(for: id)
            }
            lastLoggedProgress.removeValue(forKey: id)
            lastProgressTimestamp.removeValue(forKey: id)
            return url
        } catch {
            await MainActor.run {
                self.downloadingModels.remove(id)
                self.downloadProgress.removeValue(forKey: id)
                self.downloadedBytesByModel.removeValue(forKey: id)
                self.verifyingModels.remove(id)
                self.activeDownloadFiles.removeValue(forKey: id)
                self.completedFileCount.removeValue(forKey: id)
                self.totalFileCount.removeValue(forKey: id)
                self.completedBytesAccumulated.removeValue(forKey: id)
                self.setDownloadError(
                    DownloadErrorInfo(
                        message: error.localizedDescription,
                        timestamp: Date()
                    ),
                    for: id
                )
            }
            lastLoggedProgress.removeValue(forKey: id)
            lastProgressTimestamp.removeValue(forKey: id)
            throw error
        }
    }

    func prefetchTotalBytes(for modelId: String) async {
        if totalBytesByModel[modelId] != nil { return }
        do {
            let files = try await api.listModelFiles(modelId: modelId)
            var total: Int64 = 0
            for file in files {
                do {
                    let size = try await api.getFileSize(modelId: modelId, fileName: file)
                    total += size
                } catch { continue }
            }
            await MainActor.run { if total > 0 { self.totalBytesByModel[modelId] = total } }
        } catch {
            // best-effort; leave unknown if unavailable
        }
    }

    private func downloadWithRetries(_ config: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void, maxRetries: Int = 3) async throws -> URL {
        downloadLogger.warning("🔍 DIAGNOSTIC: downloadWithRetries ENTERED for \(config.hubId)")
        var attempt = 0
        var lastError: Error?
        while attempt < maxRetries {
            do {
                downloadLogger.warning("🔍 DIAGNOSTIC: Starting download attempt \(attempt + 1) of \(maxRetries) for \(config.hubId)")
                downloadLogger.info("⬇️ Attempt \(attempt + 1) of \(maxRetries)", context: Logger.Context(["hubId": config.hubId]))
                // Use the existing OptimizedDownloader
                downloadLogger.warning("🔍 DIAGNOSTIC: Creating OptimizedDownloader instance")
                let downloader = OptimizedDownloader()
                let useResume = config.loadStrategy != .forceRedownload
                let methodName = useResume ? "downloadModelWithResume" : "downloadModel"
                downloadLogger.warning("🔍 DIAGNOSTIC: Using \(methodName) for \(config.hubId)")
                let result: URL
                if useResume {
                    result = try await downloader.downloadModelWithResume(config, progress: progress)
                } else {
                    result = try await downloader.downloadModel(config, progress: progress)
                }
                downloadLogger.warning("🔍 DIAGNOSTIC: Downloader returned successfully: \(result)")
                return result
            } catch {
                lastError = error
                downloadLogger.warning("⚠️ Attempt \(attempt + 1) failed: \(error.localizedDescription)", context: Logger.Context(["hubId": config.hubId]))
                // Retry on common transient network issues
                if let urlError = error as? URLError,
                   urlError.code == .networkConnectionLost || urlError.code == .timedOut || urlError.code == .cannotFindHost || urlError.code == .cannotConnectToHost || urlError.code == .notConnectedToInternet {
                    attempt += 1
                    let backoff = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                    let seconds = Double(backoff) / 1_000_000_000
                    downloadLogger.info("⏳ Backing off for \(String(format: "%.1f", seconds)) seconds before retry", context: Logger.Context(["hubId": config.hubId]))
                    try? await Task.sleep(nanoseconds: backoff)
                    continue
                }
                break
            }
        }
        if let lastError {
            downloadLogger.error("❌ Exhausted retries: \(lastError.localizedDescription)", context: Logger.Context(["hubId": config.hubId]))
        }
        throw lastError ?? NSError(domain: "ModelDiscoveryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download failed with unknown error"])
    }

    func cancelDownload(modelId: String) async {
        if let t = activeTasks[modelId] { t.cancel() }
        activeTasks.removeValue(forKey: modelId)
        downloadingModels.remove(modelId)
        downloadProgress.removeValue(forKey: modelId)
        downloadedBytesByModel.removeValue(forKey: modelId)
        activeDownloadFiles.removeValue(forKey: modelId)
        completedFileCount.removeValue(forKey: modelId)
        totalFileCount.removeValue(forKey: modelId)
        completedBytesAccumulated.removeValue(forKey: modelId)
        downloadLogger.info("🛑 Download cancelled", context: Logger.Context(["hubId": modelId]))
        lastLoggedProgress.removeValue(forKey: modelId)
        lastProgressTimestamp.removeValue(forKey: modelId)
    }

    func deleteDownloadedFiles(modelId: String) async {
        let logger = Logger(label: "ModelDiscoveryManager.deleteDownloadedFiles")
        logger.info("🗑️ Starting deletion of model: \(modelId)")

        do {
            let base = try FileManagerService.shared.ensureModelsDirectoryExists()
            let normalizedId = PocketCloudMLX.ModelConfiguration.normalizeHubId(modelId)
            let possibleDirs = Self.modelDirectoryCandidates(modelId: modelId, normalizedId: normalizedId, base: base)

            var deletedPaths: [String] = []
            var attemptedDirs: [URL] = []
            var seen: Set<URL> = []

            for rawDir in possibleDirs {
                let dir = rawDir.standardizedFileURL
                if !seen.insert(dir).inserted { continue }

                attemptedDirs.append(dir)
                logger.info("🔍 Checking possible location: \(dir.path)")

                if FileManager.default.fileExists(atPath: dir.path) {
                    logger.info("✅ Found model directory at: \(dir.path)")
                    logger.info("🗑️ Deleting model directory...")

                    try FileManager.default.removeItem(at: dir)
                    deletedPaths.append(dir.path)

                    if FileManager.default.fileExists(atPath: dir.path) {
                        logger.error("❌ Model directory still exists after deletion attempt: \(dir.path)")
                    } else {
                        logger.info("✅ Successfully deleted model directory: \(dir.lastPathComponent)")
                    }
                }
            }

            if deletedPaths.isEmpty {
                logger.warning("⚠️ Model directory not found in any expected location for: \(modelId)")
                logger.info("📂 Searched in base directory: \(base.path)")
                logger.info("🔍 Possible directory names tried:")
                for dir in attemptedDirs {
                    logger.info("  - \(dir.lastPathComponent)")
                }

                // List actual contents of base directory for debugging
                if FileManager.default.fileExists(atPath: base.path) {
                    let contents = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
                    logger.info("📁 Actual contents of base directory:")
                    for item in contents.prefix(10) {
                        logger.info("  - \(item)")
                    }
                    if contents.count > 10 {
                        logger.info("  ... and \(contents.count - 10) more items")
                    }
                }
            } else {
                for path in deletedPaths {
                    logger.info("🎉 Deleted model artifacts for \(modelId) at: \(path)")
                }
            }

        } catch {
            logger.error("❌ Failed to delete model \(modelId): \(error.localizedDescription)")
            logger.error("❌ Error details: \(error)")
        }

        // Clean up internal state regardless of deletion success
        totalBytesByModel.removeValue(forKey: modelId)
        downloadedBytesByModel.removeValue(forKey: modelId)
        clearDownloadError(for: modelId)
        if let normalized = Self.normalizedHubId(from: modelId) {
            downloadedModelIds.remove(normalized)
        }
        downloadedModelIds.remove(modelId)

        // Refresh the downloaded models list
        await refreshDownloadedModels()
        logger.info("🔄 Refreshed downloaded models list after deletion attempt")
    }

    func listLocalFiles(for modelId: String, limit: Int = 40) async -> [LocalModelFile] {
        guard let normalized = Self.normalizedHubId(from: modelId) else { return [] }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result: [LocalModelFile]
                do {
                    let base = try FileManagerService.shared.ensureModelsDirectoryExists()
                    let candidates = Self.modelDirectoryCandidates(modelId: modelId, normalizedId: normalized, base: base)

                    var files: [LocalModelFile] = []
                    var seen = Set<String>()

                    for dir in candidates {
                        guard FileManager.default.fileExists(atPath: dir.path) else { continue }

                        if let enumerator = FileManager.default.enumerator(
                            at: dir,
                            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                            options: [.skipsHiddenFiles]
                        ) {
                            for case let fileURL as URL in enumerator {
                                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                                guard values?.isRegularFile == true else { continue }

                                let relative = fileURL.path.replacingOccurrences(of: dir.path + "/", with: "")
                                let identifier = fileURL.path
                                if !seen.insert(identifier).inserted { continue }

                                let size = values?.fileSize.map { Int64($0) }
                                let display = relative.isEmpty ? fileURL.lastPathComponent : relative
                                files.append(LocalModelFile(path: identifier, displayName: display, size: size))

                                if files.count >= limit { break }
                            }
                        }

                        if files.count >= limit { break }
                    }

                    result = files.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                } catch {
                    result = []
                }

                continuation.resume(returning: result)
            }
        }
    }

    nonisolated private static func modelDirectoryCandidates(modelId: String, normalizedId: String, base: URL) -> [URL] {
        var candidates: Set<URL> = []
        let components = normalizedId.split(separator: "/").map(String.init)

        candidates.insert(base.appendingPathComponent(normalizedId, isDirectory: true))

        if components.count == 2 {
            let owner = components[0]
            let repo = components[1]
            let privateOwner = "private" + owner

            let modelsRoot = base.appendingPathComponent("models", isDirectory: true)
            candidates.insert(modelsRoot.appendingPathComponent(owner, isDirectory: true).appendingPathComponent(repo, isDirectory: true))
            candidates.insert(modelsRoot.appendingPathComponent(privateOwner, isDirectory: true).appendingPathComponent(repo, isDirectory: true))

            let hfRoot = base.appendingPathComponent("models--\(owner)--\(repo)", isDirectory: true)
            candidates.insert(hfRoot)
            candidates.insert(hfRoot.appendingPathComponent("snapshots", isDirectory: true))
            candidates.insert(hfRoot.appendingPathComponent("snapshots/main", isDirectory: true))
            candidates.insert(hfRoot.appendingPathComponent("refs", isDirectory: true))

            let privateRoot = base.appendingPathComponent("models--\(privateOwner)--\(repo)", isDirectory: true)
            candidates.insert(privateRoot)
            candidates.insert(privateRoot.appendingPathComponent("snapshots", isDirectory: true))
            candidates.insert(privateRoot.appendingPathComponent("snapshots/main", isDirectory: true))
            candidates.insert(privateRoot.appendingPathComponent("refs", isDirectory: true))

            candidates.insert(base.appendingPathComponent(owner, isDirectory: true).appendingPathComponent(repo, isDirectory: true))
            candidates.insert(base.appendingPathComponent(privateOwner, isDirectory: true).appendingPathComponent(repo, isDirectory: true))
        }

        candidates.insert(base.appendingPathComponent("id(\"\(normalizedId)\", revision: \"main\")", isDirectory: true))

        let filesystemFormat = modelId.replacingOccurrences(of: "/", with: "--")
        candidates.insert(base.appendingPathComponent("models--\(filesystemFormat)", isDirectory: true))

        if FileManager.default.fileExists(atPath: base.path),
           let contents = try? FileManager.default.contentsOfDirectory(atPath: base.path) {
            let tokens = directorySearchTokens(modelId: modelId, normalizedId: normalizedId, components: components)
            for item in contents {
                let itemPath = base.appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemPath.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    if tokens.contains(where: { item.contains($0) }) ||
                        Self.extractHuggingFaceModelId(from: item) == modelId ||
                        Self.extractHuggingFaceModelId(from: item) == normalizedId {
                        candidates.insert(itemPath)
                    }
                }
            }
        }

        return Array(candidates).map { $0.standardizedFileURL }
    }

    nonisolated private static func directorySearchTokens(modelId: String, normalizedId: String, components: [String]) -> [String] {
        var values: Set<String> = []

        for source in [modelId, normalizedId] {
            values.insert(source.replacingOccurrences(of: "/", with: "--"))
            values.insert(source.replacingOccurrences(of: "/", with: "_"))
        }

        if components.count == 2 {
            let owner = components[0]
            let repo = components[1]
            let privateOwner = "private" + owner
            values.insert("\(privateOwner)--\(repo)")
            values.insert("\(privateOwner)_\(repo)")
        }

        return values.filter { !$0.isEmpty }
    }

    private func setDownloadError(_ errorInfo: DownloadErrorInfo, for hubId: String) {
        downloadErrors[hubId] = errorInfo
        if let normalized = Self.normalizedHubId(from: hubId) {
            downloadErrors[normalized] = errorInfo
        }
    }

    private func clearDownloadError(for hubId: String) {
        downloadErrors.removeValue(forKey: hubId)
        if let normalized = Self.normalizedHubId(from: hubId) {
            downloadErrors.removeValue(forKey: normalized)
        }
    }

    func refreshDownloadedModels() async {
        do {
            let models = try await OptimizedDownloader().getDownloadedModels()
            let normalizedIds = models.compactMap { Self.normalizedHubId(from: $0.hubId) }
            let newDownloadedModelIds = Set(normalizedIds)
            await MainActor.run {
                if self.downloadedModelIds != newDownloadedModelIds {
                    self.downloadedModelIds = newDownloadedModelIds
                }
            }
        } catch {
            await MainActor.run {
                if !self.downloadedModelIds.isEmpty {
                    self.downloadedModelIds.removeAll()
                }
            }
        }
    }

    static func isValidHubId(_ hubId: String) -> Bool {
        normalizedHubId(from: hubId) != nil
    }

    static func normalizedHubId(from hubId: String) -> String? {
        let sanitized = hubId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return nil }

        var components = sanitized.split(separator: "/").map { String($0) }
        if components.isEmpty { return nil }

        if components.first == "privatemodels" {
            components.removeFirst()
        }

        if var owner = components.first, owner.hasPrefix("private"), owner.count > "private".count {
            owner.removeFirst("private".count)
            guard !owner.isEmpty else { return nil }
            components[0] = owner
        }

        guard components.count >= 2 else { return nil }
        if components.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return nil
        }

        let normalized = components.joined(separator: "/")
        return PocketCloudMLX.ModelConfiguration.normalizeHubId(normalized)
    }

    nonisolated private static func extractHuggingFaceModelId(from path: String) -> String {
        if path.hasPrefix("id(\"") {
            if let closingQuote = path.range(of: "\",") {
                let start = path.index(path.startIndex, offsetBy: 4)
                let idSubstring = path[start..<closingQuote.lowerBound]
                return PocketCloudMLX.ModelConfiguration.normalizeHubId(String(idSubstring))
            }
        }

        if path.contains("models--") && path.contains("--") {
            let components = path.split(separator: "/")
            if let firstComponent = components.first,
               firstComponent.hasPrefix("models--") && firstComponent.contains("--") {

                // Remove "models--" prefix and convert "--" to "/"
                let withoutPrefix = firstComponent.dropFirst("models--".count)
                let modelId = withoutPrefix.replacingOccurrences(of: "--", with: "/")

                return PocketCloudMLX.ModelConfiguration.normalizeHubId(modelId)
            }
        }

        // If not a filesystem path format, return as-is
        return PocketCloudMLX.ModelConfiguration.normalizeHubId(path)
    }

    /// Check if a model is supported by the MLX framework
    private func isModelSupportedByMLX(_ model: HuggingFaceModel) async -> Bool {
        let normalizedId = PocketCloudMLX.ModelConfiguration.normalizeHubId(model.id)
        let registryModels = ModelRegistry.allModels

        if registryModels.contains(where: { $0.hubId.caseInsensitiveCompare(normalizedId) == .orderedSame }) {
            downloadLogger.info("✅ MLXEngine registry match: \(normalizedId)")
            return true
        }

        if registryModels.contains(where: { $0.hubId.caseInsensitiveCompare(model.id) == .orderedSame }) {
            downloadLogger.info("✅ MLXEngine registry match (raw id): \(model.id)")
            return true
        }

        if let shortId = normalizedId.split(separator: "/").last?.lowercased(),
           registryModels.contains(where: { $0.hubId.lowercased().contains(shortId) }) {
            downloadLogger.info("✅ MLXEngine heuristic match: \(normalizedId) ~ \(shortId)")
            return true
        }

        #if canImport(MLXLLM)
        let mlxRegistryIds = Set(MLXLLM.LLMRegistry.shared.models.map { String(describing: $0.id).lowercased() })
        let hfLower = normalizedId.lowercased()

        if mlxRegistryIds.contains(hfLower) {
            downloadLogger.info("✅ MLXLLM registry match: \(normalizedId)")
            return true
        }

        if mlxRegistryIds.contains(where: { hfLower.contains($0) || $0.contains(hfLower) }) {
            downloadLogger.info("✅ MLXLLM heuristic match: \(normalizedId)")
            return true
        }

        downloadLogger.warning("❌ Model \(model.id) not found in MLX registries. Sample supported IDs: \(Array(mlxRegistryIds.prefix(5)))")
        return false
        #else
        downloadLogger.warning("⚠️ MLXLLM not available, allowing download of \(model.id) for development purposes")
        return true
        #endif
    }
}
