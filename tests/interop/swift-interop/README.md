# YX Protocol Swift Interoperability Test Programs

This directory contains Swift sender and receiver programs for YX protocol interoperability testing.

## Structure

```
swift/
├── Package.swift                    # Swift package manifest
├── Sources/
│   ├── Senders/
│   │   ├── Transport/              # 5 transport layer senders
│   │   ├── Proto0/                 # 3 Protocol 0 (text) senders
│   │   └── Proto1/                 # 4 Protocol 1 (binary) senders
│   └── Receivers/
│       ├── TransportReceiver.swift # Transport layer receiver
│       ├── Proto0Receiver.swift    # Protocol 0 receiver
│       └── Proto1Receiver.swift    # Protocol 1 receiver
└── .build/debug/                   # Built executables (after build)
```

## Building

```bash
cd tests/interop/swift
swift build
```

This builds 15 executables:
- **5 transport senders**: simple, empty, large, multiple, invalid
- **3 Proto0 senders**: json, large, invalid
- **4 Proto1 senders**: base, compressed, encrypted, both
- **3 receivers**: transport, proto0, proto1

## Running Individual Programs

```bash
# Run a sender
.build/debug/swift-sender-transport-simple

# Run a receiver (in another terminal)
.build/debug/swift-receiver-transport
```

## Environment Variables

- `TEST_YX_PORT`: Override test port (default: 49999)

## Executables

All executables are built to `.build/debug/`:

**Transport Senders:**
- `swift-sender-transport-simple` - Send simple text payload
- `swift-sender-transport-empty` - Send empty payload
- `swift-sender-transport-large` - Send 10KB payload
- `swift-sender-transport-multiple` - Send 5 packets
- `swift-sender-transport-invalid` - Send packet with invalid HMAC

**Protocol 0 Senders:**
- `swift-sender-proto0-json` - Send JSON-RPC message
- `swift-sender-proto0-large` - Send large JSON (1000 keys)
- `swift-sender-proto0-invalid` - Send invalid JSON

**Protocol 1 Senders:**
- `swift-sender-proto1-base` - Send binary data (no compression/encryption)
- `swift-sender-proto1-compressed` - Send compressed binary data
- `swift-sender-proto1-encrypted` - Send encrypted binary data
- `swift-sender-proto1-both` - Send compressed + encrypted binary data

**Receivers:**
- `swift-receiver-transport` - Receive and verify transport layer packets
- `swift-receiver-proto0` - Receive and decode Protocol 0 messages
- `swift-receiver-proto1` - Receive and reassemble Protocol 1 messages

## Integration with Test Runner

The master test runner (`../run_all_interop_tests.sh`) uses these executables for cross-language testing:

- Python → Swift tests
- Swift → Python tests
- Swift → Swift tests

All 48 tests must pass for interoperability validation.

## Traceability

- **Specification**: `specs/testing/interoperability-requirements.md`
- **Build Step**: `steps/swift/ybs-step_k5l6m7n8o9p0.md`
