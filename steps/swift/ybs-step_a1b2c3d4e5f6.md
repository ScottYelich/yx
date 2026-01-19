# Step 1: Swift Project Setup

**Version**: 0.1.0

## Overview

Set up the Swift Package with dependencies, configuration, and basic directory organization. This creates the foundation for building the YX protocol Swift implementation.

## Step Objectives

1. Create Swift Package manifest (Package.swift)
2. Set up directory structure for sources and tests
3. Configure dependencies (CryptoKit for HMAC/AES)
4. Create initial module structure
5. Verify Swift environment

## Prerequisites

- Step 0 completed (BUILD_CONFIG.json exists)
- Swift {{CONFIG:swift_version}} or later installed
- Swift Package Manager available

## Traceability

**Implements**: specs/architecture/implementation-languages.md § Swift Considerations
**References**: specs/technical/yx-protocol-spec.md (Security requirements)

## Instructions

### 1. Navigate to Build Directory

```bash
cd builds/{{CONFIG:build_name}}
```

### 2. Initialize Swift Package

```bash
swift package init --type library --name YXProtocol
```

### 3. Create Package.swift

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
// Implements: specs/technical/yx-protocol-spec.md

import PackageDescription

let package = Package(
    name: "YXProtocol",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "YXProtocol",
            targets: ["YXProtocol"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "YXProtocol",
            dependencies: [],
            path: "Sources/YXProtocol"
        ),
        .testTarget(
            name: "YXProtocolTests",
            dependencies: ["YXProtocol"],
            path: "Tests/YXProtocolTests"
        ),
    ]
)
```

### 4. Create Directory Structure

```bash
mkdir -p Sources/YXProtocol/Transport
mkdir -p Sources/YXProtocol/Primitives
mkdir -p Tests/YXProtocolTests/Unit
mkdir -p Tests/YXProtocolTests/Integration
```

### 5. Create Initial Module Files

Create `Sources/YXProtocol/YXProtocol.swift`:

```swift
//
//  YXProtocol.swift
//  YX Protocol - Secure UDP-based networking protocol
//
//  Implements: specs/technical/yx-protocol-spec.md
//

import Foundation

/// YX Protocol version
public let version = "0.1.0"
```

### 6. Create README.md

Create `README.md`:

```markdown
# YX Protocol - Swift Implementation

Secure, payload-agnostic UDP-based networking protocol.

## Overview

This is the Swift implementation of the YX protocol as specified in:
- `../../specs/technical/yx-protocol-spec.md`

## Building

```bash
swift build
```

## Running Tests

```bash
swift test
```

## Project Structure

```
Sources/YXProtocol/       # Source code
  Transport/              # UDP transport layer
  Primitives/             # Core data structures
Tests/YXProtocolTests/    # Test suite
  Unit/                   # Unit tests
  Integration/            # Integration tests
```

## Specifications

Built following YBS (Yelich Build System) methodology.

See `../../specs/` for complete specifications.
```

### 7. Create .gitignore (in build directory)

Create `.gitignore`:

```
# Swift
.DS_Store
/.build
/Packages
/*.xcodeproj
xcuserdata/
DerivedData/
.swiftpm/

# Build artifacts
BUILD_STATUS.md
SESSION.md
BUILD_CONFIG.json
docs/build-history/
```

### 8. Build Package

```bash
swift build
```

## Verification

**This step is complete when:**

- [ ] `Package.swift` exists with correct configuration
- [ ] Directory structure created (`Sources/YXProtocol/`, `Tests/YXProtocolTests/`)
- [ ] Initial module file created
- [ ] Package builds successfully
- [ ] Tests can be discovered (even if none exist yet)

**Verification Commands:**

```bash
# Verify Package.swift exists
test -f Package.swift && echo "✓ Package.swift exists"

# Verify directory structure
test -d Sources/YXProtocol/Transport && \
test -d Sources/YXProtocol/Primitives && \
test -d Tests/YXProtocolTests/Unit && \
test -d Tests/YXProtocolTests/Integration && \
echo "✓ Directory structure created"

# Verify package builds
swift build && echo "✓ Package builds successfully"

# Verify tests can run (even with no tests)
swift test && echo "✓ Tests can run"

# Verify module imports
swift run -c release --build-path .build -Xswiftc -I -Xswiftc .build/release <<EOF
import YXProtocol
print("✓ YXProtocol module version: \\(version)")
EOF
```

**Expected Output:**
```
✓ Package.swift exists
✓ Directory structure created
✓ Package builds successfully
✓ Tests can run
✓ YXProtocol module version: 0.1.0
```

**Retry Policy:**
- Maximum 3 attempts
- If swift build fails: Check Swift version, retry
- If directory creation fails: Check permissions, retry
- If 3 failures: STOP and report error

## Notes

- This step creates the foundation for all subsequent Swift steps
- CryptoKit (built-in) provides HMAC-SHA256 and AES-256-GCM
- Swift Package Manager handles dependencies and building
- Directory structure follows Swift best practices
- macOS 13+ and iOS 16+ required for modern async/await support
