#!/usr/bin/env python3
"""
HMAC Verification Test

Verifies HMAC-SHA256 implementation matches Swift version.
"""

import sys
from yx.primitives.guid import GUIDFactory, guid_to_hex
from yx.primitives.data_crypto import generate_key, compute_hmac
from yx.transport.packet_builder import PacketBuilder
from yx.transport.packet import Packet


def test_hmac_basic():
    """Test basic HMAC computation"""
    print("=" * 60)
    print("Test 1: Basic HMAC Computation")
    print("=" * 60)

    # Test data
    data = b"Hello, World!"
    key = b"0" * 32  # Simple test key

    # Compute HMAC
    hmac = compute_hmac(data, key, truncate_to=16)

    print(f"Data: {data}")
    print(f"Key: {key.hex().upper()}")
    print(f"HMAC (16 bytes): {hmac.hex().upper()}")
    print(f"HMAC length: {len(hmac)} bytes")

    assert len(hmac) == 16, "HMAC should be 16 bytes"
    print("✅ HMAC is 16 bytes\n")


def test_hmac_deterministic():
    """Test HMAC is deterministic"""
    print("=" * 60)
    print("Test 2: HMAC Determinism")
    print("=" * 60)

    data = b"Test message"
    key = generate_key()

    hmac1 = compute_hmac(data, key)
    hmac2 = compute_hmac(data, key)

    print(f"HMAC 1: {hmac1.hex().upper()}")
    print(f"HMAC 2: {hmac2.hex().upper()}")
    print(f"Equal: {hmac1 == hmac2}")

    assert hmac1 == hmac2, "HMAC should be deterministic"
    print("✅ HMAC is deterministic\n")


def test_packet_hmac():
    """Test HMAC in packet building"""
    print("=" * 60)
    print("Test 3: Packet HMAC Integration")
    print("=" * 60)

    # Generate GUID and key
    guid = GUIDFactory.generate()
    key = generate_key()
    payload = b"Test packet payload"

    print(f"GUID: {guid_to_hex(guid)}")
    print(f"Key: {key.hex().upper()}")
    print(f"Payload: {payload}")
    print()

    # Build packet
    packet = PacketBuilder.build_packet(guid, payload, key)

    print(f"Packet HMAC: {packet.hmac.hex().upper()}")
    print(f"Packet GUID: {packet.guid.hex().upper()}")
    print(f"Packet Payload: {packet.payload}")
    print()

    # Verify HMAC manually
    hmac_input = packet.guid + packet.payload
    expected_hmac = compute_hmac(hmac_input, key, truncate_to=16)

    print(f"Expected HMAC: {expected_hmac.hex().upper()}")
    print(f"Actual HMAC:   {packet.hmac.hex().upper()}")
    print(f"Match: {packet.hmac == expected_hmac}")

    assert packet.hmac == expected_hmac, "Packet HMAC should match computed HMAC"
    print("✅ Packet HMAC matches expected value\n")


def test_hmac_validation():
    """Test HMAC validation"""
    print("=" * 60)
    print("Test 4: HMAC Validation")
    print("=" * 60)

    guid = GUIDFactory.generate()
    key = generate_key()
    payload = b"Validation test"

    # Build packet
    packet = PacketBuilder.build_packet(guid, payload, key)

    # Validate with correct key
    valid = PacketBuilder.validate_hmac(packet, key)
    print(f"Validation with correct key: {valid}")
    assert valid, "HMAC should validate with correct key"
    print("✅ HMAC validates with correct key")

    # Validate with wrong key
    wrong_key = generate_key()
    invalid = PacketBuilder.validate_hmac(packet, wrong_key)
    print(f"Validation with wrong key: {invalid}")
    assert not invalid, "HMAC should NOT validate with wrong key"
    print("✅ HMAC rejects wrong key\n")


def test_hmac_tampering():
    """Test HMAC detects tampering"""
    print("=" * 60)
    print("Test 5: Tampering Detection")
    print("=" * 60)

    guid = GUIDFactory.generate()
    key = generate_key()
    payload = b"Original payload"

    # Build packet
    packet = PacketBuilder.build_packet(guid, payload, key)
    original_valid = PacketBuilder.validate_hmac(packet, key)
    print(f"Original packet validates: {original_valid}")
    assert original_valid

    # Tamper with payload
    tampered_packet = Packet(
        hmac=packet.hmac,
        guid=packet.guid,
        payload=b"Tampered payload"
    )
    tampered_valid = PacketBuilder.validate_hmac(tampered_packet, key)
    print(f"Tampered packet validates: {tampered_valid}")
    assert not tampered_valid, "Tampered packet should NOT validate"
    print("✅ HMAC detects payload tampering")

    # Tamper with GUID
    tampered_guid_packet = Packet(
        hmac=packet.hmac,
        guid=GUIDFactory.generate(),
        payload=packet.payload
    )
    guid_tampered_valid = PacketBuilder.validate_hmac(tampered_guid_packet, key)
    print(f"Tampered GUID validates: {guid_tampered_valid}")
    assert not guid_tampered_valid, "Tampered GUID should NOT validate"
    print("✅ HMAC detects GUID tampering\n")


def test_round_trip():
    """Test packet serialization round trip with HMAC"""
    print("=" * 60)
    print("Test 6: Serialization Round Trip")
    print("=" * 60)

    guid = GUIDFactory.generate()
    key = generate_key()
    payload = b"Round trip test payload"

    # Build packet
    original_packet = PacketBuilder.build_packet(guid, payload, key)
    print(f"Original HMAC: {original_packet.hmac.hex().upper()}")

    # Serialize
    serialized = original_packet.to_bytes()
    print(f"Serialized length: {len(serialized)} bytes")

    # Parse
    parsed_packet = PacketBuilder.parse_packet(serialized)
    assert parsed_packet is not None, "Packet should parse"
    print(f"Parsed HMAC: {parsed_packet.hmac.hex().upper()}")

    # Validate
    valid = PacketBuilder.validate_hmac(parsed_packet, key)
    print(f"Parsed packet validates: {valid}")
    assert valid, "Parsed packet should validate"

    # Check all fields match
    assert parsed_packet.hmac == original_packet.hmac
    assert parsed_packet.guid == original_packet.guid
    assert parsed_packet.payload == original_packet.payload
    print("✅ Round trip preserves HMAC and all fields\n")


def main():
    """Run all HMAC verification tests"""
    print("\n")
    print("🔐 YX Framework - HMAC Verification Suite")
    print("=" * 60)
    print()

    try:
        test_hmac_basic()
        test_hmac_deterministic()
        test_packet_hmac()
        test_hmac_validation()
        test_hmac_tampering()
        test_round_trip()

        print("=" * 60)
        print("🎉 All HMAC tests passed!")
        print("=" * 60)
        print()
        print("Summary:")
        print("  ✅ HMAC computes 16-byte truncated SHA256")
        print("  ✅ HMAC is deterministic")
        print("  ✅ Packet HMAC integration works")
        print("  ✅ HMAC validates with correct key")
        print("  ✅ HMAC rejects wrong key")
        print("  ✅ HMAC detects payload tampering")
        print("  ✅ HMAC detects GUID tampering")
        print("  ✅ Round trip serialization preserves HMAC")
        print()

        return 0

    except AssertionError as e:
        print(f"\n❌ Test failed: {e}")
        return 1
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
