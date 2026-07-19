# YBS Step: Swift Interop Senders

**Step ID:** `ybs-step_sw5a0b1c2d3e`
**Language:** Swift
**Prerequisites:** Step sw4a complete (SimplePacketBuilder.swift exists)

---

## What This Step Builds

Create Swift sender executables in `Sources/SwiftSender/`:
- One sender per protocol variant

These are compiled Swift programs that send YX packets via UDP and exit.

---

## File: `Sources/SwiftSender/main.swift`

Replace or create with multi-mode sender:

```swift
#!/usr/bin/env swift
import Foundation

// Usage: SwiftSender <mode> [args]
// Modes: proto0, proto1-base, proto1-compressed, proto1-encrypted, proto1-both

import {{CONFIG:swift_module_name}}

func main() throws {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        print("Usage: SwiftSender <mode> [data_hex_or_json]")
        exit(1)
    }

    let mode = args[1]
    let guid = TestConfig.testGUID
    let key = TestConfig.testKey
    let port = TestConfig.testPort

    switch mode {
    case "proto0":
        let json = args.count > 2 ? args[2] : "{\"method\":\"test\"}"
        let message = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
        let packet = try SimplePacketBuilder.buildTextPacket(message, guid: guid, key: key)
        try sendUDPPacket(packet, to: "127.0.0.1", port: port)
        print("SENT proto0: \(json)")

    case "proto1-base":
        let data = args.count > 2 ? Data(hex: args[2])! : Data("hello".utf8)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x00)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-base: \(data.count) bytes")

    case "proto1-compressed":
        let data = args.count > 2 ? Data(hex: args[2])! : Data(repeating: 0xAA, count: 100)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x01)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-compressed: \(data.count) bytes")

    case "proto1-encrypted":
        let data = args.count > 2 ? Data(hex: args[2])! : Data("secret".utf8)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x02)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-encrypted: \(data.count) bytes")

    case "proto1-both":
        let data = args.count > 2 ? Data(hex: args[2])! : Data(repeating: 0xBB, count: 100)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x03)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-both: \(data.count) bytes")

    default:
        print("Unknown mode: \(mode)")
        exit(1)
    }

    exit(0)
}

extension Data {
    init?(hex: String) {
        guard hex.count % 2 == 0 else { return nil }
        var data = Data()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard let byte = UInt8(hex[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        self = data
    }
}

try main()
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift build 2>&1 | tail -5
```

Build must succeed with no errors.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw5a0b1c2d3e-DONE.txt`:

```
STEP: ybs-step_sw5a0b1c2d3e
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/SwiftSender/main.swift
VERIFICATION: PASSED (swift build succeeds)
NEXT: ybs-step_sw5b0c1d2e3f
```

Update `BUILD_STATUS.md`: add `- [x] sw5a0b1c2d3e`.
