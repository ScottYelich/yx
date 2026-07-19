# YX Framework - Testing Guide

## Setup

### Install Dependencies

The YX framework requires the `cryptography` library. It's already installed in the `yx-dev` pyenv environment.

### Python Environment

This project uses **pyenv** for Python environment management. The `yx-dev` environment has all dependencies installed.

---

## Quick Start

### Option 1: Use Full Path (Always Works)

```bash
# Run CLI
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9999

# Run tests
~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py two-peer
```

### Option 2: Configure pyenv in Shell (Recommended)

Add to your `~/.zshrc` (or `~/.bashrc` for bash):

```bash
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```

Then restart your shell or run:
```bash
source ~/.zshrc
```

Now when you're in the `src/python` directory, pyenv will automatically use the `yx-dev` environment (thanks to `.python-version` file).

You can then use just `python`:
```bash
python -m yxCLI --port 9999
python scripts/test-p2p.py two-peer
```

---

## Running Tests

### Automated P2P Tests

The `scripts/test-p2p.py` script runs automated multi-instance tests:

```bash
# Two-peer communication test
~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py two-peer

# Test all 4 protocol variants (0x00-0x03)
~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py proto-opts

# Three-peer mesh network test
~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py three-mesh
```

Logs are saved to `p2p-test-logs/` directory.

### Manual Multi-Instance Testing

**Terminal 1 (Hub on port 9999):**
```bash
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9999
```

**Terminal 2 (Sender on port 9998):**
```bash
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9998 --peers localhost:9999 --shutdown-after 10
```

**Terminal 3 (Binary protocol test with compression + encryption):**
```bash
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9997 --peers localhost:9999 --proto-opts 0x03 --shutdown-after 10
```

### Unit Tests

Run pytest unit tests:

```bash
# All tests
~/.pyenv/versions/yx-dev/bin/python -m pytest tests/ -v

# Just primitives tests
~/.pyenv/versions/yx-dev/bin/python -m pytest tests/test_primitives/ -v

# Specific test file
~/.pyenv/versions/yx-dev/bin/python -m pytest tests/test_primitives/test_guid.py -v
```

---

## CLI Usage

### Basic Command

```bash
~/.pyenv/versions/yx-dev/bin/python -m yxCLI [options]
```

### Options

- `--port PORT` - UDP listen port (default: 9999)
- `--peers HOST:PORT,...` - Comma-separated list of peers to send packets to
- `--proto-opts 0xNN` - Binary protocol options (0x00-0x03):
  - `0x00` = Plaintext, Uncompressed
  - `0x01` = Plaintext, Compressed
  - `0x02` = Encrypted, Uncompressed
  - `0x03` = Encrypted, Compressed
- `--shutdown-after N` - Auto-shutdown after N seconds
- `--key HEXKEY` - 64 hex char shared key (default: test key)

### Examples

```bash
# Listen on port 9999 (default shared key)
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9999

# Send to peer on 9999
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9998 --peers localhost:9999

# Test binary protocol with encryption + compression
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9998 --peers localhost:9999 --proto-opts 0x03

# Auto-shutdown after 10 seconds
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9998 --peers localhost:9999 --shutdown-after 10

# Multiple peers
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9997 --peers localhost:9999,localhost:9998

# Custom shared key
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9999 --key D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD
```

---

## Shared Key

All instances must use the **same shared key** for HMAC validation to work.

**Default shared key** (used automatically):
```
D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD
```

This matches the Swift test key for cross-platform compatibility.

To use a custom key, provide the same `--key` argument to all instances:
```bash
# Hub
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9999 --key YOUR_64_HEX_CHARS

# Sender (must use same key)
~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9998 --peers localhost:9999 --key YOUR_64_HEX_CHARS
```

---

## Verification Tests

### HMAC Verification

```bash
# Standalone HMAC test (no dependencies)
python3 verify_hmac_standalone.py

# Full framework HMAC test (requires cryptography)
~/.pyenv/versions/yx-dev/bin/python verify_hmac.py
```

Both tests should show all tests passing with ✅ checkmarks.

---

## Troubleshooting

### "ModuleNotFoundError: No module named 'cryptography'"

You're using system Python instead of the pyenv environment. Use:
```bash
~/.pyenv/versions/yx-dev/bin/python
```

Or set up pyenv in your shell (see Setup section above).

### "HMAC validation failed"

Instances are using different keys. Make sure all instances either:
1. Use the default shared key (no `--key` argument), OR
2. Use the same custom `--key` value

### "can't find '__main__' module"

You're trying to run a directory instead of a Python module/script.

**Wrong:**
```bash
python p2p-test-logs  # This is a directory!
```

**Right:**
```bash
python scripts/test-p2p.py
python -m yxCLI
```

---

## Test Scenarios

### Scenario 1: Two-Peer Communication
Tests basic P2P communication between two instances.
```bash
~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py two-peer
```

### Scenario 2: Protocol Options Test
Tests all 4 binary protocol variants in parallel.
```bash
~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py proto-opts
```

Creates logs:
- `p2p-test-logs/hub.log` - Hub receiving packets
- `p2p-test-logs/sender-0x00.log` - Plaintext, Uncompressed
- `p2p-test-logs/sender-0x01.log` - Plaintext, Compressed
- `p2p-test-logs/sender-0x02.log` - Encrypted, Uncompressed
- `p2p-test-logs/sender-0x03.log` - Encrypted, Compressed

### Scenario 3: Three-Peer Mesh
Tests full mesh network with 3 peers all communicating.
```bash
~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py three-mesh
```

---

## Expected Output

### Successful Test
```
ℹ️ [06:16:24.057] Using default shared test key
ℹ️ [06:16:24.057] Registered RPC handler: task.hello
🧩 [06:16:24.057] GUID: 1697FBC25676
🔐 [06:16:24.057] Key: D3046ECC8DD3242ADF62801A33EF1004...
🔧 [06:16:24.057] Running yxCLI
🌐 [06:16:24.057] UDP listening on port 9999
✅ [06:16:24.057] YX Coordinator started
ℹ️ [06:16:25.089] Received text message: {'method': 'task.hello', ...}
```

### Failed HMAC (wrong key)
```
❌ [06:07:51.874] HMAC validation failed from C393C94E2AC8
```

This means the sender used a different key than the receiver.

---

## Cross-Platform Testing

The Python implementation is **100% wire-compatible** with the Swift version.

You can run:
- **Swift hub + Python sender** ✅
- **Python hub + Swift sender** ✅
- **Mixed mesh network** ✅

Just ensure all instances (Swift and Python) use the same shared key.

---

## Quick Reference

| Task | Command |
|------|---------|
| Run hub | `~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9999` |
| Run sender | `~/.pyenv/versions/yx-dev/bin/python -m yxCLI --port 9998 --peers localhost:9999` |
| Two-peer test | `~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py two-peer` |
| Protocol test | `~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py proto-opts` |
| Unit tests | `~/.pyenv/versions/yx-dev/bin/python -m pytest tests/ -v` |
| HMAC verify | `~/.pyenv/versions/yx-dev/bin/python verify_hmac.py` |
| Check logs | `cat p2p-test-logs/*.log` |

---

## Installation Reminder

If you need to reinstall dependencies:

```bash
# Install cryptography in pyenv environment
~/.pyenv/versions/yx-dev/bin/pip install cryptography

# Or install all requirements
~/.pyenv/versions/yx-dev/bin/pip install -r requirements.txt
```
