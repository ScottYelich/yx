# Testing Specifications — System-Wide Defaults

**System**: YX Protocol
**Category**: Testing
**Type**: BASE (applies to all testing specs in this category)
**Version**: 0.1.0
**Last Updated**: 2026-04-11

## Coverage Requirements

These minimums apply to all YX implementations regardless of language.

| Path | Minimum | Target |
|---|---|---|
| Overall line coverage | 80% | 90% |
| HMAC computation | 100% | 100% |
| Packet serialization/deserialization | 100% | 100% |
| Security layer (replay, rate limit) | 100% | 100% |
| UDP transport | 80% | 90% |

## Wire Format Validation

Every implementation must validate against the canonical test vectors in
`canonical/test-vectors/` before being considered complete.

- All canonical test vectors MUST pass (zero failures allowed)
- HMAC values must match byte-for-byte
- Serialized packet bytes must match byte-for-byte

## Interoperability Testing

After both Python and Swift implementations exist, the 48-test interop matrix
is **mandatory**. A build is not complete without passing all 48 tests.

See `interoperability-requirements.md` for the full test matrix.

## Test Quality Standards

- No flaky tests (≥99% pass rate over repeated runs)
- Tests must use real UDP sockets (no mock sockets for interop tests)
- Unit tests may mock I/O but must test actual cryptographic computations
- Timing-sensitive tests (replay window, rate limiting) must use deterministic clocks

## Test Naming Conventions

```
test_<component>_<scenario>_<expected_outcome>
```

Examples:
- `test_hmac_valid_key_returns_16_bytes`
- `test_packet_tampered_hmac_raises_error`
- `test_replay_duplicate_packet_rejected`
