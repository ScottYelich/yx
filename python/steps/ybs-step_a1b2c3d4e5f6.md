# Step 1: Python Project Setup

**Version**: 0.1.0

## Overview

Set up the Python project structure with dependencies, configuration files, and basic directory organization. This creates the foundation for building the YX protocol implementation.

## What This Step Builds

Creates the Python project foundation: `pyproject.toml` with all dependencies, `src/yx/primitives/` and `src/yx/transport/` package tree, test directories, and a working `pip install -e .[dev]` environment.

## Step Objectives

1. Create Python project configuration (pyproject.toml)
2. Set up directory structure for source and tests
3. Configure dependencies (cryptography library for HMAC/AES)
4. Create initial package structure
5. Verify Python environment

## Prerequisites

- Step 0 completed (BUILD_CONFIG.json exists)
- Python {{CONFIG:python_version}} or later installed
- pip package manager available

## Traceability

**Implements**: protocol/specs/architecture/implementation-languages.md § Python Considerations
**References**: protocol/specs/technical/yx-protocol-spec.md (Security requirements)

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Navigate to Build Directory

```bash
cd builds/{{CONFIG:build_name}}
```

### 2. Create pyproject.toml

Create `pyproject.toml`:

```toml
[project]
name = "yx-protocol"
version = "0.1.0"
description = "YX UDP Protocol Implementation"
requires-python = ">={{CONFIG:python_version}}"
dependencies = [
    "cryptography>=41.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.1.0",
]

[build-system]
requires = ["setuptools>=68.0.0", "wheel"]
build-backend = "setuptools.build_meta"

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
asyncio_mode = "auto"

[tool.coverage.run]
source = ["src"]
omit = ["tests/*"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
]
```

### 3. Create Directory Structure

```bash
mkdir -p src/yx
mkdir -p src/yx/transport
mkdir -p src/yx/primitives
mkdir -p tests/unit
mkdir -p tests/integration
```

### 4. Create Package __init__.py Files

Create `src/yx/__init__.py`:

```python
"""
YX Protocol - Secure UDP-based networking protocol.

Implements: protocol/specs/technical/yx-protocol-spec.md
"""

__version__ = "0.1.0"
__all__ = []
```

Create `src/yx/transport/__init__.py`:

```python
"""
YX Transport Layer - UDP packet handling.

Implements: protocol/specs/technical/yx-protocol-spec.md § Transport Layer
"""

__all__ = []
```

Create `src/yx/primitives/__init__.py`:

```python
"""
YX Primitives - Core data structures and utilities.

Implements: protocol/specs/technical/yx-protocol-spec.md § Wire Format
"""

__all__ = []
```

Create `tests/__init__.py`:

```python
"""YX Protocol Tests"""
```

Create `tests/unit/__init__.py`:

```python
"""YX Unit Tests"""
```

Create `tests/integration/__init__.py`:

```python
"""YX Integration Tests"""
```

### 5. Install Dependencies

```bash
pip install -e .[dev]
```

### 6. Create README.md

Create `README.md`:

```markdown
# YX Protocol - Python Implementation

Secure, payload-agnostic UDP-based networking protocol.

## Overview

This is the reference Python implementation of the YX protocol as specified in:
- `../../protocol/specs/technical/yx-protocol-spec.md`

## Installation

```bash
pip install -e .[dev]
```

## Running Tests

```bash
pytest
```

## Coverage

```bash
pytest --cov=src --cov-report=html
```

## Project Structure

```
src/yx/              # Source code
  transport/         # UDP transport layer
  primitives/        # Core data structures
tests/               # Test suite
  unit/              # Unit tests
  integration/       # Integration tests
```

## Specifications

Built following YBS (Yelich Build System) methodology.

See `../../protocol/specs/` for complete specifications.
```

### 7. Create .gitignore (in build directory)

Create `.gitignore`:

```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
*.egg-info/
dist/
build/

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# Virtual environments
venv/
env/
ENV/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Build artifacts
BUILD_STATUS.md
SESSION.md
BUILD_CONFIG.json
docs/build-history/
```

## Verification

**This step is complete when:**

- [ ] `pyproject.toml` exists with correct dependencies
- [ ] Directory structure created (`src/yx/`, `src/yx/transport/`, `src/yx/primitives/`, `tests/unit/`, `tests/integration/`)
- [ ] All `__init__.py` files created
- [ ] Dependencies installed successfully
- [ ] Python environment can import `yx` package
- [ ] pytest can discover the test directory

**Verification Commands:**

```bash
# Verify pyproject.toml exists
test -f pyproject.toml && echo "✓ pyproject.toml exists"

# Verify directory structure
test -d src/yx/transport && \
test -d src/yx/primitives && \
test -d tests/unit && \
test -d tests/integration && \
echo "✓ Directory structure created"

# Verify __init__.py files
test -f src/yx/__init__.py && \
test -f src/yx/transport/__init__.py && \
test -f src/yx/primitives/__init__.py && \
echo "✓ Package files created"

# Verify package imports
python3 -c "import yx; print(f'✓ yx package version: {yx.__version__}')"

# Verify cryptography library
python3 -c "from cryptography.hazmat.primitives import hashes, hmac; print('✓ cryptography library available')"

# Verify pytest works
pytest --collect-only && echo "✓ pytest can discover tests"
```

**Expected Output:**
```
✓ pyproject.toml exists
✓ Directory structure created
✓ Package files created
✓ yx package version: 0.1.0
✓ cryptography library available
✓ pytest can discover tests
```

**Retry Policy:**
- Maximum 3 attempts
- If pip install fails: Check internet connection, retry
- If directory creation fails: Check permissions, retry
- If 3 failures: STOP and report error

## Notes

- This step creates the foundation for all subsequent steps
- cryptography library provides HMAC-SHA256 and AES-256-GCM
- pytest-asyncio will be used for async UDP transport tests
- Directory structure follows Python best practices
- Each module has __init__.py for proper package imports

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_a1b2c3d4e5f6-DONE.txt`:

```
STEP ybs-step_a1b2c3d4e5f6: Python Project Setup
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- pyproject.toml
- src/yx/__init__.py
- src/yx/primitives/__init__.py
- src/yx/transport/__init__.py
- tests/__init__.py

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_b2c3d4e5f6a1 (GUID Factory)
```

Update `BUILD_STATUS.md`: mark this step `[x]` and update **Last Updated** timestamp.

## Success Criteria

This step is successful when:
1. All verification checks pass (within 3 attempts)
2. All required files exist and are valid
3. Build compiles/runs without errors
4. DONE file created in `docs/build-history/`
5. `BUILD_STATUS.md` updated

## Next Steps

After completing this step, proceed to:
- **Next**: `ybs-step_b2c3d4e5f6a1` — GUID Factory

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
