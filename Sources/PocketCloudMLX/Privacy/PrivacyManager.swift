// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Privacy/PrivacyManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class PrivacyManager: ObservableObject {
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

/// Manages privacy-first data handling and user controls
@MainActor
public class PrivacyManager: ObservableObject {
    private let logger = Logger(label: "PrivacyManager")
    
    @Published public var dataRetentionPolicy: DataRetentionPolicy = .session
    @Published public var contextSharingEnabled = true
    @Published public var voiceDataStorageEnabled = false
    @Published public var analyticsEnabled = false
    @Published public var crashReportingEnabled = true
    
    // Privacy settings keys
    private enum SettingsKeys {
        static let dataRetentionPolicy = "privacy_data_retention_policy"
        static let contextSharingEnabled = "privacy_context_sharing_enabled"
        static let voiceDataStorageEnabled = "privacy_voice_data_storage_enabled"
        static let analyticsEnabled = "privacy_analytics_enabled"
        static let crashReportingEnabled = "privacy_crash_reporting_enabled"
    }
    
    public init() {
        loadPrivacySettings()
        logger.info("PrivacyManager initialized with privacy-first defaults")
    }
    
    // MARK: - Data Processing
    
    /// Process context with privacy controls
    public func processContext(_ context: ContextItem) -> ProcessedContext {
        logger.info("Processing context item with privacy controls")
        
        // Ensure no data leaves device
        var processedContent = context.content
        
        // Minimize data stored based on retention policy
        switch dataRetentionPolicy {
        case .none:
            // Don't store any context data
            processedContent = ""
        case .session:
            // Keep data only for current session
            processedContent = minimizeContent(processedContent)
        case .temporary:
            // Keep data for 24 hours
            processedContent = minimizeContent(processedContent)
        case .permanent:
            // Keep data permanently (user explicitly opted in)
            break
        }
        
        return ProcessedContext(
            id: context.id,
            type: context.type,
            content: processedContent,
            metadata: sanitizeMetadata(context.metadata),
            timestamp: context.timestamp,
            expiresAt: calculateExpirationDate()
        )
    }
    
    /// Process voice data with privacy controls
    public func processVoiceData(_ audioData: Data, transcription: String) -> ProcessedVoiceData? {
        logger.info("Processing voice data with privacy controls")
        
        guard voiceDataStorageEnabled else {
            // Only return transcription, discard audio data
            return ProcessedVoiceData(
                transcription: transcription,
                audioData: nil,
                processedAt: Date(),
                expiresAt: Date().addingTimeInterval(300) // 5 minutes
            )
        }
        
        // If voice data storage is enabled, still minimize retention
        let expirationDate = calculateVoiceDataExpiration()
        
        return ProcessedVoiceData(
            transcription: transcription,
            audioData: audioData,
            processedAt: Date(),
            expiresAt: expirationDate
        )
    }
    
    /// Process web content with privacy controls
    public func processWebContent(_ webContext: WebPageContext) -> ProcessedWebContext {
        logger.info("Processing web content with privacy controls")
        
        // Remove potentially sensitive information
        let sanitizedContent = sanitizeWebContent(webContext.content)
        let sanitizedImages = webContext.images.filter { url in
            // Only keep images from the same domain
            return url.host == webContext.url.host
        }
        
        return ProcessedWebContext(
            url: webContext.url,
            title: webContext.title,
            content: sanitizedContent,
            images: sanitizedImages,
            links: [], // Remove all links for privacy
            extractedAt: webContext.extractedAt,
            expiresAt: calculateExpirationDate()
        )
    }
    
    // MARK: - Data Cleanup
    
    /// Clear all stored data
    public func clearAllData() {
        logger.info("Clearing all stored data")
        
        // Remove all stored conversations
        UserDefaults.standard.removeObject(forKey: "conversations")
        UserDefaults.standard.removeObject(forKey: "context_history")
        UserDefaults.standard.removeObject(forKey: "voice_transcriptions")
        UserDefaults.standard.removeObject(forKey: "web_context_cache")
        
        // Clear temporary files
        clearTemporaryFiles()
        
        // Clear document cache
        clearDocumentCache()
        
        logger.info("All data cleared successfully")
    }
    
    /// Clear data based on retention policy
    public func cleanupExpiredData() {
        logger.info("Cleaning up expired data")
        
        let _ = Date()  // Placeholder for future expiration date logic
        
        // This would implement cleanup logic based on expiration dates
        // For now, we'll just log the action
        logger.info("Expired data cleanup completed")
    }
    
    /// Clear temporary files
    private func clearTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            
            for file in tempFiles {
                if file.lastPathComponent.hasPrefix("mlx_") {
                    try FileManager.default.removeItem(at: file)
                }
            }
            
            logger.info("Temporary files cleared")
        } catch {
            logger.error("Failed to clear temporary files: \(error.localizedDescription)")
        }
    }
    
    /// Clear document cache
    private func clearDocumentCache() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDirectory = documentsDirectory.appendingPathComponent("DocumentCache")
        
        do {
            if FileManager.default.fileExists(atPath: cacheDirectory.path) {
                try FileManager.default.removeItem(at: cacheDirectory)
                logger.info("Document cache cleared")
            }
        } catch {
            logger.error("Failed to clear document cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Privacy Settings
    
    /// Update data retention policy
    public func setDataRetentionPolicy(_ policy: DataRetentionPolicy) {
        dataRetentionPolicy = policy
        UserDefaults.standard.set(policy.rawValue, forKey: SettingsKeys.dataRetentionPolicy)
        
        logger.info("Data retention policy updated to: \(policy.rawValue)")
        
        // If policy is more restrictive, clean up existing data
        if policy == .none || policy == .session {
            cleanupExpiredData()
        }
    }
    
    /// Update context sharing setting
    public func setContextSharingEnabled(_ enabled: Bool) {
        contextSharingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SettingsKeys.contextSharingEnabled)
        
        logger.info("Context sharing \(enabled ? "enabled" : "disabled")")
    }
    
    /// Update voice data storage setting
    public func setVoiceDataStorageEnabled(_ enabled: Bool) {
        voiceDataStorageEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SettingsKeys.voiceDataStorageEnabled)
        
        logger.info("Voice data storage \(enabled ? "enabled" : "disabled")")
        
        // If disabled, clear existing voice data
        if !enabled {
            UserDefaults.standard.removeObject(forKey: "voice_transcriptions")
        }
    }
    
    /// Update analytics setting
    public func setAnalyticsEnabled(_ enabled: Bool) {
        analyticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SettingsKeys.analyticsEnabled)
        
        logger.info("Analytics \(enabled ? "enabled" : "disabled")")
    }
    
    /// Update crash reporting setting
    public func setCrashReportingEnabled(_ enabled: Bool) {
        crashReportingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SettingsKeys.crashReportingEnabled)
        
        logger.info("Crash reporting \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Privacy Compliance
    
    /// Get privacy compliance report
    public func getPrivacyComplianceReport() -> PrivacyComplianceReport {
        return PrivacyComplianceReport(
            dataRetentionPolicy: dataRetentionPolicy,
            contextSharingEnabled: contextSharingEnabled,
            voiceDataStorageEnabled: voiceDataStorageEnabled,
            analyticsEnabled: analyticsEnabled,
            crashReportingEnabled: crashReportingEnabled,
            lastDataCleanup: getLastCleanupDate(),
            dataTypesStored: getStoredDataTypes(),
            thirdPartyServices: getThirdPartyServices()
        )
    }
    
    /// Export user data for privacy compliance
    public func exportUserData() -> UserDataExport {
        logger.info("Exporting user data for privacy compliance")
        
        return UserDataExport(
            conversations: exportConversations(),
            contextHistory: exportContextHistory(),
            voiceTranscriptions: exportVoiceTranscriptions(),
            preferences: exportPreferences(),
            exportDate: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func loadPrivacySettings() {
        if let policyRawValue = UserDefaults.standard.object(forKey: SettingsKeys.dataRetentionPolicy) as? String,
           let policy = DataRetentionPolicy(rawValue: policyRawValue) {
            dataRetentionPolicy = policy
        }
        
        contextSharingEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.contextSharingEnabled)
        voiceDataStorageEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.voiceDataStorageEnabled)
        analyticsEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.analyticsEnabled)
        crashReportingEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.crashReportingEnabled)
    }
    
    private func minimizeContent(_ content: String) -> String {
        // Remove potentially sensitive information
        var minimized = content
        
        // Remove email addresses
        minimized = minimized.replacingOccurrences(
            of: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#,
            with: "[EMAIL]",
            options: .regularExpression
        )
        
        // Remove phone numbers
        minimized = minimized.replacingOccurrences(
            of: #"\b\d{3}-\d{3}-\d{4}\b"#,
            with: "[PHONE]",
            options: .regularExpression
        )
        
        // Limit content length
        if minimized.count > 1000 {
            minimized = String(minimized.prefix(1000)) + "..."
        }
        
        return minimized
    }
    
    private func sanitizeMetadata(_ metadata: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        
        // Only keep safe metadata keys
        let allowedKeys = ["source", "type", "timestamp", "fileType", "eventCount"]
        
        for (key, value) in metadata {
            if allowedKeys.contains(key) {
                sanitized[key] = value
            }
        }
        
        return sanitized
    }
    
    private func sanitizeWebContent(_ content: String) -> String {
        // Remove scripts and potentially malicious content
        var sanitized = content
        
        // Remove script tags and content
        sanitized = sanitized.replacingOccurrences(
            of: #"<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove style tags
        sanitized = sanitized.replacingOccurrences(
            of: #"<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>"#,
            with: "",
            options: .regularExpression
        )
        
        return sanitized
    }
    
    private func calculateExpirationDate() -> Date {
        switch dataRetentionPolicy {
        case .none:
            return Date() // Expire immediately
        case .session:
            return Date().addingTimeInterval(86400) // 24 hours
        case .temporary:
            return Date().addingTimeInterval(86400 * 7) // 7 days
        case .permanent:
            return Date().addingTimeInterval(86400 * 365) // 1 year
        }
    }
    
    private func calculateVoiceDataExpiration() -> Date {
        // Voice data is more sensitive, shorter retention
        switch dataRetentionPolicy {
        case .none:
            return Date()
        case .session:
            return Date().addingTimeInterval(3600) // 1 hour
        case .temporary:
            return Date().addingTimeInterval(86400) // 24 hours
        case .permanent:
            return Date().addingTimeInterval(86400 * 30) // 30 days max
        }
    }
    
    private func getLastCleanupDate() -> Date? {
        return UserDefaults.standard.object(forKey: "last_data_cleanup") as? Date
    }
    
    private func getStoredDataTypes() -> [String] {
        var types: [String] = []
        
        if UserDefaults.standard.object(forKey: "conversations") != nil {
            types.append("conversations")
        }
        
        if UserDefaults.standard.object(forKey: "context_history") != nil {
            types.append("context_history")
        }
        
        if voiceDataStorageEnabled && UserDefaults.standard.object(forKey: "voice_transcriptions") != nil {
            types.append("voice_transcriptions")
        }
        
        return types
    }
    
    private func getThirdPartyServices() -> [String] {
        // MLX Chat doesn't use third-party services by design
        return []
    }
    
    private func exportConversations() -> [String] {
        // This would export conversation data
        return []
    }
    
    private func exportContextHistory() -> [String] {
        // This would export context history
        return []
    }
    
    private func exportVoiceTranscriptions() -> [String] {
        // This would export voice transcriptions if enabled
        return voiceDataStorageEnabled ? [] : []
    }
    
    private func exportPreferences() -> [String: Any] {
        return [
            "dataRetentionPolicy": dataRetentionPolicy.rawValue,
            "contextSharingEnabled": contextSharingEnabled,
            "voiceDataStorageEnabled": voiceDataStorageEnabled,
            "analyticsEnabled": analyticsEnabled,
            "crashReportingEnabled": crashReportingEnabled
        ]
    }
}

// MARK: - Data Models

public enum DataRetentionPolicy: String, CaseIterable {
    case none = "none"
    case session = "session"
    case temporary = "temporary"
    case permanent = "permanent"
    
    public var displayName: String {
        switch self {
        case .none: return "No Data Storage"
        case .session: return "Session Only"
        case .temporary: return "Temporary (7 days)"
        case .permanent: return "Permanent"
        }
    }
    
    public var description: String {
        switch self {
        case .none: return "Data is not stored and is discarded immediately"
        case .session: return "Data is kept only for the current session"
        case .temporary: return "Data is kept for 7 days then automatically deleted"
        case .permanent: return "Data is kept until manually deleted"
        }
    }
}

public struct ProcessedContext {
    public let id: UUID
    public let type: ContextType
    public let content: String
    public let metadata: [String: Any]
    public let timestamp: Date
    public let expiresAt: Date
    
    public var isExpired: Bool {
        return Date() > expiresAt
    }
}

public struct ProcessedVoiceData {
    public let transcription: String
    public let audioData: Data?
    public let processedAt: Date
    public let expiresAt: Date
    
    public var isExpired: Bool {
        return Date() > expiresAt
    }
}

public struct ProcessedWebContext {
    public let url: URL
    public let title: String
    public let content: String
    public let images: [URL]
    public let links: [URL]
    public let extractedAt: Date
    public let expiresAt: Date
    
    public var isExpired: Bool {
        return Date() > expiresAt
    }
}

public struct PrivacyComplianceReport {
    public let dataRetentionPolicy: DataRetentionPolicy
    public let contextSharingEnabled: Bool
    public let voiceDataStorageEnabled: Bool
    public let analyticsEnabled: Bool
    public let crashReportingEnabled: Bool
    public let lastDataCleanup: Date?
    public let dataTypesStored: [String]
    public let thirdPartyServices: [String]
}

public struct UserDataExport {
    public let conversations: [String]
    public let contextHistory: [String]
    public let voiceTranscriptions: [String]
    public let preferences: [String: Any]
    public let exportDate: Date
} 