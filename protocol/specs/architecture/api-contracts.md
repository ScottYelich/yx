# YX Protocol: API Contracts Specification

**Version:** 1.0.0
**Date:** 2026-01-18
**Status:** Normative Specification
**Traceability:** Gap 4.8, Gap 5.1, Gap 6.3, Interop Requirements

---

## Overview

This specification defines API contracts that MUST be implemented consistently across all language implementations. API consistency enables:

1. **Interoperability Testing** - Sender/receiver programs work across languages
2. **Developer Ergonomics** - Similar APIs across Python, Swift, Rust, Go
3. **Documentation Portability** - Examples translate easily between languages

**Critical Requirement:** SimplePacketBuilder API MUST be identical across implementations to enable interop tests.

---

## Core Design Principles

### 1. Type Mapping Consistency

| Concept | Python | Swift | Rust | Go |
|---------|--------|-------|------|-----|
| Bytes | `bytes` | `Data` | `Vec<u8>` | `[]byte` |
| Symmetric Key | `bytes` (32) | `SymmetricKey` (256-bit) | `[u8; 32]` | `[32]byte` |
| GUID | `bytes` (6) | `Data` (6 bytes) | `[u8; 6]` | `[6]byte` |
| Host | `str` | `String` | `String` | `string` |
| Port | `int` | `Int` | `u16` | `uint16` |

### 2. Naming Conventions

| Style | Python | Swift | Rust | Go |
|-------|--------|-------|------|-----|
| Function Names | `snake_case` | `camelCase` | `snake_case` | `camelCase` |
| Class/Struct Names | `PascalCase` | `PascalCase` | `PascalCase` | `PascalCase` |
| Constants | `UPPER_SNAKE` | `camelCase` | `SCREAMING_SNAKE` | `CamelCase` |

### 3. Error Handling

| Approach | Python | Swift | Rust | Go |
|----------|--------|-------|------|-----|
| Pattern | Exceptions | `throws` | `Result<T, E>` | `(T, error)` |
| Example | `raise ValueError()` | `throw NetworkError` | `Err(Error)` | `return nil, err` |

---

## Critical API: SimplePacketBuilder

### Purpose
Pure function packet building for test programs WITHOUT requiring full framework overhead.

**Why Critical:** Enables sender/receiver test programs for interop testing (48 tests required).

### Design Requirements

✅ **MUST:**
- Be synchronous (no async/await)
- Be pure functions (no state)
- Support Protocol 0 and Protocol 1
- Support all protoOpts variants (0x00, 0x01, 0x02, 0x03)
- Use raw UDP sockets (not framework)
- Have identical API signature across languages

❌ **MUST NOT:**
- Require async runtime
- Require framework initialization
- Maintain internal state
- Use actors/threads

### Python API

```python
class SimplePacketBuilder:
    """Pure function packet builder for tests."""

    @staticmethod
    def build_text_packet(
        message: dict,      # JSON-serializable dict
        guid: bytes,        # 6 bytes
        key: bytes          # 32 bytes
    ) -> bytes:
        """
        Build Protocol 0 (text) packet.

        Returns: Complete packet ready for UDP send (HMAC + GUID + Payload)
        """
        ...

    @staticmethod
    def build_binary_packet(
        data: bytes,
        guid: bytes,        # 6 bytes
        key: bytes,         # 32 bytes
        proto_opts: int = 0x00,  # 0x00, 0x01, 0x02, or 0x03
        channel_id: int = 0,
        sequence: int = 0,
        chunk_size: int = 1024
    ) -> List[bytes]:
        """
        Build Protocol 1 (binary) packets.

        Returns: List of packets (one per chunk)
        """
        ...


def send_udp_packet(packet: bytes, host: str, port: int):
    """Send single UDP packet using BSD socket."""
    import socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(packet, (host, port))
    sock.close()


def send_udp_packets(packets: List[bytes], host: str, port: int):
    """Send multiple UDP packets using BSD socket."""
    import socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    for packet in packets:
        sock.sendto(packet, (host, port))
    sock.close()
```

### Swift API

```swift
struct SimplePacketBuilder {
    """Pure function packet builder for tests."""

    static func buildTextPacket(
        message: [String: Any],  // JSON-serializable dict
        guid: Data,              // 6 bytes
        key: Data                // 32 bytes
    ) -> Data {
        """
        Build Protocol 0 (text) packet.

        Returns: Complete packet ready for UDP send
        """
        ...
    }

    static func buildBinaryPacket(
        data: Data,
        guid: Data,              // 6 bytes
        key: Data,               // 32 bytes
        protoOpts: UInt8 = 0x00,
        channelID: UInt16 = 0,
        sequence: UInt32 = 0,
        chunkSize: Int = 1024
    ) -> [Data] {
        """
        Build Protocol 1 (binary) packets.

        Returns: Array of packets (one per chunk)
        """
        ...
    }
}


func sendUDPPacket(_ packet: Data, to host: String, port: Int) throws {
    """Send single UDP packet using BSD socket."""
    let sock = socket(AF_INET, SOCK_DGRAM, 0)
    defer { close(sock) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(port).bigEndian
    inet_pton(AF_INET, host, &addr.sin_addr)

    packet.withUnsafeBytes { bytes in
        _ = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                sendto(sock, bytes.baseAddress, bytes.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }
}


func sendUDPPackets(_ packets: [Data], to host: String, port: Int) throws {
    """Send multiple UDP packets using BSD socket."""
    for packet in packets {
        try sendUDPPacket(packet, to: host, port: port)
    }
}
```

### Usage Pattern

**Test Sender (Python):**
```python
#!/usr/bin/env python3
from yx.primitives.test_helpers import SimplePacketBuilder, send_udp_packet

guid = bytes.fromhex("010101010101")
key = bytes(32)  # 32 zeros for test
message = {"method": "test", "params": {"value": 42}}

packet = SimplePacketBuilder.build_text_packet(message, guid, key)
send_udp_packet(packet, "127.0.0.1", 49999)
print("SENT: test message")
```

**Test Sender (Swift):**
```swift
#!/usr/bin/swift
import Foundation

let guid = Data([0x01, 0x01, 0x01, 0x01, 0x01, 0x01])
let key = Data(repeating: 0, count: 32)
let message: [String: Any] = ["method": "test", "params": ["value": 42]]

let packet = SimplePacketBuilder.buildTextPacket(message: message, guid: guid, key: key)
try sendUDPPacket(packet, to: "127.0.0.1", port: 49999)
print("SENT: test message")
```

**Why Identical:** Shell scripts can run either sender and test cross-language compatibility.

---

## Core API: Main Framework

### High-Level Facade API

**Purpose:** Simple, beginner-friendly API for common use cases.

### Python API

```python
class YX:
    """High-level YX API facade."""

    def __init__(
        self,
        port: int = 50000,
        guid: Optional[bytes] = None,  # Auto-generate if None
        key: Optional[bytes] = None,   # Auto-generate if None
        listen_ip: str = "0.0.0.0",
        process_own_packets: bool = True
    ):
        """Initialize YX instance."""
        ...

    def rpc(self, method: str):
        """Decorator to register RPC handler."""
        def decorator(func):
            self.register_rpc(method, func)
            return func
        return decorator

    def register_rpc(self, method: str, handler: Callable):
        """Register RPC handler function."""
        ...

    async def send_text(
        self,
        message: dict,
        host: str,
        port: int
    ):
        """Send Protocol 0 (text) message."""
        ...

    async def send_binary(
        self,
        data: bytes,
        host: str,
        port: int,
        encrypt: bool = False,
        compress: bool = False,
        channel_id: int = 0
    ):
        """Send Protocol 1 (binary) message."""
        ...

    async def start(self, timeout: Optional[float] = None):
        """Start listening for messages."""
        ...

    async def stop(self):
        """Stop listening and cleanup."""
        ...

    @property
    def guid_hex(self) -> str:
        """Get GUID as hex string."""
        ...

    @property
    def key_hex(self) -> str:
        """Get key as hex string."""
        ...
```

### Swift API

```swift
actor YX {
    """High-level YX API facade."""

    init(
        port: Int = 50000,
        guid: Data? = nil,           // Auto-generate if nil
        key: Data? = nil,            // Auto-generate if nil
        listenIP: String = "0.0.0.0",
        processOwnPackets: Bool = true
    ) {
        """Initialize YX instance."""
        ...
    }

    func registerRPC(method: String, handler: @escaping (RPCRequest) async -> Void) {
        """Register RPC handler."""
        ...
    }

    func sendText(
        message: [String: Any],
        to host: String,
        port: Int
    ) async throws {
        """Send Protocol 0 (text) message."""
        ...
    }

    func sendBinary(
        data: Data,
        to host: String,
        port: Int,
        encrypt: Bool = false,
        compress: Bool = false,
        channelID: UInt16 = 0
    ) async throws {
        """Send Protocol 1 (binary) message."""
        ...
    }

    func start(timeout: TimeInterval? = nil) async throws {
        """Start listening for messages."""
        ...
    }

    func stop() async {
        """Stop listening and cleanup."""
        ...
    }

    var guidHex: String {
        """Get GUID as hex string."""
        ...
    }

    var keyHex: String {
        """Get key as hex string."""
        ...
    }
}
```

### Usage Example

**Python:**
```python
from yx import YX

yx = YX(port=9999)

@yx.rpc("task.hello")
async def handle_hello(request):
    print(f"Hello from {request.params['name']}")
    await request.reply({"status": "ok"})

await yx.send_text({"method": "task.hello", "params": {"name": "Alice"}}, "127.0.0.1", 9999)
await yx.start()
```

**Swift:**
```swift
let yx = YX(port: 9999)

await yx.registerRPC(method: "task.hello") { request in
    print("Hello from \(request.params["name"])")
    await request.reply(result: ["status": "ok"])
}

try await yx.sendText(message: ["method": "task.hello", "params": ["name": "Alice"]], to: "127.0.0.1", port: 9999)
try await yx.start()
```

---

## Transport API: UDP Socket

### Purpose
Low-level UDP socket with YX packet handling.

### Python API

```python
class UDPSocket:
    """Low-level UDP socket for YX packets."""

    def __init__(
        self,
        port: int,
        broadcast: bool = True,
        reuse_port: bool = True
    ):
        ...

    def send_packet(
        self,
        packet: bytes,
        host: str,
        port: int
    ):
        """Send raw packet."""
        ...

    def receive_packet(
        self,
        timeout: Optional[float] = None
    ) -> Tuple[bytes, Tuple[str, int]]:
        """
        Receive raw packet.

        Returns: (packet_bytes, (source_ip, source_port))
        """
        ...

    def close(self):
        """Close socket."""
        ...
```

### Swift API

```swift
actor UDPSocket {
    """Low-level UDP socket for YX packets."""

    init(
        port: Int,
        broadcast: Bool = true,
        reusePort: Bool = true
    ) throws {
        ...
    }

    func sendPacket(
        _ packet: Data,
        to host: String,
        port: Int
    ) async throws {
        """Send raw packet."""
        ...
    }

    func receivePacket(
        timeout: TimeInterval? = nil
    ) async throws -> (Data, String, Int) {
        """
        Receive raw packet.

        Returns: (packetData, sourceIP, sourcePort)
        """
        ...
    }

    func close() async {
        """Close socket."""
        ...
    }
}
```

---

## Protocol Handler API

### Purpose
Define contract for protocol handlers (Protocol 0, Protocol 1, etc.).

### Python API

```python
from typing import Protocol

class ProtocolHandler(Protocol):
    """Interface for protocol handlers."""

    async def handle(self, payload: bytes):
        """
        Process received payload.

        Args:
            payload: Raw payload (starts with protocol ID byte)
        """
        ...

    async def send(
        self,
        data: bytes,
        host: str,
        port: int
    ):
        """
        Send data using this protocol.

        Args:
            data: Application data (protocol will add protocol ID)
            host: Destination IP
            port: Destination port
        """
        ...
```

### Swift API

```swift
protocol ProtocolHandler {
    """Interface for protocol handlers."""

    func handle(payload: Data) async

    func send(
        data: Data,
        to host: String,
        port: Int
    ) async throws
}
```

---

## Security API

### Replay Protection API

**Python:**
```python
@dataclass
class ReplayProtection:
    max_age: float = 300.0  # seconds

    def check_and_record(self, nonce: bytes) -> bool:
        """
        Check if nonce seen before, record if new.

        Returns:
            True: Allowed (new nonce)
            False: Blocked (replay detected)
        """
        ...

    def clear(self):
        """Clear all cached nonces."""
        ...

    @property
    def count(self) -> int:
        """Get number of cached nonces."""
        ...
```

**Swift:**
```swift
actor ReplayProtection {
    private let maxAge: TimeInterval = 300.0

    func checkAndRecord(nonce: Data) async -> Bool {
        """
        Check if nonce seen before, record if new.

        Returns:
            true: Allowed (new nonce)
            false: Blocked (replay detected)
        """
        ...
    }

    func clear() async {
        """Clear all cached nonces."""
        ...
    }

    var count: Int {
        """Get number of cached nonces."""
        ...
    }
}
```

### Rate Limiter API

**Python:**
```python
@dataclass
class RateLimiter:
    max_requests: int = 10000
    window_seconds: float = 60.0
    trusted_guids: Set[str] = field(default_factory=set)

    def check_rate_limit(self, peer_id: str, source_addr: tuple) -> bool:
        """
        Check if peer under rate limit.

        Returns:
            True: Allowed
            False: Blocked (rate limit exceeded)
        """
        ...

    def add_trusted_guid(self, guid_hex: str):
        """Add GUID to whitelist (bypass rate limiting)."""
        ...

    def is_trusted(self, guid_hex: str) -> bool:
        """Check if GUID is trusted."""
        ...
```

**Swift:**
```swift
actor RateLimiter {
    private let maxRequests: Int = 10000
    private let windowSeconds: TimeInterval = 60.0

    func checkRateLimit(peerID: String, sourceAddr: String) async -> Bool {
        """
        Check if peer under rate limit.

        Returns:
            true: Allowed
            false: Blocked (rate limit exceeded)
        """
        ...
    }

    func addTrustedGUID(_ guidHex: String) async {
        """Add GUID to whitelist."""
        ...
    }

    func isTrusted(_ guidHex: String) async -> Bool {
        """Check if GUID is trusted."""
        ...
    }
}
```

---

## Type Conversion Utilities

### Purpose
Enable seamless type conversions for cross-language interop.

### Python API

```python
def guid_to_hex(guid: bytes) -> str:
    """Convert 6-byte GUID to hex string (uppercase)."""
    return guid.hex().upper()

def hex_to_guid(hex_string: str) -> bytes:
    """Parse hex string (with optional separators) to 6-byte GUID."""
    ...

def key_to_hex(key: bytes) -> str:
    """Convert 32-byte key to hex string."""
    return key.hex().upper()

def hex_to_key(hex_string: str) -> bytes:
    """Parse hex string to 32-byte key."""
    ...
```

### Swift API

```swift
extension Data {
    var hexString: String {
        """Convert to uppercase hex string."""
        return map { String(format: "%02X", $0) }.joined()
    }

    init?(hex: String) {
        """Parse hex string (with optional separators)."""
        ...
    }
}

func guidToHex(_ guid: Data) -> String {
    return guid.hexString
}

func hexToGUID(_ hex: String) -> Data? {
    return Data(hex: hex)
}
```

---

## Error Handling Contracts

### Python Error Hierarchy

```python
class YXError(Exception):
    """Base exception for YX errors."""
    pass

class NetworkError(YXError):
    """Network-related errors."""
    pass

class ValidationError(YXError):
    """Packet validation errors (HMAC, format, etc.)."""
    pass

class ProtocolError(YXError):
    """Protocol parsing/encoding errors."""
    pass

class SecurityError(YXError):
    """Security violations (replay, rate limit)."""
    pass
```

### Swift Error Enum

```swift
enum YXError: Error {
    case networkError(String)
    case validationError(String)
    case protocolError(String)
    case securityError(String)
}
```

---

## Testing API Contracts

### Test Requirements

Every implementation MUST provide test utilities:

**Python:**
```python
class TestConfig:
    """Test configuration helpers."""
    @staticmethod
    def test_port() -> int:
        """Get test port from env or default (49999)."""
        ...

    @staticmethod
    def test_guid() -> bytes:
        """Get fixed test GUID (6 bytes of 0x01)."""
        ...

    @staticmethod
    def test_key() -> bytes:
        """Get fixed test key (32 bytes of 0x00)."""
        ...
```

**Swift:**
```swift
struct TestConfig {
    static var testPort: Int {
        """Get test port from env or default (49999)."""
        ...
    }

    static var testGUID: Data {
        """Get fixed test GUID (6 bytes of 0x01)."""
        ...
    }

    static var testKey: Data {
        """Get fixed test key (32 bytes of 0x00)."""
        ...
    }
}
```

---

## Implementation Checklist

### Python Implementation
- [ ] SimplePacketBuilder with static methods
- [ ] YX facade class with decorators
- [ ] UDPSocket with synchronous send/receive
- [ ] ProtocolHandler protocol definition
- [ ] ReplayProtection dataclass
- [ ] RateLimiter dataclass
- [ ] Type conversion utilities
- [ ] Error hierarchy
- [ ] TestConfig utilities

### Swift Implementation
- [ ] SimplePacketBuilder struct with static methods
- [ ] YX actor with async methods
- [ ] UDPSocket actor
- [ ] ProtocolHandler protocol definition
- [ ] ReplayProtection actor
- [ ] RateLimiter actor
- [ ] Data extensions for hex conversion
- [ ] YXError enum
- [ ] TestConfig struct

### Cross-Language Validation
- [ ] SimplePacketBuilder produces identical packets
- [ ] Test utilities return identical values
- [ ] Error handling behavior consistent
- [ ] Interop tests pass (48/48)

---

## Version History

- **1.0.0** (2026-01-18): Initial specification

---

## References

**Related Specifications:**
- `specs/testing/interoperability-requirements.md` - Test requirements
- `specs/technical/default-values.md` - Configuration defaults
- `specs/architecture/protocol-layers.md` - Protocol details
- `specs/architecture/security-architecture.md` - Security APIs
