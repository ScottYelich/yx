#!/usr/bin/env python3
"""Protocol 1 encrypted sender (protoOpts=0x02)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


def main():
    data = bytes.fromhex(sys.argv[1]) if len(sys.argv) > 1 else b"secret"
    packets = SimplePacketBuilder.build_binary_packet(
        data, TestConfig.test_guid(), TestConfig.test_key(),
        proto_opts=0x02, channel_id=0, sequence=0
    )
    send_udp_packets(packets, "127.0.0.1", TestConfig.test_port())
    print(f"SENT: {len(data)} bytes encrypted ({len(packets)} packets)")
    sys.exit(0)


if __name__ == "__main__":
    main()
