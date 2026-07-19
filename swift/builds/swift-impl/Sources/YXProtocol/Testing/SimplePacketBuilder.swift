import Foundation
import CryptoKit

// Implements: protocol/specs/architecture/api-contracts.md (SimplePacketBuilder)

/// Synchronous packet builder for test senders.
///
/// Pattern: Build → Send → Exit (no async needed)
public struct SimplePacketBuilder {

    /// Build a Protocol 0 (text/JSON) packet.
    /// Wire format: HMAC(16) + GUID(6) + [0x00] + JSON bytes
    public static func buildTextPacket(
        _ message: [String: Any],
        guid: Data,
        key: Data
    ) throws -> Data {
        let json = try JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
        var payload = Data([0x00])
        payload.append(json)
        let symKey = try Data.symmetricKey(from: key)
        return try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: symKey)
    }

    /// Build Protocol 1 (binary) packets.
    /// Returns: Array of YX-wrapped packets (one per chunk)
    /// Order: compress → encrypt → chunk
    public static func buildBinaryPackets(
        _ data: Data,
        guid: Data,
        key: Data,
        protoOpts: UInt8 = 0x00,
        channelID: UInt16 = 0,
        sequence: UInt32 = 0,
        chunkSize: Int = 1024
    ) throws -> [Data] {
        var processed = data

        if protoOpts & 0x01 != 0 {
            processed = try processed.zlibCompress()
        }
        if protoOpts & 0x02 != 0 {
            let symKey = try Data.symmetricKey(from: key)
            processed = try processed.aesGCMEncrypt(key: symKey)
        }

        let chunks = processed.chunked(size: chunkSize)
        let total = UInt32(chunks.count)
        let symKey = try Data.symmetricKey(from: key)

        return try chunks.enumerated().map { (index, chunk) -> Data in
            var header = Data()
            header.append(0x01) // Protocol ID
            header.append(protoOpts)
            withUnsafeBytes(of: channelID.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: sequence.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt32(index).bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: total.bigEndian) { header.append(contentsOf: $0) }
            let payload = header + chunk
            return try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: symKey)
        }
    }
}

/// Send a single UDP packet synchronously using POSIX sockets.
public func sendUDPPacket(_ packet: Data, to host: String, port: UInt16) throws {
    let sock = socket(AF_INET, SOCK_DGRAM, 0)
    guard sock >= 0 else { throw POSIXError(.ENOTSUP) }
    defer { close(sock) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = inet_addr(host)

    try packet.withUnsafeBytes { ptr in
        let sent = withUnsafePointer(to: addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                sendto(sock, ptr.baseAddress, packet.count, 0, sockAddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if sent < 0 { throw POSIXError(.ENOTSUP) }
    }
}

/// Send multiple UDP packets synchronously.
public func sendUDPPackets(_ packets: [Data], to host: String, port: UInt16) throws {
    let sock = socket(AF_INET, SOCK_DGRAM, 0)
    guard sock >= 0 else { throw POSIXError(.ENOTSUP) }
    defer { close(sock) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = inet_addr(host)

    for packet in packets {
        try packet.withUnsafeBytes { ptr in
            let sent = withUnsafePointer(to: addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                    sendto(sock, ptr.baseAddress, packet.count, 0, sockAddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if sent < 0 { throw POSIXError(.ENOTSUP) }
        }
    }
}
