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
