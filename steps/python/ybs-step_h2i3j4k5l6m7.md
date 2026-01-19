# YBS Step 12: Protocol 1 (Binary/Chunked) Implementation

**Step ID:** `ybs-step_h2i3j4k5l6m7`
**Language:** Python
**Estimated Duration:** 4-6 hours
**Prerequisites:** Step 11 complete (Protocol 0)

---

## Overview

Implement Protocol 1 (Binary/Chunked v2.0) with support for compression, encryption, chunking, and channel multiplexing. This is the most complex protocol layer, enabling high-throughput binary data with optional security features.

**Traceability:**
- `specs/architecture/protocol-layers.md` - Protocol 1 specification
- `specs/technical/yx-protocol-spec.md` - Wire format and processing pipelines
- `specs/architecture/security-architecture.md` - Encryption details

---

## Context

**What You Have (Step 11):**
- Protocol 0 (Text/JSON-RPC) working
- Protocol router framework
- Transport layer

**What You're Adding:**
- Protocol 1 handler with 16-byte header
- Compression (ZLIB)
- Encryption (AES-256-GCM)
- Chunking and reassembly
- Channel multiplexing (channelID, sequence)
- Deduplication
- Stale buffer cleanup

**Complexity:** This is the largest step. Take breaks, test incrementally.

---

## Goals

1. ✅ Data compression utility (ZLIB)
2. ✅ Data encryption utility (AES-256-GCM)
3. ✅ Data chunking utility
4. ✅ Protocol 1 header parsing
5. ✅ Binary protocol handler with reassembly
6. ✅ Channel multiplexing with (channelID, sequence) buffer key
7. ✅ Stale buffer cleanup
8. ✅ Message deduplication
9. ✅ Unit tests for all components
10. ✅ Traceability ≥80%

---

## File Structure

```
canonical/python/src/yx/
├── primitives/
│   ├── data_compression.py    # NEW: ZLIB compression
│   ├── data_crypto.py          # EXTEND: Add AES-256-GCM
│   └── data_chunking.py        # NEW: Chunking logic
└── transport/
    └── binary_protocol.py      # NEW: Protocol 1 handler
```

---

## Implementation

### Part 1: Data Compression

**File:** `canonical/python/src/yx/primitives/data_compression.py`

```python
"""
Data compression utilities using ZLIB.

Traceability:
- specs/architecture/security-architecture.md (Compression)
- specs/technical/yx-protocol-spec.md (ZLIB Compression)
"""

import zlib


def compress_data(data: bytes, level: int = 6) -> bytes:
    """
    Compress data using ZLIB (raw DEFLATE).

    Args:
        data: Data to compress
        level: Compression level 0-9 (6=default, balanced)

    Returns:
        Compressed data

    Traceability:
    - specs/architecture/security-architecture.md (Compression Wire Format)
    - specs/technical/default-values.md (compression_level = 6)

    Note: Uses wbits=-15 for raw DEFLATE (Apple compatibility)
    """
    compressor = zlib.compressobj(level=level, wbits=-15)
    compressed = compressor.compress(data) + compressor.flush()
    return compressed


def decompress_data(compressed: bytes) -> bytes:
    """
    Decompress ZLIB data.

    Args:
        compressed: Compressed data

    Returns:
        Decompressed data

    Traceability:
    - specs/architecture/security-architecture.md (Compression)
    """
    try:
        # Try raw DEFLATE first
        return zlib.decompress(compressed, wbits=-15)
    except zlib.error:
        # Fallback to standard zlib (with header)
        return zlib.decompress(compressed)
```

**Tests:** `canonical/python/src/yx/primitives/test_data_compression.py`

```python
"""Tests for data compression."""

import pytest
from yx.primitives.data_compression import compress_data, decompress_data


def test_compress_decompress_roundtrip():
    """Test compression/decompression roundtrip."""
    original = b"Hello, World!" * 100
    compressed = compress_data(original)
    decompressed = decompress_data(compressed)

    assert decompressed == original
    assert len(compressed) < len(original)  # Should be smaller


def test_compress_incompressible_data():
    """Test compression on random data."""
    import os
    random_data = os.urandom(1000)

    compressed = compress_data(random_data)
    decompressed = decompress_data(compressed)

    assert decompressed == random_data


def test_compress_empty_data():
    """Test compression on empty data."""
    compressed = compress_data(b"")
    decompressed = decompress_data(compressed)

    assert decompressed == b""
```

---

### Part 2: AES-256-GCM Encryption

**File:** `canonical/python/src/yx/primitives/data_crypto.py` (EXTEND existing file)

Add these functions to the existing file:

```python
"""
Data cryptography utilities.

Traceability:
- specs/architecture/security-architecture.md (Encryption)
"""

import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from typing import Tuple


def encrypt_aes_gcm(plaintext: bytes, key: bytes) -> Tuple[bytes, bytes]:
    """
    Encrypt data using AES-256-GCM.

    Args:
        plaintext: Data to encrypt
        key: 32-byte symmetric key

    Returns:
        (nonce, ciphertext_with_tag)
            - nonce: 12 bytes (random)
            - ciphertext_with_tag: encrypted data + 16-byte auth tag

    Traceability:
    - specs/architecture/security-architecture.md (Encryption Wire Format)
    - specs/technical/yx-protocol-spec.md (AES-256-GCM Encryption)

    Wire format: [nonce(12)] + [ciphertext] + [tag(16)]
    """
    if len(key) != 32:
        raise ValueError("Key must be 32 bytes")

    aesgcm = AESGCM(key)
    nonce = os.urandom(12)  # 96-bit random nonce
    ciphertext_with_tag = aesgcm.encrypt(nonce, plaintext, None)

    return nonce, ciphertext_with_tag


def decrypt_aes_gcm(nonce: bytes, ciphertext_with_tag: bytes, key: bytes) -> bytes:
    """
    Decrypt AES-256-GCM encrypted data.

    Args:
        nonce: 12-byte nonce
        ciphertext_with_tag: Encrypted data + 16-byte tag
        key: 32-byte symmetric key

    Returns:
        Decrypted plaintext

    Raises:
        cryptography.exceptions.InvalidTag: If authentication fails

    Traceability:
    - specs/architecture/security-architecture.md (Decryption)
    """
    if len(key) != 32:
        raise ValueError("Key must be 32 bytes")
    if len(nonce) != 12:
        raise ValueError("Nonce must be 12 bytes")

    aesgcm = AESGCM(key)
    plaintext = aesgcm.decrypt(nonce, ciphertext_with_tag, None)

    return plaintext
```

**Tests:** Add to `canonical/python/src/yx/primitives/test_data_crypto.py`

```python
def test_aes_gcm_encrypt_decrypt_roundtrip():
    """Test AES-256-GCM encryption/decryption roundtrip."""
    key = os.urandom(32)
    plaintext = b"Secret message!"

    nonce, ciphertext_with_tag = encrypt_aes_gcm(plaintext, key)
    decrypted = decrypt_aes_gcm(nonce, ciphertext_with_tag, key)

    assert decrypted == plaintext
    assert len(nonce) == 12
    assert len(ciphertext_with_tag) == len(plaintext) + 16  # +16 for tag


def test_aes_gcm_different_nonces():
    """Test that same plaintext produces different ciphertexts."""
    key = os.urandom(32)
    plaintext = b"Secret message!"

    nonce1, ciphertext1 = encrypt_aes_gcm(plaintext, key)
    nonce2, ciphertext2 = encrypt_aes_gcm(plaintext, key)

    assert nonce1 != nonce2
    assert ciphertext1 != ciphertext2


def test_aes_gcm_invalid_key_size():
    """Test that invalid key size raises error."""
    with pytest.raises(ValueError):
        encrypt_aes_gcm(b"data", b"short_key")
```

---

### Part 3: Data Chunking

**File:** `canonical/python/src/yx/primitives/data_chunking.py`

```python
"""
Data chunking utilities.

Traceability:
- specs/architecture/protocol-layers.md (Chunking)
- specs/technical/yx-protocol-spec.md (Chunking Algorithm)
"""

from typing import List


def chunk_data(data: bytes, chunk_size: int = 1024) -> List[bytes]:
    """
    Split data into fixed-size chunks.

    Args:
        data: Data to chunk
        chunk_size: Size of each chunk in bytes (default: 1024)

    Returns:
        List of chunks

    Traceability:
    - specs/technical/default-values.md (chunk_size = 1024)
    """
    if chunk_size <= 0:
        raise ValueError("Chunk size must be positive")

    chunks = []
    for i in range(0, len(data), chunk_size):
        chunk = data[i:i + chunk_size]
        chunks.append(chunk)

    return chunks if chunks else [b""]  # At least one chunk (empty)


def unchunk_data(chunks: List[bytes]) -> bytes:
    """
    Reassemble chunks into original data.

    Args:
        chunks: List of chunks (dict keys are indices)

    Returns:
        Reassembled data

    Traceability:
    - specs/architecture/protocol-layers.md (Reassembly Algorithm)
    """
    return b"".join(chunks)
```

**Tests:** `canonical/python/src/yx/primitives/test_data_chunking.py`

```python
"""Tests for data chunking."""

import pytest
from yx.primitives.data_chunking import chunk_data, unchunk_data


def test_chunk_unchunk_roundtrip():
    """Test chunking/unchunking roundtrip."""
    original = b"A" * 5000
    chunks = chunk_data(original, chunk_size=1024)
    reassembled = unchunk_data(chunks)

    assert reassembled == original
    assert len(chunks) == 5  # 5000 bytes / 1024 = 5 chunks


def test_chunk_small_data():
    """Test chunking data smaller than chunk size."""
    data = b"Small"
    chunks = chunk_data(data, chunk_size=1024)

    assert len(chunks) == 1
    assert chunks[0] == data


def test_chunk_empty_data():
    """Test chunking empty data."""
    chunks = chunk_data(b"", chunk_size=1024)

    assert len(chunks) == 1
    assert chunks[0] == b""


def test_chunk_exact_multiple():
    """Test chunking data that's exact multiple of chunk size."""
    data = b"X" * 2048
    chunks = chunk_data(data, chunk_size=1024)

    assert len(chunks) == 2
    assert len(chunks[0]) == 1024
    assert len(chunks[1]) == 1024
```

---

### Part 4: Protocol 1 Binary Handler

**File:** `canonical/python/src/yx/transport/binary_protocol.py`

```python
"""
Protocol 1: Binary/Chunked handler (v2.0).

Traceability:
- specs/architecture/protocol-layers.md (Protocol 1)
- specs/technical/yx-protocol-spec.md (Binary Protocol v2.0)
"""

import struct
import time
import logging
from typing import Dict, Tuple, Optional, Callable, Awaitable, List
from dataclasses import dataclass, field

from ..primitives.data_compression import compress_data, decompress_data
from ..primitives.data_crypto import encrypt_aes_gcm, decrypt_aes_gcm
from ..primitives.data_chunking import chunk_data, unchunk_data
from .protocol_router import ProtocolID

logger = logging.getLogger(__name__)


@dataclass
class BufferEntry:
    """
    Buffer entry for incomplete message reassembly.

    Traceability:
    - specs/architecture/protocol-layers.md (Buffer Management)
    """
    chunks: Dict[int, bytes] = field(default_factory=dict)
    total_chunks: Optional[int] = None
    created_at: float = field(default_factory=time.time)
    channel_id: int = 0
    sequence: int = 0


class BinaryProtocol:
    """
    Protocol 1 handler for binary/chunked messages (v2.0).

    Traceability:
    - specs/architecture/protocol-layers.md (Protocol 1)
    - specs/technical/yx-protocol-spec.md (Binary Protocol v2.0)
    """

    # Header format: proto(1) + protoOpts(1) + channelID(2) + sequence(4) + chunkIndex(4) + totalChunks(4)
    HEADER_FORMAT = ">BBHIII"  # Big-endian
    HEADER_SIZE = 16

    def __init__(
        self,
        key: bytes,
        on_message: Optional[Callable[[bytes], Awaitable[None]]] = None,
        chunk_size: int = 1024,
        buffer_timeout: float = 60.0
    ):
        """
        Initialize binary protocol handler.

        Args:
            key: 32-byte symmetric key for encryption
            on_message: Callback for complete messages
            chunk_size: Chunk size in bytes (default: 1024)
            buffer_timeout: Timeout for incomplete buffers in seconds

        Traceability:
        - specs/technical/default-values.md (chunk_size=1024, buffer_timeout=60.0)
        """
        self._key = key
        self._on_message = on_message
        self._chunk_size = chunk_size
        self._buffer_timeout = buffer_timeout
        self._send_api = None

        # Buffer key: (channelID, sequence) -> BufferEntry
        self._incomplete_messages: Dict[Tuple[int, int], BufferEntry] = {}

        # Deduplication: Track processed (channelID, sequence) tuples
        self._processed_messages: Dict[Tuple[int, int], float] = {}
        self._dedup_window = 5.0  # 5 seconds

        # Per-channel sequence counters
        self._sequence_counters: Dict[int, int] = {}

    def install_send_api(self, send_fn: Callable[[bytes, str, int], Awaitable[None]]):
        """Install send function from transport layer."""
        self._send_api = send_fn

    async def handle(self, payload: bytes):
        """
        Process received Protocol 1 payload.

        Traceability:
        - specs/architecture/protocol-layers.md (Protocol 1 Receive Path)
        """
        # Verify protocol ID
        if not payload or payload[0] != ProtocolID.BINARY:
            logger.error(f"Invalid protocol ID for binary protocol")
            return

        # Parse header
        if len(payload) < self.HEADER_SIZE:
            logger.error(f"Payload too small for Protocol 1 header: {len(payload)} bytes")
            return

        try:
            proto, proto_opts, channel_id, sequence, chunk_index, total_chunks = struct.unpack(
                self.HEADER_FORMAT,
                payload[:self.HEADER_SIZE]
            )
        except struct.error as e:
            logger.error(f"Failed to parse Protocol 1 header: {e}")
            return

        # Extract chunk data
        chunk_data_bytes = payload[self.HEADER_SIZE:]

        logger.debug(
            f"Received chunk: channel={channel_id}, seq={sequence}, "
            f"chunk={chunk_index}/{total_chunks}, size={len(chunk_data_bytes)}"
        )

        # Check deduplication
        msg_key = (channel_id, sequence)
        if self._is_duplicate(msg_key):
            logger.debug(f"Duplicate message: {msg_key}")
            return

        # Buffer chunk
        buffer_key = (channel_id, sequence)
        if buffer_key not in self._incomplete_messages:
            self._incomplete_messages[buffer_key] = BufferEntry(
                channel_id=channel_id,
                sequence=sequence
            )

        buffer_entry = self._incomplete_messages[buffer_key]
        buffer_entry.chunks[chunk_index] = chunk_data_bytes
        buffer_entry.total_chunks = total_chunks

        # Check if all chunks received
        if len(buffer_entry.chunks) == total_chunks:
            logger.debug(f"All chunks received for {msg_key}")

            # Remove from buffer immediately
            del self._incomplete_messages[buffer_key]

            # Mark as processed (deduplication)
            self._processed_messages[msg_key] = time.time()

            # Reassemble
            reassembled = self._reassemble_chunks(buffer_entry.chunks, total_chunks)

            # Decrypt if needed
            if proto_opts & 0x02:
                reassembled = self._decrypt(reassembled)

            # Decompress if needed
            if proto_opts & 0x01:
                reassembled = self._decompress(reassembled)

            # Deliver to application
            if self._on_message:
                try:
                    await self._on_message(reassembled)
                except Exception as e:
                    logger.exception(f"Error in message handler: {e}")

        # Cleanup stale buffers periodically
        if len(self._incomplete_messages) > 10:
            self._cleanup_stale_buffers()

    async def send(
        self,
        data: bytes,
        host: str,
        port: int,
        proto_opts: int = 0x00,
        channel_id: int = 0
    ):
        """
        Send Protocol 1 message.

        Args:
            data: Application data
            host: Destination IP
            port: Destination port
            proto_opts: Protocol options (0x00, 0x01, 0x02, 0x03)
            channel_id: Channel ID (0-65535)

        Traceability:
        - specs/architecture/protocol-layers.md (Protocol 1 Send Path)
        """
        if self._send_api is None:
            raise RuntimeError("Send API not installed")

        # Get next sequence number for this channel
        sequence = self._get_next_sequence(channel_id)

        # Compress if needed
        if proto_opts & 0x01:
            data = compress_data(data)

        # Encrypt if needed
        if proto_opts & 0x02:
            nonce, ciphertext_with_tag = encrypt_aes_gcm(data, self._key)
            data = nonce + ciphertext_with_tag

        # Chunk
        chunks = chunk_data(data, self._chunk_size)
        total_chunks = len(chunks)

        logger.debug(
            f"Sending message: channel={channel_id}, seq={sequence}, "
            f"chunks={total_chunks}, proto_opts=0x{proto_opts:02x}"
        )

        # Send each chunk
        for chunk_index, chunk in enumerate(chunks):
            # Build header
            header = struct.pack(
                self.HEADER_FORMAT,
                ProtocolID.BINARY,
                proto_opts,
                channel_id,
                sequence,
                chunk_index,
                total_chunks
            )

            payload = header + chunk

            # Send via transport layer
            await self._send_api(payload, host, port)

    def _get_next_sequence(self, channel_id: int) -> int:
        """Get next sequence number for channel."""
        if channel_id not in self._sequence_counters:
            self._sequence_counters[channel_id] = 0

        seq = self._sequence_counters[channel_id]
        self._sequence_counters[channel_id] = (seq + 1) % (2**32)  # Wrap at 2^32
        return seq

    def _is_duplicate(self, msg_key: Tuple[int, int]) -> bool:
        """Check if message already processed (deduplication)."""
        now = time.time()

        # Cleanup old entries
        expired = [k for k, t in self._processed_messages.items() if now - t > self._dedup_window]
        for k in expired:
            del self._processed_messages[k]

        return msg_key in self._processed_messages

    def _reassemble_chunks(self, chunks: Dict[int, bytes], total_chunks: int) -> bytes:
        """Reassemble chunks in order."""
        ordered_chunks = [chunks[i] for i in range(total_chunks)]
        return unchunk_data(ordered_chunks)

    def _decrypt(self, data: bytes) -> bytes:
        """Decrypt AES-256-GCM data."""
        if len(data) < 12:
            raise ValueError("Encrypted data too small (no nonce)")

        nonce = data[:12]
        ciphertext_with_tag = data[12:]

        return decrypt_aes_gcm(nonce, ciphertext_with_tag, self._key)

    def _decompress(self, data: bytes) -> bytes:
        """Decompress ZLIB data."""
        return decompress_data(data)

    def _cleanup_stale_buffers(self):
        """Remove buffers older than timeout."""
        now = time.time()
        stale = [
            k for k, v in self._incomplete_messages.items()
            if now - v.created_at > self._buffer_timeout
        ]
        for k in stale:
            logger.warning(f"Removing stale buffer: {k}")
            del self._incomplete_messages[k]
```

---

### Part 5: Tests

**File:** `canonical/python/src/yx/transport/test_binary_protocol.py`

```python
"""
Tests for Protocol 1 (binary) handler.

Traceability:
- specs/architecture/protocol-layers.md (Protocol 1 Tests)
"""

import pytest
import struct
import os
from yx.transport.binary_protocol import BinaryProtocol, BufferEntry
from yx.transport.protocol_router import ProtocolID


@pytest.mark.asyncio
async def test_binary_protocol_single_chunk():
    """Test Protocol 1 with single chunk."""
    key = os.urandom(32)
    received = []

    async def on_message(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_message)

    # Create single-chunk message
    message_data = b"Small message"
    header = struct.pack(
        BinaryProtocol.HEADER_FORMAT,
        ProtocolID.BINARY,
        0x00,  # No compression/encryption
        0,     # channel_id
        0,     # sequence
        0,     # chunk_index
        1      # total_chunks
    )
    payload = header + message_data

    await handler.handle(payload)

    assert len(received) == 1
    assert received[0] == message_data


@pytest.mark.asyncio
async def test_binary_protocol_multi_chunk():
    """Test Protocol 1 with multiple chunks."""
    key = os.urandom(32)
    received = []

    async def on_message(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_message, chunk_size=10)

    # Create 3-chunk message
    original_data = b"A" * 25  # Will be 3 chunks of 10 bytes each
    chunks = [original_data[i:i+10] for i in range(0, 25, 10)]

    for chunk_index, chunk in enumerate(chunks):
        header = struct.pack(
            BinaryProtocol.HEADER_FORMAT,
            ProtocolID.BINARY,
            0x00,
            0,  # channel_id
            0,  # sequence
            chunk_index,
            len(chunks)
        )
        payload = header + chunk
        await handler.handle(payload)

    assert len(received) == 1
    assert received[0] == original_data


@pytest.mark.asyncio
async def test_binary_protocol_compressed():
    """Test Protocol 1 with compression."""
    key = os.urandom(32)
    received = []

    async def on_message(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_message)

    # Send with compression
    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)

    original = b"Hello! " * 100
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x01)  # Compress

    # Simulate receiving
    for packet in sent:
        await handler.handle(packet)

    assert len(received) == 1
    assert received[0] == original


@pytest.mark.asyncio
async def test_binary_protocol_encrypted():
    """Test Protocol 1 with encryption."""
    key = os.urandom(32)
    received = []

    async def on_message(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_message)

    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)

    original = b"Secret message!"
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x02)  # Encrypt

    # Simulate receiving
    for packet in sent:
        await handler.handle(packet)

    assert len(received) == 1
    assert received[0] == original


@pytest.mark.asyncio
async def test_binary_protocol_compressed_and_encrypted():
    """Test Protocol 1 with both compression and encryption."""
    key = os.urandom(32)
    received = []

    async def on_message(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_message)

    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)

    original = b"Secret! " * 100
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x03)  # Both

    # Simulate receiving
    for packet in sent:
        await handler.handle(packet)

    assert len(received) == 1
    assert received[0] == original


@pytest.mark.asyncio
async def test_binary_protocol_channel_isolation():
    """Test that different channels don't interfere."""
    key = os.urandom(32)
    received = []

    async def on_message(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_message)

    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)

    # Send on channel 1
    await handler.send(b"Channel 1", "127.0.0.1", 9999, channel_id=1)

    # Send on channel 2
    await handler.send(b"Channel 2", "127.0.0.1", 9999, channel_id=2)

    # Receive all packets
    for packet in sent:
        await handler.handle(packet)

    assert len(received) == 2
    assert b"Channel 1" in received
    assert b"Channel 2" in received
```

---

## Verification

```bash
cd canonical/python

# Run all Protocol 1 tests
pytest src/yx/primitives/test_data_compression.py -v
pytest src/yx/primitives/test_data_crypto.py::test_aes_gcm* -v
pytest src/yx/primitives/test_data_chunking.py -v
pytest src/yx/transport/test_binary_protocol.py -v

# Verify all pass
pytest src/yx/ -v --tb=short
```

---

## Success Criteria

✅ **All primitives implemented:**
- [ ] Compression (ZLIB)
- [ ] Encryption (AES-256-GCM)
- [ ] Chunking

✅ **Protocol 1 handler complete:**
- [ ] Header parsing
- [ ] Chunk reassembly
- [ ] Compression/decompression
- [ ] Encryption/decryption
- [ ] Channel multiplexing
- [ ] Deduplication
- [ ] Stale buffer cleanup

✅ **Tests passing:**
- [ ] 20+ tests passing
- [ ] All protocol variants tested (0x00, 0x01, 0x02, 0x03)
- [ ] Coverage ≥90%

✅ **Traceability:**
- [ ] ≥80% of code has traceability comments

---

## Next Steps

After this step:
1. ✅ Commit changes
2. ✅ Proceed to **Step 13: Security (Replay Protection + Rate Limiting)**

---

## References

**Specifications:**
- `specs/architecture/protocol-layers.md`
- `specs/technical/yx-protocol-spec.md`
- `specs/architecture/security-architecture.md`

**SDTS Reference:**
- `sdts-comparison/python/yx/transport/binary_protocol.py`
