"""Generate canonical test vectors for cross-implementation validation."""

import json
from pathlib import Path
from yx.transport import PacketBuilder
from yx.primitives import GUIDFactory


def generate_test_vectors():
    """Generate JSON test vectors."""
    vectors = {
        "version": "1.0.0",
        "protocol": "YX UDP Protocol",
        "test_cases": []
    }

    # Test case 1: Simple packet
    key = b'\x00' * 32
    guid = b'\x01' * 6
    payload = b'test payload'

    packet = PacketBuilder.build_packet(guid, payload, key)
    data = packet.to_bytes()

    vectors["test_cases"].append({
        "name": "Simple text payload",
        "guid": guid.hex(),
        "key": key.hex(),
        "payload": payload.decode('ascii'),
        "payload_hex": payload.hex(),
        "expected_hmac": packet.hmac.hex(),
        "expected_packet": data.hex(),
    })

    # Test case 2: Empty payload
    payload2 = b''
    packet2 = PacketBuilder.build_packet(guid, payload2, key)
    data2 = packet2.to_bytes()

    vectors["test_cases"].append({
        "name": "Empty payload",
        "guid": guid.hex(),
        "key": key.hex(),
        "payload": "",
        "payload_hex": "",
        "expected_hmac": packet2.hmac.hex(),
        "expected_packet": data2.hex(),
    })

    # Test case 3: Large payload
    payload3 = b'X' * 1000
    packet3 = PacketBuilder.build_packet(guid, payload3, key)
    data3 = packet3.to_bytes()

    vectors["test_cases"].append({
        "name": "Large payload (1000 bytes)",
        "guid": guid.hex(),
        "key": key.hex(),
        "payload_hex": payload3.hex(),
        "expected_hmac": packet3.hmac.hex(),
        "expected_packet": data3.hex(),
    })

    return vectors


def main():
    """Generate and save canonical artifacts."""
    # Ensure canonical directory exists
    canonical_dir = Path("../../canonical/test-vectors")
    canonical_dir.mkdir(parents=True, exist_ok=True)

    # Generate test vectors
    vectors = generate_test_vectors()

    # Save to JSON
    output_file = canonical_dir / "text-protocol-packets.json"
    with open(output_file, 'w') as f:
        json.dump(vectors, f, indent=2)

    print(f"✓ Generated {len(vectors['test_cases'])} test vectors")
    print(f"✓ Saved to {output_file}")


if __name__ == "__main__":
    main()
