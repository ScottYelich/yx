// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YXProtocol",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "YXProtocol", targets: ["YXProtocol"]),
        .executable(name: "swift-sender", targets: ["SwiftSender"]),
        .executable(name: "swift-receiver", targets: ["SwiftReceiver"]),
    ],
    targets: [
        .target(name: "YXProtocol", dependencies: []),
        .executableTarget(name: "SwiftSender", dependencies: ["YXProtocol"]),
        .executableTarget(name: "SwiftReceiver", dependencies: ["YXProtocol"]),
        .testTarget(name: "YXProtocolTests", dependencies: ["YXProtocol"]),
    ]
)
