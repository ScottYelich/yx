#!/usr/bin/env python3
"""
Protocol 0 test sender. Sends a JSON-RPC message.

Usage: python python_sender_proto0.py <message_json>

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Sender Interface)
"""

import sys
import json
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet, TestConfig


def main():
    message = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {"method": "test"}
    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()
    packet = SimplePacketBuilder.build_text_packet(message, guid, key)
    send_udp_packet(packet, "127.0.0.1", port)
    print(f"SENT: {message}")
    sys.exit(0)


if __name__ == "__main__":
    main()
