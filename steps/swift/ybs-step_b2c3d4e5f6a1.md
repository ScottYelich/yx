# Step 2: Swift GUID Factory

**Version**: 0.1.0

## Overview

Implement GUID Factory in Swift with wire-format compatibility with Python implementation.

## Step Objectives

1. Implement GUID generation (6 random bytes)
2. Implement GUID padding
3. Hex conversion
4. XCTest unit tests
5. 100% coverage

## Prerequisites

- Step 1 completed (Swift project setup)

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § Layer 2: GUID

## Instructions

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
