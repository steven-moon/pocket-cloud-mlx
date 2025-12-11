// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/Context/ContextManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class ContextManager: ObservableObject {
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
import EventKit
import Contacts
import Vision
import PDFKit
import PocketCloudCommon
import PocketCloudLogger

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Manages context extraction from various system sources
@MainActor
public class ContextManager: ObservableObject {
    private let logger = Logger(label: "ContextManager")
    private let networkManager = NetworkManager()
    
    @Published public var currentContext: [ContextItem] = []
    @Published public var contextualSuggestions: [String] = []
    @Published public var isProcessingContext = false
    
    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()
    
    public init() {
        logger.info("ContextManager initialized")
    }
    
    // MARK: - Web Page Context
    
    /// Extract context from a webpage URL
    public func extractWebPageContext(from url: URL) async -> WebPageContext? {
        logger.info("Extracting webpage context from: \(url.absoluteString)")
        
        do {
            let response = try await networkManager.send(NetworkRequest(url: url))
            guard response.statusCode == 200,
                  let htmlString = String(data: response.data, encoding: .utf8) else {
                logger.error("Failed to fetch webpage content")
                return nil
            }
            
            // Basic HTML parsing - extract title and content
            let title = extractTitle(from: htmlString)
            let content = extractMainContent(from: htmlString)
            let images = extractImageURLs(from: htmlString)
            let links = extractLinks(from: htmlString)
            
            let context = WebPageContext(
                url: url,
                title: title,
                content: content,
                images: images,
                links: links,
                extractedAt: Date()
            )
            
            logger.info("Successfully extracted webpage context: \(title)")
            return context
            
        } catch {
            logger.error("Error extracting webpage context: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Calendar Context
    
    /// Extract recent and upcoming calendar events
    public func extractCalendarContext() async -> [CalendarEvent] {
        logger.info("Extracting calendar context")
        
        // Check and request calendar access
        let status = EKEventStore.authorizationStatus(for: .event)
        
        if status == .denied || status == .restricted {
            logger.warning("Calendar access not authorized")
            return []
        }
        
        // Request authorization if not determined
        if status == .notDetermined {
            do {
                let granted: Bool
                if #available(macOS 14.0, iOS 17.0, *) {
                    granted = try await eventStore.requestFullAccessToEvents()
                } else {
                    granted = try await eventStore.requestAccess(to: .event)
                }
                if !granted {
                    logger.warning("Calendar access denied")
                    return []
                }
            } catch {
                logger.error("Error requesting calendar access: \(error.localizedDescription)")
                return []
            }
            return []
        }
        
        // Get events from last week to next month
        let startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        let calendarEvents = events.map { event in
            CalendarEvent(
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                isAllDay: event.isAllDay
            )
        }
        
        logger.info("Extracted \(calendarEvents.count) calendar events")
        return calendarEvents
    }
    
    // MARK: - Document Context
    
    /// Extract context from a document file
    public func extractDocumentContext(from url: URL) async -> DocumentContext? {
        logger.info("Extracting document context from: \(url.lastPathComponent)")
        
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return await processPDFDocument(url)
        case "txt", "md":
            return await processTextDocument(url)
        case "jpg", "jpeg", "png", "heic":
            return await processImageDocument(url)
        default:
            logger.warning("Unsupported document type: \(fileExtension)")
            return nil
        }
    }
    
    // MARK: - Context Management
    
    /// Add a context item to the current context
    public func addContextItem(_ item: ContextItem) {
        currentContext.append(item)
        updateContextualSuggestions()
        logger.info("Added context item: \(item.type.rawValue)")
    }
    
    /// Clear all current context
    public func clearContext() {
        currentContext.removeAll()
        contextualSuggestions.removeAll()
        logger.info("Cleared all context")
    }
    
    /// Generate contextual suggestions based on current context
    private func updateContextualSuggestions() {
        var suggestions: [String] = []
        
        for item in currentContext {
            switch item.type {
            case .webpage:
                suggestions.append(contentsOf: [
                    "Summarize this webpage",
                    "What are the key points?",
                    "Explain this in simple terms"
                ])
            case .document:
                suggestions.append(contentsOf: [
                    "Summarize this document",
                    "Extract key information",
                    "Create action items"
                ])
            case .calendar:
                suggestions.append(contentsOf: [
                    "What's on my schedule?",
                    "Prepare for upcoming meetings",
                    "Schedule conflicts?"
                ])
            case .contact, .system:
                break
            }
        }
        
        // Remove duplicates and limit to 5 suggestions
        contextualSuggestions = Array(Set(suggestions)).prefix(5).map { $0 }
    }
    
    // MARK: - Private Helper Methods
    
    private func extractTitle(from html: String) -> String {
        let titlePattern = "<title[^>]*>([^<]+)</title>"
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let titleRange = Range(match.range(at: 1), in: html) {
            return String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Untitled"
    }
    
    private func extractMainContent(from html: String) -> String {
        // Remove HTML tags and extract text content
        let cleanedHTML = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let content = cleanedHTML.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractImageURLs(from html: String) -> [URL] {
        let imgPattern = "<img[^>]+src=[\"']([^\"']+)[\"'][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) else {
            return []
        }
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        return matches.compactMap { match in
            guard let srcRange = Range(match.range(at: 1), in: html) else { return nil }
            let srcString = String(html[srcRange])
            return URL(string: srcString)
        }
    }
    
    private func extractLinks(from html: String) -> [URL] {
        let linkPattern = "<a[^>]+href=[\"']([^\"']+)[\"'][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) else {
            return []
        }
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        return matches.compactMap { match in
            guard let hrefRange = Range(match.range(at: 1), in: html) else { return nil }
            let hrefString = String(html[hrefRange])
            return URL(string: hrefString)
        }
    }
    
    private func processPDFDocument(_ url: URL) async -> DocumentContext? {
        guard let pdfDocument = PDFDocument(url: url) else {
            logger.error("Failed to load PDF document")
            return nil
        }
        
        var extractedText = ""
        let pageCount = pdfDocument.pageCount
        
        for pageIndex in 0..<min(pageCount, 10) { // Limit to first 10 pages
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                extractedText += pageText + "\n"
            }
        }
        
        return DocumentContext(
            url: url,
            fileName: url.lastPathComponent,
            fileType: .pdf,
            extractedText: extractedText,
            summary: generateSummary(from: extractedText),
            keyPoints: extractKeyPoints(from: extractedText),
            extractedAt: Date()
        )
    }
    
    private func processTextDocument(_ url: URL) async -> DocumentContext? {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            
            return DocumentContext(
                url: url,
                fileName: url.lastPathComponent,
                fileType: .text,
                extractedText: content,
                summary: generateSummary(from: content),
                keyPoints: extractKeyPoints(from: content),
                extractedAt: Date()
            )
        } catch {
            logger.error("Failed to read text document: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func processImageDocument(_ url: URL) async -> DocumentContext? {
        #if os(iOS)
        guard let image = UIImage(contentsOfFile: url.path) else {
            logger.error("Failed to load image")
            return nil
        }
        #elseif os(macOS)
        guard let image = NSImage(contentsOf: url) else {
            logger.error("Failed to load image")
            return nil
        }
        #endif
        
        // Use Vision framework to extract text from image
        let extractedText = await extractTextFromImage(image)
        
        return DocumentContext(
            url: url,
            fileName: url.lastPathComponent,
            fileType: .image,
            extractedText: extractedText,
            summary: generateSummary(from: extractedText),
            keyPoints: extractKeyPoints(from: extractedText),
            extractedAt: Date()
        )
    }
    
    #if os(iOS)
    private func extractTextFromImage(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            let observations = request.results ?? []
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            return recognizedText
        } catch {
            logger.error("Text recognition failed: \(error.localizedDescription)")
            return ""
        }
    }
    #elseif os(macOS)
    private func extractTextFromImage(_ image: NSImage) async -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            let observations = request.results ?? []
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            return recognizedText
        } catch {
            logger.error("Text recognition failed: \(error.localizedDescription)")
            return ""
        }
    }
    #endif
    
    private func generateSummary(from text: String) -> String {
        // Simple summary generation - take first few sentences
        let sentences = text.components(separatedBy: ". ")
        let summary = sentences.prefix(3).joined(separator: ". ")
        return summary.isEmpty ? "No summary available" : summary
    }
    
    private func extractKeyPoints(from text: String) -> [String] {
        // Simple key point extraction - look for bullet points or numbered lists
        let lines = text.components(separatedBy: .newlines)
        let keyPoints = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || 
               trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                return trimmed
            }
            return nil
        }
        
        return Array(keyPoints.prefix(5)) // Limit to 5 key points
    }
}

// MARK: - Context Data Models

public struct ContextItem: Identifiable {
    public let id = UUID()
    public let type: ContextType
    public let content: String
    public let metadata: [String: Any]
    public let timestamp: Date
    
    public init(type: ContextType, content: String, metadata: [String: Any] = [:], timestamp: Date = Date()) {
        self.type = type
        self.content = content
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

public enum ContextType: String {
    case webpage = "webpage"
    case document = "document" 
    case calendar = "calendar"
    case contact = "contact"
    case system = "system"
}

public struct WebPageContext {
    public let url: URL
    public let title: String
    public let content: String
    public let images: [URL]
    public let links: [URL]
    public let extractedAt: Date
    
    public init(url: URL, title: String, content: String, images: [URL], links: [URL], extractedAt: Date) {
        self.url = url
        self.title = title
        self.content = content
        self.images = images
        self.links = links
        self.extractedAt = extractedAt
    }
}

public struct CalendarEvent {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let notes: String?
    public let isAllDay: Bool
    
    public init(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, isAllDay: Bool) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.isAllDay = isAllDay
    }
}

public struct DocumentContext {
    public let url: URL
    public let fileName: String
    public let fileType: DocumentType
    public let extractedText: String
    public let summary: String
    public let keyPoints: [String]
    public let extractedAt: Date
    
    public init(url: URL, fileName: String, fileType: DocumentType, extractedText: String, summary: String, keyPoints: [String], extractedAt: Date) {
        self.url = url
        self.fileName = fileName
        self.fileType = fileType
        self.extractedText = extractedText
        self.summary = summary
        self.keyPoints = keyPoints
        self.extractedAt = extractedAt
    }
}

public enum DocumentType: String {
    case pdf = "pdf"
    case text = "text" 
    case image = "image"
} 
