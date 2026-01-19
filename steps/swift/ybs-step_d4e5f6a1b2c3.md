# Step 4: Swift HMAC Computation

**Version**: 0.1.0

## Overview

Implement HMAC-SHA256 using CryptoKit.

## Step Objectives

1. HMAC-SHA256 with 16-byte truncation
2. Constant-time validation
3. Packet HMAC functions
4. XCTest unit tests

## Prerequisites

- Step 3 completed

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § HMAC-SHA256

## Instructions

### 1. Create Data Crypto

Create `Sources/YXProtocol/Primitives/DataCrypto.swift`:

```swift
import Foundation
import CryptoKit

public struct DataCrypto {
    public static func computeHMAC(data: Data, key: SymmetricKey, truncateTo: Int = 16) -> Data {
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac.prefix(truncateTo))
    }

    public static func validateHMAC(data: Data, key: SymmetricKey, expectedHMAC: Data, truncateTo: Int = 16) -> Bool {
        let computed = computeHMAC(data: data, key: key, truncateTo: truncateTo)
        return computed == expectedHMAC
    }

    public static func computePacketHMAC(guid: Data, payload: Data, key: SymmetricKey) -> Data {
        let combined = guid + payload
        return computeHMAC(data: combined, key: key, truncateTo: 16)
    }

    public static func validatePacketHMAC(guid: Data, payload: Data, key: SymmetricKey, expectedHMAC: Data) -> Bool {
        let computed = computePacketHMAC(guid: guid, payload: payload, key: key)
        return computed == expectedHMAC
    }
}
```

### 2. Create Tests

Create `Tests/YXProtocolTests/Unit/DataCryptoTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import YXProtocol

final class DataCryptoTests: XCTestCase {
    func testComputeHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let data = Data("test".utf8)

        let hmac = DataCrypto.computeHMAC(data: data, key: key)

        XCTAssertEqual(hmac.count, 16)
    }

    func testValidateHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let data = Data("test".utf8)

        let hmac = DataCrypto.computeHMAC(data: data, key: key)
        let isValid = DataCrypto.validateHMAC(data: data, key: key, expectedHMAC: hmac)

        XCTAssertTrue(isValid)
    }

    func testComputePacketHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let hmac = DataCrypto.computePacketHMAC(guid: guid, payload: payload, key: key)

        XCTAssertEqual(hmac.count, 16)
    }

    func testValidatePacketHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let hmac = DataCrypto.computePacketHMAC(guid: guid, payload: payload, key: key)
        let isValid = DataCrypto.validatePacketHMAC(guid: guid, payload: payload, key: key, expectedHMAC: hmac)

        XCTAssertTrue(isValid)
    }
}
```

### 3. Run Tests

```bash
swift test --filter DataCryptoTests
```

## Verification

- [ ] HMAC computation works
- [ ] Validation works
- [ ] Tests pass

```bash
swift test --filter DataCryptoTests
```
