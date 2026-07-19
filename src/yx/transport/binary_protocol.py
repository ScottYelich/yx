"""
Protocol 1: Binary/Chunked handler (v2.0).

Traceability:
- protocol/specs/architecture/protocol-layers.md (Protocol 1)
- protocol/specs/technical/yx-protocol-spec.md (Binary Protocol v2.0)
- protocol/specs/technical/default-values.md (chunk_size=1024, buffer_timeout=60.0)
"""

import os
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
                nonce = data[:12]
                ciphertext = data[12:]
                data = decrypt_aes_gcm(nonce, ciphertext, self._key)

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
