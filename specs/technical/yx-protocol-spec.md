# YX UDP Protocol Specification

## Overview

YX is a secure, payload-agnostic UDP-based networking protocol with HMAC integrity, optional encryption/compression, and chunked delivery for large messages.

**Version:** 1.0.3 (Binary Protocol v2.0)
**Transport:** UDP broadcast
**Default Port:** 50000
**Languages:** Python, Swift (wire-format parity)

---

## Wire Format

### Packet Structure (3 Layers)

```
┌────────────────┬──────────────┬──────────────────────────────────┐
│  HMAC (16B)    │  GUID (6B)   │  Payload (variable)              │
└────────────────┴──────────────┴──────────────────────────────────┘
   0          16  17         22  23                              ...
```

**Minimum packet size:** 22 bytes (16 HMAC + 6 GUID)

### Layer 1: HMAC (16 bytes, offset 0-15)

- **Algorithm:** HMAC-SHA256 truncated to 128 bits (16 bytes)
- **Input:** `GUID (6 bytes) + Payload (all remaining bytes)`
- **Key:** 32-byte shared symmetric key
- **Validation:** Constant-time comparison on receive
- **Purpose:** Packet integrity verification

**Computation:**
```python
hmac_input = guid_6_bytes + payload_bytes
hmac_value = HMAC-SHA256(hmac_input, key)[0:16]  # Truncate to 16 bytes
```

### Layer 2: GUID (6 bytes, offset 16-21)

- **Purpose:** Sender identification
- **Format:** 6 random bytes from cryptographically secure RNG
- **Encoding:** Raw binary, no internal structure
- **Padding:** Zero-padded to exactly 6 bytes if source is shorter

### Layer 3: Payload (variable, offset 22+)

- **Format:** Protocol-agnostic binary data
- **Protocol Detection:** First byte determines protocol type
  - `0x00-0x1F` = Binary protocol (first byte is Protocol ID)
  - `0x20+` = Text protocol (typically ASCII/UTF-8)

---

## Protocol Versions

### Protocol 0: Text Protocol

**Characteristics:**
- **Protocol Marker:** First byte `0x00`
- **Format:** Plain UTF-8 encoded text (typically JSON)
- **Security:** HMAC integrity only (no encryption)
- **Compression:** None
- **Chunking:** Single packet delivery only
- **Use Case:** Simple text/JSON messages that fit in single UDP packet

**Payload Structure:**
```
┌──────┬────────────────────────────┐
│ 0x00 │  UTF-8 encoded text        │
└──────┴────────────────────────────┘
   0     1                        ...
```

### Protocol 1: Binary Protocol v2.0

**Characteristics:**
- **Protocol Marker:** First byte `0x01`
- **Format:** Structured header + optional compression/encryption + chunking
- **Security:** HMAC + optional AES-256-GCM encryption
- **Compression:** Optional ZLIB compression
- **Chunking:** Supports multi-packet messages (default 1024 byte chunks)
- **Use Case:** Large messages, encrypted messages, high-throughput data

**Header Structure (16 bytes):**
```
┌──────┬──────────┬───────────┬──────────┬────────────┬─────────────┐
│proto │protoOpts │channelID  │sequence  │chunkIndex  │totalChunks  │
│ 1B   │   1B     │    2B     │   4B     │    4B      │     4B      │
└──────┴──────────┴───────────┴──────────┴────────────┴─────────────┘
   0      1          2-3        4-7        8-11         12-15
```

**Field Descriptions:**

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `proto` | uint8 | 0x01 | Protocol version identifier |
| `protoOpts` | uint8 | 0x00-0x03 | Bit flags for compression/encryption |
| `channelID` | uint16 | 0-65535 | Logical channel for message isolation |
| `sequence` | uint32 | 0-4294967295 | Per-channel message sequence number |
| `chunkIndex` | uint32 | 0-N | Current chunk index (0-based) |
| `totalChunks` | uint32 | 1-N | Total number of chunks for this message |

**protoOpts Flags (1 byte):**

| Value | Hex | Compression | Encryption | Description |
|-------|-----|-------------|------------|-------------|
| 0 | 0x00 | No | No | Plaintext, uncompressed |
| 1 | 0x01 | Yes | No | ZLIB compressed, plaintext |
| 2 | 0x02 | No | Yes | Uncompressed, AES-256-GCM encrypted |
| 3 | 0x03 | Yes | Yes | ZLIB compressed + AES-256-GCM encrypted |

**Binary Protocol v2.0 Changes:**

v1.0 used `msgID` (1 byte) for message identification. v2.0 replaced this with:
- `channelID` (2 bytes) - Allows 65,536 logical channels
- `sequence` (4 bytes) - Per-channel sequence numbers (4B range per channel)
- **Buffer Key:** `(channelID, sequence)` tuple instead of `GUID + msgID`
- **Benefit:** Better scalability for high-throughput applications

---

## Security Mechanisms

### 1. HMAC-SHA256 Integrity

**Purpose:** Verify packet integrity and authenticity

**Implementation:**
```python
def compute_hmac(data: bytes, key: bytes) -> bytes:
    h = hmac.HMAC(key, hashes.SHA256())
    h.update(data)
    return h.finalize()[:16]  # Truncate to 16 bytes
```

**Properties:**
- 32-byte symmetric key shared across all peers
- Computed over `GUID + Payload`
- Constant-time validation to prevent timing attacks
- Failed validations logged to `/tmp/hmac_failures.log` for forensics

### 2. AES-256-GCM Encryption

**Purpose:** Confidentiality and authenticity of payload data

**Algorithm:** AES-256 in Galois/Counter Mode (GCM)

**Implementation:**
```python
def encrypt_aes_gcm(plaintext: bytes, key: bytes) -> Tuple[bytes, bytes]:
    aesgcm = AESGCM(key)  # 32-byte key
    nonce = os.urandom(12)  # 96-bit random nonce
    ciphertext = aesgcm.encrypt(nonce, plaintext, None)
    return nonce, ciphertext  # ciphertext includes 16-byte auth tag
```

**Properties:**
- **Key Size:** 256 bits (32 bytes)
- **Nonce:** 12 bytes, randomly generated per encryption
- **Authentication Tag:** 16 bytes (built into GCM mode)
- **Overhead:** 28 bytes per encrypted message (12 nonce + 16 tag)
- **Nonce Storage:** Prepended to ciphertext: `nonce(12) + ciphertext + tag(16)`

**CRITICAL:** Applied to FULL reassembled message, not per-chunk

### 3. ZLIB Compression

**Purpose:** Reduce bandwidth for compressible payloads

**Algorithm:** DEFLATE (RFC 1951)

**Implementation:**
```python
def compress_data(data: bytes, level: int = 6) -> bytes:
    compressor = zlib.compressobj(level=level, wbits=-15)  # Raw DEFLATE
    return compressor.compress(data) + compressor.flush()

def decompress_data(compressed: bytes) -> bytes:
    return zlib.decompress(compressed, wbits=-15)
```

**Properties:**
- **Mode:** Raw DEFLATE (no zlib wrapper, `wbits=-15`)
- **Level:** Default 6 (balanced speed/compression)
- **Order:** Always compress BEFORE encryption

**CRITICAL:** Applied to FULL message before encryption and chunking

### 4. Rate Limiting

**Purpose:** Defense against packet flood DoS attacks

**Algorithm:** Sliding window per peer

**Implementation:**
- Tracks timestamps per peer: `Dict[peer_id, List[timestamp]]`
- Removes requests older than window (default: 60 seconds)
- Rejects if request count ≥ threshold (default: 10,000 requests/60s)
- **Trusted GUIDs:** Can bypass rate limiting (whitelist)

**Default Configuration:**
- `max_requests`: 10,000
- `window_seconds`: 60.0
- `trusted_guids`: Empty set

### 5. Replay Protection

**Purpose:** Prevent replay attacks using captured packets

**Algorithm:** Nonce cache with TTL

**Implementation:**
- Tracks seen nonces: `Dict[nonce_bytes, timestamp]`
- **Nonce:** First 16 bytes of packet (HMAC value)
- **TTL:** 300 seconds (5 minutes, configurable)
- **Cleanup:** Automatic removal of expired nonces

**Properties:**
- Returns `False` if nonce seen within TTL window (replay detected)
- Returns `True` if new nonce (allowed, then recorded)
- Memory bounded by TTL and packet rate

### 6. Key Management

**KeyStore:**
- **Default Key:** 32-byte shared symmetric key (all peers)
- **Per-Peer Keys:** Optional override for specific peers by GUID
- **Lookup:** GUID hex string → 32-byte key
- **Validation:** All keys must be exactly 32 bytes

---

## Message Processing Pipeline

### Send Path

**Protocol 0 (Text):**
```
1. Encode message as UTF-8
2. Prepend protocol marker (0x00)
3. Build packet: Compute HMAC over GUID + Payload
4. Serialize: HMAC(16) + GUID(6) + Payload
5. Send via UDP socket
```

**Protocol 1 (Binary):**
```
1. Get next sequence number for channel: sequence = counter[channelID]++
2. IF protoOpts & 0x01: Compress FULL message with ZLIB
3. IF protoOpts & 0x02: Encrypt FULL message with AES-256-GCM
4. Chunk processed data into 1024-byte pieces (configurable)
5. FOR each chunk:
   a. Build 16-byte header (proto, protoOpts, channelID, sequence, chunkIndex, totalChunks)
   b. Payload = header + chunk_data
   c. Build packet: Compute HMAC over GUID + Payload
   d. Serialize: HMAC(16) + GUID(6) + Payload
   e. Send via UDP socket
```

### Receive Path

**All Protocols:**
```
1. Receive UDP datagram
2. Parse packet: Extract HMAC(16), GUID(6), Payload(remaining)
3. Validate minimum size (22 bytes)
4. Lookup key by GUID (or use default)
5. Recompute HMAC over GUID + Payload
6. Constant-time compare: Reject if HMAC mismatch
7. IF replay_protection enabled: Check nonce cache, reject if seen
8. IF rate_limiter enabled: Check sliding window, reject if over limit
9. Ignore self-packets (unless process_own_packets=True)
10. Route to protocol handler by first payload byte
```

**Protocol 0 (Text) Handler:**
```
1. Verify first byte is 0x00
2. Decode payload[1:] as UTF-8
3. Parse as JSON (or other text format)
4. Dispatch to application callback
```

**Protocol 1 (Binary) Handler:**
```
1. Parse header: Extract channelID, sequence, chunkIndex, totalChunks, protoOpts
2. Buffer key = (channelID, sequence)
3. Check deduplication cache (5-second window)
4. IF duplicate: Ignore
5. Store chunk in buffer: buffer[key][chunkIndex] = chunk_data
6. IF all chunks received (len(buffer[key]) == totalChunks):
   a. Pop buffer[key] immediately (prevents re-processing)
   b. Reassemble chunks in index order
   c. IF protoOpts & 0x02: Decrypt with AES-256-GCM (extract nonce from first 12 bytes)
   d. IF protoOpts & 0x01: Decompress with ZLIB
   e. Parse result (typically JSON-RPC)
   f. Dispatch to application callback
```

**Message Reassembly:**
- Buffer: `Dict[(channelID, sequence), BufferEntry]`
- BufferEntry: `{chunks: Dict[index, bytes], total_chunks: int, created_at: float}`
- Timeout: 60 seconds for incomplete buffers (auto-cleanup)
- Deduplication: Track processed `(channelID, sequence)` for 5 seconds

---

## Transport Layer

### UDP Socket Configuration

**Binding:**
- Address: `0.0.0.0:port` (all interfaces)
- Default port: 50000
- Protocol: UDP (SOCK_DGRAM)

**Socket Options:**
- `SO_REUSEADDR` - Allow immediate rebind after restart
- `SO_REUSEPORT` - Multiple processes on same IP:port (macOS/Linux)
- `SO_BROADCAST` - Enable UDP broadcast transmission

**Broadcast Target:**
- Address: `255.255.255.255:50000`
- All packets sent via broadcast (no unicast)
- Services filter by method name, request ID, or target service ID

### Asyncio Integration (Python)

**UDPTransport:**
- Uses `asyncio.DatagramProtocol` for async packet handling
- Creates new task for each received packet (non-blocking)
- Supports graceful shutdown (closes socket, cancels tasks)

**Packet Handling:**
```python
async def _handle_packet(self, data: bytes, addr: tuple):
    # 1. Parse packet
    # 2. Validate HMAC
    # 3. Check replay protection
    # 4. Check rate limits
    # 5. Invoke callback with (guid, payload, addr)
```

### Protocol Router

**Routing Logic:**
```python
async def route(self, payload: bytes):
    if not payload:
        return

    protocol_id = payload[0]

    if protocol_id == 0x00:
        await text_protocol_handler(payload)
    elif protocol_id == 0x01:
        await binary_protocol_handler(payload)
    else:
        log_error(f"Unknown protocol ID: {protocol_id:02x}")
```

---

## Key Design Principles

### 1. Payload Agnostic
YX doesn't care what you send. The protocol layer handles:
- Integrity (HMAC)
- Confidentiality (AES-GCM, optional)
- Compression (ZLIB, optional)
- Chunking (for large messages)

Application layer decides payload format (JSON, Protobuf, MessagePack, raw binary, etc.)

### 2. Broadcast-First Architecture
- All communication via UDP broadcast (`255.255.255.255`)
- No unicast delivery (kernel `SO_REUSEPORT` causes non-deterministic routing)
- Receivers filter messages by:
  - Method name
  - Request ID
  - Target service ID
  - Channel ID

### 3. Encrypt-Then-Chunk
**Security Best Practice:**
- Compress FULL message
- Encrypt FULL compressed message
- Then chunk encrypted result

**Reason:** Prevents cryptographic attacks on partial data

### 4. Channel Isolation
- 65,536 logical channels (16-bit `channelID`)
- Each channel has independent 4B sequence space
- Use cases:
  - Per-service channels
  - Per-topic channels
  - Priority lanes

### 5. Cross-Platform Wire Format
- Python and Swift implementations have 100% wire-format parity
- Identical byte layout for all protocol versions
- Struct packing: Big-endian (`>`) for all multi-byte integers

---

## Implementation Files (Python)

### Core Transport
- `yx/transport/packet.py` - Packet dataclass
- `yx/transport/packet_builder.py` - Build/parse/validate packets
- `yx/transport/udp_transport.py` - Socket + asyncio integration
- `yx/transport/protocol_router.py` - Protocol routing by first byte

### Protocols
- `yx/transport/text_protocol.py` - Protocol 0 handler
- `yx/transport/binary_protocol.py` - Protocol 1 handler (v2.0)

### Security
- `yx/primitives/data_crypto.py` - HMAC-SHA256, AES-256-GCM
- `yx/primitives/data_compression.py` - ZLIB compression
- `yx/transport/key_store.py` - Key management
- `yx/transport/rate_limiter.py` - Rate limiting
- `yx/transport/replay_protection.py` - Replay protection

### Utilities
- `yx/primitives/data_chunking.py` - Chunking logic
- `yx/primitives/guid_factory.py` - GUID generation

### Application
- `yx/application/yx_coordinator.py` - Composition root
- `yx/application/configuration.py` - Configuration dataclass
- `yx/YX.py` - High-level facade API

---

## Reference Documentation

**Full Protocol Spec:**
- `../sdts/docs/udp-packet-format.md` (719 lines) - Complete specification with version history

**Implementation Reference:**
- `../sdts/src/python/yx/` - Python implementation (v1.0.3)
- `../sdts/src/swift/yx/` - Swift implementation (wire-format parity)

---

## Version History

**v1.0.3 (Current)**
- Binary Protocol v2.0 with `(channelID, sequence)` tuple
- Python and Swift wire-format parity
- Production-ready stability

**v1.0.0**
- Binary Protocol v1.0 with `msgID` (1 byte)
- Initial release

---

## Technical Notes

1. **HMAC Truncation:** 128 bits provides adequate security for packet integrity
2. **Chunk Size:** Default 1024 bytes balances MTU efficiency and reassembly overhead
3. **Nonce Reuse:** Each AES-GCM encryption uses fresh random nonce (critical for security)
4. **Deduplication:** 5-second window prevents duplicate processing of retransmitted packets
5. **Thread Safety:** Python implementation uses asyncio (not thread-safe for multi-threaded use)
6. **MTU Awareness:** 1024-byte chunks + 22-byte YX header + 16-byte Binary header = ~1062 bytes (under 1500 MTU)
7. **No TLS Required:** HMAC + AES-GCM provides end-to-end security without TLS overhead
