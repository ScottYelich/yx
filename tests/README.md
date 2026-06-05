# System-Level Tests

This directory contains tests that span multiple YX implementations.

The per-language unit/integration tests live with each implementation
(`canonical/python/tests/`, `canonical/swift/Tests/`). This directory holds the
**cross-language interoperability** suite.

## interop/

Verifies that the Python (`canonical/python/`) and Swift (`canonical/swift/`)
implementations actually communicate over real UDP sockets (no mocks).

### Run the full 48-test matrix
```bash
python3 tests/interop/run_matrix.py
# or, which also (re)builds the Swift programs first:
tests/interop/run_all_interop_tests.sh
```

### What it covers (48 tests)

| Layer | Scenarios | × Combos | Tests |
|-------|-----------|----------|-------|
| Transport (HMAC)            | simple, empty, large, multiple, invalid | 4 | 20 |
| Protocol 0 (text/JSON-RPC)  | json, large, invalid                     | 4 | 12 |
| Protocol 1 (binary/chunked) | base, compressed, encrypted, both        | 4 | 16 |

Combinations: Python→Python, Python→Swift, Swift→Python, Swift→Swift.

### Layout
- `senders/`, `receivers/` — standalone Python sender/receiver programs.
- `transport/`, `protocol0/`, `protocol1/` — Python↔Python scenario drivers.
- `swift-interop/` — the Swift sender/receiver executables (SwiftPM package that
  depends on `canonical/swift`).
- `run_matrix.py` — the cross-language matrix driver.

### Prerequisites
- Python 3 with the `cryptography` package (used by `canonical/python`).
- A Swift toolchain (`swift build` works in `tests/interop/swift-interop/`).
- Canonical artifacts in `canonical/test-vectors/` (the Swift unit tests validate
  byte-for-byte against them).

## Notes
- "large" interop payloads are sized to the spec (~5–7 KB, single datagram) so they
  fit under the macOS `net.inet.udp.maxdgram` cap (9216 bytes). Arbitrarily large
  data is carried by Protocol 1 chunking (multi-packet, reassembled).
- Tests require localhost UDP; they bind port 49999 by default (override with
  `TEST_YX_PORT`).
