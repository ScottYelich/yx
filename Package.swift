// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "yx",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "Primitives", targets: ["Primitives"]),
        .library(name: "Transport", targets: ["Transport"]),
        .library(name: "RPC", targets: ["RPC"]),
        .library(name: "YX", targets: ["YX"]),
        .executable(name: "yxkey", targets: ["yxkey"]),
        .executable(name: "yxnode", targets: ["yxnode"]),
    ],
    targets: [
        // MARK: - Foundation Layer (no dependencies)

        .target(
            name: "Primitives"
            // Foundation primitives: Data extensions, GUID, JSON, logging
            // Provides: Data+Hex, Data+Crypto, GUID utilities, JSON types
        ),

        // MARK: - Transport Layer (depends on Foundation only)

        .target(
            name: "Transport",
            dependencies: ["Primitives"]
            // Packet handling, protocols, networking, security
            // Provides: UDPTransport, ProtocolRouter, TextProtocol, BinaryProtocol
            // Security: RateLimiter, ReplayProtection, KeyRotation
        ),

        // MARK: - RPC Layer (depends on Transport)

        .target(
            name: "RPC",
            dependencies: ["Transport"]
            // JSON-RPC dispatch and handlers
            // Provides: RPCDispatcher, RPC handlers, IdentityManager
        ),

        // MARK: - Application Layer (umbrella)

        .target(
            name: "YX",
            dependencies: ["Primitives", "Transport", "RPC"]
            // Top-level system coordination and re-exports
            // Provides: NetworkSystem, RPCSystem, Configuration, YX facade
        ),

        // MARK: - Executables

        .executableTarget(
            name: "yxkey",
            dependencies: ["Primitives"]
            // Mesh key manager (macOS Keychain). Spec: key-management.md
        ),

        .executableTarget(
            name: "yxnode",
            dependencies: ["YX", "Primitives"]
            // Base mesh node daemon + canonical service example (ADR D09).
        ),

        // MARK: - Tests

        .testTarget(
            name: "YXTests",
            dependencies: ["YX"]
            // Tests can import YX to test full integration
        )
    ]
)
