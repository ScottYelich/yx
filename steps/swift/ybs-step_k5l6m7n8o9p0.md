# YBS Step 15 (Swift): Interoperability Test Suite

**Step ID:** `ybs-step_k5l6m7n8o9p0`
**Language:** Swift
**System:** YX Protocol
**Focus:** Complete 48-test interoperability framework

## Prerequisites

- ✅ Step 14 completed (SimplePacketBuilder)
- ✅ Python Step 15 completed (Python interop programs exist)
- ✅ Specifications: `specs/testing/interoperability-requirements.md`
- ✅ All previous steps completed (full protocol stack)

## Overview

Implement **complete 48-test interoperability suite** to verify cross-language compatibility.

**Test Matrix (N² for N languages):**
- Python → Python (4 combinations)
- Python → Swift (4 combinations)
- Swift → Python (4 combinations)
- Swift → Swift (4 combinations)

**Test Layers (12 scenarios per combination):**
1. **Transport Layer** (5 scenarios): Simple, empty, large, multiple, invalid key
2. **Protocol 0 (Text)** (3 scenarios): JSON, large JSON, invalid JSON
3. **Protocol 1 (Binary)** (4 scenarios): Base, compressed, encrypted, both

**Total Tests:** 4 combinations × 12 scenarios = **48 tests**

**Critical Requirement:** ALL 48 tests MUST pass. No exceptions. Wire format compatibility alone is NOT sufficient - actual UDP network communication must work.

## Traceability

**Specifications:**
- `specs/testing/interoperability-requirements.md` - Complete test requirements
- `specs/architecture/api-contracts.md` - SimplePacketBuilder API

**Gaps Addressed:**
- Gap 6.1: Interoperability test framework
- Gap 6.2: Cross-language testing
- Gap 6.3: 48-test matrix implementation

**SDTS Lessons:**
- Wire format compatibility ≠ network interoperability
- Must test actual UDP communication (no mocks)
- Sender/receiver pattern critical for clean tests

## Build Instructions

### 1. Create Swift Sender Programs

Create directory structure:
```
tests/interop/swift/
├── senders/
│   ├── swift_sender_transport_simple.swift
│   ├── swift_sender_transport_empty.swift
│   ├── swift_sender_transport_large.swift
│   ├── swift_sender_transport_multiple.swift
│   ├── swift_sender_transport_invalid.swift
│   ├── swift_sender_proto0_json.swift
│   ├── swift_sender_proto0_large.swift
│   ├── swift_sender_proto0_invalid.swift
│   ├── swift_sender_proto1_base.swift
│   ├── swift_sender_proto1_compressed.swift
│   ├── swift_sender_proto1_encrypted.swift
│   └── swift_sender_proto1_both.swift
└── receivers/
    ├── swift_receiver_transport.swift
    ├── swift_receiver_proto0.swift
    └── swift_receiver_proto1.swift
```

#### Transport Layer Senders

**File:** `tests/interop/swift/senders/swift_sender_transport_simple.swift`

```swift
#!/usr/bin/env swift

import Foundation

// Add path to YX module (adjust based on build location)
#if os(macOS)
import YX
#endif

// Simple transport test: Send single packet with payload
do {
    let payload = "Hello from Swift".data(using: .utf8)!
    let guid = TestConfig.testGUID
    let key = TestConfig.testKey

    // Build packet manually (transport layer only)
    var message = Data(capacity: guid.count + payload.count)
    message.append(guid)
    message.append(payload)

    // Compute HMAC
    let hmacKey = SymmetricKey(data: key)
    var hmac = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
    hmac = hmac.prefix(16)

    // Build packet
    var packet = Data(capacity: hmac.count + message.count)
    packet.append(hmac)
    packet.append(message)

    // Send
    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_transport_empty.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Empty payload test
do {
    let payload = Data() // Empty
    let packet = try SimplePacketBuilder.buildPacket(
        guid: TestConfig.testGUID,
        payload: payload,
        key: TestConfig.testKey
    )

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_transport_large.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Large payload test (10 KB)
do {
    let payload = Data(repeating: 0xAB, count: 10_000)
    let packet = try SimplePacketBuilder.buildPacket(
        guid: TestConfig.testGUID,
        payload: payload,
        key: TestConfig.testKey
    )

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_transport_multiple.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Multiple packets test
do {
    for i in 0..<5 {
        let payload = "Message \(i)".data(using: .utf8)!
        let packet = try SimplePacketBuilder.buildPacket(
            guid: TestConfig.testGUID,
            payload: payload,
            key: TestConfig.testKey
        )

        try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)
        Thread.sleep(forTimeInterval: 0.1) // Small delay
    }

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_transport_invalid.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Invalid HMAC test (should be rejected by receiver)
do {
    let payload = "Invalid packet".data(using: .utf8)!
    let wrongKey = Data(repeating: 0xFF, count: 32)

    let packet = try SimplePacketBuilder.buildPacket(
        guid: TestConfig.testGUID,
        payload: payload,
        key: wrongKey // Wrong key - HMAC will be invalid
    )

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

#### Protocol 0 (Text) Senders

**File:** `tests/interop/swift/senders/swift_sender_proto0_json.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 0: Simple JSON-RPC
do {
    struct RPCRequest: Codable {
        let jsonrpc: String
        let method: String
        let params: [String: String]
        let id: Int
    }

    let request = RPCRequest(
        jsonrpc: "2.0",
        method: "test.echo",
        params: ["message": "Hello from Swift"],
        id: 1
    )

    let packet = try SimplePacketBuilder.buildTextPacket(
        message: request,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey
    )

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_proto0_large.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 0: Large JSON payload
do {
    struct RPCRequest: Codable {
        let jsonrpc: String
        let method: String
        let params: [String: String]
        let id: Int
    }

    // Large params (1000 key-value pairs)
    var largeParams: [String: String] = [:]
    for i in 0..<1000 {
        largeParams["key\(i)"] = "value\(i)"
    }

    let request = RPCRequest(
        jsonrpc: "2.0",
        method: "test.large",
        params: largeParams,
        id: 2
    )

    let packet = try SimplePacketBuilder.buildTextPacket(
        message: request,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey
    )

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_proto0_invalid.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 0: Invalid JSON (should be rejected)
do {
    // Manually construct invalid JSON payload
    let invalidJSON = "{invalid json}".data(using: .utf8)!

    var payload = Data(capacity: 1 + invalidJSON.count)
    payload.append(0x00) // Protocol 0
    payload.append(invalidJSON)

    let packet = try SimplePacketBuilder.buildPacket(
        guid: TestConfig.testGUID,
        payload: payload,
        key: TestConfig.testKey
    )

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

#### Protocol 1 (Binary) Senders

**File:** `tests/interop/swift/senders/swift_sender_proto1_base.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 1: Base (no compression, no encryption)
do {
    let data = Data(repeating: 0xCD, count: 100)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x00, // Base
        channelID: 0,
        sequence: 0
    )

    for packet in packets {
        try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)
        Thread.sleep(forTimeInterval: 0.01)
    }

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_proto1_compressed.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 1: Compressed (ZLIB)
do {
    let data = Data(repeating: 0xEE, count: 1000)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x01, // Compressed
        channelID: 0,
        sequence: 0
    )

    for packet in packets {
        try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)
        Thread.sleep(forTimeInterval: 0.01)
    }

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_proto1_encrypted.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 1: Encrypted (AES-256-GCM)
do {
    let data = Data(repeating: 0xFF, count: 100)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x02, // Encrypted
        encryptionKey: TestConfig.testEncryptionKey,
        channelID: 0,
        sequence: 0
    )

    for packet in packets {
        try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)
        Thread.sleep(forTimeInterval: 0.01)
    }

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**File:** `tests/interop/swift/senders/swift_sender_proto1_both.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 1: Both compressed and encrypted
do {
    let data = Data(repeating: 0xAA, count: 1000)

    let packets = try SimplePacketBuilder.buildBinaryPackets(
        data: data,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey,
        protoOpts: 0x03, // Both
        encryptionKey: TestConfig.testEncryptionKey,
        channelID: 0,
        sequence: 0
    )

    for packet in packets {
        try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)
        Thread.sleep(forTimeInterval: 0.01)
    }

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

### 2. Create Swift Receiver Programs

#### Transport Layer Receiver

**File:** `tests/interop/swift/receivers/swift_receiver_transport.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Transport layer receiver - verifies HMAC and extracts payload
do {
    print("Listening on port \(TestConfig.testPort)...")

    let (packet, sourceAddr, sourcePort) = try UDPHelper.receive(
        port: TestConfig.testPort,
        timeout: 10.0
    )

    print("Received packet from \(sourceAddr):\(sourcePort)")

    // Verify HMAC
    let valid = SimplePacketBuilder.verifyPacket(packet: packet, key: TestConfig.testKey)

    if valid {
        // Extract payload
        if let payload = SimplePacketBuilder.extractPayload(packet: packet) {
            print("RECEIVED: \(payload.count) bytes")
            exit(0)
        } else {
            print("ERROR: Failed to extract payload")
            exit(1)
        }
    } else {
        print("ERROR: Invalid HMAC")
        exit(1)
    }

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

#### Protocol 0 Receiver

**File:** `tests/interop/swift/receivers/swift_receiver_proto0.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 0 receiver - decodes JSON-RPC
do {
    print("Listening on port \(TestConfig.testPort)...")

    let (packet, sourceAddr, sourcePort) = try UDPHelper.receive(
        port: TestConfig.testPort,
        timeout: 10.0
    )

    print("Received packet from \(sourceAddr):\(sourcePort)")

    // Verify HMAC
    guard SimplePacketBuilder.verifyPacket(packet: packet, key: TestConfig.testKey) else {
        print("ERROR: Invalid HMAC")
        exit(1)
    }

    // Extract payload
    guard let payload = SimplePacketBuilder.extractPayload(packet: packet) else {
        print("ERROR: Failed to extract payload")
        exit(1)
    }

    // Verify protocol ID
    guard payload[0] == 0x00 else {
        print("ERROR: Expected protocol ID 0x00, got 0x\(String(format: "%02X", payload[0]))")
        exit(1)
    }

    // Extract JSON
    let jsonData = payload.suffix(from: 1)

    // Try to decode as JSON
    if let json = try? JSONSerialization.jsonObject(with: jsonData) {
        print("RECEIVED: Valid JSON")
        if let dict = json as? [String: Any] {
            if let method = dict["method"] as? String {
                print("Method: \(method)")
            }
        }
        exit(0)
    } else {
        print("ERROR: Invalid JSON")
        exit(1)
    }

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

#### Protocol 1 Receiver

**File:** `tests/interop/swift/receivers/swift_receiver_proto1.swift`

```swift
#!/usr/bin/env swift

import Foundation
import YX

// Protocol 1 receiver - handles chunked binary messages
actor MessageBuffer {
    private var chunks: [UInt32: Data] = [:]
    private var totalChunks: UInt32 = 0

    func addChunk(index: UInt32, data: Data, total: UInt32) {
        if totalChunks == 0 {
            totalChunks = total
        }
        chunks[index] = data
    }

    func isComplete() -> Bool {
        return chunks.count == Int(totalChunks)
    }

    func reassemble() throws -> Data {
        var result = Data()
        for i in 0..<totalChunks {
            guard let chunk = chunks[i] else {
                throw NSError(domain: "Missing chunk", code: 1)
            }
            result.append(chunk)
        }
        return result
    }
}

// Main receiver
Task {
    do {
        print("Listening on port \(TestConfig.testPort)...")

        let buffer = MessageBuffer()
        var receivedCount = 0
        let maxChunks = 100

        // Receive chunks
        while receivedCount < maxChunks {
            let (packet, _, _) = try UDPHelper.receive(port: TestConfig.testPort, timeout: 5.0)

            // Verify HMAC
            guard SimplePacketBuilder.verifyPacket(packet: packet, key: TestConfig.testKey) else {
                print("ERROR: Invalid HMAC")
                exit(1)
            }

            // Extract payload
            guard let payload = SimplePacketBuilder.extractPayload(packet: packet) else {
                continue
            }

            // Verify protocol ID
            guard payload[0] == 0x01 else {
                print("ERROR: Expected protocol ID 0x01")
                continue
            }

            // Parse header
            guard payload.count >= 16 else {
                print("ERROR: Payload too small for header")
                continue
            }

            let protoOpts = payload[1]
            let chunkIndex = payload.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }.bigEndian
            let totalChunks = payload.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt32.self) }.bigEndian

            // Extract data
            let data = payload.suffix(from: 16)

            // Buffer chunk
            await buffer.addChunk(index: chunkIndex, data: data, total: totalChunks)
            receivedCount += 1

            // Check if complete
            if await buffer.isComplete() {
                // Reassemble
                let reassembled = try await buffer.reassemble()

                // Decrypt if needed
                var processed = reassembled
                if protoOpts & 0x02 != 0 {
                    let key = try Data.symmetricKey(from: TestConfig.testEncryptionKey)
                    processed = try processed.aesGCMDecrypt(key: key)
                }

                // Decompress if needed
                if protoOpts & 0x01 != 0 {
                    processed = try processed.zlibDecompress()
                }

                print("RECEIVED: \(processed.count) bytes (protoOpts: 0x\(String(format: "%02X", protoOpts)))")
                exit(0)
            }
        }

        print("ERROR: Timeout waiting for complete message")
        exit(1)

    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
}

// Keep alive
RunLoop.main.run()
```

### 3. Create Master Test Runner

**File:** `tests/interop/run_all_interop_tests.sh`

```bash
#!/bin/bash

# Master interop test runner
# Runs all 48 tests (4 combinations × 12 scenarios)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_PORT=49999

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
FAILED_TESTS=()

# Test function
run_test() {
    local test_name=$1
    local sender=$2
    local receiver=$3
    local timeout=${4:-5}

    echo -n "Testing $test_name... "

    # Start receiver in background
    $receiver > /tmp/receiver.log 2>&1 &
    local receiver_pid=$!

    # Give receiver time to bind
    sleep 0.5

    # Run sender
    if $sender > /tmp/sender.log 2>&1; then
        # Wait for receiver
        sleep 0.5

        # Check if receiver succeeded
        if wait $receiver_pid; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC} (receiver failed)"
            ((FAILED++))
            FAILED_TESTS+=("$test_name")
        fi
    else
        echo -e "${RED}FAIL${NC} (sender failed)"
        ((FAILED++))
        FAILED_TESTS+=("$test_name")
        kill $receiver_pid 2>/dev/null || true
    fi
}

echo "========================================="
echo "YX Interoperability Test Suite (48 tests)"
echo "========================================="
echo ""

# ============================================
# TRANSPORT LAYER TESTS (20 tests = 4×5)
# ============================================

echo "Transport Layer Tests (20 tests):"
echo ""

# Python → Python
run_test "Transport/Py→Py/Simple" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_simple.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Py→Py/Empty" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_empty.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Py→Py/Large" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_large.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Py→Py/Multiple" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_multiple.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Py→Py/Invalid" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_invalid.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

# Python → Swift
run_test "Transport/Py→Swift/Simple" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_simple.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Py→Swift/Empty" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_empty.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Py→Swift/Large" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_large.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Py→Swift/Multiple" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_multiple.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Py→Swift/Invalid" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_transport_invalid.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

# Swift → Python
run_test "Transport/Swift→Py/Simple" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_simple.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Swift→Py/Empty" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_empty.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Swift→Py/Large" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_large.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Swift→Py/Multiple" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_multiple.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

run_test "Transport/Swift→Py/Invalid" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_invalid.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_transport.py"

# Swift → Swift
run_test "Transport/Swift→Swift/Simple" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_simple.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Swift→Swift/Empty" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_empty.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Swift→Swift/Large" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_large.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Swift→Swift/Multiple" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_multiple.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

run_test "Transport/Swift→Swift/Invalid" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_transport_invalid.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_transport.swift"

echo ""

# ============================================
# PROTOCOL 0 (TEXT) TESTS (12 tests = 4×3)
# ============================================

echo "Protocol 0 (Text) Tests (12 tests):"
echo ""

# Python → Python
run_test "Proto0/Py→Py/JSON" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto0_json.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto0.py"

run_test "Proto0/Py→Py/Large" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto0_large.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto0.py"

run_test "Proto0/Py→Py/Invalid" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto0_invalid.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto0.py"

# Python → Swift
run_test "Proto0/Py→Swift/JSON" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto0_json.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto0.swift"

run_test "Proto0/Py→Swift/Large" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto0_large.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto0.swift"

run_test "Proto0/Py→Swift/Invalid" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto0_invalid.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto0.swift"

# Swift → Python
run_test "Proto0/Swift→Py/JSON" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto0_json.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto0.py"

run_test "Proto0/Swift→Py/Large" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto0_large.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto0.py"

run_test "Proto0/Swift→Py/Invalid" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto0_invalid.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto0.py"

# Swift → Swift
run_test "Proto0/Swift→Swift/JSON" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto0_json.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto0.swift"

run_test "Proto0/Swift→Swift/Large" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto0_large.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto0.swift"

run_test "Proto0/Swift→Swift/Invalid" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto0_invalid.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto0.swift"

echo ""

# ============================================
# PROTOCOL 1 (BINARY) TESTS (16 tests = 4×4)
# ============================================

echo "Protocol 1 (Binary) Tests (16 tests):"
echo ""

# Python → Python
run_test "Proto1/Py→Py/Base" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_base.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

run_test "Proto1/Py→Py/Compressed" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_compressed.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

run_test "Proto1/Py→Py/Encrypted" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_encrypted.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

run_test "Proto1/Py→Py/Both" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_both.py" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

# Python → Swift
run_test "Proto1/Py→Swift/Base" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_base.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

run_test "Proto1/Py→Swift/Compressed" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_compressed.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

run_test "Proto1/Py→Swift/Encrypted" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_encrypted.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

run_test "Proto1/Py→Swift/Both" \
    "python3 $SCRIPT_DIR/python/senders/python_sender_proto1_both.py" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

# Swift → Python
run_test "Proto1/Swift→Py/Base" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_base.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

run_test "Proto1/Swift→Py/Compressed" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_compressed.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

run_test "Proto1/Swift→Py/Encrypted" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_encrypted.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

run_test "Proto1/Swift→Py/Both" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_both.swift" \
    "python3 $SCRIPT_DIR/python/receivers/python_receiver_proto1.py"

# Swift → Swift
run_test "Proto1/Swift→Swift/Base" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_base.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

run_test "Proto1/Swift→Swift/Compressed" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_compressed.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

run_test "Proto1/Swift→Swift/Encrypted" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_encrypted.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

run_test "Proto1/Swift→Swift/Both" \
    "swift $SCRIPT_DIR/swift/senders/swift_sender_proto1_both.swift" \
    "swift $SCRIPT_DIR/swift/receivers/swift_receiver_proto1.swift"

echo ""
echo "========================================="
echo "Results: $PASSED passed, $FAILED failed (out of 48 tests)"
echo "========================================="

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}FAILED TESTS:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED!${NC}"
    exit 0
fi
```

Make executable:
```bash
chmod +x tests/interop/run_all_interop_tests.sh
```

## Verification

### Running Tests

```bash
cd tests/interop/
./run_all_interop_tests.sh
```

### Success Criteria

- [ ] **ALL 48 tests MUST pass** (no exceptions)
- [ ] Transport Layer: 20/20 tests pass (4 combinations × 5 scenarios)
- [ ] Protocol 0 (Text): 12/12 tests pass (4 combinations × 3 scenarios)
- [ ] Protocol 1 (Binary): 16/16 tests pass (4 combinations × 4 scenarios)
- [ ] Python → Swift communication verified
- [ ] Swift → Python communication verified
- [ ] Swift → Swift communication verified
- [ ] Compression works across languages
- [ ] Encryption works across languages (SDTS Issue #1 wire format)
- [ ] Chunking/reassembly works across languages
- [ ] All test programs exit with status 0 on success

### Expected Output

```
=========================================
YX Interoperability Test Suite (48 tests)
=========================================

Transport Layer Tests (20 tests):

Testing Transport/Py→Py/Simple... PASS
Testing Transport/Py→Py/Empty... PASS
Testing Transport/Py→Py/Large... PASS
Testing Transport/Py→Py/Multiple... PASS
Testing Transport/Py→Py/Invalid... PASS
Testing Transport/Py→Swift/Simple... PASS
[... 42 more tests ...]

=========================================
Results: 48 passed, 0 failed (out of 48 tests)
=========================================
ALL TESTS PASSED!
```

## Implementation Notes

### Critical Requirements

1. **Real UDP Communication:** All tests use actual UDP sockets (no mocks)
2. **Wire Format Compatibility:** Byte-identical packets across languages
3. **Cross-Language Validation:** Python ↔ Swift must interoperate perfectly
4. **No Assumptions:** Wire format match ≠ network interoperability

### SDTS Issue #1: AES-GCM Wire Format

**Critical:** Swift CryptoKit and Python cryptography library MUST produce identical wire format:
```
[nonce(12)] + [ciphertext] + [tag(16)]
```

This is verified by Proto1 encrypted tests across languages.

### Test Pattern

**Sender (simple, synchronous):**
```swift
let packet = build_packet(...)
send_udp(packet)
exit(0)
```

**Receiver (full async stack):**
```swift
receive_udp()
verify_hmac()
process_protocol()
exit(0 if success else 1)
```

This pattern enables clean, isolated tests.

### Debugging Failed Tests

If tests fail:
1. Check `/tmp/sender.log` and `/tmp/receiver.log`
2. Verify test port is available (49999)
3. Check firewall settings
4. Run individual test manually to debug
5. Verify Python and Swift implementations both completed Steps 1-14

### Adding More Languages

When adding new language (e.g., Rust):
- Add sender/receiver programs in `tests/interop/rust/`
- Update master runner to include new combinations
- Total tests becomes N² × 12 (e.g., 3 languages = 9 × 12 = 108 tests)

## Traceability Matrix

| Gap ID | Specification | Implementation | Tests |
|--------|---------------|----------------|-------|
| 6.1 | interoperability-requirements.md § Framework | Master runner script | 48 tests |
| 6.2 | interoperability-requirements.md § Cross-language | Swift senders/receivers | All combinations |
| 6.3 | interoperability-requirements.md § 48-test matrix | Complete test suite | Transport + Proto0 + Proto1 |

## Next Steps

After completing this step:

1. ✅ All Swift implementation steps complete (Steps 0-15)
2. ✅ All Python implementation steps complete (Steps 0-15)
3. ✅ **48 interop tests passing** ← MANDATORY BUILD COMPLETION CRITERIA
4. ⏭️ Update STEPS_ORDER.txt files
5. ⏭️ Final: System is COMPLETE when all 48 interop tests pass

## Build Completion Criteria

The **entire YX system** is complete when:
- ✅ Python implementation complete (Steps 0-15)
- ✅ Swift implementation complete (Steps 0-15)
- ✅ Canonical artifacts generated (Python)
- ✅ **ALL 48 interop tests pass (48/48)** ⚠️ MANDATORY

**CRITICAL:** The build is NOT complete until:
```bash
cd tests/interop/
./run_all_interop_tests.sh
# Output: ALL TESTS PASSED!
# Exit code: 0
```

## References

- `specs/testing/interoperability-requirements.md` - Complete requirements
- `specs/architecture/api-contracts.md` - SimplePacketBuilder API
- Python Step 15: `steps/python/ybs-step_k5l6m7n8o9p0.md`
- SDTS Issue #1: AES-GCM wire format compatibility
- CLAUDE.md: ⚠️ INTEROP TESTS ARE MANDATORY section
