// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/MCPTools.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - protocol MCPTool {
//   - struct MCPToolResult {
//   - protocol MCPResource {
//   - struct MCPResourceContent {
//   - struct MCPFileTool: MCPTool {
//   - struct MCPDirectoryTool: MCPTool {
//
// Living Docs:
//   - Main README: mlx-engine/Documentation/README.md
//   - Integration Roadmap: mlx-engine/Documentation/Internal/Development-Status/mlx-integration-roadmap.md
//   - Theming & Branding Update: mlx-engine/Documentation/Internal/Development-Status/swiftuikit-theming-branding-update.md
//   - Feature Completion: mlx-engine/Documentation/Internal/Development-Status/feature-completion.md
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
import OSLog

// MARK: - MCP Tool Protocol

@MainActor
public protocol MCPTool {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: Any] { get }
    
    @MainActor
    func execute(arguments: [String: Any]) async throws -> MCPToolResult
}

public struct MCPToolResult {
    public let content: String
    public let isError: Bool
    public let metadata: [String: Any]
    
    public init(content: String, isError: Bool = false, metadata: [String: Any] = [:]) {
        self.content = content
        self.isError = isError
        self.metadata = metadata
    }
}

// MARK: - MCP Resource Protocol

@MainActor
public protocol MCPResource {
    var uri: String { get }
    var name: String { get }
    var description: String { get }
    var mimeType: String { get }
    
    @MainActor
    func getContent() async throws -> MCPResourceContent
}

public struct MCPResourceContent {
    public let text: String
    public let mimeType: String
    public let encoding: String
    
    public init(text: String, mimeType: String = "text/plain", encoding: String = "utf-8") {
        self.text = text
        self.mimeType = mimeType
        self.encoding = encoding
    }
}

// MARK: - File System Tools

public struct MCPFileTool: MCPTool {
    public let name = "file_operations"
    public let description = "Read, write, and manipulate files in the workspace"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "operation": [
                "type": "string",
                "enum": ["read", "write", "delete", "exists", "stat"]
            ],
            "path": [
                "type": "string",
                "description": "File path relative to workspace"
            ],
            "content": [
                "type": "string",
                "description": "Content to write (for write operation)"
            ]
        ],
        "required": ["operation", "path"]
    ]
    
    private let logger = Logger(subsystem: "MCPProtocol", category: "MCPFileTool")
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let operation = arguments["operation"] as? String,
              let path = arguments["path"] as? String else {
            throw MCPError.invalidArguments("Missing operation or path")
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        switch operation {
        case "read":
            return try await readFile(at: fileURL)
        case "write":
            guard let content = arguments["content"] as? String else {
                throw MCPError.invalidArguments("Missing content for write operation")
            }
            return try await writeFile(at: fileURL, content: content)
        case "delete":
            return try await deleteFile(at: fileURL)
        case "exists":
            return await checkFileExists(at: fileURL)
        case "stat":
            return try await getFileStat(at: fileURL)
        default:
            throw MCPError.invalidArguments("Unknown operation: \(operation)")
        }
    }
    
    private func readFile(at url: URL) async throws -> MCPToolResult {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            logger.info("Read file: \(url.path)")
            return MCPToolResult(content: content)
        } catch {
            logger.error("Failed to read file \(url.path): \(error)")
            throw MCPError.executionFailed("Failed to read file: \(error.localizedDescription)")
        }
    }
    
    private func writeFile(at url: URL, content: String) async throws -> MCPToolResult {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            logger.info("Wrote file: \(url.path)")
            return MCPToolResult(content: "File written successfully")
        } catch {
            logger.error("Failed to write file \(url.path): \(error)")
            throw MCPError.executionFailed("Failed to write file: \(error.localizedDescription)")
        }
    }
    
    private func deleteFile(at url: URL) async throws -> MCPToolResult {
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Deleted file: \(url.path)")
            return MCPToolResult(content: "File deleted successfully")
        } catch {
            logger.error("Failed to delete file \(url.path): \(error)")
            throw MCPError.executionFailed("Failed to delete file: \(error.localizedDescription)")
        }
    }
    
    private func checkFileExists(at url: URL) async -> MCPToolResult {
        let exists = FileManager.default.fileExists(atPath: url.path)
        return MCPToolResult(content: exists ? "true" : "false")
    }
    
    private func getFileStat(at url: URL) async throws -> MCPToolResult {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let stat: [String: Any] = [
                "size": attributes[.size] as? Int ?? 0,
                "modificationDate": (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0,
                "isDirectory": attributes[.type] as? FileAttributeType == .typeDirectory
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: stat)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            return MCPToolResult(content: jsonString)
        } catch {
            throw MCPError.executionFailed("Failed to get file stat: \(error.localizedDescription)")
        }
    }
}

public struct MCPDirectoryTool: MCPTool {
    public let name = "directory_operations"
    public let description = "List directory contents and manage directories"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "operation": [
                "type": "string",
                "enum": ["list", "create", "delete"]
            ],
            "path": [
                "type": "string",
                "description": "Directory path"
            ]
        ],
        "required": ["operation", "path"]
    ]
    
    private let logger = Logger(subsystem: "MCPProtocol", category: "MCPDirectoryTool")
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let operation = arguments["operation"] as? String,
              let path = arguments["path"] as? String else {
            throw MCPError.invalidArguments("Missing operation or path")
        }
        
        let directoryURL = URL(fileURLWithPath: path)
        
        switch operation {
        case "list":
            return try await listDirectory(at: directoryURL)
        case "create":
            return try await createDirectory(at: directoryURL)
        case "delete":
            return try await deleteDirectory(at: directoryURL)
        default:
            throw MCPError.invalidArguments("Unknown operation: \(operation)")
        }
    }
    
    private func listDirectory(at url: URL) async throws -> MCPToolResult {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
            
            let items = try contents.map { itemURL in
                let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                return [
                    "name": itemURL.lastPathComponent,
                    "path": itemURL.path,
                    "isDirectory": resourceValues.isDirectory ?? false,
                    "size": resourceValues.fileSize ?? 0
                ]
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: items)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            
            return MCPToolResult(content: jsonString)
        } catch {
            throw MCPError.executionFailed("Failed to list directory: \(error.localizedDescription)")
        }
    }
    
    private func createDirectory(at url: URL) async throws -> MCPToolResult {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            logger.info("Created directory: \(url.path)")
            return MCPToolResult(content: "Directory created successfully")
        } catch {
            throw MCPError.executionFailed("Failed to create directory: \(error.localizedDescription)")
        }
    }
    
    private func deleteDirectory(at url: URL) async throws -> MCPToolResult {
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Deleted directory: \(url.path)")
            return MCPToolResult(content: "Directory deleted successfully")
        } catch {
            throw MCPError.executionFailed("Failed to delete directory: \(error.localizedDescription)")
        }
    }
}

public struct MCPSearchTool: MCPTool {
    public let name = "search"
    public let description = "Search for files and content in the workspace"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "query": [
                "type": "string",
                "description": "Search query"
            ],
            "path": [
                "type": "string",
                "description": "Path to search in (optional)"
            ],
            "filePattern": [
                "type": "string",
                "description": "File pattern to match (optional)"
            ]
        ],
        "required": ["query"]
    ]
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let query = arguments["query"] as? String else {
            throw MCPError.invalidArguments("Missing search query")
        }
        
        let searchPath = arguments["path"] as? String ?? "."
        let filePattern = arguments["filePattern"] as? String
        
        return try await searchInFiles(query: query, path: searchPath, pattern: filePattern)
    }
    
    private func searchInFiles(query: String, path: String, pattern: String?) async throws -> MCPToolResult {
        let searchURL = URL(fileURLWithPath: path)
        var results: [[String: Any]] = []
        
        let enumerator = FileManager.default.enumerator(at: searchURL, includingPropertiesForKeys: [.isRegularFileKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
                
                // Check file pattern if provided
                if let pattern = pattern, !fileURL.lastPathComponent.contains(pattern) {
                    continue
                }
                
                // Search file content
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                
                for (lineNumber, line) in lines.enumerated() {
                    if line.localizedCaseInsensitiveContains(query) {
                        results.append([
                            "file": fileURL.path,
                            "line": lineNumber + 1,
                            "content": line.trimmingCharacters(in: .whitespacesAndNewlines)
                        ])
                    }
                }
            } catch {
                // Skip files that can't be read
                continue
            }
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: results)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
        
        return MCPToolResult(content: jsonString)
    }
}

// MARK: - Developer Tools

public struct MCPGitTool: MCPTool {
    public let name = "git"
    public let description = "Git repository operations"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "operation": [
                "type": "string",
                "enum": ["status", "log", "diff", "branch", "commit"]
            ],
            "path": [
                "type": "string",
                "description": "Repository path (optional)"
            ]
        ],
        "required": ["operation"]
    ]
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let operation = arguments["operation"] as? String else {
            throw MCPError.invalidArguments("Missing operation")
        }
        
        let repoPath = arguments["path"] as? String ?? "."
        
        switch operation {
        case "status":
            return try await gitStatus(in: repoPath)
        case "log":
            return try await gitLog(in: repoPath)
        case "diff":
            return try await gitDiff(in: repoPath)
        case "branch":
            return try await gitBranch(in: repoPath)
        default:
            throw MCPError.invalidArguments("Unknown git operation: \(operation)")
        }
    }
    
    private func gitStatus(in path: String) async throws -> MCPToolResult {
        let result = try await runGitCommand(["status", "--porcelain"], in: path)
        return MCPToolResult(content: result)
    }
    
    private func gitLog(in path: String) async throws -> MCPToolResult {
        let result = try await runGitCommand(["log", "--oneline", "-10"], in: path)
        return MCPToolResult(content: result)
    }
    
    private func gitDiff(in path: String) async throws -> MCPToolResult {
        let result = try await runGitCommand(["diff", "--name-only"], in: path)
        return MCPToolResult(content: result)
    }
    
    private func gitBranch(in path: String) async throws -> MCPToolResult {
        let result = try await runGitCommand(["branch", "-a"], in: path)
        return MCPToolResult(content: result)
    }
    
    private func runGitCommand(_ args: [String], in path: String) async throws -> String {
        #if os(macOS)
        let process = Process()
        if #available(macOS 10.13, *) {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        } else {
            process.launchPath = "/usr/bin/git"
            process.currentDirectoryPath = path
        }
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        #else
        // Subprocess execution is not supported on iOS/tvOS/watchOS
        throw MCPError.executionFailed("Git operations are only supported on macOS")
        #endif
    }
}

public struct MCPCodeAnalysisTool: MCPTool {
    public let name = "code_analysis"
    public let description = "Analyze code structure and quality"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "file": [
                "type": "string",
                "description": "File to analyze"
            ],
            "analysis_type": [
                "type": "string",
                "enum": ["structure", "complexity", "dependencies"]
            ]
        ],
        "required": ["file", "analysis_type"]
    ]
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let filePath = arguments["file"] as? String,
              let analysisType = arguments["analysis_type"] as? String else {
            throw MCPError.invalidArguments("Missing file or analysis_type")
        }
        
        switch analysisType {
        case "structure":
            return try await analyzeStructure(file: filePath)
        case "complexity":
            return try await analyzeComplexity(file: filePath)
        case "dependencies":
            return try await analyzeDependencies(file: filePath)
        default:
            throw MCPError.invalidArguments("Unknown analysis type: \(analysisType)")
        }
    }
    
    private func analyzeStructure(file: String) async throws -> MCPToolResult {
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var analysis = [
            "totalLines": lines.count,
            "codeLines": lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count,
            "commentLines": lines.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("//") }.count
        ]
        
        // Basic Swift analysis
        if file.hasSuffix(".swift") {
            analysis["classes"] = lines.filter { $0.contains("class ") }.count
            analysis["structs"] = lines.filter { $0.contains("struct ") }.count
            analysis["functions"] = lines.filter { $0.contains("func ") }.count
            analysis["protocols"] = lines.filter { $0.contains("protocol ") }.count
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: analysis)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPToolResult(content: jsonString)
    }
    
    private func analyzeComplexity(file: String) async throws -> MCPToolResult {
        // Simplified complexity analysis
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        let complexity = [
            "cyclomaticComplexity": calculateCyclomaticComplexity(content: content),
            "nestingDepth": calculateMaxNestingDepth(lines: lines),
            "functionCount": lines.filter { $0.contains("func ") }.count
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: complexity)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPToolResult(content: jsonString)
    }
    
    private func analyzeDependencies(file: String) async throws -> MCPToolResult {
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        let imports = lines.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("import ") }
            .map { $0.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let dependencies: [String: Any] = [
            "imports": imports,
            "count": imports.count
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: dependencies)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPToolResult(content: jsonString)
    }
    
    private func calculateCyclomaticComplexity(content: String) -> Int {
        let keywords = ["if", "else", "for", "while", "switch", "case", "catch", "&&", "||"]
        var complexity = 1 // Base complexity
        
        for keyword in keywords {
            complexity += content.components(separatedBy: keyword).count - 1
        }
        
        return complexity
    }
    
    private func calculateMaxNestingDepth(lines: [String]) -> Int {
        var maxDepth = 0
        var currentDepth = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("{") {
                currentDepth += 1
                maxDepth = max(maxDepth, currentDepth)
            }
            if trimmed.contains("}") {
                currentDepth = max(0, currentDepth - 1)
            }
        }
        
        return maxDepth
    }
}

public struct MCPDocumentationTool: MCPTool {
    public let name = "documentation"
    public let description = "Generate and analyze documentation"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "operation": [
                "type": "string",
                "enum": ["generate", "extract", "validate"]
            ],
            "file": [
                "type": "string",
                "description": "File to process"
            ]
        ],
        "required": ["operation", "file"]
    ]
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let operation = arguments["operation"] as? String,
              let filePath = arguments["file"] as? String else {
            throw MCPError.invalidArguments("Missing operation or file")
        }
        
        switch operation {
        case "generate":
            return try await generateDocumentation(for: filePath)
        case "extract":
            return try await extractDocumentation(from: filePath)
        case "validate":
            return try await validateDocumentation(in: filePath)
        default:
            throw MCPError.invalidArguments("Unknown operation: \(operation)")
        }
    }
    
    private func generateDocumentation(for file: String) async throws -> MCPToolResult {
        // Simple documentation generation
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var documentation = "# Documentation for \(URL(fileURLWithPath: file).lastPathComponent)\n\n"
        
        // Extract public functions and classes
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("public func ") || trimmed.hasPrefix("func ") {
                let funcName = extractFunctionName(from: trimmed)
                documentation += "## \(funcName)\n\nTODO: Add description\n\n"
            } else if trimmed.hasPrefix("public class ") || trimmed.hasPrefix("class ") {
                let className = extractClassName(from: trimmed)
                documentation += "# \(className)\n\nTODO: Add class description\n\n"
            }
        }
        
        return MCPToolResult(content: documentation)
    }
    
    private func extractDocumentation(from file: String) async throws -> MCPToolResult {
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var docComments: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("///") || trimmed.hasPrefix("/**") {
                docComments.append(trimmed)
            }
        }
        
        return MCPToolResult(content: docComments.joined(separator: "\n"))
    }
    
    private func validateDocumentation(in file: String) async throws -> MCPToolResult {
        let content = try String(contentsOfFile: file, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var publicFunctions = 0
        var documentedFunctions = 0
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.hasPrefix("public func ") {
                publicFunctions += 1
                
                // Check if previous line has documentation
                if index > 0 {
                    let prevLine = lines[index - 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if prevLine.hasPrefix("///") {
                        documentedFunctions += 1
                    }
                }
            }
        }
        
        let coverage = publicFunctions > 0 ? Double(documentedFunctions) / Double(publicFunctions) * 100 : 100
        
        let result: [String: Any] = [
            "totalPublicFunctions": publicFunctions,
            "documentedFunctions": documentedFunctions,
            "coveragePercentage": coverage
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: result)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPToolResult(content: jsonString)
    }
    
    private func extractFunctionName(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        for (index, component) in components.enumerated() {
            if component == "func" && index + 1 < components.count {
                let nameWithParams = components[index + 1]
                return nameWithParams.components(separatedBy: "(").first ?? nameWithParams
            }
        }
        return "unknown"
    }
    
    private func extractClassName(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        for (index, component) in components.enumerated() {
            if component == "class" && index + 1 < components.count {
                return components[index + 1].components(separatedBy: ":").first ?? components[index + 1]
            }
        }
        return "unknown"
    }
}

// MARK: - MLX-Specific Tools

public struct MCPModelTool: MCPTool {
    public let name = "mlx_model"
    public let description = "MLX model operations"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "operation": [
                "type": "string",
                "enum": ["list", "load", "unload", "info"]
            ],
            "model_id": [
                "type": "string",
                "description": "Model identifier"
            ]
        ],
        "required": ["operation"]
    ]
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let operation = arguments["operation"] as? String else {
            throw MCPError.invalidArguments("Missing operation")
        }
        
        // This would integrate with the MLX engine
        switch operation {
        case "list":
            return MCPToolResult(content: "[]") // Placeholder
        case "load":
            guard let modelId = arguments["model_id"] as? String else {
                throw MCPError.invalidArguments("Missing model_id")
            }
            return MCPToolResult(content: "Model \(modelId) loaded")
        case "unload":
            return MCPToolResult(content: "Model unloaded")
        case "info":
            return MCPToolResult(content: "{\"status\": \"ready\"}")
        default:
            throw MCPError.invalidArguments("Unknown operation: \(operation)")
        }
    }
}

public struct MCPEmbeddingTool: MCPTool {
    public let name = "embeddings"
    public let description = "Generate embeddings using MLX"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "text": [
                "type": "string",
                "description": "Text to embed"
            ],
            "model": [
                "type": "string",
                "description": "Embedding model to use"
            ]
        ],
        "required": ["text"]
    ]
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard arguments["text"] is String else {
            throw MCPError.invalidArguments("Missing text")
        }
        
        // This would integrate with MLX embedding generation
        // Placeholder implementation
        let embedding = Array(repeating: 0.1, count: 768) // Mock embedding
        
        let result: [String: Any] = [
            "embedding": embedding,
            "dimensions": embedding.count,
            "model": arguments["model"] as? String ?? "default"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: result)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPToolResult(content: jsonString)
    }
}

public struct MCPInferenceTool: MCPTool {
    public let name = "inference"
    public let description = "Run MLX model inference"
    public let inputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "prompt": [
                "type": "string",
                "description": "Input prompt"
            ],
            "model": [
                "type": "string",
                "description": "Model to use for inference"
            ],
            "max_tokens": [
                "type": "integer",
                "description": "Maximum tokens to generate"
            ]
        ],
        "required": ["prompt"]
    ]
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> MCPToolResult {
        guard let prompt = arguments["prompt"] as? String else {
            throw MCPError.invalidArguments("Missing prompt")
        }
        
        // This would integrate with MLX inference
        // Placeholder implementation
        let response = "This is a mock response to: \(prompt)"
        
        let result: [String: Any] = [
            "response": response,
            "model": arguments["model"] as? String ?? "default",
            "tokens_generated": response.split(separator: " ").count
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: result)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPToolResult(content: jsonString)
    }
}

// MARK: - Resources

public struct MCPFileSystemResource: MCPResource {
    public let uri = "filesystem://"
    public let name = "File System"
    public let description = "Access to workspace file system"
    public let mimeType = "application/json"
    
    public init() {}
    
    public func getContent() async throws -> MCPResourceContent {
        let workspaceInfo: [String: Any] = [
            "type": "filesystem",
            "root": FileManager.default.currentDirectoryPath,
            "capabilities": ["read", "write", "list"]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: workspaceInfo)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPResourceContent(text: jsonString, mimeType: "application/json")
    }
}

public struct MCPWorkspaceResource: MCPResource {
    public let uri = "workspace://"
    public let name = "Workspace"
    public let description = "Current workspace information"
    public let mimeType = "application/json"
    
    public init() {}
    
    public func getContent() async throws -> MCPResourceContent {
        let workspaceInfo = [
            "path": FileManager.default.currentDirectoryPath,
            "name": URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent,
            "type": "workspace"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: workspaceInfo)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPResourceContent(text: jsonString, mimeType: "application/json")
    }
}

public struct MCPGitRepositoryResource: MCPResource {
    public let uri = "git://"
    public let name = "Git Repository"
    public let description = "Git repository information"
    public let mimeType = "application/json"
    
    public init() {}
    
    public func getContent() async throws -> MCPResourceContent {
        // Check if we're in a git repository
        let gitDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".git")
        
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            throw MCPError.resourceNotFound("Not a git repository")
        }
        
        let repoInfo: [String: Any] = [
            "isGitRepo": true,
            "path": FileManager.default.currentDirectoryPath,
            "gitDir": gitDir.path
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: repoInfo)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPResourceContent(text: jsonString, mimeType: "application/json")
    }
}

public struct MCPDocumentationResource: MCPResource {
    public let uri = "docs://"
    public let name = "Documentation"
    public let description = "Project documentation"
    public let mimeType = "text/markdown"
    
    public init() {}
    
    public func getContent() async throws -> MCPResourceContent {
        // Look for README files
        let possibleReadmes = ["README.md", "README.txt", "readme.md", "readme.txt"]
        
        for readmeName in possibleReadmes {
            let readmePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(readmeName)
            if FileManager.default.fileExists(atPath: readmePath.path) {
                let content = try String(contentsOf: readmePath, encoding: .utf8)
                return MCPResourceContent(text: content, mimeType: "text/markdown")
            }
        }
        
        throw MCPError.resourceNotFound("No documentation found")
    }
}

public struct MCPModelRegistryResource: MCPResource {
    public let uri = "models://"
    public let name = "Model Registry"
    public let description = "Available MLX models"
    public let mimeType = "application/json"
    
    public init() {}
    
    public func getContent() async throws -> MCPResourceContent {
        // This would integrate with the MLX model registry
        let modelsInfo = [
            "available": [],
            "loaded": [],
            "downloading": []
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: modelsInfo)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return MCPResourceContent(text: jsonString, mimeType: "application/json")
    }
} 