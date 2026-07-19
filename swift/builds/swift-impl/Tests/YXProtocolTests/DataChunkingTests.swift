import XCTest
@testable import YXProtocol

final class DataChunkingTests: XCTestCase {

    func testSingleChunk() {
        let data = Data([1, 2, 3])
        let chunks = data.chunked(size: 10)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], data)
    }

    func testMultipleChunks() {
        let data = Data(repeating: 0xFF, count: 2500)
        let chunks = data.chunked(size: 1024)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].count, 1024)
        XCTAssertEqual(chunks[1].count, 1024)
        XCTAssertEqual(chunks[2].count, 452)
    }

    func testEmptyData() {
        let data = Data()
        let chunks = data.chunked(size: 10)
        XCTAssertEqual(chunks.count, 0)
    }

    func testExactChunkSize() {
        let data = Data(repeating: 0xAA, count: 1024)
        let chunks = data.chunked(size: 1024)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].count, 1024)
    }

    func testBufferEntryReassemble() throws {
        let chunks: [UInt32: Data] = [0: Data([1, 2]), 1: Data([3, 4]), 2: Data([5, 6])]
        let entry = BufferEntry(chunks: chunks, totalChunks: 3, timestamp: Date())
        let result = try entry.reassemble()
        XCTAssertEqual(result, Data([1, 2, 3, 4, 5, 6]))
    }

    func testBufferEntryIncomplete() {
        let chunks: [UInt32: Data] = [0: Data([1, 2])]
        let entry = BufferEntry(chunks: chunks, totalChunks: 3, timestamp: Date())
        XCTAssertFalse(entry.isComplete)
    }

    func testRoundtripLargeData() throws {
        let original = Data(repeating: 0x42, count: 3000)
        let chunks = original.chunked(size: 1024)
        XCTAssertEqual(chunks.count, 3)

        var chunkDict: [UInt32: Data] = [:]
        for (i, chunk) in chunks.enumerated() {
            chunkDict[UInt32(i)] = chunk
        }
        let entry = BufferEntry(chunks: chunkDict, totalChunks: UInt32(chunks.count), timestamp: Date())
        let reassembled = try entry.reassemble()
        XCTAssertEqual(reassembled, original)
    }
}
