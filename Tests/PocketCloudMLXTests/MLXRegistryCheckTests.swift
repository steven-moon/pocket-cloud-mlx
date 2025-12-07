// == LLM Context: Bread Crumbs ==
// Module        : Workspace
// File          : pocket-cloud-mlx/Tests/PocketCloudMLXTests/MLXRegistryCheckTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class MLXRegistryCheckTests: XCTestCase {
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
import XCTest
@testable import PocketCloudMLX

#if canImport(MLXLLM)
import MLXLLM
#endif

final class MLXRegistryCheckTests: XCTestCase {

    func testMLXRegistryAvailableModels() {
        #if canImport(MLXLLM)
        let registry = MLXLLM.LLMRegistry.shared
        let models = registry.models

        print("📊 Found \(models.count) models in MLX registry:")
        for (index, model) in models.enumerated() {
            print("  \(index + 1): ID=\(String(describing: model.id)), name=\(model.name)")
            if index >= 20 { // Show first 20 models
                print("  ... and \(models.count - 20) more")
                break
            }
        }

        // Check for specific models we're interested in
        let targetModels = [
            "mlx-community/Llama-3.2-1B-Instruct-4bit",
            "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
            "mlx-community/Llama-3.2-3B-Instruct-4bit",
            "mlx-community/SmolLM2-360M-Instruct"
        ]

        print("\n🔍 Checking for target models:")
        for targetModel in targetModels {
            let matchingModels = models.filter { String(describing: $0.id).contains(targetModel) }
            if matchingModels.isEmpty {
                print("❌ \(targetModel) - NOT FOUND in registry")
            } else {
                print("✅ \(targetModel) - FOUND (\(matchingModels.count) matches)")
                for match in matchingModels {
                    print("   - ID: \(String(describing: match.id)), Name: \(match.name)")
                }
            }
        }

        XCTAssertGreaterThan(models.count, 0, "MLX registry should contain models")
        #else
        print("❌ MLXLLM not available in test")
        XCTFail("MLXLLM should be available for these tests")
        #endif
    }

    func testModelDiscoveryService() async throws {
        print("🔍 Testing ModelDiscoveryService...")

        do {
            let models = try await ModelDiscoveryService.searchMLXModels(query: "mlx", limit: 5)
            print("✅ ModelDiscoveryService found \(models.count) MLX models")

            if !models.isEmpty {
                print("📋 First model found:")
                print("   ID: \(models[0].id)")
                print("   Name: \(models[0].name)")
                print("   Architecture: \(models[0].architecture ?? "Unknown")")
                print("   Parameters: \(models[0].parameters ?? "Unknown")")
                print("   Quantization: \(models[0].quantization ?? "Unknown")")
            }
        } catch {
            print("❌ ModelDiscoveryService failed: \(error.localizedDescription)")
            throw error
        }
    }

    func testRecommendedModelsForDevice() async throws {
        print("🔍 Testing recommended models for current device...")

        do {
            let models = try await ModelDiscoveryService.recommendedMLXModelsForCurrentDevice(limit: 5)
            print("✅ Found \(models.count) recommended models for current device")

            for (index, model) in models.enumerated() {
                print("   \(index + 1): \(model.name) (\(model.parameters ?? "Unknown"))")
            }
        } catch {
            print("❌ Recommended models failed: \(error.localizedDescription)")
            throw error
        }
    }
}
