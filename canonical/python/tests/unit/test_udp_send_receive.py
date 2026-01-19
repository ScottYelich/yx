"""Test UDP send/receive."""

import socket
import pytest
from yx.transport import UDPSocket


class TestUDPSendReceive:
    """Test send/receive functionality."""

    def test_send_packet(self):
        """Test sending packet."""
        key = b'\x00' * 32
        sender = UDPSocket(port=0)  # Random port
        sender.bind()

        # Should not raise
        sender.send_packet(b'\x01'*6, b'test', key, '127.0.0.1', 50010)

        sender.close()

    def test_send_receive_loopback(self):
        """Test sending and receiving on same machine."""
        key = b'\x00' * 32

        receiver = UDPSocket(port=50011)
        receiver.bind()
        receiver.socket.settimeout(1.0)

        sender = UDPSocket(port=0)
        sender.bind()

        # Send
        sender.send_packet(b'\x01'*6, b'test payload', key, '127.0.0.1', 50011)

        # Receive
        guid, payload, addr = receiver.receive_packet(key)

        assert guid == b'\x01' * 6
        assert payload == b'test payload'

        sender.close()
        receiver.close()
