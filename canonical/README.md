# Canonical Artifacts

This directory contains language-agnostic reference artifacts that all YX implementations must validate against.

## Purpose

Canonical artifacts ensure wire format compatibility across all language implementations. When multiple implementations exist (Python, Swift, Rust, etc.), they must all produce and consume identical packets.

## Directory Structure

### test-vectors/
**Purpose:** JSON-formatted test cases with expected inputs and outputs

**Contents:**
- `text-protocol-packets.json` - Text protocol (Protocol 0) test cases
- `binary-protocol-packets.json` - Binary protocol (Protocol 1) test cases
- `hmac-test-vectors.json` - HMAC computation test cases
- `encryption-test-vectors.json` - AES-256-GCM encryption test cases
- `compression-test-vectors.json` - ZLIB compression test cases

**Format Example:**
```json
{
  "version": "1.0.0",
  "test_cases": [
    {
      "name": "Simple text protocol packet",
      "guid": "010203040506",
      "key": "0000000000000000000000000000000000000000000000000000000000000000",
      "payload_hex": "007B226D6574686F64223A2274657374227D",
      "expected_hmac": "a1b2c3d4e5f6...",
      "expected_packet_hex": "a1b2c3d4e5f6...010203040506007B226D..."
    }
  ]
}
```

### reference-packets/
**Purpose:** Binary packet files for byte-level validation

**Contents:**
- `packet-*.bin` - Raw binary packets
- `README.txt` - Describes each packet file

**Usage:** Load binary file, parse as YX packet, validate structure

### benchmarks/
**Purpose:** Performance baselines for comparison

**Contents:**
- `throughput-baseline.json` - Messages per second by protocol type
- `latency-baseline.json` - Round-trip times
- `memory-baseline.json` - Memory usage patterns

**Format Example:**
```json
{
  "version": "1.0.0",
  "implementation": "Python",
  "timestamp": "2026-01-18T20:45:00Z",
  "benchmarks": {
    "text_protocol_throughput": {
      "messages_per_second": 10000,
      "avg_latency_ms": 0.1,
      "p99_latency_ms": 0.5
    }
  }
}
```

## Workflow

### Generating Canonical Artifacts (First Implementation)

Typically the **Python implementation** (reference) generates these:

1. Build completes Python implementation
2. Run canonical artifact generation step
3. Export test vectors, reference packets, benchmarks to `canonical/`
4. Commit to repository

### Validating Against Canonical Artifacts (Subsequent Implementations)

When building **Swift** (or other language):

1. Load test vectors from `canonical/test-vectors/`
2. For each test case:
   - Parse packet with Swift implementation
   - Verify HMAC matches expected
   - Verify payload matches expected
3. All test vectors MUST pass
4. Generate own benchmarks, compare to baseline

## Version Control

**Should canonical artifacts be committed?**

✅ **YES** - Commit to repository:
- Provides known-good reference for all implementations
- Enables offline validation
- Documents expected behavior

**Update when:**
- Protocol version changes
- Bug fixes in reference implementation
- Additional test coverage needed

## Validation Requirements

All YX implementations MUST:
- Parse all test vectors successfully
- Produce identical HMAC values
- Produce identical packet bytes for same inputs
- Pass all cryptographic test vectors
- Meet or exceed benchmark baselines (within reason)

## Creating New Test Vectors

When adding test coverage:

1. Create test case in reference implementation
2. Export to appropriate JSON file in `test-vectors/`
3. Document the test case purpose
4. Update this README with new test vector file
5. Commit changes

## Cross-Implementation Testing

After canonical artifacts exist:
- See `../tests/interop/` for cross-language validation tests
- Interop tests use canonical artifacts as ground truth
