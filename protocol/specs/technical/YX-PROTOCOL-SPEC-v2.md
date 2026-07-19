# YX Network Protocol Specification v2.0

**Version:** 2.0.0 (Current Production Version)
**Date:** 2025-10-19
**Status:** Production - Stable
**Previous Version:** 1.0.0 (see `YX-PROTOCOL-SPEC.md`)

**Breaking Changes:** This version is NOT backward compatible with v1.0 binary protocol. See `MIGRATION-v1-to-v2.md` for upgrade guidance.

---

## Table of Contents

1. [Overview](#overview)
2. [What's New in v2.0](#whats-new-in-v20)
3. [Packet Structure](#packet-structure)
4. [Protocol Detection](#protocol-detection)
5. [Protocol 0: Text/JSON](#protocol-0-textjson)
6. [Protocol 1: Binary/Chunked](#protocol-1-binarychunked)
7. [Security](#security)
8. [Message Flow](#message-flow)
9. [Implementation Notes](#implementation-notes)

---

## Overview

YX is a secure, peer-to-peer UDP networking protocol designed for high-performance distributed systems. It supports two protocols:

- **Protocol 0 (Text)**: JSON-RPC 2.0 messages for simple RPC communication
- **Protocol 1 (Binary)**: Chunked, optionally compressed/encrypted messages for large payloads

### Key Features

- **Packet Integrity**: HMAC-SHA256 authentication on every packet
- **Peer Identification**: 6-byte GUID per peer
- **Dual Protocols**: Text (Protocol 0) and Binary (Protocol 1)
- **Channel Isolation**: 65,535 logical channels per connection (v2.0)
- **Sequence Tracking**: 4.3 billion messages per channel (v2.0)
- **Chunking**: Automatic chunking for large messages (Protocol 1)
- **Compression**: Optional zlib compression (Protocol 1)
- **Encryption**: Optional AES-256-GCM encryption (Protocol 1)
- **Message Reassembly**: Automatic reassembly with 60-second timeout

---

## What's New in v2.0

### Header Redesign (Protocol 1 Only)

**v1.0 Header (16 bytes):**
```
[protoID(1)] + [protoOpts(1)] + [msgID(1)] + [meta(1)] + [chunkIndex(4)] + [totalChunks(4)] + [reserved(4)]
```

**v2.0 Header (16 bytes):**
```
[protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)]
```

### Key Improvements

1. **Channel-Based Architecture**
   - **65,535 logical channels** (2-byte channelID) vs 256 message IDs
   - Independent sequence spaces per channel
   - Eliminates birthday paradox collision risk (was ~50% at 16 concurrent messages)

2. **Predictable Sequencing**
   - **4.3 billion messages per channel** (4-byte sequence) vs 256 IDs
   - Linear increment: 0, 1, 2, 3, ... (enables gap detection)
   - Duplicate detection via sequence tracking

3. **Massive Capacity**
   - **Total message space**: 65K channels × 4.3B sequences = **280 trillion unique messages**
   - Per-channel flow control capability
   - Better debugging with predictable sequences

### Backward Compatibility

**Protocol 0 (Text):** ✅ **FULLY COMPATIBLE** - No changes
**Protocol 1 (Binary):** ❌ **BREAKING CHANGE** - Header format changed

**Migration:** See `MIGRATION-v1-to-v2.md` for upgrade instructions.

---

## Packet Structure

### Wire Format

All UDP packets follow this structure:

```
┌─────────────┬─────────────┬─────────────────────┐
│  HMAC (16)  │  GUID (6)   │  Payload (variable) │
└─────────────┴─────────────┴─────────────────────┘
```

**Total Minimum Size**: 22 bytes (16 + 6)

### Field Descriptions

| Field   | Size (bytes) | Type   | Description                                      |
|---------|--------------|--------|--------------------------------------------------|
| HMAC    | 16           | bytes  | HMAC-SHA256 of (GUID + Payload), truncated      |
| GUID    | 6            | bytes  | Unique peer identifier (zero-padded)             |
| Payload | variable     | bytes  | Protocol-specific data (Protocol 0 or 1)         |

### HMAC Computation

```
HMAC = HMAC-SHA256(key, GUID + Payload)[0:16]
```

- **Algorithm**: HMAC-SHA256
- **Input**: Concatenation of GUID (6 bytes) + Payload (variable)
- **Key**: Shared symmetric key (32 bytes for AES-256)
- **Output**: First 16 bytes of HMAC-SHA256 hash

### GUID Format

- **Size**: 6 bytes
- **Generation**: Random bytes from secure RNG
- **Padding**: If < 6 bytes, zero-padded on the right
- **Encoding**: Raw bytes (not hex)

---

## Protocol Detection

The protocol is detected by examining the **first byte** of the payload:

```
if payload[0] < 32:
    protocol = BINARY (Protocol 1)
else:
    protocol = TEXT (Protocol 0)
```

### Rationale

- **ASCII/JSON**: Valid JSON always starts with `{` (0x7B) or `[` (0x5B), both > 32
- **Binary**: Protocol ID 0x01 is < 32, clearly distinguishes from text

---

## Protocol 0: Text/JSON

### Purpose

Protocol 0 carries JSON-RPC 2.0 messages for simple, human-readable RPC calls.

### Payload Format

```
┌──────────────────────────┐
│  JSON String (UTF-8)     │
└──────────────────────────┘
```

**No protocol ID byte** - detected by first character being ASCII (≥ 32)

### Example

#### Wire Format (after HMAC + GUID):

```
{"method":"task.hello","params":{"name":"Alice"},"id":1}
```

### Encoding

- **Character Encoding**: UTF-8
- **JSON Format**: Standard JSON (RFC 8259)
- **Whitespace**: Optional (compact recommended for UDP)

### Size Limits

- **Maximum Payload**: ~1472 bytes (UDP MTU - HMAC - GUID)
- **Larger Messages**: Use Protocol 1 instead

### JSON-RPC 2.0 Format

```json
{
  "method": "string",       // Required: RPC method name
  "params": object,         // Optional: Method parameters
  "id": number | string     // Optional: Request ID (null for notifications)
}
```

**No changes from v1.0** - Protocol 0 remains fully compatible.

---

## Protocol 1: Binary/Chunked

### Purpose

Protocol 1 handles large payloads with optional compression and encryption. Messages are automatically chunked to fit UDP MTU. **v2.0 introduces channel-based architecture for stream isolation.**

### Payload Format

```
┌──────┬──────────┬───────────┬──────────┬────────────┬──────────────┬────────────┐
│ 0x01 │ protoOpts│ channelID │ sequence │ chunkIndex │ totalChunks  │ chunk_data │
│  (1) │    (1)   │    (2)    │    (4)   │     (4)    │      (4)     │ (variable) │
└──────┴──────────┴───────────┴──────────┴────────────┴──────────────┴────────────┘
```

**Total Header Size**: 16 bytes (unchanged from v1.0)

### Header Fields

| Field        | Offset | Size | Type      | Description                                    |
|--------------|--------|------|-----------|------------------------------------------------|
| protoID      | 0      | 1    | uint8     | Protocol identifier (0x01 = binary)            |
| protoOpts    | 1      | 1    | uint8     | Options bitfield (compression/encryption)      |
| **channelID**| 2      | 2    | uint16be  | **Logical channel (0-65535)** ⭐ NEW           |
| **sequence** | 4      | 4    | uint32be  | **Per-channel sequence (0-4.3B)** ⭐ NEW       |
| chunkIndex   | 8      | 4    | uint32be  | Index of this chunk (0-based)                  |
| totalChunks  | 12     | 4    | uint32be  | Total number of chunks in message              |
| chunk_data   | 16     | var  | bytes     | Chunk payload                                  |

**⭐ Changes from v1.0:**
- **Removed**: `msgID` (1 byte), `meta` (1 byte), `reserved` (4 bytes)
- **Added**: `channelID` (2 bytes), `sequence` (4 bytes)
- **Total size**: Unchanged (16 bytes)

### Protocol Options Bitfield (protoOpts)

| Bit | Mask | Name        | Description                       |
|-----|------|-------------|-----------------------------------|
| 0   | 0x01 | COMPRESS    | Compression enabled (zlib)        |
| 1   | 0x02 | ENCRYPT     | Encryption enabled (AES-256-GCM)  |
| 2-7 | -    | Reserved    | Reserved for future use (set to 0)|

**Valid Combinations** (unchanged from v1.0):

- `0x00`: No compression, no encryption
- `0x01`: Compression only
- `0x02`: Encryption only
- `0x03`: Both compression and encryption

### Channel Allocation Guidelines

| Range       | Purpose                                          |
|-------------|--------------------------------------------------|
| 0           | System/control messages (ping, heartbeat)       |
| 1           | Default RPC channel (JSON-RPC 2.0)               |
| 2-99        | Reserved for framework                           |
| 100-999     | Application-defined channels                     |
| 1000-65535  | User-defined channels                            |

### Sequence Numbering

- **Per-channel**: Each channel maintains independent sequence counter
- **Initial value**: 0 for first message on channel
- **Increment**: +1 for each message sent on that channel
- **Wraparound**: Wraps at 2^32 (extremely unlikely with proper channel allocation)
- **Uses**:
  - Message ordering
  - Gap detection (missing sequence numbers)
  - Duplicate detection
  - Nonce derivation for encryption

### Processing Order

#### Sending (Encode)

```
1. Original Data
   ↓
2. Compress (if 0x01 set)
   ↓
3. Encrypt (if 0x02 set)
   ↓
4. Chunk (split into ≤1024 byte chunks)
   ↓
5. Add headers to each chunk (same channelID + sequence for all chunks)
   ↓
6. Send chunks
```

#### Receiving (Decode)

```
1. Receive chunks
   ↓
2. Buffer chunks by (channelID, sequence) tuple  ⭐ CHANGED from msgID
   ↓
3. Reassemble when all chunks received
   ↓
4. Decrypt (if 0x02 set)
   ↓
5. Decompress (if 0x01 set)
   ↓
6. Deliver complete data
```

### Chunking

- **Default Chunk Size**: 1024 bytes (configurable)
- **Channel ID**: Application-defined logical channel (0-65535)
- **Sequence Number**: Auto-incremented per channel
- **Chunk Indexing**: 0-based sequential integers
- **Reassembly**: Chunks buffered by **(channelID, sequence)** tuple until complete

### Encryption (AES-256-GCM)

When `protoOpts & 0x02`:

```
┌────────────┬─────────────────┐
│  Nonce(12) │  Ciphertext(var)│
└────────────┴─────────────────┘
```

- **Algorithm**: AES-256-GCM (Galois/Counter Mode)
- **Key Size**: 32 bytes (256 bits)
- **Nonce Size**: 12 bytes (random per message)
- **Authentication**: Built into GCM mode
- **Timing**: Encrypt BEFORE chunking, decrypt AFTER reassembly

### Compression (zlib)

When `protoOpts & 0x01`:

- **Algorithm**: zlib (DEFLATE)
- **Level**: Default compression level
- **Timing**: Compress BEFORE encryption, decompress AFTER decryption

### Complete Example

#### Sending Multi-Channel Messages (v2.0)

```python
# Send on channel 1 (default RPC)
data_ch1 = b'{"method":"task.hello","params":{"name":"Alice"}}'

# Send on channel 100 (application data)
data_ch100 = b'{"method":"data.stream","data":"sensor readings..."}'

# 1. Compress
compressed_ch1 = zlib.compress(data_ch1)
compressed_ch100 = zlib.compress(data_ch100)

# 2. Encrypt
nonce_ch1 = os.urandom(12)
cipher_ch1 = AES.new(key, AES.MODE_GCM, nonce=nonce_ch1)
ciphertext_ch1, _ = cipher_ch1.encrypt_and_digest(compressed_ch1)
encrypted_ch1 = nonce_ch1 + ciphertext_ch1

nonce_ch100 = os.urandom(12)
cipher_ch100 = AES.new(key, AES.MODE_GCM, nonce=nonce_ch100)
ciphertext_ch100, _ = cipher_ch100.encrypt_and_digest(compressed_ch100)
encrypted_ch100 = nonce_ch100 + ciphertext_ch100

# 3. Chunk (assume single chunk for both)
chunks_ch1 = [encrypted_ch1]
chunks_ch100 = [encrypted_ch100]

# 4. Add headers
# Channel 1, sequence 0 (first message on this channel)
header_ch1 = struct.pack('>BBHIII',
    0x01,           # protoID
    0x03,           # protoOpts (compress + encrypt)
    1,              # channelID = 1
    0,              # sequence = 0 (first message)
    0,              # chunkIndex = 0
    1               # totalChunks = 1
)

# Channel 100, sequence 0 (first message on this channel)
header_ch100 = struct.pack('>BBHIII',
    0x01,           # protoID
    0x03,           # protoOpts (compress + encrypt)
    100,            # channelID = 100
    0,              # sequence = 0 (first message)
    0,              # chunkIndex = 0
    1               # totalChunks = 1
)

payload_ch1 = header_ch1 + chunks_ch1[0]
payload_ch100 = header_ch100 + chunks_ch100[0]

# 5. Send both messages
# Both messages can have sequence=0 because they're on different channels!
```

#### Receiving (v2.0)

```python
# 1. Receive packet, validate HMAC, extract payload

# 2. Parse header
protoID = payload[0]                                    # 0x01
protoOpts = payload[1]                                  # 0x03
channelID = unpack('>H', payload[2:4])[0]               # 1 or 100
sequence = unpack('>I', payload[4:8])[0]                # 0
chunkIndex = unpack('>I', payload[8:12])[0]             # 0
totalChunks = unpack('>I', payload[12:16])[0]           # 1
chunk_data = payload[16:]

# 3. Buffer chunk by (channelID, sequence) tuple  ⭐ NEW
buffer_key = (channelID, sequence)
buffers[buffer_key][chunkIndex] = chunk_data

# 4. Check complete
if len(buffers[buffer_key]) == totalChunks:
    # 5. Reassemble
    complete = chunk_data  # Only 1 chunk

    # 6. Decrypt (protoOpts & 0x02)
    nonce = complete[:12]
    ciphertext = complete[12:]
    cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
    compressed = cipher.decrypt(ciphertext)

    # 7. Decompress (protoOpts & 0x01)
    data = zlib.decompress(compressed)

    # 8. Parse JSON
    message = json.loads(data)

    # 9. Cleanup buffer
    del buffers[buffer_key]
```

### Message Reassembly

**Buffer Management (v2.0):**

- **Key**: **(channelID, sequence)** tuple ⭐ CHANGED from msgID
- **Value**: Dictionary of {chunkIndex: chunk_data}
- **Timeout**: 60 seconds (stale buffers deleted)
- **Completion**: When `len(chunks) == totalChunks`

**Benefits of (channelID, sequence) Key:**
- No collision risk between channels
- Can track gaps: missing sequence 5 on channel 1
- Can detect duplicates: already processed sequence 10 on channel 2
- Independent buffer spaces per channel

**Cleanup:**

```python
# Periodic cleanup (every N seconds)
now = time.time()
for buffer_key, buffer in buffers.items():
    if now - buffer.created_at > 60:
        del buffers[buffer_key]  # Remove stale incomplete messages
```

---

## Security

### HMAC Authentication

**Purpose**: Verify packet integrity and authenticity

**Calculation:**

```
data_to_hmac = GUID + Payload
hmac_full = HMAC-SHA256(key, data_to_hmac)
hmac_truncated = hmac_full[0:16]
```

**Verification:**

1. Extract HMAC from packet (first 16 bytes)
2. Recompute HMAC on GUID + Payload
3. Compare: `received_hmac == computed_hmac`
4. Reject if mismatch

**No changes from v1.0.**

### Encryption (AES-256-GCM)

**When**: Protocol 1 with `protoOpts & 0x02`

**Algorithm**: AES-256-GCM
- **Mode**: Galois/Counter Mode (authenticated encryption)
- **Key Size**: 256 bits (32 bytes)
- **Nonce**: 12 bytes (96 bits), random per message
- **Tag**: Embedded in GCM ciphertext (16 bytes)

**Nonce Generation:**

```python
nonce = os.urandom(12)  # Cryptographically secure random
```

**CRITICAL**: Never reuse nonce with same key!

**Nonce Derivation (Optional Enhancement in v2.0):**

For deterministic nonce generation using channelID + sequence:

```python
# Option: Derive nonce from channelID + sequence + timestamp
nonce_material = struct.pack('>HIQ', channelID, sequence, timestamp_ns)
nonce = HMAC-SHA256(key, nonce_material)[:12]
```

**No changes to core encryption from v1.0.**

### Key Management

**Shared Key:**

- **Size**: 32 bytes (256 bits)
- **Generation**: Cryptographically secure random
- **Distribution**: Out-of-band (pre-shared or key exchange)
- **Storage**: Securely stored (environment variable, keychain, etc.)

**Test Key** (Development Only):

```
D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD
```

**WARNING**: Never use test key in production!

**No changes from v1.0.**

### Rate Limiting

**Protection**: DoS/flooding attacks

**Mechanism:**

- Track request count per peer GUID
- Sliding window (e.g., last 60 seconds)
- Reject if rate exceeds threshold (e.g., 100 req/min)

**v2.0 Enhancement**: Can implement per-channel rate limiting

**No changes to core rate limiting from v1.0.**

---

## Message Flow

### Multi-Channel Communication (v2.0 Example)

```
┌──────────┐                                  ┌──────────┐
│ Client   │                                  │ Service  │
└────┬─────┘                                  └────┬─────┘
     │                                             │
     │ 1. Send RPC on channel 1 (default RPC)      │
     │    channelID=1, sequence=0                  │
     │ ─────────────────────────────────────────> │
     │                                             │
     │ 2. Send data stream on channel 100          │
     │    channelID=100, sequence=0                │
     │ ─────────────────────────────────────────> │
     │                                             │
     │                                         3. Process both
     │                                         4. Response on channel 1
     │                                         5. Data on channel 100
     │                                             │
     │ <───── Response (ch=1, seq=0) ────────────  │
     │ <───── Data (ch=100, seq=0) ───────────────  │
     │                                             │
     │ 6. Next RPC on channel 1                    │
     │    channelID=1, sequence=1                  │
     │ ─────────────────────────────────────────> │
     │                                             │
```

### Large RPC Response (Protocol 1)

```
┌──────────┐                                  ┌──────────┐
│ Client   │                                  │ Service  │
└────┬─────┘                                  └────┬─────┘
     │                                             │
     │ 1. Send RPC request (Protocol 0)            │
     │ ─────────────────────────────────────────> │
     │                                             │
     │                                         2. Process request
     │                                         3. Large response (1647 bytes)
     │                                         4. Compress (~600 bytes)
     │                                         5. Chunk into 1 chunk
     │                                         6. Add binary header
     │                                            (channelID=1, sequence=5)
     │                                             │
     │ <───────── Chunk 1/1 ─────────────────────  │
     │    [HMAC][GUID][0x01|0x01|ch=1|seq=5|0|1|compressed_data]
     │                                             │
     │ 7. Buffer chunk by (channelID=1, seq=5)     │
     │ 8. Check complete (1/1)                     │
     │ 9. Decompress                               │
     │ 10. Parse JSON                              │
     │ 11. Match request ID                        │
     │ 12. Complete future                         │
     │                                             │
```

---

## Implementation Notes

### Protocol Detection

```python
def detect_protocol(payload: bytes) -> int:
    if not payload:
        return None

    first_byte = payload[0]

    if first_byte < 32:
        return PROTOCOL_BINARY  # 0x01
    else:
        return PROTOCOL_TEXT    # 0x00
```

**No changes from v1.0.**

### Sequence Management (v2.0)

**Per-Channel Sequence Counters:**

```python
class BinaryProtocol:
    def __init__(self):
        self._sequences = {}  # {channelID: next_sequence}

    async def send(self, payload, channel_id=1, proto_opts=0x00):
        # Get next sequence for this channel
        sequence = self._sequences.get(channel_id, 0)
        self._sequences[channel_id] = (sequence + 1) % (2**32)

        # Build header with channelID + sequence
        header = struct.pack('>BBHIII',
            0x01,           # protoID
            proto_opts,     # protoOpts
            channel_id,     # channelID (2 bytes)
            sequence,       # sequence (4 bytes)
            chunk_index,    # chunkIndex
            total_chunks    # totalChunks
        )
        ...
```

### Buffer Key Management (v2.0)

**Old (v1.0):**
```python
buffer_key = msgID  # Single byte (0-255)
```

**New (v2.0):**
```python
buffer_key = (channelID, sequence)  # Tuple (channel, seq)
```

**Collision Probability:**
- **v1.0**: 50% at ~16 concurrent messages (birthday paradox)
- **v2.0**: Effectively zero (280 trillion unique IDs)

### Chunking Strategy

**When to use Protocol 1:**

- Payload > ~1400 bytes (approaching UDP MTU)
- Need compression (reduce bandwidth)
- Need encryption (confidentiality)
- Need channel isolation (multiple logical streams)

**When to use Protocol 0:**

- Small payloads (< 1400 bytes)
- Human-readable debugging
- Simple RPC calls

**No changes from v1.0.**

### UDP MTU Considerations

**Typical MTU**: 1500 bytes (Ethernet)

**YX Overhead:**

- HMAC: 16 bytes
- GUID: 6 bytes
- IP header: 20 bytes
- UDP header: 8 bytes
- **Total overhead**: 50 bytes

**Available payload**: ~1450 bytes

**Protocol 1 overhead**: 16 bytes (header)

**Effective chunk data**: ~1434 bytes

**Recommendation**: Use 1024-byte chunks for safety margin

**No changes from v1.0.**

### Broadcast vs Unicast

**Broadcast** (255.255.255.255):

- All peers on network receive
- Used for discovery, heartbeats, RPC (with SO_REUSEPORT)

**Unicast** (specific IP):

- Only target peer receives
- **WARNING**: Fails with SO_REUSEPORT (random socket delivery)
- Only use if peers on different ports

**Rule**: Always use broadcast for YX RPC communication

**No changes from v1.0.**

---

## Appendix

### Binary Protocol Header (C-style struct)

**v2.0:**

```c
struct BinaryProtocolHeader {
    uint8_t  protoID;       // 0x01 = Binary/Chunked
    uint8_t  protoOpts;     // 0x00-0x03 (compress/encrypt flags)
    uint16_t channelID;     // 0-65535 (logical channel) - BIG ENDIAN
    uint32_t sequence;      // 0-4.3B (per-channel sequence) - BIG ENDIAN
    uint32_t chunkIndex;    // 0-4.3B (chunk position) - BIG ENDIAN
    uint32_t totalChunks;   // 0-4.3B (total chunks) - BIG ENDIAN
} __attribute__((packed));
```

**Total Size**: 16 bytes (1 + 1 + 2 + 4 + 4 + 4)

### Packet Example (Hex Dump)

**Protocol 0 (Text)** - No changes:

```
# Packet: {"method":"ping"}
Offset  Hex                                          ASCII
------  -------------------------------------------  ----------------
0000    A1 B2 C3 D4 E5 F6 G7 H8 I9 J0 K1 L2 M3 N4  [HMAC............]
0010    O5 P6 11 22 33 44 55 66                     [..][GUID......]
0018    7B 22 6D 65 74 68 6F 64 22 3A 22 70 69 6E  {"method":"pin
0028    67 22 7D                                     g"}
```

**Protocol 1 (Binary v2.0):**

```
# Packet: Single chunk, compressed, channel 42, sequence 10
Offset  Hex                                          ASCII
------  -------------------------------------------  ----------------
0000    A1 B2 C3 D4 E5 F6 G7 H8 I9 J0 K1 L2 M3 N4  [HMAC............]
0010    O5 P6 11 22 33 44 55 66                     [..][GUID......]
0018    01 01                                        [protoID,opts]
001A    00 2A                                        [channelID=42]
001C    00 00 00 0A                                  [sequence=10]
0020    00 00 00 00                                  [chunkIndex=0]
0024    00 00 00 01                                  [totalChunks=1]
0028    78 9C ... [compressed data]                  [zlib data...]
```

### Comparison: v1.0 vs v2.0

| Feature                | v1.0                      | v2.0                                |
|------------------------|---------------------------|-------------------------------------|
| Protocol 0 (Text)      | Unchanged                 | Unchanged                           |
| Protocol 1 Header Size | 16 bytes                  | 16 bytes                            |
| Message ID Field       | msgID (1 byte)            | channelID (2 bytes) + sequence (4 bytes) |
| Unique Message IDs     | 256                       | 280 trillion                        |
| Collision Risk         | ~50% at 16 messages       | Effectively zero                    |
| Buffer Key             | msgID                     | (channelID, sequence) tuple         |
| Channel Isolation      | No                        | Yes (65K channels)                  |
| Gap Detection          | No                        | Yes (linear sequences)              |
| Backward Compatible    | N/A                       | Protocol 0: Yes, Protocol 1: No     |

---

**End of Specification**

**Version:** 2.0.0
**Last Updated:** 2025-10-19
**Maintained by:** YX Development Team
**See Also:**
- `YX-PROTOCOL-SPEC.md` - v1.0 specification
- `MIGRATION-v1-to-v2.md` - Migration guide
- `YX-PROTOCOL-V2-WIP.md` - Development notes
