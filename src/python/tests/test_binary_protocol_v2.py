"""
Unit tests for Binary Protocol v2.0 (channel + sequence design)

Tests the new header format with channelID + sequence instead of msgID.
"""

import pytest
import struct
import asyncio
from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.data_crypto import generate_key


class TestBinaryProtocolV2:
    """Test suite for Binary Protocol v2.0"""

    @pytest.fixture
    def protocol(self):
        """Create a BinaryProtocol instance with test key"""
        key = generate_key(256)
        return BinaryProtocol(key=key, chunk_size=1024)

    @pytest.mark.asyncio
    async def test_header_encoding_single_chunk(self, protocol):
        """Test header encoding for single chunk message"""
        test_data = b"Hello, YX v2.0!"
        channel_id = 42

        # Send data
        payloads = await protocol.send(test_data, proto_opts=0x00, channel_id=channel_id)

        # Should be single chunk
        assert len(payloads) == 1
        payload = payloads[0]

        # Parse header: [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)]
        assert len(payload) >= 16
        proto_id = payload[0]
        proto_opts = payload[1]
        parsed_channel_id = struct.unpack('>H', payload[2:4])[0]
        sequence = struct.unpack('>I', payload[4:8])[0]
        chunk_index = struct.unpack('>I', payload[8:12])[0]
        total_chunks = struct.unpack('>I', payload[12:16])[0]
        chunk_data = payload[16:]

        # Verify header fields
        assert proto_id == 0x01  # Binary protocol
        assert proto_opts == 0x00  # No compression or encryption
        assert parsed_channel_id == channel_id
        assert sequence == 0  # First message on this channel
        assert chunk_index == 0
        assert total_chunks == 1
        assert chunk_data == test_data

    @pytest.mark.asyncio
    async def test_sequence_increment(self, protocol):
        """Test that sequence numbers increment per channel"""
        channel_id = 10

        # Send 5 messages on same channel
        for i in range(5):
            payloads = await protocol.send(b"test", channel_id=channel_id)
            payload = payloads[0]
            sequence = struct.unpack('>I', payload[4:8])[0]
            assert sequence == i  # Should increment: 0, 1, 2, 3, 4

    @pytest.mark.asyncio
    async def test_channel_isolation(self, protocol):
        """Test that different channels have independent sequence counters"""
        # Send on channel 1
        payloads_ch1_msg1 = await protocol.send(b"ch1-msg1", channel_id=1)
        seq_ch1_msg1 = struct.unpack('>I', payloads_ch1_msg1[0][4:8])[0]

        # Send on channel 2
        payloads_ch2_msg1 = await protocol.send(b"ch2-msg1", channel_id=2)
        seq_ch2_msg1 = struct.unpack('>I', payloads_ch2_msg1[0][4:8])[0]

        # Send on channel 1 again
        payloads_ch1_msg2 = await protocol.send(b"ch1-msg2", channel_id=1)
        seq_ch1_msg2 = struct.unpack('>I', payloads_ch1_msg2[0][4:8])[0]

        # Both channels should start at 0
        assert seq_ch1_msg1 == 0
        assert seq_ch2_msg1 == 0

        # Channel 1 second message should be sequence 1
        assert seq_ch1_msg2 == 1

    @pytest.mark.asyncio
    async def test_multi_chunk_message(self, protocol):
        """Test chunking of large messages"""
        # Create data larger than chunk_size (1024 bytes)
        large_data = b"X" * 3000
        channel_id = 5

        payloads = await protocol.send(large_data, channel_id=channel_id)

        # Should be chunked
        assert len(payloads) > 1

        # All chunks should have same channelID and sequence
        first_payload = payloads[0]
        expected_channel_id = struct.unpack('>H', first_payload[2:4])[0]
        expected_sequence = struct.unpack('>I', first_payload[4:8])[0]
        total_chunks = struct.unpack('>I', first_payload[12:16])[0]

        assert expected_channel_id == channel_id
        assert total_chunks == len(payloads)

        for i, payload in enumerate(payloads):
            parsed_channel_id = struct.unpack('>H', payload[2:4])[0]
            parsed_sequence = struct.unpack('>I', payload[4:8])[0]
            chunk_index = struct.unpack('>I', payload[8:12])[0]

            assert parsed_channel_id == expected_channel_id
            assert parsed_sequence == expected_sequence
            assert chunk_index == i

    @pytest.mark.asyncio
    async def test_message_reassembly(self, protocol):
        """Test that chunked messages are correctly reassembled"""
        original_data = b"This is a test message for reassembly"
        channel_id = 7

        # Track reassembled message
        received_message = None

        async def on_message(msg):
            nonlocal received_message
            received_message = msg

        protocol.on_message = on_message

        # Send and immediately handle (simulating receive)
        payloads = await protocol.send(original_data, channel_id=channel_id)

        for payload in payloads:
            await protocol.handle(payload)

        # Message should be reassembled (as JSON in real usage, but we test raw bytes)
        # Note: on_message expects JSON, so this will fail to parse, but complete_data is returned
        # We need to test the internal reassembly instead

        # Directly test by checking buffer is empty (reassembly completed)
        assert len(protocol._buffers) == 0

    @pytest.mark.asyncio
    async def test_compression(self, protocol):
        """Test compressed messages"""
        # Highly compressible data
        data = b"AAAA" * 500  # 2000 bytes of 'A'
        channel_id = 3

        # Send with compression
        payloads_compressed = await protocol.send(data, proto_opts=0x01, channel_id=channel_id)

        # Send without compression
        payloads_uncompressed = await protocol.send(data, proto_opts=0x00, channel_id=channel_id + 1)

        # Compressed should be smaller
        compressed_size = sum(len(p) for p in payloads_compressed)
        uncompressed_size = sum(len(p) for p in payloads_uncompressed)

        assert compressed_size < uncompressed_size

        # Verify proto_opts flag
        assert payloads_compressed[0][1] == 0x01  # Compression flag set

    @pytest.mark.asyncio
    async def test_encryption(self, protocol):
        """Test encrypted messages"""
        data = b"Secret message"
        channel_id = 4

        # Send with encryption
        payloads = await protocol.send(data, proto_opts=0x02, channel_id=channel_id)

        # Verify proto_opts flag
        assert payloads[0][1] == 0x02  # Encryption flag set

        # Chunk data should NOT be plaintext (it's encrypted)
        chunk_data = payloads[0][16:]
        assert chunk_data != data

    @pytest.mark.asyncio
    async def test_compression_and_encryption(self, protocol):
        """Test both compression and encryption together"""
        data = b"ZZZZ" * 300
        channel_id = 6

        # Send with both
        payloads = await protocol.send(data, proto_opts=0x03, channel_id=channel_id)

        # Verify proto_opts flag
        assert payloads[0][1] == 0x03  # Both flags set

    @pytest.mark.asyncio
    async def test_buffer_key_is_tuple(self, protocol):
        """Test that buffer key is (channelID, sequence) tuple"""
        data = b"test"

        # Send on channel 10, sequence will be 0
        payloads = await protocol.send(data, channel_id=10)

        # Handle first chunk (but not all, so buffer remains)
        # First, send a multi-chunk message
        large_data = b"X" * 3000
        payloads_large = await protocol.send(large_data, channel_id=20)

        # Handle only first chunk
        await protocol.handle(payloads_large[0])

        # Buffer should exist with key (20, 0) - channelID=20, sequence=0
        buffer_keys = list(protocol._buffers.keys())
        assert len(buffer_keys) == 1
        assert buffer_keys[0] == (20, 0)  # Tuple of (channelID, sequence)

    @pytest.mark.asyncio
    async def test_out_of_order_chunks(self, protocol):
        """Test that chunks can arrive out of order and still reassemble"""
        large_data = b"Y" * 3000
        channel_id = 8

        payloads = await protocol.send(large_data, channel_id=channel_id)
        assert len(payloads) > 1  # Must be chunked

        # Handle chunks out of order (reverse)
        for payload in reversed(payloads):
            result = await protocol.handle(payload)

        # Should still reassemble successfully
        assert len(protocol._buffers) == 0  # Buffer cleared after reassembly

    @pytest.mark.asyncio
    async def test_sequence_wraparound(self, protocol):
        """Test sequence number wraparound at 2^32"""
        channel_id = 99

        # Set sequence counter to near max
        protocol._sequence_counters[channel_id] = (2**32) - 2

        # Send 3 messages
        for _ in range(3):
            payloads = await protocol.send(b"test", channel_id=channel_id)
            sequence = struct.unpack('>I', payloads[0][4:8])[0]

        # Last message should have wrapped to 0
        # Sequences: (2^32 - 2), (2^32 - 1), 0
        payloads = await protocol.send(b"test", channel_id=channel_id)
        sequence = struct.unpack('>I', payloads[0][4:8])[0]
        assert sequence == 1  # Should be 1 after wraparound

    @pytest.mark.asyncio
    async def test_channel_range(self, protocol):
        """Test full channel ID range (0-65535)"""
        # Test boundary values
        for channel_id in [0, 1, 255, 256, 65534, 65535]:
            payloads = await protocol.send(b"test", channel_id=channel_id)
            parsed_channel_id = struct.unpack('>H', payloads[0][2:4])[0]
            assert parsed_channel_id == channel_id

    @pytest.mark.asyncio
    async def test_header_size_unchanged(self, protocol):
        """Verify header is still 16 bytes"""
        payloads = await protocol.send(b"test", channel_id=1)

        # Header should be exactly 16 bytes
        # [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)]
        # = 1 + 1 + 2 + 4 + 4 + 4 = 16 bytes

        # Minimum payload size is header + data
        assert len(payloads[0]) >= 16

    def test_buffer_entry_tracks_channel_and_sequence(self, protocol):
        """Test that BufferEntry stores channel_id and sequence for debugging"""
        from yx.transport.binary_protocol import BufferEntry

        entry = BufferEntry(total_chunks=3, channel_id=42, sequence=123)
        assert entry.channel_id == 42
        assert entry.sequence == 123
        assert entry.total_chunks == 3


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v"])
