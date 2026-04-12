# Step 2: Swift GUID Factory

**Version**: 0.1.0

## Overview

Implement GUID Factory in Swift with wire-format compatibility with Python implementation.

## What This Step Builds

Implements `GUIDFactory` struct — a 6-byte cryptographically-secure identifier generator using Swift's `SystemRandomNumberGenerator`, in `Sources/YXProtocol/Primitives/GUIDFactory.swift`.

## Step Objectives

1. Implement GUID generation (6 random bytes)
2. Implement GUID padding
3. Hex conversion
4. XCTest unit tests
5. 100% coverage

## Prerequisites

- Step 1 completed (Swift project setup)

## Traceability

**Implements**: protocol/specs/technical/yx-protocol-spec.md § Layer 2: GUID

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Create GUID Factory

Create `Sources/YXProtocol/Primitives/GUIDFactory.swift`:

```swift
import Foundation

public struct GUIDFactory {
    public static func generate() -> Data {
        var bytes = [UInt8](repeating: 0, count: 6)
        _ = SecRandomCopyBytes(kSecRandomDefault, 6, &bytes)
        return Data(bytes)
    }

    public static func pad(guid: Data) -> Data {
        if guid.count == 6 {
            return guid
        } else if guid.count < 6 {
            return guid + Data(repeating: 0, count: 6 - guid.count)
        } else {
            return guid.prefix(6)
        }
    }

    public static func fromHex(_ hexString: String) -> Data {
        var data = Data()
        var hex = hexString
        while hex.count >= 2 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let byteString = String(hex[..<index])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            hex = String(hex[index...])
        }
        return pad(guid: data)
    }

    public static func toHex(_ guid: Data) -> String {
        return guid.map { String(format: "%02x", $0) }.joined()
    }
}
```

### 2. Create Tests

Create `Tests/YXProtocolTests/Unit/GUIDFactoryTests.swift`:

```swift
import XCTest
@testable import YXProtocol

final class GUIDFactoryTests: XCTestCase {
    func testGenerateReturns6Bytes() {
        let guid = GUIDFactory.generate()
        XCTAssertEqual(guid.count, 6)
    }

    func testGenerateProducesDifferentGUIDs() {
        let guid1 = GUIDFactory.generate()
        let guid2 = GUIDFactory.generate()
        XCTAssertNotEqual(guid1, guid2)
    }

    func testPadGUID() {
        let short = Data([0x01, 0x02])
        let padded = GUIDFactory.pad(guid: short)
        XCTAssertEqual(padded.count, 6)
        XCTAssertEqual(padded, Data([0x01, 0x02, 0x00, 0x00, 0x00, 0x00]))
    }

    func testPadGUIDExact6Bytes() {
        let exact = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let padded = GUIDFactory.pad(guid: exact)
        XCTAssertEqual(padded, exact)
    }

    func testFromHex() {
        let guid = GUIDFactory.fromHex("010203040506")
        XCTAssertEqual(guid, Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
    }

    func testToHex() {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let hex = GUIDFactory.toHex(guid)
        XCTAssertEqual(hex, "010203040506")
    }

    func testHexRoundtrip() {
        let original = Data([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff])
        let hex = GUIDFactory.toHex(original)
        let restored = GUIDFactory.fromHex(hex)
        XCTAssertEqual(restored, original)
    }
}
```

### 3. Run Tests

```bash
swift test --filter GUIDFactoryTests
```

## Verification

- [ ] Tests pass
- [ ] GUID generation works
- [ ] Padding works
- [ ] Hex conversion works

```bash
swift test --filter GUIDFactoryTests
```

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_b2c3d4e5f6a1-DONE.txt`:

```
STEP ybs-step_b2c3d4e5f6a1: Swift GUID Factory
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- Sources/YXProtocol/Primitives/GUIDFactory.swift
- Tests/YXProtocolTests/Unit/GUIDFactoryTests.swift

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_c3d4e5f6a1b2 (Packet Structure)
```

Update `BUILD_STATUS.md`: mark this step `[x]` and update **Last Updated** timestamp.

## Success Criteria

This step is successful when:
1. All verification checks pass (within 3 attempts)
2. All required files exist and are valid
3. Build compiles/runs without errors
4. DONE file created in `docs/build-history/`
5. `BUILD_STATUS.md` updated

## Next Steps

After completing this step, proceed to:
- **Next**: `ybs-step_c3d4e5f6a1b2` — Packet Structure

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
