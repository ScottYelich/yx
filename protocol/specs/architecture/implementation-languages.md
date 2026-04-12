# YX Implementation Languages

**Version:** 0.1.0
**Last Updated:** 2026-01-18

## Overview

This document specifies the programming languages supported for YX protocol implementations and provides guidance on language selection.

## Reference Implementation

The YX protocol was originally developed as part of the AlgoTrader system (`../sdts/scott/algotrader`).

### Reference Implementation Language Distribution

| Language | Files | Percentage | Purpose |
|----------|-------|------------|---------|
| Python | 231 | 93% | Core framework, services, dashboard, algorithms |
| Swift | 17 | 7% | High-performance services, algorithms |
| Bash | 30+ | N/A | Testing, deployment, system utilities |

**Key Finding:** Python is the primary implementation language, with Swift used selectively for performance-critical components.

---

## Supported Implementation Languages

### Tier 1: Primary Languages (Reference Implementations)

#### Python
- **Status:** Reference implementation exists
- **Location:** `../sdts/src/python/yx/`
- **Version:** Python 3.11+
- **Use Cases:**
  - General-purpose YX applications
  - Service frameworks
  - Rapid prototyping
  - Dashboard and UI applications
- **Advantages:**
  - Comprehensive asyncio support
  - Rich ecosystem (pytest, cryptography library)
  - Fast development cycle
  - Cross-platform
- **Package Requirements:**
  - `cryptography` (HMAC, AES-256-GCM)
  - `asyncio` (async/await support)

#### Swift
- **Status:** Reference implementation exists
- **Location:** `../sdts/src/swift/yx/`
- **Version:** Swift 5.9+
- **Use Cases:**
  - High-performance services
  - Low-latency applications
  - macOS/iOS native applications
  - Memory-constrained environments
- **Advantages:**
  - Native performance (compiled)
  - Strong type safety
  - Excellent async/await support
  - Apple ecosystem integration
- **Package Requirements:**
  - `CryptoKit` (HMAC, AES-GCM)
  - Foundation (networking)

### Tier 2: Planned Languages (No Reference Implementation)

#### Rust
- **Status:** Planned, not yet implemented
- **Use Cases:**
  - Ultra-low-latency applications
  - Systems programming
  - Embedded systems
  - Security-critical applications
- **Advantages:**
  - Memory safety without GC
  - Zero-cost abstractions
  - Fearless concurrency
- **Recommended Crates:**
  - `tokio` (async runtime)
  - `ring` or `rustcrypto` (cryptography)
  - `serde` (serialization)

#### Go
- **Status:** Planned, not yet implemented
- **Use Cases:**
  - Microservices
  - Cloud-native applications
  - Concurrent systems
- **Advantages:**
  - Built-in concurrency (goroutines)
  - Fast compilation
  - Excellent standard library
  - Cross-compilation
- **Recommended Packages:**
  - Standard library `crypto` (HMAC, AES-GCM)
  - `encoding/json` (JSON handling)

#### JavaScript/TypeScript
- **Status:** Planned, not yet implemented
- **Use Cases:**
  - Web applications
  - Node.js services
  - Browser-based clients
- **Advantages:**
  - Universal (browser + server)
  - Large ecosystem
  - TypeScript type safety
- **Recommended Packages:**
  - `crypto` (Node.js crypto module)
  - `dgram` (UDP sockets)

#### C/C++
- **Status:** Planned, not yet implemented
- **Use Cases:**
  - Embedded systems
  - Legacy system integration
  - Maximum performance
- **Advantages:**
  - Direct hardware access
  - Minimal overhead
  - Legacy interop
- **Recommended Libraries:**
  - OpenSSL (cryptography)
  - libsodium (cryptography alternative)

---

## Language Selection Guidelines

### When to Use Python
✅ **Choose Python when:**
- Development speed is priority
- Integration with Python ecosystem needed
- Prototyping or proof-of-concept
- Dashboard/UI applications
- Data processing workloads
- Team is Python-experienced

❌ **Avoid Python when:**
- Ultra-low latency required (<1ms)
- Memory footprint critical (<50MB)
- CPU-intensive continuous processing

### When to Use Swift
✅ **Choose Swift when:**
- Performance is critical
- macOS/iOS native app
- Low memory footprint needed
- Type safety is priority
- Apple ecosystem integration

❌ **Avoid Swift when:**
- Cross-platform deployment (Linux/Windows)
- Team lacks Swift experience
- Rapid prototyping needed

### When to Use Rust (Future)
✅ **Choose Rust when:**
- Maximum performance required
- Memory safety without GC critical
- Embedded/systems programming
- Security-critical applications

❌ **Avoid Rust when:**
- Team lacks Rust experience
- Rapid development needed
- Simple use case (overkill)

### When to Use Go (Future)
✅ **Choose Go when:**
- Microservices architecture
- Cloud-native deployment
- Concurrency-heavy workload
- Fast compilation needed

❌ **Avoid Go when:**
- Complex type systems needed
- Generics required (limited support)

---

## Wire Format Compatibility

**CRITICAL REQUIREMENT:** All language implementations MUST produce identical wire format.

### Verification Process

1. **Reference Packet Generation:**
   - Use Python implementation to generate test packets
   - Document exact byte sequences

2. **New Implementation Validation:**
   - Generate same logical message in new language
   - Compare byte-for-byte with reference
   - Verify HMAC matches
   - Verify payload structure matches

3. **Cross-Language Testing:**
   - Python sender → New language receiver
   - New language sender → Python receiver
   - Verify message integrity and parsing

### Test Vector Example

```
Message: {"method": "test", "params": {}}
Key: 32 bytes of 0x00
GUID: 0x010203040506

Expected Packet (hex):
HMAC:    [16 bytes - computed]
GUID:    01 02 03 04 05 06
Payload: 00 7B 22 6D 65 74 68 6F 64 22 3A 22 74 65 73 74 22 2C ...
```

---

## Performance Characteristics

Based on reference implementation and language characteristics:

| Language | Latency | Throughput | Memory | Startup |
|----------|---------|------------|--------|---------|
| Python | ~1-5ms | ~10K msg/s | ~50-100MB | ~100ms |
| Swift | ~0.1-1ms | ~50K msg/s | ~20-50MB | ~10ms |
| Rust (est) | ~0.05-0.5ms | ~100K+ msg/s | ~5-20MB | ~1ms |
| Go (est) | ~0.1-1ms | ~50K msg/s | ~20-50MB | ~10ms |

*Note: Estimates based on typical language characteristics; actual performance depends on implementation quality.*

---

## Language-Specific Considerations

### Python Considerations
- **Asyncio:** Use `asyncio` for non-blocking I/O
- **GIL:** Global Interpreter Lock limits CPU parallelism (not an issue for I/O-bound YX)
- **Type Hints:** Use type hints for better code quality (`typing` module)
- **Packaging:** Use `pyproject.toml` for modern Python packaging

### Swift Considerations
- **Async/Await:** Use Swift 5.5+ structured concurrency
- **Package Manager:** Use Swift Package Manager (SPM)
- **Platform:** macOS 12+ required for full async/await support
- **Linux Support:** Limited but improving (Swift on Linux)

### Future Language Considerations

#### Rust
- **Async Runtime:** Tokio is de facto standard
- **Error Handling:** Use `Result<T, E>` for all fallible operations
- **Memory Model:** Leverage ownership for zero-copy operations

#### Go
- **Goroutines:** One goroutine per connection pattern
- **Context:** Use `context.Context` for cancellation
- **Error Handling:** Explicit error returns

---

## Implementation Priority

### Phase 1: Reference Implementations (Complete)
- ✅ Python (complete)
- ✅ Swift (complete)

### Phase 2: High-Priority Languages
- Rust (high performance, embedded)
- Go (cloud-native, microservices)

### Phase 3: Ecosystem Languages
- JavaScript/TypeScript (web/Node.js)
- C/C++ (embedded, legacy)

### Phase 4: Additional Languages (As Needed)
- Java/Kotlin (Android, enterprise)
- C# (Windows, Unity)
- Elixir (distributed systems)

---

## Porting Guidelines

When implementing YX in a new language:

1. **Start with Protocol Spec:** Read `../technical/yx-protocol-spec.md` thoroughly
2. **Implement Core First:** Packet building/parsing before protocols
3. **Test Incrementally:** Unit test each component
4. **Verify Wire Format:** Compare with reference implementation
5. **Add Protocol Support:** Text protocol, then Binary protocol
6. **Test Interoperability:** Cross-language message exchange
7. **Document Differences:** Any language-specific considerations

### Reference Implementation as Guide

- **Study:** `../sdts/src/python/yx/` for Python patterns
- **Study:** `../sdts/src/swift/yx/` for Swift patterns
- **Compare:** See how each handles async, crypto, networking
- **Test Against:** Use existing tests as validation

---

## Summary

YX is designed to be **language-agnostic at the protocol level** while providing **idiomatic implementations** in each supported language.

**Current Status:**
- Python: Reference implementation, production-ready
- Swift: Reference implementation, production-ready
- Others: Planned, following wire format specification

**Selection Criteria:**
- Python for general use, rapid development
- Swift for performance, Apple ecosystem
- Future languages for specific use cases

All implementations must maintain **wire format compatibility** verified through cross-language testing.
