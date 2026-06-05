# YX Protocol - Interoperability Status

**Last Updated:** 2026-06-04

## Summary

Both Python and Swift implementations are complete and **cross-language
interoperability is fully verified over real UDP sockets**: all 48 mandated
interop tests pass.

Run it: `python3 tests/interop/run_matrix.py` (or `tests/interop/run_all_interop_tests.sh`).

---

## Results ✅

### Unit suites
- **Python** (`canonical/python/`): 148 unit tests pass (Transport, Protocol 0,
  Protocol 1 compression/AES-GCM/chunking+reassembly, security).
- **Swift** (`canonical/swift/`): 67 tests pass (43 XCTest + 24 Swift Testing).

### Cross-language interop: 48/48 (real UDP, no mocks)

| Layer | Scenarios | Combos | Tests |
|-------|-----------|--------|-------|
| Transport (HMAC) | simple, empty, large, multiple, invalid | 4 | 20 |
| Protocol 0 (text/JSON-RPC) | json, large, invalid | 4 | 12 |
| Protocol 1 (binary/chunked) | base, compressed, encrypted, both | 4 | 16 |

Combinations: Python→Python, Python→Swift, Swift→Python, Swift→Swift.

### Verified compatibility details
- **HMAC-SHA256** truncated to 16 bytes over `GUID + payload`.
- **Compression**: Apple `COMPRESSION_ZLIB` (raw DEFLATE) ⟺ Python `zlib wbits=-15`.
- **AES-256-GCM**: wire format `[nonce(12)] + [ciphertext] + [tag(16)]`, shared `test_key`.
- **Protocol 1 chunking**: 16-byte header `>BBHIII`, reassembly keyed by
  `(channelID, sequence)`; multi-chunk verified Python↔Swift.

### Notes
- "large" interop payloads are sized to spec (~5–7 KB single datagram), under the
  macOS `net.inet.udp.maxdgram` cap (9216). Arbitrarily large data uses Protocol 1
  chunking (multi-packet, reassembled).
- Swift receivers bind a persistent socket for multi-chunk receives (a one-shot
  bind/recv/close per chunk drops back-to-back chunks).

## History

A prior state reported cross-language UDP as untested due to API mismatches and a
broken `test_all_combinations.py` harness. Those were resolved by promoting the YBS
step implementations into `canonical/`, fixing a `Data`-slice indexing bug in the
Swift receivers (the previously-reported "SIGTRAP"), and adding the persistent-socket
multi-chunk receive. The naive `test_all_combinations.py` harness was removed in
favor of `run_matrix.py`.
