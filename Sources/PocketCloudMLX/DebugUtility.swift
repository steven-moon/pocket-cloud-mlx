// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/DebugUtility.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - extension DateFormatter {
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
#if canImport(Metal)
import Metal
#endif

// Using Logging module types directly

/// Utility for generating debug reports and managing logging
@MainActor
public final class DebugUtility {
    public static let shared = DebugUtility()
    private init() {}
    
    /// Generate a comprehensive debug report
    public func generateDebugReport() async -> String {
        let logs = Logger.recentLogs(limit: 100)
        let userLogs = Logger.recentUserLogs(limit: 50)
        
        let header = "=== PocketCloudMLX DEBUG REPORT ===\n"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let headerInfo = "Generated: \(timestamp)\n"
        
        let aiLogsSection = "--- AI Agent Logs ---\n" + logs.map { entry in
            let ts = ISO8601DateFormatter().string(from: entry.timestamp)
            let file = entry.file.components(separatedBy: "/").last ?? entry.file
            return "\(ts) [\(entry.level)] [\(file):\(entry.function):\(entry.line)] \(entry.message)"
        }.joined(separator: "\n")
        
        let userLogsSection = "\n--- User Logs ---\n" + userLogs.map { entry in
            let ts = ISO8601DateFormatter().string(from: entry.timestamp)
            return "\(ts) [\(entry.level)] \(entry.message)"
        }.joined(separator: "\n")
        
        let footer = "\n=== END DEBUG REPORT ==="
        
        return header + headerInfo + aiLogsSection + userLogsSection + footer
    }
    
    /// Get the paths to log files
    public func getLogFilePaths() -> [String] {
        var paths: [String] = []
        
        if let aiLogPath = Logger.getLogFileURL()?.path {
            paths.append("AI Logs: \(aiLogPath)")
        }
        
        if let userLogPath = Logger.getUserLogFileURL()?.path {
            paths.append("User Logs: \(userLogPath)")
        }
        
        return paths
    }
    
    /// Clear all logs
    public func clearAllLogs() {
        Logger.clearLogs()
    }
    
    /// Get recent logs for debugging
    public func getRecentLogs(limit: Int = 50) -> [LogEntry] {
        return Logger.recentLogs(limit: limit)
    }
    
    /// Get recent user logs for debugging
    public func getRecentUserLogs(limit: Int = 50) -> [LogEntry] {
        return Logger.recentUserLogs(limit: limit)
    }
}

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
} 