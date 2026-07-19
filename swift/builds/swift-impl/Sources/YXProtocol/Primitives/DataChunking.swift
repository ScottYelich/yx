import Foundation

// Implements: protocol/specs/technical/yx-protocol-spec.md § Data Chunking

// MARK: - Data Chunking

extension Data {
    /// Split data into fixed-size chunks.
    /// - Parameter chunkSize: Max bytes per chunk (default 1024)
    /// - Returns: Array of chunks
    public func chunked(size chunkSize: Int = 1024) -> [Data] {
        guard !isEmpty else { return [] }
        guard chunkSize > 0 else { return [self] }
        var chunks: [Data] = []
        var offset = 0
        while offset < count {
            let end = Swift.min(offset + chunkSize, count)
            chunks.append(self[offset..<end])
            offset = end
        }
        return chunks
    }
}

// MARK: - BufferEntry

public enum ChunkingError: Error, CustomStringConvertible {
    case incompleteMessage
    case missingChunk(UInt32)

    public var description: String {
        switch self {
        case .incompleteMessage: return "Not all chunks received"
        case .missingChunk(let i): return "Missing chunk \(i)"
        }
    }
}

/// Buffer for incomplete chunked messages.
public struct BufferEntry {
    public var chunks: [UInt32: Data]
    public let totalChunks: UInt32
    public let timestamp: Date

    public init(chunks: [UInt32: Data], totalChunks: UInt32, timestamp: Date) {
        self.chunks = chunks
        self.totalChunks = totalChunks
        self.timestamp = timestamp
    }

    public var isComplete: Bool { chunks.count == Int(totalChunks) }

    /// Reassemble chunks in order.
    public func reassemble() throws -> Data {
        guard isComplete else { throw ChunkingError.incompleteMessage }
        var result = Data()
        for i in 0..<totalChunks {
            guard let chunk = chunks[i] else { throw ChunkingError.missingChunk(i) }
            result.append(chunk)
        }
        return result
    }
}
