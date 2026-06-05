"""
Generate canonical artifacts for cross-implementation validation.

Produces (under ../../canonical/):
  test-vectors/transport-packets.json       byte-fixed transport packets
  test-vectors/binary-protocol-packets.json Protocol 1: byte-fixed base + round-trip
  reference-packets/*.bin                    raw bytes of the deterministic packets
  benchmarks/baseline.json                   primitive throughput baseline (this machine)

Determinism note:
  Transport and Protocol-1 *base* packets are a deterministic function of their
  inputs (HMAC-SHA256, fixed framing) -> byte-identical across languages, so they
  are stored as expected wire bytes ("byte_fixed").
  Compressed packets are NOT guaranteed byte-identical across DEFLATE encoders, and
  encrypted packets use a random AES-GCM nonce -> non-deterministic. Those are
  stored as "round-trip" cases (build -> decode -> expected plaintext) instead.
"""

import sys
import json
import time
from pathlib import Path

HERE = Path(__file__).resolve()
CANON = HERE.parents[2]                       # .../canonical
SRC = HERE.parents[1] / "src"                 # .../canonical/python/src
sys.path.insert(0, str(SRC))

from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import SimplePacketBuilder, TestConfig
from yx.primitives.data_compression import compress_data, decompress_data
from yx.primitives.data_crypto import compute_packet_hmac, encrypt_aes_gcm, decrypt_aes_gcm
from yx.primitives.data_chunking import chunk_data

GUID = TestConfig.test_guid()
KEY = TestConfig.test_key()


def _transport_case(name, payload):
    packet = PacketBuilder.build_packet(GUID, payload, KEY)
    return {
        "name": name,
        "guid": GUID.hex(),
        "key": KEY.hex(),
        "payload_hex": payload.hex(),
        "expected_hmac": packet.hmac.hex(),
        "expected_packet": packet.to_bytes().hex(),
    }


def transport_vectors():
    return {
        "version": "1.0.0",
        "protocol": "YX Transport (HMAC + GUID + payload)",
        "byte_fixed": True,
        "test_cases": [
            _transport_case("Simple payload", b"test payload"),
            _transport_case("Empty payload", b""),
            _transport_case("Large payload (7000 bytes)", b"X" * 7000),
        ],
    }


def _binary_base_case(name, payload, chunk_size=1024):
    packets = SimplePacketBuilder.build_binary_packet(
        payload, GUID, KEY, proto_opts=0x00, channel_id=0, sequence=0, chunk_size=chunk_size)
    return {
        "name": name,
        "guid": GUID.hex(),
        "key": KEY.hex(),
        "proto_opts": 0,
        "channel_id": 0,
        "sequence": 0,
        "chunk_size": chunk_size,
        "payload_hex": payload.hex(),
        "expected_packets": [p.hex() for p in packets],
    }


def _binary_roundtrip_case(name, payload, proto_opts):
    return {
        "name": name,
        "guid": GUID.hex(),
        "key": KEY.hex(),
        "proto_opts": proto_opts,
        "channel_id": 0,
        "sequence": 0,
        "chunk_size": 1024,
        "payload_hex": payload.hex(),
        "expected_plaintext_hex": payload.hex(),
    }


def binary_vectors():
    return {
        "version": "1.0.0",
        "protocol": "YX Protocol 1 (Binary/Chunked)",
        "note": (
            "byte_fixed packets are deterministic and byte-identical across languages; "
            "round_trip cases (compressed/encrypted) are not byte-deterministic "
            "(DEFLATE encoding is not canonical; AES-GCM uses a random nonce) and are "
            "validated by decoding to expected_plaintext_hex."
        ),
        "byte_fixed": [
            _binary_base_case("Base, single chunk", b"small binary payload"),
            _binary_base_case("Base, multi-chunk (2500 bytes -> 3 chunks)", b"B" * 2500),
        ],
        "round_trip": [
            _binary_roundtrip_case("Compressed", b"Hello, World! " * 100, 0x01),
            _binary_roundtrip_case("Encrypted", b"secret binary payload " * 8, 0x02),
            _binary_roundtrip_case("Compressed + Encrypted", b"Hello, World! " * 100, 0x03),
        ],
    }


def write_reference_packets(ref_dir, transport, binary):
    ref_dir.mkdir(parents=True, exist_ok=True)
    written = []
    name_map = {
        "Simple payload": "transport-simple.bin",
        "Empty payload": "transport-empty.bin",
        "Large payload (7000 bytes)": "transport-large.bin",
    }
    for tc in transport["test_cases"]:
        fn = name_map.get(tc["name"])
        if fn:
            (ref_dir / fn).write_bytes(bytes.fromhex(tc["expected_packet"]))
            written.append(fn)
    # Protocol 1 base, single chunk -> one .bin
    base = binary["byte_fixed"][0]
    (ref_dir / "proto1-base-chunk0.bin").write_bytes(bytes.fromhex(base["expected_packets"][0]))
    written.append("proto1-base-chunk0.bin")
    return written


def _rate(n, seconds):
    return round(n / seconds) if seconds > 0 else 0


def benchmarks():
    payload = b"x" * 256
    big = b"Hello, World! " * 100  # compressible

    def timed(fn, iters):
        t0 = time.perf_counter()
        for _ in range(iters):
            fn()
        return time.perf_counter() - t0

    hmac_iters = 50000
    t = timed(lambda: compute_packet_hmac(GUID, payload, KEY), hmac_iters)
    hmac_rate = _rate(hmac_iters, t)

    pkt_iters = 50000
    t = timed(lambda: PacketBuilder.build_and_serialize(GUID, payload, KEY), pkt_iters)
    pkt_rate = _rate(pkt_iters, t)

    comp_iters = 20000
    t = timed(lambda: compress_data(big), comp_iters)
    comp_rate = _rate(comp_iters, t)

    enc_iters = 20000
    t = timed(lambda: encrypt_aes_gcm(payload, KEY), enc_iters)
    enc_rate = _rate(enc_iters, t)

    chunk_iters = 50000
    big_chunkable = b"Y" * 4096
    t = timed(lambda: chunk_data(big_chunkable, 1024), chunk_iters)
    chunk_rate = _rate(chunk_iters, t)

    return {
        "version": "1.0.0",
        "note": "Baseline throughput on the generating machine; for regression tracking, not a pass/fail vector.",
        "python": sys.version.split()[0],
        "metrics_ops_per_sec": {
            "compute_packet_hmac (256B)": hmac_rate,
            "build_and_serialize (256B)": pkt_rate,
            "compress_data (1400B compressible)": comp_rate,
            "encrypt_aes_gcm (256B)": enc_rate,
            "chunk_data (4096B @1024)": chunk_rate,
        },
    }


def _self_check(transport, binary):
    """Fail loudly if anything is non-deterministic or a round-trip breaks."""
    # byte-fixed transport reproduce exactly
    for tc in transport["test_cases"]:
        again = PacketBuilder.build_packet(GUID, bytes.fromhex(tc["payload_hex"]), KEY).to_bytes().hex()
        assert again == tc["expected_packet"], f"transport non-deterministic: {tc['name']}"
    # byte-fixed binary base reproduce exactly
    for tc in binary["byte_fixed"]:
        again = [p.hex() for p in SimplePacketBuilder.build_binary_packet(
            bytes.fromhex(tc["payload_hex"]), GUID, KEY,
            proto_opts=0, channel_id=0, sequence=0, chunk_size=tc["chunk_size"])]
        assert again == tc["expected_packets"], f"binary base non-deterministic: {tc['name']}"
    # round-trip cases decode back to plaintext
    for tc in binary["round_trip"]:
        payload = bytes.fromhex(tc["payload_hex"])
        packets = SimplePacketBuilder.build_binary_packet(
            payload, GUID, KEY, proto_opts=tc["proto_opts"], chunk_size=tc["chunk_size"])
        data = b"".join(PacketBuilder.parse_packet(p).payload[16:] for p in packets)
        if tc["proto_opts"] & 0x02:
            data = decrypt_aes_gcm(data[:12], data[12:], KEY)
        if tc["proto_opts"] & 0x01:
            data = decompress_data(data)
        assert data == payload, f"round-trip failed: {tc['name']}"


def main():
    tv_dir = CANON / "test-vectors"
    ref_dir = CANON / "reference-packets"
    bench_dir = CANON / "benchmarks"
    tv_dir.mkdir(parents=True, exist_ok=True)
    bench_dir.mkdir(parents=True, exist_ok=True)

    transport = transport_vectors()
    binary = binary_vectors()

    _self_check(transport, binary)  # determinism + round-trip guards

    (tv_dir / "transport-packets.json").write_text(json.dumps(transport, indent=2))
    (tv_dir / "binary-protocol-packets.json").write_text(json.dumps(binary, indent=2))
    refs = write_reference_packets(ref_dir, transport, binary)
    (bench_dir / "baseline.json").write_text(json.dumps(benchmarks(), indent=2))

    print(f"✓ transport-packets.json: {len(transport['test_cases'])} byte-fixed vectors")
    print(f"✓ binary-protocol-packets.json: {len(binary['byte_fixed'])} byte-fixed + {len(binary['round_trip'])} round-trip")
    print(f"✓ reference-packets/: {len(refs)} raw packets ({', '.join(refs)})")
    print(f"✓ benchmarks/baseline.json written")


if __name__ == "__main__":
    main()
