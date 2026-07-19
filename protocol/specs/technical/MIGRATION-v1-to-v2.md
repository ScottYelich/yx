# YX Protocol Migration Guide: v1.0 → v2.0

**Document Version:** 1.0
**Date:** 2025-10-19
**Target Audience:** Developers upgrading YX Framework implementations

---

## Table of Contents

1. [Overview](#overview)
2. [Breaking Changes](#breaking-changes)
3. [What Stays the Same](#what-stays-the-same)
4. [Migration Strategy](#migration-strategy)
5. [Code Changes Required](#code-changes-required)
6. [Testing Strategy](#testing-strategy)
7. [Rollback Plan](#rollback-plan)
8. [FAQ](#faq)

---

## Overview

YX Protocol v2.0 introduces a **channel-based architecture** for Protocol 1 (Binary) to eliminate message ID collision risks and enable logical stream isolation. This is a **breaking change** for binary protocol users.

### Who Needs to Migrate?

✅ **You MUST migrate if:**
- You use Protocol 1 (Binary) for large messages, compression, or encryption
- You have peers communicating over YX binary protocol
- You want to use the new channel isolation features

✅ **You DON'T need to migrate if:**
- You only use Protocol 0 (Text/JSON-RPC) - **fully compatible**
- You're starting a new project - use v2.0 from the start

### Migration Timeline

**Recommended Approach:** Flag day upgrade (all peers simultaneously)

**Why:** v1.0 and v2.0 binary protocols are **incompatible**. Mixed deployments will fail to communicate over Protocol 1.

---

## Breaking Changes

### 1. Protocol 1 Header Format

**v1.0 Header (16 bytes):**
```
Offset  Field         Size    Type      Description
------  ------------  ------  --------  ---------------------------
0       protoID       1       uint8     0x01 (binary)
1       protoOpts     1       uint8     Compress/encrypt flags
2       msgID         1       uint8     Message ID (0-255)
3       meta          1       uint8     Metadata (reserved)
4-7     chunkIndex    4       uint32be  Chunk index
8-11    totalChunks   4       uint32be  Total chunks
12-15   reserved      4       uint32be  Reserved (0)
```

**v2.0 Header (16 bytes):**
```
Offset  Field         Size    Type      Description
------  ------------  ------  --------  ---------------------------
0       protoID       1       uint8     0x01 (binary)
1       protoOpts     1       uint8     Compress/encrypt flags
2-3     channelID     2       uint16be  Logical channel (0-65535)
4-7     sequence      4       uint32be  Per-channel sequence (0-4.3B)
8-11    chunkIndex    4       uint32be  Chunk index
12-15   totalChunks   4       uint32be  Total chunks
```

**Key Differences:**
- `msgID` (1 byte) → `channelID` (2 bytes)
- `meta` (1 byte) → part of `sequence` (4 bytes)
- `reserved` (4 bytes) → removed (absorbed by `channelID` + `sequence`)

### 2. Buffer Key Change

**v1.0:**
```python
buffer_key = msgID  # 0-255
buffers[msgID] = {chunkIndex: chunk_data}
```

**v2.0:**
```python
buffer_key = (channelID, sequence)  # (0-65535, 0-4.3B)
buffers[(channelID, sequence)] = {chunkIndex: chunk_data}
```

### 3. Sequence Management

**v1.0:**
- Random msgID per message (0-255)
- No tracking required
- High collision risk (~50% at 16 concurrent messages)

**v2.0:**
- Per-channel sequence counters
- Linear increment: 0, 1, 2, 3, ...
- Must track `_sequences = {channelID: next_seq}`

---

## What Stays the Same

### ✅ No Changes To:

1. **Protocol 0 (Text/JSON-RPC)**: Fully compatible
2. **Packet structure**: HMAC (16) + GUID (6) + Payload
3. **HMAC computation**: Still HMAC-SHA256(GUID + Payload)[:16]
4. **Encryption**: Still AES-256-GCM with 12-byte nonce
5. **Compression**: Still zlib
6. **Processing order**: Compress → Encrypt → Chunk (send)
7. **Processing order**: Reassemble → Decrypt → Decompress (receive)
8. **protoOpts bitfield**: Same values (0x00-0x03)
9. **Chunk size**: Still 1024 bytes default
10. **Buffer timeout**: Still 60 seconds

### ✅ Compatible Features:

- Protocol 0 peers can still communicate (no binary protocol used)
- Shared keys remain the same format (32 bytes / 64 hex chars)
- GUID format unchanged (6 bytes)
- UDP broadcast behavior unchanged

---

## Migration Strategy

### Option A: Flag Day Upgrade (Recommended)

**Best For:** Controlled environments, small deployments

**Steps:**

1. **Preparation Phase (Week 1-2)**
   - Update all codebases to v2.0
   - Run integration tests in isolated environment
   - Document rollback procedure

2. **Deployment Phase (Day 1)**
   - Schedule maintenance window (all peers offline)
   - Deploy v2.0 to ALL peers simultaneously
   - Start all peers
   - Verify connectivity

3. **Verification Phase (Day 1-2)**
   - Monitor logs for errors
   - Test Protocol 1 communication
   - Run end-to-end tests

**Downtime:** Required during deployment window

**Risk:** Low (if tested thoroughly)

### Option B: Protocol Version Negotiation (Future)

**Status:** Not implemented in v2.0

**Concept:**
- Peers advertise supported protocol versions
- Fall back to v1.0 if v2.0 not supported
- Allows gradual rollout

**Availability:** Planned for v2.1+

---

## Code Changes Required

### Python Implementation

#### 1. Update Header Encoding

**Before (v1.0):**
```python
def _encode_header(self, msg_id, chunk_index, total_chunks, proto_opts):
    return struct.pack('>BBBBIII',
        0x01,           # protoID
        proto_opts,     # protoOpts
        msg_id,         # msgID (1 byte)
        0,              # meta (reserved)
        chunk_index,    # chunkIndex
        total_chunks,   # totalChunks
        0               # reserved
    )
```

**After (v2.0):**
```python
def _encode_header(self, channel_id, sequence, chunk_index, total_chunks, proto_opts):
    return struct.pack('>BBHIII',
        0x01,           # protoID
        proto_opts,     # protoOpts
        channel_id,     # channelID (2 bytes, big-endian)
        sequence,       # sequence (4 bytes, big-endian)
        chunk_index,    # chunkIndex
        total_chunks    # totalChunks
        # No reserved field
    )
```

#### 2. Update Header Decoding

**Before (v1.0):**
```python
def _decode_header(self, header):
    proto_id, proto_opts, msg_id, meta, chunk_idx, total_chunks, reserved = \
        struct.unpack('>BBBBIII', header)
    return {
        'proto_id': proto_id,
        'proto_opts': proto_opts,
        'msg_id': msg_id,
        'chunk_index': chunk_idx,
        'total_chunks': total_chunks
    }
```

**After (v2.0):**
```python
def _decode_header(self, header):
    proto_id, proto_opts, channel_id, sequence, chunk_idx, total_chunks = \
        struct.unpack('>BBHIII', header)
    return {
        'proto_id': proto_id,
        'proto_opts': proto_opts,
        'channel_id': channel_id,      # NEW
        'sequence': sequence,            # NEW
        'chunk_index': chunk_idx,
        'total_chunks': total_chunks
    }
```

#### 3. Add Sequence Tracking

**New in v2.0:**
```python
class BinaryProtocol:
    def __init__(self, key, chunk_size=1024):
        self.key = key
        self.chunk_size = chunk_size
        self._buffers = {}
        self._sequences = {}  # NEW: {channelID: next_sequence}

    def _get_next_sequence(self, channel_id):
        """Get next sequence number for channel"""
        seq = self._sequences.get(channel_id, 0)
        self._sequences[channel_id] = (seq + 1) % (2**32)
        return seq
```

#### 4. Update Buffer Key

**Before (v1.0):**
```python
async def handle(self, payload):
    header = self._decode_header(payload[:16])
    msg_id = header['msg_id']

    # Buffer by msgID
    if msg_id not in self._buffers:
        self._buffers[msg_id] = {}

    self._buffers[msg_id][header['chunk_index']] = chunk_data

    if len(self._buffers[msg_id]) == header['total_chunks']:
        # Reassemble
        complete = b''.join(self._buffers[msg_id][i] for i in range(total_chunks))
        del self._buffers[msg_id]
```

**After (v2.0):**
```python
async def handle(self, payload):
    header = self._decode_header(payload[:16])
    channel_id = header['channel_id']
    sequence = header['sequence']

    # Buffer by (channelID, sequence) tuple
    buffer_key = (channel_id, sequence)
    if buffer_key not in self._buffers:
        self._buffers[buffer_key] = {}

    self._buffers[buffer_key][header['chunk_index']] = chunk_data

    if len(self._buffers[buffer_key]) == header['total_chunks']:
        # Reassemble
        complete = b''.join(self._buffers[buffer_key][i] for i in range(total_chunks))
        del self._buffers[buffer_key]
```

#### 5. Update Send API

**Before (v1.0):**
```python
async def send(self, payload, proto_opts=0x00):
    msg_id = random.randint(0, 255)  # Random msgID
    # ... chunking logic ...
    header = self._encode_header(msg_id, chunk_idx, total_chunks, proto_opts)
```

**After (v2.0):**
```python
async def send(self, payload, proto_opts=0x00, channel_id=1):
    sequence = self._get_next_sequence(channel_id)  # Linear sequence
    # ... chunking logic ...
    header = self._encode_header(channel_id, sequence, chunk_idx, total_chunks, proto_opts)
```

### Swift Implementation

#### 1. Update Header Struct

**Before (v1.0):**
```swift
struct BinaryProtocolHeader {
    let protoID: UInt8       // 0x01
    let protoOpts: UInt8     // 0x00-0x03
    let msgID: UInt8         // 0-255
    let meta: UInt8          // reserved
    let chunkIndex: UInt32   // big-endian
    let totalChunks: UInt32  // big-endian
    let reserved: UInt32     // big-endian
}
```

**After (v2.0):**
```swift
struct BinaryProtocolHeader {
    let protoID: UInt8       // 0x01
    let protoOpts: UInt8     // 0x00-0x03
    let channelID: UInt16    // 0-65535, big-endian
    let sequence: UInt32     // 0-4.3B, big-endian
    let chunkIndex: UInt32   // big-endian
    let totalChunks: UInt32  // big-endian
}
```

#### 2. Update Encoding

**Before (v1.0):**
```swift
func encodeHeader(msgID: UInt8, chunkIndex: UInt32, totalChunks: UInt32, protoOpts: UInt8) -> Data {
    var header = Data()
    header.append(0x01)                           // protoID
    header.append(protoOpts)                      // protoOpts
    header.append(msgID)                          // msgID
    header.append(0)                              // meta
    header.append(contentsOf: chunkIndex.bigEndianBytes)
    header.append(contentsOf: totalChunks.bigEndianBytes)
    header.append(contentsOf: UInt32(0).bigEndianBytes)  // reserved
    return header
}
```

**After (v2.0):**
```swift
func encodeHeader(channelID: UInt16, sequence: UInt32, chunkIndex: UInt32, totalChunks: UInt32, protoOpts: UInt8) -> Data {
    var header = Data()
    header.append(0x01)                           // protoID
    header.append(protoOpts)                      // protoOpts
    header.append(contentsOf: channelID.bigEndianBytes)   // channelID (2 bytes)
    header.append(contentsOf: sequence.bigEndianBytes)    // sequence (4 bytes)
    header.append(contentsOf: chunkIndex.bigEndianBytes)
    header.append(contentsOf: totalChunks.bigEndianBytes)
    return header  // No reserved field
}
```

#### 3. Add Sequence Tracking

**New in v2.0:**
```swift
actor BinaryProtocol {
    private var sequences: [UInt16: UInt32] = [:]  // [channelID: nextSequence]

    private func getNextSequence(for channelID: UInt16) -> UInt32 {
        let seq = sequences[channelID] ?? 0
        sequences[channelID] = (seq + 1) % UInt32.max
        return seq
    }
}
```

#### 4. Update Buffer Key

**Before (v1.0):**
```swift
private var buffers: [UInt8: [UInt32: Data]] = [:]  // [msgID: [chunkIndex: data]]
```

**After (v2.0):**
```swift
// Use tuple as buffer key
private typealias BufferKey = String  // "\(channelID)-\(sequence)"
private var buffers: [BufferKey: [UInt32: Data]] = [:]

private func makeBufferKey(channelID: UInt16, sequence: UInt32) -> BufferKey {
    return "\(channelID)-\(sequence)"
}
```

---

## Testing Strategy

### 1. Unit Tests

**Test Coverage Required:**

```python
# Python Tests
~/.pyenv/versions/yx-dev/bin/python3 -m pytest tests/test_binary_protocol_v2.py -v
~/.pyenv/versions/yx-dev/bin/python3 -m pytest tests/test_interop_v2.py -v
```

```bash
# Swift Tests
swift test --filter BinaryProtocolV2Tests
```

**Verify:**
- ✅ Header encoding/decoding (16 bytes)
- ✅ Big-endian byte order for channelID, sequence
- ✅ Sequence increment per channel
- ✅ Channel isolation (independent sequences)
- ✅ Multi-chunk reassembly with (channelID, sequence) key
- ✅ Compression + encryption still work

### 2. Integration Tests

**Cross-Language Communication:**

```bash
# Terminal 1: Start Python peer
cd src/python
python -m yxCLI --port 9999

# Terminal 2: Start Swift peer, send to Python
cd src/swift/yx/yx
.build/debug/yxCLI --port 9998 --peers "localhost:9999"
```

**Verify:**
- ✅ Python → Swift binary messages
- ✅ Swift → Python binary messages
- ✅ Large messages (>1024 bytes) chunk correctly
- ✅ Compression works cross-language
- ✅ Encryption works cross-language

### 3. Load Testing

**Test Scenarios:**

```python
# Test 1: High message rate on single channel
for i in range(1000):
    await protocol.send(data, channel_id=1)

# Verify: Sequences 0-999 in order, no gaps

# Test 2: Multiple channels simultaneously
await asyncio.gather(
    send_stream(channel_id=1, count=100),
    send_stream(channel_id=2, count=100),
    send_stream(channel_id=3, count=100)
)

# Verify: Each channel has sequences 0-99, no cross-contamination
```

### 4. Compatibility Testing

**Negative Tests:**

```python
# Test: v1.0 peer cannot parse v2.0 packet
v2_packet = build_v2_packet(channel_id=42, sequence=10)
v1_parser = V1BinaryProtocol()
try:
    v1_parser.parse(v2_packet)
    assert False, "Should have failed"
except Exception:
    pass  # Expected: v1.0 cannot parse v2.0

# Test: v2.0 peer cannot parse v1.0 packet
v1_packet = build_v1_packet(msg_id=42)
v2_parser = V2BinaryProtocol()
try:
    v2_parser.parse(v1_packet)
    assert False, "Should have failed"
except Exception:
    pass  # Expected: v2.0 cannot parse v1.0
```

---

## Rollback Plan

### Preparation

**Before Deployment:**

1. ✅ Tag v1.0 codebase in git: `git tag v1.0-stable`
2. ✅ Backup configuration files
3. ✅ Document current deployment state
4. ✅ Test rollback procedure in staging

### Rollback Steps

**If v2.0 deployment fails:**

```bash
# 1. Stop all v2.0 peers
./bin/yxctl stop all

# 2. Revert to v1.0 codebase
git checkout v1.0-stable

# 3. Rebuild
cd src/python && pip install -e .
cd src/swift/yx/yx && swift build

# 4. Restart peers
./bin/yxctl start all

# 5. Verify connectivity
./bin/yxctl ping all
```

**Rollback Window:** < 15 minutes (if tested)

### Partial Rollback Not Supported

⚠️ **WARNING**: Cannot run mixed v1.0/v2.0 deployment for Protocol 1 communication.

**Why:** Header formats are incompatible. Peers will fail to parse packets.

**Mitigation:** Use Protocol 0 (Text/JSON-RPC) for critical communication paths during migration window.

---

## FAQ

### Q: Can I run v1.0 and v2.0 peers simultaneously?

**A:** ❌ No, not for Protocol 1 (Binary) communication. Protocol 0 (Text/JSON-RPC) will continue working, but binary protocol messages will fail to parse.

### Q: What if I only use Protocol 0 (Text)?

**A:** ✅ No migration needed. Protocol 0 is fully compatible between v1.0 and v2.0.

### Q: Can I migrate gradually (one peer at a time)?

**A:** ❌ No. All peers using Protocol 1 must upgrade simultaneously (flag day).

### Q: How do I choose which channel to use?

**A:** See channel allocation guidelines in `YX-PROTOCOL-SPEC-v2.md`. Use channel 1 for default RPC, 100+ for application data.

### Q: What happens to in-flight messages during upgrade?

**A:** They will be lost. Drain message queues before shutdown, or design for message loss (idempotent operations).

### Q: Can I preserve old msgID behavior?

**A:** ⚠️ Not recommended. You could map msgID to channel 0, but you lose the benefits of v2.0. Better to fully migrate.

### Q: Do shared keys need to change?

**A:** ❌ No. Shared keys remain 32 bytes, same format as v1.0.

### Q: How do I test without disrupting production?

**A:** Use isolated test environment with separate ports (e.g., 19999 instead of 9999) and different shared keys.

### Q: What's the rollback procedure if v2.0 fails?

**A:** See [Rollback Plan](#rollback-plan). Requires reverting all peers to v1.0 simultaneously.

### Q: Is there a protocol version negotiation feature?

**A:** ❌ Not in v2.0. Planned for v2.1+. For now, use flag day upgrade only.

### Q: Can I use the test key for migration?

**A:** ⚠️ Only in development/test environments. NEVER use test key in production.

### Q: Why do my Swift tests crash with Signal 5 when using Data slices?

**A:** ⚠️ Swift 6 strict concurrency has a known issue with `Data.SubSequence` subscripting in tests. **Solution:** Convert to Array before subscripting:

```swift
// ❌ Problematic:
let bytes = packet[2..<4]
XCTAssertEqual(bytes[0], 0x12)  // Crashes in test suites!

// ✅ Solution:
let bytes = packet[2..<4]
XCTAssertEqual(Array(bytes)[0], 0x12)  // Works!
```

This only affects test code. Production code should use `withUnsafeBytes` for byte access or `Data.prefix()`/`Data.suffix()` methods instead of slicing.

---

## Migration Checklist

Use this checklist for your deployment:

### Pre-Migration

- [ ] Read this guide completely
- [ ] Review `YX-PROTOCOL-SPEC-v2.md`
- [ ] Update all codebases to v2.0
- [ ] Run unit tests (Python + Swift)
- [ ] Run integration tests (Python ↔ Swift)
- [ ] Test rollback procedure in staging
- [ ] Schedule maintenance window
- [ ] Notify stakeholders of downtime

### Migration Day

- [ ] Stop all v1.0 peers
- [ ] Verify all peers stopped
- [ ] Deploy v2.0 codebase to all peers
- [ ] Rebuild/reinstall v2.0
- [ ] Start all v2.0 peers
- [ ] Verify connectivity with `yxctl ping all`
- [ ] Test Protocol 1 binary communication
- [ ] Monitor logs for errors

### Post-Migration

- [ ] Run end-to-end tests
- [ ] Monitor performance metrics
- [ ] Check buffer cleanup (no memory leaks)
- [ ] Verify channel isolation working
- [ ] Document lessons learned
- [ ] Update runbooks

### If Rollback Needed

- [ ] Stop all v2.0 peers
- [ ] Revert to v1.0 codebase (`git checkout v1.0-stable`)
- [ ] Rebuild v1.0
- [ ] Start all v1.0 peers
- [ ] Verify connectivity
- [ ] Root cause analysis
- [ ] Fix issues before retry

---

## Support

**Documentation:**
- `YX-PROTOCOL-SPEC-v2.md` - Complete v2.0 specification
- `YX-PROTOCOL-SPEC.md` - v1.0 specification (reference)
- `CLAUDE.md` - Implementation guide
- `YX-PROTOCOL-V2-WIP.md` - Development notes

**Testing:**
- `src/python/tests/test_binary_protocol_v2.py` - Python unit tests
- `src/python/tests/test_interop_v2.py` - Python integration tests
- `src/swift/yx/yx/Tests/TransportTests/BinaryProtocolV2Tests.swift` - Swift tests

**Issues:**
- Report issues to your team's issue tracker
- Include logs, packet dumps, and reproduction steps

---

**End of Migration Guide**

**Version:** 1.0
**Last Updated:** 2025-10-19
**Maintained by:** YX Development Team
