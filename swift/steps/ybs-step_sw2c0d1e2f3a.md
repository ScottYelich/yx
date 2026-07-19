# YBS Step: DataChunking.swift

**Step ID:** `ybs-step_sw2c0d1e2f3a`
**Language:** Swift
**Prerequisites:** Step sw2b complete (DataCompression.swift exists)

---

## What This Step Builds

Create `Sources/{{CONFIG:swift_module_name}}/Primitives/DataChunking.swift` — split Data into chunks and BufferEntry for reassembly.

---

## Implementation

**File:** `Sources/{{CONFIG:swift_module_name}}/Primitives/DataChunking.swift`

```swift
import Foundation

// MARK: - Data Chunking

extension Data {

    /// Split data into fixed-size chunks.
    /// - Parameter chunkSize: Max bytes per chunk (default 1024)
    /// - Returns: Array of chunks (empty array for empty data)
    func chunked(size chunkSize: Int = 1024) -> [Data] {
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

enum ChunkingError: Error, CustomStringConvertible {
    case incompleteMessage
    case missingChunk(UInt32)

    var description: String {
        switch self {
        case .incompleteMessage: return "Not all chunks received"
        case .missingChunk(let i): return "Missing chunk \(i)"
        }
    }
}

/// Buffer for incomplete chunked messages.
struct BufferEntry {
    var chunks: [UInt32: Data]
    let totalChunks: UInt32
    let timestamp: Date

    var isComplete: Bool { chunks.count == Int(totalChunks) }

    /// Reassemble chunks in order.
    func reassemble() throws -> Data {
        guard isComplete else { throw ChunkingError.incompleteMessage }
        var result = Data()
        for i in 0..<totalChunks {
            guard let chunk = chunks[i] else { throw ChunkingError.missingChunk(i) }
            result.append(chunk)
        }
        return result
    }
}
```

---

## Tests

**File:** `Tests/{{CONFIG:swift_module_name}}Tests/DataChunkingTests.swift`

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

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

    func testBufferEntryReassemble() throws {
        let chunks: [UInt32: Data] = [0: Data([1,2]), 1: Data([3,4]), 2: Data([5,6])]
        let entry = BufferEntry(chunks: chunks, totalChunks: 3, timestamp: Date())
        let result = try entry.reassemble()
        XCTAssertEqual(result, Data([1,2,3,4,5,6]))
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter DataChunking
```

All 3 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw2c0d1e2f3a-DONE.txt`:

```
STEP: ybs-step_sw2c0d1e2f3a
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Primitives/DataChunking.swift, Tests/DataChunkingTests.swift
VERIFICATION: PASSED
NEXT: ybs-step_sw2d0e1f2a3b
```

Update `BUILD_STATUS.md`: add `- [x] sw2c0d1e2f3a`.
