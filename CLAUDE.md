# AI Agent Guide for YX System

## System Overview

**System Name:** YX
**Type:** UDP-based networking protocol
**Purpose:** Secure, payload-agnostic transport layer for distributed systems

## Session Management

At startup, check for session files in `scratch/`:
- `scratch/SESSION.md` — Contains crash recovery state and context
- If found: Read and resume from saved state
- If not found: Start fresh session

All session files and temporary notes are kept in `scratch/`.

---

## Three-System Structure

YX is organized as **three YBS systems** in one repository:

| System | Directory | What it is |
|---|---|---|
| **YX Protocol** | `protocol/` | Language-agnostic wire format specification |
| **YX Python** | `python/` | Python reference implementation |
| **YX Swift** | `swift/` | Swift high-performance implementation |

Plus shared cross-cutting directories:
- `canonical/` — Promoted reference implementations and test vectors
- `builds/` — Active build workspaces (created by Step 0)
- `tests/interop/` — Cross-language interoperability tests

---

## Understanding the Protocol Specs

Before building any implementation, read the protocol specs:

```
protocol/specs/
├── technical/
│   ├── _BASE.md                     ← Wire format invariants (read first)
│   ├── yx-protocol-spec.md          ← Core protocol specification
│   └── default-values.md            ← Cross-language default values
├── architecture/
│   ├── _BASE.md                     ← Design principles
│   ├── ybs-decisions.md             ← Architecture Decision Records (D01-D07)
│   ├── protocol-layers.md           ← Three-layer architecture
│   ├── api-contracts.md             ← Language-agnostic API contracts
│   └── security-architecture.md    ← Security model
└── testing/
    ├── _BASE.md                     ← Coverage standards
    ├── testing-strategy.md          ← Test requirements
    └── interoperability-requirements.md ← Mandatory 48-test matrix
```

---

## Building the Python Implementation

**Step files:** `python/steps/`
**Step sequence:** `python/steps/STEPS_ORDER.txt`
**Build output:** `builds/python-impl/` (or custom build name)
**Implementation specs:** `python/specs/`

### Workflow

1. **Read specs first:**
   - `protocol/specs/technical/yx-protocol-spec.md`
   - `python/specs/technical/ybs-spec_3f7a9c2e1b4d.md`
   - `python/specs/testing/ybs-spec_8b2d5e9f1a3c.md`

2. **Check for crash recovery:**
   - Look for `builds/<build_name>/SESSION.md`
   - If found, resume from last completed step

3. **Execute Step 0:** `python/steps/ybs-step_000000000000.md`
   - Creates `builds/<build_name>/BUILD_CONFIG.json`, `BUILD_STATUS.md`, `SESSION.md`
   - If `BUILD_CONFIG.json` already exists, skip questions and proceed

4. **Execute Steps 1-15 autonomously** (no prompts between steps):
   - Read each step file from `python/steps/` per STEPS_ORDER.txt
   - Substitute all `{{CONFIG:key}}` placeholders with values from `BUILD_CONFIG.json`
   - Execute instructions
   - Run verification (up to 3 attempts)
   - Create DONE file in `builds/<build_name>/docs/build-history/`
   - Update `BUILD_STATUS.md` and `SESSION.md`
   - Proceed to next step

5. **Canonical Artifacts** (Step 10):
   - Generates `canonical/test-vectors/` JSON files
   - These are the ground truth for Swift validation

---

## Building the Swift Implementation

**Prerequisite:** Python build complete, `canonical/test-vectors/` exists.

**Step files:** `swift/steps/`
**Step sequence:** `swift/steps/STEPS_ORDER.txt`
**Build output:** `builds/swift-impl/` (or custom build name)
**Implementation specs:** `swift/specs/`

### Workflow

1. **Read specs first:**
   - `protocol/specs/technical/yx-protocol-spec.md`
   - `swift/specs/technical/ybs-spec_6c4f2a8d1e7b.md`
   - `swift/specs/testing/ybs-spec_9e1b3c6a4f2d.md`

2. **Execute Step 0:** `swift/steps/ybs-step_000000000000.md`
   - Verifies `canonical/test-vectors/` exists (STOP if missing)
   - Creates build workspace

3. **Execute Steps 1-13 autonomously:**
   - Follow the same autonomous execution pattern as Python
   - Step 7 validates against canonical test vectors

---

## Running Interoperability Tests ⚠️ MANDATORY

**Status:** MANDATORY — Build is NOT complete without passing all 48 tests

After BOTH implementations are complete:

```bash
cd tests/interop/
./run_all_interop_tests.sh
```

### Required Test Matrix (48 tests total)

| Layer | Combinations | Scenarios | Tests |
|---|---|---|---|
| Transport | 4 (P→P, P→S, S→P, S→S) | 5 | 20 |
| Protocol 0 (Text) | 4 | 3 | 12 |
| Protocol 1 (Binary) | 4 | 4 | 16 |
| **Total** | | | **48** |

- ALL 48 tests MUST pass — no exceptions
- Use real UDP sockets (no mocks)
- Wire format compatibility alone is NOT sufficient

**See:** `protocol/specs/testing/interoperability-requirements.md`

---

## Build Completion Criteria

### Single Implementation Complete

- All step verifications pass
- `BUILD_STATUS.md` shows 100% complete
- All unit tests pass
- All integration tests pass
- Code coverage ≥80% overall, 100% on critical paths
- Traceability ≥80%
- All canonical test vectors pass (Swift only)
- DONE files exist for all steps

### Entire YX System Complete

- ✅ Python implementation complete (Steps 0-15)
- ✅ Canonical artifacts generated in `canonical/test-vectors/`
- ✅ Swift implementation complete (Steps 0-13)
- ✅ **ALL 48 interop tests pass** ⚠️ MANDATORY

---

## Important Rules

- **Execute Step 0 first** — No exceptions
- **Build Python before Swift** — Python generates canonical artifacts
- **Never skip verification** — Up to 3 attempts per step
- **Proceed autonomously** — No "ready for next step?" prompts
- **Maintain traceability** — All source files must reference protocol specs
- **Update status files** — Keep `BUILD_STATUS.md` and `SESSION.md` current
- **Create DONE files** — Every step creates a DONE file in `docs/build-history/`
- **⚠️ Interop tests are mandatory** — Cannot skip, cannot assume compatibility

---

## Directory Structure

```
yx/
├── CLAUDE.md
│
├── protocol/                    # System 1: YX Protocol (spec-only)
│   ├── README.md
│   └── specs/
│       ├── technical/           # Wire format, default values
│       │   ├── _BASE.md
│       │   ├── yx-protocol-spec.md
│       │   └── default-values.md
│       ├── architecture/        # Design decisions, ADRs, API contracts
│       │   ├── _BASE.md
│       │   ├── ybs-decisions.md
│       │   ├── protocol-layers.md
│       │   ├── api-contracts.md
│       │   ├── implementation-languages.md
│       │   └── security-architecture.md
│       └── testing/             # Test requirements, interop matrix
│           ├── _BASE.md
│           ├── testing-strategy.md
│           └── interoperability-requirements.md
│
├── python/                      # System 2: Python Implementation
│   ├── README.md
│   ├── specs/                   # Python-specific implementation specs
│   │   ├── technical/
│   │   │   ├── _BASE.md
│   │   │   └── ybs-spec_3f7a9c2e1b4d.md
│   │   └── testing/
│   │       ├── _BASE.md
│   │       └── ybs-spec_8b2d5e9f1a3c.md
│   └── steps/                   # YBS build steps (Steps 0-15)
│       ├── STEPS_ORDER.txt
│       ├── ybs-step_000000000000.md
│       └── ybs-step_<guid>.md   (Steps 1-15)
│
├── swift/                       # System 3: Swift Implementation
│   ├── README.md
│   ├── specs/                   # Swift-specific implementation specs
│   │   ├── technical/
│   │   │   ├── _BASE.md
│   │   │   └── ybs-spec_6c4f2a8d1e7b.md
│   │   └── testing/
│   │       ├── _BASE.md
│   │       └── ybs-spec_9e1b3c6a4f2d.md
│   └── steps/                   # YBS build steps (Steps 0-13)
│       ├── STEPS_ORDER.txt
│       ├── ybs-step_000000000000.md
│       └── ybs-step_<guid>.md   (Steps 1-13)
│
├── builds/                      # Active build workspaces (created by Step 0)
│   ├── python-impl/             # Python build output
│   └── swift-impl/              # Swift build output
│
├── canonical/                   # Promoted reference implementations + artifacts
│   ├── README.md
│   ├── python/                  # Promoted from builds/python-impl/
│   ├── swift/                   # Promoted from builds/swift-impl/
│   └── test-vectors/            # Generated by Python, consumed by Swift
│
└── tests/
    └── interop/                 # Cross-system interop tests (48-test matrix)
```

---

## Key Concepts

### Three-System Model

1. **Protocol system** — defines what YX IS (wire format, security model). Spec-only.
2. **Python system** — defines HOW to build YX in Python. Reference implementation.
3. **Swift system** — defines HOW to build YX in Swift. Validates against Python.

### Canonical Promotion Flow

```
python/steps/ → builds/python-impl/ → (verified) → canonical/python/
swift/steps/  → builds/swift-impl/  → (verified) → canonical/swift/
```

### Path Conventions

- Protocol specs are at `protocol/specs/` (project-root-relative)
- Builds are at `builds/<name>/` (project-root-relative)
- Canonical artifacts at `canonical/test-vectors/` (project-root-relative)
- From a build directory (`builds/<name>/`): protocol specs are at `../../protocol/specs/`

---

## References

- YBS Framework: `../ybs/`
- Python canonical implementation: `canonical/python/`
- Swift canonical implementation: `canonical/swift/`
