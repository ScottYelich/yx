# Python Implementation Build Steps

Build steps for creating the YX protocol Python implementation.

## Overview

These steps guide the AI agent through building a complete Python implementation of the YX protocol, including:
- Core protocol (packet building, parsing, HMAC)
- Transport layer (UDP, asyncio)
- Protocol handlers (Text Protocol 0, Binary Protocol 1)
- Security (HMAC-SHA256, AES-256-GCM, ZLIB compression)
- Comprehensive tests
- Canonical artifact generation

## Step Sequence

Steps will be created in order:

1. **Project Setup** - Create Python project structure, pyproject.toml
2. **Packet Core** - Packet dataclass, GUIDFactory
3. **Packet Builder** - Build, parse, validate packets
4. **HMAC Security** - HMAC-SHA256 computation and validation
5. **Encryption** - AES-256-GCM encryption/decryption
6. **Compression** - ZLIB compression/decompression
7. **UDP Transport** - Socket handling, asyncio integration
8. **Text Protocol** - Protocol 0 handler
9. **Binary Protocol** - Protocol 1 handler (v2.0 with channels)
10. **Protocol Router** - Route packets to correct handler
11. **Security Components** - RateLimiter, ReplayProtection, KeyStore
12. **Unit Tests** - Test all components
13. **Integration Tests** - End-to-end flows
14. **Network Tests** - UDP broadcast, SO_REUSEPORT
15. **Canonical Artifacts** - Generate test vectors for other implementations
16. **Documentation** - README, API docs
17. **Final Verification** - All tests pass, coverage ≥80%

## Target Build Directory

`../../builds/python-impl/`

## Traceability

All steps implement specifications from:
- `../../specs/technical/yx-protocol-spec.md` - Protocol specification
- `../../specs/testing/testing-strategy.md` - Testing requirements
- `../../specs/architecture/implementation-languages.md` - Language guidance

## Canonical Artifact Generation

**Critical Step:** Python implementation generates canonical test vectors

Output to: `../../canonical/test-vectors/`

These artifacts enable other language implementations to validate wire format compatibility.

## Current Status

Steps not yet created. Will be added as part of YBS system development.
