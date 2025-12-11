// swift-tools-version: 6.0
// Package.swift for PocketCloudMLX
//
// Local inference engine for the PocketCloud ecosystem using Apple's MLX framework.

import PackageDescription
import Foundation

// Check if we're running in a workspace with sibling dependencies
let pocketCloudUIRelativePaths = ["../pocket-cloud-ui", "pocket-cloud-ui"]
let pocketCloudUIPath = pocketCloudUIRelativePaths.first { FileManager.default.fileExists(atPath: $0) }
let hasPocketCloudUI = pocketCloudUIPath != nil

let pocketCloudLoggerRelativePaths = ["../pocket-cloud-logger", "pocket-cloud-logger"]
let pocketCloudLoggerPath = pocketCloudLoggerRelativePaths.first { FileManager.default.fileExists(atPath: $0) }
let hasPocketCloudLogger = pocketCloudLoggerPath != nil

let pocketCloudAIAgentRelativePaths = ["../pocket-cloud-ai-agent", "pocket-cloud-ai-agent"]
let pocketCloudAIAgentPath = pocketCloudAIAgentRelativePaths.first { FileManager.default.fileExists(atPath: $0) }
let hasPocketCloudAIAgent = pocketCloudAIAgentPath != nil
let pocketCloudCommonRelativePaths = ["../pocket-cloud-common", "pocket-cloud-common"]
let pocketCloudCommonPath = pocketCloudCommonRelativePaths.first { FileManager.default.fileExists(atPath: $0) }
let hasPocketCloudCommon = pocketCloudCommonPath != nil

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.29.0"),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", branch: "main"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.3"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.0.0")
]

var targetDependencies: [Target.Dependency] = [
    .product(name: "MLX", package: "mlx-swift"),
    .product(name: "MLXNN", package: "mlx-swift"),
    .product(name: "MLXLLM", package: "mlx-swift-lm"),
    .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
    .product(name: "MLXVLM", package: "mlx-swift-lm"),
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
    .product(name: "Yams", package: "Yams")
]

var testDependencies: [Target.Dependency] = [
    "PocketCloudMLX",
    .product(name: "MLXLLM", package: "mlx-swift-lm"),
    .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
    .product(name: "MLXVLM", package: "mlx-swift-lm")
]

// Add workspace dependencies if available
if hasPocketCloudUI, let pocketCloudUIPath {
    dependencies.append(.package(path: pocketCloudUIPath))
    targetDependencies.append(.product(name: "PocketCloudUI", package: "pocket-cloud-ui"))
}

if hasPocketCloudLogger, let pocketCloudLoggerPath {
    dependencies.append(.package(path: pocketCloudLoggerPath))
    targetDependencies.append(.product(name: "PocketCloudLogger", package: "pocket-cloud-logger"))
    testDependencies.append(.product(name: "PocketCloudLogger", package: "pocket-cloud-logger"))
}

if hasPocketCloudAIAgent, let pocketCloudAIAgentPath {
    dependencies.append(.package(path: pocketCloudAIAgentPath))
}

if hasPocketCloudCommon, let pocketCloudCommonPath {
    dependencies.append(.package(path: pocketCloudCommonPath))
    targetDependencies.append(.product(name: "PocketCloudCommon", package: "pocket-cloud-common"))
    testDependencies.append(.product(name: "PocketCloudCommon", package: "pocket-cloud-common"))
}

var targets: [Target] = [
    .target(
        name: "PocketCloudMLX",
        dependencies: targetDependencies,
        path: "Sources/PocketCloudMLX",
        exclude: [
            "Resources/Info.plist"
        ],
        resources: [
            .copy("Resources/default.metallib"),
            .process("Resources/models.yaml")
        ]
    ),
    .testTarget(
        name: "PocketCloudMLXTests",
        dependencies: testDependencies,
        path: "Tests/PocketCloudMLXTests",
        exclude: [
            "Info.plist"
        ],
        resources: [
            .copy("Resources/default.metallib")
        ]
    )
]

let package = Package(
    name: "PocketCloudMLX",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
        .tvOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "PocketCloudMLX",
            targets: ["PocketCloudMLX"]
        )
    ],
    dependencies: dependencies,
    targets: targets
)
