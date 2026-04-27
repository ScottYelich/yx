#!/usr/bin/env python3
"""
Protocol 1 (binary) test receiver.

Supports all protoOpts variants.

Traceability:
- specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import sys
import asyncio
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../builds/python-impl/src'))

from yx.transport.binary_protocol import BinaryProtocol
from yx.transport.udp_socket import UDPSocket
from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import TestConfig


received_data = []


async def on_message(data: bytes):
    """Callback for received message."""
    received_data.append(data)


async def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    # Create binary protocol handler
    handler = BinaryProtocol(key=key, on_message=on_message)

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.bind()

    # Set timeout on the socket
    receiver.socket.settimeout(1.0)

    try:
        # Wait for packets (5s timeout, may be multiple chunks)
        timeout = 5.0
        start = asyncio.get_event_loop().time()

        while asyncio.get_event_loop().time() - start < timeout:
            try:
                data, addr = receiver.socket.recvfrom(65507)

                # Parse packet
                packet = PacketBuilder.parse_packet(data)

                # Validate HMAC
                if not PacketBuilder.validate_hmac(packet, key):
                    continue  # Skip invalid packets

                # Handle with binary protocol
                await handler.handle(packet.payload)

                # If we received complete message, exit
                if received_data:
                    break

            except Exception:
                continue  # Timeout, keep waiting

        if received_data:
            print(f"RECEIVED: {len(received_data[0])} bytes")
            sys.exit(0)  # Success
        else:
            print("FAILED: Timeout waiting for message")
            sys.exit(1)

    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)
    finally:
        receiver.close()


if __name__ == "__main__":
    asyncio.run(main())
