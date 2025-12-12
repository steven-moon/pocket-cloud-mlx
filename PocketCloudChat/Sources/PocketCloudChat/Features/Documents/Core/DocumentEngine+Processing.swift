import Foundation
import PocketCloudUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension DocumentEngine {
    func processFile(_ url: URL) async throws -> DocumentFile {
        let didStartScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let sourceAttributes = try fileManager.attributesOfItem(atPath: url.path)
        let sourceSize = sourceAttributes[.size] as? Int64 ?? 0

        guard sourceSize <= maxFileSize else {
            throw DocumentError.fileTooLarge(size: sourceSize, maxSize: maxFileSize)
        }

        let fileExtension = url.pathExtension.lowercased()
        let documentID = UUID()
        let persistedURL = try persistFile(from: url, documentID: documentID, fileExtension: fileExtension)
        let persistedAttributes = try fileManager.attributesOfItem(atPath: persistedURL.path)
        let fileSizeValue = persistedAttributes[FileAttributeKey.size] as? NSNumber
        let fileSize = fileSizeValue?.int64Value ?? sourceSize
        let fileName = url.lastPathComponent
        let category = determineCategory(for: fileExtension)
        let preview = try await extractPreview(from: persistedURL, category: category)

        return DocumentFile(
            id: documentID,
            name: fileName,
            type: fileExtension,
            category: category,
            sizeBytes: fileSize,
            dateAdded: Date(),
            storedPath: persistedURL.path,
            preview: preview
        )
    }

    private func determineCategory(for fileExtension: String) -> DocumentCategory {
        if supportedImageExtensions.contains(fileExtension) {
            return .images
        } else if supportedDocumentExtensions.contains(fileExtension) {
            return .documents
        } else if supportedMediaExtensions.contains(fileExtension) {
            return .media
        } else {
            return .documents
        }
    }

    private func extractPreview(from url: URL, category: DocumentCategory) async throws -> DocumentPreview? {
        switch category {
        case .images:
            return try await extractImagePreview(from: url)
        case .documents:
            return try await extractDocumentPreview(from: url)
        case .media:
            return try await extractMediaPreview(from: url)
        case .all:
            return nil
        }
    }

    private func extractImagePreview(from url: URL) async throws -> DocumentPreview? {
        #if os(iOS)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let data = image.jpegData(compressionQuality: 0.3)
        return DocumentPreview(type: .image, data: data, text: nil)
        #elseif os(macOS)
        guard let image = NSImage(contentsOfFile: url.path) else { return nil }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.3])
        return DocumentPreview(type: .image, data: data, text: nil)
        #else
        return DocumentPreview(type: .image, data: nil, text: "Image: \(url.lastPathComponent)")
        #endif
    }

    private func extractDocumentPreview(from url: URL) async throws -> DocumentPreview? {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "txt", "md":
            let content = try String(contentsOf: url, encoding: .utf8)
            return DocumentPreview(type: .text, data: nil, text: String(content.prefix(500)))
        case "pdf":
            return try await extractPDFPreview(from: url)
        case "rtf":
            return try await extractRTFPreview(from: url)
        default:
            return DocumentPreview(type: .text, data: nil, text: "Document: \(url.lastPathComponent)")
        }
    }

    private func extractPDFPreview(from url: URL) async throws -> DocumentPreview? {
        #if os(iOS) || os(macOS)
        return DocumentPreview(type: .text, data: nil, text: "PDF Document: \(url.lastPathComponent)")
        #else
        return DocumentPreview(type: .text, data: nil, text: "PDF: \(url.lastPathComponent)")
        #endif
    }

    private func extractRTFPreview(from url: URL) async throws -> DocumentPreview? {
        let data = try Data(contentsOf: url)
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            return DocumentPreview(type: .text, data: nil, text: String(attributedString.string.prefix(500)))
        }
        return DocumentPreview(type: .text, data: nil, text: "RTF Document: \(url.lastPathComponent)")
    }

    private func extractMediaPreview(from url: URL) async throws -> DocumentPreview? {
        DocumentPreview(type: .text, data: nil, text: "Media: \(url.lastPathComponent)")
    }
}
