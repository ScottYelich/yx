# Technical Specifications — System-Wide Defaults

**System**: YX Protocol
**Category**: Technical
**Type**: BASE (applies to all technical specs in this category)
**Version**: 0.1.0
**Last Updated**: 2026-04-11

## Wire Format Invariants

These rules apply to every YX packet regardless of implementation language.
Any spec in `technical/` may rely on these without re-stating them.

### Packet Layout

```
[HMAC 16 bytes][GUID 6 bytes][PAYLOAD N bytes]
```

- **HMAC**: First 16 bytes of HMAC-SHA256(key, GUID || PAYLOAD)
- **GUID**: 6-byte cryptographically-random identifier
- **PAYLOAD**: Variable-length, format determined by Protocol Layer byte

### Encoding

- All multi-byte integers: **big-endian**
- Strings in payload: **UTF-8**
- Binary data in payload: raw bytes, no base64
- HMAC computation: `HMAC-SHA256(key, guid_bytes + payload_bytes)`, truncated to 16 bytes

### Cross-Language Compatibility

All implementations MUST produce **byte-identical** packets for identical inputs.
- Same key + GUID + payload → same HMAC bytes
- Same HMAC + GUID + payload → same serialized packet

### Minimum Packet Size

- Minimum: 22 bytes (16 HMAC + 6 GUID + 0 payload)
- Maximum: transport MTU (implementation-defined, typically 65507 for UDP)

## Security Defaults

- HMAC key length: 32 bytes
- Replay window: 300 seconds
- Rate limit: 10,000 requests per 60 seconds per sender
- These values are normative unless explicitly overridden by a spec

## Versioning

All technical specs use semantic versioning starting at `0.1.0`.
Breaking wire-format changes require a major version bump.
