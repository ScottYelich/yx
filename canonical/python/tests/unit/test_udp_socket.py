"""Unit tests for UDP Socket."""

import socket
import pytest
from yx.transport import UDPSocket


class TestUDPSocket:
    """Test UDP socket configuration."""

    def test_create_socket(self):
        """Test socket creation."""
        udp = UDPSocket(port=50001)
        sock = udp.create_socket()

        assert sock is not None
        assert sock.type == socket.SOCK_DGRAM

        udp.close()

    def test_bind_socket(self):
        """Test socket binding."""
        udp = UDPSocket(port=50002)
        udp.bind()

        # Socket should be bound
        assert udp.socket is not None

        udp.close()

    def test_socket_has_broadcast(self):
        """Test that socket has broadcast enabled."""
        udp = UDPSocket(port=50003)
        sock = udp.create_socket()

        # Check SO_BROADCAST is set (non-zero means enabled)
        broadcast = sock.getsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST)
        assert broadcast != 0

        udp.close()

    def test_close_socket(self):
        """Test socket closing."""
        udp = UDPSocket(port=50004)
        udp.create_socket()
        udp.close()

        assert udp.socket is None
