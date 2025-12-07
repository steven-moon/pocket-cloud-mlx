// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Download/DownloadProgressNotifier.swift
// Purpose       : Posts download and verification progress notifications
//
// Key Types in this file:
//   - struct DownloadProgressNotifier
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//
// == End LLM Context Header ==

import Foundation

/// Posts download and verification progress notifications
public struct DownloadProgressNotifier: DownloadProgressNotification, Sendable {
    
    public init() {}
    
    // MARK: - DownloadProgressNotification Protocol
    
    public func postVerificationProgress(_ hubId: String, event: String, info: [String: Any]) {
        var payload: [String: Any] = [
            "hubId": hubId,
            "event": event
        ]
        for (k, v) in info {
            payload[k] = v
        }
        NotificationCenter.default.post(
            name: .mlxModelVerificationProgress,
            object: nil,
            userInfo: payload
        )
    }
    
    public func postDownloadProgress(_ hubId: String, event: String, info: [String: Any]) {
        var payload: [String: Any] = [
            "hubId": hubId,
            "event": event
        ]
        for (key, value) in info {
            payload[key] = value
        }
        NotificationCenter.default.post(
            name: .mlxModelDownloadProgress,
            object: nil,
            userInfo: payload
        )
    }
}
