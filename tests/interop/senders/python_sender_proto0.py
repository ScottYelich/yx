#!/usr/bin/env python3
"""
Protocol 0 (text) test sender.

Usage: python_sender_proto0.py <message_json>

Traceability:
- specs/testing/interoperability-requirements.md (Sender Interface)
"""

import sys
import json
import os

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../canonical/python/src'))

from yx.primitives.test_helpers import (
    SimplePacketBuilder,
    send_udp_packet,
    TestConfig
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python_sender_proto0.py <message_json>")
        sys.exit(1)

    message_json = sys.argv[1]
    message = json.loads(message_json)

    guid = TestConfig.test_guid()
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    # Build packet
    packet = SimplePacketBuilder.build_text_packet(message, guid, key)

    # Send
    send_udp_packet(packet, "127.0.0.1", port)

    print(f"SENT: {message}")
    sys.exit(0)


if __name__ == "__main__":
    main()
