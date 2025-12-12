import Foundation
import UniformTypeIdentifiers

extension DocumentEngine {
    public func extractFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        aiLogger.debug("extractFileURLs received \(providers.count) provider(s)")

        let urls = await withTaskGroup(of: URL?.self) { group in
            for provider in providers {
                let typeIdentifiers = provider.registeredTypeIdentifiers.joined(separator: ", ")
                aiLogger.debug("Provider advertised type identifiers: [\(typeIdentifiers)]")
                group.addTask {
                    do {
                        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                            if let url = try await self.loadURLItem(from: provider, typeIdentifier: UTType.fileURL.identifier) {
                                self.aiLogger.debug("Provider yielded fileURL: \(url.lastPathComponent)")
                                return url
                            }
                        }

                        if provider.canLoadObject(ofClass: NSURL.self) {
                            if let url = try await self.loadNSURLObject(from: provider) {
                                self.aiLogger.debug("Provider yielded NSURL: \(url.lastPathComponent)")
                                return url
                            }
                        }

                        if provider.canLoadObject(ofClass: NSString.self) {
                            if let url = try await self.loadPathString(from: provider) {
                                self.aiLogger.debug("Provider yielded NSString path: \(url.lastPathComponent)")
                                return url
                            }
                        }

                        if provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                            if let url = try await self.loadFileRepresentation(from: provider, typeIdentifier: UTType.item.identifier) {
                                self.aiLogger.debug("Provider yielded file representation for item: \(url.lastPathComponent)")
                                return url
                            }
                        }

                        if let firstIdentifier = provider.registeredTypeIdentifiers.first {
                            if let url = try await self.loadFileRepresentation(from: provider, typeIdentifier: firstIdentifier) {
                                self.aiLogger.debug("Provider yielded file representation for \(firstIdentifier): \(url.lastPathComponent)")
                                return url
                            }
                        }
                    } catch {
                        self.logger.error("Failed to load dropped item: \(error.localizedDescription)")
                        self.aiLogger.error("Provider failed with error: \(error.localizedDescription)")
                    }

                    return nil
                }
            }

            var collected: [URL] = []
            for await result in group {
                if let url = result {
                    collected.append(url)
                }
            }
            return collected
        }

        aiLogger.debug("extractFileURLs resolved \(urls.count) URL(s)")
        return urls
    }

    public func handleDrop(providers: [NSItemProvider]) async -> Bool {
        aiLogger.debug("handleDrop received \(providers.count) provider(s)")
        isProcessing = true
        defer { isProcessing = false }

        let urls = await extractFileURLs(from: providers)
        aiLogger.debug("handleDrop resolved \(urls.count) URL(s)")

        if !urls.isEmpty {
            await addFiles(urls)
            aiLogger.debug("handleDrop completed addFiles")
            return true
        }

        aiLogger.debug("handleDrop found no resolvable URLs")
        return false
    }
}

private extension DocumentEngine {
    func loadURLItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    self.aiLogger.debug("loadURLItem returned URL: \(url.lastPathComponent)")
                    continuation.resume(returning: url)
                } else if let data = item as? Data {
                    if let url = URL(dataRepresentation: data, relativeTo: nil) {
                        self.aiLogger.debug("loadURLItem produced URL from data: \(url.lastPathComponent)")
                        continuation.resume(returning: url)
                    } else {
                        self.aiLogger.debug("loadURLItem could not derive URL from data payload")
                        continuation.resume(returning: nil)
                    }
                } else if let string = item as? String {
                    self.aiLogger.debug("loadURLItem produced path string: \(string)")
                    continuation.resume(returning: URL(fileURLWithPath: string))
                } else if let nsURL = item as? NSURL {
                    let url = nsURL as URL
                    self.aiLogger.debug("loadURLItem returned NSURL: \(url.lastPathComponent)")
                    continuation.resume(returning: url)
                } else {
                    self.aiLogger.debug("loadURLItem returned unsupported item: \(String(describing: item))")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func loadNSURLObject(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: NSURL.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = object as? URL {
                    self.aiLogger.debug("loadNSURLObject returned URL: \(url.lastPathComponent)")
                    continuation.resume(returning: url)
                } else {
                    self.aiLogger.debug("loadNSURLObject returned nil object")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func loadPathString(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: NSString.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let stringObject = object as? NSString {
                    let path = stringObject as String
                    self.aiLogger.debug("loadPathString returned NSString: \(path)")
                    continuation.resume(returning: URL(fileURLWithPath: path))
                } else {
                    self.aiLogger.debug("loadPathString returned nil object")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func loadFileRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    self.aiLogger.debug("loadFileRepresentation returned nil for type \(typeIdentifier)")
                    continuation.resume(returning: nil)
                    return
                }

                let tempDirectory = FileManager.default.temporaryDirectory
                let destination = tempDirectory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")

                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                    Task { @MainActor in
                        self.aiLogger.debug("loadFileRepresentation copied file to temp destination: \(destination.lastPathComponent)")
                    }
                    continuation.resume(returning: destination)
                } catch {
                    Task { @MainActor in
                        self.aiLogger.error("loadFileRepresentation failed to persist temporary file: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
