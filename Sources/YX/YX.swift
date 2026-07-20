import Foundation
@_exported import Primitives
@_exported import CryptoKit
@_exported import Transport
@_exported import RPC

/// Simplified YX Framework API
///
/// This class provides a high-level, developer-friendly interface for the YX networking framework.
/// Instead of manually wiring NetworkSystem, protocols, and RPC dispatchers, use this simple facade.
///
/// **Background Process Compatibility:**
/// YX automatically configures stdout for line-buffered output, ensuring logging works correctly
/// when the process runs in background, via nohup, or with redirected output. This solves the
/// common Swift stdout buffering issue where print() statements don't appear in background processes.
///
/// Example:
/// ```swift
/// let yx = await YX(port: 9999)
///
/// await yx.registerRPC("hello") { request in
///     print("Hello from \(request.params["name"] ?? "unknown")")
/// }
///
/// await yx.sendText(["method": "hello", "params": ["name": "Scott"]], to: "192.168.1.100", port: 9999)
/// await yx.sendBinary(data, to: "192.168.1.100", port: 9999, encrypt: true, compress: true)
/// ```
public actor YX {
    /// The underlying network system
    private let network: NetworkSystem

    /// Local GUID (6 bytes)
    nonisolated public let guid: Data

    /// Default symmetric key
    nonisolated public let key: SymmetricKey

    /// Port we're listening on
    nonisolated public let port: UInt16

    /// Initialize YX framework with simplified API
    ///
    /// - Parameters:
    ///   - port: UDP port to listen on (default: 9999)
    ///   - guid: 6-byte GUID (auto-generated if nil)
    ///   - key: 32-byte symmetric key (auto-generated if nil)
    ///   - processOwnPackets: Whether to process packets from self (default: false)
    public init(
        port: UInt16 = 9999,
        guid: Data? = nil,
        key: SymmetricKey? = nil,
        processOwnPackets: Bool = false
    ) async {
        // Fix stdout buffering for background processes/daemons
        // This ensures print() statements appear immediately after newlines
        // rather than being block-buffered when stdout is redirected
        setvbuf(stdout, nil, _IOLBF, 0)  // Line-buffered output

        // Auto-generate GUID if not provided
        let finalGUID: Data
        if let guid = guid {
            guard guid.count == 6 else {
                fatalError("GUID must be exactly 6 bytes, got \(guid.count)")
            }
            finalGUID = guid
        } else {
            finalGUID = GUIDFactory.generate()
            log("🆔 Auto-generated GUID: \(finalGUID.hexString)", level: .info)
        }

        // Auto-generate key if not provided
        let finalKey: SymmetricKey
        if let key = key {
            finalKey = key
        } else {
            finalKey = SymmetricKey(size: .bits256)
            log("🔑 Auto-generated symmetric key", level: .info)
        }

        self.guid = finalGUID
        self.key = finalKey
        self.port = port

        // Create configuration
        var config = Configuration.default
        config.network.udpPort = port
        config.network.processOwnPackets = processOwnPackets

        // Initialize network system
        self.network = await NetworkSystem(
            guid: finalGUID,
            key: finalKey,
            config: config
        )

        log("✅ YX initialized on port \(port)", level: .info)
        log("🆔 GUID: \(finalGUID.hexString)", level: .info)
    }

    /// Register an RPC handler for a specific method
    ///
    /// - Parameters:
    ///   - method: JSON-RPC method name (e.g., "task.hello")
    ///   - handler: Async function to handle the request
    ///
    /// Example:
    /// ```swift
    /// await yx.registerRPC("hello") { request in
    ///     print("Hello from \(request.params["name"] ?? "unknown")")
    /// }
    /// ```
    public func registerRPC(
        _ method: String,
        handler: @escaping @Sendable (RPCRequest) async -> Void
    ) async {
        await network.rpc.register(method, handler: handler)
        log("📝 Registered RPC handler: \(method)", level: .info)
    }

    /// Register an S-expression handler for a car (head) symbol (Protocol-0 s-expr, ADR D11)
    ///
    /// - Parameters:
    ///   - head: The car symbol to dispatch on (e.g., "node-hello", "msg")
    ///   - handler: Async function receiving the parsed S-expression
    ///
    /// Example:
    /// ```swift
    /// await yx.registerSexp("node-hello") { expr in
    ///     print("hello from \(expr.field("node")?.stringValue ?? "?")")
    /// }
    /// ```
    public func registerSexp(
        _ head: String,
        handler: @escaping @Sendable (SExpr) async -> Void
    ) async {
        await network.rpc.registerSexp(head, handler: handler)
        log("📝 Registered S-expr handler: \(head)", level: .info)
    }

    /// Send an S-expression as a Protocol-0 text payload (ADR D11)
    ///
    /// - Parameters:
    ///   - expr: The S-expression to send (serialized to its light canonical form)
    ///   - host: Destination IP address (use "255.255.255.255" for broadcast)
    ///   - port: Destination port
    ///
    /// Example:
    /// ```swift
    /// await yx.sendSexpr(
    ///     .list([.sym("node-hello"), .list([.sym("node"), .str("colossus")])]),
    ///     to: "192.168.1.100", port: 9720)
    /// ```
    public func sendSexpr(_ expr: SExpr, to host: String, port: UInt16) async {
        let payload = Data(expr.serialize().utf8)

        // Build packet with GUID and HMAC — same packet build path as sendText
        let packet = UDPPacketUtils.build(guid: guid, bytesAfterGUID: payload, key: key)
        network.networking.sendUDPPacket(packet, to: host, port: port)
        log("📤 Sent s-expr to \(host):\(port)", level: .info)
    }

    /// Send a text protocol message (JSON-RPC)
    ///
    /// - Parameters:
    ///   - message: JSON-RPC message dictionary (must have "method" key)
    ///   - host: Destination IP address (use "255.255.255.255" for broadcast)
    ///   - port: Destination port
    ///
    /// Example:
    /// ```swift
    /// await yx.sendText(
    ///     ["method": "hello", "params": ["name": "Scott"], "id": 1],
    ///     to: "192.168.1.100",
    ///     port: 9999
    /// )
    /// ```
    public func sendText(
        _ message: [String: Any],
        to host: String,
        port: UInt16
    ) async {
        // Serialize JSON in this actor to avoid sending non-Sendable dictionary to another actor
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message) else {
            log("❌ Failed to serialize JSON message", level: .error)
            return
        }

        // Build packet with GUID and HMAC
        let guid = self.guid
        let key = self.key
        let packet = UDPPacketUtils.build(guid: guid, bytesAfterGUID: jsonData, key: key)

        // Send via network transport (networking is nonisolated, no await needed)
        let networking = network.networking
        networking.sendUDPPacket(packet, to: host, port: port)
        log("📤 Sent text message to \(host):\(port)", level: .info)
    }

    /// Send a binary protocol message
    ///
    /// - Parameters:
    ///   - data: Binary data to send
    ///   - host: Destination IP address (use "255.255.255.255" for broadcast)
    ///   - port: Destination port
    ///   - encrypt: Whether to encrypt with AES-256-GCM (default: false)
    ///   - compress: Whether to compress with zlib (default: false)
    ///
    /// Example:
    /// ```swift
    /// await yx.sendBinary(
    ///     "Binary data".data(using: .utf8)!,
    ///     to: "192.168.1.100",
    ///     port: 9999,
    ///     encrypt: true,
    ///     compress: true
    /// )
    /// ```
    public func sendBinary(
        _ data: Data,
        to host: String,
        port: UInt16,
        encrypt: Bool = false,
        compress: Bool = false
    ) async {
        // Map encrypt/compress to proto_opts bitfield
        var protoOpts: UInt8 = 0x00
        if compress {
            protoOpts |= 0x01  // Bit 0: compression
        }
        if encrypt {
            protoOpts |= 0x02  // Bit 1: encryption
        }

        await network.sendProtocol1Packet(
            payload: data,
            protoOpts: protoOpts,
            to: host,
            port: port
        )
        log("📤 Sent binary message to \(host):\(port) (encrypt=\(encrypt), compress=\(compress))", level: .info)
    }

    /// Gracefully shutdown the YX framework
    ///
    /// This will stop listening for messages and clean up resources.
    public func shutdown() async {
        log("🛑 Shutting down YX...", level: .info)
        await network.shutdown()
        log("✅ YX shutdown complete", level: .info)
    }

    /// Return local GUID as hex string for display
    nonisolated public var guidHex: String {
        guid.hexString
    }

    /// Return key as hex string for display
    nonisolated public var keyHex: String {
        key.withUnsafeBytes { Data($0).hexString }
    }
}
