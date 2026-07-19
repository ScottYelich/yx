import Foundation
// filename: Data+Chunking.swift


public extension Data {
    /// Splits Data into equal-sized chunks (last chunk may be smaller)
    func chunked(into size: Int) -> [Data] {
        guard size > 0 else { return [] }
        var chunks: [Data] = []
        var offset = 0

        while offset < self.count {
            let end = Swift.min(offset + size, self.count)
            chunks.append(self[offset..<end])
            offset = end
        }

        return chunks
    }

    /// Splits Data into a fixed number of chunks, distributing bytes as evenly as possible
    func splitIntoChunks(chunks: Int) -> [Data] {
        guard chunks > 0 else { return [] }
        let totalSize = self.count
        let baseSize = totalSize / chunks
        let remainder = totalSize % chunks

        var result: [Data] = []
        var offset = 0

        for i in 0..<chunks {
            var size = baseSize
            if i < remainder {
                size += 1
            }
            let end = offset + size
            result.append(self[offset..<end])
            offset = end
        }

        return result
    }
}
