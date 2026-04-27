// swift-tools-version: 5.9
// YX Protocol Interoperability Test Programs (Swift)

import PackageDescription

let package = Package(
    name: "YXInteropSwift",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../../../builds/swift-impl")
    ],
    targets: [
        // Transport Layer Senders
        .executableTarget(
            name: "swift-sender-transport-simple",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Transport",
            sources: ["TransportSimple.swift"]
        ),
        .executableTarget(
            name: "swift-sender-transport-empty",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Transport",
            sources: ["TransportEmpty.swift"]
        ),
        .executableTarget(
            name: "swift-sender-transport-large",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Transport",
            sources: ["TransportLarge.swift"]
        ),
        .executableTarget(
            name: "swift-sender-transport-multiple",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Transport",
            sources: ["TransportMultiple.swift"]
        ),
        .executableTarget(
            name: "swift-sender-transport-invalid",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Transport",
            sources: ["TransportInvalid.swift"]
        ),

        // Protocol 0 Senders
        .executableTarget(
            name: "swift-sender-proto0-json",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Proto0",
            sources: ["Proto0JSON.swift"]
        ),
        .executableTarget(
            name: "swift-sender-proto0-large",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Proto0",
            sources: ["Proto0Large.swift"]
        ),
        .executableTarget(
            name: "swift-sender-proto0-invalid",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Proto0",
            sources: ["Proto0Invalid.swift"]
        ),

        // Protocol 1 Senders
        .executableTarget(
            name: "swift-sender-proto1-base",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Proto1",
            sources: ["Proto1Base.swift"]
        ),
        .executableTarget(
            name: "swift-sender-proto1-compressed",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Proto1",
            sources: ["Proto1Compressed.swift"]
        ),
        .executableTarget(
            name: "swift-sender-proto1-encrypted",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Proto1",
            sources: ["Proto1Encrypted.swift"]
        ),
        .executableTarget(
            name: "swift-sender-proto1-both",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Senders/Proto1",
            sources: ["Proto1Both.swift"]
        ),

        // Receivers
        .executableTarget(
            name: "swift-receiver-transport",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Receivers",
            sources: ["TransportReceiver.swift"]
        ),
        .executableTarget(
            name: "swift-receiver-proto0",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Receivers",
            sources: ["Proto0Receiver.swift"]
        ),
        .executableTarget(
            name: "swift-receiver-proto1",
            dependencies: [.product(name: "YXProtocol", package: "swift-impl")],
            path: "Sources/Receivers",
            sources: ["Proto1Receiver.swift"]
        ),
    ]
)
