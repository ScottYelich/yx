import Foundation
// filename: BinaryProtocol.swift

import Primitives
import CryptoKit
import Compression

/// Actor responsible for handling binary protocol payloads (Protocol 1) - v2.0
///
/// Version 2.0 Changes:
/// - Replaced 1-byte msgID with 2-byte channelID + 4-byte sequence
/// - Buffer key changed from msgID to (channelID, sequence) tuple
/// - Enables channel isolation and virtually unlimited message capacity
public actor BinaryProtocol: ProtocolHandler {

    public func proto() async -> UInt8 { ProtocolID.binary.rawValue }

    public let core = ProtocolActorCore(proto: 0x01)

    /// v2.0: Buffer key is now (channelID, sequence) tuple
    private var buffers: [BufferKey: BufferWithTimeout] = [:]

    /// v2.0: Per-channel sequence counters
    private var sequenceCounters: [UInt16: UInt32] = [:]

    /// Deduplication cache: tracks processed (channelID, sequence) pairs with timestamps
    private var processedMessages: [BufferKey: Date] = [:]

    private var sendAPI: (@Sendable (Data, String, UInt16) async -> Void)?

    /// Timeout for incomplete message buffers
    private let bufferTimeout: TimeInterval

    /// Chunk size for splitting large payloads
    private let chunkSize: Int

    /// Time window for message deduplication
    private let dedupWindow: TimeInterval

    /// Symmetric key for encryption/decryption
    private var key: SymmetricKey?

    public init(
        chunkSize: Int = 1024,
        bufferTimeout: TimeInterval = 60.0,
        dedupWindow: TimeInterval = 5.0
    ) {
        self.chunkSize = chunkSize
        self.bufferTimeout = bufferTimeout
        self.dedupWindow = dedupWindow
    }

    /// v2.0: Buffer key type for (channelID, sequence) tuple
    private struct BufferKey: Hashable {
        let channelID: UInt16
        let sequence: UInt32
    }

    /// Set the encryption key for this protocol
    public func setKey(_ key: SymmetricKey) async {
        self.key = key
    }

    /// Install a send function for outbound chunked messages.
    public func installSendAPI(_ send: @escaping @Sendable (Data, String, UInt16) async -> Void) async {
        self.sendAPI = send
    }

    /// Set a receive handler for fully reassembled and decoded payloads.
    public func setReceiveHandler(_ handler: @escaping @Sendable (Data) async -> Void) async {
        core.setReceiveHandler(handler)
    }

    /// Ingest a single chunk of a Protocol 1 binary message (v2.0 with channelID + sequence).
    public func ingest(_ packet: UDPPacket, key: SymmetricKey) async {
        // Clean up stale buffers periodically
        cleanupStaleBuffers()

        let headerResult = Self.parseProtocol1Header(from: packet)

        let header: Protocol1Header
        switch headerResult {
        case .success(let h):
            header = h
        case .failure(let error):
            log("❌ \(error.localizedDescription)", level: .error)
            return
        }

        // v2.0: Buffer key is (channelID, sequence) tuple
        let bufferKey = BufferKey(channelID: header.channelID, sequence: header.sequence)

        // DEDUPLICATION: Check if we've already processed this message
        let now = Date()
        if let lastProcessed = processedMessages[bufferKey] {
            if now.timeIntervalSince(lastProcessed) < dedupWindow {
                log("🔍 Ignoring duplicate message ch=\(header.channelID) seq=\(header.sequence)", level: .debug)
                return
            }
        }

        // Clean up old entries from dedup cache
        processedMessages = processedMessages.filter { _, timestamp in
            now.timeIntervalSince(timestamp) < dedupWindow
        }

        if buffers[bufferKey] == nil {
            buffers[bufferKey] = BufferWithTimeout(
                buffer: MessageBuffer(header: header),
                createdAt: Date()
            )
        }

        guard var bufferWithTimeout = buffers[bufferKey] else { return }
        var buffer = bufferWithTimeout.buffer

        let chunkData = Data(packet.bytesAfterGUID.dropFirst(Protocol1Header.size))

        if buffer.chunks[header.chunkIndex] == nil {
            // Store raw chunk data WITHOUT decrypting
            // Decryption happens after reassembly (encrypt-then-chunk approach)
            buffer.chunks[header.chunkIndex] = chunkData
        } else {
            log("⚠️ Duplicate chunk \(header.chunkIndex) for ch=\(header.channelID) seq=\(header.sequence) — ignoring", level: .warning)
        }

        if buffer.chunks.count == Int(header.totalChunks) {
            var fullPayload = Data()
            for i in 0..<header.totalChunks {
                guard let part = buffer.chunks[i] else {
                    log("❌ Missing chunk \(i) for ch=\(header.channelID) seq=\(header.sequence)", level: .error)
                    buffers.removeValue(forKey: bufferKey)
                    return
                }
                fullPayload.append(part)
            }

            log("🔍 Reassembled ch=\(header.channelID) seq=\(header.sequence) payload: \(fullPayload.count) bytes", level: .debug)

            // Decrypt FULL payload if encryption bit is set (encrypt-then-chunk approach)
            var decodedPayload = fullPayload
            if Self.shouldEncrypt(protoOpts: header.protoOpts) {
                guard let decrypted = try? fullPayload.decryptedAES(using: key) else {
                    log("❌ Failed to decrypt full reassembled payload", level: .error)
                    buffers.removeValue(forKey: bufferKey)
                    return
                }
                decodedPayload = decrypted
                log("🔐 Decrypted full payload: \(fullPayload.count) → \(decodedPayload.count) bytes", level: .debug)
            }

            // Decompress if needed
            if let final = Self.decodePayload(decodedPayload, using: header.protoOpts) {
                await self.core.handlePayload(final)
            } else {
                log("❌ Failed to decode Protocol1 payload", level: .error)
            }

            buffers.removeValue(forKey: bufferKey)

            // Mark as processed (for deduplication)
            processedMessages[bufferKey] = Date()
        } else {
            bufferWithTimeout.buffer = buffer
            buffers[bufferKey] = bufferWithTimeout
        }
    }

    /// Send a payload with given options, encoded then chunked (v2.0 with channelID + sequence).
    /// Encoding order: compress (if bit 0 set) → encrypt (if bit 1 set) → chunk → send
    public func send(
        payload: Data,
        protoOpts: UInt8,
        to host: String,
        port: UInt16,
        channelID: UInt16 = 1
    ) async {
        guard let send = sendAPI else {
            log("❌ BinaryProtocol: sendAPI not installed", level: .error)
            return
        }

        guard let encryptionKey = key else {
            log("❌ BinaryProtocol: encryption key not set", level: .error)
            return
        }

        // v2.0: Get next sequence number for this channel
        let sequence = sequenceCounters[channelID] ?? 0
        sequenceCounters[channelID] = (sequence &+ 1)  // Wraparound at 2^32

        // Step 1: Encode the full payload (compress/encrypt based on protoOpts)
        guard let encodedPayload = Self.encodePayload(payload, using: protoOpts, key: encryptionKey) else {
            log("❌ BinaryProtocol: Failed to encode payload", level: .error)
            return
        }

        log("📤 Encoded payload: \(payload.count) → \(encodedPayload.count) bytes (protoOpts: 0x\(String(format: "%02X", protoOpts)))", level: .debug)

        // Step 2: Chunk the encoded payload
        let chunks = encodedPayload.chunked(into: chunkSize)

        // Step 3: Send each chunk
        for (i, chunk) in chunks.enumerated() {
            let packet = UDPPacketUtils.buildProtocol1Chunked(
                guid: Data(), // Filled by caller's wrapper with GUID
                proto: await self.proto(),
                protoOpts: protoOpts,
                channelID: channelID,
                sequence: sequence,
                chunkIndex: UInt32(i),
                totalChunks: UInt32(chunks.count),
                payload: chunk, // Already encoded
                key: encryptionKey
            )
            // Send only the payload part (header + chunk), not the full packet with HMAC+GUID
            // The sendAPI will add HMAC+GUID
            await send(packet.bytesAfterGUID, host, port)
        }

        log("📤 BinaryProtocol: Sent \(chunks.count) chunk(s) ch=\(channelID) seq=\(sequence) opts=0x\(String(format: "%02X", protoOpts)) to \(host):\(port)", level: .info)
    }

    /// Required by ProtocolHandler
    public func send(_ payload: Data, to host: String, port: UInt16) async {
        await send(payload: payload, protoOpts: 0x00, to: host, port: port)
    }

    /// Extract and decode the payload from a single-chunk packet.
    /// Note: This assumes the packet contains the complete message (totalChunks = 1)
    public func extractPayload(from packet: UDPPacket, key: SymmetricKey) async -> Data? {
        guard case .success(let header) = Self.parseProtocol1Header(from: packet) else {
            return nil
        }

        let chunkData = Data(packet.bytesAfterGUID.dropFirst(Protocol1Header.size))

        // Decrypt if encryption bit is set (encrypt-then-chunk approach)
        // For single-chunk messages, the chunk IS the full encrypted payload
        var decodedPayload = chunkData
        if Self.shouldEncrypt(protoOpts: header.protoOpts) {
            guard let decrypted = try? chunkData.decryptedAES(using: key) else {
                log("❌ Failed to decrypt payload in extractPayload", level: .error)
                return nil
            }
            decodedPayload = decrypted
        }

        // Decompress if needed
        return Self.decodePayload(decodedPayload, using: header.protoOpts)
    }

    // MARK: - Internal Helpers

    /// Check if compression bit is set in protoOpts
    public static func shouldCompress(protoOpts: UInt8) -> Bool {
        return (protoOpts & 0x01) != 0
    }

    /// Check if encryption bit is set in protoOpts
    public static func shouldEncrypt(protoOpts: UInt8) -> Bool {
        return (protoOpts & 0x02) != 0
    }

    /// Encode payload for sending: compress then encrypt based on protoOpts
    /// - Parameters:
    ///   - payload: Raw payload data
    ///   - protoOpts: Protocol options (bit 0 = compression, bit 1 = encryption)
    ///   - key: Symmetric key for encryption (used only if encryption bit is set)
    /// - Returns: Encoded payload or nil if encoding fails
    private static func encodePayload(_ payload: Data, using protoOpts: UInt8, key: SymmetricKey) -> Data? {
        var result = payload

        // Step 1: Compress if requested (bit 0)
        if shouldCompress(protoOpts: protoOpts) {
            guard let compressed = result.compressed(using: COMPRESSION_ZLIB) else {
                log("❌ Failed to compress payload", level: .error)
                return nil
            }
            result = compressed
            log("🗜️ Compressed payload: \(payload.count) → \(result.count) bytes", level: .debug)
        }

        // Step 2: Encrypt if requested (bit 1)
        if shouldEncrypt(protoOpts: protoOpts) {
            guard let encrypted = result.encryptedAES(using: key) else {
                log("❌ Failed to encrypt payload", level: .error)
                return nil
            }
            result = encrypted
            log("🔐 Encrypted payload: \(result.count - 28) → \(result.count) bytes", level: .debug)
        }

        return result
    }

    /// Removes buffers that have exceeded the timeout period
    private func cleanupStaleBuffers() {
        let now = Date()
        let before = buffers.count

        buffers = buffers.filter { _, value in
            now.timeIntervalSince(value.createdAt) < bufferTimeout
        }

        let after = buffers.count
        if before != after {
            log("🧹 Cleaned up \(before - after) stale buffer(s) from BinaryProtocol", level: .info)
        }
    }

    /// Decode payload from received data: decompress based on protoOpts
    /// Note: Decryption must be done BEFORE calling this (handled in ingest/extractPayload)
    /// - Parameters:
    ///   - payload: Already-decrypted payload data
    ///   - protoOpts: Protocol options (bit 0 = compression, bit 1 = encryption)
    /// - Returns: Decoded payload or nil if decoding fails
    private static func decodePayload(_ payload: Data, using protoOpts: UInt8) -> Data? {
        var result = payload

        // Check if compression was used (bit 0)
        if shouldCompress(protoOpts: protoOpts) {
            guard let decompressed = result.decompressed(using: COMPRESSION_ZLIB) else {
                log("❌ Failed to decompress payload", level: .error)
                return nil
            }
            result = decompressed
            log("🗜️ Decompressed payload: \(payload.count) → \(result.count) bytes", level: .debug)
        }

        return result
    }

    private static func parseProtocol1Header(from packet: UDPPacket) -> Result<Protocol1Header, ProtocolError> {
        let raw = Data(packet.bytesAfterGUID.prefix(Protocol1Header.size))
        guard raw.count >= Protocol1Header.size else {
            return .failure(.parsingFailed(
                protocol: "Protocol1",
                reason: "Insufficient data: expected \(Protocol1Header.size), got \(raw.count)"
            ))
        }
        guard let header = Protocol1Header(from: raw) else {
            return .failure(.parsingFailed(
                protocol: "Protocol1",
                reason: "Invalid header format"
            ))
        }
        return .success(header)
    }

    private struct MessageBuffer {
        let header: Protocol1Header
        var chunks: [UInt32: Data] = [:]
    }

    private struct BufferWithTimeout {
        var buffer: MessageBuffer
        let createdAt: Date
    }
}

