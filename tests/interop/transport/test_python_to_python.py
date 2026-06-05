#!/usr/bin/env python3
"""
Transport layer test: Python → Python.

Traceability:
- specs/testing/interoperability-requirements.md (Transport Tests)
"""

import sys
import time
import argparse
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
    Run transport layer test scenario.

    Scenarios:
    - simple: Small payload
    - empty: Empty payload
    - large: Large payload (5KB)
    - multiple: 10 packets sequentially
    - invalid_key: Wrong key (should fail)
    """
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    received = []

    # Start receiver
    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.bind()
    receiver.socket.settimeout(3.0)

    def receive_task():
        try:
            for _ in range(10):  # Multiple packets for 'multiple' scenario
                data, addr = receiver.socket.recvfrom(65507)
                packet = PacketBuilder.parse_packet(data)
                if PacketBuilder.validate_hmac(packet, key):
                    received.append(packet.payload)
                if scenario != "multiple":
                    break
        except Exception:
            pass

    # Start receiver thread
    recv_thread = threading.Thread(target=receive_task)
    recv_thread.start()

    # Send based on scenario
    time.sleep(0.1)  # Let receiver bind

    if scenario == "simple":
        message = {"test": "simple"}
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "empty":
        message = {}
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "large":
        message = {"data": "X" * 5000}
        packet = SimplePacketBuilder.build_text_packet(message, guid, key)
        send_udp_packet(packet, "127.0.0.1", port)

    elif scenario == "multiple":
        for i in range(10):
            message = {"seq": i}
            packet = SimplePacketBuilder.build_text_packet(message, guid, key)
            send_udp_packet(packet, "127.0.0.1", port)
            time.sleep(0.01)

    elif scenario == "invalid_key":
        wrong_key = bytes(32)  # All zeros (same as test key - need different key
        wrong_key = bytes([0xFF] * 32)  # All 0xFF (different from test key)
        message = {"test": "invalid"}
        packet = SimplePacketBuilder.build_text_packet(message, guid, wrong_key)
        send_udp_packet(packet, "127.0.0.1", port)

    # Wait for receives
    recv_thread.join()
    receiver.close()

    # Validate
    if scenario == "invalid_key":
        if len(received) == 0:
            return True  # Success: invalid key rejected
        return False

    if scenario == "multiple":
        return len(received) == 10

    return len(received) >= 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True,
                       choices=["simple", "empty", "large", "multiple", "invalid_key"])
    args = parser.parse_args()

    success = test_scenario(args.scenario)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
