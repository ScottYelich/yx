#!/usr/bin/env python3
"""
Protocol 1 test: Python to Python binary/chunked.

Tests all 4 protoOpts variants.

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Protocol 1 Tests)
"""

import sys
import asyncio
import argparse
import socket
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packets, TestConfig


async def run_scenario(proto_opts_hex: str) -> bool:
    proto_opts = int(proto_opts_hex, 16)
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()
    received = []

    async def on_message(data: bytes):
        received.append(data)

    original = b"Test data for Protocol 1 " * 20
    handler = BinaryProtocol(key=key, on_message=on_message)

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(1.0)
    receiver.bind()

    # Build and send
    packets = SimplePacketBuilder.build_binary_packet(
        original, guid, key, proto_opts=proto_opts
    )
    send_udp_packets(packets, "127.0.0.1", port)

    # Receive loop
    timeout = 3.0
    start = asyncio.get_event_loop().time()
    while asyncio.get_event_loop().time() - start < timeout:
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            await handler.handle(payload_r)
            if received:
                break
        except socket.timeout:
            pass
        except Exception:
            pass
        await asyncio.sleep(0.01)

    receiver.close()

    if received:
        assert received[0] == original
        return True
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proto-opts", required=True, choices=["0x00", "0x01", "0x02", "0x03"])
    args = parser.parse_args()
    success = asyncio.run(run_scenario(args.proto_opts))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
