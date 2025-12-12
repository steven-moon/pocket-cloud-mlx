import Foundation
import AIDevLogger

func parseDownloadEventData(info: [String: Any]) -> ModelDiscoveryManager.DownloadEventData? {
    guard let hubId = info["hubId"] as? String,
          let event = info["event"] as? String else { return nil }

    func intValue(_ key: String) -> Int? {
        if let v = info[key] as? Int { return v }
        if let n = info[key] as? NSNumber { return n.intValue }
        return nil
    }

    func int64Value(_ key: String) -> Int64? {
        if let v = info[key] as? Int64 { return v }
        if let n = info[key] as? NSNumber { return n.int64Value }
        return nil
    }

    func doubleValue(_ key: String) -> Double? {
        if let v = info[key] as? Double { return v }
        if let n = info[key] as? NSNumber { return n.doubleValue }
        return nil
    }

    return ModelDiscoveryManager.DownloadEventData(
        hubId: hubId,
        event: event,
        index: intValue("index"),
        total: intValue("total"),
        totalFiles: intValue("totalFiles"),
        fileName: info["file"] as? String,
        downloadedBytes: int64Value("downloadedBytes"),
        totalBytes: int64Value("totalBytes"),
        fileProgress: doubleValue("fileProgress"),
        overallProgress: doubleValue("overallProgress"),
        overallDownloadedBytes: int64Value("overallDownloadedBytes"),
        overallTotalBytes: int64Value("overallTotalBytes"),
        fileSize: int64Value("fileSize")
    )
}

@MainActor
extension ModelDiscoveryManager {

    func processDownloadEvent(_ data: DownloadEventData) {
        let hubId = data.hubId

        func updateOverallProgress(using overallFallback: Double? = nil) {
            let downloaded = downloadedBytesByModel[hubId] ?? 0
            let total = totalBytesByModel[hubId] ?? 0
            if total > 0 && downloaded >= 0 {
                let pct = min(max(Double(downloaded) / Double(total), 0), 1)
                downloadProgress[hubId] = pct
                logProgressIfNeeded(for: hubId, progress: pct)
            } else if let overall = overallFallback {
                let clamped = min(max(overall, 0), 1)
                downloadProgress[hubId] = clamped
                logProgressIfNeeded(for: hubId, progress: clamped)
            }
        }

        switch data.event {
        case "start":
            completedFileCount[hubId] = 0
            if let total = data.totalFiles {
                totalFileCount[hubId] = max(total, 0)
            } else {
                totalFileCount.removeValue(forKey: hubId)
            }
            activeDownloadFiles.removeValue(forKey: hubId)
            completedBytesAccumulated[hubId] = 0
            if let total = data.overallTotalBytes, total > 0 {
                totalBytesByModel[hubId] = total
            } else {
                totalBytesByModel.removeValue(forKey: hubId)
            }
            if let downloaded = data.overallDownloadedBytes {
                downloadedBytesByModel[hubId] = downloaded
            } else {
                downloadedBytesByModel[hubId] = 0
            }

        case "total_bytes":
            if let overall = data.overallTotalBytes, overall > 0 {
                totalBytesByModel[hubId] = max(totalBytesByModel[hubId] ?? 0, overall)
            } else if let total = data.totalBytes, total > 0 {
                totalBytesByModel[hubId] = max(totalBytesByModel[hubId] ?? 0, total)
            }
            if let downloaded = data.overallDownloadedBytes {
                downloadedBytesByModel[hubId] = downloaded
            } else if let downloaded = data.downloadedBytes {
                let overallBytes = (completedBytesAccumulated[hubId] ?? 0) + downloaded
                downloadedBytesByModel[hubId] = overallBytes
            }
            updateOverallProgress(using: data.overallProgress)
            downloadLogger.debug(
                "total_bytes event",
                context: Logger.Context([
                    "hubId": hubId,
                    "downloadedBytes": String(downloadedBytesByModel[hubId] ?? 0),
                    "knownTotalBytes": String(totalBytesByModel[hubId] ?? 0)
                ])
            )

        case "file_start":
            let index = max(data.index ?? 1, 1)
            let total = data.total ?? totalFileCount[hubId] ?? index
            let name = data.fileName ?? "File \(index)"
            let downloaded = data.downloadedBytes
            let totalBytes = data.totalBytes
            let progress = data.fileProgress
            let candidateTotal = max(total, index)
            let previousTotal = totalFileCount[hubId] ?? 0
            totalFileCount[hubId] = max(candidateTotal, previousTotal)
            activeDownloadFiles[hubId] = ActiveDownloadFile(
                name: name,
                index: index,
                total: total,
                downloadedBytes: downloaded,
                totalBytes: totalBytes,
                progress: progress
            )
            var bytesSoFar = downloadedBytesByModel[hubId] ?? 0
            if let overallBytes = data.overallDownloadedBytes {
                bytesSoFar = overallBytes
                downloadedBytesByModel[hubId] = overallBytes
            } else if let downloaded = data.downloadedBytes {
                let overallBytes = (completedBytesAccumulated[hubId] ?? 0) + downloaded
                bytesSoFar = overallBytes
                downloadedBytesByModel[hubId] = overallBytes
            }
            if let modelBytes = data.overallTotalBytes, modelBytes > 0 {
                totalBytesByModel[hubId] = max(totalBytesByModel[hubId] ?? 0, modelBytes)
            }
            updateOverallProgress(using: data.overallProgress)
            downloadLogger.debug(
                "file_start event",
                context: Logger.Context([
                    "hubId": hubId,
                    "file": name,
                    "fileIndex": String(index),
                    "bytesDownloaded": String(bytesSoFar),
                    "knownTotalBytes": String(totalBytesByModel[hubId] ?? 0)
                ])
            )

        case "file_progress":
            let index = max(data.index ?? activeDownloadFiles[hubId]?.index ?? 1, 1)
            let total = data.total ?? totalFileCount[hubId] ?? index
            let name = data.fileName ?? activeDownloadFiles[hubId]?.name ?? "File \(index)"
            let downloaded = data.downloadedBytes ?? activeDownloadFiles[hubId]?.downloadedBytes
            let totalBytes = data.totalBytes ?? activeDownloadFiles[hubId]?.totalBytes
            let progress = data.fileProgress ?? activeDownloadFiles[hubId]?.progress
            let candidateTotal = max(total, index)
            let previousTotal = totalFileCount[hubId] ?? 0
            totalFileCount[hubId] = max(candidateTotal, previousTotal)
            activeDownloadFiles[hubId] = ActiveDownloadFile(
                name: name,
                index: index,
                total: total,
                downloadedBytes: downloaded,
                totalBytes: totalBytes,
                progress: progress
            )
            var bytesSoFar = downloadedBytesByModel[hubId] ?? 0
            if let overallBytes = data.overallDownloadedBytes {
                bytesSoFar = overallBytes
                downloadedBytesByModel[hubId] = overallBytes
            } else if let downloaded = data.downloadedBytes {
                let overallBytes = (completedBytesAccumulated[hubId] ?? 0) + downloaded
                bytesSoFar = overallBytes
                downloadedBytesByModel[hubId] = overallBytes
            }
            if let modelBytes = data.overallTotalBytes, modelBytes > 0 {
                totalBytesByModel[hubId] = max(totalBytesByModel[hubId] ?? 0, modelBytes)
            }
            updateOverallProgress(using: data.overallProgress)
            downloadLogger.debug(
                "file_progress event",
                context: Logger.Context([
                    "hubId": hubId,
                    "file": name,
                    "fileIndex": String(index),
                    "bytesDownloaded": String(bytesSoFar),
                    "knownTotalBytes": String(totalBytesByModel[hubId] ?? 0)
                ])
            )

        case "file_complete":
            let index = max(data.index ?? (completedFileCount[hubId] ?? 0) + 1, 1)
            completedFileCount[hubId] = index
            let total = data.total ?? totalFileCount[hubId] ?? index
            let candidateTotal = max(total, index)
            let previousTotal = totalFileCount[hubId] ?? 0
            totalFileCount[hubId] = max(candidateTotal, previousTotal)
            if let modelBytes = data.overallTotalBytes, modelBytes > 0 {
                totalBytesByModel[hubId] = max(totalBytesByModel[hubId] ?? 0, modelBytes)
            }
            if let fileSize = data.fileSize {
                completedBytesAccumulated[hubId, default: 0] += fileSize
            }
            if let overall = data.overallDownloadedBytes {
                downloadedBytesByModel[hubId] = overall
            } else if data.fileSize != nil {
                downloadedBytesByModel[hubId] = completedBytesAccumulated[hubId]
            }
            updateOverallProgress(using: data.overallProgress)
            if let current = activeDownloadFiles[hubId] {
                activeDownloadFiles[hubId] = ActiveDownloadFile(
                    name: current.name,
                    index: current.index,
                    total: current.total,
                    downloadedBytes: current.downloadedBytes,
                    totalBytes: current.totalBytes,
                    progress: 1.0
                )
            }
            downloadLogger.debug(
                "file_complete event",
                context: Logger.Context([
                    "hubId": hubId,
                    "fileIndex": String(index),
                    "accumulatedBytes": String(downloadedBytesByModel[hubId] ?? 0),
                    "knownTotalBytes": String(totalBytesByModel[hubId] ?? 0)
                ])
            )

        case "file_error":
            activeDownloadFiles.removeValue(forKey: hubId)
            completedBytesAccumulated.removeValue(forKey: hubId)

        case "complete":
            if let total = data.total {
                totalFileCount[hubId] = total
                completedFileCount[hubId] = total
            }
            if let modelBytes = data.overallTotalBytes, modelBytes > 0 {
                totalBytesByModel[hubId] = max(totalBytesByModel[hubId] ?? 0, modelBytes)
            }
            if let overallBytes = data.overallDownloadedBytes {
                downloadedBytesByModel[hubId] = overallBytes
                if data.overallTotalBytes == nil {
                    totalBytesByModel[hubId] = max(totalBytesByModel[hubId] ?? 0, overallBytes)
                }
            } else if let total = data.totalBytes {
                downloadedBytesByModel[hubId] = total
            }
            updateOverallProgress(using: data.overallProgress)
            if downloadProgress[hubId] == nil { downloadProgress[hubId] = 1.0 }
            activeDownloadFiles.removeValue(forKey: hubId)
            completedBytesAccumulated.removeValue(forKey: hubId)
            downloadLogger.debug(
                "complete event",
                context: Logger.Context([
                    "hubId": hubId,
                    "downloadedBytes": String(downloadedBytesByModel[hubId] ?? 0),
                    "knownTotalBytes": String(totalBytesByModel[hubId] ?? 0)
                ])
            )

        default:
            break
        }
    }

    func logProgressIfNeeded(for hubId: String, progress: Double) {
        let lastValue = lastLoggedProgress[hubId] ?? -1
        let now = Date()
        let lastTime = lastProgressTimestamp[hubId] ?? .distantPast
        let delta = progress - lastValue
    if progress >= 0.999 || delta >= 0.01 || now.timeIntervalSince(lastTime) >= 10 {
            let percentage = Int((progress * 100).rounded())
            downloadLogger.debug("Progress: \(percentage)%", context: Logger.Context(["hubId": hubId]))
            lastLoggedProgress[hubId] = progress
            lastProgressTimestamp[hubId] = now
        }
    }
}
