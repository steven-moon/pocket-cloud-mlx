import Foundation

func makeVerificationEventData(info: [String: Any]) -> ModelDiscoveryManager.VerificationEventData? {
    guard let hubId = info["hubId"] as? String,
          let event = info["event"] as? String else { return nil }

    return ModelDiscoveryManager.VerificationEventData(
        hubId: hubId,
        event: event,
        source: info["source"] as? String,
        target: info["target"] as? String,
        file: info["file"] as? String,
        status: info["status"] as? String,
        message: info["message"] as? String,
        success: info["success"] as? Bool,
        elapsed: info["elapsed"] as? Double,
        fileCount: info["fileCount"] as? Int,
        index: info["index"] as? Int,
        total: info["total"] as? Int,
        missingCount: info["missingCount"] as? Int,
        corruptCount: info["corruptCount"] as? Int,
        srcBytes: info["srcBytes"] as? Int64,
        tgtBytes: info["tgtBytes"] as? Int64,
        mlxExists: info["mlxExists"] as? Bool,
        hfExists: info["hfExists"] as? Bool,
        mlxComplete: info["mlxComplete"] as? Bool,
        hfComplete: info["hfComplete"] as? Bool
    )
}

@MainActor
extension ModelDiscoveryManager {

    struct VerificationEventData: Sendable {
        let hubId: String
        let event: String
        let source: String?
        let target: String?
        let file: String?
        let status: String?
        let message: String?
        let success: Bool?
        let elapsed: Double?
        let fileCount: Int?
        let index: Int?
        let total: Int?
        let missingCount: Int?
        let corruptCount: Int?
        let srcBytes: Int64?
        let tgtBytes: Int64?
        let mlxExists: Bool?
        let hfExists: Bool?
        let mlxComplete: Bool?
        let hfComplete: Bool?
    }

    private func appendVerificationMessage(_ text: String, hubId: String) {
        var arr = verificationMessages[hubId] ?? []
        arr.append(text)
        if arr.count > 200 { arr.removeFirst(arr.count - 200) }
        verificationMessages[hubId] = arr
    }

    func processVerificationEvent(_ event: VerificationEventData) {
        if !verifyingModels.contains(event.hubId) {
            verifyingModels.insert(event.hubId)
        }

        func append(_ text: String) {
            appendVerificationMessage(text, hubId: event.hubId)
        }

        switch event.event {
        case "start":
            append("Verification started")
        case "directory_status":
            let mlx = event.mlxExists ?? false
            let hf = event.hfExists ?? false
            append("Dirs — MLX: \(mlx ? "OK" : "missing"), HF: \(hf ? "OK" : "missing")")
        case "directory_completeness":
            let mlxC = event.mlxComplete ?? false
            let hfC = event.hfComplete ?? false
            append("Completeness — MLX: \(mlxC), HF: \(hfC)")
        case "scan_start":
            append("Scanning files…")
            if let src = event.source {
                verifySourcePath[event.hubId] = src
                append("Source: \(src)")
            }
            if let tgt = event.target {
                verifyTargetPath[event.hubId] = tgt
                append("Target: \(tgt)")
            }
        case "scan_source":
            if let count = event.fileCount {
                append("Source files: \(count)")
            }
        case "scan_target":
            if let count = event.fileCount {
                append("Target files: \(count)")
            }
        case "scan_file_progress":
            if let idx = event.index, let total = event.total {
                verifyScanIndex[event.hubId] = idx
                verifyScanTotal[event.hubId] = total
            }
            if let file = event.file {
                append("Scanning \(verifyScanIndex[event.hubId] ?? 0)/\(verifyScanTotal[event.hubId] ?? 0): \(file)")
            }
        case "scan_result":
            if let missing = event.missingCount { verifyMissingCount[event.hubId] = missing }
            if let corrupt = event.corruptCount { verifyCorruptCount[event.hubId] = corrupt }
            if let srcBytes = event.srcBytes { verifySrcBytes[event.hubId] = srcBytes }
            if let tgtBytes = event.tgtBytes { verifyTgtBytes[event.hubId] = tgtBytes }
            append("Scan — missing: \(verifyMissingCount[event.hubId] ?? 0), corrupt: \(verifyCorruptCount[event.hubId] ?? 0)")
        case "missing_files":
            if let missing = event.missingCount { verifyMissingCount[event.hubId] = missing }
            verifyTotalToRepair[event.hubId] = verifyMissingCount[event.hubId]
            verifyRepairedCount[event.hubId] = 0
            verificationProgress[event.hubId] = 0
            append("Repairing missing files (\(verifyMissingCount[event.hubId] ?? 0))…")
        case "repair_progress":
            let idx = event.index ?? 0
            let total = event.total ?? 0
            verifyTotalToRepair[event.hubId] = total
            verifyRepairedCount[event.hubId] = idx
            if total > 0 {
                verificationProgress[event.hubId] = min(1.0, Double(idx) / Double(total))
            }
            if let file = event.file {
                append("Repaired \(idx)/\(total): \(file)")
            }
        case "repair_complete":
            let success = event.success ?? false
            append(success ? "Repair complete" : "Repair incomplete")
        case "redownload_complete":
            append("Redownload complete, re-verifying…")
        case "result":
            if let status = event.status { append("Result: \(status)") }
        case "finished":
            if let elapsed = event.elapsed { verifyElapsed[event.hubId] = elapsed }
            let succeeded = event.success ?? false
            append(succeeded ? "Verification succeeded (\(String(format: "%.1fs", verifyElapsed[event.hubId] ?? 0)))" : "Verification finished with issues")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                guard let self else { return }
                self.verifyingModels.remove(event.hubId)
                self.verificationProgress[event.hubId] = nil
            }
        default:
            if let message = event.message {
                append(message)
            }
        }
    }
}
