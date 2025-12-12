// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketCloudChat",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .executable(name: "PocketCloudChat", targets: ["PocketCloudChatApp"])
    ],
    dependencies: [
        .package(path: "../../pocket-cloud-mlx"),
        .package(path: "../../pocket-cloud-ui"),
        .package(path: "../../pocket-cloud-logger"),
        .package(path: "../../pocket-cloud-common")
    ],
    targets: [
        .executableTarget(
            name: "PocketCloudChatApp",
            dependencies: [
                .target(name: "PocketCloudChat", condition: .none),
            ]
        ),
        .target(
            name: "PocketCloudChat",
            dependencies: [
                "PocketCloudMLX",
                "PocketCloudUI",
                "PocketCloudLogger",
                "PocketCloudCommon"
            ],
            path: "Sources/PocketCloudChat",
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .target(
            name: "PocketCloudChatiOS",
            dependencies: [
                "PocketCloudChat"
            ],
            path: "Sources/iOS"
        ),
        .target(
            name: "PocketCloudChatShared",
            path: "Sources/Shared"
        ),
        .target(
            name: "PocketCloudChatmacOS",
            dependencies: [
                "PocketCloudChat"
            ],
            path: "Sources/macOS"
        )
    ]
)
