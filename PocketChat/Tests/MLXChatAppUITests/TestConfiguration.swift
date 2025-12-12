// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Tests/MLXChatAppUITests/TestConfiguration.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct TestConfiguration {
//   - struct TestModel {
//   - struct TestAdapter {
//   - enum AdapterCategory: String {
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

/// Test configuration for MLX Chat App advanced features tests
struct TestConfiguration {
    /// Shared instance
    static let shared = TestConfiguration()

    /// HuggingFace API token (loaded from secure location)
    let huggingFaceToken: String?

    /// Whether to run real model download tests
    let shouldRunRealModelTests: Bool

    /// Test models to use for testing
    let testModels: [TestModel]

    /// LoRA adapters to test with
    let testAdapters: [TestAdapter]

    /// Test timeout duration
    let testTimeout: TimeInterval = 300 // 5 minutes

    private init() {
        // Load HuggingFace token securely
        huggingFaceToken = Self.loadHuggingFaceToken()

        // Check if real model tests should run (DEFAULT: ALWAYS RUN REAL TESTS)
        // Only disable if explicitly requested via environment variable
        let forceMockTests = ProcessInfo.processInfo.environment["FORCE_MOCK_TESTS"] == "true"
        let ciMode = ProcessInfo.processInfo.environment["CI"] == "true"
        shouldRunRealModelTests = !forceMockTests || ciMode

        // Log the test configuration for debugging
        print("🔧 [TEST CONFIG] Real model tests: \(shouldRunRealModelTests)")
        print("🔧 [TEST CONFIG] Force mock tests: \(forceMockTests)")
        print("🔧 [TEST CONFIG] CI mode: \(ciMode)")
        print("🔧 [TEST CONFIG] HuggingFace token available: \(huggingFaceToken != nil)")

        // Configure test models
        testModels = Self.configureTestModels()

        // Configure test adapters
        testAdapters = Self.configureTestAdapters()
    }

    // MARK: - Private Methods

    private static func loadHuggingFaceToken() -> String? {
        // Try multiple secure locations for the token

        // 1. Environment variable (most secure for CI/CD)
        if let envToken = ProcessInfo.processInfo.environment["HUGGINGFACE_TOKEN"] {
            return envToken
        }

        // 2. Secure file in project directory (for local development)
        let tokenFile = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("huggingface_token.txt")

        if let tokenData = try? Data(contentsOf: tokenFile),
           let token = String(data: tokenData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }

        // 3. macOS Keychain (most secure for local development)
        #if os(macOS)
        return loadTokenFromKeychain()
        #endif

        return nil
    }

    #if os(macOS)
    private static func loadTokenFromKeychain() -> String? {
        // Use macOS Keychain to securely store/retrieve token
        let service = "mlx-engine-tests"
        let account = "huggingface-token"

        // This is a simplified implementation - in production you'd want
        // to use Security.framework properly with proper error handling
        let keychainPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Keychains")
            .appendingPathComponent("mlx-engine-test-token.txt")

        if let tokenData = try? Data(contentsOf: keychainPath),
           let token = String(data: tokenData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }

        return nil
    }
    #endif

    private static func configureTestModels() -> [TestModel] {
        return [
            TestModel(
                name: "TinyLlama-1.1B-Chat-v1.0",
                hubId: "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
                description: "Lightweight model for testing",
                size: 2_200_000_000, // ~2.2GB
                downloadTimeEstimate: 60, // seconds
                recommendedForTesting: true
            ),
            TestModel(
                name: "Phi-3-mini-4k-instruct",
                hubId: "microsoft/Phi-3-mini-4k-instruct",
                description: "Microsoft's Phi-3 mini model",
                size: 7_600_000_000, // ~7.6GB
                downloadTimeEstimate: 180,
                recommendedForTesting: false
            ),
            TestModel(
                name: "Qwen2-0.5B-Instruct",
                hubId: "Qwen/Qwen2-0.5B-Instruct",
                description: "Qwen 2 model for testing",
                size: 1_000_000_000, // ~1GB
                downloadTimeEstimate: 45,
                recommendedForTesting: true
            )
        ]
    }

    private static func configureTestAdapters() -> [TestAdapter] {
        return [
            TestAdapter(
                name: "Medical Assistant",
                hubId: "mlx-community/llama-2-7b-chat-lora-medical",
                baseModel: "meta-llama/Llama-2-7b-chat-hf",
                description: "Medical terminology specialist",
                size: 50_000_000, // ~50MB
                category: .medical
            ),
            TestAdapter(
                name: "Coding Assistant",
                hubId: "mlx-community/llama-2-7b-chat-lora-coding",
                baseModel: "meta-llama/Llama-2-7b-chat-hf",
                description: "Programming and development specialist",
                size: 45_000_000, // ~45MB
                category: .coding
            ),
            TestAdapter(
                name: "Legal Assistant",
                hubId: "mlx-community/llama-2-7b-chat-lora-legal",
                baseModel: "meta-llama/Llama-2-7b-chat-hf",
                description: "Legal document specialist",
                size: 48_000_000, // ~48MB
                category: .legal
            )
        ]
    }

    // MARK: - Public Methods

    /// Get the best test model for current environment
    func bestTestModel() -> TestModel? {
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            // In CI, use the smallest model
            return testModels.first { $0.recommendedForTesting }
        } else if ProcessInfo.processInfo.environment["FORCE_MOCK_TESTS"] == "true" {
            // When mock tests are forced, return nil to use mock implementations
            return nil
        } else {
            // For local testing, use recommended models (REAL TESTS BY DEFAULT)
            return testModels.first { $0.recommendedForTesting }
        }
    }

    /// Check if we have valid HuggingFace credentials
    func hasValidCredentials() -> Bool {
        return huggingFaceToken != nil && !huggingFaceToken!.isEmpty
    }

    /// Get test configuration summary
    func configurationSummary() -> String {
        return """
        Test Configuration (DEFAULT: REAL TESTS ENABLED):
        - HuggingFace Token: \(hasValidCredentials() ? "✅ Available" : "❌ Missing")
        - Real Model Tests: \(shouldRunRealModelTests ? "✅ Enabled (DEFAULT)" : "❌ Disabled (via FORCE_MOCK_TESTS)")
        - Test Models: \(testModels.count) configured
        - Test Adapters: \(testAdapters.count) configured
        - Test Timeout: \(testTimeout) seconds
        - To force mock tests: export FORCE_MOCK_TESTS=true
        """
    }
}

/// Test model configuration
struct TestModel {
    let name: String
    let hubId: String
    let description: String
    let size: Int64 // bytes
    let downloadTimeEstimate: TimeInterval // seconds
    let recommendedForTesting: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/\(hubId)/resolve/main")!
    }
}

/// Test adapter configuration
struct TestAdapter {
    let name: String
    let hubId: String
    let baseModel: String
    let description: String
    let size: Int64 // bytes
    let category: AdapterCategory

    var downloadURL: URL {
        URL(string: "https://huggingface.co/\(hubId)/resolve/main")!
    }
}

/// Adapter categories for testing
enum AdapterCategory: String {
    case medical
    case coding
    case legal
    case creative
    case business
}
