# YX Build Workflow

## Overview

This document describes the practical workflow for building YX implementations using YBS, testing them, and promoting working code to canonical reference.

## Directory Structure Philosophy

```
yx/
├── specs/              # WHAT to build (committed)
├── steps/              # HOW to build (committed)
├── builds/             # BUILD WORKSPACES (NOT committed, .gitignored)
│   ├── python-impl/    # Temporary Python build
│   └── swift-impl/     # Temporary Swift build
├── canonical/          # REFERENCE ARTIFACTS (committed)
│   ├── test-vectors/   # JSON test cases
│   ├── python/         # Working Python implementation (reference)
│   └── swift/          # Working Swift implementation (reference)
└── tests/interop/      # Cross-language tests (committed)
```

**Key Concept:** `builds/` is a workspace (like `/tmp`), `canonical/` is the promoted, working reference code.

## Phase 1: Build Python Implementation

### Step 1: Create Python Build Workspace

```bash
cd /Users/scottyelich/stuff/algotrader25/2025/yx

# AI agent executes Step 0
# This creates builds/python-impl/ with BUILD_CONFIG.json
```

**How to execute:** Point AI agent at the yx directory and say:
> "Build the Python implementation. Start with Step 0, language=Python, build_name=python-impl."

### Step 2: AI Executes Python Steps 1-10 Autonomously

The AI agent will:
1. Read `steps/python/STEPS_ORDER.txt`
2. Execute each step sequentially
3. Run all tests at each step
4. Verify 100% coverage
5. Update BUILD_STATUS.md
6. Generate canonical test vectors in Step 10

**Build artifacts created in:** `builds/python-impl/`

```
builds/python-impl/
├── BUILD_CONFIG.json
├── BUILD_STATUS.md
├── pyproject.toml
├── src/yx/
│   ├── transport/
│   │   ├── packet.py
│   │   ├── packet_builder.py
│   │   └── udp_socket.py
│   └── primitives/
│       ├── guid_factory.py
│       └── data_crypto.py
└── tests/
    ├── unit/
    └── integration/
```

### Step 3: Test Python Implementation Thoroughly

```bash
cd builds/python-impl

# Run all tests
pytest -v

# Check coverage
pytest --cov=src --cov-report=term-missing

# Run integration tests
pytest tests/integration/ -v

# Generate canonical artifacts (Step 10)
python3 tests/generate_canonical.py
```

**Verification criteria:**
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code coverage ≥ 80%
- [ ] Canonical test vectors generated in `../../canonical/test-vectors/`
- [ ] No errors when running the implementation

### Step 4: Promote Python to Canonical

Once Python implementation is working:

```bash
# Create canonical Python directory
mkdir -p canonical/python

# Copy working implementation
cp -r builds/python-impl/src/yx canonical/python/
cp -r builds/python-impl/tests canonical/python/
cp builds/python-impl/pyproject.toml canonical/python/
cp builds/python-impl/README.md canonical/python/

# Verify test vectors were generated
ls -lh canonical/test-vectors/text-protocol-packets.json
```

**What gets promoted:**
- ✅ Working source code (`src/yx/`)
- ✅ All tests (`tests/`)
- ✅ Configuration (`pyproject.toml`)
- ✅ Documentation (`README.md`)
- ❌ Build artifacts (`.pytest_cache`, `__pycache__`, etc.)

### Step 5: Commit Canonical Python

```bash
git add canonical/python/
git add canonical/test-vectors/
git commit -m "Add canonical Python implementation

- Complete YX protocol implementation
- All tests passing (100% coverage)
- Generated canonical test vectors
- Reference implementation for other languages
"
git push
```

## Phase 2: Build Swift Implementation

### Step 1: Create Swift Build Workspace

```bash
# AI agent executes Step 0 for Swift
```

**How to execute:** Point AI agent at the yx directory and say:
> "Build the Swift implementation. Start with Step 0, language=Swift, build_name=swift-impl."

### Step 2: AI Executes Swift Steps 1-10 Autonomously

The AI agent will:
1. Read `steps/swift/STEPS_ORDER.txt`
2. Execute each step sequentially
3. Run XCTests at each step
4. Validate against canonical test vectors in Step 9
5. Run integration tests in Step 10

**Build artifacts created in:** `builds/swift-impl/`

```
builds/swift-impl/
├── BUILD_CONFIG.json
├── BUILD_STATUS.md
├── Package.swift
├── Sources/YXProtocol/
│   ├── Transport/
│   │   ├── Packet.swift
│   │   ├── PacketBuilder.swift
│   │   └── UDPSocket.swift
│   └── Primitives/
│       ├── GUIDFactory.swift
│       └── DataCrypto.swift
└── Tests/YXProtocolTests/
    ├── Unit/
    └── Integration/
```

### Step 3: Test Swift Implementation

```bash
cd builds/swift-impl

# Run all tests
swift test

# Run specific test suites
swift test --filter CanonicalValidationTests  # CRITICAL: Must pass!
swift test --filter PacketFlowTests

# Build in release mode
swift build -c release
```

**Verification criteria:**
- [ ] All XCTests pass
- [ ] Canonical validation tests pass (proves wire format compatibility)
- [ ] Integration tests pass
- [ ] Builds in release mode

### Step 4: Promote Swift to Canonical

Once Swift implementation is working:

```bash
# Create canonical Swift directory
mkdir -p canonical/swift

# Copy working implementation
cp -r builds/swift-impl/Sources canonical/swift/
cp -r builds/swift-impl/Tests canonical/swift/
cp builds/swift-impl/Package.swift canonical/swift/
cp builds/swift-impl/README.md canonical/swift/
```

### Step 5: Commit Canonical Swift

```bash
git add canonical/swift/
git commit -m "Add canonical Swift implementation

- Complete YX protocol implementation
- All tests passing
- Wire format compatible with Python (validated)
- Reference implementation for Swift/iOS
"
git push
```

## Phase 3: Cross-Language Validation

### Interoperability Tests

Create actual interop test scripts (these would be created as part of a future step):

Create `tests/interop/test-python-to-swift.sh`:

```bash
#!/bin/bash
# Test Python sender → Swift receiver

set -e

echo "Testing Python → Swift interoperability..."

# Start Swift receiver in background
cd ../../canonical/swift
swift run receiver --port 50100 &
RECEIVER_PID=$!

sleep 2

# Send from Python
cd ../../canonical/python
python3 -m sender --port 50100 --message '{"method":"test","params":{}}'

# Check receiver got message
sleep 1

# Cleanup
kill $RECEIVER_PID

echo "✓ Python → Swift test passed"
```

Run interop tests:

```bash
cd tests/interop
./test-python-to-swift.sh
./test-swift-to-python.sh
```

## YBS-Compatible Execution Methods

### Method 1: Manual AI Invocation (Recommended)

**For each step:**
1. User points AI at the build directory
2. User says: "Execute Step N" or "Continue to next step"
3. AI reads step file, executes instructions, runs verification
4. AI updates BUILD_STATUS.md
5. User reviews output, then proceeds to next step

**Pros:** Full control, can inspect at each step
**Cons:** Requires user interaction between steps

### Method 2: Autonomous AI Execution (Pure YBS)

**One-shot execution:**

User says to AI:
> "Build the complete Python implementation. Start with Step 0 (language=Python, build_name=python-impl), then autonomously execute all steps 1-10 without stopping. Run all tests. Generate canonical artifacts. Report when complete."

AI executes all steps without interruption.

**Pros:** True autonomous execution (core YBS principle)
**Cons:** Less visibility into process, harder to debug failures

### Method 3: Helper Script (YBS-Compatible)

Create `scripts/build-helper.sh`:

```bash
#!/bin/bash
# Helper script to drive YBS builds
# This script INVOKES the AI agent for each step

SYSTEM_DIR="/Users/scottyelich/stuff/algotrader25/2025/yx"
BUILD_NAME="$1"
LANGUAGE="$2"

if [ -z "$BUILD_NAME" ] || [ -z "$LANGUAGE" ]; then
    echo "Usage: $0 <build-name> <language>"
    echo "Example: $0 python-impl Python"
    exit 1
fi

cd "$SYSTEM_DIR"

echo "Starting YBS build: $BUILD_NAME ($LANGUAGE)"

# Step 0: Configuration
echo "=== Step 0: Build Configuration ==="
echo "MANUAL: Point AI at $SYSTEM_DIR and execute Step 0"
echo "Config: language=$LANGUAGE, build_name=$BUILD_NAME"
read -p "Press enter when Step 0 is complete..."

# Steps 1-N: Read from STEPS_ORDER.txt and prompt for each
STEPS_FILE="steps/${LANGUAGE,,}/STEPS_ORDER.txt"

if [ ! -f "$STEPS_FILE" ]; then
    echo "Error: $STEPS_FILE not found"
    exit 1
fi

# Parse step files (skip comments)
STEP_NUM=1
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    # Extract step file name
    STEP_FILE=$(echo "$line" | awk '{print $NF}')

    echo ""
    echo "=== Step $STEP_NUM: $STEP_FILE ==="
    echo "MANUAL: Ask AI to execute steps/${LANGUAGE,,}/$STEP_FILE"
    echo "BUILD_DIR: builds/$BUILD_NAME"
    read -p "Press enter when step is complete..."

    STEP_NUM=$((STEP_NUM + 1))
done < <(grep "^ybs-step_" "$STEPS_FILE")

echo ""
echo "✓ All steps complete!"
echo "Next: Test thoroughly, then promote to canonical/"
```

**Usage:**
```bash
./scripts/build-helper.sh python-impl Python
```

**Pros:** Structured walkthrough, checkpoints at each step
**Cons:** Still requires AI invocation for each step

## Recommended Workflow

### For Python (Reference Implementation):

```bash
# 1. Start build
# Tell AI: "Build Python implementation, start with Step 0,
#          language=Python, build_name=python-impl"

# 2. AI executes Steps 0-10 autonomously
# (You can optionally checkpoint after each step)

# 3. Verify build
cd builds/python-impl
pytest --cov=src --cov-report=html
open htmlcov/index.html  # Review coverage

# 4. Test canonical generation
python3 tests/generate_canonical.py
cat ../../canonical/test-vectors/text-protocol-packets.json | jq

# 5. Promote to canonical
mkdir -p ../../canonical/python
cp -r src/yx ../../canonical/python/
cp -r tests ../../canonical/python/
cp pyproject.toml README.md ../../canonical/python/

# 6. Commit
cd ../..
git add canonical/python canonical/test-vectors
git commit -m "Canonical Python implementation"
git push
```

### For Swift (Validates Against Python):

```bash
# 1. Ensure Python canonical exists
test -d canonical/python || echo "ERROR: Build Python first!"

# 2. Start build
# Tell AI: "Build Swift implementation, start with Step 0,
#          language=Swift, build_name=swift-impl"

# 3. AI executes Steps 0-10 autonomously
# Step 9 will validate against canonical/test-vectors/

# 4. Verify build
cd builds/swift-impl
swift test --filter CanonicalValidationTests  # MUST PASS!

# 5. Promote to canonical
mkdir -p ../../canonical/swift
cp -r Sources Tests Package.swift README.md ../../canonical/swift/

# 6. Commit
cd ../..
git add canonical/swift
git commit -m "Canonical Swift implementation"
git push
```

## Update .gitignore

Ensure builds/ is ignored but canonical/ is tracked:

```gitignore
# In .gitignore:

# Build workspaces (temporary)
builds/*/
!builds/README.md

# Canonical is tracked (these are negations - DO track)
!canonical/python/
!canonical/swift/
!canonical/test-vectors/
```

## Summary

**YBS Workflow:**
1. **Workspace builds** (temporary) → `builds/<name>/`
2. **Test thoroughly** → All tests must pass
3. **Promote to canonical** → `canonical/<language>/`
4. **Commit canonical** → Reference implementations

**Key Principle:** `builds/` is ephemeral (like `target/` or `.build/`), `canonical/` is the permanent, working reference code.

This stays true to YBS while providing practical workflow for reference implementations.
