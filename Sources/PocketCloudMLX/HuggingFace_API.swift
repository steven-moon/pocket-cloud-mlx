// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/HuggingFace_API.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - actor HuggingFaceAPI_Client {
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
import PocketCloudLogger
@preconcurrency import Hub
#if canImport(Security)
import Security
#endif

// For device memory detection
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#endif

#if canImport(MLXLLM)
import MLXLLM
#endif

// MARK: - Hugging Face API Client

/// Hugging Face Hub API client for searching and downloading models
public actor HuggingFaceAPI_Client {
    public static let shared = HuggingFaceAPI_Client()

    private let baseURL = "https://huggingface.co/api"
    private let session: URLSession
    private static let tokenLogger = Logger(label: "HuggingFaceAPI.Token")
    private static let tokenLogTimestampKey = "com.mlxengine.huggingface.lastMissingTokenLog"
    private static let tokenLogFlagKey = "com.mlxengine.huggingface.missingTokenLogged"
    private static let keychainAccount = "PocketCloudMLX-HuggingFace"
    private static let keychainService = "com.mlxengine.huggingface"
    private let responseLogger = Logger(label: "HuggingFaceAPI.Response")

    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300  // 5 minutes
        configuration.timeoutIntervalForResource = 3600  // 1 hour
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true

        // Enable HTTP/2 for better performance
        configuration.httpShouldUsePipelining = true
        configuration.httpMaximumConnectionsPerHost = 6  // Allow multiple concurrent connections

        session = URLSession(configuration: configuration)
    }

    // Helper to get the current token from AppStorage (UserDefaults)
    private func currentToken() -> String? {
        UserDefaults.standard.string(forKey: "huggingFaceToken")
    }

    private func interpretHTTPError(
        response: HTTPURLResponse,
        data: Data?,
        requestDescription: String
    ) -> HuggingFaceError_Type {
        let status = response.statusCode
        let localized = HTTPURLResponse.localizedString(forStatusCode: status)

        let messageFromBody: String? = {
            guard let data, !data.isEmpty else { return nil }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? String, !error.isEmpty { return error }
                if let message = json["message"] as? String, !message.isEmpty { return message }
                if let detail = json["detail"] as? String, !detail.isEmpty { return detail }
            }
            guard let bodyString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !bodyString.isEmpty
            else {
                return nil
            }
            let maxLength = 200
            if bodyString.count > maxLength {
                let prefix = bodyString.prefix(maxLength)
                return String(prefix) + "..."
            }
            return bodyString
        }()

        var composedMessage = "HTTP \(status) \(localized)"
        if let messageFromBody {
            composedMessage += " – \(messageFromBody)"
        }

        if status == 404 {
            responseLogger.notice(
                "HTTP 404 for \(requestDescription): \(composedMessage)"
            )
        } else {
            responseLogger.warning(
                "HTTP failure for \(requestDescription): \(composedMessage)"
            )
        }

        switch status {
        case 401:
            return .unauthorized(messageFromBody ?? "Missing or invalid Hugging Face token")
        case 403:
            return .forbidden(messageFromBody ?? "Access to the repository is forbidden")
        case 404:
            return .notFound(messageFromBody ?? "Requested resource was not found")
        case 429:
            let retryHeader = response.value(forHTTPHeaderField: "Retry-After")
            let retryInterval = retryHeader.flatMap { Double($0) }
            return .rateLimited(retryAfter: retryInterval)
        default:
            if (500...599).contains(status) {
                return .networkError
            }
            return .networkError
        }
    }

    /// Searches for models on Hugging Face Hub with device compatibility filtering
    public func searchModels(query: String, limit: Int = 20) async throws -> [HuggingFaceModel_Data] {
        let logger = Logger(label: "HuggingFaceAPI")
        logger.info(
            "Searching models with query: \(query), limit: \(limit)")
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/models?search=\(encodedQuery)&limit=\(limit)"

        guard let url = URL(string: urlString) else {
            throw HuggingFaceError.invalidURL
        }

        var request = URLRequest(url: url)
        if let token = currentToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HuggingFaceError.networkError
        }

        logger.info("HTTP response status: \(httpResponse.statusCode)")
        guard (200...299).contains(httpResponse.statusCode) else {
            throw interpretHTTPError(
                response: httpResponse,
                data: data,
                requestDescription: "GET /models search"
            )
        }

        // Use JSONDecoder with proper configuration to handle decimal numbers
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        var models = try decoder.decode([HuggingFaceModel_Data].self, from: data)
        logger.info("Models found: \(models.count)")

        // Filter for device compatibility using restored device analyzer
        let deviceAnalyzer = DeviceCompatibilityAnalyzer()
        models = models.filter { model in
            let isCompatible = deviceAnalyzer.isModelCompatible(model)
            if !isCompatible {
                logger.info("❌ Filtered out incompatible model: \(model.id)")
            }
            return isCompatible
        }

        logger.info("✅ Device-compatible models remaining: \(models.count)")

        // Filter for MLX registry compatibility - ensure models are actually supported by MLX
        #if canImport(MLXLLM)
        let mlxRegistryModels = MLXLLM.LLMRegistry.shared.models
        let mlxRegistryIds = Set(mlxRegistryModels.map { String(describing: $0.id) })

        // More permissive filtering - allow MLX-compatible models even if not in official registry
        models = models.filter { model in
            let hfId = model.id.lowercased()

            // Check for exact matches first (highest priority)
            if mlxRegistryIds.contains(model.id) {
                logger.info("✅ Exact MLX Registry match: \(model.id)")
                return true
            }

            // Check for partial matches with MLX Registry (high priority)
            let hasMLXRegistryMatch = mlxRegistryIds.contains { mlxId in
                let mlxIdStr = String(describing: mlxId).lowercased()

                // Remove common prefixes for comparison
                let hfIdClean = hfId.replacingOccurrences(of: "mlx-community/", with: "")
                let mlxIdClean = mlxIdStr.replacingOccurrences(of: "mlx-community/", with: "")

                // Check if either contains the other
                return hfIdClean.contains(mlxIdClean) || mlxIdClean.contains(hfIdClean) ||
                       hfId.contains(mlxIdStr) || mlxIdStr.contains(hfId)
            }

            if hasMLXRegistryMatch {
                logger.info("✅ MLX Registry compatible: \(model.id)")
                return true
            }

            // Check for MLX-compatible characteristics (medium priority) - MORE PERMISSIVE
            let hasMLXTags = model.tags?.contains { tag in
                let lowerTag = tag.lowercased()
                return lowerTag.contains("mlx") || lowerTag.contains("apple") || lowerTag.contains("metal") ||
                       lowerTag.contains("llama") || lowerTag.contains("mistral") || lowerTag.contains("qwen") ||
                       lowerTag.contains("gemma") || lowerTag.contains("phi") || lowerTag.contains("gpt")
            } == true

            let hasMLXInName = hfId.contains("mlx") || hfId.contains("mlx-community") ||
                               hfId.contains("lmstudio-community") || hfId.contains("apple")

            let hasMLXCompatibleArchitecture = model.tags?.contains { tag in
                let lowerTag = tag.lowercased()
                return lowerTag.contains("llama") || lowerTag.contains("mistral") || lowerTag.contains("qwen") ||
                       lowerTag.contains("gemma") || lowerTag.contains("phi") || lowerTag.contains("gpt") ||
                       lowerTag.contains("transformer") || lowerTag.contains("decoder") || lowerTag.contains("encoder")
            } == true

            // Check for quantization tags that indicate MLX compatibility
            let hasMLXQuantization = model.tags?.contains { tag in
                let lowerTag = tag.lowercased()
                return lowerTag.contains("4bit") || lowerTag.contains("8bit") || lowerTag.contains("int4") ||
                       lowerTag.contains("int8") || lowerTag.contains("q4") || lowerTag.contains("q8")
            } == true

            // More permissive: if it has any MLX-compatible characteristics, allow it
            let isMLXCompatible = hasMLXTags || hasMLXInName || hasMLXCompatibleArchitecture || hasMLXQuantization

            if isMLXCompatible {
                logger.info("✅ MLX compatible (characteristics): \(model.id)")
                return true
            }

            // Log why model was filtered out
            logger.info("❌ Filtered out: \(model.id) - no MLX compatibility detected")
            return false
        }
        logger.info("✅ MLX-compatible models remaining: \(models.count)")
        #endif

        return models
    }

    /// Gets detailed information about a specific model
    public func getModelInfo(modelId: String) async throws -> HuggingFaceModel_Data {
        let logger = Logger(label: "HuggingFaceAPI")
        logger.info("Getting model info for: \(modelId)")
        let encodedModelId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "\(baseURL)/models/\(encodedModelId)"

        guard let url = URL(string: urlString) else {
            throw HuggingFaceError.invalidURL
        }

        var request = URLRequest(url: url)
        if let token = currentToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HuggingFaceError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw interpretHTTPError(
                response: httpResponse,
                data: data,
                requestDescription: "GET /models/:id"
            )
        }

        logger.info("HTTP response status: \(httpResponse.statusCode)")
        let model = try JSONDecoder().decode(HuggingFaceModel_Data.self, from: data)
        logger.info("Model info retrieved")
        return model
    }

    /// Lists all files in a Hugging Face model repo using the siblings field.
    public func listModelFiles(modelId: String) async throws -> [String] {
        let metadata = try await listModelFilesDetailed(modelId: modelId)
        let fileNames = metadata.map { $0.fileName }
        let logger = Logger(label: "HuggingFaceAPI")
        logger.info("Model \(modelId) has \(fileNames.count) files: \(fileNames)")
        return fileNames
    }

    /// Retrieves metadata about each file (name, size, hash) for the specified Hugging Face model.
    /// - Parameter modelId: The identifier of the Hugging Face repository (e.g., "mlx-community/llama-3b").
    /// - Returns: An array describing each available file along with the integrity metadata provided by Hugging Face.
    public func listModelFilesDetailed(modelId: String) async throws -> [ModelFileMetadata] {
        let modelInfo = try await getModelInfo(modelId: modelId)
        guard let siblings = modelInfo.siblings else {
            let logger = Logger(label: "HuggingFaceAPI")
            logger.warning("No siblings (file list) found for model: \(modelId)")
            return []
        }
        return siblings.map { $0.toMetadata() }
    }

    /// Downloads a model using the official Hub library (compatible with MLX examples)
    public func downloadModel(
        modelId: String, fileName: String, to destinationURL: URL,
        progress: @Sendable @escaping (Double, Int64, Int64) -> Void
    ) async throws {
        let logger = Logger(label: "HuggingFaceAPI")
        logger.info("🚀 Starting Hub library download for \(fileName) from \(modelId)")

        // Use the official Hub library for downloading
        // Use standard MLX/HF cache (~/.cache/huggingface/hub)
        let token = HuggingFaceAPI_Client.shared.loadHuggingFaceToken()
        let home = FileManager.default.mlxUserHomeDirectory
        let base = home
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub", isDirectory: true)
        let hubApi = HubApi(downloadBase: base, hfToken: token)
        
        // Download the specific file using Hub library
        let repo = Hub.Repo(id: modelId, type: .models)
        
        do {
            // Download the file using Hub library (fast path)
            let downloadedURL = try await hubApi.snapshot(
                from: repo,
                matching: fileName
            )
            // Some Hub implementations yield temporary ".incomplete" paths while finalizing.

            // If that happens or the file is missing, fall back to direct HTTP download.
            let downloadedPath = downloadedURL.path
            let looksIncomplete = downloadedPath.hasSuffix(".incomplete")
            let exists = FileManager.default.fileExists(atPath: downloadedPath)

            if !looksIncomplete && exists,
               let resolvedFileURL = resolveSnapshotFile(downloadedURL, matching: fileName) {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: resolvedFileURL, to: destinationURL)

                // Get file size for progress reporting
                let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                progress(1.0, fileSize, fileSize)
                logger.info("✅ Hub library download completed successfully for \(fileName) (\(fileSize) bytes)")
                return
            }

            // Fallback: direct HTTP download if snapshot result is incomplete/missing
            logger.warning("⚠️ Hub snapshot path not ready (exists=\(exists), incomplete=\(looksIncomplete)); using direct HTTP download for \(fileName)")
            try await downloadFileDirect(modelId: modelId, fileName: fileName, to: destinationURL, progress: progress)

        } catch {
            // If Hub library fails for any reason, try direct HTTP download as a robust fallback
            logger.error("❌ Hub library download failed: \(error.localizedDescription). Falling back to direct HTTP download.")
            try await downloadFileDirect(modelId: modelId, fileName: fileName, to: destinationURL, progress: progress)
        }
    }

    /// Robust direct HTTP download fallback that streams content and moves to destination
    private func downloadFileDirect(
        modelId: String,
        fileName: String,
        to destinationURL: URL,
        progress: @Sendable @escaping (Double, Int64, Int64) -> Void
    ) async throws {
        let logger = Logger(label: "HuggingFaceAPI")
        let encodedModelId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelId
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        let urlString = "https://huggingface.co/\(encodedModelId)/resolve/main/\(encodedFileName)"
        guard let url = URL(string: urlString) else { throw HuggingFaceError_Type.invalidURL }

        // Ensure destination directory exists
        let destDir = destinationURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: destDir.path) {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        }

        // Prepare request with optional auth
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = currentToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Try to fetch size for progress reporting
        var expected: Int64 = 0
        if let size = try? await getFileSize(modelId: modelId, fileName: fileName) {
            expected = size
        }
        progress(0.0, 0, expected)

        let (bytesStream, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HuggingFaceError_Type.networkError
        }

        guard httpResponse.statusCode == 200 else {
            throw interpretHTTPError(
                response: httpResponse,
                data: nil,
                requestDescription: "GET /resolve/main direct"
            )
        }

        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let parentDir = tempFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        FileManager.default.createFile(atPath: tempFileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempFileURL)
        var didMoveFile = false
        defer {
            try? handle.close()
            if !didMoveFile {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }

        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)
        var received: Int64 = 0
        var lastPctEmitted: Double = -1
        var lastUnknownEmissionBytes: Int64 = 0
        let unknownEmissionThreshold: Int64 = 5 * 1024 * 1024

        for try await byte in bytesStream {
            try Task.checkCancellation()
            buffer.append(byte)
            received += 1

            if buffer.count >= 64 * 1024 {
                handle.write(buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if expected > 0 {
                let pct = min(max(Double(received) / Double(expected), 0), 1)
                if pct - lastPctEmitted >= 0.01 {
                    lastPctEmitted = pct
                    progress(pct, received, expected)
                }
            } else if received - lastUnknownEmissionBytes >= unknownEmissionThreshold {
                lastUnknownEmissionBytes = received
                progress(0.0, received, expected)
            }
        }

        if !buffer.isEmpty {
            handle.write(buffer)
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempFileURL, to: destinationURL)
        didMoveFile = true

        let finalExpected = expected > 0 ? expected : received
        progress(1.0, received, finalExpected)
        logger.info("✅ Direct HTTP download completed for \(fileName) (\(received) bytes)")
    }

    /// Resolve the actual file URL returned by the Hub snapshot helper.
    /// Some Hub implementations return a directory that contains the requested file rather than the file itself.
    private func resolveSnapshotFile(_ snapshotURL: URL, matching fileName: String) -> URL? {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: snapshotURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        if !isDirectory.boolValue {
            return snapshotURL
        }

        // First, try resolving the expected relative path components directly.
        let components = fileName.split(separator: "/").map(String.init)
        var candidate = snapshotURL
        for component in components {
            candidate.appendPathComponent(component)
        }
        if fm.fileExists(atPath: candidate.path) {
            return candidate
        }

        // Fall back to searching for the last path component if direct resolution fails.
        if let lastComponent = components.last,
           let enumerator = fm.enumerator(
                at: snapshotURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
           ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == lastComponent {
                    var childIsDirectory: ObjCBool = false
                    if fm.fileExists(atPath: url.path, isDirectory: &childIsDirectory), !childIsDirectory.boolValue {
                        return url
                    }
                }
            }
        }

        return nil
    }

    /// Gets the file size for a model file from Hugging Face (HEAD request)
    public func getFileSize(modelId: String, fileName: String) async throws -> Int64 {
        let encodedModelId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "https://huggingface.co/\(encodedModelId)/resolve/main/\(encodedFileName)"
        guard let url = URL(string: urlString) else {
            throw HuggingFaceError_Type.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        if let token = currentToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HuggingFaceError_Type.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw interpretHTTPError(
                response: httpResponse,
                data: nil,
                requestDescription: "HEAD /resolve/main"
            )
        }
        let totalBytes = httpResponse.expectedContentLength
        return totalBytes > 0 ? totalBytes : 0
    }

    // Platform-safe Hugging Face token loader
    public nonisolated func loadHuggingFaceToken() -> String? {
        Self.tokenLogger.debug("loadHuggingFaceToken() invoked")

        // 1. Prefer in-app token (UserDefaults) so user-set token overrides Keychain/Env
        if let tokenFromDefaults = UserDefaults.standard.string(forKey: "huggingFaceToken"),
           !tokenFromDefaults.isEmpty {
            Self.resetMissingTokenLog()
            Self.tokenLogger.debug("Using token from app settings (UserDefaults)")
            return tokenFromDefaults
        }

        // 2. Try environment variables (useful for CI/CD or CLI)
        let envVars = ["HUGGINGFACE_TOKEN", "HF_TOKEN", "HF_HUB_TOKEN"]
        for envVar in envVars {
            if let token = ProcessInfo.processInfo.environment[envVar], !token.isEmpty {
                Self.resetMissingTokenLog()
                Self.tokenLogger.debug("Using token from environment variable \(envVar)")
                return token
            }
        }
        let joinedEnv = envVars.joined(separator: ", ")
        Self.tokenLogger.debug("No environment token present in \(joinedEnv)")

        // 3. Try Keychain (stored via TokenSetup.swift on macOS)
        if let keychainToken = Self.loadTokenFromKeychain(), !keychainToken.isEmpty {
            Self.resetMissingTokenLog()
            Self.tokenLogger.debug("Using token from Keychain entry \(Self.keychainService)")
            return keychainToken
        }

        // 4. DEBUG/TEST fallback: read from .env file in project root (for local dev & unit tests only)
        let isTestRun = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #if DEBUG
        if let token = loadTokenFromDotEnv() {
            Self.resetMissingTokenLog()
            Self.tokenLogger.debug("Using token from .env (debug/test)")
            return token
        }
        #else
        if isTestRun, let token = loadTokenFromDotEnv() {
            Self.resetMissingTokenLog()
            Self.tokenLogger.debug("Using token from .env (test)")
            return token
        }
        #endif

        if Self.shouldLogMissingToken() {
            Self.tokenLogger.warning("No Hugging Face token configured. Set one in Settings or provide HUGGINGFACE_TOKEN.")
        }
        return nil
    }

    private nonisolated static func loadTokenFromKeychain() -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            if let data = item as? Data,
               let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !token.isEmpty {
                return token
            }
        case errSecItemNotFound:
            Self.tokenLogger.debug("Keychain entry not found for Hugging Face token")
        default:
            Self.tokenLogger.warning("Keychain lookup failed with status: \(status)")
        }
        #endif
        return nil
    }

    // Loads HUGGINGFACE_TOKEN from a nearby .env file (local dev/tests only)
    private nonisolated func loadTokenFromDotEnv() -> String? {
        let fm = FileManager.default
        // Candidate directories: current and up to 5 parents
        var dirs: [String] = []
        var current = fm.currentDirectoryPath
        for _ in 0..<6 {
            dirs.append(current)
            let parent = (current as NSString).deletingLastPathComponent
            if parent == current { break }
            current = parent
        }
        // Also consider a common subfolder name if present
        let candidates = dirs.flatMap { dir -> [String] in
            ["\(dir)/.env", "\(dir)/pocket-cloud-mlx/.env"]
        }
        for path in candidates {
            if fm.fileExists(atPath: path), let data = try? String(contentsOfFile: path, encoding: .utf8) {
                // Parse simple KEY=VALUE lines, ignore comments and whitespace
                for rawLine in data.components(separatedBy: .newlines) {
                    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if line.isEmpty || line.hasPrefix("#") { continue }
                    // Support optional quotes
                    if line.hasPrefix("HUGGINGFACE_TOKEN=") {
                        let valuePart = String(line.dropFirst("HUGGINGFACE_TOKEN=".count))
                        let token = valuePart.trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                        if !token.isEmpty { return token }
                    }
                }
            }
        }
        return nil
    }

    /// Validates a Hugging Face token by calling the whoami endpoint.
    /// Returns the username if valid, or nil if invalid.
    public func validateToken(token: String) async throws -> String? {
        guard !token.isEmpty else { return nil }
        let url = URL(string: "https://huggingface.co/api/whoami-v2")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let user = json["user"] as? [String: Any],
               let name = user["name"] as? String
            {
                return name
            }
            return "(valid, no username)"
        } catch {
            let logger = Logger(label: "HuggingFaceAPI")
            logger.error("Token validation failed: \(error)")
            return nil
        }
    }

    private func validateTokenViaSearch(token: String) async throws -> Bool {
        var request = URLRequest(
            url: URL(string: "https://huggingface.co/api/models?search=mlx&limit=1")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 200
    }
}

// MARK: - Token logging helpers

extension HuggingFaceAPI_Client {
    private nonisolated static func shouldLogMissingToken() -> Bool {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970

        if !defaults.bool(forKey: tokenLogFlagKey) {
            defaults.set(true, forKey: tokenLogFlagKey)
            defaults.set(now, forKey: tokenLogTimestampKey)
            return true
        }

        let last = defaults.double(forKey: tokenLogTimestampKey)
        if last == 0 || (now - last) > 120 {
            defaults.set(now, forKey: tokenLogTimestampKey)
            return true
        }

        return false
    }

    private nonisolated static func resetMissingTokenLog() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: tokenLogFlagKey)
        defaults.removeObject(forKey: tokenLogTimestampKey)
    }
}
