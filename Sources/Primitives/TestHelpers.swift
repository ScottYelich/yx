import Foundation
import CryptoKit
import Compression

// MARK: - Test Configuration

/// Configuration helpers for test environments
public struct TestConfig {

    /// Get test port from environment or default to 49999
    /// Reads TEST_YX_PORT env var
    public static var testPort: UInt16 {
        if let portStr = ProcessInfo.processInfo.environment["TEST_YX_PORT"],
           let port = UInt16(portStr) {
            return port
        }
        return 49999  // Default test port (NOT 50000 - that's production)
    }

    /// Get shared test key path
    public static var testKeyPath: String {
        // Relative to repository root
        "etc/shared_key.txt"
    }
}

// MARK: - Simple Packet Building (Non-Actor)

/// Simplified packet building for tests and utilities
/// Pure functions - no actors, no async, direct use of existing UDPPacketUtils
public struct SimplePacketBuilder {

    /// Build Protocol 0 (Text/JSON) packet ready to send
    /// - Parameters:
    ///   - message: JSON-serializable dictionary
    ///   - guid: 6-byte peer GUID
    ///   - key: HMAC-SHA256 key
    /// - Returns: Complete packet bytes ready for sendto()
    /// - Throws: JSONSerialization errors
    public static func buildTextPacket(
        message: [String: Any],
        guid: Data,
        key: SymmetricKey
    ) throws -> Data {
        // 1. Serialize JSON — this IS the Protocol 0 payload
        // (no marker byte: text is sniff-routed, first payload byte >= 32)
        let payload = try JSONSerialization.data(withJSONObject: message, options: [])

        // 3. Use existing UDPPacketUtils to build with HMAC
        // Note: UDPPacketUtils is in Transport module, need to import it
        // For now, implement HMAC directly to avoid circular dependencies

        // Pad GUID to 6 bytes
        let trimmedGUID = guid.prefix(6)
        let paddedGUID = trimmedGUID + Data(repeating: 0, count: max(0, 6 - trimmedGUID.count))

        // Calculate HMAC over (GUID + payload)
        let hmacInput = paddedGUID + payload
        let hmac = HMAC<SHA256>.authenticationCode(for: hmacInput, using: key)
        let hmacBytes = Data(hmac.prefix(16))  // First 16 bytes

        // 4. Assemble packet: [HMAC(16)] + [GUID(6)] + [payload]
        var packet = Data()
        packet.append(hmacBytes)   // 16 bytes
        packet.append(paddedGUID)  // 6 bytes
        packet.append(payload)     // JSON length

        return packet
    }

    /// Build Protocol 0 packet from pre-serialized JSON data
    public static func buildTextPacket(
        jsonData: Data,
        guid: Data,
        key: SymmetricKey
    ) -> Data {
        // Protocol 0 payload is the raw JSON bytes (sniff-routed, no marker byte)
        let payload = jsonData

        // Pad GUID to 6 bytes
        let trimmedGUID = guid.prefix(6)
        let paddedGUID = trimmedGUID + Data(repeating: 0, count: max(0, 6 - trimmedGUID.count))

        // Calculate HMAC over (GUID + payload)
        let hmacInput = paddedGUID + payload
        let hmac = HMAC<SHA256>.authenticationCode(for: hmacInput, using: key)
        let hmacBytes = Data(hmac.prefix(16))

        // Assemble packet
        var packet = Data()
        packet.append(hmacBytes)
        packet.append(paddedGUID)
        packet.append(payload)

        return packet
    }

    /// Build Protocol 1 (Binary/Chunked) packet(s)
    ///
    /// - Parameters:
    ///   - data: Binary data to send
    ///   - guid: 6-byte GUID
    ///   - key: Symmetric key for HMAC and encryption
    ///   - protoOpts: Protocol options (0x00-0x03)
    ///                0x00 = No compression/encryption
    ///                0x01 = Compression
    ///                0x02 = Encryption
    ///                0x03 = Both
    ///   - channelID: Logical channel (0-65535, default=1)
    ///   - sequence: Message sequence number (0-2^32-1)
    ///   - chunkSize: Maximum chunk size (default=1024)
    /// - Returns: Array of complete packets (one per chunk)
    public static func buildBinaryPacket(
        data: Data,
        guid: Data,
        key: SymmetricKey,
        protoOpts: UInt8 = 0x00,
        channelID: UInt16 = 1,
        sequence: UInt32 = 0,
        chunkSize: Int = 1024
    ) throws -> [Data] {
        var encodedData = data

        // Step 1: Apply compression if requested (bit 0)
        if (protoOpts & 0x01) != 0 {
            guard let compressed = encodedData.compressed(using: COMPRESSION_ZLIB) else {
                throw UDPSendError.invalidHost // Compression failed
            }
            encodedData = compressed
        }

        // Step 2: Apply encryption if requested (bit 1)
        if (protoOpts & 0x02) != 0 {
            guard let encrypted = encodedData.encryptedAES(using: key) else {
                throw UDPSendError.invalidHost // Encryption failed
            }
            encodedData = encrypted
        }

        // Step 1: Chunk the data
        var chunks: [Data] = []
        var offset = 0
        while offset < encodedData.count {
            let end = min(offset + chunkSize, encodedData.count)
            let chunk = encodedData[offset..<end]
            chunks.append(Data(chunk))
            offset = end
        }

        let totalChunks = UInt32(chunks.count)

        // Step 2: Build packets with headers
        var packets: [Data] = []
        let trimmedGUID = guid.prefix(6)
        let paddedGUID = trimmedGUID + Data(repeating: 0, count: max(0, 6 - trimmedGUID.count))

        for (index, chunk) in chunks.enumerated() {
            let chunkIndex = UInt32(index)

            // Build payload header (Protocol 1 format)
            // [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] +
            // [chunkIndex(4)] + [totalChunks(4)]
            var payload = Data()
            payload.append(0x01)  // protoID
            payload.append(protoOpts)  // protoOpts

            // Add channelID (2 bytes, big-endian)
            var channelBE = channelID.bigEndian
            payload.append(Data(bytes: &channelBE, count: 2))

            // Add sequence (4 bytes, big-endian)
            var sequenceBE = sequence.bigEndian
            payload.append(Data(bytes: &sequenceBE, count: 4))

            // Add chunkIndex (4 bytes, big-endian)
            var chunkIndexBE = chunkIndex.bigEndian
            payload.append(Data(bytes: &chunkIndexBE, count: 4))

            // Add totalChunks (4 bytes, big-endian)
            var totalChunksBE = totalChunks.bigEndian
            payload.append(Data(bytes: &totalChunksBE, count: 4))

            // Add chunk data
            payload.append(chunk)

            // Calculate HMAC over GUID + payload
            let hmacInput = paddedGUID + payload
            let hmac = HMAC<SHA256>.authenticationCode(for: hmacInput, using: key)
            let hmacBytes = Data(hmac.prefix(16))

            // Assemble: [HMAC(16)] + [GUID(6)] + [payload]
            var packet = Data()
            packet.append(hmacBytes)
            packet.append(paddedGUID)
            packet.append(payload)

            packets.append(packet)
        }

        return packets
    }
}

// MARK: - Synchronous UDP Send (Non-Actor)

public enum UDPSendError: Error {
    case socketCreationFailed
    case sendFailed(bytesRequested: Int, bytesSent: Int)
    case invalidHost
}

/// Send UDP packet synchronously using BSD sockets
/// NO actors, NO async - direct syscall
/// - Parameters:
///   - packet: Complete packet bytes to send
///   - host: Destination IP or "255.255.255.255" for broadcast
///   - port: Destination port (NOT HARDCODED!)
/// - Throws: UDPSendError if send fails
public func sendUDPPacket(
    _ packet: Data,
    to host: String,
    port: UInt16
) throws {
    // Create UDP socket
    let sock = socket(AF_INET, SOCK_DGRAM, 0)
    guard sock >= 0 else {
        throw UDPSendError.socketCreationFailed
    }
    defer { close(sock) }

    // Enable broadcast if needed
    if host == "255.255.255.255" {
        var broadcast: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
    }

    // Build destination address
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian

    if host == "255.255.255.255" {
        addr.sin_addr.s_addr = INADDR_BROADCAST
    } else {
        addr.sin_addr.s_addr = inet_addr(host)
        guard addr.sin_addr.s_addr != INADDR_NONE else {
            throw UDPSendError.invalidHost
        }
    }

    // Send packet (SYNCHRONOUS!)
    let bytesSent = packet.withUnsafeBytes { bufferPtr in
        withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(sock, bufferPtr.baseAddress, packet.count, 0,
                       sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    guard bytesSent == packet.count else {
        throw UDPSendError.sendFailed(bytesRequested: packet.count, bytesSent: bytesSent)
    }
}

/// Send multiple UDP packets synchronously (for chunked binary protocol)
/// - Parameters:
///   - packets: Array of packet bytes to send
///   - host: Destination IP or "255.255.255.255" for broadcast
///   - port: Destination port
/// - Throws: UDPSendError if any send fails
public func sendUDPPackets(
    _ packets: [Data],
    to host: String,
    port: UInt16
) throws {
    for packet in packets {
        try sendUDPPacket(packet, to: host, port: port)
    }
}

// MARK: - Convenience Helpers
// Note: Data hex extensions are in Data+Hex.swift (hexString, init?(hex:))
