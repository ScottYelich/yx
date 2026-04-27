#!/bin/bash
# Build Swift interoperability test programs
# Traceability: specs/testing/interoperability-requirements.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Swift interop test programs..."
swift build

echo ""
echo "Build complete! Executables available in .build/debug/"
echo ""
echo "Senders (12):"
echo "  Transport: swift-sender-transport-{simple,empty,large,multiple,invalid}"
echo "  Proto0:    swift-sender-proto0-{json,large,invalid}"
echo "  Proto1:    swift-sender-proto1-{base,compressed,encrypted,both}"
echo ""
echo "Receivers (3):"
echo "  swift-receiver-{transport,proto0,proto1}"
echo ""
