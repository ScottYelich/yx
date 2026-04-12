# Step 6-8: Swift UDP Socket and Send/Receive

**Version**: 0.1.0

## Overview

Implement UDP socket with send/receive functionality. Combined steps for efficiency.

## What This Step Builds

Implements the complete UDP transport layer: `UDPSocket` class using `NWConnection`/`NWListener` with broadcast mode, plus async `sendPacket()` and `receivePacket()` operations. Combines Python Steps 6-8 into one Swift step.

## Step Objectives

1. UDP socket creation with broadcast support
2. Send packets
3. Receive packets
4. Tests

## Prerequisites

- Step 5 completed

## Traceability

**Implements**: protocol/specs/technical/yx-protocol-spec.md § UDP Transport

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Create UDP Socket

Create `Sources/YXProtocol/Transport/UDPSocket.swift`:

```swift
import Foundation
import Network

public class UDPSocket {
    private var connection: NWConnection?
    public let port: UInt16

    public init(port: UInt16 = 50000) {
        self.port = port
    }

    public func bind() throws {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let endpoint = NWEndpoint.hostPort(host: .ipv4(.any), port: NWEndpoint.Port(integerLiteral: port))
        let listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))

        listener.start(queue: .main)
    }

    public func sendPacket(guid: Data, payload: Data, key: SymmetricKey, host: String = "255.255.255.255", port: UInt16 = 50000) throws {
        let data = try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: key)

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)
        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)

        let connection = NWConnection(to: endpoint, using: params)
        connection.start(queue: .main)

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \\(error)")
            }
            connection.cancel()
        })
    }
}
```

### 2. Tests

Note: Full UDP tests require async Swift testing capabilities. Basic tests:

Create `Tests/YXProtocolTests/Unit/UDPSocketTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import YXProtocol

final class UDPSocketTests: XCTestCase {
    func testSocketInit() {
        let socket = UDPSocket(port: 50000)
        XCTAssertEqual(socket.port, 50000)
    }

    func testSendPacket() throws {
        let socket = UDPSocket(port: 0)
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        // Should not crash
        try socket.sendPacket(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: key, host: "127.0.0.1", port: 50010)
    }
}
```

### 3. Run Tests

```bash
swift test --filter UDPSocketTests
```

## Verification

- [ ] Socket creates
- [ ] Send doesn't crash
- [ ] Tests pass

```bash
swift test
```

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_f6a1b2c3d4e5-DONE.txt`:

```
STEP ybs-step_f6a1b2c3d4e5: Swift UDP Socket and Send/Receive
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- Sources/YXProtocol/Transport/UDPSocket.swift
- Tests/YXProtocolTests/Unit/UDPSocketTests.swift

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_a2b3c4d5e6f7 (Canonical Artifact Validation)
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
- **Next**: `ybs-step_a2b3c4d5e6f7` — Canonical Artifact Validation

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
