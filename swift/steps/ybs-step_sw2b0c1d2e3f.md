# YBS Step: DataCompression.swift

**Step ID:** `ybs-step_sw2b0c1d2e3f`
**Language:** Swift
**Prerequisites:** Step sw2a complete (AES-GCM extension done)

---

## What This Step Builds

Create `Sources/{{CONFIG:swift_module_name}}/Primitives/DataCompression.swift` — ZLIB compression/decompression.

---

## Implementation

**File:** `Sources/{{CONFIG:swift_module_name}}/Primitives/DataCompression.swift`

```swift
import Foundation
import Compression

// MARK: - ZLIB Compression

enum CompressionError: Error, CustomStringConvertible {
    case compressionFailed
    case decompressionFailed

    var description: String {
        switch self {
        case .compressionFailed: return "Compression failed"
        case .decompressionFailed: return "Decompression failed"
        }
    }
}

extension Data {

    /// Compress using ZLIB.
    /// Note: uses Apple Compression framework COMPRESSION_ZLIB.
    func zlibCompress() throws -> Data {
        guard !isEmpty else { return Data() }
        return try withUnsafeBytes { src -> Data in
            let bufSize = 4096
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
            defer { buf.deallocate() }
            var stream = compression_stream(dst_ptr: buf, dst_size: bufSize,
                                            src_ptr: src.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                            src_size: count, state: nil)
            guard compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
                throw CompressionError.compressionFailed
            }
            defer { compression_stream_destroy(&stream) }
            var result = Data()
            repeat {
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                if status == COMPRESSION_STATUS_ERROR { throw CompressionError.compressionFailed }
                let written = bufSize - stream.dst_size
                if written > 0 { result.append(buf, count: written) }
                stream.dst_ptr = buf
                stream.dst_size = bufSize
            } while stream.src_size > 0
            return result
        }
    }

    /// Decompress ZLIB data.
    func zlibDecompress() throws -> Data {
        guard !isEmpty else { return Data() }
        return try withUnsafeBytes { src -> Data in
            let bufSize = 65536
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
            defer { buf.deallocate() }
            var stream = compression_stream(dst_ptr: buf, dst_size: bufSize,
                                            src_ptr: src.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                            src_size: count, state: nil)
            guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
                throw CompressionError.decompressionFailed
            }
            defer { compression_stream_destroy(&stream) }
            var result = Data()
            repeat {
                let status = compression_stream_process(&stream, 0)
                if status == COMPRESSION_STATUS_ERROR { throw CompressionError.decompressionFailed }
                let written = bufSize - stream.dst_size
                if written > 0 { result.append(buf, count: written) }
                stream.dst_ptr = buf
                stream.dst_size = bufSize
            } while status == COMPRESSION_STATUS_OK
            return result
        }
    }
}
```

---

## Tests

**File:** `Tests/{{CONFIG:swift_module_name}}Tests/DataCompressionTests.swift`

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class DataCompressionTests: XCTestCase {

    func testRoundtrip() throws {
        let original = String(repeating: "Hello World ", count: 100).data(using: .utf8)!
        let compressed = try original.zlibCompress()
        let decompressed = try compressed.zlibDecompress()
        XCTAssertEqual(decompressed, original)
        XCTAssertLessThan(compressed.count, original.count)
    }

    func testEmpty() throws {
        let result = try Data().zlibCompress()
        XCTAssertEqual(result, Data())
        let decompressed = try Data().zlibDecompress()
        XCTAssertEqual(decompressed, Data())
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter DataCompression
```

Both tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw2b0c1d2e3f-DONE.txt`:

```
STEP: ybs-step_sw2b0c1d2e3f
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Primitives/DataCompression.swift, Tests/DataCompressionTests.swift
VERIFICATION: PASSED
NEXT: ybs-step_sw2c0d1e2f3a
```

Update `BUILD_STATUS.md`: add `- [x] sw2b0c1d2e3f`.
