# Technical Specifications — Python System-Wide Defaults

**System**: YX Python Implementation
**Category**: Technical
**Type**: BASE
**Version**: 0.1.0
**Last Updated**: 2026-04-11

## Language Version

- **Minimum**: Python 3.10
- **Recommended**: Python 3.11+
- Reason: `match` statements (3.10), improved `asyncio` exception groups (3.11)

## Package Management

- **Tool**: `pyproject.toml` + `pip` (PEP 517/518 build system)
- **Test extras**: `pip install -e .[dev]`
- No `requirements.txt` — all dependencies declared in `pyproject.toml`

## Coding Standards

- Type annotations required on all public functions and class attributes
- `dataclass` preferred over plain classes for data structures
- f-strings for string formatting (not `.format()` or `%`)
- Constants in `UPPER_SNAKE_CASE`

## Async Model

- `asyncio` for all async I/O (UDP socket operations)
- `async def` / `await` style (not callbacks)
- Event loop management is the caller's responsibility

## Module Structure Convention

```
src/yx/
├── primitives/    # Pure computation: GUID generation, HMAC, crypto
└── transport/     # I/O and packet handling: Packet, PacketBuilder, UDPSocket
```

`primitives/` has no I/O dependencies. `transport/` may depend on `primitives/`
but not vice versa.

## Error Handling

- Raise `ValueError` for invalid inputs (bad key length, empty GUID, etc.)
- Raise `RuntimeError` for I/O failures (socket bind errors, etc.)
- Never silently swallow errors in protocol-critical paths
