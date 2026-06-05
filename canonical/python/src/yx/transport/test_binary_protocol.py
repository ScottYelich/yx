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
