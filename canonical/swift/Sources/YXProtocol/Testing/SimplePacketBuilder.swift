import Foundation
import CryptoKit

/// Simplified packet builder for testing
///
/// Builds complete YX packets without requiring async/actor infrastructure.
/// Enables simple test senders: build → send → exit.
///
/// CRITICAL: API must match Python implementation exactly for interop testing.
///
/// Traceability:
/// - specs/architecture/api-contracts.md § SimplePacketBuilder API
public struct SimplePacketBuilder {

    /// Build Protocol 0 (Text/JSON-RPC) packet
    /// - Returns: Complete packet ([HMAC(16)] + [GUID(6)] + [0x00] + [JSON])
    public static func buildTextPacket<T: Encodable>(message: T, guid: Data, key: Data) throws -> Data {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)

        var payload = Data(capacity: 1 + jsonData.count)
        payload.append(0x00)
        payload.append(jsonData)

        return try buildPacket(guid: guid, payload: payload, key: key)
    }

    /// Build Protocol 1 (Binary) packets
    /// - Returns: Array of complete packets (one per chunk)
    /// Processing order: compress → encrypt → chunk → build packets
    public static func buildBinaryPackets(
        data: Data,
        guid: Data,
        key: Data,
        protoOpts: UInt8 = 0x00,
        encryptionKey: Data? = nil,
        channelID: UInt16 = 0,
        sequence: UInt32 = 0,
        chunkSize: Int = 1024
    ) throws -> [Data] {
        var processed = data

        // Compress (if protoOpts & 0x01)
        if protoOpts & 0x01 != 0 {
            processed = try processed.zlibCompress()
        }

        // Encrypt (if protoOpts & 0x02)
        if protoOpts & 0x02 != 0 {
            guard let encKey = encryptionKey else {
                throw BuildError.encryptionKeyRequired
            }
            let symmetricKey = try Data.symmetricKey(from: encKey)
            processed = try processed.aesGCMEncrypt(key: symmetricKey)
        }

        // Chunk
        let chunks = processed.chunked(size: chunkSize)
        let totalChunks = UInt32(chunks.count)

        var packets: [Data] = []
        for (index, chunk) in chunks.enumerated() {
            // Build 16-byte header
            var header = Data(capacity: 16)
            header.append(0x01) // Protocol ID
            header.append(protoOpts) // Protocol options
            withUnsafeBytes(of: channelID.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: sequence.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt32(index).bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: totalChunks.bigEndian) { header.append(contentsOf: $0) }

            var payload = Data(capacity: header.count + chunk.count)
            payload.append(header)
            payload.append(chunk)

            let packet = try buildPacket(guid: guid, payload: payload, key: key)
            packets.append(packet)
        }

        return packets
    }

    /// Build complete packet with HMAC ([HMAC(16)] + [GUID(6)] + [payload])
    private static func buildPacket(guid: Data, payload: Data, key: Data) throws -> Data {
        var message = Data(capacity: guid.count + payload.count)
        message.append(guid)
        message.append(payload)

        let hmacKey = SymmetricKey(data: key)
        var hmac = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
        hmac = hmac.prefix(16)

        var packet = Data(capacity: hmac.count + message.count)
        packet.append(hmac)
        packet.append(message)

        return packet
    }

    /// Verify packet HMAC
    public static func verifyPacket(packet: Data, key: Data) -> Bool {
        guard packet.count >= 22 else { // 16 (HMAC) + 6 (GUID)
            return false
        }

        let receivedHMAC = packet.prefix(16)
        let message = Data(packet.suffix(from: packet.startIndex + 16))

        let hmacKey = SymmetricKey(data: key)
        var expectedHMAC = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
        expectedHMAC = expectedHMAC.prefix(16)

        return receivedHMAC == expectedHMAC
    }

    /// Extract GUID from packet
    public static func extractGUID(packet: Data) -> Data? {
        guard packet.count >= 22 else {
            return nil
        }
        return Data(packet[(packet.startIndex + 16)..<(packet.startIndex + 22)])
    }

    /// Extract payload from packet (after HMAC and GUID)
    public static func extractPayload(packet: Data) -> Data? {
        guard packet.count >= 22 else {
            return nil
        }
        return Data(packet.suffix(from: packet.startIndex + 22))
    }
}

/// Build errors
public enum BuildError: Error, CustomStringConvertible {
    case encodingFailed
    case encryptionKeyRequired
    case invalidGUID
    case invalidKey

    public var description: String {
        switch self {
        case .encodingFailed:
            return "Failed to encode message"
        case .encryptionKeyRequired:
            return "Encryption key required when protoOpts includes encryption"
        case .invalidGUID:
            return "Invalid GUID (must be 6 bytes)"
        case .invalidKey:
            return "Invalid key"
        }
    }
}
