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
