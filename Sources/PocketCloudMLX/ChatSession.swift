// == LLM Context: Bread Crumbs ==
// Module        : PocketCloudMLX
// File          : pocket-cloud-mlx/Sources/PocketCloudMLX/ChatSession.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ChatMessage: Codable, Sendable, Equatable {
//
// Living Docs:
//   - Main README: pocket-cloud-mlx/Documentation/README.md
//   - Integration Roadmap: pocket-cloud-mlx/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: pocket-cloud-mlx/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: pocket-cloud-mlx/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - pocket-cloud-mlx/Sources/PocketCloudMLX/ChatSessionManager.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import PocketCloudLogger
import Metal

#if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
  import MLX
  import MLXLLM
  import MLXLMCommon
#endif

/// Chat message with role and content
public struct ChatMessage: Codable, Sendable, Equatable {
  public enum Role: String, Codable, Sendable {
    case system, user, assistant
  }

  public let id: UUID
  public let role: Role
  public let content: String
  public let timestamp: Date

  public init(role: Role, content: String, timestamp: Date = Date()) {
    self.id = UUID()
    self.role = role
    self.content = content
    self.timestamp = timestamp
  }
}

// MARK: - Chat Session

/// Chat session for conversational interactions
public final class ChatSession: @unchecked Sendable, ChatSessionProtocol {
  // MARK: - Properties
  
  private let logger = Logger(label: "ChatSession")
  
  /// Model configuration for this session
  public let modelConfiguration: ModelConfiguration
  
  /// Optional Metal library for GPU operations
  public let metalLibrary: MTLLibrary?
  
  /// InferenceEngine for actual text generation
  private var inferenceEngine: InferenceEngineFacade?
  
  /// Chat message history
  private var messages: [ChatMessage] = []
  
  /// Store for message persistence (legacy support)
  private var store: [ChatMessage] = []
  
  /// Session initialization status
  private var isInitialized = false
  
  /// Intelligent help system for app-specific queries
  private let helpSystem: HelpSystem?

  // MARK: - Initialization

  /// Private initializer - use create(modelConfiguration:metalLibrary:) instead
  private init(modelConfiguration: ModelConfiguration, metalLibrary: MTLLibrary?) {
    self.modelConfiguration = modelConfiguration
    self.metalLibrary = metalLibrary
    
    // Initialize help system (gracefully handle errors)
    do {
      let helpSystem = try HelpSystem()
      self.helpSystem = helpSystem
      if helpSystem.isEnabled {
        logger.info("✅ Help system initialized")
      } else {
        logger.notice("ℹ️ Help system disabled; documentation artifacts not bundled.")
      }
    } catch {
      self.helpSystem = nil
      #if DEBUG
      logger.warning("⚠️ Help system failed to initialize: \(error)")
      #else
      logger.debug("Help system unavailable (development docs not bundled)")
      #endif
    }
  }

  /// Creates a new chat session with the specified model configuration
  /// - Parameters:
  ///   - modelConfiguration: Configuration for the model to load
  ///   - metalLibrary: Optional Metal library for GPU operations
  /// - Returns: Initialized ChatSession
  /// - Throws: Initialization errors
  public static func create(
    modelConfiguration: ModelConfiguration,
    metalLibrary: MTLLibrary? = nil
  ) async throws -> ChatSession {
    let session = ChatSession(
      modelConfiguration: modelConfiguration,
      metalLibrary: metalLibrary
    )
    try await session.initialize()
    return session
  }

  /// Initializes the chat session by loading the inference engine
  private func initialize() async throws {
    logger.info("🚀 Initializing chat session with model: \(modelConfiguration.name)")
    
    // Proactively verify and repair the model before attempting to load
    logger.info("🔍 Running proactive model verification before session creation")
    let downloader = OptimizedDownloader()

    do {
      let modelVerified = try await downloader.verifyAndRepairModel(modelConfiguration)
      if modelVerified {
        logger.info("✅ Model verification passed, proceeding with session creation")
      } else {
        logger.warning("⚠️ Model verification detected issues, but proceeding anyway")
      }
    } catch {
      logger.error("❌ Model verification failed: \(error.localizedDescription)")
      logger.warning("⚠️ Proceeding with session creation despite verification failure")

      // If verification failed, try a forced redownload as last resort
      do {
        logger.info("🔄 Attempting forced redownload as recovery...")
        let downloader = OptimizedDownloader()
        let redownloadSuccess = try await downloader.forceRedownloadAndRepair(modelConfiguration) { [weak self] status in
          self?.logger.info("Recovery: \(status)")
        }

        if redownloadSuccess {
          logger.info("✅ Recovery successful, model redownloaded")
          // Try verification again after redownload
          let finalVerification = try await downloader.verifyAndRepairModel(modelConfiguration)
          if finalVerification {
            logger.info("✅ Model verified after recovery")
          }
        } else {
          logger.warning("⚠️ Recovery failed, session may not work properly")
        }
      } catch {
        logger.error("❌ Recovery also failed: \(error.localizedDescription)")
      }
    }
    
    // Load the inference engine
    inferenceEngine = try await InferenceEngineFacade.loadModel(modelConfiguration) { [weak self] progress in
      self?.logger.info("Loading model progress: \(Int(progress * 100))%")
    }
    
    // Add system message if provided
    if let systemPrompt = modelConfiguration.defaultSystemPrompt {
      addMessage(ChatMessage(role: .system, content: systemPrompt))
    }
    
    isInitialized = true
    logger.info("✅ Chat session initialized successfully")
  }

  /// Adds a message to the chat history
  /// - Parameter message: Message to add
  public func addMessage(_ message: ChatMessage) {
    messages.append(message)
    store.append(message)  // Legacy support
  }

  // MARK: - Text Generation

  /// Generates a response to the given prompt
  /// - Parameters:
  ///   - prompt: Input prompt
  ///   - parameters: Generation parameters
  /// - Returns: Generated text response
  /// - Throws: Generation errors
  public func generate(prompt: String, parameters: GenerateParams = .init()) async throws -> String {
    guard isInitialized else {
      throw LLMEngineError.notInitialized
    }

    logger.info("🤖 Generating response for prompt: \(prompt.prefix(50))...")

    // Check if this is a help query first
    if let helpSystem = helpSystem, helpSystem.isHelpQuery(prompt) {
      logger.info("🆘 Processing help query")
      let helpResponse = await helpSystem.processHelpQuery(prompt)
      
      // Add messages to history
      addMessage(ChatMessage(role: .user, content: prompt))
      addMessage(ChatMessage(role: .assistant, content: helpResponse.answer))
      
      logger.info("✅ Help response generated (confidence: \(helpResponse.confidence))")
      return helpResponse.answer
    }
    
    guard let engine = inferenceEngine else {
      throw LLMEngineError.notInitialized
    }

    // Log generation start
    logger.info("🤖 Generating response for prompt: \(prompt.prefix(50))...")
    // Prepare the full conversation context
    let fullPrompt = prepareInput(prompt: prompt)
    
    // Generate response using the inference engine
    let response = try await engine.generate(fullPrompt, params: parameters)

    // Add messages to history
    addMessage(ChatMessage(role: .user, content: prompt))
    addMessage(ChatMessage(role: .assistant, content: response))

    logger.info("✅ Response generated successfully")
    return response
  }

  /// Generates a streaming response to the given prompt
  /// - Parameters:
  ///   - prompt: Input prompt
  ///   - parameters: Generation parameters
  /// - Returns: Async stream of generated text chunks
  /// - Throws: Generation errors
  public func generateStream(prompt: String, parameters: GenerateParams = .init()) async throws
    -> AsyncThrowingStream<String, Error>
  {
    guard isInitialized else {
      throw LLMEngineError.notInitialized
    }
    
    guard let engine = inferenceEngine else {
      throw LLMEngineError.notInitialized
    }

    logger.info("🌊 Starting streaming generation for prompt: \(prompt.prefix(50))...")

    // Check if this is a help query first
    if let helpSystem = helpSystem, helpSystem.isHelpQuery(prompt) {
      return AsyncThrowingStream { continuation in
        Task {
          logger.info("🆘 Processing help query in streaming mode")
          let helpResponse = await helpSystem.processHelpQuery(prompt)
          
          // Add messages to history
          addMessage(ChatMessage(role: .user, content: prompt))
          addMessage(ChatMessage(role: .assistant, content: helpResponse.answer))
          
          // Stream the help response word by word for better UX
          let words = helpResponse.answer.components(separatedBy: " ")
          for word in words {
            continuation.yield(word + " ")
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay for natural streaming
          }
          
          continuation.finish()
          logger.info("✅ Help response streamed (confidence: \(helpResponse.confidence))")
        }
      }
    }

    // Prepare the full conversation context
    let fullPrompt = prepareInput(prompt: prompt)
    
    return AsyncThrowingStream { continuation in
      Task {
        do {
          // Add user message to history immediately
          addMessage(ChatMessage(role: .user, content: prompt))
          
          var fullResponse = ""
          
          // Stream response using the inference engine
          for try await chunk in engine.stream(fullPrompt, params: parameters) {
            fullResponse += chunk
            continuation.yield(chunk)
          }

          // Add assistant message to history
          addMessage(ChatMessage(role: .assistant, content: fullResponse))

          continuation.finish()
          logger.info("✅ Streaming generation completed")

        } catch {
          continuation.finish(throwing: error)
          logger.error("❌ Streaming generation failed: \(error)")
        }
      }
    }
  }

  /// Prepares input by combining prompt with chat history
  /// - Parameter prompt: Current prompt
  /// - Returns: Combined input text
  private func prepareInput(prompt: String) -> String {
    var input = ""

    // Add chat history
    for message in messages {
      switch message.role {
      case .system:
        input += "System: \(message.content)\n"
      case .user:
        input += "User: \(message.content)\n"
      case .assistant:
        input += "Assistant: \(message.content)\n"
      }
    }

    // Add current prompt
    if !prompt.isEmpty {
      input += "User: \(prompt)\n"
    }

    input += "Assistant: "
    return input
  }

  /// Gets the current chat history
  /// - Returns: Array of chat messages
  public func getHistory() -> [ChatMessage] {
    return messages
  }

  /// Gets session statistics
  /// - Returns: Dictionary with session information
  public func getStats() -> [String: Any] {
    return [
      "modelId": modelConfiguration.hubId,
      "modelType": modelConfiguration.modelType.rawValue,
      "messageCount": messages.count,
      "isInitialized": isInitialized,
      "hasMetalLibrary": metalLibrary != nil,
      "maxSequenceLength": modelConfiguration.maxTokens,
      "maxCacheSize": modelConfiguration.gpuCacheLimit,
    ]
  }

  /// Stream response method (legacy support for app compatibility)
  public func streamResponse(_ prompt: String) -> AsyncThrowingStream<String, Error> {
    return AsyncThrowingStream { continuation in
      Task {
        do {
          // Use the new generateStream method
          for try await chunk in try await generateStream(prompt: prompt) {
            continuation.yield(chunk)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  // MARK: - Legacy API Support

  /// Compatibility property for message count
  public var messageCount: Int { 
    return messages.count 
  }

  /// Compatibility property for last message
  public var lastMessage: ChatMessage? { 
    return messages.last 
  }

  /// Compatibility property for conversation history
  public var conversationHistory: [ChatMessage] { 
    return messages 
  }

  /// Legacy addMessage method for backward compatibility
  public func addMessage(_ role: ChatMessage.Role, content: String) async {
    addMessage(ChatMessage(role: role, content: content))
  }

  /// Legacy generateResponse method for backward compatibility
  public func generateResponse(_ prompt: String) async throws -> String {
    return try await generate(prompt: prompt)
  }

  /// Legacy removeLastMessage method for backward compatibility
  public func removeLastMessage() {
    if !messages.isEmpty {
      messages.removeLast()
      if !store.isEmpty {
        store.removeLast()
      }
    }
  }

  /// Legacy clearHistory method for backward compatibility
  public func clearHistory() async {
    messages.removeAll()
    store.removeAll()
  }

  /// Legacy exportConversation method for backward compatibility
  public func exportConversation() -> String {
    return messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
  }

  /// Legacy testSession method for testing
  public static func testSession() async -> ChatSession {
    let config = ModelConfiguration(
      name: "Qwen1.5 Test",
      hubId: "mlx-community/Qwen1.5-0.5B-Chat-4bit",
      description: "Qwen1.5 0.5B model for testing",
      maxTokens: 4096,
      modelType: .llm,
      gpuCacheLimit: 512 * 1024 * 1024,
      features: []
    )
    
    // Proactively verify and repair the model before attempting to create session
    AppLogger.shared.info("ChatSession", "🔍 Running proactive model verification before session creation")
    let downloader = OptimizedDownloader()

    do {
      let modelVerified = try await downloader.verifyAndRepairModel(config)
      if modelVerified {
        AppLogger.shared.info("ChatSession", "✅ Model verification passed, proceeding with session creation")
      } else {
        AppLogger.shared.warning("ChatSession", "⚠️ Model verification detected issues, but proceeding anyway")
      }
    } catch {
      AppLogger.shared.error("ChatSession", "❌ Model verification failed: \(error.localizedDescription)")
      AppLogger.shared.warning("ChatSession", "⚠️ Proceeding with session creation despite verification failure")

      // If verification failed, try a forced redownload as last resort
      do {
        AppLogger.shared.info("ChatSession", "🔄 Attempting forced redownload as recovery...")
        let downloader = OptimizedDownloader()
        let redownloadSuccess = try await downloader.forceRedownloadAndRepair(config) { status in
          AppLogger.shared.info("ChatSession", "Recovery: \(status)")
        }

        if redownloadSuccess {
          AppLogger.shared.info("ChatSession", "✅ Recovery successful, model redownloaded")
          // Try verification again after redownload
          let finalVerification = try await downloader.verifyAndRepairModel(config)
          if finalVerification {
            AppLogger.shared.info("ChatSession", "✅ Model verified after recovery")
          }
        } else {
          AppLogger.shared.warning("ChatSession", "⚠️ Recovery failed, session may not work properly")
        }
      } catch {
        AppLogger.shared.error("ChatSession", "❌ Recovery also failed: \(error.localizedDescription)")
      }
    }

    // Create a session and properly initialize it for tests
    do {
      let session = try await ChatSession.create(
        modelConfiguration: config,
        metalLibrary: nil
      )
      return session
    } catch {
      // If creation fails, create a minimal session for testing
      let session = ChatSession(modelConfiguration: config, metalLibrary: nil)
      session.isInitialized = true
      return session
    }
  }

  /// Close the chat session and clean up resources
  public func close() {
    logger.info("Closing chat session for model: \(modelConfiguration.name)")
    // Clean up any resources if needed
    // Note: MLX cleanup happens automatically when the session is deallocated
  }
}
