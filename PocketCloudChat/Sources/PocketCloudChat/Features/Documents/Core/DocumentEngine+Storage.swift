import Foundation
import PocketCloudUI

extension DocumentEngine {
    func loadDocumentLibrary() async {
        do {
            if !fileManager.fileExists(atPath: libraryFileURL.path) {
                documentLibrary = []
                return
            }

            let data = try Data(contentsOf: libraryFileURL)
        let decoded = try jsonDecoder.decode([DocumentFile].self, from: data)
            documentLibrary = decoded.filter { file in
                guard let storedPath = file.storedPath else { return false }
                return fileManager.fileExists(atPath: storedPath)
            }
        } catch {
            logger.error("Failed to load document library: \(error.localizedDescription)")
            documentLibrary = []
        }
    }

    func saveDocumentLibrary() async {
        do {
            let data = try jsonEncoder.encode(documentLibrary)
            try ensureParentDirectoryExists(for: libraryFileURL)
            try data.write(to: libraryFileURL, options: [.atomic])
            logger.info("Document library persisted with \(self.documentLibrary.count) files")
        } catch {
            logger.error("Failed to save document library: \(error.localizedDescription)")
        }
    }

    func prepareStorageDirectories() {
        do {
            try ensureDirectoryExists(at: storageRootURL)
            try ensureDirectoryExists(at: documentsDirectoryURL)
        } catch {
            logger.error("Failed to prepare storage directories: \(error.localizedDescription)")
        }
    }

    func persistFile(from sourceURL: URL, documentID: UUID, fileExtension: String, allowFallback: Bool = true) throws -> URL {
        try ensureDirectoryExists(at: documentsDirectoryURL)

        let sanitizedExtension = fileExtension.isEmpty ? nil : fileExtension
        let fileName = sanitizedExtension.map { "\(documentID.uuidString).\($0)" } ?? documentID.uuidString
    var destinationURL = documentsDirectoryURL.appendingPathComponent(fileName, isDirectory: false)

        let standardizedSource = sourceURL.standardizedFileURL
        if standardizedSource == destinationURL.standardizedFileURL {
            return destinationURL
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            if allowFallback, shouldFallbackToLocalStorage(for: error) {
                switchToFallbackStorage(reason: error.localizedDescription)
                prepareStorageDirectories()
                return try persistFile(from: sourceURL, documentID: documentID, fileExtension: fileExtension, allowFallback: false)
            }
            throw error
        }

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
    try destinationURL.setResourceValues(resourceValues)

        return destinationURL
    }

    func deletePersistedFile(for document: DocumentFile) {
        guard let storedPath = document.storedPath else { return }
        do {
            if fileManager.fileExists(atPath: storedPath) {
                try fileManager.removeItem(atPath: storedPath)
            }
        } catch {
            logger.error("Failed to remove stored file for document \(document.id): \(error.localizedDescription)")
        }
    }

    func resolveStorageRootURL() -> URL {
        if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            if ensureWritableDirectory(at: appGroupURL) {
                return appGroupURL
            }
            logger.error("App group container \(self.appGroupIdentifier) is not writable; falling back to local storage")
        }

        return fallbackStorageRootURL()
    }
}

private extension DocumentEngine {
    func ensureParentDirectoryExists(for fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try ensureDirectoryExists(at: directoryURL)
    }

    func ensureDirectoryExists(at directoryURL: URL) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func shouldFallbackToLocalStorage(for error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSCocoaErrorDomain else { return false }

        switch nsError.code {
        case NSFileWriteNoPermissionError,
             NSFileReadNoPermissionError,
             NSFileWriteVolumeReadOnlyError:
            return true
        default:
            return false
        }
    }

    @discardableResult
    func switchToFallbackStorage(reason: String) -> URL {
        let fallbackRoot = fallbackStorageRootURL()
        if storageRootURL != fallbackRoot {
            logger.error("Switching document storage to fallback directory: \(fallbackRoot.path) (reason: \(reason))")
            aiLogger.error("Fallback storage activated at \(fallbackRoot.path)")
            storageRootURL = fallbackRoot
        }
        return fallbackRoot
    }

    func fallbackStorageRootURL() -> URL {
        let supportURL = applicationSupportDirectoryURL()
        if ensureWritableDirectory(at: supportURL) {
            return supportURL
        }

        let temporaryURL = fileManager.temporaryDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        do {
            try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create temporary storage directory: \(error.localizedDescription)")
        }
        return temporaryURL
    }

    func applicationSupportDirectoryURL() -> URL {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return supportDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
    }

    func ensureWritableDirectory(at directoryURL: URL) -> Bool {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let probeURL = directoryURL.appendingPathComponent(".mlx-write-test-\(UUID().uuidString)")
            try Data().write(to: probeURL, options: .atomic)
            try fileManager.removeItem(at: probeURL)
            return true
        } catch {
            logger.error("Directory check failed for \(directoryURL.path): \(error.localizedDescription)")
            return false
        }
    }
}
