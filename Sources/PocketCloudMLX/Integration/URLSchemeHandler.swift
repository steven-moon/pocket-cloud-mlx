// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Integration/URLSchemeHandler.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class URLSchemeHandler: ObservableObject {
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

/// Handles URL scheme integration for external app communication
@MainActor
public class URLSchemeHandler: ObservableObject {
    private let logger = Logger(label: "URLSchemeHandler")
    
    @Published public var lastReceivedURL: URL?
    @Published public var pendingContextData: String?
    
    private let contextManager: ContextManager
    private let privacyManager: PrivacyManager
    
    public init(contextManager: ContextManager, privacyManager: PrivacyManager) {
        self.contextManager = contextManager
        self.privacyManager = privacyManager
        logger.info("URLSchemeHandler initialized")
    }
    
    // MARK: - URL Scheme Handling
    
    /// Handle incoming URL from external apps
    public func handleURL(_ url: URL) -> Bool {
        logger.info("Handling URL: \(url.absoluteString)")
        
        guard url.scheme == "mlxchat" else {
            logger.warning("Unsupported URL scheme: \(url.scheme ?? "nil")")
            return false
        }
        
        lastReceivedURL = url
        
        switch url.host {
        case "context":
            return handleContextURL(url)
        case "chat":
            return handleChatURL(url)
        case "document":
            return handleDocumentURL(url)
        case "voice":
            return handleVoiceURL(url)
        default:
            logger.warning("Unsupported URL host: \(url.host ?? "nil")")
            return false
        }
    }
    
    // MARK: - Context URL Handling
    
    /// Handle context sharing from external apps
    private func handleContextURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            logger.error("Invalid context URL format")
            return false
        }
        
        var contextData: [String: String] = [:]
        
        for item in queryItems {
            if let value = item.value {
                contextData[item.name] = value
            }
        }
        
        guard let data = contextData["data"] else {
            logger.error("Missing context data in URL")
            return false
        }
        
        return processExternalContextData(data, source: contextData["source"] ?? "external")
    }
    
    /// Process context data from external sources
    private func processExternalContextData(_ data: String, source: String) -> Bool {
        do {
            // Decode URL-encoded data
            guard let decodedData = data.removingPercentEncoding else {
                logger.error("Failed to decode context data")
                return false
            }
            
            // Parse JSON if it's JSON data
            if let jsonData = decodedData.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                return processJSONContext(json, source: source)
            } else {
                // Handle as plain text
                return processTextContext(decodedData, source: source)
            }
            
        } catch {
            logger.error("Failed to process context data: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Process JSON context data
    private func processJSONContext(_ json: [String: Any], source: String) -> Bool {
        guard privacyManager.contextSharingEnabled else {
            logger.warning("Context sharing is disabled")
            return false
        }
        
        var contextType: ContextType = .system
        var content = ""
        var metadata: [String: Any] = ["source": source]
        
        // Handle different JSON structures
        if let title = json["title"] as? String,
           let url = json["url"] as? String,
           let pageContent = json["content"] as? String {
            
            // Webpage context
            contextType = .webpage
            content = "Webpage: \(title)\n\(pageContent)"
            metadata["title"] = title
            metadata["url"] = url
            
        } else if let fileName = json["fileName"] as? String,
                  let fileContent = json["content"] as? String {
            
            // Document context
            contextType = .document
            content = "Document: \(fileName)\n\(fileContent)"
            metadata["fileName"] = fileName
            
        } else {
            // Generic context
            content = json.description
        }
        
        let contextItem = ContextItem(
            type: contextType,
            content: content,
            metadata: metadata
        )
        
        // Process through privacy manager
        let processedContext = privacyManager.processContext(contextItem)
        
        // Add to context manager
        let finalContextItem = ContextItem(
            type: processedContext.type,
            content: processedContext.content,
            metadata: processedContext.metadata,
            timestamp: processedContext.timestamp
        )
        
        contextManager.addContextItem(finalContextItem)
        
        logger.info("Added external context from \(source)")
        return true
    }
    
    /// Process plain text context
    private func processTextContext(_ text: String, source: String) -> Bool {
        guard privacyManager.contextSharingEnabled else {
            logger.warning("Context sharing is disabled")
            return false
        }
        
        let contextItem = ContextItem(
            type: .system,
            content: text,
            metadata: ["source": source]
        )
        
        // Process through privacy manager
        let processedContext = privacyManager.processContext(contextItem)
        
        // Add to context manager
        let finalContextItem = ContextItem(
            type: processedContext.type,
            content: processedContext.content,
            metadata: processedContext.metadata,
            timestamp: processedContext.timestamp
        )
        
        contextManager.addContextItem(finalContextItem)
        pendingContextData = processedContext.content
        
        logger.info("Added text context from \(source)")
        return true
    }
    
    // MARK: - Chat URL Handling
    
    /// Handle direct chat requests
    private func handleChatURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            logger.error("Invalid chat URL format")
            return false
        }
        
        var message: String?
        var _: String?
        
        for item in queryItems {
            switch item.name {
            case "message":
                message = item.value?.removingPercentEncoding
            case "model":
                _ = item.value
            default:
                break
            }
        }
        
        guard let chatMessage = message else {
            logger.error("Missing message in chat URL")
            return false
        }
        
        // Store the message for the chat interface to pick up
        pendingContextData = chatMessage
        
        logger.info("Received chat message from external app")
        return true
    }
    
    // MARK: - Document URL Handling
    
    /// Handle document sharing
    private func handleDocumentURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            logger.error("Invalid document URL format")
            return false
        }
        
        var documentPath: String?
        var _: String?
        
        for item in queryItems {
            switch item.name {
            case "path":
                documentPath = item.value?.removingPercentEncoding
            case "type":
                _ = item.value
            default:
                break
            }
        }
        
        guard let path = documentPath,
              let documentURL = URL(string: path) else {
            logger.error("Invalid document path in URL")
            return false
        }
        
        // Process the document
        Task {
            if let documentContext = await contextManager.extractDocumentContext(from: documentURL) {
                let contextItem = ContextItem(
                    type: .document,
                    content: "Document: \(documentContext.fileName)\n\(documentContext.extractedText)",
                    metadata: [
                        "source": "external_document",
                        "fileName": documentContext.fileName,
                        "fileType": documentContext.fileType.rawValue
                    ]
                )
                
                contextManager.addContextItem(contextItem)
                logger.info("Added document context from external app")
            }
        }
        
        return true
    }
    
    // MARK: - Voice URL Handling
    
    /// Handle voice commands from external apps
    private func handleVoiceURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            logger.error("Invalid voice URL format")
            return false
        }
        
        var command: String?
        var text: String?
        
        for item in queryItems {
            switch item.name {
            case "command":
                command = item.value
            case "text":
                text = item.value?.removingPercentEncoding
            default:
                break
            }
        }
        
        guard let voiceCommand = command else {
            logger.error("Missing voice command in URL")
            return false
        }
        
        switch voiceCommand {
        case "speak":
            if let textToSpeak = text {
                // This would trigger speech synthesis
                pendingContextData = "speak:\(textToSpeak)"
                logger.info("Received speak command from external app")
                return true
            }
        case "listen":
            // This would trigger speech recognition
            pendingContextData = "listen"
            logger.info("Received listen command from external app")
            return true
        default:
            logger.warning("Unsupported voice command: \(voiceCommand)")
            return false
        }
        
        return false
    }
    
    // MARK: - URL Generation
    
    /// Generate URL for sharing context with other apps
    public func generateContextURL(contextItem: ContextItem) -> URL? {
        guard privacyManager.contextSharingEnabled else {
            logger.warning("Context sharing is disabled")
            return nil
        }
        
        var components = URLComponents()
        components.scheme = "mlxchat"
        components.host = "context"
        
        // Create JSON representation
        let contextData: [String: Any] = [
            "type": contextItem.type.rawValue,
            "content": contextItem.content,
            "timestamp": contextItem.timestamp.timeIntervalSince1970,
            "metadata": contextItem.metadata
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: contextData)
            let jsonString = String(data: jsonData, encoding: .utf8)
            
            components.queryItems = [
                URLQueryItem(name: "data", value: jsonString),
                URLQueryItem(name: "source", value: "mlxchat")
            ]
            
            return components.url
        } catch {
            logger.error("Failed to generate context URL: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Generate URL for opening MLX Chat with a specific message
    public func generateChatURL(message: String, model: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "mlxchat"
        components.host = "chat"
        
        var queryItems = [URLQueryItem(name: "message", value: message)]
        
        if let model = model {
            queryItems.append(URLQueryItem(name: "model", value: model))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    /// Generate URL for sharing a document
    public func generateDocumentURL(documentPath: String, documentType: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mlxchat"
        components.host = "document"
        
        components.queryItems = [
            URLQueryItem(name: "path", value: documentPath),
            URLQueryItem(name: "type", value: documentType)
        ]
        
        return components.url
    }
    
    // MARK: - Utility Methods
    
    /// Clear pending context data
    public func clearPendingData() {
        pendingContextData = nil
        lastReceivedURL = nil
    }
    
    /// Check if URL scheme is registered
    public func isURLSchemeRegistered() -> Bool {
        // This would check if the mlxchat:// scheme is properly registered
        // For now, we'll assume it is
        return true
    }
    
    /// Get supported URL schemes
    public func getSupportedSchemes() -> [String] {
        return ["mlxchat"]
    }
    
    /// Get supported URL actions
    public func getSupportedActions() -> [String] {
        return ["context", "chat", "document", "voice"]
    }
}

// MARK: - URL Scheme Extensions

public extension ContextType {
    var rawValue: String {
        switch self {
        case .webpage: return "webpage"
        case .document: return "document"
        case .calendar: return "calendar"
        case .contact: return "contact"
        case .system: return "system"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "webpage": self = .webpage
        case "document": self = .document
        case "calendar": self = .calendar
        case "contact": self = .contact
        case "system": self = .system
        default: return nil
        }
    }
} 