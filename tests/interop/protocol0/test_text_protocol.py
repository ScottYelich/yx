#!/usr/bin/env python3
"""
Protocol 0 test: Python to Python text/JSON-RPC.

Scenarios: json, large_json, unicode

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Protocol 0 Tests)
"""

import sys
import asyncio
import argparse
import socket
import json
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

    await asyncio.sleep(0.05)

    if scenario == "json":
        msg = {"method": "test.hello", "params": {"name": "TestSender"}, "id": 1}
        packet = SimplePacketBuilder.build_text_packet(msg, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            assert payload_r[0] == 0x00
            parsed = json.loads(payload_r[1:].decode('utf-8'))
            assert parsed == msg
            received.append(payload_r)
        except Exception:
            pass

    elif scenario == "large_json":
        msg = {"data": "A" * 10000, "id": 2}
        packet = SimplePacketBuilder.build_text_packet(msg, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            received.append(payload_r)
        except Exception:
            pass

    elif scenario == "unicode":
        msg = {"message": "Hello \u4e16\u754c \U0001f30d", "id": 3}
        packet = SimplePacketBuilder.build_text_packet(msg, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)
        try:
            guid_r, payload_r, addr = receiver.receive_packet(key)
            parsed = json.loads(payload_r[1:].decode('utf-8'))
            assert parsed == msg
            received.append(payload_r)
        except Exception:
            pass

    receiver.close()
    return len(received) == 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True, choices=["json", "large_json", "unicode"])
    args = parser.parse_args()
    success = asyncio.run(run_scenario(args.scenario))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
