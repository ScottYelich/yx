from yx.primitives.guid_factory import guid_to_hex


def test_guid_to_hex():
    guid = bytes([0xE3, 0x2E, 0x3C, 0xA7, 0x02, 0xDE])
    assert guid_to_hex(guid) == "E32E3CA702DE"
    assert guid_to_hex(b'\x00' * 6) == "000000000000"
