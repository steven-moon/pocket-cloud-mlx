// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HelpSystem.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:

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

/// Intelligent help system that provides contextual assistance based on app documentation
/// 
/// Integrates with the MLX Chat App to answer user questions about features, usage, and troubleshooting.
/// Uses the processed documentation from `Documentation/.build/` to provide accurate, contextual responses.
///
/// **Documentation**: `Documentation/Internal/Development-Status/feature-completion.md#intelligent-help-system`
public final class HelpSystem: @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// Configuration loaded from the help system build artifacts
    public struct Configuration: Codable {
        public let version: String
        public let enabled: Bool
        public let documentationPath: String
        public let indexPath: String
        public let processedDocsPath: String
        public let categories: [String: CategoryConfig]
        public let searchSettings: SearchSettings
        public let responseSettings: ResponseSettings
        
        public struct CategoryConfig: Codable {
            public let priority: Int
            public let description: String
            public let keywords: [String]
        }
        
        public struct SearchSettings: Codable {
            public let minRelevanceScore: Double
            public let maxResults: Int
            public let contextWindow: Int
            public let useSemanticSearch: Bool
        }
        
        public struct ResponseSettings: Codable {
            public let includeSourceReferences: Bool
            public let maxResponseLength: Int
            public let conversationalTone: Bool
            public let suggestRelatedTopics: Bool
        }
    }
    
    // MARK: - Types
    
    /// Represents a help response with context and suggestions
    public struct HelpResponse {
        public let answer: String
        public let sourceDocuments: [String]
        public let relatedTopics: [String]
        public let confidence: Double
        
        public init(answer: String, sourceDocuments: [String], relatedTopics: [String], confidence: Double) {
            self.answer = answer
            self.sourceDocuments = sourceDocuments
            self.relatedTopics = relatedTopics
            self.confidence = confidence
        }
    }
    
    /// Processed documentation content
    private struct ProcessedDocument: Codable {
        let title: String
        let category: String
        let sourceFile: String
        let wordCount: Int
        let processedDate: String
        let content: String
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let documentationIndex: [String: Any]
    private let processedDocuments: [ProcessedDocument]
    private let basePath: String
    public let isEnabled: Bool
    private static let logger = Logger(label: "HelpSystem")
    
    // MARK: - Initialization
    
    /// Initialize the help system with configuration from build artifacts
    /// - Parameter basePath: Base path to the MLX Engine directory (default: Bundle path detection)
    public init(basePath: String? = nil) throws {
        // Determine base path
        if let basePath = basePath {
            self.basePath = basePath
        } else {
            // Try to find the Documentation directory relative to the bundle
            let bundlePath = Bundle.main.bundleURL.path
            self.basePath = bundlePath
        }
        
        // Load configuration and gracefully disable when artifacts are missing
        let configPath = "\(self.basePath)/Documentation/.build/help-system-config.json"
        let disabledConfig = Self.makeDisabledConfiguration(basePath: self.basePath)
        let config: Configuration
        var isEnabled = false

        if let configData = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let configWrapper = try? JSONDecoder().decode([String: Configuration].self, from: configData),
           let decodedConfig = configWrapper["help_system"] {
            config = decodedConfig
            isEnabled = decodedConfig.enabled
        } else {
            config = disabledConfig
            Self.logger.notice("Help system configuration missing at \(configPath). Using disabled fallback configuration.")
            self.configuration = config
            self.documentationIndex = [:]
            self.processedDocuments = []
            self.isEnabled = false
            return
        }

        // Load documentation index
        let indexPath = "\(self.basePath)/Documentation/.build/index/documentation-index.json"
        let documentationIndex: [String: Any]
        if let indexData = try? Data(contentsOf: URL(fileURLWithPath: indexPath)),
           let index = try? JSONSerialization.jsonObject(with: indexData) as? [String: Any] {
            documentationIndex = index
        } else {
            Self.logger.notice("Help system documentation index missing at \(indexPath). Disabling help system.")
            self.configuration = config
            self.documentationIndex = [:]
            self.processedDocuments = []
            self.isEnabled = false
            return
        }

        // Load processed documents
        let processedPath = "\(self.basePath)/Documentation/.build/processed"
        let processedDocs: [ProcessedDocument]
        if let docs = try? Self.loadProcessedDocuments(from: processedPath) {
            processedDocs = docs
        } else {
            Self.logger.notice("Help system processed documents missing at \(processedPath). Disabling help system.")
            self.configuration = config
            self.documentationIndex = documentationIndex
            self.processedDocuments = []
            self.isEnabled = false
            return
        }

        self.configuration = config
        self.documentationIndex = documentationIndex
        self.processedDocuments = processedDocs
        self.isEnabled = isEnabled && !processedDocs.isEmpty
    }
    
    // MARK: - Public Interface
    
    /// Check if a user query is asking for help with the app
    /// - Parameter query: User's message
    /// - Returns: True if the query appears to be asking for help
    public func isHelpQuery(_ query: String) -> Bool {
        guard isEnabled else { return false }
        let helpKeywords = [
            "help", "how", "what", "why", "where", "when", "can you",
            "show me", "explain", "tell me", "guide", "tutorial", "support",
            "features", "capabilities", "settings", "options", "problem"
        ]
        
        let lowercasedQuery = query.lowercased()
        return helpKeywords.contains { keyword in
            lowercasedQuery.contains(keyword)
        }
    }
    
    /// Process a help query and generate a contextual response
    /// - Parameter query: User's help question
    /// - Returns: HelpResponse with answer and context
    public func processHelpQuery(_ query: String) async -> HelpResponse {
        guard isEnabled else {
            return HelpResponse(
                answer: "I couldn't load the in-app help content yet. Please refer to the documentation in the Docs tab for guidance.",
                sourceDocuments: [],
                relatedTopics: [],
                confidence: 0.0
            )
        }
        
        // Find relevant documents
        let relevantDocs = findRelevantDocuments(for: query)
        
        // Generate response based on relevant documentation
        let response = generateResponse(for: query, using: relevantDocs)
        
        return response
    }
    
    /// Get available help categories for user exploration
    /// - Returns: Dictionary of categories with descriptions
    public func getAvailableCategories() -> [String: String] {
        return configuration.categories.mapValues { $0.description }
    }
    
    /// Get help topics within a specific category
    /// - Parameter category: Category name (e.g., "Getting-Started")
    /// - Returns: Array of topic titles
    public func getTopicsInCategory(_ category: String) -> [String] {
        return processedDocuments
            .filter { $0.category == category }
            .map { $0.title }
    }
    
    // MARK: - Private Implementation
    
    private static func loadProcessedDocuments(from path: String) throws -> [ProcessedDocument] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            throw HelpSystemError.configurationNotFound("Processed documents directory not found: \(path)")
        }
        
        let files = try fileManager.contentsOfDirectory(atPath: path)
        var documents: [ProcessedDocument] = []
        
        for file in files where file.hasSuffix(".md") {
            let filePath = "\(path)/\(file)"
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let document = try JSONDecoder().decode(ProcessedDocument.self, from: data)
            documents.append(document)
        }
        
        return documents
    }
    
    private func findRelevantDocuments(for query: String) -> [ProcessedDocument] {
        let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var documentScores: [(ProcessedDocument, Double)] = []
        
        for document in processedDocuments {
            let score = calculateRelevanceScore(document: document, queryWords: queryWords)
            if score >= configuration.searchSettings.minRelevanceScore {
                documentScores.append((document, score))
            }
        }
        
        // Sort by relevance and return top results
        documentScores.sort { $0.1 > $1.1 }
        let maxResults = configuration.searchSettings.maxResults
        return Array(documentScores.prefix(maxResults).map { $0.0 })
    }
    
    private func calculateRelevanceScore(document: ProcessedDocument, queryWords: [String]) -> Double {
        let documentText = "\(document.title) \(document.content)".lowercased()
        
        // Check category keywords
        var score = 0.0
        if let categoryConfig = configuration.categories[document.category] {
            for keyword in categoryConfig.keywords {
                if queryWords.contains(keyword.lowercased()) {
                    score += 0.3
                }
            }
        }
        
        // Check direct word matches
        for word in queryWords {
            if documentText.contains(word) {
                score += 0.1
            }
        }
        
        // Boost score for title matches
        let titleWords = document.title.lowercased().components(separatedBy: .whitespacesAndNewlines)
        for word in queryWords {
            if titleWords.contains(word) {
                score += 0.2
            }
        }
        
        return min(score, 1.0) // Cap at 1.0
    }
    
    private func generateResponse(for query: String, using documents: [ProcessedDocument]) -> HelpResponse {
        if documents.isEmpty {
            return HelpResponse(
                answer: "I don't have specific information about that. You can explore the app's features by asking about 'getting started', 'features', or 'settings'.",
                sourceDocuments: [],
                relatedTopics: ["Getting Started", "Features Overview", "Common Questions"],
                confidence: 0.1
            )
        }
        
        // Generate contextual response based on the most relevant document
        let primaryDoc = documents[0]
        let answer = generateContextualAnswer(for: query, from: primaryDoc)
        
        // Extract source document names
        let sourceNames = documents.map { $0.title }
        
        // Suggest related topics
        let relatedTopics = suggestRelatedTopics(based: primaryDoc.category)
        
        // Calculate confidence based on relevance and number of matches
        let confidence = min(0.9, 0.3 + (Double(documents.count) * 0.1))
        
        return HelpResponse(
            answer: answer,
            sourceDocuments: sourceNames,
            relatedTopics: relatedTopics,
            confidence: confidence
        )
    }
    
    private func generateContextualAnswer(for query: String, from document: ProcessedDocument) -> String {
        // Extract relevant sections from the document content
        let content = document.content
        let maxLength = configuration.responseSettings.maxResponseLength
        
        // For now, provide a section of the content with context
        // In a more advanced implementation, this would use NLP to extract the most relevant parts
        
        var answer = "Based on the \(document.title) documentation:\n\n"
        
        // Extract a relevant portion of the content
        let contentLines = content.components(separatedBy: .newlines)
        let relevantLines = contentLines.prefix(10).joined(separator: "\n")
        
        let truncatedContent = String(relevantLines.prefix(maxLength - answer.count - 100))
        answer += truncatedContent
        
        if configuration.responseSettings.includeSourceReferences {
            answer += "\n\n📚 Source: \(document.title)"
        }
        
        return answer
    }
    
    private func suggestRelatedTopics(based category: String) -> [String] {
        // Get other documents in the same category or related categories
        var suggestions: [String] = []
        
        // Add topics from the same category
        let sameCategoryDocs = processedDocuments.filter { $0.category == category }
        suggestions.append(contentsOf: sameCategoryDocs.prefix(2).map { $0.title })
        
        // Add topics from high-priority categories
        let highPriorityCategories = configuration.categories
            .filter { $0.value.priority <= 3 }
            .keys
        
        for priorityCategory in highPriorityCategories where priorityCategory != category {
            let docs = processedDocuments.filter { $0.category == priorityCategory }
            if let firstDoc = docs.first {
                suggestions.append(firstDoc.title)
            }
        }
        
        return Array(Array(Set(suggestions)).prefix(3))
    }
}

// MARK: - Helpers

private extension HelpSystem {
    static func makeDisabledConfiguration(basePath: String) -> Configuration {
        Configuration(
            version: "0.0.0",
            enabled: false,
            documentationPath: "\(basePath)/Documentation",
            indexPath: "",
            processedDocsPath: "",
            categories: [:],
            searchSettings: .init(
                minRelevanceScore: 0.5,
                maxResults: 3,
                contextWindow: 5,
                useSemanticSearch: false
            ),
            responseSettings: .init(
                includeSourceReferences: false,
                maxResponseLength: 512,
                conversationalTone: true,
                suggestRelatedTopics: false
            )
        )
    }
}

// MARK: - Error Types

public enum HelpSystemError: Error, LocalizedError {
    case configurationNotFound(String)
    case invalidConfiguration(String)
    case documentProcessingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationNotFound(let message):
            return "Help system configuration not found: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid help system configuration: \(message)"
        case .documentProcessingError(let message):
            return "Document processing error: \(message)"
        }
    }
} 