"""Test GUID generation and encoding"""

from yx.primitives.guid import GUIDFactory, guid_to_hex, hex_to_guid


def test_guid_generation():
    """Test GUID generation produces 6 bytes"""
    guid = GUIDFactory.generate()
    assert len(guid) == 6
    assert isinstance(guid, bytes)


def test_guid_uniqueness():
    """Test that generated GUIDs are unique"""
    guid1 = GUIDFactory.generate()
    guid2 = GUIDFactory.generate()
    assert guid1 != guid2


def test_guid_padding():
    """Test GUID padding to 6 bytes"""
    short_guid = b'\x01\x02\x03'
    padded = GUIDFactory.pad_guid(short_guid)
    assert len(padded) == 6
    assert padded == b'\x01\x02\x03\x00\x00\x00'


def test_guid_padding_exact():
    """Test GUID padding with exact 6 bytes"""
    exact_guid = b'\x01\x02\x03\x04\x05\x06'
    padded = GUIDFactory.pad_guid(exact_guid)
    assert len(padded) == 6
    assert padded == exact_guid


def test_guid_padding_too_long():
    """Test GUID padding truncates when too long"""
    long_guid = b'\x01\x02\x03\x04\x05\x06\x07\x08'
    padded = GUIDFactory.pad_guid(long_guid)
    assert len(padded) == 6
    assert padded == b'\x01\x02\x03\x04\x05\x06'


def test_guid_hex_encoding():
    """Test GUID to hex conversion"""
    guid = b'\x01\x02\x03\x04\x05\x06'
    hex_str = guid_to_hex(guid)
    assert hex_str == "010203040506"


def test_hex_to_guid():
    """Test hex to GUID conversion"""
    hex_str = "010203040506"
    guid = hex_to_guid(hex_str)
    assert guid == b'\x01\x02\x03\x04\x05\x06'


def test_hex_round_trip():
    """Test hex encoding/decoding round trip"""
    original = GUIDFactory.generate()
    hex_str = guid_to_hex(original)
    decoded = hex_to_guid(hex_str)
    assert original == decoded
