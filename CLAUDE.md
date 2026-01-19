# AI Agent Guide for YX System

## System Overview

**System Name:** YX
**Type:** UDP-based networking protocol
**Purpose:** Secure, payload-agnostic transport layer for distributed systems

## Session Management

**IMPORTANT:** At startup, check for session files in `scratch/`:
- `scratch/SESSION.md` - Contains crash recovery state and context
- If found: Read and resume from saved state
- If not found: Start fresh session

All session files and temporary notes are kept in `scratch/` directory.

## YBS Build Instructions

This is a YBS (Yelich Build System) managed system with **multi-language implementations**.

### 1. Understand the System

Read the specifications in order:
- `specs/technical/yx-protocol-spec.md` - Core protocol specification
- `specs/testing/testing-strategy.md` - Testing requirements
- `specs/architecture/implementation-languages.md` - Language guidance

### 2. Understand the Multi-Language Structure

YX supports multiple language implementations:
- **Python** (`builds/python-impl/`) - Reference implementation, generates canonical artifacts
- **Swift** (`builds/swift-impl/`) - High-performance implementation, validates against canonical artifacts
- **Future** - Rust, Go, etc.

Build steps are organized by language:
- `steps/ybs-step_000000000000.md` - Step 0 (language selection)
- `steps/python/` - Python-specific build steps
- `steps/swift/` - Swift-specific build steps

### 3. Build Workflow

#### Building Python Implementation (First)

1. **Navigate to build directory:**
   ```bash
   cd builds/python-impl/
   ```

2. **Check for crash recovery:**
   - Look for `SESSION.md` in the build directory
   - If found, resume from saved state

3. **Execute Step 0 (Configuration):**
   - Check if `BUILD_CONFIG.json` exists
   - If exists: Load configuration, skip questions
   - If not exists: Ask questions, create BUILD_CONFIG.json
   - Select language: Python

4. **Execute Python Steps 1-N autonomously:**
   - Read step files from `../../steps/python/` in order
   - Replace all `{{CONFIG:key}}` placeholders with BUILD_CONFIG.json values
   - Execute instructions
   - Run verification
   - Proceed automatically to next step (no prompts)

5. **Generate Canonical Artifacts:**
   - Final Python steps generate test vectors → `../../canonical/test-vectors/`
   - Generate reference packets → `../../canonical/reference-packets/`
   - Generate benchmarks → `../../canonical/benchmarks/`

6. **Update status after each step:**
   - Update `BUILD_STATUS.md` with progress
   - Update `SESSION.md` for crash recovery
   - Create step-DONE file in `docs/build-history/`

#### Building Swift Implementation (Second)

1. **Ensure Python build is complete:**
   - Python implementation must be built first
   - Canonical artifacts must exist in `canonical/`

2. **Navigate to build directory:**
   ```bash
   cd builds/swift-impl/
   ```

3. **Execute Step 0 (Configuration):**
   - Select language: Swift
   - Create BUILD_CONFIG.json

4. **Execute Swift Steps 1-N autonomously:**
   - Read step files from `../../steps/swift/` in order
   - Follow same process as Python build

5. **Validate Against Canonical Artifacts:**
   - Load test vectors from `../../canonical/test-vectors/`
   - Verify Swift implementation produces identical results
   - All canonical test vectors MUST pass

6. **Update status after each step**

#### Running Interoperability Tests (Final) ⚠️ MANDATORY - CANNOT SKIP

**Status:** ✅ MANDATORY - Build is NOT complete without passing all interop tests

After both implementations are complete:

1. **Navigate to interop tests:**
   ```bash
   cd tests/interop/
   ```

2. **Run ALL cross-language tests:**
   ```bash
   ./run_all_interop_tests.sh
   ```

3. **Required test matrix (N² tests for N languages):**
   - Python → Python (actual UDP communication)
   - Python → Swift (actual UDP communication)
   - Swift → Python (actual UDP communication)
   - Swift → Swift (actual UDP communication)

4. **Each combination must test 5 scenarios:**
   - Simple payload
   - Empty payload
   - Large payload (≥5KB)
   - Multiple packets (≥10)
   - Invalid key rejection

5. **Total required: 2² × 5 = 20 tests**
   - ALL 20 tests MUST pass
   - No exceptions, no skipping
   - Use real UDP sockets (not mocks)

6. **Wire format compatibility is NOT sufficient:**
   - ❌ Byte-identical packets in memory ≠ interoperability
   - ✅ Must prove actual UDP network communication works

**See:** `specs/testing/interoperability-requirements.md` for complete details

### 4. Build Completion Criteria

A single implementation is complete when:
- All language-specific steps executed successfully
- All verification criteria pass
- BUILD_STATUS.md shows 100% complete
- All unit tests pass (100%)
- All integration tests pass (100%)
- Traceability ≥80%

The **entire YX system** is complete when:
- ✅ Python implementation complete (Steps 0-10)
- ✅ Swift implementation complete (Steps 0-10)
- ✅ Canonical artifacts generated
- ✅ **ALL interop tests pass (20/20 tests)** ⚠️ MANDATORY

**CRITICAL:** The system is NOT complete until all 20 interop tests pass:
- 4 combinations × 5 scenarios = 20 tests
- Real UDP communication verified
- No mocks, no assumptions
- Cannot skip any tests

### 5. Important Rules

- **Always execute Step 0 first** - No exceptions
- **Build Python before Swift** - Python generates canonical artifacts
- **Never skip verification** - Run all verification checks
- **Retry failed steps** - Up to 3 attempts per step
- **Proceed autonomously** - No "ready for next step?" prompts
- **Maintain traceability** - All code must reference specifications
- **Update status files** - Keep BUILD_STATUS.md and SESSION.md current
- **Validate canonical artifacts** - Swift implementation must pass all Python test vectors
- **⚠️ INTEROP TESTS ARE MANDATORY** - Cannot skip, cannot assume compatibility
  - Wire format compatibility ≠ network interoperability
  - Must run all 20 tests (4 combinations × 5 scenarios)
  - Real UDP sockets required (no mocks)
  - Build is NOT complete without passing interop tests

## Directory Structure

```
yx/
├── specs/                       # WHAT to build (language-agnostic)
│   ├── technical/               # Protocol specification
│   ├── testing/                 # Testing requirements
│   └── architecture/            # Design decisions
├── steps/                       # HOW to build (language-specific)
│   ├── ybs-step_000000000000.md # Step 0: Language selection
│   ├── python/                  # Python build steps
│   └── swift/                   # Swift build steps
├── builds/                      # Build workspaces
│   ├── python-impl/             # Python implementation
│   └── swift-impl/              # Swift implementation
├── canonical/                   # Shared reference artifacts
│   ├── test-vectors/            # JSON test cases
│   ├── reference-packets/       # Binary packets
│   └── benchmarks/              # Performance baselines
└── tests/                       # System-level tests
    └── interop/                 # Cross-language tests
```

## Path References

- **YBS Framework:** `../ybs/` (reference documentation)
- **AlgoTrader (example system):** `../sdts/scott/algotrader/`
- **Current system:** `/Users/scottyelich/stuff/algotrader25/2025/yx/`

## Current Status

- ✅ YX protocol specification complete
- ✅ Testing strategy defined
- ✅ Multi-language structure established
- ⏳ Step 0 needs to be created
- ⏳ Python build steps need to be created
- ⏳ Swift build steps need to be created
- ⏳ No builds exist yet

## Key Concepts

### Canonical Artifacts
Python implementation generates reference test vectors that Swift (and future implementations) must validate against. This ensures wire format compatibility across all languages.

### Build Order
1. Python first → generates canonical artifacts
2. Swift second → validates against canonical artifacts
3. Interop tests → verifies cross-language communication

### Wire Format Compatibility
All implementations MUST produce byte-identical packets for the same inputs. This is verified through canonical test vectors and interop tests.
