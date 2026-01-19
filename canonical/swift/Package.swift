// swift-tools-version: 5.9
// Implements: specs/technical/yx-protocol-spec.md

import PackageDescription

let package = Package(
    name: "YXProtocol",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "YXProtocol",
            targets: ["YXProtocol"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "YXProtocol",
            dependencies: []
        ),
        .testTarget(
            name: "YXProtocolTests",
            dependencies: ["YXProtocol"]
        ),
    ]
)
