#!/usr/bin/env python3
"""
Transport-layer test sender (raw HMAC packet, no protocol byte).

Usage: python_sender_transport.py <scenario>
  scenarios: simple | empty | large | multiple | invalid

Mirrors the Swift `swift-sender-transport-*` programs so the byte layout
([HMAC(16)] + [GUID(6)] + [payload]) is identical across languages.

Traceability:
- specs/testing/interoperability-requirements.md (Sender Interface)
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../canonical/python/src'))

from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import TestConfig, send_udp_packet


def main():
    scenario = sys.argv[1] if len(sys.argv) > 1 else "simple"
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    host = "127.0.0.1"
    port = TestConfig.test_port()

    if scenario == "simple":
        payloads = [b"Hello from Python"]
        send_key = key
    elif scenario == "empty":
        payloads = [b""]
        send_key = key
    elif scenario == "large":
        # ~7KB: spec >=5KB single datagram, under macOS udp.maxdgram (9216).
        payloads = [b"X" * 7000]
        send_key = key
    elif scenario == "multiple":
        payloads = [f"Message {i}".encode() for i in range(5)]
        send_key = key
    elif scenario == "invalid":
        # Sign with the wrong key so the receiver must reject the packet.
        payloads = [b"Invalid packet"]
        send_key = bytes([0xFF] * 32)
    else:
        print(f"Unknown scenario: {scenario}")
        sys.exit(1)

    for payload in payloads:
        packet = PacketBuilder.build_and_serialize(guid, payload, send_key)
        send_udp_packet(packet, host, port)

    print("SENT")
    sys.exit(0)


if __name__ == "__main__":
    main()
