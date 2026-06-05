"""
Validate the canonical artifacts (test-vectors / reference-packets).

Proves the Python implementation reproduces the byte-fixed vectors exactly and
that the round-trip (compressed/encrypted) cases decode back to the original
payload through the real BinaryProtocol receive handler.

Traceability:
- specs/architecture/protocol-layers.md (wire format, chunking)
- canonical/test-vectors/, canonical/reference-packets/
"""

import asyncio
import json
from pathlib import Path

from yx.transport.packet_builder import PacketBuilder
from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.test_helpers import SimplePacketBuilder

CANON = Path(__file__).resolve().parents[2]
TV = CANON / "test-vectors"
REF = CANON / "reference-packets"


def _load(name):
    return json.loads((TV / name).read_text())


def test_transport_vectors_byte_fixed():
    data = _load("transport-packets.json")
    for tc in data["test_cases"]:
        guid = bytes.fromhex(tc["guid"])
        key = bytes.fromhex(tc["key"])
        payload = bytes.fromhex(tc["payload_hex"])
        packet = PacketBuilder.build_packet(guid, payload, key)
        assert packet.hmac.hex() == tc["expected_hmac"], tc["name"]
        assert packet.to_bytes().hex() == tc["expected_packet"], tc["name"]


def test_binary_base_vectors_byte_fixed():
    data = _load("binary-protocol-packets.json")
    for tc in data["byte_fixed"]:
        guid = bytes.fromhex(tc["guid"])
        key = bytes.fromhex(tc["key"])
        payload = bytes.fromhex(tc["payload_hex"])
        packets = SimplePacketBuilder.build_binary_packet(
            payload, guid, key,
            proto_opts=tc["proto_opts"], channel_id=tc["channel_id"],
            sequence=tc["sequence"], chunk_size=tc["chunk_size"])
        assert [p.hex() for p in packets] == tc["expected_packets"], tc["name"]


def test_binary_roundtrip_vectors():
    data = _load("binary-protocol-packets.json")

    async def decode(tc):
        guid = bytes.fromhex(tc["guid"])
        key = bytes.fromhex(tc["key"])
        payload = bytes.fromhex(tc["payload_hex"])

        received = []

        async def on_msg(d):
            received.append(d)

        handler = BinaryProtocol(key=key, on_message=on_msg)

        packets = SimplePacketBuilder.build_binary_packet(
            payload, guid, key, proto_opts=tc["proto_opts"],
            channel_id=tc["channel_id"], sequence=tc["sequence"], chunk_size=tc["chunk_size"])
        for pkt in packets:
            parsed = PacketBuilder.parse_packet(pkt)
            assert PacketBuilder.validate_hmac(parsed, key), tc["name"]
            await handler.handle(parsed.payload)

        assert received, f"no message reassembled: {tc['name']}"
        assert received[0].hex() == tc["expected_plaintext_hex"], tc["name"]

    for tc in data["round_trip"]:
        asyncio.run(decode(tc))


def test_reference_packets_match_vectors():
    transport = _load("transport-packets.json")
    binary = _load("binary-protocol-packets.json")
    name_map = {
        "transport-simple.bin": transport["test_cases"][0]["expected_packet"],
        "transport-empty.bin": transport["test_cases"][1]["expected_packet"],
        "transport-large.bin": transport["test_cases"][2]["expected_packet"],
        "proto1-base-chunk0.bin": binary["byte_fixed"][0]["expected_packets"][0],
    }
    for fn, expected_hex in name_map.items():
        raw = (REF / fn).read_bytes()
        assert raw.hex() == expected_hex, fn
