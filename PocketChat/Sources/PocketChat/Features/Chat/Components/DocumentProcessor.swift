// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/Chat/Components/DocumentProcessor.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class DocumentProcessor {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
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
import MLXEngine
import AIDevLogger
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
import PDFKit
#elseif os(macOS)
import AppKit
import PDFKit
#endif

/// Handles document processing including vision and embedding features
@MainActor
final class DocumentProcessor {
    private let logger = Logger(label: "DocumentProcessor")
    private let visionEngine = VisionLanguageEngine.shared

    private enum ProcessingError: Error {
        case imageDataUnavailable
        case pdfConversionFailed
    }

#if os(iOS)
    private typealias PDFRenderedImage = UIImage
#elseif os(macOS)
    private typealias PDFRenderedImage = NSImage
#endif

    // Preview info for picked document
    struct PickedDocumentPreview {
        let url: URL?
        let fileName: String
        let fileType: String
        let iconName: String
        let imageThumbnail: Data? // PNG/JPEG data for images or PDF first page
        let fileSize: String?

        // Current initializer used by app code
        init(url: URL, fileName: String, fileType: String, iconName: String = "doc", imageThumbnail: Data? = nil, fileSize: String? = nil) {
            self.url = url
            self.fileName = fileName
            self.fileType = fileType
            self.iconName = iconName
            self.imageThumbnail = imageThumbnail
            self.fileSize = fileSize
        }

        // Legacy initializer expected by older tests/UI
        init(fileName: String, fileSize: String, fileType: String, fileURL: URL? = nil, thumbnailImage: Data? = nil) {
            self.url = fileURL
            self.fileName = fileName
            self.fileType = fileType
            self.iconName = "doc"
            self.imageThumbnail = thumbnailImage
            self.fileSize = fileSize
        }

        // Legacy property aliases for compatibility
        var fileURL: URL? { url }
        var thumbnailImage: Data? { imageThumbnail }
    }

    // Supported document types (images, PDFs)
    #if os(iOS)
    let supportedDocumentTypes: [UTType] = [.image, .pdf]
    #elseif os(macOS)
    let supportedDocumentTypes: [UTType] = [.image, .pdf]
    #else
    let supportedDocumentTypes: [UTType] = [.image]
    #endif

    // Dependencies
    private var messages: [ChatMessage] = []
    private var isGenerating: Bool = false
    private var errorMessage: String?
    private var visionModelOverride: ModelConfiguration?

    // Callbacks for UI updates
    var onMessagesUpdated: (([ChatMessage]) -> Void)?
    var onGenerationStateChanged: ((Bool) -> Void)?
    var onErrorMessageUpdated: ((String?) -> Void)?

    init() {}

    func setVisionModelOverride(_ model: ModelConfiguration?) {
        visionModelOverride = model
    }

    // MARK: - Document Handling

    func handlePickedDocument(url: URL) {
        // Detect file type
        let type = UTType(filenameExtension: url.pathExtension)
        let fileName = url.lastPathComponent
        var iconName = "doc"
        var fileType = "Unknown"
        var imageThumbnail: Data? = nil

        if let type = type {
            if type.conforms(to: .image) {
                fileType = "Image"
                iconName = "photo"
                // Try to load thumbnail data
                #if os(iOS)
                if let image = UIImage(contentsOfFile: url.path),
                   let data = image.jpegData(compressionQuality: 0.7) {
                    imageThumbnail = data
                }
                #elseif os(macOS)
                if let image = NSImage(contentsOf: url),
                   let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let data = bitmap.representation(using: .jpeg, properties: [:]) {
                    imageThumbnail = data
                }
                #endif
            } else if type.conforms(to: .pdf) {
                fileType = "PDF"
                iconName = "doc.richtext"
                // Render first page as image thumbnail (platform-specific)
                #if os(iOS) || os(macOS)
                if let pdfDoc = PDFDocument(url: url), let page = pdfDoc.page(at: 0) {
                    #if os(iOS)
                    let pageRect = page.bounds(for: .mediaBox)
                    UIGraphicsBeginImageContextWithOptions(pageRect.size, false, 0.0)
                    if let ctx = UIGraphicsGetCurrentContext() {
                        UIColor.white.set()
                        ctx.fill(pageRect)
                        page.draw(with: .mediaBox, to: ctx)
                        if let image = UIGraphicsGetImageFromCurrentImageContext(), let data = image.jpegData(compressionQuality: 0.7) {
                            imageThumbnail = data
                        }
                    }
                    UIGraphicsEndImageContext()
                    #elseif os(macOS)
                    let pageRect = page.bounds(for: .mediaBox)
                    let img = NSImage(size: pageRect.size)
                    img.lockFocus()
                    if let ctx = NSGraphicsContext.current?.cgContext {
                        NSColor.white.set()
                        ctx.fill(pageRect)
                        page.draw(with: .mediaBox, to: ctx)
                        if let tiff = img.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .jpeg, properties: [:]) {
                            imageThumbnail = data
                        }
                    }
                    img.unlockFocus()
                    #endif
                }
                #endif
            } else if type.conforms(to: .plainText) {
                fileType = "Text"
                iconName = "doc.text"
                // No preview for text
            } else {
                fileType = type.localizedDescription ?? "Unknown"
                iconName = "questionmark.folder"
            }
        }

        pickedDocumentPreview = PickedDocumentPreview(
            url: url,
            fileName: fileName,
            fileType: fileType,
            iconName: iconName,
            imageThumbnail: imageThumbnail
        )
        errorMessage = nil
        onErrorMessageUpdated?(errorMessage)
    }

    // MARK: - Vision Features

    func describeImage(prompt: String) async {
        guard pickedDocumentPreview != nil else {
            errorMessage = "Attach an image before running vision analysis."
            onErrorMessageUpdated?(errorMessage)
            return
        }

        await sendPickedDocumentToModel(prompt: prompt)
    }

    // MARK: - Document Processing

    func sendPickedDocumentToModel(prompt: String?) async {
        guard let preview = pickedDocumentPreview else {
            errorMessage = "Select a file before sending to the model."
            onErrorMessageUpdated?(errorMessage)
            return
        }

        isGenerating = true
        onGenerationStateChanged?(isGenerating)

        defer {
            isGenerating = false
            onGenerationStateChanged?(isGenerating)
        }

        switch preview.fileType {
        case "Image":
            await processWithVisionModel(preview: preview, prompt: prompt)
        case "PDF":
            do {
                let imageData = try convertPDFToImageData(from: preview)
                await processWithVisionModel(preview: preview, prompt: prompt, imageDataOverride: imageData)
            } catch {
                logger.error("PDF conversion failed", context: Logger.Context([
                    "file": preview.fileName,
                    "error": error.localizedDescription
                ]))
                let message: String
                if let processingError = error as? ProcessingError {
                    switch processingError {
                    case .pdfConversionFailed:
                        message = "Unable to convert the PDF into an image. Try a smaller document or export the page as an image."
                    case .imageDataUnavailable:
                        message = "Could not access PDF data." // Should not occur here but keep for completeness
                    }
                } else {
                    message = error.localizedDescription
                }
                errorMessage = "PDF conversion failed: \(message)"
                onErrorMessageUpdated?(errorMessage)
            }
        case "Text":
            await processWithEmbeddingModel(preview: preview)
        default:
            errorMessage = "Unsupported file type for model input."
            onErrorMessageUpdated?(errorMessage)
        }
    }

    private func processWithVisionModel(preview: PickedDocumentPreview, prompt: String?, imageDataOverride: Data? = nil) async {
        defer { visionModelOverride = nil }
        do {
            let imageData = try imageDataOverride ?? loadImageData(for: preview)
            let vlmModel = visionModelOverride ?? ModelRegistry.defaultModel(for: .vlm)
            let result = try await visionEngine.describeImage(data: imageData, prompt: prompt, model: vlmModel)
            visionModelOverride = nil

            let userMessage = ChatMessage(
                role: .user,
                content: makeUserMessage(for: preview, prompt: result.prompt),
                timestamp: Date()
            )

            let performance = ChatMessage.PerformanceInfo(
                modelId: result.modelId,
                modelName: vlmModel?.name ?? result.modelId.split(separator: "/").last.map(String.init),
                tokensPerSecond: result.tokensPerSecond,
                tokenCount: result.tokenCount,
                generationDuration: result.duration
            )

            let assistantMessage = ChatMessage(
                role: .assistant,
                content: result.text,
                timestamp: Date(),
                performance: performance
            )

            messages.append(userMessage)
            messages.append(assistantMessage)
            onMessagesUpdated?(messages)

            pickedDocumentPreview = nil
            errorMessage = nil
            onErrorMessageUpdated?(errorMessage)
        } catch let processingError as ProcessingError {
            logger.error("Vision processing failed", context: Logger.Context([
                "file": preview.fileName,
                "error": String(describing: processingError)
            ]))
            errorMessage = "Could not load image data. Please try a different file."
            onErrorMessageUpdated?(errorMessage)
        } catch {
            logger.error("Vision processing failed", context: Logger.Context([
                "file": preview.fileName,
                "error": error.localizedDescription
            ]))
            errorMessage = "Vision error: \(error.localizedDescription)"
            onErrorMessageUpdated?(errorMessage)
        }
    }

    private func processWithEmbeddingModel(preview: PickedDocumentPreview) async {
        guard let embeddingModel = ModelRegistry.defaultModel(for: .embedding, preferSmallerModels: true) else {
            errorMessage = "No embedding model available."
            onErrorMessageUpdated?(errorMessage)
            return
        }

        do {
            // Download if needed - this would need to be handled by the parent view model
            // For now, assume it's downloaded
            let engine = try await InferenceEngine.loadModel(embeddingModel) { progress in
                print("Embedding model loading progress: \(progress)")
            }

            guard let url = preview.url else {
                errorMessage = "Missing file URL."
                onErrorMessageUpdated?(errorMessage)
                return
            }

            let text = try String(contentsOf: url, encoding: .utf8)
            let response = try await engine.generate(text, params: GenerateParams(maxTokens: 10, temperature: 0.0))

            let userMsg = ChatMessage(role: .user, content: "[Sent file: \(preview.fileName)]\n\n\(text.prefix(200))...", timestamp: Date())
            let assistantMsg = ChatMessage(role: .assistant, content: response, timestamp: Date())

            messages.append(userMsg)
            messages.append(assistantMsg)
            onMessagesUpdated?(messages)

            pickedDocumentPreview = nil

        } catch {
            errorMessage = "Embedding error: \(error.localizedDescription)"
            onErrorMessageUpdated?(errorMessage)
        }
    }

    private func loadImageData(for preview: PickedDocumentPreview) throws -> Data {
        if let url = preview.url {
            #if os(macOS)
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            #endif
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }

        if let data = preview.imageThumbnail {
            return data
        }

        throw ProcessingError.imageDataUnavailable
    }

    private func convertPDFToImageData(from preview: PickedDocumentPreview) throws -> Data {
        guard let url = preview.url else {
            throw ProcessingError.pdfConversionFailed
        }

#if os(macOS)
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
#endif

        guard let pdfDocument = PDFDocument(url: url), pdfDocument.pageCount > 0 else {
            throw ProcessingError.pdfConversionFailed
        }

        do {
            if let mergedData = try mergeAllPages(of: pdfDocument) {
                return mergedData
            }
        } catch {
            logger.warning("Falling back to first page for PDF conversion", context: Logger.Context([
                "file": preview.fileName,
                "error": error.localizedDescription
            ]))
        }

        guard let firstPageData = try firstPageImageData(of: pdfDocument) else {
            throw ProcessingError.pdfConversionFailed
        }

        return firstPageData
    }

    private func renderPDFPage(_ page: PDFPage, targetWidth: CGFloat) -> PDFRenderedImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            logger.warning("PDF page has invalid bounds", context: Logger.Context([
                "width": "\(bounds.width)",
                "height": "\(bounds.height)"
            ]))
            return nil
        }

        let scale = targetWidth / max(bounds.width, 1)
        let targetSize = CGSize(width: targetWidth, height: bounds.height * scale)

#if os(iOS)
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let renderedImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            let context = ctx.cgContext
            context.saveGState()
            context.translateBy(x: 0, y: targetSize.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
        }

        if renderedImage.size != .zero {
            return renderedImage
        }

        let thumbnail = page.thumbnail(of: targetSize, for: .mediaBox)
        return thumbnail.size == .zero ? nil : thumbnail
#elseif os(macOS)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: targetSize)).fill()
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.translateBy(x: 0, y: targetSize.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
        }
        image.unlockFocus()

        if let tiff = image.tiffRepresentation, !tiff.isEmpty {
            return image
        }

        let thumbnail = page.thumbnail(of: targetSize, for: .mediaBox)
        guard thumbnail.size != .zero else { return nil }

        let fallback = NSImage(size: thumbnail.size)
        fallback.lockFocus()
        thumbnail.draw(in: NSRect(origin: .zero, size: thumbnail.size))
        fallback.unlockFocus()
        return fallback
#endif
    }

    private func mergeAllPages(of document: PDFDocument) throws -> Data? {
        let pageCount = document.pageCount
        guard pageCount > 0 else { return nil }

        var renderedPages: [PDFRenderedImage] = []

        let targetWidth: CGFloat = 1024
        let maxHeight: CGFloat = 16000
        var totalHeight: CGFloat = 0
        for index in 0..<pageCount {
            guard let page = document.page(at: index) else { continue }
            guard let image = renderPDFPage(page, targetWidth: targetWidth) else {
                logger.warning("Skipping PDF page rendering failure", context: Logger.Context([
                    "pageIndex": "\(index)"
                ]))
                continue
            }
            renderedPages.append(image)
            totalHeight += image.size.height
        }

        guard !renderedPages.isEmpty else { return nil }

        // Avoid producing excessively large images that could crash the app.
        if totalHeight == 0 {
            throw ProcessingError.pdfConversionFailed
        }

        if totalHeight > maxHeight {
            logger.warning("Combined PDF height exceeds limits, scaling down", context: Logger.Context([
                "pageCount": "\(pageCount)",
                "originalHeight": "\(totalHeight)",
                "maxHeight": "\(maxHeight)"
            ]))
            let scaleFactor = maxHeight / totalHeight
            totalHeight = 0
            renderedPages = renderedPages.map { image in
#if os(iOS)
                let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
                UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let scaled = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                totalHeight += scaled?.size.height ?? 0
                return scaled ?? image
#elseif os(macOS)
                let newSize = NSSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
                let scaled = NSImage(size: newSize)
                scaled.lockFocus()
                let destinationRect = NSRect(origin: NSPoint(x: 0, y: 0), size: newSize)
                let sourceRect = NSRect(origin: NSPoint(x: 0, y: 0), size: image.size)
                image.draw(in: destinationRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
                scaled.unlockFocus()
                totalHeight += scaled.size.height
                return scaled
#endif
            }
        }

        if totalHeight == 0 {
            throw ProcessingError.pdfConversionFailed
        }

#if os(iOS)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: targetWidth, height: totalHeight), true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            throw ProcessingError.pdfConversionFailed
        }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: CGSize(width: targetWidth, height: totalHeight)))

        var currentY: CGFloat = 0
        for image in renderedPages {
            image.draw(in: CGRect(x: 0, y: currentY, width: targetWidth, height: image.size.height))
            currentY += image.size.height
        }

        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return combinedImage?.jpegData(compressionQuality: 0.85)
#elseif os(macOS)
        let finalSize = NSSize(width: targetWidth, height: totalHeight)
        let combinedImage = NSImage(size: finalSize)
        combinedImage.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: finalSize)).fill()

        var currentY: CGFloat = totalHeight
        for image in renderedPages {
            currentY -= image.size.height
            let destinationRect = NSRect(x: 0, y: currentY, width: targetWidth, height: image.size.height)
            let sourceRect = NSRect(origin: NSPoint(x: 0, y: 0), size: image.size)
            image.draw(in: destinationRect, from: sourceRect, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        }

        combinedImage.unlockFocus()

        guard let tiff = combinedImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
#endif
    }

    private func firstPageImageData(of document: PDFDocument) throws -> Data? {
        guard let firstPage = document.page(at: 0) else { return nil }
    guard let rendered = renderPDFPage(firstPage, targetWidth: 1024) else { return nil }

#if os(iOS)
    return rendered.jpegData(compressionQuality: 0.85)
#elseif os(macOS)
    guard let tiff = rendered.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
        return nil
    }
    return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
#endif
    }

    private func makeUserMessage(for preview: PickedDocumentPreview, prompt: String) -> String {
        var lines: [String] = ["Sent image: \(preview.fileName)"]
        if !prompt.isEmpty {
            lines.append("Prompt: \(prompt)")
        }
        return lines.joined(separator: "\n\n")
    }

    // MARK: - Embedding Feature

    func generateEmbedding(phrase: String) async {
        isGenerating = true
        onGenerationStateChanged?(isGenerating)

        defer {
            isGenerating = false
            onGenerationStateChanged?(isGenerating)
        }

        // Select a default embedding model from the registry
        guard let embeddingModel = ModelRegistry.defaultModel(for: .embedding, preferSmallerModels: true) else {
            errorMessage = "No embedding model available."
            onErrorMessageUpdated?(errorMessage)
            return
        }

        do {
            // Download if needed - this would need to be handled by the parent view model
            // For now, assume it's downloaded
            let engine = try await InferenceEngine.loadModel(embeddingModel) { progress in
                print("Embedding model loading progress: \(progress)")
            }
            let response = try await engine.generate(phrase, params: GenerateParams(maxTokens: 10, temperature: 0.0))

            let message = ChatMessage(role: .assistant, content: "Embedding: \(response)", timestamp: Date())
            messages.append(message)
            onMessagesUpdated?(messages)

        } catch {
            errorMessage = "Embedding error: \(error.localizedDescription)"
            onErrorMessageUpdated?(errorMessage)
        }
    }

    // MARK: - State Management

    var pickedDocumentPreview: PickedDocumentPreview? {
        didSet {
            // Could add callback here if needed
        }
    }

    func getMessages() -> [ChatMessage] {
        return messages
    }

    func setMessages(_ newMessages: [ChatMessage]) {
        messages = newMessages
        onMessagesUpdated?(messages)
    }

    func getErrorMessage() -> String? {
        return errorMessage
    }

    func setErrorMessage(_ message: String?) {
        errorMessage = message
        onErrorMessageUpdated?(errorMessage)
    }
}
