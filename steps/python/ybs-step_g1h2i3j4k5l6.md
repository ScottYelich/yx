# YBS Step 11: Protocol 0 (Text/JSON-RPC) Implementation

**Step ID:** `ybs-step_g1h2i3j4k5l6`
**Language:** Python
**Estimated Duration:** 2-3 hours
**Prerequisites:** Steps 1-10 complete

---

## Overview

Implement Protocol 0 (Text/JSON-RPC) handler for human-readable message exchange. This protocol layer sits above the transport layer and handles text-based messages with JSON-RPC 2.0 support.

**Traceability:**
- `specs/architecture/protocol-layers.md` - Protocol 0 specification
- `specs/technical/yx-protocol-spec.md` - Wire format
- `specs/architecture/api-contracts.md` - API contracts

---

## Context

**What You Have (Steps 1-10):**
- Transport layer (UDP + HMAC validation)
- Packet structure and builder
- Basic send/receive

**What You're Adding:**
- Protocol 0 handler (0x00 prefix + UTF-8 JSON)
- Protocol router (dispatches by protocol ID)
- JSON-RPC 2.0 support
- Integration with transport layer

**What Comes Next (Step 12):**
- Protocol 1 (Binary) handler
- Then security features (Step 13)
- Then test infrastructure (Steps 14-15)

---

## Goals

By the end of this step, you will have:

1. ✅ Protocol 0 handler (TextProtocol class)
2. ✅ Protocol router (ProtocolRouter class)
3. ✅ Protocol ID enumeration
4. ✅ JSON-RPC 2.0 request/response types
5. ✅ Integration with transport layer
6. ✅ Unit tests for Protocol 0
7. ✅ Traceability ≥80%

---

## File Structure

Create these files:

```
canonical/python/src/yx/
├── transport/
│   ├── protocol_router.py        # NEW: Routes by protocol ID
│   └── text_protocol.py          # NEW: Protocol 0 handler
└── rpc/                           # NEW DIRECTORY
    ├── __init__.py
    ├── json_rpc.py                # NEW: JSON-RPC 2.0 types
    └── dispatcher.py              # NEW: RPC method dispatcher
```

---

## Implementation

### Part 1: Protocol ID Enumeration

**File:** `canonical/python/src/yx/transport/protocol_router.py`

```python
"""
Protocol Router - Dispatches packets to protocol handlers.

Traceability:
- specs/architecture/protocol-layers.md (Protocol Router section)
"""

from enum import IntEnum
from typing import Dict, Callable, Awaitable, Optional
import logging

logger = logging.getLogger(__name__)


class ProtocolID(IntEnum):
    """
    Protocol identifier byte (first byte of payload).

    Traceability:
    - specs/architecture/protocol-layers.md (Protocol ID Registry)
    """
    TEXT = 0x00      # Protocol 0: Text/JSON-RPC
    BINARY = 0x01    # Protocol 1: Binary/Chunked


class ProtocolRouter:
    """
    Routes validated payloads to appropriate protocol handler.

    Traceability:
    - specs/architecture/protocol-layers.md (Protocol Router)
    """

    def __init__(self):
        self._handlers: Dict[int, Callable[[bytes], Awaitable[None]]] = {}

    def register(
        self,
        protocol_id: int,
        handler: Callable[[bytes], Awaitable[None]]
    ):
        """
        Register protocol handler.

        Args:
            protocol_id: Protocol ID byte (e.g., 0x00 for text)
            handler: Async function that processes payload

        Traceability:
        - specs/architecture/protocol-layers.md (Handler Registration)
        """
        self._handlers[protocol_id] = handler
        logger.info(f"Registered protocol handler for ID: 0x{protocol_id:02x}")

    async def route(self, payload: bytes):
        """
        Route payload to handler by protocol ID.

        Args:
            payload: Raw payload (first byte is protocol ID)

        Traceability:
        - specs/architecture/protocol-layers.md (Routing Algorithm)
        """
        if not payload:
            logger.debug("Empty payload, ignoring")
            return

        protocol_id = payload[0]

        handler = self._handlers.get(protocol_id)
        if handler is None:
            logger.error(f"Unknown protocol ID: 0x{protocol_id:02x}")
            return

        try:
            await handler(payload)
        except Exception as e:
            logger.exception(f"Error in protocol handler 0x{protocol_id:02x}: {e}")
```

**Verification:**
```bash
cd canonical/python
pytest src/yx/transport/test_protocol_router.py -v
```

---

### Part 2: JSON-RPC 2.0 Types

**File:** `canonical/python/src/yx/rpc/__init__.py`

```python
"""
RPC subsystem for JSON-RPC 2.0 support.

Traceability:
- specs/architecture/protocol-layers.md (Protocol 0 section)
"""

from .json_rpc import RPCRequest, RPCResponse, RPCError
from .dispatcher import RPCDispatcher

__all__ = ['RPCRequest', 'RPCResponse', 'RPCError', 'RPCDispatcher']
```

**File:** `canonical/python/src/yx/rpc/json_rpc.py`

```python
"""
JSON-RPC 2.0 request/response types.

Traceability:
- specs/architecture/protocol-layers.md (JSON-RPC 2.0 Format)
"""

from dataclasses import dataclass
from typing import Any, Optional, Dict


@dataclass
class RPCRequest:
    """
    JSON-RPC 2.0 request.

    Traceability:
    - specs/architecture/protocol-layers.md (JSON-RPC 2.0 Structure)
    """
    id: Optional[str]
    method: str
    params: Dict[str, Any]
    raw: Dict[str, Any]

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'RPCRequest':
        """Parse JSON-RPC request from dict."""
        return cls(
            id=data.get('id'),
            method=data.get('method', ''),
            params=data.get('params', {}),
            raw=data
        )

    def reply(self, result: Any) -> 'RPCResponse':
        """Create success response."""
        return RPCResponse(
            id=self.id,
            result=result,
            error=None
        )

    def reply_error(self, code: int, message: str) -> 'RPCResponse':
        """Create error response."""
        return RPCResponse(
            id=self.id,
            result=None,
            error=RPCError(code=code, message=message)
        )


@dataclass
class RPCError:
    """JSON-RPC 2.0 error object."""
    code: int
    message: str
    data: Optional[Any] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dict."""
        result = {
            'code': self.code,
            'message': self.message
        }
        if self.data is not None:
            result['data'] = self.data
        return result


@dataclass
class RPCResponse:
    """JSON-RPC 2.0 response."""
    id: Optional[str]
    result: Optional[Any]
    error: Optional[RPCError]

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-RPC response dict."""
        response = {
            'jsonrpc': '2.0',
            'id': self.id
        }

        if self.error:
            response['error'] = self.error.to_dict()
        else:
            response['result'] = self.result

        return response
```

---

### Part 3: RPC Dispatcher

**File:** `canonical/python/src/yx/rpc/dispatcher.py`

```python
"""
RPC dispatcher for method routing.

Traceability:
- specs/architecture/protocol-layers.md (Application Layer)
"""

from typing import Dict, Callable, Awaitable, Any
import logging
from .json_rpc import RPCRequest, RPCResponse

logger = logging.getLogger(__name__)


class RPCDispatcher:
    """
    Dispatches RPC requests to registered handlers.

    Traceability:
    - specs/architecture/api-contracts.md (RPC Dispatcher)
    """

    def __init__(self):
        self._handlers: Dict[str, Callable[[RPCRequest], Awaitable[None]]] = {}

    def register(
        self,
        method: str,
        handler: Callable[[RPCRequest], Awaitable[None]]
    ):
        """
        Register RPC method handler.

        Args:
            method: Method name (e.g., "task.hello")
            handler: Async function that processes request
        """
        self._handlers[method] = handler
        logger.info(f"Registered RPC handler: {method}")

    async def dispatch(self, request: RPCRequest):
        """
        Dispatch request to handler.

        Args:
            request: Parsed RPC request
        """
        handler = self._handlers.get(request.method)

        if handler is None:
            logger.warning(f"RPC method not found: {request.method}")
            return

        try:
            await handler(request)
        except Exception as e:
            logger.exception(f"Error in RPC handler '{request.method}': {e}")
```

---

### Part 4: Protocol 0 Handler

**File:** `canonical/python/src/yx/transport/text_protocol.py`

```python
"""
Protocol 0: Text/JSON-RPC handler.

Traceability:
- specs/architecture/protocol-layers.md (Protocol 0 section)
- specs/technical/yx-protocol-spec.md (Protocol 0 wire format)
"""

import json
import logging
from typing import Optional, Callable, Awaitable, Dict, Any

from .protocol_router import ProtocolID
from ..rpc.json_rpc import RPCRequest

logger = logging.getLogger(__name__)


class TextProtocol:
    """
    Protocol 0 handler for text/JSON messages.

    Traceability:
    - specs/architecture/protocol-layers.md (Protocol 0)
    """

    def __init__(self, on_message: Optional[Callable[[Dict[str, Any]], Awaitable[None]]] = None):
        """
        Initialize text protocol handler.

        Args:
            on_message: Callback for received messages (async)
        """
        self._on_message = on_message
        self._send_api = None

    def install_send_api(self, send_fn: Callable[[bytes, str, int], Awaitable[None]]):
        """
        Install send function from transport layer.

        Args:
            send_fn: Async function(payload, host, port) that sends packet

        Traceability:
        - specs/architecture/protocol-layers.md (Handler Responsibilities)
        """
        self._send_api = send_fn

    async def handle(self, payload: bytes):
        """
        Process received Protocol 0 payload.

        Args:
            payload: Raw payload (starts with 0x00)

        Traceability:
        - specs/architecture/protocol-layers.md (Receive Path)
        """
        # Verify protocol ID
        if not payload or payload[0] != ProtocolID.TEXT:
            logger.error(f"Invalid protocol ID for text protocol: {payload[0] if payload else 'empty'}")
            return

        # Extract JSON payload (skip protocol ID byte)
        json_bytes = payload[1:]

        # Decode UTF-8
        try:
            json_str = json_bytes.decode('utf-8')
        except UnicodeDecodeError as e:
            logger.error(f"Failed to decode UTF-8: {e}")
            return

        # Parse JSON
        try:
            message = json.loads(json_str)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON: {e}")
            return

        logger.debug(f"Received text message: {message}")

        # Dispatch to callback
        if self._on_message:
            try:
                await self._on_message(message)
            except Exception as e:
                logger.exception(f"Error in message handler: {e}")

    async def send(
        self,
        message: Dict[str, Any],
        host: str,
        port: int
    ):
        """
        Send Protocol 0 message.

        Args:
            message: JSON-serializable dict
            host: Destination IP
            port: Destination port

        Traceability:
        - specs/architecture/protocol-layers.md (Send Path)
        """
        if self._send_api is None:
            raise RuntimeError("Send API not installed")

        # Encode as JSON
        json_str = json.dumps(message)
        json_bytes = json_str.encode('utf-8')

        # Check size (Protocol 0 is single packet)
        if len(json_bytes) > 1450:  # Conservative limit
            logger.warning(f"Message size {len(json_bytes)} bytes may exceed MTU")

        # Prepend protocol ID
        payload = bytes([ProtocolID.TEXT]) + json_bytes

        logger.debug(f"Sending text message to {host}:{port}")

        # Send via transport layer
        await self._send_api(payload, host, port)
```

---

### Part 5: Integration Tests

**File:** `canonical/python/src/yx/transport/test_protocol_router.py`

```python
"""
Tests for protocol router.

Traceability:
- specs/architecture/protocol-layers.md (Testing Requirements)
"""

import pytest
from yx.transport.protocol_router import ProtocolRouter, ProtocolID


@pytest.mark.asyncio
async def test_protocol_router_routes_text():
    """Test router dispatches Protocol 0 to text handler."""
    received = []

    async def text_handler(payload: bytes):
        received.append(payload)

    router = ProtocolRouter()
    router.register(ProtocolID.TEXT, text_handler)

    # Route text protocol payload
    payload = bytes([0x00]) + b"test"
    await router.route(payload)

    assert len(received) == 1
    assert received[0] == payload


@pytest.mark.asyncio
async def test_protocol_router_unknown_protocol():
    """Test router handles unknown protocol ID gracefully."""
    router = ProtocolRouter()

    # Should not raise, just log error
    payload = bytes([0xFF]) + b"test"
    await router.route(payload)


@pytest.mark.asyncio
async def test_protocol_router_empty_payload():
    """Test router handles empty payload."""
    router = ProtocolRouter()
    await router.route(b"")
```

**File:** `canonical/python/src/yx/transport/test_text_protocol.py`

```python
"""
Tests for Protocol 0 (text) handler.

Traceability:
- specs/architecture/protocol-layers.md (Protocol 0 Tests)
"""

import pytest
import json
from yx.transport.text_protocol import TextProtocol
from yx.transport.protocol_router import ProtocolID


@pytest.mark.asyncio
async def test_text_protocol_receive_json():
    """Test Protocol 0 receives and parses JSON."""
    received = []

    async def on_message(msg):
        received.append(msg)

    handler = TextProtocol(on_message=on_message)

    # Create Protocol 0 payload
    message = {"method": "test", "params": {"value": 42}}
    json_bytes = json.dumps(message).encode('utf-8')
    payload = bytes([ProtocolID.TEXT]) + json_bytes

    await handler.handle(payload)

    assert len(received) == 1
    assert received[0] == message


@pytest.mark.asyncio
async def test_text_protocol_send_json():
    """Test Protocol 0 sends JSON with protocol ID."""
    sent = []

    async def send_api(payload, host, port):
        sent.append((payload, host, port))

    handler = TextProtocol()
    handler.install_send_api(send_api)

    message = {"method": "test", "params": {"value": 42}}
    await handler.send(message, "127.0.0.1", 9999)

    assert len(sent) == 1
    payload, host, port = sent[0]

    # Verify protocol ID
    assert payload[0] == ProtocolID.TEXT

    # Verify JSON content
    json_bytes = payload[1:]
    parsed = json.loads(json_bytes.decode('utf-8'))
    assert parsed == message


@pytest.mark.asyncio
async def test_text_protocol_invalid_json():
    """Test Protocol 0 handles invalid JSON gracefully."""
    received = []

    async def on_message(msg):
        received.append(msg)

    handler = TextProtocol(on_message=on_message)

    # Invalid JSON
    payload = bytes([ProtocolID.TEXT]) + b"{invalid json}"

    # Should not raise, just log error
    await handler.handle(payload)

    assert len(received) == 0


@pytest.mark.asyncio
async def test_text_protocol_invalid_utf8():
    """Test Protocol 0 handles invalid UTF-8 gracefully."""
    received = []

    async def on_message(msg):
        received.append(msg)

    handler = TextProtocol(on_message=on_message)

    # Invalid UTF-8
    payload = bytes([ProtocolID.TEXT]) + bytes([0xFF, 0xFE])

    # Should not raise, just log error
    await handler.handle(payload)

    assert len(received) == 0


@pytest.mark.asyncio
async def test_text_protocol_large_message():
    """Test Protocol 0 warns on large messages."""
    handler = TextProtocol()

    async def send_api(payload, host, port):
        pass

    handler.install_send_api(send_api)

    # Large message (>1450 bytes)
    large_message = {"data": "X" * 2000}

    # Should send but log warning
    await handler.send(large_message, "127.0.0.1", 9999)
```

**File:** `canonical/python/src/yx/rpc/test_json_rpc.py`

```python
"""
Tests for JSON-RPC 2.0 types.

Traceability:
- specs/architecture/protocol-layers.md (JSON-RPC 2.0 Format)
"""

import pytest
from yx.rpc.json_rpc import RPCRequest, RPCResponse, RPCError


def test_rpc_request_from_dict():
    """Test RPCRequest parsing."""
    data = {
        'jsonrpc': '2.0',
        'id': 'req-001',
        'method': 'task.hello',
        'params': {'name': 'Alice'}
    }

    request = RPCRequest.from_dict(data)

    assert request.id == 'req-001'
    assert request.method == 'task.hello'
    assert request.params == {'name': 'Alice'}
    assert request.raw == data


def test_rpc_request_reply():
    """Test RPCRequest.reply() creates success response."""
    request = RPCRequest(
        id='req-001',
        method='test',
        params={},
        raw={}
    )

    response = request.reply({'status': 'ok'})

    assert response.id == 'req-001'
    assert response.result == {'status': 'ok'}
    assert response.error is None


def test_rpc_request_reply_error():
    """Test RPCRequest.reply_error() creates error response."""
    request = RPCRequest(
        id='req-001',
        method='test',
        params={},
        raw={}
    )

    response = request.reply_error(-32601, "Method not found")

    assert response.id == 'req-001'
    assert response.result is None
    assert response.error.code == -32601
    assert response.error.message == "Method not found"


def test_rpc_response_to_dict_success():
    """Test RPCResponse.to_dict() for success."""
    response = RPCResponse(
        id='req-001',
        result={'status': 'ok'},
        error=None
    )

    data = response.to_dict()

    assert data == {
        'jsonrpc': '2.0',
        'id': 'req-001',
        'result': {'status': 'ok'}
    }


def test_rpc_response_to_dict_error():
    """Test RPCResponse.to_dict() for error."""
    response = RPCResponse(
        id='req-001',
        result=None,
        error=RPCError(code=-32601, message="Method not found")
    )

    data = response.to_dict()

    assert data == {
        'jsonrpc': '2.0',
        'id': 'req-001',
        'error': {
            'code': -32601,
            'message': 'Method not found'
        }
    }
```

---

## Verification

### Run All Tests

```bash
cd canonical/python

# Run Protocol 0 tests
pytest src/yx/transport/test_protocol_router.py -v
pytest src/yx/transport/test_text_protocol.py -v
pytest src/yx/rpc/test_json_rpc.py -v

# Verify all tests pass
pytest src/yx/ -v --tb=short
```

### Expected Output

```
test_protocol_router.py::test_protocol_router_routes_text PASSED
test_protocol_router.py::test_protocol_router_unknown_protocol PASSED
test_protocol_router.py::test_protocol_router_empty_payload PASSED

test_text_protocol.py::test_text_protocol_receive_json PASSED
test_text_protocol.py::test_text_protocol_send_json PASSED
test_text_protocol.py::test_text_protocol_invalid_json PASSED
test_text_protocol.py::test_text_protocol_invalid_utf8 PASSED
test_text_protocol.py::test_text_protocol_large_message PASSED

test_json_rpc.py::test_rpc_request_from_dict PASSED
test_json_rpc.py::test_rpc_request_reply PASSED
test_json_rpc.py::test_rpc_request_reply_error PASSED
test_json_rpc.py::test_rpc_response_to_dict_success PASSED
test_json_rpc.py::test_rpc_response_to_dict_error PASSED

==================== 13 passed ====================
```

### Verify Traceability

```bash
# Check traceability comments exist
grep -r "Traceability:" src/yx/transport/protocol_router.py
grep -r "Traceability:" src/yx/transport/text_protocol.py
grep -r "Traceability:" src/yx/rpc/
```

Expected: ≥80% of classes/functions have traceability comments.

---

## Success Criteria

✅ **Code Complete:**
- [ ] ProtocolRouter class implemented
- [ ] ProtocolID enum defined
- [ ] TextProtocol class implemented
- [ ] RPCRequest/RPCResponse types implemented
- [ ] RPCDispatcher class implemented

✅ **Tests Pass:**
- [ ] 13/13 Protocol 0 tests passing
- [ ] No test failures or errors
- [ ] Coverage ≥90% for new code

✅ **Traceability:**
- [ ] ≥80% of code has traceability comments
- [ ] References specs/architecture/protocol-layers.md
- [ ] References specs/technical/yx-protocol-spec.md

✅ **Integration:**
- [ ] Protocol router routes text messages
- [ ] Text protocol encodes/decodes JSON
- [ ] RPC types support JSON-RPC 2.0 format

---

## Common Issues

### Issue 1: Import Errors

**Symptom:** `ImportError: cannot import name 'ProtocolRouter'`

**Cause:** Missing `__init__.py` or incorrect imports

**Fix:**
```python
# src/yx/transport/__init__.py
from .protocol_router import ProtocolRouter, ProtocolID
from .text_protocol import TextProtocol
```

### Issue 2: JSON Encoding Errors

**Symptom:** `TypeError: Object of type bytes is not JSON serializable`

**Cause:** Trying to serialize bytes in JSON

**Fix:** Convert bytes to hex string before JSON encoding:
```python
message = {
    'guid': guid.hex(),  # Convert bytes to string
    'data': data.hex()
}
```

### Issue 3: Async Callback Not Awaited

**Symptom:** `RuntimeWarning: coroutine 'on_message' was never awaited`

**Cause:** Forgetting to await async callback

**Fix:**
```python
# WRONG
if self._on_message:
    self._on_message(message)  # Missing await!

# RIGHT
if self._on_message:
    await self._on_message(message)
```

---

## Next Steps

After completing this step:

1. ✅ Commit your changes:
   ```bash
   git add src/yx/transport/protocol_router.py
   git add src/yx/transport/text_protocol.py
   git add src/yx/rpc/
   git commit -m "Add Protocol 0 (Text/JSON-RPC) implementation

   - Implement protocol router with dispatch by ID
   - Add text protocol handler with JSON encoding/decoding
   - Add JSON-RPC 2.0 types and dispatcher
   - 13/13 tests passing

   Traceability: specs/architecture/protocol-layers.md

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
   ```

2. ✅ Proceed to **Step 12: Protocol 1 (Binary/Chunked)**

---

## References

**Specifications:**
- `specs/architecture/protocol-layers.md` - Protocol layer architecture
- `specs/technical/yx-protocol-spec.md` - Wire format details
- `specs/architecture/api-contracts.md` - API contracts

**SDTS Reference:**
- `sdts-comparison/python/yx/transport/text_protocol.py` - Reference implementation
- `sdts-comparison/python/yx/rpc/` - RPC reference implementation

**Step Dependencies:**
- Step 10: Generate canonical artifacts (prerequisite)
- Step 12: Protocol 1 implementation (next)
