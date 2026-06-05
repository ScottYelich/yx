#!/usr/bin/env python3
"""
Transport-layer test receiver (raw HMAC packet, no protocol byte).

Waits for one packet, validates the transport HMAC, and exits 0 on success or
1 on invalid/timeout. Mirrors the Swift `swift-receiver-transport` program.

Traceability:
- specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../canonical/python/src'))

from yx.transport.packet_builder import PacketBuilder
from yx.transport.udp_socket import UDPSocket
from yx.primitives.test_helpers import TestConfig


def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.bind()
    receiver.socket.settimeout(10.0)

    try:
        data, addr = receiver.socket.recvfrom(65507)
        packet = PacketBuilder.parse_packet(data)
        if packet is None or not PacketBuilder.validate_hmac(packet, key):
            print("ERROR: Invalid HMAC")
            sys.exit(1)
        print(f"RECEIVED: {len(packet.payload)} bytes")
        sys.exit(0)
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)
    finally:
        receiver.close()


if __name__ == "__main__":
    main()
