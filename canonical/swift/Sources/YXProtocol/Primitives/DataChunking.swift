import Foundation

extension Data {

    /// Split data into chunks of specified size
    /// - Parameter chunkSize: Maximum chunk size (default 1024)
    /// - Returns: Array of data chunks
    public func chunked(size chunkSize: Int = 1024) -> [Data] {
        guard !isEmpty else {
            return []
        }

        guard chunkSize > 0 else {
            return [self]
        }

        var chunks: [Data] = []
        var offset = 0

        while offset < count {
            let end = Swift.min(offset + chunkSize, count)
            let chunk = self[startIndex + offset ..< startIndex + end]
            chunks.append(Data(chunk))
            offset = end
        }

        return chunks
    }
}

/// Buffer entry for incomplete messages
struct BufferEntry {
    /// Received chunks (indexed by chunkIndex)
    var chunks: [UInt32: Data]

    /// Total number of chunks expected
    let totalChunks: UInt32

    /// Timestamp when first chunk received
    let timestamp: Date

    /// Check if message is complete
    var isComplete: Bool {
        return chunks.count == Int(totalChunks)
    }

    /// Reassemble chunks into complete message
    /// - Returns: Complete message data
    /// - Throws: ChunkingError if chunks are missing
    func reassemble() throws -> Data {
        guard isComplete else {
            throw ChunkingError.incompleteMessage
        }

        var result = Data()
        for index in 0..<totalChunks {
            guard let chunk = chunks[index] else {
                throw ChunkingError.missingChunk(index)
            }
            result.append(chunk)
        }

        return result
    }
}

enum ChunkingError: Error, CustomStringConvertible {
    case incompleteMessage
    case missingChunk(UInt32)
    case bufferTimeout

    var description: String {
        switch self {
        case .incompleteMessage:
            return "Message is incomplete (not all chunks received)"
        case .missingChunk(let index):
            return "Missing chunk at index \(index)"
        case .bufferTimeout:
            return "Buffer timeout (message incomplete)"
        }
    }
}
