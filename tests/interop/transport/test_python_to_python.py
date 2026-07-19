#!/usr/bin/env python3
"""
Transport layer test: Python to Python.

Tests 5 scenarios:
- simple: basic payload
- empty: empty JSON
- large: large payload
- multiple: 10 sequential packets
- invalid_key: wrong key (must be rejected)

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Transport Tests)
"""

import sys
import asyncio
import argparse
import socket
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig


async def run_scenario(scenario: str) -> bool:
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()
    received = []

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(2.0)
    receiver.bind()

    async def recv_loop(n: int):
        for _ in range(n):
            try:
                guid_r, payload_r, addr = receiver.receive_packet(key)
                received.append(payload_r)
            except socket.timeout:
                break
            except Exception:
                break

    await asyncio.sleep(0.05)

    if scenario == "simple":
        packet = SimplePacketBuilder.build_text_packet({"test": "simple"}, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 1

    elif scenario == "empty":
        packet = SimplePacketBuilder.build_text_packet({}, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 1

    elif scenario == "large":
        packet = SimplePacketBuilder.build_text_packet({"data": "X" * 5000}, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 1

    elif scenario == "multiple":
        for i in range(10):
            packet = SimplePacketBuilder.build_text_packet({"seq": i}, guid, key)
            send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(10)
        result = len(received) == 10

    elif scenario == "invalid_key":
        wrong_key = bytes([0xFF] * 32)
        packet = SimplePacketBuilder.build_text_packet({"test": "bad"}, guid, wrong_key)
        send_udp_packet(packet, "127.0.0.1", port)
        await recv_loop(1)
        result = len(received) == 0  # Must be rejected

    else:
        result = False

    receiver.close()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True,
                        choices=["simple", "empty", "large", "multiple", "invalid_key"])
    args = parser.parse_args()
    success = asyncio.run(run_scenario(args.scenario))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
