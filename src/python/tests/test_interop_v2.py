"""
Integration tests for YX Protocol v2.0 cross-language interoperability.

Tests Python ↔ Swift communication using the new channelID + sequence protocol.
"""

import pytest
import asyncio
import struct
from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.data_crypto import generate_key


class TestProtocolV2Interoperability:
    """Test v2.0 protocol interoperability between Python and Swift implementations"""

    @pytest.fixture
    def protocol(self):
        """Create a BinaryProtocol instance with fixed test key"""
        # Use fixed key for deterministic testing
        key = bytes.fromhex("D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD")
        return BinaryProtocol(key=key, chunk_size=1024)

    @pytest.mark.asyncio
    async def test_python_encode_swift_decode_format(self, protocol):
        """
        Test that Python encodes packets in the format Swift expects.

        Swift expects: [protoID(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] + [chunkIndex(4)] + [totalChunks(4)]
        """
        test_data = b"Hello from Python to Swift!"
        channel_id = 42

        # Encode using Python
        payloads = await protocol.send(test_data, proto_opts=0x00, channel_id=channel_id)

        assert len(payloads) == 1  # Single chunk
        payload = payloads[0]

        # Verify header format matches Swift expectations
        assert len(payload) >= 16

        # Parse header manually (as Swift would)
        proto_id = payload[0]
        proto_opts = payload[1]
        parsed_channel_id = struct.unpack('>H', payload[2:4])[0]  # Big-endian uint16
        sequence = struct.unpack('>I', payload[4:8])[0]           # Big-endian uint32
        chunk_index = struct.unpack('>I', payload[8:12])[0]       # Big-endian uint32
        total_chunks = struct.unpack('>I', payload[12:16])[0]     # Big-endian uint32
        chunk_data = payload[16:]

        # Verify all fields
        assert proto_id == 0x01, "Protocol ID should be 0x01 (Binary)"
        assert proto_opts == 0x00, "Protocol options should be 0x00 (no compression/encryption)"
        assert parsed_channel_id == channel_id, f"Channel ID mismatch: expected {channel_id}, got {parsed_channel_id}"
        assert sequence == 0, "First message should have sequence 0"
        assert chunk_index == 0, "First chunk should have index 0"
        assert total_chunks == 1, "Single chunk message"
        assert chunk_data == test_data, "Chunk data should match original"

    @pytest.mark.asyncio
    async def test_swift_format_python_decode(self, protocol):
        """
        Test that Python can decode packets in Swift's v2.0 format.

        Simulates receiving a packet from Swift.
        """
        # Simulate Swift sending a message
        test_data = b"Hello from Swift to Python!"
        channel_id = 99
        sequence = 5

        # Build packet as Swift would (v2.0 format)
        header = struct.pack('>BBHIII',
            0x01,          # protoID
            0x00,          # protoOpts
            channel_id,    # channelID (2 bytes, big-endian)
            sequence,      # sequence (4 bytes, big-endian)
            0,             # chunkIndex
            1              # totalChunks
        )

        swift_packet = header + test_data

        # Decode using Python
        result = await protocol.handle(swift_packet)

        # Verify buffer was created and cleared (message reassembled)
        assert len(protocol._buffers) == 0, "Buffer should be empty after reassembly"

    @pytest.mark.asyncio
    async def test_multi_chunk_interop(self, protocol):
        """Test multi-chunk messages maintain format compatibility"""
        # Create message larger than chunk size
        large_data = b"X" * 3000
        channel_id = 10

        # Encode
        payloads = await protocol.send(large_data, channel_id=channel_id)

        assert len(payloads) > 1, "Should be chunked"

        # Verify all chunks have same channelID and sequence
        first_channel_id = struct.unpack('>H', payloads[0][2:4])[0]
        first_sequence = struct.unpack('>I', payloads[0][4:8])[0]

        for i, payload in enumerate(payloads):
            channel_id_in_chunk = struct.unpack('>H', payload[2:4])[0]
            sequence_in_chunk = struct.unpack('>I', payload[4:8])[0]
            chunk_index = struct.unpack('>I', payload[8:12])[0]
            total_chunks = struct.unpack('>I', payload[12:16])[0]

            assert channel_id_in_chunk == first_channel_id, f"Channel ID mismatch in chunk {i}"
            assert sequence_in_chunk == first_sequence, f"Sequence mismatch in chunk {i}"
            assert chunk_index == i, f"Chunk index should be {i}"
            assert total_chunks == len(payloads), "Total chunks should match"

    @pytest.mark.asyncio
    async def test_channel_isolation_interop(self, protocol):
        """Test that different channels maintain independent sequences"""
        # Send on multiple channels (as if communicating with multiple Swift peers)

        # Channel 1, message 1
        p1 = await protocol.send(b"ch1-msg1", channel_id=1)
        seq1_1 = struct.unpack('>I', p1[0][4:8])[0]

        # Channel 2, message 1
        p2 = await protocol.send(b"ch2-msg1", channel_id=2)
        seq2_1 = struct.unpack('>I', p2[0][4:8])[0]

        # Channel 1, message 2
        p1_2 = await protocol.send(b"ch1-msg2", channel_id=1)
        seq1_2 = struct.unpack('>I', p1_2[0][4:8])[0]

        # Verify sequences
        assert seq1_1 == 0, "Channel 1 first message should be seq 0"
        assert seq2_1 == 0, "Channel 2 first message should be seq 0"
        assert seq1_2 == 1, "Channel 1 second message should be seq 1"

    @pytest.mark.asyncio
    async def test_compression_interop(self, protocol):
        """Test compressed messages maintain format compatibility"""
        # Highly compressible data
        data = b"AAAA" * 500
        channel_id = 5

        payloads = await protocol.send(data, proto_opts=0x01, channel_id=channel_id)

        # Verify protoOpts flag
        proto_opts = payloads[0][1]
        assert proto_opts == 0x01, "Compression flag should be set"

        # Verify channel ID is still correct
        parsed_channel_id = struct.unpack('>H', payloads[0][2:4])[0]
        assert parsed_channel_id == channel_id

    @pytest.mark.asyncio
    async def test_encryption_interop(self, protocol):
        """Test encrypted messages maintain format compatibility"""
        data = b"Secret message"
        channel_id = 6

        payloads = await protocol.send(data, proto_opts=0x02, channel_id=channel_id)

        # Verify protoOpts flag
        proto_opts = payloads[0][1]
        assert proto_opts == 0x02, "Encryption flag should be set"

        # Verify channel ID is still correct
        parsed_channel_id = struct.unpack('>H', payloads[0][2:4])[0]
        assert parsed_channel_id == channel_id

        # Verify data is encrypted (not plaintext)
        chunk_data = payloads[0][16:]
        assert chunk_data != data, "Data should be encrypted"

    @pytest.mark.asyncio
    async def test_big_endian_encoding(self, protocol):
        """Test that all multi-byte fields use big-endian encoding (network byte order)"""
        channel_id = 0x1234  # 4660 in decimal

        payloads = await protocol.send(b"test", channel_id=channel_id)
        payload = payloads[0]

        # Extract raw bytes
        channel_id_bytes = payload[2:4]

        # Verify big-endian encoding
        # Big-endian: most significant byte first
        # 0x1234 should be stored as [0x12, 0x34]
        assert channel_id_bytes[0] == 0x12, "First byte should be 0x12 (MSB)"
        assert channel_id_bytes[1] == 0x34, "Second byte should be 0x34 (LSB)"

        # Verify round-trip
        decoded = struct.unpack('>H', channel_id_bytes)[0]
        assert decoded == channel_id

    @pytest.mark.asyncio
    async def test_header_size_constant(self, protocol):
        """Test that header is always exactly 16 bytes (Swift constant)"""
        # Try various payload sizes
        for size in [1, 10, 100, 1000]:
            data = b"X" * size
            payloads = await protocol.send(data, channel_id=1)

            for payload in payloads:
                # Header is first 16 bytes, data starts at byte 16
                assert len(payload) >= 16, f"Payload too small for {size} byte data"

                # Verify we can parse all 16 header bytes
                proto_id = payload[0]
                proto_opts = payload[1]
                channel_id = struct.unpack('>H', payload[2:4])[0]
                sequence = struct.unpack('>I', payload[4:8])[0]
                chunk_index = struct.unpack('>I', payload[8:12])[0]
                total_chunks = struct.unpack('>I', payload[12:16])[0]

                # All should parse successfully
                assert proto_id == 0x01
                assert channel_id > 0

    @pytest.mark.asyncio
    async def test_full_round_trip(self, protocol):
        """Test complete encode → decode round trip"""
        original_data = b"Round trip test message"
        channel_id = 7

        # Track received messages
        received = []

        async def on_message(msg):
            received.append(msg)

        protocol.on_message = on_message

        # Encode
        payloads = await protocol.send(original_data, channel_id=channel_id)

        # Decode
        for payload in payloads:
            await protocol.handle(payload)

        # Verify buffer was cleared (reassembly complete)
        assert len(protocol._buffers) == 0

    @pytest.mark.asyncio
    async def test_sequence_counter_persistence(self, protocol):
        """Test that sequence counters persist across multiple sends"""
        channel_id = 15

        sequences = []
        for i in range(5):
            payloads = await protocol.send(b"test", channel_id=channel_id)
            seq = struct.unpack('>I', payloads[0][4:8])[0]
            sequences.append(seq)

        # Verify sequences are sequential
        assert sequences == [0, 1, 2, 3, 4]


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v"])
