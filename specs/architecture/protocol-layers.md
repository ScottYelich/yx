# YX Protocol: Protocol Layer Architecture

**Version:** 1.0.0
**Date:** 2026-01-18
**Status:** Normative Specification
**Traceability:** Gap 1.1, 1.2, 1.3, 1.4

---

## Overview

The YX protocol implements a three-layer architecture:

1. **Transport Layer** - HMAC + GUID + Payload (UDP delivery)
2. **Protocol Layer** - Protocol 0 (Text) or Protocol 1 (Binary)
3. **Application Layer** - Message handling and RPC dispatch

This document describes the protocol layer architecture, protocol routing, and layer interactions.

---

## Layer Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                         │
│  (JSON-RPC dispatch, message handlers, business logic)       │
└──────────────────────────────────────────────────────────────┘
                            ↑
                            │ Decoded Message
                            │
┌──────────────────────────────────────────────────────────────┐
│                      PROTOCOL LAYER                           │
│                                                               │
│  ┌────────────────────┐          ┌─────────────────────────┐ │
│  │  Protocol Router   │          │   Protocol Handlers     │ │
│  │  (Routes by ID)    │────────▶ │  - TextProtocol (0x00) │ │
│  └────────────────────┘          │  - BinaryProtocol(0x01)│ │
│                                   └─────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                            ↑
                            │ Validated Payload
                            │
┌──────────────────────────────────────────────────────────────┐
│                      TRANSPORT LAYER                          │
│  (UDP + HMAC validation + Replay + Rate Limiting)            │
└──────────────────────────────────────────────────────────────┘
                            ↑
                            │ Raw UDP Datagram
                            │
┌──────────────────────────────────────────────────────────────┐
│                      NETWORK LAYER                            │
│  (UDP/IP, OS kernel)                                          │
└──────────────────────────────────────────────────────────────┘
```

---

## Transport Layer (Layer 1)

### Responsibility
Deliver authenticated UDP packets with integrity verification and security enforcement.

### Wire Format
```
[HMAC(16 bytes)] + [GUID(6 bytes)] + [Payload(variable)]
```

### Components

**1. UDP Socket**
- Binds to port (default: 50000)
- Receives raw datagrams
- Sends datagrams to broadcast address

**2. Packet Parser**
- Extracts HMAC, GUID, Payload from raw bytes
- Validates minimum packet size (22 bytes)
- Returns structured Packet object

**3. HMAC Validator**
- Looks up key by GUID (per-peer keys)
- Recomputes HMAC over GUID + Payload
- Compares using constant-time comparison
- Logs failures to `/tmp/hmac_failures.log`

**4. Replay Protection (Optional)**
- Extracts nonce (HMAC value)
- Checks if nonce seen before
- Records new nonces with timestamp
- Rejects replayed packets

**5. Rate Limiter (Optional)**
- Tracks requests per peer (sliding window)
- Enforces limits (default: 10,000 req/60s)
- Supports trusted GUID whitelist
- Rejects over-limit packets

### Output
Validated payload (bytes) passed to Protocol Layer.

### Error Handling
- Packet too small → DROP (silent)
- HMAC invalid → DROP + log to /tmp
- Replay detected → DROP + log warning
- Rate limit exceeded → DROP + log warning

---

## Protocol Layer (Layer 2)

### Responsibility
Decode protocol-specific payload format and handle message reassembly.

### Protocol Routing

**Routing Algorithm:**
```
1. Receive validated payload from Transport Layer
2. Extract first byte (Protocol ID)
3. Route to appropriate protocol handler:
   - 0x00 → TextProtocol handler
   - 0x01 → BinaryProtocol handler
   - Other → Log error, drop packet
```

### Protocol ID Registry

| Protocol ID | Protocol Name | Status | Handler |
|-------------|---------------|--------|---------|
| 0x00 | Text/JSON-RPC | ✅ Required | TextProtocol |
| 0x01 | Binary/Chunked | ✅ Required | BinaryProtocol |
| 0x21 | Task Hello (Reserved) | ⚠️ Optional | TaskHelloHandler |
| 0x22 | RPC Chain (Reserved) | ⚠️ Optional | RPCChainHandler |
| 0x23 | Task Chain (Reserved) | ⚠️ Optional | TaskChainHandler |
| 0x02-0x20 | Reserved for future | - | - |
| 0x24-0xFF | Available | - | - |

**Extension Point:** New protocols can be added by implementing handler interface and registering with router.

---

## Protocol 0: Text/JSON-RPC

### Purpose
Human-readable text messages for RPC calls, status requests, and debugging.

### Wire Format
```
[Protocol ID: 0x00] + [UTF-8 JSON payload]
```

### Characteristics
- **Single packet:** No chunking, entire message in one UDP packet
- **Max size:** ~1450 bytes (UDP MTU - YX header)
- **Encoding:** UTF-8
- **Format:** JSON-RPC 2.0 (recommended) or plain JSON
- **Compression:** None
- **Encryption:** None
- **Reliability:** UDP semantics (best-effort)

### JSON-RPC 2.0 Format

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "method": "task.hello",
  "params": {
    "name": "Alice",
    "timestamp": 1705600000
  }
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "result": {
    "status": "ok",
    "message": "Hello, Alice!"
  }
}
```

**Error:**
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "error": {
    "code": -32601,
    "message": "Method not found"
  }
}
```

### Handler Responsibilities

**Receive Path:**
```
1. Verify first byte is 0x00
2. Extract payload[1:] (skip protocol ID)
3. Decode as UTF-8
4. Parse as JSON
5. Validate JSON-RPC structure (if applicable)
6. Dispatch to application callback
```

**Send Path:**
```
1. Encode message as JSON
2. Convert to UTF-8 bytes
3. Prepend protocol ID (0x00)
4. Pass to Transport Layer for HMAC + send
```

### Use Cases
- RPC method calls
- Configuration requests
- Status queries
- Debugging messages
- Command/control messages

### Limitations
- Single packet only (no multi-packet messages)
- No compression (payload visible in full size)
- No encryption (payload visible in plaintext)
- No reassembly (message must fit in one UDP packet)

---

## Protocol 1: Binary/Chunked (v2.0)

### Purpose
High-performance binary data with optional compression/encryption and support for large messages.

### Wire Format
```
[Protocol ID: 0x01] + [protoOpts: 1 byte] + [channelID: 2 bytes] +
[sequence: 4 bytes] + [chunkIndex: 4 bytes] + [totalChunks: 4 bytes] +
[chunk data: variable]
```

### Header Fields

| Field | Size | Type | Range | Description |
|-------|------|------|-------|-------------|
| Protocol ID | 1 byte | uint8 | 0x01 | Always 0x01 for Binary Protocol |
| protoOpts | 1 byte | uint8 | 0x00-0x03 | Compression/encryption flags |
| channelID | 2 bytes | uint16 | 0-65535 | Logical channel number |
| sequence | 4 bytes | uint32 | 0-2^32-1 | Per-channel sequence number |
| chunkIndex | 4 bytes | uint32 | 0-N | Current chunk (0-based) |
| totalChunks | 4 bytes | uint32 | 1-N | Total chunks in message |

**Total Header Size:** 16 bytes

### protoOpts Flags

| Value | Binary | Compression | Encryption | Description |
|-------|--------|-------------|------------|-------------|
| 0x00 | 00 | No | No | Plain binary, no processing |
| 0x01 | 01 | Yes (ZLIB) | No | Compressed only |
| 0x02 | 10 | No | Yes (AES-GCM) | Encrypted only |
| 0x03 | 11 | Yes | Yes | Compressed then encrypted |

### Channel Multiplexing

**Channel Isolation:**
- 65,536 independent channels (16-bit channelID)
- Each channel has independent sequence counter (32-bit)
- Messages on different channels do not interfere
- Enables concurrent multi-stream communication

**Buffer Key:** `(channelID, sequence)` tuple
- Uniquely identifies a message being reassembled
- Multiple messages can reassemble concurrently
- No blocking between channels

**Use Cases:**
- Channel 0: Command/control messages
- Channel 1: Market data stream
- Channel 2: Order flow
- Channel 3: Heartbeats
- Channels 4-65535: Application-specific

### Chunking

**Chunk Size:** Default 1024 bytes (configurable)

**Why Chunking:**
- UDP MTU typically 1500 bytes
- YX header (22 bytes) + Protocol 1 header (16 bytes) = 38 bytes overhead
- Safe chunk data size: 1024 bytes (total packet ~1062 bytes, under MTU)
- Enables arbitrarily large messages (2^32 chunks × chunk size)

**Reassembly:**
```
1. Receive chunk with (channelID, sequence, chunkIndex, totalChunks)
2. Buffer key = (channelID, sequence)
3. Store chunk at chunks[chunkIndex]
4. If all chunks received (len(chunks) == totalChunks):
   a. Reassemble in chunk order
   b. Remove from buffer (prevent re-processing)
   c. Proceed to decryption/decompression
```

**Stale Buffer Management:**
- Buffer timeout: 60 seconds (default)
- Incomplete messages removed after timeout
- Prevents memory leaks from partial messages

### Compression (protoOpts & 0x01)

**Algorithm:** ZLIB (RFC 1951)
**Format:** Raw DEFLATE (wbits=-15)
**Level:** Default 6 (balanced)

**When Applied:** Before encryption, after application data

**Python:**
```python
compressed = zlib.compress(data, level=6, wbits=-15)
```

**Swift:**
```swift
let compressed = data.compressed(using: .zlib)
```

**Wire Format Compatibility:** Both produce identical raw DEFLATE streams.

### Encryption (protoOpts & 0x02)

**Algorithm:** AES-256-GCM
**Key Size:** 32 bytes
**Nonce Size:** 12 bytes (random per encryption)
**Tag Size:** 16 bytes

**When Applied:** After compression (if enabled), before chunking

**Wire Format:**
```
[nonce(12)] + [ciphertext(variable)] + [tag(16)]
```

**Critical:** Encryption applied to FULL reassembled message, not per-chunk.

### Deduplication

**Purpose:** Prevent duplicate delivery of same message (e.g., retransmissions).

**Algorithm:**
- Track processed `(channelID, sequence)` tuples
- Deduplication window: 5 seconds (default)
- If seen before: silently drop
- If new: proceed with processing

### Processing Pipeline

**Send Path:**
```
Application Data
    ↓
IF protoOpts & 0x01: Compress with ZLIB
    ↓
IF protoOpts & 0x02: Encrypt with AES-256-GCM
    ↓
Chunk into 1024-byte pieces
    ↓
FOR each chunk:
  - Build 16-byte header
  - Prepend to chunk data
  - Pass to Transport Layer (HMAC + send)
```

**Receive Path:**
```
Validated Payload from Transport Layer
    ↓
Parse 16-byte header
    ↓
Buffer chunk by (channelID, sequence)
    ↓
Check deduplication cache (if dup: DROP)
    ↓
IF all chunks received:
  - Reassemble in chunk order
  - IF protoOpts & 0x02: Decrypt with AES-256-GCM
  - IF protoOpts & 0x01: Decompress with ZLIB
  - Dispatch to application callback
```

### Handler Responsibilities

**Receive Path:**
```
1. Verify first byte is 0x01
2. Parse 16-byte header
3. Extract channelID, sequence, chunkIndex, totalChunks, protoOpts
4. Buffer management:
   a. Create buffer entry if not exists
   b. Store chunk at chunkIndex
   c. Check if all chunks received
5. If complete:
   a. Reassemble chunks
   b. Decrypt (if protoOpts & 0x02)
   c. Decompress (if protoOpts & 0x01)
   d. Dispatch to application
   e. Remove from buffer
6. Periodic cleanup of stale buffers (60s timeout)
```

**Send Path:**
```
1. Get next sequence number for channel
2. Compress (if protoOpts & 0x01)
3. Encrypt (if protoOpts & 0x02)
4. Chunk processed data
5. FOR each chunk:
   a. Build header (proto=0x01, protoOpts, channelID, sequence, chunkIndex, totalChunks)
   b. Payload = header + chunk_data
   c. Pass to Transport Layer
```

### Use Cases
- Large messages (>1KB)
- Compressed data (logs, JSON, text)
- Encrypted data (sensitive information)
- High-throughput streams
- Binary protocols (Protobuf, MessagePack, CBOR)

---

## Protocol Router

### Purpose
Route validated payloads to appropriate protocol handler based on Protocol ID.

### Architecture

**Python:**
```python
class ProtocolRouter:
    def __init__(self):
        self._handlers = {}  # Dict[int, ProtocolHandler]

    def register(self, protocol_id: int, handler: ProtocolHandler):
        """Register protocol handler."""
        self._handlers[protocol_id] = handler

    async def route(self, payload: bytes):
        """Route payload to handler by protocol ID."""
        if not payload:
            return  # Empty payload

        protocol_id = payload[0]

        handler = self._handlers.get(protocol_id)
        if handler is None:
            logger.error(f"Unknown protocol ID: {protocol_id:02x}")
            return  # Drop packet

        await handler.handle(payload)
```

**Swift:**
```swift
actor ProtocolRouter {
    private var handlers: [UInt8: ProtocolHandler] = [:]

    func register(protocolID: UInt8, handler: ProtocolHandler) {
        handlers[protocolID] = handler
    }

    func route(payload: Data) async {
        guard !payload.isEmpty else { return }

        let protocolID = payload[0]

        guard let handler = handlers[protocolID] else {
            print("Unknown protocol ID: \(String(format: "0x%02x", protocolID))")
            return
        }

        await handler.handle(payload: payload)
    }
}
```

### Handler Interface

**Python:**
```python
class ProtocolHandler(Protocol):
    async def handle(self, payload: bytes):
        """Process received payload."""
        ...

    async def send(self, data: bytes, host: str, port: int):
        """Send data using this protocol."""
        ...
```

**Swift:**
```swift
protocol ProtocolHandler {
    func handle(payload: Data) async
    func send(data: Data, to host: String, port: Int) async throws
}
```

### Registration

**Python:**
```python
router = ProtocolRouter()
router.register(0x00, text_protocol)
router.register(0x01, binary_protocol)
```

**Swift:**
```swift
let router = ProtocolRouter()
await router.register(protocolID: 0x00, handler: textProtocol)
await router.register(protocolID: 0x01, handler: binaryProtocol)
```

---

## Layer Interactions

### Send Path (Application → Network)

```
APPLICATION LAYER
    ↓ (message to send)
PROTOCOL LAYER
    ├─ Protocol 0: Prepend 0x00, UTF-8 encode
    └─ Protocol 1: Compress → Encrypt → Chunk → Build headers
    ↓ (payload bytes)
TRANSPORT LAYER
    ├─ Compute HMAC (GUID + Payload)
    ├─ Build packet [HMAC(16) + GUID(6) + Payload]
    └─ Send UDP datagram
    ↓
NETWORK LAYER
```

### Receive Path (Network → Application)

```
NETWORK LAYER
    ↓ (UDP datagram)
TRANSPORT LAYER
    ├─ Parse packet [HMAC + GUID + Payload]
    ├─ Validate HMAC (constant-time)
    ├─ Check replay protection
    └─ Check rate limiting
    ↓ (validated payload)
PROTOCOL LAYER (ROUTER)
    ├─ Extract protocol ID (first byte)
    └─ Route to handler (TextProtocol or BinaryProtocol)
    ↓
PROTOCOL HANDLER
    ├─ Protocol 0: Decode UTF-8, parse JSON
    └─ Protocol 1: Reassemble → Decrypt → Decompress
    ↓ (decoded message)
APPLICATION LAYER
```

---

## Design Principles

### 1. Separation of Concerns
- Transport Layer: Security and delivery
- Protocol Layer: Encoding and reassembly
- Application Layer: Business logic

### 2. Protocol Agnostic Transport
- Transport Layer doesn't care about protocol format
- Payload is opaque bytes to Transport Layer
- Protocol Layer adds structure

### 3. Extensibility
- New protocols can be added without changing Transport Layer
- Handler interface defines contract
- Router dynamically dispatches

### 4. Channel Isolation
- Protocol 1 channels don't interfere
- Enables concurrent message streams
- Per-channel sequence counters

### 5. Compression Before Encryption
- Compression more effective on plaintext
- Encrypted data appears random (incompressible)
- Order: Compress → Encrypt → Chunk

### 6. Encrypt Before Chunking
- Encryption applied to FULL message
- Prevents attacks on partial ciphertexts
- Simpler key management

---

## Performance Characteristics

### Protocol 0 (Text)
- **Latency:** Lowest (single packet, no processing)
- **Throughput:** Limited by MTU (~1450 bytes/message)
- **CPU:** Minimal (JSON encoding only)
- **Use Case:** Low-latency RPC, commands, status

### Protocol 1 (Binary, 0x00)
- **Latency:** Low (chunking overhead only)
- **Throughput:** Unlimited (2^32 chunks)
- **CPU:** Minimal (chunking only)
- **Use Case:** Large binary data

### Protocol 1 (Binary, 0x01 Compressed)
- **Latency:** Medium (compression overhead)
- **Throughput:** High (reduced bandwidth)
- **CPU:** Medium (ZLIB compression)
- **Use Case:** Large compressible data (logs, JSON, text)

### Protocol 1 (Binary, 0x02 Encrypted)
- **Latency:** Medium (encryption overhead)
- **Throughput:** Unlimited
- **CPU:** Medium (AES-GCM)
- **Use Case:** Sensitive data

### Protocol 1 (Binary, 0x03 Both)
- **Latency:** Highest (compression + encryption)
- **Throughput:** High (compression reduces size)
- **CPU:** High (both operations)
- **Use Case:** Large sensitive data

---

## Protocol Selection Guide

### When to Use Protocol 0 (Text)

✅ **Good For:**
- RPC method calls (< 1KB payloads)
- Configuration messages
- Status requests
- Debugging (human-readable)
- Command/control messages

❌ **NOT Good For:**
- Large messages (>1KB)
- Binary data
- Sensitive data (no encryption)
- High-throughput streams

### When to Use Protocol 1 (Binary)

✅ **Good For:**
- Large messages (>1KB)
- Binary protocols (Protobuf, MessagePack)
- High-throughput data streams
- Sensitive data (with encryption)
- Compressible data (with compression)

❌ **NOT Good For:**
- Simple RPC calls (overkill)
- Maximum latency sensitivity (chunking overhead)
- Debugging (not human-readable)

---

## Testing Requirements

### Protocol 0 Tests
- [ ] Simple JSON message
- [ ] Large JSON (>1KB, near MTU)
- [ ] Invalid JSON rejection
- [ ] UTF-8 encoding/decoding
- [ ] Cross-language compatibility

### Protocol 1 Tests
- [ ] Single chunk message
- [ ] Multi-chunk message (>1KB)
- [ ] Compression (protoOpts 0x01)
- [ ] Encryption (protoOpts 0x02)
- [ ] Compression + encryption (protoOpts 0x03)
- [ ] Channel isolation
- [ ] Stale buffer cleanup
- [ ] Deduplication
- [ ] Cross-language compatibility

### Protocol Router Tests
- [ ] Route Protocol 0 to TextProtocol
- [ ] Route Protocol 1 to BinaryProtocol
- [ ] Unknown protocol ID rejected
- [ ] Empty payload handled

---

## Implementation Checklist

### Python Implementation
- [ ] TextProtocol class with handle() and send()
- [ ] BinaryProtocol class with handle() and send()
- [ ] ProtocolRouter with registration and routing
- [ ] Protocol 0 tests passing
- [ ] Protocol 1 tests passing
- [ ] Router tests passing

### Swift Implementation
- [ ] TextProtocol actor with handle() and send()
- [ ] BinaryProtocol actor with handle() and send()
- [ ] ProtocolRouter actor with registration and routing
- [ ] Protocol 0 tests passing
- [ ] Protocol 1 tests passing
- [ ] Router tests passing

### Cross-Language Validation
- [ ] Protocol 0: Python → Swift
- [ ] Protocol 0: Swift → Python
- [ ] Protocol 1 (0x00): Python → Swift
- [ ] Protocol 1 (0x01): Python → Swift
- [ ] Protocol 1 (0x02): Python → Swift
- [ ] Protocol 1 (0x03): Python → Swift
- [ ] All combinations (N²) tested

---

## Version History

- **1.0.0** (2026-01-18): Initial specification

---

## References

**Related Specifications:**
- `specs/technical/yx-protocol-spec.md` - Complete protocol details
- `specs/architecture/security-architecture.md` - Security layer
- `specs/testing/interoperability-requirements.md` - Testing requirements
- `specs/technical/default-values.md` - Default configurations
