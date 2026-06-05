#!/usr/bin/env python3
"""
Cross-language interop matrix runner: full 48-test suite.

Runs all 4 language combinations (Python/Swift sender x Python/Swift receiver)
over real UDP sockets for:
  - Transport layer  (5 scenarios)  -> 20 tests
  - Protocol 0 (text) (3 scenarios)  -> 12 tests
  - Protocol 1 (binary, chunked)     (4 scenarios) -> 16 tests
  = 48 tests

No mocks: every test runs a real receiver process and a real sender process.
"invalid" scenarios pass when the receiver correctly REJECTS the packet.
"""

import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SWIFT_BIN = os.path.join(REPO, "tests/interop/swift-interop/.build/debug")
SENDERS = os.path.join(HERE, "senders")
RECEIVERS = os.path.join(HERE, "receivers")
PY = sys.executable

TRANSPORT = ["simple", "empty", "large", "multiple", "invalid"]
PROTO0 = ["json", "large", "invalid"]
PROTO1 = ["base", "compressed", "encrypted", "both"]

# Proto1 payload (hex) — ~1.5KB exercises multi-chunk reassembly.
_P1_DATA_HEX = "ee" * 1500

_JSON = {
    "json": json.dumps({"jsonrpc": "2.0", "method": "test.echo",
                        "params": {"message": "hi"}, "id": 1}),
    "large": json.dumps({"jsonrpc": "2.0", "method": "test.large",
                         "params": {f"key{i}": f"value{i}" for i in range(300)},
                         "id": 2}),
}

GREEN, RED, YELLOW, BLUE, BOLD, RST = (
    "\033[92m", "\033[91m", "\033[93m", "\033[94m", "\033[1m", "\033[0m")


def receiver_cmd(layer, lang):
    if lang == "py":
        return [PY, os.path.join(RECEIVERS, f"python_receiver_{layer}.py")]
    return [os.path.join(SWIFT_BIN, f"swift-receiver-{layer}")]


def sender_cmd(layer, lang, scenario):
    if layer == "transport":
        if lang == "py":
            return [PY, os.path.join(SENDERS, "python_sender_transport.py"), scenario]
        return [os.path.join(SWIFT_BIN, f"swift-sender-transport-{scenario}")]
    if layer == "proto0":
        if lang == "py":
            if scenario == "invalid":
                return [PY, os.path.join(SENDERS, "python_sender_proto0_invalid.py")]
            return [PY, os.path.join(SENDERS, "python_sender_proto0.py"), _JSON[scenario]]
        return [os.path.join(SWIFT_BIN, f"swift-sender-proto0-{scenario}")]
    # proto1
    if lang == "py":
        return [PY, os.path.join(SENDERS, f"python_sender_proto1_{scenario}.py"), _P1_DATA_HEX]
    return [os.path.join(SWIFT_BIN, f"swift-sender-proto1-{scenario}")]


def run_one(recv, send, expect_pass, timeout=8.0):
    rx = subprocess.Popen(recv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    time.sleep(0.6)  # let the receiver bind
    try:
        subprocess.run(send, timeout=5.0, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        pass
    try:
        rc = rx.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        rx.kill()
        rc = None
    if expect_pass:
        return rc == 0
    return rc is not None and rc != 0


def main():
    combos = [("py", "py", "Python -> Python"),
              ("py", "swift", "Python -> Swift"),
              ("swift", "py", "Swift -> Python"),
              ("swift", "swift", "Swift -> Swift")]

    if not os.path.isdir(SWIFT_BIN):
        print(f"{RED}Swift executables not found at {SWIFT_BIN}{RST}")
        print("Build them first: cd tests/interop/swift-interop && swift build")
        return 2

    passed = failed = 0
    print(f"{BOLD}{BLUE}YX Interop Matrix - full 48-test suite{RST}\n")

    for layer, scenarios in (("transport", TRANSPORT), ("proto0", PROTO0), ("proto1", PROTO1)):
        print(f"{BOLD}== {layer.upper()} =={RST}")
        for s_lang, r_lang, label in combos:
            results = []
            for scn in scenarios:
                expect_pass = scn != "invalid"
                ok = run_one(receiver_cmd(layer, r_lang),
                             sender_cmd(layer, s_lang, scn), expect_pass)
                results.append((scn, ok))
                passed += ok
                failed += (not ok)
                time.sleep(0.25)
            cells = "  ".join(
                f"{GREEN if ok else RED}{scn}{RST}" for scn, ok in results)
            n_ok = sum(ok for _, ok in results)
            tag = GREEN if n_ok == len(results) else RED
            print(f"  {label:<18} {tag}{n_ok}/{len(results)}{RST}   {cells}")
        print()

    total = passed + failed
    color = GREEN if failed == 0 else YELLOW
    print(f"{BOLD}{color}TOTAL: {passed}/{total} passed{RST}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
