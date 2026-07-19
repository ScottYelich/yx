#!/usr/bin/env python3
"""Protocol 1 compressed sender (protoOpts=0x01)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


def main():
    data = bytes.fromhex(sys.argv[1]) if len(sys.argv) > 1 else b"hello" * 100
    packets = SimplePacketBuilder.build_binary_packet(
        data, TestConfig.test_guid(), TestConfig.test_key(),
        proto_opts=0x01, channel_id=0, sequence=0
    )
    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes compressed ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
