# Step 1: Python Project Setup

**Version**: 0.1.0

## Overview

Set up the Python project structure with dependencies, configuration files, and basic directory organization. This creates the foundation for building the YX protocol implementation.

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

**Implements**: specs/architecture/implementation-languages.md § Python Considerations
**References**: specs/technical/yx-protocol-spec.md (Security requirements)

## Instructions

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

Implements: specs/technical/yx-protocol-spec.md
"""

__version__ = "0.1.0"
__all__ = []
```

Create `src/yx/transport/__init__.py`:

```python
"""
YX Transport Layer - UDP packet handling.

Implements: specs/technical/yx-protocol-spec.md § Transport Layer
"""

__all__ = []
```

Create `src/yx/primitives/__init__.py`:

```python
"""
YX Primitives - Core data structures and utilities.

Implements: specs/technical/yx-protocol-spec.md § Wire Format
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
- `../../specs/technical/yx-protocol-spec.md`

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

See `../../specs/` for complete specifications.
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
