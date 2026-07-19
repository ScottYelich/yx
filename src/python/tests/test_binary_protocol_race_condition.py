#!/usr/bin/env python3
"""
test_binary_protocol_race_condition.py

Unit test to verify that BinaryProtocol handles simultaneous duplicate chunks
without processing the same message multiple times.

This test simulates the race condition that was causing "Received response for
unknown request" errors when multiple chunks arrived simultaneously via UDP
broadcast with SO_REUSEPORT enabled.
"""

import asyncio
import pytest
import sys
from pathlib import Path

# Add YX framework to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.data_chunking import chunk_data


class MessageCounter:
    """Helper to count how many times a message is received"""
    def __init__(self):
        self.count = 0
        self.messages = []

    async def on_message(self, message):
        """Callback that counts messages"""
        self.count += 1
        self.messages.append(message)


@pytest.mark.asyncio
async def test_no_duplicate_processing_single_chunk():
    """
    Test that a single-chunk message received twice is only processed once.

    Simulates: UDP packet duplication or SO_REUSEPORT delivering same packet twice
    """
    key = bytes.fromhex('D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD')
    counter = MessageCounter()
    protocol = BinaryProtocol(key=key, on_message=counter.on_message)

    # Create a single-chunk message (small JSON payload)
    test_message = b'{"method": "test", "params": {"value": 42}}'

    # Chunk it (will be 1 chunk since it's small)
    chunks = chunk_data(test_message, chunk_size=1024)
    assert len(chunks) == 1, "Test payload should fit in single chunk"

    # Build binary protocol packet (no encryption/compression for simplicity)
    # Header: [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)] + [data]
    import struct
    proto_id = 1
    proto_opts = 0x00  # No compression or encryption
    channel_id = 1
    sequence = 1
    chunk_index = 0
    total_chunks = 1

    header = struct.pack('>BBHIII', proto_id, proto_opts, channel_id, sequence,
                         chunk_index, total_chunks)
    packet = header + chunks[0]

    # Simulate receiving the SAME packet TWICE (UDP duplication)
    await protocol.handle(packet)
    await protocol.handle(packet)

    # Wait for async processing
    await asyncio.sleep(0.1)

    # Verify: Message should only be processed ONCE despite receiving packet twice
    assert counter.count == 1, f"Message processed {counter.count} times, expected 1"
    assert len(counter.messages) == 1, f"Got {len(counter.messages)} messages, expected 1"


@pytest.mark.asyncio
async def test_no_duplicate_processing_multi_chunk():
    """
    Test that a multi-chunk message with duplicate final chunk is only processed once.

    Simulates: Final chunk arriving twice before buffer cleanup completes
    """
    key = bytes.fromhex('D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD')
    counter = MessageCounter()
    protocol = BinaryProtocol(key=key, chunk_size=100, on_message=counter.on_message)

    # Create a multi-chunk message (large payload that will be chunked)
    test_message = b'{"method": "test", "data": "' + (b'x' * 500) + b'"}'

    # Chunk it with small chunk size to force multiple chunks
    chunks = chunk_data(test_message, chunk_size=100)
    assert len(chunks) > 1, "Test payload should be split into multiple chunks"

    # Build and send all packets
    import struct
    proto_id = 1
    proto_opts = 0x00
    channel_id = 1
    sequence = 1
    total_chunks = len(chunks)

    packets = []
    for chunk_index, chunk in enumerate(chunks):
        header = struct.pack('>BBHIII', proto_id, proto_opts, channel_id, sequence,
                             chunk_index, total_chunks)
        packets.append(header + chunk)

    # Send all chunks EXCEPT the last one
    for packet in packets[:-1]:
        await protocol.handle(packet)

    # Verify message NOT processed yet
    assert counter.count == 0, "Message should not be processed until all chunks received"

    # Now send the LAST chunk TWICE (simulating race condition)
    await protocol.handle(packets[-1])
    await protocol.handle(packets[-1])  # DUPLICATE!

    # Wait for async processing
    await asyncio.sleep(0.1)

    # Verify: Message should only be processed ONCE despite duplicate final chunk
    assert counter.count == 1, f"Message processed {counter.count} times, expected 1"
    assert len(counter.messages) == 1, f"Got {len(counter.messages)} messages, expected 1"


@pytest.mark.asyncio
async def test_concurrent_chunk_arrival():
    """
    Test that all chunks arriving simultaneously only process message once.

    Simulates: Broadcast storm where all chunks arrive at exact same time
    """
    key = bytes.fromhex('D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD')
    counter = MessageCounter()
    protocol = BinaryProtocol(key=key, chunk_size=100, on_message=counter.on_message)

    # Create multi-chunk message
    test_message = b'{"method": "test", "data": "' + (b'y' * 300) + b'"}'
    chunks = chunk_data(test_message, chunk_size=100)

    # Build all packets
    import struct
    proto_id = 1
    proto_opts = 0x00
    channel_id = 1
    sequence = 1
    total_chunks = len(chunks)

    packets = []
    for chunk_index, chunk in enumerate(chunks):
        header = struct.pack('>BBHIII', proto_id, proto_opts, channel_id, sequence,
                             chunk_index, total_chunks)
        packets.append(header + chunk)

    # Send ALL chunks concurrently (simulate simultaneous arrival)
    await asyncio.gather(*[protocol.handle(packet) for packet in packets])

    # Wait for async processing
    await asyncio.sleep(0.1)

    # Verify: Message processed exactly once
    assert counter.count == 1, f"Message processed {counter.count} times, expected 1"


@pytest.mark.asyncio
async def test_multiple_messages_no_crosstalk():
    """
    Test that multiple different messages don't interfere with each other.

    Ensures the race condition fix doesn't break normal multi-message handling.
    """
    key = bytes.fromhex('D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD')
    counter = MessageCounter()
    protocol = BinaryProtocol(key=key, chunk_size=100, on_message=counter.on_message)

    # Create 3 different messages with different sequence numbers
    messages = [
        (1, b'{"id": 1}'),
        (2, b'{"id": 2}'),
        (3, b'{"id": 3}'),
    ]

    # Send all messages concurrently
    import struct
    for sequence, msg in messages:
        chunks = chunk_data(msg, chunk_size=100)
        for chunk_index, chunk in enumerate(chunks):
            proto_id = 1
            proto_opts = 0x00
            channel_id = 1
            total_chunks = len(chunks)

            header = struct.pack('>BBHIII', proto_id, proto_opts, channel_id, sequence,
                                 chunk_index, total_chunks)
            packet = header + chunk
            await protocol.handle(packet)

    # Wait for processing
    await asyncio.sleep(0.1)

    # Verify: All 3 messages processed exactly once
    assert counter.count == 3, f"Expected 3 messages, got {counter.count}"
    assert len(set(str(m) for m in counter.messages)) == 3, "Messages should be unique"


if __name__ == '__main__':
    # Run tests with pytest
    pytest.main([__file__, '-v'])
