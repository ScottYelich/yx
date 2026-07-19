"""
Binary protocol (Protocol 1) handler - v2.0

Handles chunked/encrypted/compressed binary packets with channel + sequence design.

Version 2.0 Changes:
- Replaced 1-byte msgID with 2-byte channelID + 4-byte sequence
- Buffer key changed from msgID to (channelID, sequence) tuple
- Enables channel isolation and virtually unlimited message capacity
"""

import asyncio
import struct
import time
from typing import Dict, Optional, Tuple, List
from dataclasses import dataclass, field
from ..primitives.data_chunking import chunk_data, unchunk_data
from ..primitives.data_compression import compress_data, decompress_data
from ..primitives.data_crypto import encrypt_aes_gcm, decrypt_aes_gcm
from ..primitives.logger import Logger

logger = Logger("BinaryProtocol")


@dataclass
class BufferEntry:
    """Buffer for reassembling chunked messages"""
    chunks: Dict[int, bytes] = field(default_factory=dict)
    total_chunks: int = 0
    created_at: float = field(default_factory=time.time)
    channel_id: int = 0  # v2.0: track channel for debugging
    sequence: int = 0    # v2.0: track sequence for debugging


class BinaryProtocol:
    """Protocol 1: Binary/chunked message handler with encryption and compression (v2.0)"""

    PROTO_OPTS_COMPRESS = 0x01
    PROTO_OPTS_ENCRYPT = 0x02

    def __init__(self, key: bytes, chunk_size: int = 1024, buffer_timeout: float = 60.0, on_message=None, dedup_window: float = 5.0):
        """
        Initialize binary protocol handler.

        Args:
            key: Symmetric key for encryption
            chunk_size: Maximum chunk size (default: 1024)
            buffer_timeout: Timeout for incomplete buffers (default: 60s)
            on_message: Callback for reassembled messages
            dedup_window: Time window for message deduplication (default: 5.0s)
        """
        self.key = key
        self.chunk_size = chunk_size
        self.buffer_timeout = buffer_timeout
        self.on_message = on_message
        self.dedup_window = dedup_window
        self._buffers: Dict[Tuple[int, int], BufferEntry] = {}  # (channelID, sequence) -> BufferEntry
        self._sequence_counters: Dict[int, int] = {}  # channelID -> next sequence number
        self._processed_messages: Dict[Tuple[int, int], float] = {}  # (channelID, sequence) -> timestamp

    async def handle(self, payload: bytes):
        """
        Handle binary protocol payload (v2.0 with channelID + sequence).

        Args:
            payload: Raw payload starting with protocol ID
        """
        try:
            if len(payload) < 16:  # Minimum header size
                logger.error(f"Payload too small for binary protocol: {len(payload)} bytes")
                return

            # Parse header v2.0: [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)] + [data]
            proto_id = payload[0]
            proto_opts = payload[1]
            channel_id = struct.unpack('>H', payload[2:4])[0]  # 2 bytes, big-endian
            sequence = struct.unpack('>I', payload[4:8])[0]    # 4 bytes, big-endian
            chunk_index = struct.unpack('>I', payload[8:12])[0]
            total_chunks = struct.unpack('>I', payload[12:16])[0]
            chunk_data_raw = payload[16:]

            # Buffer key is (channelID, sequence) tuple
            buffer_key = (channel_id, sequence)

            # DEDUPLICATION: Check if we've already processed this message
            current_time = time.time()
            if buffer_key in self._processed_messages:
                last_processed = self._processed_messages[buffer_key]
                if current_time - last_processed < self.dedup_window:
                    # Duplicate message within dedup window - ignore silently
                    logger.debug(f"Ignoring duplicate message ch={channel_id} seq={sequence}")
                    return

            # Clean up old entries from dedup cache
            self._processed_messages = {
                k: v for k, v in self._processed_messages.items()
                if current_time - v < self.dedup_window
            }

            # Store chunk (no per-chunk decryption - decrypt after reassembly)
            if buffer_key not in self._buffers:
                self._buffers[buffer_key] = BufferEntry(
                    total_chunks=total_chunks,
                    channel_id=channel_id,
                    sequence=sequence
                )

            buffer = self._buffers[buffer_key]
            buffer.chunks[chunk_index] = chunk_data_raw

            # Check if complete
            if len(buffer.chunks) == total_chunks:
                # CRITICAL: Delete buffer IMMEDIATELY to prevent duplicate processing
                # if multiple chunks arrive simultaneously
                buffer_data = self._buffers.pop(buffer_key)

                # Step 1: Reassemble chunks
                ordered_chunks = [buffer_data.chunks[i] for i in range(total_chunks)]
                complete_data = unchunk_data(ordered_chunks)

                # Step 2: Decrypt if encrypted (AFTER reassembly)
                if proto_opts & self.PROTO_OPTS_ENCRYPT:
                    if len(complete_data) < 12:
                        logger.error("Encrypted payload too small")
                        return
                    nonce = complete_data[:12]
                    ciphertext = complete_data[12:]
                    complete_data = decrypt_aes_gcm(nonce, ciphertext, self.key)

                # Step 3: Decompress if compressed (AFTER decryption)
                if proto_opts & self.PROTO_OPTS_COMPRESS:
                    complete_data = decompress_data(complete_data)

                logger.packet(f"Reassembled message ch={channel_id} seq={sequence} ({len(complete_data)} bytes)")

                # Mark as processed (for deduplication)
                self._processed_messages[buffer_key] = time.time()

                # Dispatch to application handler (parse as JSON for RPC)
                if self.on_message:
                    try:
                        # Binary protocol carries JSON-RPC messages (same as text protocol)
                        from ..primitives.json_utils import json_decode_bytes
                        message = json_decode_bytes(complete_data)
                        logger.info(f"Received binary message (ch={channel_id}, seq={sequence}): {message}")
                        await self.on_message(message)
                    except Exception as e:
                        logger.error(f"Failed to parse binary message as JSON: {e}")

                return complete_data

        except Exception as e:
            logger.error(f"Failed to handle binary protocol: {e}")

    async def send(self, data: bytes, proto_opts: int = 0x00, channel_id: int = 1) -> List[bytes]:
        """
        Encode data as binary protocol payloads (v2.0 with channelID + sequence).

        Encoding order: compress → encrypt → chunk → send

        Args:
            data: Data to send
            proto_opts: Protocol options (0x00-0x03)
            channel_id: Logical channel ID (0-65535, default=1)

        Returns:
            List[bytes]: List of chunk payloads
        """
        # Get next sequence number for this channel
        if channel_id not in self._sequence_counters:
            self._sequence_counters[channel_id] = 0

        sequence = self._sequence_counters[channel_id]
        self._sequence_counters[channel_id] = (sequence + 1) % (2**32)  # Wrap at 2^32

        # Step 1: Compress if requested
        encoded_data = data
        if proto_opts & self.PROTO_OPTS_COMPRESS:
            encoded_data = compress_data(encoded_data)

        # Step 2: Encrypt if requested (BEFORE chunking)
        if proto_opts & self.PROTO_OPTS_ENCRYPT:
            nonce, ciphertext = encrypt_aes_gcm(encoded_data, self.key)
            encoded_data = nonce + ciphertext

        # Step 3: Chunk the encoded data
        chunks = chunk_data(encoded_data, self.chunk_size)
        total_chunks = len(chunks)

        # Step 4: Build packets with headers
        payloads = []
        for chunk_index, chunk in enumerate(chunks):
            # Build header v2.0: [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)]
            header = struct.pack('>BBHIII',
                               0x01,           # protoID
                               proto_opts,     # protoOpts
                               channel_id,     # channelID (2 bytes, big-endian)
                               sequence,       # sequence (4 bytes, big-endian)
                               chunk_index,    # chunkIndex
                               total_chunks)   # totalChunks
            payload = header + chunk
            payloads.append(payload)

        logger.send(f"BinaryProtocol: Sent {len(payloads)} chunk(s) ch={channel_id} seq={sequence} opts=0x{proto_opts:02x}")
        return payloads

    def cleanup_stale_buffers(self):
        """Remove buffers that have timed out (v2.0)"""
        now = time.time()
        to_remove = []
        for buffer_key, buffer in self._buffers.items():
            if now - buffer.created_at > self.buffer_timeout:
                to_remove.append(buffer_key)

        for buffer_key in to_remove:
            channel_id, sequence = buffer_key
            del self._buffers[buffer_key]
            logger.warning(f"Removed stale buffer ch={channel_id} seq={sequence}")
