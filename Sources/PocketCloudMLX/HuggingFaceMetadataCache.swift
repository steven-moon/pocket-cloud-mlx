// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFaceMetadataCache.swift
// Purpose       : Caching system for HuggingFace model metadata
//
// Key Types in this file:
//   - struct HuggingFaceMetadataCache
//   - struct CachedModelMetadata
//
// == End LLM Context Header ==

import Foundation
import PocketCloudLogger

public extension Notification.Name {
    /// Notification posted when the HuggingFace metadata cache is updated.
    static let huggingFaceMetadataCacheDidChange = Notification.Name("huggingFaceMetadataCacheDidChange")
}

/// Cached metadata from HuggingFace Hub API
public struct CachedModelMetadata: Codable, Hashable, Sendable {
    // Core identification
    public let hubId: String
    public let modelId: String?
    public let author: String?
    public let sha: String?

    // Statistics - Real data from HuggingFace
    public let downloads: Int?
    public let downloadsAllTime: Int?
    public let likes: Int?
    public let trendingScore: Double?

    // Status
    public let private_: Bool?
    public let gated: Bool?
    public let disabled: Bool?

    // Timestamps
    public let createdAt: String?
    public let lastModified: String?

    // Classification
    public let tags: [String]?
    public let pipelineTag: String?
    public let libraryName: String?

    // Content
    public let description: String?
    public let cardData: [String: String]?  // Simplified for caching

    // Files and storage
    public let siblings: [String]?  // Simplified to just filenames
    public let usedStorage: Double?

    // Paper with Code integration
    public let paperswithcodeId: String?

    // Cache metadata
    public let cachedAt: Date
    public let cacheVersion: Int

    public init(
        hubId: String,
        modelId: String? = nil,
        author: String? = nil,
        sha: String? = nil,
        downloads: Int? = nil,
        downloadsAllTime: Int? = nil,
        likes: Int? = nil,
        trendingScore: Double? = nil,
        private_: Bool? = nil,
        gated: Bool? = nil,
        disabled: Bool? = nil,
        createdAt: String? = nil,
        lastModified: String? = nil,
        tags: [String]? = nil,
        pipelineTag: String? = nil,
        libraryName: String? = nil,
        description: String? = nil,
        cardData: [String: String]? = nil,
        siblings: [String]? = nil,
        usedStorage: Double? = nil,
        paperswithcodeId: String? = nil,
        cachedAt: Date = Date(),
        cacheVersion: Int = 1
    ) {
        self.hubId = hubId
        self.modelId = modelId
        self.author = author
        self.sha = sha
        self.downloads = downloads
        self.downloadsAllTime = downloadsAllTime
        self.likes = likes
        self.trendingScore = trendingScore
        self.private_ = private_
        self.gated = gated
        self.disabled = disabled
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.tags = tags
        self.pipelineTag = pipelineTag
        self.libraryName = libraryName
        self.description = description
        self.cardData = cardData
        self.siblings = siblings
        self.usedStorage = usedStorage
        self.paperswithcodeId = paperswithcodeId
        self.cachedAt = cachedAt
        self.cacheVersion = cacheVersion
    }

    /// Create from HuggingFaceModel_Data
    public static func from(_ model: HuggingFaceModel_Data) -> CachedModelMetadata {
        return CachedModelMetadata(
            hubId: model.id,
            modelId: model.modelId,
            author: model.author,
            sha: model.sha,
            downloads: model.downloads.flatMap { Int($0) },
            downloadsAllTime: nil,  // Not available in current model
            likes: model.likes.flatMap { Int($0) },
            trendingScore: model.trendingScore,
            private_: model.private_,
            gated: model.gated,
            disabled: model.disabled,
            createdAt: model.createdAt, // This is the published date
            lastModified: model.lastModified,
            tags: model.tags,
            pipelineTag: model.pipeline_tag,
            libraryName: model.library_name,
            description: nil,  // Would need to parse from cardData
            cardData: nil,  // Simplified for now
            siblings: model.siblings?.map { $0.rfilename },
            usedStorage: model.usedStorage,
            paperswithcodeId: nil,  // Not available in current model
            cachedAt: Date(),
            cacheVersion: 1
        )
    }
}

/// Manager for HuggingFace metadata cache
public actor HuggingFaceMetadataCache {
    public static let shared = HuggingFaceMetadataCache()

    private var cache: [String: CachedModelMetadata] = [:]
    private let cacheFileURL: URL
    private let cacheExpirationDays: Int = 7
    private let logger = Logger(label: "HuggingFaceMetadataCache")
    private var missingHubIds: [String: Date] = [:]
    private let missingHubIdRetryInterval: TimeInterval = 6 * 60 * 60 // Retry every 6 hours

    private init() {
        // Set up cache file location
        let cacheDir = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!
        let appCacheDir = cacheDir.appendingPathComponent("PocketCloudMLX")
        try? FileManager.default.createDirectory(
            at: appCacheDir,
            withIntermediateDirectories: true
        )
        self.cacheFileURL = appCacheDir.appendingPathComponent("hf_metadata_cache.json")

        // Load existing cache
        Task {
            await loadCache()
        }
    }

    /// Load cache from disk
    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            logger.info("No existing metadata cache found")
            return
        }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cache = try decoder.decode([String: CachedModelMetadata].self, from: data)
            logger.info("Loaded \(cache.count) cached model metadata entries")
        } catch {
            logger.error("Failed to load metadata cache: \(error)")
        }
    }

    /// Save cache to disk
    private func saveCache() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(cache)
            try data.write(to: cacheFileURL)
            logger.info("Saved \(cache.count) metadata entries to cache")
            
            // Notify observers that the cache has changed
            NotificationCenter.default.post(name: .huggingFaceMetadataCacheDidChange, object: self)
        } catch {
            logger.error("Failed to save metadata cache: \(error)")
        }
    }

    /// Get metadata for a model
    public func getMetadata(for hubId: String) -> CachedModelMetadata? {
        // Check if cached and not expired
        if let cached = cache[hubId] {
            let daysSinceCached = Calendar.current.dateComponents(
                [.day],
                from: cached.cachedAt,
                to: Date()
            ).day ?? 0

            if daysSinceCached < cacheExpirationDays {
                return cached
            }
        }
        return nil
    }
    
    /// Gets metadata if it's valid in the cache, otherwise fetches it.
    public func getOrFetchMetadata(for hubId: String) async -> CachedModelMetadata? {
        if let cached = getMetadata(for: hubId) {
            return cached
        }
        
        // Not in cache or expired, fetch it
        await updateMetadata(for: hubId)
        
        // Return the newly fetched data
        return cache[hubId]
    }

    /// Store metadata for a model
    public func setMetadata(_ metadata: CachedModelMetadata) {
        cache[metadata.hubId] = metadata
        saveCache()
    }

    /// Update metadata from HuggingFace API
    public func updateMetadata(for hubId: String) async {
        if let lastFailure = missingHubIds[hubId], Date().timeIntervalSince(lastFailure) < missingHubIdRetryInterval {
            logger.debug("Skipping metadata refresh for \(hubId); last not-found recorded \(Date().timeIntervalSince(lastFailure))s ago")
            return
        }

        do {
            logger.info("Fetching metadata for \(hubId)")

            // Prefer the direct model lookup to avoid search filtering that can hide results.
            let model: HuggingFaceModel_Data
            do {
                model = try await HuggingFaceAPI.shared.getModelInfo(modelId: hubId)
            } catch let hfError as HuggingFaceError {
                if case .notFound = hfError {
                    logger.notice("Model \(hubId) not found via direct lookup; attempting relaxed search once.")
                } else {
                    logger.warning("Direct model lookup failed for \(hubId): \(hfError). Falling back to search.")
                }

                let searchResults = try await HuggingFaceAPI.shared.searchModels(query: hubId, limit: 5)
                guard let match = searchResults.first(where: { $0.id.caseInsensitiveCompare(hubId) == .orderedSame }) else {
                    logger.notice("Model \(hubId) still not found after fallback search; recording as missing")
                    missingHubIds[hubId] = Date()
                    return
                }
                model = match
            } catch {
                logger.error("Direct model lookup failed for \(hubId): \(error.localizedDescription)")
                return
            }

            let metadata = CachedModelMetadata.from(model)
            cache[hubId] = metadata
            saveCache()
            logger.info("Updated metadata for \(hubId)")
            missingHubIds.removeValue(forKey: hubId)
        } catch {
            if let hfError = error as? HuggingFaceError, case .notFound = hfError {
                let hours = missingHubIdRetryInterval / 3600
                let formattedHours = String(format: "%.1f", hours)
                logger.notice("Model \(hubId) reported as missing by Hugging Face; suppressing future lookups for \(formattedHours)h")
                missingHubIds[hubId] = Date()
            } else {
                logger.error("Failed to fetch metadata for \(hubId): \(error)")
            }
        }
    }

    /// Batch update metadata for multiple models
    public func batchUpdateMetadata(for hubIds: [String]) async {
        logger.info("Batch updating metadata for \(hubIds.count) models")

        for hubId in hubIds {
            // Add small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            await updateMetadata(for: hubId)
        }

        logger.info("Completed batch metadata update")
    }

    /// Clear expired cache entries
    public func clearExpiredEntries() {
        let expiredIds = cache.filter { _, metadata in
            let daysSinceCached = Calendar.current.dateComponents(
                [.day],
                from: metadata.cachedAt,
                to: Date()
            ).day ?? 0
            return daysSinceCached >= cacheExpirationDays
        }.map { $0.key }

        for id in expiredIds {
            cache.removeValue(forKey: id)
        }

        if !expiredIds.isEmpty {
            logger.info("Cleared \(expiredIds.count) expired metadata entries")
            saveCache()
        }
    }

    /// Clear all cache
    public func clearAll() {
        cache.removeAll()
        try? FileManager.default.removeItem(at: cacheFileURL)
        logger.info("Cleared all metadata cache")
        
        // Notify observers
        NotificationCenter.default.post(name: .huggingFaceMetadataCacheDidChange, object: self)
    }

    /// Get cache statistics
    public func getCacheStats() -> (totalEntries: Int, oldestEntry: Date?, newestEntry: Date?) {
        let dates = cache.values.map { $0.cachedAt }
        return (
            totalEntries: cache.count,
            oldestEntry: dates.min(),
            newestEntry: dates.max()
        )
    }
}
