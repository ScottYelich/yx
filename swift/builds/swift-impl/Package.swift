// swift-tools-version: 5.9
// Implements: protocol/specs/technical/yx-protocol-spec.md

import PackageDescription

let package = Package(
    name: "YXProtocol",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "YXProtocol",
            targets: ["YXProtocol"]
        ),
        .executable(name: "SwiftSender", targets: ["SwiftSender"]),
        .executable(name: "SwiftReceiver", targets: ["SwiftReceiver"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "YXProtocol",
            dependencies: [],
            path: "Sources/YXProtocol"
        ),
        .executableTarget(
            name: "SwiftSender",
            dependencies: ["YXProtocol"],
            path: "Sources/SwiftSender"
        ),
        .executableTarget(
            name: "SwiftReceiver",
            dependencies: ["YXProtocol"],
            path: "Sources/SwiftReceiver"
        ),
        .testTarget(
            name: "YXProtocolTests",
            dependencies: ["YXProtocol"],
            path: "Tests/YXProtocolTests"
        ),
    ]
)
