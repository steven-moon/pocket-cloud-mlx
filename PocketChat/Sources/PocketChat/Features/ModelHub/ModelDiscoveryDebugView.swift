// == LLM Context: Bread Crumbs ==
// Module        : MLXChatApp
// File          : mlx-engine/MLXChatApp/Sources/MLXChatApp/Features/ModelHub/ModelDiscoveryDebugView.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - struct ModelDiscoveryDebugView: View {
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
import SwiftUI
import MLXEngine

/// Debug view for troubleshooting model discovery issues
struct ModelDiscoveryDebugView: View {
    @StateObject private var viewModel = ModelDiscoveryViewModel()
    @State private var debugOutput: String = ""
    @State private var isRunningTests = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Model Discovery Debug")
                .font(.title)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Debug Output:")
                        .font(.headline)
                    
                    Text(debugOutput.isEmpty ? "No debug output yet. Run tests to see results." : debugOutput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            HStack(spacing: 16) {
                Button("Test Popular Models") {
                    Task { await testPopularModels() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningTests)
                
                Button("Test MLX Discovery") {
                    Task { await testMLXDiscovery() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningTests)
                
                Button("Clear Output") {
                    debugOutput = ""
                }
                .buttonStyle(.bordered)
            }
            
            if isRunningTests {
                ProgressView("Running tests...")
            }
        }
        .padding()
    }
    
    private func testPopularModels() async {
        isRunningTests = true
        debugOutput = "🔍 Testing popular model discovery...\n\n"
        
        let testQueries = [
            "llama",
            "phi", 
            "mistral",
            "qwen",
            "gemma",
            "mlx"
        ]
        
        for query in testQueries {
            do {
                debugOutput += "📝 Testing query: '\(query)'\n"
                let models = try await viewModel.huggingFaceAPI.searchModels(query: query, limit: 5)
                debugOutput += "   Found \(models.count) models\n"
                
                let mlxCompatible = models.filter { $0.hasMLXFiles() }
                debugOutput += "   MLX compatible: \(mlxCompatible.count)\n"
                
                for model in mlxCompatible.prefix(3) {
                    debugOutput += "   - \(model.id) (tags: \(model.tags?.joined(separator: ", ") ?? "none"))\n"
                }
                
                if mlxCompatible.isEmpty {
                    debugOutput += "   ⚠️ No MLX-compatible models found for '\(query)'\n"
                }
                
                debugOutput += "\n"
                
            } catch {
                debugOutput += "   ❌ Error searching '\(query)': \(error.localizedDescription)\n\n"
            }
        }
        
        debugOutput += "✅ Popular model discovery test completed\n"
        isRunningTests = false
    }
    
    private func testMLXDiscovery() async {
        isRunningTests = true
        debugOutput = "🔍 Testing MLX-specific discovery...\n\n"
        
        do {
            // Test the recommended models method
            debugOutput += "📝 Testing recommendedMLXModelsForCurrentDevice...\n"
            let recommended = try await ModelDiscoveryService.recommendedMLXModelsForCurrentDevice(limit: 10)
            debugOutput += "   Found \(recommended.count) recommended models\n"
            
            for model in recommended {
                debugOutput += "   - \(model.id) (downloads: \(model.downloads), likes: \(model.likes))\n"
            }
            
            debugOutput += "\n"
            
            // Test specific MLX search
            debugOutput += "📝 Testing MLX-specific search...\n"
            let mlxModels = try await ModelDiscoveryService.searchMLXModels(query: "mlx", limit: 10)
            debugOutput += "   Found \(mlxModels.count) MLX models\n"
            
            for model in mlxModels.prefix(5) {
                debugOutput += "   - \(model.id) (downloads: \(model.downloads), likes: \(model.likes))\n"
            }
            
            debugOutput += "\n✅ MLX discovery test completed\n"
            
        } catch {
            debugOutput += "❌ Error in MLX discovery test: \(error.localizedDescription)\n"
        }
        
        isRunningTests = false
    }
}

#if DEBUG
#Preview {
    ModelDiscoveryDebugView()
}
#endif
