#! /usr/bin/env python3
"""
Protocol 0 test receiver. Waits for Protocol 0 packet and exits.

Exit code: 0 = success, 1 = failure

Traceability:
- protocol/specs/testing/interoperability-requirements.md (Receiver Interface)
"""

import sys
import json
import socket
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../src'))

from yx.transport.udp_socket import UDPSocket
from yx.primitives.test_helpers import TestConfig


def main():
    key = TestConfig.test_key()
    port = TestConfig.test_port()

    receiver = UDPSocket(port=port)
    receiver.create_socket()
    receiver.socket.settimeout(5.0)
    receiver.bind()

    try:
        guid, payload, addr = receiver.receive_packet(key)

        if payload[0] != 0x00:
            print(f"FAILED: Expected Protocol 0, got 0x{payload[0]:02x}")
            sys.exit(1)

        message = json.loads(payload[1:].decode('utf-8'))
        print(f"RECEIVED: {message}")
        sys.exit(0)

    except socket.timeout:
        print("FAILED: Timeout waiting for packet")
        sys.exit(1)
    except Exception as e:
        print(f"FAILED: {e}")
        sys.exit(1)
    finally:
        receiver.close()


if __name__ == "__main__":
    main()
