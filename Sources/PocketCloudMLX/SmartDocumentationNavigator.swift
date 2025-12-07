// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/SmartDocumentationNavigator.swift
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

/// Smart navigation system that provides guided learning paths through documentation
/// 
/// This creates adaptive documentation experiences that:
/// - Suggest next logical steps based on current reading
/// - Track user progress through documentation
/// - Provide personalized learning paths
/// - Surface related content contextually
///
/// **Documentation**: `Documentation/User/Features/smart-navigation.md`
public final class SmartDocumentationNavigator: @unchecked Sendable {
    
    // MARK: - Types
    
    public struct LearningPath: Identifiable, Hashable {
        public let id: String
        public let title: String
        public let description: String
        public let steps: [LearningStep]
        public let difficulty: Difficulty
        public let estimatedTime: TimeInterval
        
        public enum Difficulty: String, CaseIterable {
            case beginner = "beginner"
            case intermediate = "intermediate"
            case advanced = "advanced"
            
            public var displayName: String {
                switch self {
                case .beginner: return "Beginner"
                case .intermediate: return "Intermediate"
                case .advanced: return "Advanced"
                }
            }
            
            public var icon: String {
                switch self {
                case .beginner: return "1.circle.fill"
                case .intermediate: return "2.circle.fill"
                case .advanced: return "3.circle.fill"
                }
            }
        }
    }
    
    public struct LearningStep: Identifiable, Hashable {
        public let id: String
        public let title: String
        public let documentId: String
        public let description: String
        public let actionRequired: Bool
        public let prerequisites: [String]
        public let estimatedTime: TimeInterval
        
        public init(id: String, title: String, documentId: String, description: String, actionRequired: Bool = false, prerequisites: [String] = [], estimatedTime: TimeInterval = 300) {
            self.id = id
            self.title = title
            self.documentId = documentId
            self.description = description
            self.actionRequired = actionRequired
            self.prerequisites = prerequisites
            self.estimatedTime = estimatedTime
        }
    }
    
    public struct UserProgress: Codable {
        public var visitedDocuments: Set<String>
        public var completedSteps: Set<String>
        public var currentPath: String?
        public var sessionStartTime: Date
        public var totalReadingTime: TimeInterval
        
        public init() {
            self.visitedDocuments = []
            self.completedSteps = []
            self.currentPath = nil
            self.sessionStartTime = Date()
            self.totalReadingTime = 0
        }
    }
    
    public struct NavigationSuggestion: Identifiable {
        public let id = UUID()
        public let title: String
        public let reason: String
        public let documentId: String
        public let priority: Priority
        public let actionType: ActionType
        
        public enum Priority: Int, CaseIterable {
            case low = 1
            case medium = 2
            case high = 3
            case critical = 4
            
            public var displayName: String {
                switch self {
                case .low: return "Optional"
                case .medium: return "Recommended"
                case .high: return "Important"
                case .critical: return "Essential"
                }
            }
        }
        
        public enum ActionType: String, CaseIterable {
            case read = "read"
            case practice = "practice"
            case test = "test"
            case explore = "explore"
            
            public var icon: String {
                switch self {
                case .read: return "book.fill"
                case .practice: return "play.circle.fill"
                case .test: return "checkmark.circle.fill"
                case .explore: return "magnifyingglass.circle.fill"
                }
            }
        }
    }
    
    // MARK: - Properties
    
    private var userProgress: UserProgress
    private let learningPaths: [LearningPath]
    private let helpSystem: HelpSystem?
    
    // MARK: - Initialization
    
    public init(helpSystem: HelpSystem? = nil) {
        self.helpSystem = helpSystem
        self.userProgress = UserProgress()
        self.learningPaths = Self.createLearningPaths()
        
        // Load saved progress if available
        loadUserProgress()
    }
    
    // MARK: - Public Interface
    
    /// Record that user visited a document
    public func recordDocumentVisit(_ documentId: String, readingTime: TimeInterval = 0) {
        userProgress.visitedDocuments.insert(documentId)
        userProgress.totalReadingTime += readingTime
        saveUserProgress()
    }
    
    /// Record that user completed a learning step
    public func recordStepCompletion(_ stepId: String) {
        userProgress.completedSteps.insert(stepId)
        saveUserProgress()
    }
    
    /// Get suggested next steps based on current progress
    public func getNavigationSuggestions(currentDocumentId: String? = nil) -> [NavigationSuggestion] {
        var suggestions: [NavigationSuggestion] = []
        
        // Suggest next steps in current learning path
        if let currentPath = userProgress.currentPath,
           let path = learningPaths.first(where: { $0.id == currentPath }) {
            suggestions.append(contentsOf: getPathSuggestions(path: path))
        }
        
        // Suggest related content based on current document
        if let documentId = currentDocumentId {
            suggestions.append(contentsOf: getRelatedContentSuggestions(documentId: documentId))
        }
        
        // Suggest learning paths if none started
        if userProgress.currentPath == nil {
            suggestions.append(contentsOf: getLearningPathSuggestions())
        }
        
        // Sort by priority and return top suggestions
        return Array(suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }.prefix(5))
    }
    
    /// Get recommended learning path for user
    public func getRecommendedLearningPath() -> LearningPath? {
        // If user is new, suggest beginner path
        if userProgress.visitedDocuments.isEmpty {
            return learningPaths.first { $0.difficulty == .beginner }
        }
        
        // If user has some experience, suggest intermediate
        if userProgress.visitedDocuments.count < 5 {
            return learningPaths.first { $0.difficulty == .intermediate }
        }
        
        // For experienced users, suggest advanced
        return learningPaths.first { $0.difficulty == .advanced }
    }
    
    /// Start a specific learning path
    public func startLearningPath(_ pathId: String) {
        userProgress.currentPath = pathId
        saveUserProgress()
    }
    
    /// Get progress for current learning path
    public func getCurrentPathProgress() -> (completed: Int, total: Int)? {
        guard let currentPath = userProgress.currentPath,
              let path = learningPaths.first(where: { $0.id == currentPath }) else {
            return nil
        }
        
        let completedSteps = path.steps.filter { userProgress.completedSteps.contains($0.id) }
        return (completed: completedSteps.count, total: path.steps.count)
    }
    
    /// Get personalized dashboard data
    public func getDashboardData() -> DashboardData {
        let totalDocuments = getAllDocumentIds().count
        let visitedCount = userProgress.visitedDocuments.count
        let progressPercentage = totalDocuments > 0 ? Double(visitedCount) / Double(totalDocuments) : 0
        
        return DashboardData(
            progressPercentage: progressPercentage,
            documentsRead: visitedCount,
            totalDocuments: totalDocuments,
            readingTime: userProgress.totalReadingTime,
            currentPath: userProgress.currentPath,
            suggestions: getNavigationSuggestions(),
            achievements: getAchievements()
        )
    }
    
    // MARK: - Private Implementation
    
    private func getPathSuggestions(path: LearningPath) -> [NavigationSuggestion] {
        var suggestions: [NavigationSuggestion] = []
        
        // Find next uncompleted step
        for step in path.steps {
            if !userProgress.completedSteps.contains(step.id) {
                // Check if prerequisites are met
                let prerequisitesMet = step.prerequisites.allSatisfy { 
                    userProgress.completedSteps.contains($0) 
                }
                
                if prerequisitesMet {
                    suggestions.append(NavigationSuggestion(
                        title: step.title,
                        reason: "Next step in your learning path",
                        documentId: step.documentId,
                        priority: .high,
                        actionType: step.actionRequired ? .practice : .read
                    ))
                    break // Only suggest the immediate next step
                }
            }
        }
        
        return suggestions
    }
    
    private func getRelatedContentSuggestions(documentId: String) -> [NavigationSuggestion] {
        var suggestions: [NavigationSuggestion] = []
        
        // Simple related content logic based on document categories
        let relatedDocs = getRelatedDocuments(documentId: documentId)
        
        for relatedDoc in relatedDocs.prefix(2) {
            if !userProgress.visitedDocuments.contains(relatedDoc.id) {
                suggestions.append(NavigationSuggestion(
                    title: relatedDoc.title,
                    reason: "Related to what you're currently reading",
                    documentId: relatedDoc.id,
                    priority: .medium,
                    actionType: .explore
                ))
            }
        }
        
        return suggestions
    }
    
    private func getLearningPathSuggestions() -> [NavigationSuggestion] {
        var suggestions: [NavigationSuggestion] = []
        
        if let recommendedPath = getRecommendedLearningPath() {
            suggestions.append(NavigationSuggestion(
                title: "Start \(recommendedPath.title)",
                reason: "Recommended learning path for your level",
                documentId: recommendedPath.steps.first?.documentId ?? "",
                priority: .critical,
                actionType: .read
            ))
        }
        
        return suggestions
    }
    
    private func getRelatedDocuments(documentId: String) -> [RelatedDocument] {
        // This would be enhanced with actual document relationship data
        return [
            RelatedDocument(id: "settings", title: "Settings & Configuration"),
            RelatedDocument(id: "privacy", title: "Privacy Features"),
            RelatedDocument(id: "performance", title: "Performance Tips")
        ]
    }
    
    private func getAllDocumentIds() -> [String] {
        // This would come from the actual documentation system
        return ["welcome", "chat", "settings", "privacy", "performance", "models", "troubleshooting"]
    }
    
    private func getAchievements() -> [Achievement] {
        var achievements: [Achievement] = []
        
        // Reading achievements
        if userProgress.visitedDocuments.count >= 3 {
            achievements.append(Achievement(
                id: "reader",
                title: "Documentation Explorer",
                description: "Read 3 or more documentation pages",
                icon: "book.fill"
            ))
        }
        
        // Time achievements
        if userProgress.totalReadingTime >= 900 { // 15 minutes
            achievements.append(Achievement(
                id: "studious",
                title: "Studious Learner",
                description: "Spent 15+ minutes reading documentation",
                icon: "clock.fill"
            ))
        }
        
        // Path completion achievements
        if let currentPath = userProgress.currentPath,
           let path = learningPaths.first(where: { $0.id == currentPath }) {
            let completedSteps = path.steps.filter { userProgress.completedSteps.contains($0.id) }
            if completedSteps.count == path.steps.count {
                achievements.append(Achievement(
                    id: "pathComplete",
                    title: "Path Completed",
                    description: "Completed \(path.title) learning path",
                    icon: "checkmark.circle.fill"
                ))
            }
        }
        
        return achievements
    }
    
    private func loadUserProgress() {
        // Load from UserDefaults or file system
        if let data = UserDefaults.standard.data(forKey: "documentationProgress"),
           let progress = try? JSONDecoder().decode(UserProgress.self, from: data) {
            self.userProgress = progress
        }
    }
    
    private func saveUserProgress() {
        if let data = try? JSONEncoder().encode(userProgress) {
            UserDefaults.standard.set(data, forKey: "documentationProgress")
        }
    }
    
    // MARK: - Static Learning Paths
    
    private static func createLearningPaths() -> [LearningPath] {
        return [
            // Beginner Path
            LearningPath(
                id: "beginner",
                title: "Getting Started with MLX Chat",
                description: "Perfect for new users - learn the basics step by step",
                steps: [
                    LearningStep(
                        id: "welcome",
                        title: "Welcome & Overview",
                        documentId: "welcome",
                        description: "Learn what MLX Chat is and its key benefits"
                    ),
                    LearningStep(
                        id: "firstChat",
                        title: "Your First Conversation",
                        documentId: "chat",
                        description: "Start chatting with AI and learn the interface",
                        actionRequired: true,
                        prerequisites: ["welcome"]
                    ),
                    LearningStep(
                        id: "privacy",
                        title: "Privacy & Security",
                        documentId: "privacy",
                        description: "Understand how your data stays private",
                        prerequisites: ["firstChat"]
                    )
                ],
                difficulty: .beginner,
                estimatedTime: 900 // 15 minutes
            ),
            
            // Intermediate Path
            LearningPath(
                id: "intermediate",
                title: "Mastering MLX Chat Features",
                description: "Explore advanced features and customization options",
                steps: [
                    LearningStep(
                        id: "models",
                        title: "Understanding AI Models",
                        documentId: "models",
                        description: "Learn about different models and their capabilities"
                    ),
                    LearningStep(
                        id: "settings",
                        title: "Customize Your Experience",
                        documentId: "settings",
                        description: "Configure settings for optimal performance",
                        actionRequired: true,
                        prerequisites: ["models"]
                    ),
                    LearningStep(
                        id: "performance",
                        title: "Optimize Performance",
                        documentId: "performance",
                        description: "Tips for best performance on your device",
                        prerequisites: ["settings"]
                    )
                ],
                difficulty: .intermediate,
                estimatedTime: 1200 // 20 minutes
            ),
            
            // Advanced Path
            LearningPath(
                id: "advanced",
                title: "Power User Guide",
                description: "Advanced techniques and troubleshooting",
                steps: [
                    LearningStep(
                        id: "troubleshooting",
                        title: "Troubleshooting Guide",
                        documentId: "troubleshooting",
                        description: "Solve common issues and optimize further"
                    ),
                    LearningStep(
                        id: "integration",
                        title: "System Integration",
                        documentId: "integration",
                        description: "Integrate with other apps and workflows",
                        actionRequired: true,
                        prerequisites: ["troubleshooting"]
                    )
                ],
                difficulty: .advanced,
                estimatedTime: 1800 // 30 minutes
            )
        ]
    }
}

// MARK: - Supporting Types

public struct DashboardData {
    public let progressPercentage: Double
    public let documentsRead: Int
    public let totalDocuments: Int
    public let readingTime: TimeInterval
    public let currentPath: String?
    public let suggestions: [SmartDocumentationNavigator.NavigationSuggestion]
    public let achievements: [Achievement]
}

public struct Achievement: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
}

private struct RelatedDocument {
    let id: String
    let title: String
} 