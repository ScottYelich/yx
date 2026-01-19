"""UDP Socket Configuration for YX Protocol."""

import socket
from typing import Tuple
from .packet_builder import PacketBuilder


class UDPSocket:
    """Configure and manage UDP socket for YX protocol."""

    def __init__(self, port: int = 50000):
        """
        Initialize UDP socket.

        Args:
            port: Port to bind to (default: 50000)
        """
        self.port = port
        self.socket: socket.socket = None

    def create_socket(self) -> socket.socket:
        """
        Create and configure UDP socket.

        Returns:
            socket.socket: Configured UDP socket

        Raises:
            OSError: If socket creation fails
        """
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

        # Allow address reuse
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        # Allow port reuse (multiple listeners on same port)
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except AttributeError:
            # SO_REUSEPORT not available on Windows
            pass

        # Enable broadcast
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

        self.socket = sock
        return sock

    def bind(self):
        """Bind socket to all interfaces."""
        if self.socket is None:
            self.create_socket()
        self.socket.bind(('0.0.0.0', self.port))

    def close(self):
        """Close socket."""
        if self.socket:
            self.socket.close()
            self.socket = None

    def send_packet(self, guid: bytes, payload: bytes, key: bytes, host: str = '255.255.255.255', port: int = 50000):
        """Send YX packet via UDP."""
        if self.socket is None:
            self.create_socket()

        data = PacketBuilder.build_and_serialize(guid, payload, key)
        self.socket.sendto(data, (host, port))

    def receive_packet(self, key: bytes, buffer_size: int = 65507) -> Tuple[bytes, bytes, Tuple[str, int]]:
        """
        Receive and parse YX packet.

        Returns:
            (guid, payload, addr) tuple or raises exception
        """
        if self.socket is None:
            raise RuntimeError("Socket not created")

        data, addr = self.socket.recvfrom(buffer_size)
        packet = PacketBuilder.parse_and_validate(data, key)

        if packet is None:
            raise ValueError("Invalid packet received")

        return packet.guid, packet.payload, addr
