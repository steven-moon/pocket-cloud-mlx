// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/MCPManager.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class MCPManager: ObservableObject {
//   - struct MCPClient: Identifiable {
//   - struct MCPCapabilities: Codable {
//   - struct MCPMessage: Codable {
//   - enum MCPError: Error, Codable {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
//
// Related Files (heuristic):
//   - mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/MCPTools.swift
//
// Note for AI Agents:
//   - Keep this header accurate. If you rename/move files or change responsibilities,
//     update Key Types and Related Files. Add links to any additional living docs you create.
//   - Prefer tokens from StyleManager for colors/spacing; avoid hardcoded values.
//
// == End LLM Context Header ==
import Foundation
import OSLog

/// Manager for Model Context Protocol (MCP) implementation
/// Based on Cursor's MCP specification for external tool and data source integration
@MainActor
public class MCPManager: ObservableObject {
    private let logger = Logger(subsystem: "MCPProtocol", category: "MCPManager")
    
    @Published public var isServerRunning = false
    @Published public var connectedClients: [MCPClient] = []
    @Published public var availableTools: [MCPTool] = []
    @Published public var availableResources: [MCPResource] = []
    
    private let port: Int
    
    public init(port: Int = 8765) {
        self.port = port
        setupDefaultTools()
        setupDefaultResources()
    }
    
    // MARK: - Server Management
    
    public func startServer() async {
        guard !isServerRunning else {
            logger.warning("MCP server is already running")
            return
        }
        
        // Mock server startup
        isServerRunning = true
        logger.info("Mock MCP server started on port \(self.port)")
    }
    
    public func stopServer() async {
        guard isServerRunning else { return }
        
        isServerRunning = false
        connectedClients.removeAll()
        
        logger.info("Mock MCP server stopped")
    }
    
    // MARK: - Client Management
    
    public func addClient(_ client: MCPClient) {
        connectedClients.append(client)
        logger.info("MCP client connected: \(client.id)")
    }
    
    public func removeClient(_ clientId: String) {
        connectedClients.removeAll { $0.id == clientId }
        logger.info("MCP client disconnected: \(clientId)")
    }
    
    // MARK: - Tool Management
    
    public func registerTool(_ tool: MCPTool) {
        availableTools.append(tool)
        logger.info("Registered MCP tool: \(tool.name)")
    }
    
    public func unregisterTool(_ toolName: String) {
        availableTools.removeAll { $0.name == toolName }
        logger.info("Unregistered MCP tool: \(toolName)")
    }
    
    public func executeTool(_ toolName: String, with arguments: [String: Any]) async throws -> MCPToolResult {
        guard let tool = availableTools.first(where: { $0.name == toolName }) else {
            throw MCPError.toolNotFound(toolName)
        }
        
        logger.info("Executing MCP tool: \(toolName)")
        return try await tool.execute(arguments: arguments)
    }
    
    // MARK: - Resource Management
    
    public func registerResource(_ resource: MCPResource) {
        availableResources.append(resource)
        logger.info("Registered MCP resource: \(resource.uri)")
    }
    
    public func unregisterResource(_ uri: String) {
        availableResources.removeAll { $0.uri == uri }
        logger.info("Unregistered MCP resource: \(uri)")
    }
    
    public func getResource(_ uri: String) async throws -> MCPResourceContent {
        guard let resource = availableResources.first(where: { $0.uri == uri }) else {
            throw MCPError.resourceNotFound(uri)
        }
        
        logger.info("Fetching MCP resource: \(uri)")
        return try await resource.getContent()
    }
    
    // MARK: - Default Setup
    
    private func setupDefaultTools() {
        // File system tools
        registerTool(MCPFileTool())
        registerTool(MCPDirectoryTool())
        registerTool(MCPSearchTool())
        
        // Developer tools
        registerTool(MCPGitTool())
        registerTool(MCPCodeAnalysisTool())
        registerTool(MCPDocumentationTool())
        
        // MLX-specific tools
        registerTool(MCPModelTool())
        registerTool(MCPEmbeddingTool())
        registerTool(MCPInferenceTool())
    }
    
    private func setupDefaultResources() {
        // File system resources
        registerResource(MCPFileSystemResource())
        registerResource(MCPWorkspaceResource())
        
        // Git resources
        registerResource(MCPGitRepositoryResource())
        
        // Documentation resources
        registerResource(MCPDocumentationResource())
        
        // Model resources
        registerResource(MCPModelRegistryResource())
    }
}

// MARK: - MCP Protocol Types

public struct MCPClient: Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let capabilities: MCPCapabilities
    
    public init(id: String, name: String, version: String, capabilities: MCPCapabilities) {
        self.id = id
        self.name = name
        self.version = version
        self.capabilities = capabilities
    }
}

public struct MCPCapabilities: Codable {
    public let roots: Bool
    public let sampling: Bool
    public let tools: Bool
    public let resources: Bool
    public let prompts: Bool
    
    public init(roots: Bool = true, sampling: Bool = true, tools: Bool = true, resources: Bool = true, prompts: Bool = true) {
        self.roots = roots
        self.sampling = sampling
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
    }
}

public struct MCPMessage: Codable {
    public let jsonrpc: String = "2.0"
    public let id: String?
    public let method: String?
    public let params: [String: Any]?
    public let result: [String: Any]?
    public let error: MCPError?
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params, result, error
    }
    
    public init(id: String? = nil, method: String? = nil, params: [String: Any]? = nil, result: [String: Any]? = nil, error: MCPError? = nil) {
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        // Skip complex params/result decoding for now
        params = nil
        result = nil
        error = try container.decodeIfPresent(MCPError.self, forKey: .error)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(method, forKey: .method)
        // Skip complex params/result encoding for now
        try container.encodeIfPresent(error, forKey: .error)
    }
}

public enum MCPError: Error, Codable {
    case toolNotFound(String)
    case resourceNotFound(String)
    case invalidArguments(String)
    case executionFailed(String)
    case unauthorized
    case serverError(String)
    
    public var code: Int {
        switch self {
        case .toolNotFound: return -32601
        case .resourceNotFound: return -32602
        case .invalidArguments: return -32602
        case .executionFailed: return -32603
        case .unauthorized: return -32604
        case .serverError: return -32000
        }
    }
    
    public var message: String {
        switch self {
        case .toolNotFound(let name): return "Tool not found: \(name)"
        case .resourceNotFound(let uri): return "Resource not found: \(uri)"
        case .invalidArguments(let details): return "Invalid arguments: \(details)"
        case .executionFailed(let details): return "Execution failed: \(details)"
        case .unauthorized: return "Unauthorized"
        case .serverError(let details): return "Server error: \(details)"
        }
    }
} 