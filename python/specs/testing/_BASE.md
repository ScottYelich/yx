# Testing Specifications — Python System-Wide Defaults

**System**: YX Python Implementation
**Category**: Testing
**Type**: BASE
**Version**: 0.1.0
**Last Updated**: 2026-04-11

## Test Framework

- **Framework**: `pytest` (≥7.4.0)
- **Async support**: `pytest-asyncio` (≥0.21.0), `asyncio_mode = "auto"`
- **Coverage**: `pytest-cov` (≥4.1.0)

## Test Organization

```
tests/
├── unit/           # One file per source module: test_<module>.py
└── integration/    # End-to-end flows: test_<feature>_flow.py
```

## Running Tests

```bash
pytest                                    # All tests
pytest tests/unit/                        # Unit only
pytest tests/integration/                 # Integration only
pytest --cov=src --cov-report=term-missing  # With coverage
```

## Coverage Thresholds

Per the protocol testing BASE spec: overall ≥80%, critical paths 100%.
Coverage is checked as part of the final verification step.

## Async Test Pattern

```python
import pytest

@pytest.mark.asyncio
async def test_send_receive():
    ...
```

With `asyncio_mode = "auto"` in `pyproject.toml`, the decorator is optional
but recommended for clarity.

## Deterministic Time in Tests

For replay protection and rate limiting tests, patch `time.time()`:

```python
from unittest.mock import patch

with patch('yx.security.time.time', return_value=1000.0):
    ...
```
