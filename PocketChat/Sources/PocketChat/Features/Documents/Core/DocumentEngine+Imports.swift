import Foundation
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

extension DocumentEngine {
    func importFromPhotoLibrary() async -> [URL] {
        aiLogger.debug("importFromPhotoLibrary invoked")
        #if os(iOS)
        logger.info("Photo library import requested")
        return []
        #else
        await setError("Photo library not available on this platform")
        return []
        #endif
    }

    func importFromFilesApp() async -> [URL] {
        aiLogger.debug("importFromFilesApp invoked")
        #if os(iOS)
        logger.info("Files app import requested")
        return []
        #elseif os(macOS)
        logger.info("File picker import requested")
        return await withCheckedContinuation { continuation in
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.resume(returning: [])
                    return
                }

                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = self.allowsMultipleSelection
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = self.selectedCategory.supportedTypes
                panel.begin { response in
                    guard response == .OK else {
                        self.aiLogger.debug("NSOpenPanel cancelled")
                        continuation.resume(returning: [])
                        return
                    }

                    let urls = panel.urls
                    guard !urls.isEmpty else {
                        self.aiLogger.debug("NSOpenPanel returned no URLs")
                        continuation.resume(returning: [])
                        return
                    }

                    Task { [weak self] in
                        guard let self else {
                            continuation.resume(returning: [])
                            return
                        }

                        let exported = await self.handleImportedURLs(urls)
                        self.aiLogger.debug("importFromFilesApp produced \(exported.count) URL(s)")
                        continuation.resume(returning: exported)
                    }
                }
            }
        }
        #else
        await setError("File picker not available on this platform")
        return []
        #endif
    }

    func importFromCamera() async -> [URL] {
        aiLogger.debug("importFromCamera invoked")
        #if os(iOS)
        logger.info("Camera import requested")
        return []
        #else
        await setError("Camera not available on this platform")
        return []
        #endif
    }

    func importFromDocumentScanner() async -> [URL] {
        aiLogger.debug("importFromDocumentScanner invoked")
        #if os(iOS)
        logger.info("Document scanner requested")
        return []
        #else
        await setError("Document scanner not available on this platform")
        return []
        #endif
    }

    func importFromCloudStorage() async -> [URL] {
        aiLogger.debug("importFromCloudStorage invoked")
        logger.info("Cloud storage import requested")
        return []
    }

    func handleImportedURLs(_ urls: [URL]) async -> [URL] {
        guard !urls.isEmpty else { return [] }

        let existingIDs = Set(selectedFiles.map { $0.id })
        aiLogger.debug("handleImportedURLs ingesting \(urls.count) URL(s)")
        await addFiles(urls)

        let newFiles = selectedFiles.filter { !existingIDs.contains($0.id) }
        let exported = newFiles.compactMap { $0.url }
        aiLogger.debug("handleImportedURLs returning \(exported.count) new URL(s)")
        return exported
    }
}

public enum DeviceImportSource {
    case photoLibrary
    case files
    case camera
    case scanner
    case cloud
}
