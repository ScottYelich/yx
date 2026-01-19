# YX System

**YX** is a secure, payload-agnostic UDP-based networking protocol with HMAC integrity, optional encryption/compression, and chunked delivery for large messages.

## Overview

YX provides a lightweight, secure transport layer for distributed systems:
- UDP broadcast-based communication
- HMAC-SHA256 packet integrity
- Optional AES-256-GCM encryption
- Optional ZLIB compression
- Multi-packet chunking for large messages
- Channel-based message isolation (65K channels)
- Cross-platform wire format (Python/Swift parity)

## This is a YBS System

This directory follows the YBS (Yelich Build System) structure:

- `specs/` - Specifications defining WHAT YX is and does
- `steps/` - Build steps defining HOW to implement YX
- `builds/` - Build workspaces for different YX implementations
- `docs/` - Additional documentation

## Getting Started

To build YX using YBS:

1. Read the specifications in `specs/`
2. Review the build steps in `steps/`
3. Execute Step 0 to configure your build
4. Let the AI agent execute steps 1-N autonomously

## Current Status

- **Specifications**: In progress
- **Build Steps**: Not yet defined
- **Builds**: None yet

## Reference Documentation

- `docs/ybs-overview.md` - Introduction to YBS framework
- `docs/ybs-framework-spec.md` - Complete YBS framework specification
- `specs/technical/yx-protocol-spec.md` - YX UDP protocol specification
