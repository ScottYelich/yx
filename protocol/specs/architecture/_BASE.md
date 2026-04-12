# Architecture Specifications — System-Wide Defaults

**System**: YX Protocol
**Category**: Architecture
**Type**: BASE (applies to all architecture specs in this category)
**Version**: 0.1.0
**Last Updated**: 2026-04-11

## Design Principles

These principles govern all architectural decisions in the YX protocol. Every
ADR and architecture spec must be consistent with these principles.

### P1 — Payload Agnostic

The transport layer carries opaque bytes. It has no knowledge of payload
semantics. Protocol layers above transport interpret payload content.

### P2 — Security by Default

Every packet is authenticated via HMAC. There is no unauthenticated mode.
Replay protection and rate limiting are mandatory components, not optional.

### P3 — Wire Format Stability

The binary packet format is stable. Changes that break byte-level compatibility
with existing implementations require an explicit ADR and version increment.

### P4 — Multi-Language Parity

All implementations in all languages must produce and consume identical wire
formats. Feature parity is required: a capability defined in one implementation
is a requirement for all others.

### P5 — Separation of Concerns

The three layers (Transport, Protocol 0 Text, Protocol 1 Binary) are independent.
Higher layers depend on lower layers but not vice versa.

## Layering Constraints

```
Protocol 1 (Binary)  ─┐
                       ├─ Transport Layer (UDP + HMAC)
Protocol 0 (Text)   ─┘
```

- Transport layer: packet framing, HMAC auth, GUID, UDP I/O
- Protocol 0: JSON/text payload routing
- Protocol 1: binary chunked payload with optional compression/encryption
- Layers do not bypass each other

## Decision Records

All architectural decisions are recorded in `ybs-decisions.md` as ADRs (D01, D02...).
New decisions must be documented there before implementation begins.
