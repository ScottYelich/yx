#!/usr/bin/env python3
"""
Protocol 0 test sender: invalid JSON (receiver must reject).

Sends a well-formed transport packet whose Protocol 0 payload ([0x00] + body)
contains malformed JSON. Mirrors the Swift `swift-sender-proto0-invalid`.

Traceability:
- specs/testing/interoperability-requirements.md (Sender Interface)
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../canonical/python/src'))

from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import TestConfig, send_udp_packet


def main():
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()

    payload = bytes([0x00]) + b"{invalid json}"
    packet = PacketBuilder.build_and_serialize(guid, payload, key)
    send_udp_packet(packet, "127.0.0.1", TestConfig.test_port())

    print("SENT")
    sys.exit(0)


if __name__ == "__main__":
    main()
