// == LLM Context: Bread Crumbs ==
// Module        : Workspace
// File          : pocket-cloud-mlx/Tests/PocketCloudMLXTests/GenerateParamsTests.swift
// Purpose       : Quick context for AI agents. Use these bread crumbs to navigate code and docs.
//
// Key Types in this file:
//   - class GenerateParamsTests: XCTestCase {
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

/// Tests for GenerateParams configuration and validation
/// This consolidates GenerateParams tests from PocketCloudMLXTests
@MainActor
final class GenerateParamsTests: XCTestCase {

    // MARK: - Default Values Tests

    func testGenerateParamsDefaultValues() {
        let params = GenerateParams()

        XCTAssertEqual(params.maxTokens, 128)
        XCTAssertEqual(params.temperature, 0.7, accuracy: 0.01)
        XCTAssertEqual(params.topP, 0.9, accuracy: 0.01)
        XCTAssertEqual(params.topK, 40)
        XCTAssertTrue(params.stopTokens.isEmpty)
    }

    func testGenerateParamsCustomValues() {
        let params = GenerateParams(
            maxTokens: 200,
            temperature: 0.5,
            topP: 0.8,
            topK: 20,
            stopTokens: ["END", "STOP"]
        )

        XCTAssertEqual(params.maxTokens, 200)
        XCTAssertEqual(params.temperature, 0.5, accuracy: 0.01)
        XCTAssertEqual(params.topP, 0.8, accuracy: 0.01)
        XCTAssertEqual(params.topK, 20)
        XCTAssertEqual(params.stopTokens, ["END", "STOP"])
    }

    // MARK: - Parameter Validation Tests

    func testGenerateParamsMaxTokens() {
        // Valid max tokens
        let validParams = GenerateParams(maxTokens: 1000)
        XCTAssertEqual(validParams.maxTokens, 1000)

        // Edge cases
        let zeroTokens = GenerateParams(maxTokens: 0)
        XCTAssertEqual(zeroTokens.maxTokens, 0)

        let largeTokens = GenerateParams(maxTokens: 10000)
        XCTAssertEqual(largeTokens.maxTokens, 10000)
    }

    func testGenerateParamsTemperature() {
        // Valid temperatures
        let lowTemp = GenerateParams(temperature: 0.0)
        XCTAssertEqual(lowTemp.temperature, 0.0, accuracy: 0.01)

        let highTemp = GenerateParams(temperature: 2.0)
        XCTAssertEqual(highTemp.temperature, 2.0, accuracy: 0.01)

        let normalTemp = GenerateParams(temperature: 0.8)
        XCTAssertEqual(normalTemp.temperature, 0.8, accuracy: 0.01)
    }

    func testGenerateParamsTopP() {
        // Valid topP values
        let lowTopP = GenerateParams(topP: 0.0)
        XCTAssertEqual(lowTopP.topP, 0.0, accuracy: 0.01)

        let highTopP = GenerateParams(topP: 1.0)
        XCTAssertEqual(highTopP.topP, 1.0, accuracy: 0.01)

        let normalTopP = GenerateParams(topP: 0.95)
        XCTAssertEqual(normalTopP.topP, 0.95, accuracy: 0.01)
    }

    func testGenerateParamsTopK() {
        // Valid topK values
        let lowTopK = GenerateParams(topK: 0)
        XCTAssertEqual(lowTopK.topK, 0)

        let highTopK = GenerateParams(topK: 100)
        XCTAssertEqual(highTopK.topK, 100)

        let normalTopK = GenerateParams(topK: 50)
        XCTAssertEqual(normalTopK.topK, 50)
    }

    func testGenerateParamsStopTokens() {
        // Empty stop tokens
        let emptyStop = GenerateParams(stopTokens: [])
        XCTAssertTrue(emptyStop.stopTokens.isEmpty)

        // Single stop token
        let singleStop = GenerateParams(stopTokens: ["STOP"])
        XCTAssertEqual(singleStop.stopTokens, ["STOP"])

        // Multiple stop tokens
        let multipleStop = GenerateParams(stopTokens: ["END", "STOP", "<eos>"])
        XCTAssertEqual(multipleStop.stopTokens, ["END", "STOP", "<eos>"])

        // Special characters in stop tokens
        let specialStop = GenerateParams(stopTokens: ["\n", "\r\n", "###"])
        XCTAssertEqual(specialStop.stopTokens, ["\n", "\r\n", "###"])
    }

    // MARK: - Parameter Combination Tests

    func testGenerateParamsCreativeWriting() {
        // Parameters suitable for creative writing
        let creative = GenerateParams(
            maxTokens: 500,
            temperature: 1.2,
            topP: 0.9,
            topK: 50,
            stopTokens: ["END"]
        )

        XCTAssertEqual(creative.maxTokens, 500)
        XCTAssertEqual(creative.temperature, 1.2, accuracy: 0.01)
        XCTAssertEqual(creative.topP, 0.9, accuracy: 0.01)
        XCTAssertEqual(creative.topK, 50)
        XCTAssertEqual(creative.stopTokens, ["END"])
    }

    func testGenerateParamsTechnicalWriting() {
        // Parameters suitable for technical/factual writing
        let technical = GenerateParams(
            maxTokens: 200,
            temperature: 0.3,
            topP: 0.7,
            topK: 30,
            stopTokens: ["\n\n"]
        )

        XCTAssertEqual(technical.maxTokens, 200)
        XCTAssertEqual(technical.temperature, 0.3, accuracy: 0.01)
        XCTAssertEqual(technical.topP, 0.7, accuracy: 0.01)
        XCTAssertEqual(technical.topK, 30)
        XCTAssertEqual(technical.stopTokens, ["\n\n"])
    }

    func testGenerateParamsChatConversation() {
        // Parameters suitable for chat conversations
        let chat = GenerateParams(
            maxTokens: 150,
            temperature: 0.8,
            topP: 0.85,
            topK: 40,
            stopTokens: ["User:", "Assistant:", "\n\n"]
        )

        XCTAssertEqual(chat.maxTokens, 150)
        XCTAssertEqual(chat.temperature, 0.8, accuracy: 0.01)
        XCTAssertEqual(chat.topP, 0.85, accuracy: 0.01)
        XCTAssertEqual(chat.topK, 40)
        XCTAssertEqual(chat.stopTokens, ["User:", "Assistant:", "\n\n"])
    }

    func testGenerateParamsCodeGeneration() {
        // Parameters suitable for code generation
        let code = GenerateParams(
            maxTokens: 300,
            temperature: 0.2,
            topP: 0.8,
            topK: 20,
            stopTokens: ["\n\n", "# End", "```"]
        )

        XCTAssertEqual(code.maxTokens, 300)
        XCTAssertEqual(code.temperature, 0.2, accuracy: 0.01)
        XCTAssertEqual(code.topP, 0.8, accuracy: 0.01)
        XCTAssertEqual(code.topK, 20)
        XCTAssertEqual(code.stopTokens, ["\n\n", "# End", "```"])
    }

    // MARK: - Edge Cases Tests

    func testGenerateParamsNegativeValues() {
        // Test with negative values (should be handled gracefully)
        let negativeTemp = GenerateParams(temperature: -0.5)
        XCTAssertEqual(negativeTemp.temperature, -0.5, accuracy: 0.01)

        let negativeTopP = GenerateParams(topP: -0.1)
        XCTAssertEqual(negativeTopP.topP, -0.1, accuracy: 0.01)

        let negativeTopK = GenerateParams(topK: -10)
        XCTAssertEqual(negativeTopK.topK, -10)
    }

    func testGenerateParamsExtremeValues() {
        // Test with extreme values
        let extremeTemp = GenerateParams(temperature: 10.0)
        XCTAssertEqual(extremeTemp.temperature, 10.0, accuracy: 0.01)

        let extremeTopP = GenerateParams(topP: 2.0)
        XCTAssertEqual(extremeTopP.topP, 2.0, accuracy: 0.01)

        let extremeTopK = GenerateParams(topK: 1000)
        XCTAssertEqual(extremeTopK.topK, 1000)
    }

    // MARK: - Equality and Comparison Tests

    func testGenerateParamsEquality() {
        let params1 = GenerateParams(
            maxTokens: 100,
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            stopTokens: ["STOP"]
        )

        let params2 = GenerateParams(
            maxTokens: 100,
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            stopTokens: ["STOP"]
        )

        let params3 = GenerateParams(
            maxTokens: 200,
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            stopTokens: ["STOP"]
        )

        // Should be equal (value equality)
        XCTAssertEqual(params1.maxTokens, params2.maxTokens)
        XCTAssertEqual(params1.temperature, params2.temperature, accuracy: 0.01)
        XCTAssertEqual(params1.topP, params2.topP, accuracy: 0.01)
        XCTAssertEqual(params1.topK, params2.topK)
        XCTAssertEqual(params1.stopTokens, params2.stopTokens)

        // Different values should not be equal
        XCTAssertNotEqual(params1.maxTokens, params3.maxTokens)
    }

    // MARK: - Codable Tests

    func testGenerateParamsCodable() throws {
        let original = GenerateParams(
            maxTokens: 256,
            temperature: 0.8,
            topP: 0.95,
            topK: 50,
            stopTokens: ["END", "STOP"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerateParams.self, from: data)

        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertEqual(decoded.temperature, original.temperature, accuracy: 0.01)
        XCTAssertEqual(decoded.topP, original.topP, accuracy: 0.01)
        XCTAssertEqual(decoded.topK, original.topK)
        XCTAssertEqual(decoded.stopTokens, original.stopTokens)
    }
}
