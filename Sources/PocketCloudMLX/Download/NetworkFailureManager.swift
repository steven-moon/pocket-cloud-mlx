// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/NetworkFailureManager.swift
// Purpose       : Manages network failures, retry logic, and exponential backoff
//
// Key Types in this file:
//   - actor NetworkFailureManager
//   - struct NetworkFailureState
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation
import PocketCloudLogger

/// Manages network failure tracking and retry logic with exponential backoff
public actor NetworkFailureManager: NetworkFailureHandling {
    private let logger = Logger(label: "NetworkFailureManager")
    
    private struct NetworkFailureState {
        var consecutiveFailures: Int
        var nextRetry: Date
        var lastErrorDescription: String
        var lastNotice: Date?
    }
    
    private var networkFailures: [String: NetworkFailureState] = [:]
    private var pendingRepairTasks: [String: Task<Void, Never>] = [:]
    private let maxNetworkBackoff: TimeInterval = 15 * 60 // 15 minutes max
    
    public init() {}
    
    // MARK: - NetworkFailureHandling Protocol
    
    public func recordSuccess(for hubId: String) {
        if let task = pendingRepairTasks.removeValue(forKey: hubId) {
            task.cancel()
        }
        
        if networkFailures.removeValue(forKey: hubId) != nil {
            logger.info("✅ Network recovered for \(hubId)")
        }
    }
    
    public func recordFailure(for hubId: String, context: String, error: Error) {
        guard isNetworkError(error) else {
            logger.debug("⏭️ Error is not network-related, skipping backoff for \(hubId)")
            return
        }
        
        let now = Date()
        let previous = networkFailures[hubId]
        let consecutive = min((previous?.consecutiveFailures ?? 0) + 1, 6)
        let baseDelay: TimeInterval = 20 // seconds
        let delay = min(pow(2.0, Double(consecutive - 1)) * baseDelay, maxNetworkBackoff)
        
        let state = NetworkFailureState(
            consecutiveFailures: consecutive,
            nextRetry: now.addingTimeInterval(delay),
            lastErrorDescription: error.localizedDescription,
            lastNotice: nil
        )
        networkFailures[hubId] = state
        
        logger.warning("🌐 Network failure during \(context) for \(hubId); retry after \(Int(delay))s (attempt #\(consecutive))")
    }
    
    public func isNetworkReady(for hubId: String, context: String) -> Bool {
        guard var state = networkFailures[hubId] else { return true }
        
        let now = Date()
        if now >= state.nextRetry {
            networkFailures.removeValue(forKey: hubId)
            logger.info("✅ Network backoff expired for \(hubId) — ready to retry")
            return true
        }
        
        let remaining = max(1, Int(state.nextRetry.timeIntervalSince(now)))
        if state.lastNotice == nil || now.timeIntervalSince(state.lastNotice ?? .distantPast) > 15 {
            logger.info("⏸️ Network backoff active for \(hubId) in \(context); retry in ~\(remaining)s")
            state.lastNotice = now
            networkFailures[hubId] = state
        } else {
            logger.debug("⏸️ Suppressing repeated notice for \(hubId)")
        }
        
        return false
    }
    
    public func pendingBackoff(for hubId: String) -> Int? {
        guard let state = networkFailures[hubId] else { return nil }
        let remaining = Int(state.nextRetry.timeIntervalSinceNow.rounded())
        return remaining > 0 ? remaining : nil
    }
    
    public func isNetworkError(_ error: Error) -> Bool {
        // Check for OptimizedDownloadError
        if let downloadError = error as? OptimizedDownloadError {
            if case .networkUnavailable = downloadError {
                return true
            }
        }
        
        // Check for URLError
        if error is URLError {
            return true
        }
        
        // Check NSError domain
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }
        
        // Check error description
        let description = nsError.localizedDescription.lowercased()
        if description.contains("network") || description.contains("internet") ||
           description.contains("offline") || description.contains("timed out") ||
           description.contains("connection") {
            return true
        }
        
        // Final fallback check
        let fallback = String(describing: error).lowercased()
        return fallback.contains("network") || fallback.contains("internet") ||
               fallback.contains("offline") || fallback.contains("timed out") ||
               fallback.contains("connection")
    }
    
    // MARK: - Deferred Repair Scheduling
    
    public func scheduleDeferredRepair(
        for hubId: String,
        repairAction: @escaping @Sendable () async -> Void
    ) {
        guard pendingRepairTasks[hubId] == nil,
              let state = networkFailures[hubId] else { return }
        
        let delay = max(0, state.nextRetry.timeIntervalSinceNow)
        logger.info("🗓️ Scheduling deferred repair for \(hubId) in ~\(Int(delay.rounded()))s")
        
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            guard let self = self else { return }
            await self.executeDeferredRepair(for: hubId, action: repairAction)
        }
        
        pendingRepairTasks[hubId] = task
    }
    
    private func executeDeferredRepair(
        for hubId: String,
        action: @Sendable () async -> Void
    ) async {
        pendingRepairTasks[hubId] = nil
        
        if let wait = pendingBackoff(for: hubId) {
            logger.warning("⏸️ Deferred repair for \(hubId) still in backoff (~\(wait)s)")
            return
        }
        
        logger.info("🛠️ Executing deferred repair for \(hubId)")
        await action()
    }
}
