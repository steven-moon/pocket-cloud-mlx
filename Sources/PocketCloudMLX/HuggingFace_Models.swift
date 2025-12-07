// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFace_Models.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct HuggingFaceModel_Data: Codable, Identifiable, Hashable {
//   - struct Sibling: Codable {
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

// MARK: - Core Data Models

/// Hugging Face model information
public struct HuggingFaceModel_Data: Codable, Identifiable, Hashable {
    public let id: String
    public let modelId: String?
    public let author: String?
    public let downloads: Double?
    public let likes: Double?
    public let tags: [String]?
    public let pipeline_tag: String?
    public let createdAt: String?
    public let lastModified: String?
    public let private_: Bool?
    public let gated: Bool?
    public let disabled: Bool?
    public let sha: String?
    public let library_name: String?
    public let safetensors: SafetensorsField?
    public let usedStorage: Double?
    public let trendingScore: Double?
    public let cardData: [String: AnyCodable]?
    public let siblings: [Sibling]?
    public let config: [String: AnyCodable]?
    public let transformersInfo: [String: AnyCodable]?
    public let spaces: [String]?
    public let modelIndex: String?
    public let widgetData: WidgetDataField?

    // Custom decoding to handle decimal numbers for integer fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        modelId = try container.decodeIfPresent(String.self, forKey: .modelId)
        author = try container.decodeIfPresent(String.self, forKey: .author)

        // Handle potential decimal values for numeric fields (preserve precision)
        downloads = try Self.decodeNumber(container, key: .downloads)
        likes = try Self.decodeNumber(container, key: .likes)
        usedStorage = try Self.decodeNumber(container, key: .usedStorage)
        trendingScore = try Self.decodeNumber(container, key: .trendingScore)

        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        pipeline_tag = try container.decodeIfPresent(String.self, forKey: .pipeline_tag)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        lastModified = try container.decodeIfPresent(String.self, forKey: .lastModified)
        private_ = try container.decodeIfPresent(Bool.self, forKey: .private_)
        gated = try container.decodeIfPresent(Bool.self, forKey: .gated)
        disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)
        sha = try container.decodeIfPresent(String.self, forKey: .sha)
        library_name = try container.decodeIfPresent(String.self, forKey: .library_name)
        safetensors = try container.decodeIfPresent(SafetensorsField.self, forKey: .safetensors)
        cardData = try container.decodeIfPresent([String: AnyCodable].self, forKey: .cardData)
        siblings = try container.decodeIfPresent([Sibling].self, forKey: .siblings)
        config = try container.decodeIfPresent([String: AnyCodable].self, forKey: .config)
        transformersInfo = try container.decodeIfPresent([String: AnyCodable].self, forKey: .transformersInfo)
        spaces = try container.decodeIfPresent([String].self, forKey: .spaces)
        modelIndex = try container.decodeIfPresent(String.self, forKey: .modelIndex)
        widgetData = try container.decodeIfPresent(WidgetDataField.self, forKey: .widgetData)
    }

    // Coding keys for custom decoding
    private enum CodingKeys: String, CodingKey {
        case id, modelId, author, downloads, likes, tags, pipeline_tag
        case createdAt, lastModified, private_, gated, disabled, sha, library_name
        case safetensors, usedStorage, trendingScore, cardData, siblings, config
        case transformersInfo, spaces, modelIndex, widgetData
    }

    // Helper function to decode either Int or Double (preserve decimal precision)
    private static func decodeNumber(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double? {
        // First try to decode as Double (preserves decimal precision)
        if let doubleValue = try container.decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }

        // If that fails, try to decode as Int and convert to Double
        if let intValue = try container.decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }

        // If both fail, return nil
        return nil
    }

    public init(
        id: String,
        modelId: String? = nil,
        author: String? = nil,
        downloads: Double? = nil,
        likes: Double? = nil,
        tags: [String]? = nil,
        pipeline_tag: String? = nil,
        createdAt: String? = nil,
        lastModified: String? = nil,
        private_: Bool? = nil,
        gated: Bool? = nil,
        disabled: Bool? = nil,
        sha: String? = nil,
        library_name: String? = nil,
        safetensors: SafetensorsField? = nil,
        usedStorage: Double? = nil,
        trendingScore: Double? = nil,
        cardData: [String: AnyCodable]? = nil,
        siblings: [Sibling]? = nil,
        config: [String: AnyCodable]? = nil,
        transformersInfo: [String: AnyCodable]? = nil,
        spaces: [String]? = nil,
        modelIndex: String? = nil,
        widgetData: WidgetDataField? = nil
    ) {
        self.id = id
        self.modelId = modelId
        self.author = author
        self.downloads = downloads
        self.likes = likes
        self.tags = tags
        self.pipeline_tag = pipeline_tag
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.private_ = private_
        self.gated = gated
        self.disabled = disabled
        self.sha = sha
        self.library_name = library_name
        self.safetensors = safetensors
        self.usedStorage = usedStorage
        self.trendingScore = trendingScore
        self.cardData = cardData
        self.siblings = siblings
        self.config = config
        self.transformersInfo = transformersInfo
        self.spaces = spaces
        self.modelIndex = modelIndex
        self.widgetData = widgetData
    }

    // Custom Equatable/Hashable: only use id
    public static func == (lhs: HuggingFaceModel, rhs: HuggingFaceModel) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Utility: MLX compatibility check
    public func hasMLXFiles() -> Bool {
        // Direct MLX indicators
        if let library = library_name, library.lowercased() == "mlx" { return true }
        if let tags = tags, tags.contains(where: { $0.lowercased() == "mlx" }) { return true }
        if id.lowercased().contains("mlx") { return true }

        // Check for MLX files in siblings
        if let siblings = siblings {
            for sib in siblings {
                if sib.rfilename.lowercased().contains("mlx") { return true }
            }
        }

        // Check for popular model families that are commonly converted to MLX
        // These models are often available in MLX format even if not explicitly tagged
        let popularFamilies = ["llama", "phi", "mistral", "qwen", "gemma", "codellama", "vicuna"]
        let lowercasedId = id.lowercased()

        for family in popularFamilies {
            if lowercasedId.contains(family) {
                // Additional checks to ensure this is likely MLX-compatible
                if let tags = tags {
                    // Check for relevant tags that suggest MLX compatibility
                    let relevantTags = ["text-generation", "instruct", "chat", "safetensors", "gguf"]
                    if relevantTags.contains(where: { tag in
                        tags.contains { $0.lowercased().contains(tag.lowercased()) }
                    }) {
                        return true
                    }
                }

                // Check if it's from a known MLX-friendly organization
                if lowercasedId.contains("mlx-community") ||
                   lowercasedId.contains("lmstudio-community") ||
                   lowercasedId.contains("thebloke") {
                    return true
                }
            }
        }

        return false
    }

    // Utility: Convert to ModelConfiguration (now with metadata extraction)
    public func toModelConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            name: id,
            hubId: id,
            description: "Model from Hugging Face Hub",
            parameters: self.extractParameters(),
            quantization: self.extractQuantization(),
            architecture: self.extractArchitecture(),
            maxTokens: 4096,
            estimatedSizeGB: nil,
            defaultSystemPrompt: nil,
            endOfTextTokens: nil,
            modelType: .llm,  // Default to LLM, can be refined
            gpuCacheLimit: 512 * 1024 * 1024,
            features: []
        )
    }

    // Utility: Extract quantization
    public func extractQuantization() -> String? {
        let name = id.lowercased()
        if name.contains("4bit") || name.contains("q4") { return "4bit" }
        if name.contains("6bit") || name.contains("q6") { return "6bit" }
        if name.contains("8bit") || name.contains("q8") { return "8bit" }
        if name.contains("fp16") { return "fp16" }
        if name.contains("fp32") { return "fp32" }
        if name.contains("bf16") { return "bf16" }
        if let tags = tags {
            for tag in tags {
                if tag.contains("4-bit") || tag.contains("q4") { return "4bit" }
                if tag.contains("6-bit") || tag.contains("q6") { return "6bit" }
                if tag.contains("8-bit") || tag.contains("q8") { return "8bit" }
                if tag.contains("fp16") { return "fp16" }
                if tag.contains("fp32") { return "fp32" }
                if tag.contains("bf16") { return "bf16" }
            }
        }
        return nil
    }

    // Utility: Extract parameters (robust) — returns the largest `<number>B` found to avoid MoE 'A3B' false hits
    public func extractParameters() -> String? {
        var best: Double = 0
        func scan(_ text: String) {
            let lower = text.lowercased()
            let ns = lower as NSString
            let pattern = "([0-9]+(?:\\.[0-9]+)?)\\s*b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: ns.length)
                for m in regex.matches(in: lower, options: [], range: range) {
                    if m.numberOfRanges >= 2 {
                        let val = Double(ns.substring(with: m.range(at: 1))) ?? 0
                        if val > best { best = val }
                    }
                }
            }
        }
        scan(id)
        if let tags = tags { tags.forEach { scan($0) } }
        if best > 0 { return String(format: best.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fB" : "%.1fB", best) }
        return nil
    }

    // Utility: Extract architecture
    public func extractArchitecture() -> String? {
        let name = id.lowercased()
        if name.contains("llama") { return "Llama" }
        if name.contains("qwen") { return "Qwen" }
        if name.contains("mistral") { return "Mistral" }
        if name.contains("phi") { return "Phi" }
        if name.contains("gemma") { return "Gemma" }
        if name.contains("deepseek") { return "DeepSeek" }
        if name.contains("devstral") { return "Devstral" }
        if let tags = tags {
            for tag in tags {
                if tag.lowercased().contains("llama") { return "Llama" }
                if tag.lowercased().contains("qwen") { return "Qwen" }
                if tag.lowercased().contains("mistral") { return "Mistral" }
                if tag.lowercased().contains("phi") { return "Phi" }
                if tag.lowercased().contains("gemma") { return "Gemma" }
                if tag.lowercased().contains("deepseek") { return "DeepSeek" }
                if tag.lowercased().contains("devstral") { return "Devstral" }
            }
        }
        return nil
    }
}

/// File information for model siblings
public struct Sibling: Codable {
    /// Lightweight representation of the `lfs` metadata provided by Hugging Face.
    public struct LFSInfo: Codable {
        public let oid: String?
        public let size: Double?
        public let sha256: String?
        public let pointerSize: Double?
        public let pointerSha256: String?

        public init(
            oid: String? = nil,
            size: Double? = nil,
            sha256: String? = nil,
            pointerSize: Double? = nil,
            pointerSha256: String? = nil
        ) {
            self.oid = oid
            self.size = size
            self.sha256 = sha256
            self.pointerSize = pointerSize
            self.pointerSha256 = pointerSha256
        }

        private enum CodingKeys: String, CodingKey {
            case oid
            case size
            case sha256
            case pointerSize
            case pointerSha256
        }
    }

    public let rfilename: String
    public let size: Double?
    public let sha: String?
    public let lfs: LFSInfo?
    public let securityStatus: String?

    public init(
        rfilename: String,
        size: Double?,
        sha: String? = nil,
        lfs: LFSInfo? = nil,
        securityStatus: String? = nil
    ) {
        self.rfilename = rfilename
        self.size = size
        self.sha = sha
        self.lfs = lfs
        self.securityStatus = securityStatus
    }

    // Custom decoding to preserve decimal precision for size field
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        rfilename = try container.decode(String.self, forKey: .rfilename)

        // Handle potential decimal values for size field (preserve precision)
        if let doubleValue = try? container.decode(Double.self, forKey: .size) {
            size = doubleValue
        } else if let intValue = try? container.decode(Int.self, forKey: .size) {
            size = Double(intValue)
        } else {
            size = nil
        }

        sha = try container.decodeIfPresent(String.self, forKey: .sha)
        lfs = try container.decodeIfPresent(LFSInfo.self, forKey: .lfs)
        securityStatus = try container.decodeIfPresent(String.self, forKey: .securityStatus)
    }

    /// Best-effort conversion of the reported size to a 64-bit integer.
    public var expectedSizeInBytes: Int64? {
        if let size {
            return Int64(size)
        }
        if let lfsSize = lfs?.size {
            return Int64(lfsSize)
        }
        if let pointerSize = lfs?.pointerSize {
            return Int64(pointerSize)
        }
        return nil
    }

    /// Returns the preferred SHA-256 fingerprint, favouring explicit values.
    public var preferredSHA256: String? {
        if let sha = sha, !sha.isEmpty { return sha }
        if let sha256 = lfs?.sha256, !sha256.isEmpty { return sha256 }
        if let pointerSha = lfs?.pointerSha256, !pointerSha.isEmpty { return pointerSha }
        return nil
    }

    // Coding keys for custom decoding
    private enum CodingKeys: String, CodingKey {
        case rfilename
        case size
        case sha
        case lfs
        case securityStatus
    }
}

/// Lightweight struct used by download/verification flows to reason about file integrity expectations.
public struct ModelFileMetadata: Codable, Sendable {
    public let fileName: String
    public let size: Int64?
    public let sha256: String?

    public init(fileName: String, size: Int64?, sha256: String?) {
        self.fileName = fileName
        self.size = size
        self.sha256 = sha256
    }
}

public extension Sibling {
    /// Converts the sibling entry into metadata consumed by downloaders.
    func toMetadata() -> ModelFileMetadata {
        ModelFileMetadata(
            fileName: rfilename,
            size: expectedSizeInBytes,
            sha256: preferredSHA256?.lowercased()
        )
    }
}

/// Generic container for arbitrary JSON values
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let double = try? container.decode(Double.self) {
            // Prioritize Double decoding to handle decimal numbers
            self.value = double
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let uint = try? container.decode(UInt.self) {
            self.value = uint
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self.value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let uint as UInt:
            try container.encode(uint)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(self.value, context)
        }
    }
}

// MARK: - Field Types

/// Safetensors field representation
public enum SafetensorsField: Codable, Sendable {
    case bool(Bool)
    case object([String: AnyCodable])
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let obj = try? container.decode([String: AnyCodable].self) {
            self = .object(obj)
        } else {
            self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try container.encode(b)
        case .object(let obj): try container.encode(obj)
        case .unknown: try container.encodeNil()
        }
    }
}

/// Widget data field representation
public enum WidgetDataField: Codable {
    case dict([String: AnyCodable])
    case array([AnyCodable])
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dict(dict)
        } else if let arr = try? container.decode([AnyCodable].self) {
            self = .array(arr)
        } else {
            self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .dict(let dict): try container.encode(dict)
        case .array(let arr): try container.encode(arr)
        case .unknown: try container.encodeNil()
        }
    }
}

// Swift 6 stricter sendability requires explicit opt-ins for these dynamic model representations.
extension HuggingFaceModel_Data: @unchecked Sendable {}
extension Sibling: @unchecked Sendable {}
extension WidgetDataField: @unchecked Sendable {}
