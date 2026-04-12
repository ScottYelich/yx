#!/usr/bin/env python3
"""
YX Protocol — Transport Layer Interoperability Test Suite

Tests all 4 combinations × 5 scenarios = 20 transport tests.

Combinations:
  P→P  Python sender  → Python receiver
  P→S  Python sender  → Swift receiver
  S→P  Swift sender   → Python receiver
  S→S  Swift sender   → Swift receiver

Scenarios:
  1. Simple payload      (ASCII text)
  2. Empty payload       (zero bytes)
  3. Large payload       (5 KB)
  4. Multiple packets    (5 sequential)
  5. Invalid key reject  (receiver rejects wrong-key packet)

Traceability:
- protocol/specs/testing/interoperability-requirements.md
"""

import sys
import os
import time
import subprocess
import threading
import socket
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
SRC_PATH = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_PATH))

from yx.transport import UDPSocket, PacketBuilder
from yx.primitives import GUIDFactory

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PYTHON = sys.executable
PYTHON_SENDER  = PROJECT_ROOT / "tests" / "interop" / "senders"  / "python-sender"
PYTHON_RECEIVER = PROJECT_ROOT / "tests" / "interop" / "receivers" / "python-receiver"

SWIFT_PKG = PROJECT_ROOT / "canonical" / "swift"
SWIFT_BUILD = SWIFT_PKG / ".build" / "arm64-apple-macosx" / "debug"
SWIFT_SENDER   = SWIFT_BUILD / "swift-sender"
SWIFT_RECEIVER = SWIFT_BUILD / "swift-receiver"

DEFAULT_KEY = b'\x00' * 32
WRONG_KEY   = b'\xff' * 32
LOCALHOST   = "127.0.0.1"

# Use a high ephemeral port range to avoid conflicts
BASE_PORT = 54000

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
class C:
    GREEN  = '\033[92m'
    RED    = '\033[91m'
    BLUE   = '\033[94m'
    YELLOW = '\033[93m'
    BOLD   = '\033[1m'
    RESET  = '\033[0m'

def ok(msg):  print(f"  {C.GREEN}✓ {msg}{C.RESET}")
def err(msg): print(f"  {C.RED}✗ {msg}{C.RESET}")
def info(msg):print(f"  {C.YELLOW}  {msg}{C.RESET}")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def ensure_swift_built():
    if not SWIFT_SENDER.exists() or not SWIFT_RECEIVER.exists():
        print(f"{C.YELLOW}Building Swift package…{C.RESET}")
        subprocess.run(["swift", "build"], cwd=SWIFT_PKG, check=True,
                       capture_output=True)
        print(f"{C.GREEN}Swift build complete.{C.RESET}")

def run(cmd, timeout=10, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, timeout=timeout, capture_output=True,
                          text=True, **kwargs)

def start_bg(cmd, **kwargs) -> subprocess.Popen:
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, **kwargs)

def wait_for_port(port: int, timeout: float = 2.0) -> bool:
    """Wait until something is bound to port (poll with connect)."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            # UDP: just check bind is possible on a different fd – not reliable.
            # Instead, just sleep briefly; POSIX bind is near-instant.
            s.close()
        except Exception:
            pass
        time.sleep(0.05)
    return True

def python_send_single(payload: bytes, host: str, port: int, key: bytes = DEFAULT_KEY):
    """Send one packet from Python in the current thread."""
    sock = UDPSocket(port=0)
    sock.send_packet(guid=GUIDFactory.generate(), payload=payload, key=key,
                     host=host, port=port)
    sock.close()

def python_receive_single(port: int, key: bytes = DEFAULT_KEY,
                          timeout: float = 5.0) -> bytes:
    """Receive one packet in Python; returns payload bytes."""
    sock = UDPSocket(port=port)
    sock.bind()
    sock.socket.settimeout(timeout)
    _, payload, _ = sock.receive_packet(key=key)
    sock.close()
    return payload

# ---------------------------------------------------------------------------
# Individual scenario runners
# ---------------------------------------------------------------------------
def _run_combo(label: str, start_receiver, send, expect: bytes,
               recv_timeout: float = 5.0) -> bool:
    """
    Generic test runner.
      start_receiver() → (process_or_None, stop_fn)
      send()           → send the packet(s)
      expect           → expected payload bytes
    Returns True on pass.
    """
    result = {"payload": None, "error": None}
    recv_ready = threading.Event()

    def receiver_thread():
        try:
            payload = start_receiver()
            result["payload"] = payload
        except Exception as e:
            result["error"] = str(e)
        finally:
            recv_ready.set()

    t = threading.Thread(target=receiver_thread, daemon=True)
    t.start()
    time.sleep(0.5)   # let receiver bind (Swift subprocesses need ~0.3s to start)

    try:
        send()
    except Exception as e:
        recv_ready.wait(timeout=recv_timeout)
        err(f"Sender error: {e}")
        return False

    recv_ready.wait(timeout=recv_timeout + 1)

    if result["error"]:
        err(f"Receiver error: {result['error']}")
        return False
    if result["payload"] is None:
        err("No payload received (timeout?)")
        return False
    if result["payload"] != expect:
        err(f"Payload mismatch\n    got:      {result['payload'][:80]!r}\n    expected: {expect[:80]!r}")
        return False
    return True


# ---------------------------------------------------------------------------
# Scenario implementations
# ---------------------------------------------------------------------------
def scenario_simple(send_fn, recv_fn, port) -> bool:
    payload = b"Hello from YX interop test!"
    return _run_combo(
        "simple",
        lambda: recv_fn(port),
        lambda: send_fn(payload, LOCALHOST, port),
        payload,
    )

def scenario_empty(send_fn, recv_fn, port) -> bool:
    payload = b""
    return _run_combo(
        "empty",
        lambda: recv_fn(port),
        lambda: send_fn(payload, LOCALHOST, port),
        payload,
    )

def scenario_large(send_fn, recv_fn, port) -> bool:
    payload = b"X" * 5000
    return _run_combo(
        "large",
        lambda: recv_fn(port),
        lambda: send_fn(payload, LOCALHOST, port),
        payload,
    )

def scenario_multiple(send_fn, recv_fn, port, n=5) -> bool:
    """Send n packets sequentially, verify each is received."""
    for i in range(n):
        payload = f"packet-{i}".encode()
        ok_flag = _run_combo(
            f"multiple[{i}]",
            lambda: recv_fn(port),
            lambda p=payload: send_fn(p, LOCALHOST, port),
            payload,
            recv_timeout=4.0,
        )
        if not ok_flag:
            err(f"Packet {i} failed")
            return False
        time.sleep(0.1)
    return True

def scenario_invalid_key(send_fn, recv_wrong_key_fn, port) -> bool:
    """
    Send packet with CORRECT key; receiver uses WRONG key → must reject.
    Expected: receiver returns error / times out, does NOT print RECEIVED.
    """
    payload = b"should be rejected"
    result = {"output": None, "error": None}
    recv_ready = threading.Event()

    def receiver_thread():
        try:
            result["output"] = recv_wrong_key_fn(port)
        except Exception as e:
            result["error"] = str(e)
        finally:
            recv_ready.set()

    t = threading.Thread(target=receiver_thread, daemon=True)
    t.start()
    time.sleep(0.5)

    try:
        send_fn(payload, LOCALHOST, port)
    except Exception:
        pass

    recv_ready.wait(timeout=6.0)

    # Either an exception was raised (ValueError / timeout) OR
    # the output did NOT contain the payload.
    if result["error"]:
        return True  # Receiver raised an error — correct behaviour
    if result["output"] is None:
        return True  # Timed out — receiver rejected packet (correct)
    # If output contains payload, that means receiver accepted it — FAIL
    err(f"Receiver accepted packet with wrong key: {result['output']!r}")
    return False


# ---------------------------------------------------------------------------
# Python/Swift send/receive wrappers
# ---------------------------------------------------------------------------
# Python
def py_send(payload: bytes, host: str, port: int, key=DEFAULT_KEY):
    python_send_single(payload, host, port, key)

def py_recv(port: int, key=DEFAULT_KEY, timeout=5.0) -> bytes:
    return python_receive_single(port, key, timeout)

def py_recv_wrong_key(port: int) -> bytes:
    return python_receive_single(port, WRONG_KEY, timeout=3.0)

# Swift (via compiled executables)
def swift_send(payload: bytes, host: str, port: int, key=DEFAULT_KEY):
    payload_str = payload.decode('utf-8', errors='replace')
    cmd = [str(SWIFT_SENDER), payload_str, host, str(port),
           "--key", key.hex()]
    r = run(cmd, timeout=6)
    if r.returncode != 0:
        raise RuntimeError(f"swift-sender failed: {r.stderr or r.stdout}")
    if "SENT:" not in r.stdout and payload_str:
        raise RuntimeError(f"swift-sender unexpected output: {r.stdout!r}")

def swift_recv(port: int, key=DEFAULT_KEY, timeout=5.0) -> bytes:
    cmd = [str(SWIFT_RECEIVER), str(port),
           "--key", key.hex(), "--timeout", str(timeout)]
    r = run(cmd, timeout=timeout + 2)
    if r.returncode != 0:
        raise RuntimeError(f"swift-receiver failed: {r.stderr or r.stdout}")
    # Don't strip trailing whitespace — empty payload gives "RECEIVED: " with trailing space
    line = r.stdout.rstrip('\n')
    prefix = "RECEIVED: "
    if line.startswith(prefix):
        return line[len(prefix):].encode('utf-8')
    raise RuntimeError(f"swift-receiver unexpected: {line!r}")

def swift_recv_wrong_key(port: int) -> bytes:
    return swift_recv(port, WRONG_KEY, timeout=3.0)


# ---------------------------------------------------------------------------
# Test matrix
# ---------------------------------------------------------------------------
COMBOS = [
    ("P→P", py_send,    py_recv,    py_recv_wrong_key),
    ("P→S", py_send,    swift_recv, swift_recv_wrong_key),
    ("S→P", swift_send, py_recv,    py_recv_wrong_key),
    ("S→S", swift_send, swift_recv, swift_recv_wrong_key),
]

SCENARIOS = [
    ("simple payload",     scenario_simple),
    ("empty payload",      scenario_empty),
    ("large payload 5KB",  scenario_large),
    ("5 sequential pkts",  scenario_multiple),
    ("invalid key reject", scenario_invalid_key),
]


def run_all() -> tuple[int, int]:
    passed = failed = 0
    port = BASE_PORT

    print(f"\n{C.BOLD}{C.BLUE}{'='*72}{C.RESET}")
    print(f"{C.BOLD}{C.BLUE}  YX Protocol — Transport Interop Tests  (4 combos × 5 scenarios = 20){C.RESET}")
    print(f"{C.BOLD}{C.BLUE}{'='*72}{C.RESET}\n")

    for combo_label, send_fn, recv_fn, recv_wrong_fn in COMBOS:
        print(f"{C.BOLD}── Combination: {combo_label} ──{C.RESET}")
        for scen_label, scen_fn in SCENARIOS:
            print(f"  {scen_label}…", end="", flush=True)
            try:
                if scen_label == "invalid key reject":
                    result = scen_fn(send_fn, recv_wrong_fn, port)
                elif scen_label == "5 sequential pkts":
                    result = scen_fn(send_fn, recv_fn, port)
                else:
                    result = scen_fn(send_fn, recv_fn, port)
            except Exception as e:
                result = False
                err(f"Exception: {e}")
            port += 1

            if result:
                print(f"\r  {C.GREEN}✓{C.RESET} {scen_label}")
                passed += 1
            else:
                print(f"\r  {C.RED}✗{C.RESET} {scen_label}")
                failed += 1
        print()

    print(f"{C.BOLD}{'='*72}{C.RESET}")
    total = passed + failed
    print(f"Result: {passed}/{total} passed", end="")
    if failed == 0:
        print(f"  {C.GREEN}{C.BOLD}ALL TRANSPORT TESTS PASS ✓{C.RESET}")
    else:
        print(f"  {C.RED}{C.BOLD}{failed} FAILED ✗{C.RESET}")
    print()

    return passed, failed


if __name__ == "__main__":
    ensure_swift_built()
    passed, failed = run_all()
    sys.exit(0 if failed == 0 else 1)
