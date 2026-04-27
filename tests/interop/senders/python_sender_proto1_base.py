#!/usr/bin/env python3
"""
Protocol 1 (binary, base) test sender.

Usage: python_sender_proto1_base.py <data_hex>

Traceability:
- specs/testing/interoperability-requirements.md (Sender Interface)
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../builds/python-impl/src'))

from yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packets,
    TestConfig
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python_sender_proto1_base.py <data_hex>")
        sys.exit(1)

    data_hex = sys.argv[1]
    data = bytes.fromhex(data_hex)

    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    # Build packets (protoOpts = 0x00, no compression/encryption)
    packets = SimplePacketBuilder.build_binary_packet(
        data, guid, key,
        proto_opts=0x00,
        channel_id=0,
        sequence=0
    )

    # Send
    send_udp_packets(packets, "127.0.0.1", port)

    print(f"SENT: {len(data)} bytes ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
