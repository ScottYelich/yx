# YBS Step: Swift Interop Receivers

**Step ID:** `ybs-step_sw5b0c1d2e3f`
**Language:** Swift
**Prerequisites:** Step sw5a complete (SwiftSender/main.swift exists)

---

## What This Step Builds

Create Swift receiver executables in `Sources/SwiftReceiver/`:
- One receiver that handles both Protocol 0 and Protocol 1 packets

These are compiled Swift programs that receive YX packets via UDP, print received data, and exit.

---

## File: `Sources/SwiftReceiver/main.swift`

Create with multi-mode receiver:

```swift
#!/usr/bin/env swift
import Foundation

// Usage: SwiftReceiver <mode> [timeout_seconds]
// Modes: proto0, proto1
// Receives one message (or reassembles one binary transmission) then exits.

import YXProtocol

func main() throws {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        print("Usage: SwiftReceiver <mode> [timeout_seconds]")
        exit(1)
    }

    let mode = args[1]
    let timeoutSecs = args.count > 2 ? Double(args[2]) ?? 5.0 : 5.0
    let key = TestConfig.testKey
    let port = TestConfig.testPort

    let socket = try UDPSocket(port: port)
    try socket.bind()
    socket.setTimeout(timeoutSecs)

    switch mode {
    case "proto0":
        guard let (guid, payload, _) = try socket.receivePacket(key: key) else {
            fputs("ERROR: timeout\n", stderr)
            exit(2)
        }
        // payload[0] == 0x00 (proto marker), payload[1...] == JSON
        guard payload.count >= 1, payload[0] == 0x00 else {
            fputs("ERROR: not a proto0 packet\n", stderr)
            exit(3)
        }
        let json = payload.dropFirst()
        let parsed = try JSONSerialization.jsonObject(with: json)
        print("RECEIVED proto0 guid=\(guid.map { String(format: "%02X", $0) }.joined()): \(parsed)")
        exit(0)

    case "proto1":
        // Reassemble binary chunks
        var chunks: [UInt32: Data] = [:]
        var totalChunks: UInt32 = 0
        let startTime = Date()

        repeat {
            guard let (_, payload, _) = try socket.receivePacket(key: key) else {
                break
            }
            guard payload.count >= 16, payload[0] == 0x01 else { continue }

            let protoOpts = payload[1]
            // channelID: payload[2..<4], sequence: payload[4..<8]
            let chunkIndex = payload[8..<12].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let total = payload[12..<16].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let chunkData = payload.dropFirst(16)

            chunks[chunkIndex] = chunkData
            totalChunks = total

            if UInt32(chunks.count) == totalChunks { break }
        } while Date().timeIntervalSince(startTime) < timeoutSecs

        guard UInt32(chunks.count) == totalChunks, totalChunks > 0 else {
            fputs("ERROR: incomplete reassembly (\(chunks.count)/\(totalChunks))\n", stderr)
            exit(2)
        }

        // Reassemble in order
        var assembled = Data()
        for i in 0..<totalChunks {
            guard let chunk = chunks[i] else {
                fputs("ERROR: missing chunk \(i)\n", stderr)
                exit(3)
            }
            assembled.append(chunk)
        }

        // Determine protoOpts from first chunk
        // (We already have protoOpts from the last chunk but we only need it for decryption/decompression)
        print("RECEIVED proto1: \(assembled.count) bytes")
        exit(0)

    default:
        print("Unknown mode: \(mode)")
        exit(1)
    }
}

try main()
```

---

## Package.swift Update

Add SwiftReceiver target to `Package.swift` (in `targets` array):

```swift
.executableTarget(
    name: "SwiftReceiver",
    dependencies: ["YXProtocol"]
),
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift build 2>&1 | tail -5
```

Build must succeed with no errors. Both `SwiftSender` and `SwiftReceiver` must appear in `.build/debug/`.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw5b0c1d2e3f-DONE.txt`:

```
STEP: ybs-step_sw5b0c1d2e3f
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/SwiftReceiver/main.swift
VERIFICATION: PASSED (swift build succeeds, SwiftReceiver binary exists)
NEXT: ybs-step_sw5c0d1e2f3a
```

Update `BUILD_STATUS.md`: add `- [x] sw5b0c1d2e3f`.
