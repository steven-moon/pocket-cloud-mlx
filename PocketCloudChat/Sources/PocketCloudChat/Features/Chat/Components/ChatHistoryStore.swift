// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/ChatHistoryStore.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ChatHistoryEntry: Identifiable, Codable
//   - actor ChatHistoryStore {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==

import Foundation
@preconcurrency import PocketCloudMLX
import PocketCloudLogger

/// Represents a saved conversation that can be resumed later.
struct ChatHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var modelHubId: String?
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        modelHubId: String?,
        messages: [ChatMessage]
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelHubId = modelHubId
        self.messages = messages
    }

    static func makeTitle(from messages: [ChatMessage]) -> String {
        guard let firstUserMessage = messages.first(where: { $0.role == .user }) else {
            return "Conversation"
        }

        let trimmed = firstUserMessage.content
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Conversation"
        }

        let maxLength = 60
        if trimmed.count <= maxLength {
            return trimmed
        }

        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "..."
    }
}

extension ChatHistoryEntry: @unchecked Sendable {}

/// Persists chat history entries to disk and provides access helpers.
actor ChatHistoryStore {
    static let shared = ChatHistoryStore()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let historyURL: URL
    private var entries: [ChatHistoryEntry] = []

    private init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        historyURL = ChatHistoryStore.makeHistoryURL()
        entries = ChatHistoryStore.loadExistingEntries(from: historyURL, using: decoder)
    }

    func allEntries() -> [ChatHistoryEntry] {
        entries.sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveConversation(
        id: UUID?,
        messages: [ChatMessage],
        modelHubId: String?
    ) async -> ChatHistoryEntry {
        let now = Date()
        let title = ChatHistoryEntry.makeTitle(from: messages)
        AppLogger.shared.info(
            "ChatHistory",
            "Persisting conversation with \(messages.count) messages (existing: \(id != nil ? "yes" : "no"))"
        )

        if let id, let index = entries.firstIndex(where: { $0.id == id }) {
            var updated = entries[index]
            updated.messages = messages
            updated.updatedAt = now
            updated.title = title
            updated.modelHubId = modelHubId
            entries[index] = updated
            resortEntries()
            persistEntries()
            return updated
        }

        let newEntry = ChatHistoryEntry(
            title: title,
            createdAt: now,
            updatedAt: now,
            modelHubId: modelHubId,
            messages: messages
        )
        entries.append(newEntry)
        resortEntries()
        persistEntries()
        return newEntry
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        persistEntries()
    }

    func clearAll() {
        entries.removeAll()
        persistEntries()
    }

    private func persistEntries() {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: historyURL, options: [.atomic])
        } catch {
            AppLogger.shared.error("ChatHistory", "Failed to persist history: \(error.localizedDescription)")
        }
    }

    private func resortEntries() {
        entries.sort { $0.updatedAt > $1.updatedAt }
    }

    private static func makeHistoryURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.mlxchatapp"
        let historyDirectory = baseDirectory
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("ChatHistory", isDirectory: true)

        do {
            try fileManager.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        } catch {
            AppLogger.shared.error("ChatHistory", "Failed to create history directory: \(error.localizedDescription)")
        }

        return historyDirectory.appendingPathComponent("history.json", isDirectory: false)
    }

    private static func loadExistingEntries(from url: URL, using decoder: JSONDecoder) -> [ChatHistoryEntry] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        do {
            return try decoder.decode([ChatHistoryEntry].self, from: data)
        } catch {
            AppLogger.shared.error("ChatHistory", "Failed to decode history: \(error.localizedDescription)")
            return []
        }
    }
}
