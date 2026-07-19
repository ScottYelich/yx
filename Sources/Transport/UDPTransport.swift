import Foundation
// filename: UDPTransport.swift

import Primitives
import CryptoKit

/// Actor-based UDP networking implementation.
///
/// Replaces DispatchQueue-based UnsafeNetworkingCore with proper Swift concurrency.
public actor UDPTransport {
    private var socket: Int32 = -1
    private let guid: Data
    private let defaultKey: SymmetricKey
    private var peerKeys: [Data: SymmetricKey] = [:]
    public let router: ProtocolRouter
    public var processOwnPackets: Bool = false

    // Task management
    private var receiveTask: Task<Void, Never>?
    private var isRunning = false

    // Configuration
    private let maxPacketSize: Int
    private let rateLimiter: RateLimiter?
    private let nonceCache: ReplayProtection?

    public init(
        guid: Data,
        key: SymmetricKey,
        router: ProtocolRouter,
        maxPacketSize: Int = 4096,
        rateLimiter: RateLimiter? = nil,
        nonceCache: ReplayProtection? = nil
    ) {
        self.guid = guid
        self.defaultKey = key
        self.router = router
        self.maxPacketSize = maxPacketSize
        self.rateLimiter = rateLimiter
        self.nonceCache = nonceCache
    }

    deinit {
        if socket >= 0 {
            close(socket)
        }
    }

    /// Starts listening on the specified port
    public func start(port: UInt16) async throws {
        guard !isRunning else {
            throw NetworkingError.bindFailed(port: port)
        }

        socket = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socket >= 0 else {
            throw NetworkingError.socketCreationFailed
        }

        var yes: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        setsockopt(socket, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        setsockopt(socket, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))

        // Socket defaults to blocking mode - recv() will block until data arrives
        // This is efficient: the thread sleeps in kernel until a packet arrives
        // Swift async runtime handles this correctly via thread pool

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_ANY)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard result == 0 else {
            let error = errno
            log("❌ bind() failed with errno=\(error): \(String(cString: strerror(error)))", level: .error)
            throw NetworkingError.bindFailed(port: port)
        }

        isRunning = true
        log("🌐 UDP listening on port \(port)", level: .info)
        log("🔍 Socket \(socket) bound successfully to 0.0.0.0:\(port)", level: .info)

        // Start receive loop DETACHED from this actor's executor.
        // receiveLoop blocks in recvfrom(); if it ran actor-isolated it would starve
        // the actor forever and queued send()/stop() calls would never execute
        // (bug found 2026-07-19: "Sent" was logged but no bytes ever left the socket).
        receiveTask = Task.detached { [self] in
            await receiveLoop(
                socket: socket,
                guid: guid,
                defaultKey: defaultKey,
                router: router,
                maxPacketSize: maxPacketSize,
                rateLimiter: rateLimiter,
                nonceCache: nonceCache
            )
        }
    }

    /// Stops the networking actor gracefully
    public func stop() async {
        isRunning = false
        receiveTask?.cancel()
        await receiveTask?.value
        receiveTask = nil

        if socket >= 0 {
            close(socket)
            socket = -1
        }
    }

    /// Sends a UDP packet
    public func send(_ packet: UDPPacket, to host: String, port: UInt16) {
        guard socket >= 0 else {
            log("⚠️ send() called but socket not initialized (socket=\(socket))", level: .warning)
            return
        }

        if let targetGUID = packet.guid {
            let key = peerKeys[targetGUID] ?? defaultKey
            let keyHex = key.withUnsafeBytes { Data($0).hexString }
            let kind = (peerKeys[targetGUID] != nil) ? "derived" : "default"
            log("📤 Sending to \(targetGUID.hexString) — using \(kind) key: \(keyHex)", level: .debug)
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let data = packet.bytes
        log("📤 Sending \(data.count) bytes from socket \(socket) to \(host):\(port)", level: .info)

        let bytesSent = data.withUnsafeBytes { buffer in
            withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(socket, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        if bytesSent < 0 {
            let error = errno
            log("❌ sendto() failed: errno=\(error) - \(String(cString: strerror(error)))", level: .error)
        } else {
            log("✅ Sent \(bytesSent) bytes successfully", level: .info)
        }
    }

    /// Sets a key for a specific peer
    public func setKey(for guid: Data, key: SymmetricKey) {
        peerKeys[guid] = key
    }

    /// Gets key for a peer
    public func key(for guid: Data) -> SymmetricKey? {
        peerKeys[guid]
    }

    /// Returns local GUID
    public var localGUID: Data {
        guid
    }

    /// Returns all peer keys
    public func allKeys() -> [Data: SymmetricKey] {
        peerKeys
    }

    // MARK: - Private

    // nonisolated: must run OFF the actor executor — the blocking recvfrom() would
    // otherwise hold the actor and starve every queued send()/stop() call.
    nonisolated private func receiveLoop(
        socket: Int32,
        guid: Data,
        defaultKey: SymmetricKey,
        router: ProtocolRouter,
        maxPacketSize: Int,
        rateLimiter: RateLimiter?,
        nonceCache: ReplayProtection?
    ) async {
        log("🔵 UDP receive loop started for socket \(socket)", level: .info)
        var buffer = [UInt8](repeating: 0, count: maxPacketSize)

        // Loop until task is cancelled
        while !Task.isCancelled {
            // Use recvfrom() to get source address
            var addr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let received = withUnsafeMutablePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    recvfrom(socket, &buffer, buffer.count, 0, sockaddrPtr, &addrLen)
                }
            }

            // Check for errors or shutdown
            guard received > 0 else {
                if received == 0 {
                    log("🛑 recvfrom() returned 0 - socket closed", level: .info)
                    break
                }

                let error = errno
                if error == EINTR {
                    // Interrupted by signal, retry
                    continue
                }

                log("❌ recvfrom() error: \(error) - \(String(cString: strerror(error)))", level: .error)
                break
            }

            // Extract source IP and port
            let sourceIP = String(cString: inet_ntoa(addr.sin_addr))
            let sourcePort = UInt16(bigEndian: addr.sin_port)

            log("📥 Received \(received) bytes from \(sourceIP):\(sourcePort) on socket \(socket)", level: .info)

            let data = Data(buffer[0..<received])
            let packetGUID = data.count >= 22 ? data.subdata(in: 16..<22) : nil

            // Get key for this packet - hop into the actor for the peerKeys lookup
            let key: SymmetricKey
            if let guid = packetGUID, let peerKey = await self.key(for: guid) {
                key = peerKey
                let keyHex = key.withUnsafeBytes { Data($0).hexString }
                log("🧪 [UDPNetworking] Using derived key for \(guid.hexString): \(keyHex)", level: .debug)
            } else {
                key = defaultKey
                if let guid = packetGUID {
                    let keyHex = key.withUnsafeBytes { Data($0).hexString }
                    log("🧪 [UDPNetworking] Using default key for \(guid.hexString): \(keyHex)", level: .debug)
                }
            }

            let packet = UDPPacketUtils.parse(data, key: key, sourceIP: sourceIP, sourcePort: sourcePort)

            log("📦 Parsed packet - GUID: \(packet.guid?.hexString ?? "nil"), Errors: \(packet.errors)", level: .info)

            // Actor-isolated property — explicit hop from the nonisolated loop
            let shouldProcess = await self.processOwnPackets
            if packet.guid == guid && !shouldProcess {
                log("🛑 Skipped self-sent packet with GUID \(guid.hexString)", level: .info)
                continue
            }

            // Rate limiting check
            if let limiter = rateLimiter {
                let peerIdentifier = packet.guid?.hexString ?? "unknown"
                let allowed = await limiter.checkLimit(for: peerIdentifier)
                if !allowed {
                    log("⚠️ Rate limit exceeded for peer: \(peerIdentifier)", level: .warning)
                    continue
                }
            }

            // Replay protection check (using packet hash as pseudo-nonce)
            if let cache = nonceCache {
                // Create a pseudo-nonce from packet GUID + HMAC (first 16 bytes)
                let pseudoNonce = (packet.guid ?? Data()) + (packet.hmac ?? Data()).prefix(16)
                let allowed = await cache.checkAndRecord(pseudoNonce)
                if !allowed {
                    log("⚠️ Replay attack detected for peer: \(packet.guid?.hexString ?? "unknown")", level: .warning)
                    continue
                }
            }

            // Create a dummy Networking for compatibility (will be refactored in P1)
            let networking = Networking(guid: guid, key: defaultKey, router: router)
            await router.route(packet, key: key, via: networking)
        }

        log("🛑 UDP receive loop exited", level: .info)
    }
}
