# Step 4: Swift HMAC Computation

**Version**: 0.1.0

## Overview

Implement HMAC-SHA256 using CryptoKit.

## What This Step Builds

Implements HMAC-SHA256 computation using `CryptoKit.HMAC<SHA256>` with 16-byte truncation and constant-time comparison via `HMAC.isValidAuthenticationCode`, in `DataCrypto.swift`.

## Step Objectives

1. HMAC-SHA256 with 16-byte truncation
2. Constant-time validation
3. Packet HMAC functions
4. XCTest unit tests

## Prerequisites

- Step 3 completed

## Traceability

**Implements**: protocol/specs/technical/yx-protocol-spec.md § HMAC-SHA256

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

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

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_d4e5f6a1b2c3-DONE.txt`:

```
STEP ybs-step_d4e5f6a1b2c3: Swift HMAC Computation
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- Sources/YXProtocol/Primitives/DataCrypto.swift
- Tests/YXProtocolTests/Unit/DataCryptoTests.swift

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_e5f6a1b2c3d4 (Packet Builder)
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
- **Next**: `ybs-step_e5f6a1b2c3d4` — Packet Builder

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
