import Foundation
// filename: Protocol1Header.swift

import Primitives

/// Binary Protocol v2.0 Header
///
/// Version 2.0 Changes:
/// - Replaced 1-byte msgID with 2-byte channelID + 4-byte sequence
/// - Buffer key changed from msgID to (channelID, sequence) tuple
/// - Enables channel isolation and virtually unlimited message capacity
public struct Protocol1Header: Sendable {

    public static let size = 16

    public let proto: UInt8        // Protocol ID (0x01 = Binary/Chunked)
    public let protoOpts: UInt8    // Options: 0x00-0x03 (compress/encrypt flags)
    public let channelID: UInt16   // v2.0: Logical channel (0-65535)
    public let sequence: UInt32    // v2.0: Per-channel sequence number
    public let chunkIndex: UInt32  // Chunk position in message
    public let totalChunks: UInt32 // Total chunks in complete message

    public init(
        proto: UInt8,
        protoOpts: UInt8,
        channelID: UInt16,
        sequence: UInt32,
        chunkIndex: UInt32,
        totalChunks: UInt32
    ) {
        self.proto = proto
        self.protoOpts = protoOpts
        self.channelID = channelID
        self.sequence = sequence
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
    }

    public init?(from data: Data) {
        guard data.count >= Self.size else { return nil }
        self.proto = data[0]
        self.protoOpts = data[1]
        self.channelID = UInt16(bigEndian: data[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) })
        self.sequence = UInt32(bigEndian: data[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) })
        self.chunkIndex = UInt32(bigEndian: data[8..<12].withUnsafeBytes { $0.load(as: UInt32.self) })
        self.totalChunks = UInt32(bigEndian: data[12..<16].withUnsafeBytes { $0.load(as: UInt32.self) })
    }

    public func serialize() -> Data {
        var data = Data()
        data.append(proto)
        data.append(protoOpts)
        data.append(channelID.bigEndianBytes)
        data.append(sequence.bigEndianBytes)
        data.append(chunkIndex.bigEndianBytes)
        data.append(totalChunks.bigEndianBytes)
        return data
    }
}

