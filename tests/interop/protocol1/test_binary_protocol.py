#!/usr/bin/env python3
"""
Protocol 1 (binary/chunked) test: Python → Python.

Tests all protoOpts variants:
- 0x00: Base (no compression/encryption)
- 0x01: Compressed
- 0x02: Encrypted
- 0x03: Compressed + Encrypted

Traceability:
- specs/testing/interoperability-requirements.md (Protocol 1 Tests)
- specs/architecture/protocol-layers.md (Protocol 1 Specification)
"""

import sys
import asyncio
import argparse
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../canonical/python/src'))

from yx.transport.binary_protocol import BinaryProtocol
from yx.transport.udp_socket import UDPSocket
from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packets,
    TestConfig
)


received_messages = []


async def on_message(data: bytes):
    """Callback for received message."""
    received_messages.append(data)


async def test_scenario(proto_opts: int):
    """
    Run Protocol 1 test with specified protoOpts.

    Args:
        proto_opts: 0x00 (base), 0x01 (compressed), 0x02 (encrypted), 0x03 (both)
    """
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    # Clear received messages
    received_messages.clear()

    # Create test data
    test_data = b"Hello, World! " * 100  # ~1400 bytes

    # Create binary protocol handler
    handler = BinaryProtocol(key=key, on_message=on_message)

    # Start receiver
    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.bind()
    receiver.socket.setblocking(False)

    # Get event loop
    loop = asyncio.get_event_loop()

    async def receive_task():
        try:
            timeout = 5.0
            start = loop.time()

            while loop.time() - start < timeout:
                try:
                    # Use loop.sock_recv for async socket reading
                    data = await asyncio.wait_for(
                        loop.sock_recv(receiver.socket, 65507),
                        timeout=1.0
                    )

                    # Get the address - we need to parse it from the data
                    # For loopback, we can skip HMAC validation in handler
                    packet = PacketBuilder.parse_packet(data)

                    if not PacketBuilder.validate_hmac(packet, key):
                        continue

                    # Handle with binary protocol
                    await handler.handle(packet.payload)

                    # If we received complete message, exit
                    if received_messages:
                        break

                except asyncio.TimeoutError:
                    continue
                except Exception:
                    continue

        except Exception as e:
            print(f"Receive error: {e}")

    # Start receive task
    recv_task = asyncio.create_task(receive_task())

    # Build and send packets
    await asyncio.sleep(0.1)  # Let receiver bind

    packets = SimplePacketBuilder.build_binary_packet(
        test_data, guid, key,
        proto_opts=proto_opts,
        channel_id=0,
        sequence=0
    )

    send_udp_packets(packets, "127.0.0.1", port)

    # Wait for receive
    await asyncio.wait_for(recv_task, timeout=5.0)
    receiver.close()

    # Validate
    if len(received_messages) == 0:
        return False

    # Verify received data matches sent data
    return received_messages[0] == test_data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proto-opts", required=True,
                       help="protoOpts value: 0x00, 0x01, 0x02, or 0x03")
    args = parser.parse_args()

    # Parse proto_opts
    proto_opts_str = args.proto_opts.lower()
    if proto_opts_str.startswith("0x"):
        proto_opts = int(proto_opts_str, 16)
    else:
        proto_opts = int(proto_opts_str)

    if proto_opts not in [0x00, 0x01, 0x02, 0x03]:
        print(f"Invalid proto-opts: {args.proto_opts}")
        sys.exit(1)

    success = asyncio.run(test_scenario(proto_opts))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
