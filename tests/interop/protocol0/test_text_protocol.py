#!/usr/bin/env python3
"""
Protocol 0 (text/JSON-RPC) test: Python → Python.

Traceability:
- specs/testing/interoperability-requirements.md (Protocol 0 Tests)
- specs/architecture/protocol-layers.md (Protocol 0 Specification)
"""

import sys
import time
import argparse
import json
import os
import threading

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../canonical/python/src'))

from yx.transport.udp_socket import UDPSocket
from yx.transport.packet_builder import PacketBuilder
from yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packet,
    TestConfig
)


def test_scenario(scenario: str):
    """
    Run Protocol 0 test scenario.

    Scenarios:
    - json: Valid JSON-RPC message
    - large_json: Large JSON message (>5KB)
    - invalid_json: Malformed JSON (should fail)
    """
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    received = []
    errors = []

    # Start receiver
    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.bind()
    receiver.socket.settimeout(3.0)

    def receive_task():
        try:
            data, addr = receiver.socket.recvfrom(65507)
            packet = PacketBuilder.parse_packet(data)

            if not PacketBuilder.validate_hmac(packet, key):
                errors.append("HMAC validation failed")
                return

            # Verify Protocol 0
            if packet.payload[0] != 0x00:
                errors.append(f"Expected Protocol 0, got 0x{packet.payload[0]:02x}")
                return

            # Try to parse JSON
            json_bytes = packet.payload[1:]
            try:
                message = json.loads(json_bytes.decode('utf-8'))
                received.append(message)
            except Exception as e:
                errors.append(f"JSON parse error: {e}")
        except Exception as e:
            errors.append(f"Receive error: {e}")

    # Start receiver thread
    recv_thread = threading.Thread(target=receive_task)
    recv_thread.start()

    # Send based on scenario
    time.sleep(0.1)  # Let receiver bind

    if scenario == "json":
        message = {
            "jsonrpc": "2.0",
            "method": "test.echo",
            "params": {"value": "hello"},
            "id": 1
        }
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "large_json":
        # Create a large JSON object (>5KB)
        message = {
            "jsonrpc": "2.0",
            "method": "test.largeData",
            "params": {
                "data": "X" * 5000
            },
            "id": 2
        }
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "invalid_json":
        # Send malformed JSON (missing closing brace)
        malformed_json = b'{"jsonrpc": "2.0", "method": "test"'

        # Build packet manually with Protocol 0 marker + malformed JSON
        builder = PacketBuilder()
        payload = bytes([0x00]) + malformed_json  # 0x00 = Protocol 0
        packet = builder.build_packet(guid, payload, key)
        send_udp_packet(packet.to_bytes(), "127.0.0.1", port)

    # Wait for receive
    recv_thread.join()
    receiver.close()

    # Validate results
    if scenario == "invalid_json":
        # Should have error parsing JSON
        return len(errors) > 0 and "JSON parse error" in errors[0]

    if scenario in ["json", "large_json"]:
        # Should successfully receive and parse
        return len(received) == 1 and len(errors) == 0

    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True,
                       choices=["json", "large_json", "invalid_json"])
    args = parser.parse_args()

    success = test_scenario(args.scenario)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
