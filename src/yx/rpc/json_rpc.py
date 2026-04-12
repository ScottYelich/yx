"""
JSON-RPC 2.0 request/response types.

Traceability:
- protocol/specs/architecture/protocol-layers.md (JSON-RPC 2.0 Format)
"""

from dataclasses import dataclass
from typing import Any, Optional, Dict


@dataclass
class RPCRequest:
    """
    JSON-RPC 2.0 request.

    Traceability:
    - protocol/specs/architecture/protocol-layers.md (JSON-RPC 2.0 Structure)
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
