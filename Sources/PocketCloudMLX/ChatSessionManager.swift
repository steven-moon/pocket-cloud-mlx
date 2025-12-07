// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/ChatSessionManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - protocol ChatSessionProtocol {
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/ChatSession.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import PocketCloudLogger
@preconcurrency import Metal

#if os(iOS)
import UIKit
#endif

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Device Compatibility

/// Simple device compatibility checker for MLX support
private enum MLXDeviceCompatibility {
    private static let logger = Logger(label: "MLXDeviceCompatibility")

    /// Check if the current device supports MLX framework
    static func isMLXCompatible() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #elseif os(iOS)
        // Get device model identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let modelIdentifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Check for iPhone with A14+ (iPhone 12 and newer - iPhone13,x+)
        if modelIdentifier.hasPrefix("iPhone") {
            if let numberRange = modelIdentifier.range(of: "\\d+", options: .regularExpression),
               let majorVersion = Int(modelIdentifier[numberRange]) {
                return majorVersion >= 13
            }
        }

        // Check for iPad with M1/M2 or A14+ (iPad13,x+)
        if modelIdentifier.hasPrefix("iPad") {
            if let numberRange = modelIdentifier.range(of: "\\d+", options: .regularExpression),
               let majorVersion = Int(modelIdentifier[numberRange]) {
                return majorVersion >= 13
            }
        }

        return false
        #elseif os(macOS)
    let modelIdentifier = macHardwareModel()
    let runningUnderRosetta = isRunningUnderRosetta()
    let arm64Capable = hasArm64Capability()
#if arch(arm64)
    let isCompatible = !runningUnderRosetta
#else
    let isCompatible = !runningUnderRosetta && arm64Capable
#endif

        if !isCompatible {
            let architecture: String = {
#if arch(arm64)
                return "arm64"
#elseif arch(x86_64)
                return "x86_64"
#else
                return "unknown"
#endif
            }()

            logger.error(
                "MLX unavailable on current Mac configuration",
                context: Logger.Context([
                    "model": modelIdentifier,
                    "arch": architecture,
                    "rosetta": String(runningUnderRosetta),
                    "arm64_capable": String(arm64Capable)
                ])
            )
        }

        return isCompatible
        #else
        return false
        #endif
    }

    private static func macHardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return model.withUnsafeBufferPointer { buffer -> String in
            guard let base = buffer.baseAddress else { return "unknown" }
            return base.withMemoryRebound(to: UInt8.self, capacity: buffer.count) {
                String(decodingCString: $0, as: UTF8.self)
            }
        }
    }

    private static func hasArm64Capability() -> Bool {
        var arm64Capability: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &arm64Capability, &size, nil, 0)
        return result == 0 && arm64Capability == 1
    }

    private static func isRunningUnderRosetta() -> Bool {
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0)
        return result == 0 && translated == 1
    }
}

/// Protocol for chat sessions (both real and mock)
public protocol ChatSessionProtocol {
    func generateResponse(_ prompt: String) async throws -> String
    func generateStream(prompt: String, parameters: GenerateParams) async throws -> AsyncThrowingStream<String, any Error>
    func close()
}

/// Mock ChatSession for simulator testing
/// This prevents MLX framework crashes while providing the same interface
public final class MockChatSession: ChatSessionProtocol {
    private let logger = Logger(label: "MockChatSession")
    private let modelConfiguration: ModelConfiguration

    public init(modelConfiguration: ModelConfiguration) {
        self.modelConfiguration = modelConfiguration
        logger.info("🎭 MockChatSession initialized for model: \(modelConfiguration.name)")
    }

    public func generateResponse(_ prompt: String) async throws -> String {
        logger.info("🎭 Mock response generated for prompt: \(prompt)")
        return "Hello! I'm running in simulator mode. This is a mock response from \(modelConfiguration.name). Real MLX models can't load here, but the chat interface works perfectly for testing UI functionality! 🚀"
    }

    public func generateStream(prompt: String, parameters: GenerateParams = .init()) async throws -> AsyncThrowingStream<String, any Error> {
        logger.info("🎭 Mock stream generated for prompt: \(prompt)")

        let modelName = modelConfiguration.name
        return AsyncThrowingStream<String, any Error> { continuation in
            Task {
                do {
                    let mockResponse = "Hello! I'm running in simulator mode. This is a mock streaming response from \(modelName). Real MLX models can't load here, but the chat interface works perfectly for testing UI functionality! 🚀"

                    // Simulate streaming by sending chunks
                    let words = mockResponse.split(separator: " ")
                    for (index, word) in words.enumerated() {
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                        continuation.yield(String(word) + (index < words.count - 1 ? " " : ""))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func close() {
        logger.info("🎭 MockChatSession closed")
    }
}

/// Singleton manager for ChatSession instances to prevent race conditions
/// and ensure only one model is loaded at a time
public final class ChatSessionManager: @unchecked Sendable {
    public static let shared = ChatSessionManager()

    private let logger = Logger(label: "ChatSessionManager")
    private var currentSession: ChatSessionProtocol?
    private var currentModelConfiguration: ModelConfiguration?
    private var isLoading = false
    private let loadingLock = NSLock()

    // Queue for serializing session operations
    private let sessionQueue = DispatchQueue(label: "com.mlxengine.chatsessionmanager", qos: .userInitiated)

    private init() {
        logger.info("🚀 ChatSessionManager initialized")
    }

    /// Gets the current active session
    public func getCurrentSession() -> ChatSessionProtocol? {
        return sessionQueue.sync { currentSession }
    }

    /// Gets the current model configuration
    public func getCurrentModel() -> ModelConfiguration? {
        return sessionQueue.sync { currentModelConfiguration }
    }

    /// Checks if a model is currently loading
    public func isModelLoading() -> Bool {
        return loadingLock.withLock { isLoading }
    }

    /// Switches to a new model, unloading the current one if different
    /// - Parameters:
    ///   - modelConfiguration: The model to switch to
    ///   - metalLibrary: Optional Metal library for GPU operations
    /// - Returns: The new ChatSession
    /// - Throws: Initialization errors
    public func switchToModel(_ modelConfiguration: ModelConfiguration, metalLibrary: MTLLibrary? = nil) async throws -> ChatSessionProtocol {
        // On simulator, return a mock session to prevent MLX crashes
        #if targetEnvironment(simulator)
            return try await switchToSimulatorMockModel(modelConfiguration)
        #else
            return try await switchToRealModel(modelConfiguration, metalLibrary: metalLibrary)
        #endif
    }

    /// Simulator-safe model switching that returns mock sessions
    private func switchToSimulatorMockModel(_ modelConfiguration: ModelConfiguration) async throws -> ChatSessionProtocol {
        return sessionQueue.sync {
            // Check if this is the same model
            if let current = currentModelConfiguration, current.hubId == modelConfiguration.hubId {
                logger.info("✅ Same simulator mock model already loaded: \(modelConfiguration.name)")
                if let session = currentSession {
                    return session
                }
            }

            logger.info("🔄 Switching to simulator mock model: \(modelConfiguration.name)")

            // Create mock session for simulator
            let mockSession = MockChatSession(modelConfiguration: modelConfiguration)

            // Update state
            currentSession = mockSession
            currentModelConfiguration = modelConfiguration

            logger.info("✅ Successfully loaded simulator mock model: \(modelConfiguration.name)")
            return mockSession
        }
    }

    /// Real model switching for physical devices
    private func switchToRealModel(_ modelConfiguration: ModelConfiguration, metalLibrary: MTLLibrary? = nil) async throws -> ChatSessionProtocol {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ChatSessionProtocol, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "ChatSessionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Manager deallocated"]))
                    return
                }

                Task {
                    do {
                        // Check device compatibility first
                        guard MLXDeviceCompatibility.isMLXCompatible() else {
                            let error = LLMEngineError.deviceNotSupported(
                                message: "This device does not support MLX. MLX requires Apple Silicon (A14+ on iOS/iPadOS, M1+ on macOS)."
                            )
                            self.logger.error("❌ Device not compatible with MLX")
                            continuation.resume(throwing: error)
                            return
                        }

                        // Check if we're already loading
                        if self.loadingLock.withLock({ self.isLoading }) {
                            self.logger.info("ℹ️ Model loading already in progress, waiting…")
                            // Wait for current loading to complete
                            while self.loadingLock.withLock({ self.isLoading }) {
                                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                            }
                        }

                        // Check if this is the same model
                        if let current = self.currentModelConfiguration, current.hubId == modelConfiguration.hubId {
                            self.logger.info("✅ Same model already loaded: \(modelConfiguration.name)")
                            if let session = self.currentSession {
                                continuation.resume(returning: session)
                                return
                            }
                        }

                        // Start loading new model
                        self.loadingLock.withLock { self.isLoading = true }
                        defer { self.loadingLock.withLock { self.isLoading = false } }

                        self.logger.info("🔄 Switching to model: \(modelConfiguration.name)")

                        // Clean up current session
                        self.currentSession = nil
                        self.currentModelConfiguration = nil

                        let newSession: ChatSessionProtocol
#if canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLX)
                        if modelConfiguration.supportsVision && modelConfiguration.supportsChat {
                            self.logger.info("🔀 Using vision-language chat session for model: \(modelConfiguration.name)")
                            newSession = try await VisionLanguageChatSession.create(
                                modelConfiguration: modelConfiguration
                            )
                        } else {
                            newSession = try await ChatSession.create(
                                modelConfiguration: modelConfiguration,
                                metalLibrary: metalLibrary
                            )
                        }
#else
                        newSession = try await ChatSession.create(
                            modelConfiguration: modelConfiguration,
                            metalLibrary: metalLibrary
                        )
#endif

                        // Update state
                        self.currentSession = newSession
                        self.currentModelConfiguration = modelConfiguration

                        self.logger.info("✅ Successfully switched to model: \(modelConfiguration.name)")
                        continuation.resume(returning: newSession)

                    } catch {
                        self.logger.error("❌ Failed to switch model: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Ensures a session is available for the given model
    /// - Parameters:
    ///   - modelConfiguration: The model configuration
    ///   - metalLibrary: Optional Metal library
    /// - Returns: Active ChatSession for the model
    /// - Throws: Session creation errors
    public func ensureSession(for modelConfiguration: ModelConfiguration, metalLibrary: MTLLibrary? = nil) async throws -> ChatSessionProtocol {
        if let currentSession = getCurrentSession(),
           let currentModel = getCurrentModel(),
           currentModel.hubId == modelConfiguration.hubId {
            logger.info("✅ Using existing session for model: \(modelConfiguration.name)")
            return currentSession
        }

        logger.info("🔄 Creating new session for model: \(modelConfiguration.name)")
        return try await switchToModel(modelConfiguration, metalLibrary: metalLibrary)
    }

    /// Clears the current session
    public func clearSession() {
        sessionQueue.async { [weak self] in
            self?.currentSession = nil
            self?.currentModelConfiguration = nil
            self?.logger.info("🧹 Session cleared")
        }
    }

    /// Gets session statistics
    public func getSessionStats() -> [String: Any] {
        return sessionQueue.sync {
            var stats: [String: Any] = [
                "hasSession": currentSession != nil,
                "isLoading": loadingLock.withLock({ isLoading })
            ]

            if let model = currentModelConfiguration {
                stats["currentModel"] = model.name
                stats["modelId"] = model.hubId
            }

            // Note: getStats() is not available in ChatSessionProtocol
            // We'll just note that a session exists
            if currentSession != nil {
                stats["sessionType"] = "ChatSessionProtocol"
            }

            return stats
        }
    }

    /// Forces cleanup of resources
    public func cleanup() {
        logger.info("🧹 Cleaning up ChatSessionManager")
        clearSession()
    }
}
