#!/usr/bin/env python3
"""
Protocol 1 (encrypted) test sender.

Usage: python_sender_proto1_encrypted.py <data_hex>

Traceability:
- specs/testing/interoperability-requirements.md (Sender Interface)
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../canonical/python/src'))

from yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packets,
    TestConfig
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python_sender_proto1_encrypted.py <data_hex>")
        sys.exit(1)

    data = bytes.fromhex(sys.argv[1])

    packets = SimplePacketBuilder.build_binary_packet(
        data,
        TestConfig.test_guid(),
        TestConfig.test_key(),
        proto_opts=0x02,  # Encrypted
        channel_id=0,
        sequence=0
    )

    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes (encrypted, {len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
