import Foundation
import CryptoKit

/// Protocol 1: Binary (Chunked) handler
///
/// Header format (16 bytes):
/// [proto(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] +
/// [chunkIndex(4)] + [totalChunks(4)]
///
/// protoOpts flags:
/// - 0x00: Base (no compression, no encryption)
/// - 0x01: Compressed (ZLIB)
/// - 0x02: Encrypted (AES-256-GCM)
/// - 0x03: Both (compress then encrypt)
actor BinaryProtocol {

    static let protocolID: UInt8 = 0x01
    static let headerSize = 16

    struct ProtoOpts: OptionSet {
        let rawValue: UInt8
        static let compressed = ProtoOpts(rawValue: 0x01)
        static let encrypted = ProtoOpts(rawValue: 0x02)
    }

    /// Buffer key: (channelID, sequence). A struct (not a tuple) so it is
    /// Hashable and usable as a Dictionary key.
    struct BufferKey: Hashable {
        let channelID: UInt16
        let sequence: UInt32
    }

    private let key: SymmetricKey?
    private let onMessage: (Data) async -> Void
    private let chunkSize: Int
    private let bufferTimeout: TimeInterval

    private var incompleteMessages: [BufferKey: BufferEntry] = [:]
    private var processedMessages: [BufferKey: Date] = [:]
    private var sequenceCounters: [UInt16: UInt32] = [:]

    init(key: Data? = nil,
         onMessage: @escaping (Data) async -> Void,
         chunkSize: Int = 1024,
         bufferTimeout: TimeInterval = 60.0) {
        self.key = key != nil ? try? Data.symmetricKey(from: key!) : nil
        self.onMessage = onMessage
        self.chunkSize = chunkSize
        self.bufferTimeout = bufferTimeout
    }

    /// Handle incoming binary protocol payload (header + data)
    func handle(payload: Data) async throws {
        guard payload.count >= Self.headerSize else {
            throw ProtocolError.invalidFormat("Payload too small for header")
        }
        guard payload[payload.startIndex] == Self.protocolID else {
            throw ProtocolError.invalidFormat("Expected protocol ID 0x01")
        }

        let header = try parseHeader(payload)
        let data = Data(payload.suffix(from: payload.startIndex + Self.headerSize))

        try await processChunk(header: header, data: data)
        cleanupBuffers()
    }

    private func processChunk(header: BinaryHeader, data: Data) async throws {
        let key = BufferKey(channelID: header.channelID, sequence: header.sequence)

        if processedMessages[key] != nil {
            return  // duplicate
        }

        // Single chunk message - process immediately
        if header.totalChunks == 1 {
            let message = try await processMessage(data: data, protoOpts: header.protoOpts)
            await onMessage(message)
            processedMessages[key] = Date()
            return
        }

        // Multi-chunk message - buffer
        if var entry = incompleteMessages[key] {
            entry.chunks[header.chunkIndex] = data
            incompleteMessages[key] = entry

            if entry.isComplete {
                let reassembled = try entry.reassemble()
                let message = try await processMessage(data: reassembled, protoOpts: header.protoOpts)
                await onMessage(message)
                processedMessages[key] = Date()
                incompleteMessages.removeValue(forKey: key)
            }
        } else {
            var chunks: [UInt32: Data] = [:]
            chunks[header.chunkIndex] = data

            let entry = BufferEntry(
                chunks: chunks,
                totalChunks: header.totalChunks,
                timestamp: Date()
            )
            incompleteMessages[key] = entry
        }
    }

    /// Process complete message (decrypt → decompress)
    private func processMessage(data: Data, protoOpts: UInt8) async throws -> Data {
        var result = data
        let opts = ProtoOpts(rawValue: protoOpts)

        if opts.contains(.encrypted) {
            guard let key = key else {
                throw ProtocolError.invalidFormat("Encryption key not provided")
            }
            result = try result.aesGCMDecrypt(key: key)
        }

        if opts.contains(.compressed) {
            result = try result.zlibDecompress()
        }

        return result
    }

    private func cleanupBuffers() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-bufferTimeout)
        incompleteMessages = incompleteMessages.filter { _, entry in entry.timestamp > cutoff }
        processedMessages = processedMessages.filter { _, timestamp in timestamp > cutoff }
    }

    /// Encode message for sending (compress → encrypt → chunk).
    /// - Returns: Array of encoded packets (one per chunk)
    func encode(data: Data, protoOpts: UInt8 = 0x00, channelID: UInt16 = 0) throws -> [Data] {
        let sequence = nextSequence(for: channelID)

        var processed = data
        let opts = ProtoOpts(rawValue: protoOpts)

        if opts.contains(.compressed) {
            processed = try processed.zlibCompress()
        }

        if opts.contains(.encrypted) {
            guard let key = key else {
                throw ProtocolError.invalidFormat("Encryption key not provided")
            }
            processed = try processed.aesGCMEncrypt(key: key)
        }

        let chunks = processed.chunked(size: chunkSize)
        let totalChunks = UInt32(chunks.count)

        var packets: [Data] = []
        for (index, chunk) in chunks.enumerated() {
            let header = BinaryHeader(
                proto: Self.protocolID,
                protoOpts: protoOpts,
                channelID: channelID,
                sequence: sequence,
                chunkIndex: UInt32(index),
                totalChunks: totalChunks
            )
            let packet = buildPacket(header: header, data: chunk)
            packets.append(packet)
        }

        return packets
    }

    private func nextSequence(for channelID: UInt16) -> UInt32 {
        let current = sequenceCounters[channelID, default: 0]
        sequenceCounters[channelID] = current + 1
        return current
    }

    private func parseHeader(_ payload: Data) throws -> BinaryHeader {
        guard payload.count >= Self.headerSize else {
            throw ProtocolError.invalidFormat("Payload too small")
        }

        // Rebase to a zero-based contiguous buffer for safe offset loads.
        let h = Data(payload.prefix(Self.headerSize))
        let proto = h[0]
        let protoOpts = h[1]
        let channelID = h.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }.bigEndian
        let sequence = h.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }.bigEndian
        let chunkIndex = h.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }.bigEndian
        let totalChunks = h.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt32.self) }.bigEndian

        return BinaryHeader(
            proto: proto,
            protoOpts: protoOpts,
            channelID: channelID,
            sequence: sequence,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks
        )
    }

    private func buildPacket(header: BinaryHeader, data: Data) -> Data {
        var packet = Data(capacity: Self.headerSize + data.count)
        packet.append(header.proto)
        packet.append(header.protoOpts)
        withUnsafeBytes(of: header.channelID.bigEndian) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: header.sequence.bigEndian) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: header.chunkIndex.bigEndian) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: header.totalChunks.bigEndian) { packet.append(contentsOf: $0) }
        packet.append(data)
        return packet
    }
}

/// Binary protocol header (16 bytes)
struct BinaryHeader {
    let proto: UInt8
    let protoOpts: UInt8
    let channelID: UInt16
    let sequence: UInt32
    let chunkIndex: UInt32
    let totalChunks: UInt32
}
