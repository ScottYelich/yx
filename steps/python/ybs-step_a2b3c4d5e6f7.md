# Step 7: UDP Socket Configuration

**Version**: 0.1.0

## Overview

Configure UDP socket with broadcast support for YX protocol communication.

## Step Objectives

1. Create socket with SO_REUSEADDR, SO_REUSEPORT, SO_BROADCAST
2. Bind to all interfaces (0.0.0.0:port)
3. Test socket creation and configuration
4. 100% test coverage

## Prerequisites

- Step 6 completed

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § UDP Socket Configuration

## Instructions

### 1. Create UDP Socket Module

Create `src/yx/transport/udp_socket.py`:

```python
"""UDP Socket Configuration for YX Protocol."""

import socket
from typing import Tuple


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
```

### 2. Update __init__.py

Update `src/yx/transport/__init__.py`:

```python
from .packet import Packet
from .packet_builder import PacketBuilder
from .udp_socket import UDPSocket

__all__ = ["Packet", "PacketBuilder", "UDPSocket"]
```

### 3. Create Tests

Create `tests/unit/test_udp_socket.py`:

```python
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

        # Check SO_BROADCAST is set
        broadcast = sock.getsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST)
        assert broadcast == 1

        udp.close()

    def test_close_socket(self):
        """Test socket closing."""
        udp = UDPSocket(port=50004)
        udp.create_socket()
        udp.close()

        assert udp.socket is None
```

### 4. Run Tests

```bash
pytest tests/unit/test_udp_socket.py -v
```

## Verification

- [ ] Socket creates successfully
- [ ] SO_BROADCAST enabled
- [ ] Binds to 0.0.0.0
- [ ] Tests pass

```bash
pytest tests/unit/test_udp_socket.py -v
python3 -c "from yx.transport import UDPSocket; s = UDPSocket(); s.bind(); s.close(); print('✓ UDP socket verified')"
```
