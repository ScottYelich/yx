#!/usr/bin/env python3
"""
Protocol 0 (text) test receiver.

Waits for Protocol 0 message, validates, exits with success.

Traceability:
- specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import sys
import json
import asyncio
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../builds/python-impl/src'))

from yx.transport.udp_socket import UDPSocket
from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import TestConfig


async def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.bind()

    # Set timeout on the socket
    receiver.socket.settimeout(5.0)

    try:
        # Wait for packet (5s timeout)
        data, addr = receiver.socket.recvfrom(65507)

        # Parse packet
        packet = PacketBuilder.parse_packet(data)

        # Validate HMAC
        if not PacketBuilder.validate_hmac(packet, key):
            print("FAILED: HMAC validation failed")
            sys.exit(1)

        # Verify Protocol 0
        if packet.payload[0] != 0x00:
            print(f"FAILED: Expected Protocol 0, got 0x{packet.payload[0]:02x}")
            sys.exit(1)

        # Parse JSON
        json_bytes = packet.payload[1:]
        message = json.loads(json_bytes.decode('utf-8'))

        print(f"RECEIVED: {message}")
        sys.exit(0)  # Success

    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)
    finally:
        receiver.close()


if __name__ == "__main__":
    asyncio.run(main())
