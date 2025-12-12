// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Documents/Core/DocumentEngine.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class DocumentEngine: ObservableObject
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// == End LLM Context Header ==

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine
import os.log
import PocketCloudUI
import PocketCloudLogger

#if os(iOS)
import UIKit
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

/// Core document engine coordinating document ingestion, persistence, and metadata.
@MainActor
public class DocumentEngine: ObservableObject {
    // MARK: - Logging
    let logger = Logger(subsystem: "com.mlxchatapp", category: "DocumentEngine")
    let aiLogger = AIDevLogger.Logger(label: "MLXChatApp.DocumentEngine")

    // MARK: - Published Properties
    @Published public var selectedFiles: [DocumentFile] = []
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    @Published public var selectedCategory: DocumentCategory = .all
    @Published public var dragHover: Bool = false
    @Published public var supportedTypes: [UTType] = []
    @Published public var allowsMultipleSelection: Bool = true
    @Published public var documentLibrary: [DocumentFile] = []
    @Published public var searchText: String = ""
    @Published public var sortOrder: DocumentSortOrder = .dateAdded

    // MARK: - Core Dependencies
    var cancellables = Set<AnyCancellable>()
    let fileManager = FileManager.default
    let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
    let supportedImageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
    let supportedDocumentExtensions = ["pdf", "txt", "rtf", "html", "md", "docx", "doc", "pages"]
    let supportedMediaExtensions = ["mp4", "mov", "avi", "mp3", "wav", "m4a"]

    // MARK: - Persistence Identifiers
    let appGroupIdentifier = "group.clevercoding.mlx-shared"
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.mlxchatapp"
    let persistedDocumentsFolderName = "PersistedDocuments"
    let libraryFileName = "DocumentLibrary.json"

    // MARK: - Codable Helpers
    let jsonEncoder: JSONEncoder
    let jsonDecoder: JSONDecoder

    // MARK: - File System Paths
    lazy var storageRootURL: URL = resolveStorageRootURL()
    var documentsDirectoryURL: URL {
        storageRootURL.appendingPathComponent(persistedDocumentsFolderName, isDirectory: true)
    }
    var libraryFileURL: URL {
        storageRootURL.appendingPathComponent(libraryFileName, isDirectory: false)
    }

    // MARK: - Initialization
    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        jsonEncoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        jsonDecoder = decoder

        setupSupportedTypes()
        setupFileSystemMonitoring()
        prepareStorageDirectories()
        Task { [weak self] in
            await self?.loadDocumentLibrary()
        }
    }

    // MARK: - Public Interface
    public func setCategory(_ category: DocumentCategory) {
        selectedCategory = category
        updateSupportedTypes()
    }

    public func setMultipleSelection(_ allowed: Bool) {
        allowsMultipleSelection = allowed
    }

    public func addFiles(_ urls: [URL]) async {
        aiLogger.debug("addFiles called with \(urls.count) URL(s)")
        isProcessing = true
        defer { isProcessing = false }

        var processed: [DocumentFile] = []
        for url in urls {
            do {
                let file = try await processFile(url)
                processed.append(file)
                logger.info("Successfully processed file: \(url.lastPathComponent)")
                aiLogger.debug("Processed file: \(url.lastPathComponent)")
            } catch {
                logger.error("Failed to process file \(url.lastPathComponent): \(error.localizedDescription)")
                await setError("Failed to process \(url.lastPathComponent): \(error.localizedDescription)")
                aiLogger.error("Processing failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if allowsMultipleSelection {
            selectedFiles.append(contentsOf: processed)
        } else if let first = processed.first {
            selectedFiles = [first]
        }

        documentLibrary.append(contentsOf: processed)
        await saveDocumentLibrary()
        aiLogger.debug("addFiles completed; selectedFiles=\(selectedFiles.count), library=\(documentLibrary.count)")
    }

    public func removeFile(_ file: DocumentFile) {
        selectedFiles.removeAll { $0.id == file.id }
    }

    public func deleteDocument(_ document: DocumentFile) async {
        documentLibrary.removeAll { $0.id == document.id }
        selectedFiles.removeAll { $0.id == document.id }
        deletePersistedFile(for: document)
        await saveDocumentLibrary()
    }

    public func clearSelection() {
        selectedFiles.removeAll()
    }

    public var filteredDocuments: [DocumentFile] {
        var filtered = documentLibrary

        if selectedCategory != .all {
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter { document in
                document.name.localizedCaseInsensitiveContains(searchText) ||
                document.type.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOrder {
        case .name:
            filtered.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateAdded:
            filtered.sort { $0.dateAdded > $1.dateAdded }
        case .size:
            filtered.sort { $0.sizeBytes > $1.sizeBytes }
        case .type:
            filtered.sort { $0.type.localizedCaseInsensitiveCompare($1.type) == .orderedAscending }
        }

        return filtered
    }

    public var documentStatistics: AIDevSwiftUIKit.DocumentStatistics {
        let allDocs = documentLibrary
        return AIDevSwiftUIKit.DocumentStatistics(
            totalCount: allDocs.count,
            imageCount: allDocs.filter { $0.category == .images }.count,
            documentCount: allDocs.filter { $0.category == .documents }.count,
            mediaCount: allDocs.filter { $0.category == .media }.count,
            totalSize: allDocs.reduce(0) { $0 + $1.sizeBytes }
        )
    }

    public func exportSelectedFiles() async -> [URL] {
        selectedFiles.compactMap { $0.url }
    }

    public func importFromDeviceSource(_ source: DeviceImportSource) async -> [URL] {
        aiLogger.debug("Import requested from source: \(String(describing: source))")
        isProcessing = true
        defer { isProcessing = false }

        let result: [URL]
        switch source {
        case .photoLibrary:
            result = await importFromPhotoLibrary()
        case .files:
            result = await importFromFilesApp()
        case .camera:
            result = await importFromCamera()
        case .scanner:
            result = await importFromDocumentScanner()
        case .cloud:
            result = await importFromCloudStorage()
        }

        aiLogger.debug("Import finished for source \(String(describing: source)) with \(result.count) URL(s)")
        return result
    }

    public func clearError() {
        errorMessage = nil
    }

    // MARK: - Internal Utilities
    func setupSupportedTypes() {
        updateSupportedTypes()
    }

    func updateSupportedTypes() {
        supportedTypes = selectedCategory.supportedTypes
    }

    func setupFileSystemMonitoring() {
        // Placeholder for optional file monitoring hooks.
    }

    func setError(_ message: String) async {
        await MainActor.run { [weak self] in
            self?.errorMessage = message
        }
    }
}
