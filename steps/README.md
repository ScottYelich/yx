# YX Build Steps

This directory contains the sequential build steps for implementing the YX protocol.

## Organization

Build steps are organized by implementation language:

```
steps/
├── STEPS_ORDER.txt              # Execution order (points to Step 0)
├── ybs-step_000000000000.md     # Step 0: Build Configuration (language selection)
├── python/                      # Python-specific build steps
│   ├── ybs-step_<guid>.md       # Step 1: Python project setup
│   ├── ybs-step_<guid>.md       # Step 2: Python packet builder
│   └── ...                      # More Python steps
└── swift/                       # Swift-specific build steps
    ├── ybs-step_<guid>.md       # Step 1: Swift project setup
    ├── ybs-step_<guid>.md       # Step 2: Swift packet builder
    └── ...                      # More Swift steps
```

## Step 0: Build Configuration

**File:** `ybs-step_000000000000.md`

**Purpose:** Collect configuration and determine which language-specific step sequence to execute

**Key Configuration:**
- `{{CONFIG:language|choice[Python,Swift,Both]|Implementation language|Python}}`
- `{{CONFIG:target_build|string|Build directory name|python-impl}}`

Based on language selection, Step 0 directs the AI agent to the appropriate step sequence.

## Language-Specific Steps

### Python Steps (`python/`)
Steps for building the Python implementation of YX protocol.

**Sequence will include:**
- Project setup (pyproject.toml, directory structure)
- Core protocol implementation (packet building, parsing)
- Transport layer (UDP, asyncio)
- Protocol handlers (Text, Binary)
- Security primitives (HMAC, AES-GCM, compression)
- Tests (unit, integration, network)
- Canonical artifact generation
- Documentation

### Swift Steps (`swift/`)
Steps for building the Swift implementation of YX protocol.

**Sequence will include:**
- Project setup (Package.swift, directory structure)
- Core protocol implementation (packet building, parsing)
- Transport layer (UDP, async/await)
- Protocol handlers (Text, Binary)
- Security primitives (CryptoKit HMAC, AES-GCM)
- Tests (XCTest unit tests, integration tests)
- Canonical artifact validation
- Documentation

## Execution Flow

### Building Python Implementation
```
1. Execute Step 0 → Select "Python"
2. Follow steps in python/
3. Generate canonical artifacts to ../../canonical/
4. Complete build in builds/python-impl/
```

### Building Swift Implementation
```
1. Execute Step 0 → Select "Swift"
2. Follow steps in swift/
3. Validate against canonical artifacts from ../../canonical/
4. Complete build in builds/swift-impl/
```

### Building Both
```
1. Execute Step 0 → Select "Both"
2. Build Python first (generates canonical artifacts)
3. Build Swift second (validates against canonical artifacts)
4. Run interop tests from ../../tests/interop/
```

## Step Dependencies

- All Python steps depend on Step 0
- All Swift steps depend on Step 0
- Swift canonical validation step depends on Python canonical generation step (if both are built)
- Interop tests depend on both implementations being complete

## Current Status

- **Step 0:** Not yet created
- **Python steps:** Not yet created
- **Swift steps:** Not yet created

Steps will be created following the YBS step template format with:
- Clear objectives
- Detailed instructions
- Explicit verification criteria
- Configuration markers
- Traceability to specifications
