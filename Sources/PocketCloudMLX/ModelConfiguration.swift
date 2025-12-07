import Foundation

extension ModelConfiguration: Identifiable {
    public var id: String { hubId }
}

extension ModelConfiguration: Hashable {
    public static func == (lhs: ModelConfiguration, rhs: ModelConfiguration) -> Bool {
        lhs.hubId == rhs.hubId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hubId)
    }
}

public extension ModelConfiguration {
    /// Convenience helper to return a copy of the configuration.
    func makeCopy() -> ModelConfiguration { self }

    /// Placeholder metadata support maintained for compatibility with callers.
    var metadata: CachedModelMetadata? {
        get { nil }
        set { _ = newValue }
    }

        var lastModified: String? { metadata?.lastModified }
        var createdAt: String? { metadata?.createdAt }
}