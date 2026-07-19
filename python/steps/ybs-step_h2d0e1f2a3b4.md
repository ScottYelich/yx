# YBS Step: Binary Protocol Handler

**Step ID:** `ybs-step_h2d0e1f2a3b4`
**Language:** Python
**Prerequisites:** Steps h2a, h2b, h2c complete (compression, chunking, AES-GCM all working)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. File exists at `{{CONFIG:impl_src}}/transport/binary_protocol.py`
2. Tests pass when running pytest

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/transport/binary_protocol.py` — Protocol 1 binary/chunked handler.

---

## Implementation

**File:** `{{CONFIG:impl_src}}/transport/binary_protocol.py`

```python
"""
Protocol 1: Binary/Chunked handler (v2.0).

Traceability:
- protocol/specs/architecture/protocol-layers.md (Protocol 1)
- protocol/specs/technical/yx-protocol-spec.md (Binary Protocol v2.0)
- protocol/specs/technical/default-values.md (chunk_size=1024, buffer_timeout=60.0)
"""

import struct
import time
import logging
from typing import Dict, Tuple, Optional, Callable, Awaitable
from dataclasses import dataclass, field

from ..primitives.data_compression import compress_data, decompress_data
from ..primitives.data_crypto import encrypt_aes_gcm, decrypt_aes_gcm
from ..primitives.data_chunking import chunk_data, unchunk_data
from .protocol_router import ProtocolID

logger = logging.getLogger(__name__)

# Header: proto(1) + protoOpts(1) + channelID(2) + sequence(4) + chunkIndex(4) + totalChunks(4)
HEADER_FORMAT = ">BBHIII"
HEADER_SIZE = 16


@dataclass
class BufferEntry:
    """Incomplete message buffer entry."""
    chunks: Dict[int, bytes] = field(default_factory=dict)
    total_chunks: Optional[int] = None
    created_at: float = field(default_factory=time.time)
    proto_opts: int = 0


class BinaryProtocol:
    """
    Protocol 1 handler for binary/chunked messages.

    Traceability:
    - protocol/specs/architecture/protocol-layers.md (Protocol 1)
    - protocol/specs/technical/yx-protocol-spec.md (Binary Protocol v2.0)
    """

    HEADER_FORMAT = HEADER_FORMAT
    HEADER_SIZE = HEADER_SIZE

    def __init__(
        self,
        key: bytes,
        on_message: Optional[Callable[[bytes], Awaitable[None]]] = None,
        chunk_size: int = 1024,
        buffer_timeout: float = 60.0
    ):
        self._key = key
        self._on_message = on_message
        self._chunk_size = chunk_size
        self._buffer_timeout = buffer_timeout
        self._send_api = None
        self._incomplete: Dict[Tuple[int, int], BufferEntry] = {}
        self._processed: Dict[Tuple[int, int], float] = {}
        self._sequences: Dict[int, int] = {}

    def install_send_api(self, send_fn: Callable[[bytes, str, int], Awaitable[None]]):
        """Install send function from transport layer."""
        self._send_api = send_fn

    async def handle(self, payload: bytes):
        """
        Process received Protocol 1 payload.

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 1 Receive Path)
        """
        if not payload or payload[0] != ProtocolID.BINARY:
            return
        if len(payload) < HEADER_SIZE:
            return

        try:
            proto, proto_opts, channel_id, sequence, chunk_index, total_chunks = struct.unpack(
                HEADER_FORMAT, payload[:HEADER_SIZE]
            )
        except struct.error:
            return

        chunk_bytes = payload[HEADER_SIZE:]
        msg_key = (channel_id, sequence)

        # Deduplication
        if msg_key in self._processed:
            return

        # Buffer chunk
        if msg_key not in self._incomplete:
            self._incomplete[msg_key] = BufferEntry(proto_opts=proto_opts)

        entry = self._incomplete[msg_key]
        entry.chunks[chunk_index] = chunk_bytes
        entry.total_chunks = total_chunks

        if len(entry.chunks) == total_chunks:
            del self._incomplete[msg_key]
            self._processed[msg_key] = time.time()

            # Reassemble
            ordered = [entry.chunks[i] for i in range(total_chunks)]
            data = unchunk_data(ordered)

            # Decrypt if needed
            if proto_opts & 0x02:
                if len(data) < 12:
                    return
                data = decrypt_aes_gcm(data[:12], data[12:], self._key)

            # Decompress if needed
            if proto_opts & 0x01:
                data = decompress_data(data)

            if self._on_message:
                try:
                    await self._on_message(data)
                except Exception as e:
                    logger.exception(f"Error in message handler: {e}")

        if len(self._incomplete) > 10:
            self._cleanup_stale()

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

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Protocol 1 Send Path)
        """
        if self._send_api is None:
            raise RuntimeError("Send API not installed")

        sequence = self._next_sequence(channel_id)

        # Compress then encrypt
        if proto_opts & 0x01:
            data = compress_data(data)
        if proto_opts & 0x02:
            nonce, ct = encrypt_aes_gcm(data, self._key)
            data = nonce + ct

        chunks = chunk_data(data, self._chunk_size)
        total = len(chunks)

        for i, chunk in enumerate(chunks):
            header = struct.pack(
                HEADER_FORMAT,
                ProtocolID.BINARY, proto_opts, channel_id, sequence, i, total
            )
            await self._send_api(header + chunk, host, port)

    def _next_sequence(self, channel_id: int) -> int:
        seq = self._sequences.get(channel_id, 0)
        self._sequences[channel_id] = (seq + 1) % (2**32)
        return seq

    def _cleanup_stale(self):
        now = time.time()
        stale = [k for k, v in self._incomplete.items()
                 if now - v.created_at > self._buffer_timeout]
        for k in stale:
            del self._incomplete[k]
        old = [k for k, t in self._processed.items() if now - t > self._buffer_timeout]
        for k in old:
            del self._processed[k]
```

---

## Tests

**File:** `{{CONFIG:impl_src}}/transport/test_binary_protocol.py`

```python
"""Tests for Protocol 1 binary handler."""

import pytest
import struct
import os
from yx.transport.binary_protocol import BinaryProtocol, HEADER_FORMAT
from yx.transport.protocol_router import ProtocolID


@pytest.mark.asyncio
async def test_single_chunk():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    msg = b"Small message"
    header = struct.pack(HEADER_FORMAT, ProtocolID.BINARY, 0x00, 0, 0, 0, 1)
    await handler.handle(header + msg)
    assert received == [msg]


@pytest.mark.asyncio
async def test_multi_chunk():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    original = b"A" * 25
    chunks = [original[i:i+10] for i in range(0, 25, 10)]
    for i, chunk in enumerate(chunks):
        header = struct.pack(HEADER_FORMAT, ProtocolID.BINARY, 0x00, 0, 0, i, len(chunks))
        await handler.handle(header + chunk)
    assert received == [original]


@pytest.mark.asyncio
async def test_send_receive_compressed():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)
    original = b"Hello! " * 100
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x01)
    for p in sent:
        await handler.handle(p)
    assert received == [original]


@pytest.mark.asyncio
async def test_send_receive_encrypted():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)
    original = b"Secret!"
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x02)
    for p in sent:
        await handler.handle(p)
    assert received == [original]


@pytest.mark.asyncio
async def test_send_receive_both():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)
    original = b"Secret! " * 100
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x03)
    for p in sent:
        await handler.handle(p)
    assert received == [original]
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/transport/test_binary_protocol.py -v
```

All 5 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_h2d0e1f2a3b4-DONE.txt`:

```
STEP: ybs-step_h2d0e1f2a3b4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/transport/binary_protocol.py, test_binary_protocol.py
VERIFICATION: PASSED
NEXT: ybs-step_i3a0b1c2d3e4
```

Update `BUILD_STATUS.md`: add `- [x] h2d0e1f2a3b4`.
