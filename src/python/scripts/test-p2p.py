#!/usr/bin/env python3
"""
P2P Testing Script for YX Framework

Equivalent to Swift test-p2p.sh for automated multi-instance testing.

Usage:
    python scripts/test-p2p.py [scenario]

Scenarios:
    two-peer    - Test two peers communicating (default)
    proto-opts  - Test all 4 protocol variants (0x00-0x03)
    three-mesh  - Test three-peer mesh network

Examples:
    # Two-peer test
    ~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py two-peer

    # Protocol options test
    ~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py proto-opts

    # Three-peer mesh
    ~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py three-mesh

Logs are saved to p2p-test-logs/ directory.

Note: Make sure to use the pyenv yx-dev environment:
    ~/.pyenv/versions/yx-dev/bin/python scripts/test-p2p.py

Or set up pyenv in your shell (see TESTING.md for details).
"""

import subprocess
import time
import signal
import sys
from pathlib import Path

def run_instance(port, peers=None, proto_opts=None, shutdown_after=10, log_file=None):
    """Run yxCLI instance"""
    cmd = [sys.executable, "-m", "yxCLI", "--port", str(port)]

    if peers:
        cmd.extend(["--peers", peers])

    if proto_opts is not None:
        cmd.extend(["--proto-opts", f"0x{proto_opts:02x}"])

    cmd.extend(["--shutdown-after", str(shutdown_after)])

    # Open log file if specified
    if log_file:
        log_path = Path("p2p-test-logs") / log_file
        log_path.parent.mkdir(exist_ok=True)
        log_fd = open(log_path, "w")
        proc = subprocess.Popen(cmd, stdout=log_fd, stderr=subprocess.STDOUT)
        return proc, log_fd
    else:
        proc = subprocess.Popen(cmd)
        return proc, None


def test_two_peer():
    """Test two peers communicating"""
    print("🧪 Testing two-peer communication...")
    print("    Both peers listen on port 50000, filtered by GUID")

    procs = []
    logs = []

    # Hub on 50000
    proc, log = run_instance(50000, log_file="hub.log")
    procs.append(proc)
    logs.append(log)

    time.sleep(1)

    # Sender also on 50000
    proc, log = run_instance(50000, peers="localhost:50000", log_file="sender.log")
    procs.append(proc)
    logs.append(log)

    # Wait for completion
    for proc in procs:
        proc.wait()

    # Close logs
    for log in logs:
        if log:
            log.close()

    print("✅ Two-peer test complete")


def test_proto_opts():
    """Test all 4 protocol option variants"""
    print("🧪 Testing Protocol 1 options (0x00-0x03)...")
    print("    All peers listen on port 50000, filtered by GUID")

    procs = []
    logs = []

    # Hub on 50000
    proc, log = run_instance(50000, log_file="hub.log", shutdown_after=15)
    procs.append(proc)
    logs.append(log)

    time.sleep(1)

    # Senders with different proto opts - all on same port
    for opts in [0x00, 0x01, 0x02, 0x03]:
        proc, log = run_instance(
            50000,
            peers="localhost:50000",
            proto_opts=opts,
            shutdown_after=10,
            log_file=f"sender-0x{opts:02x}.log"
        )
        procs.append(proc)
        logs.append(log)
        time.sleep(0.5)

    # Wait for completion
    for proc in procs:
        proc.wait()

    # Close logs
    for log in logs:
        if log:
            log.close()

    print("✅ Protocol options test complete")
    print("📋 Check p2p-test-logs/ for detailed logs")


def test_three_mesh():
    """Test three-peer mesh network"""
    print("🧪 Testing three-peer mesh...")
    print("    All three peers listen on port 50000, filtered by GUID")

    procs = []
    logs = []

    # Peer A on 50000
    proc, log = run_instance(50000, peers="localhost:50000", log_file="peer-a.log")
    procs.append(proc)
    logs.append(log)

    time.sleep(0.5)

    # Peer B on 50000
    proc, log = run_instance(50000, peers="localhost:50000", log_file="peer-b.log")
    procs.append(proc)
    logs.append(log)

    time.sleep(0.5)

    # Peer C on 50000
    proc, log = run_instance(50000, peers="localhost:50000", log_file="peer-c.log")
    procs.append(proc)
    logs.append(log)

    # Wait for completion
    for proc in procs:
        proc.wait()

    # Close logs
    for log in logs:
        if log:
            log.close()

    print("✅ Three-peer mesh test complete")


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="P2P testing for YX framework")
    parser.add_argument("test", nargs="?", default="two-peer",
                       choices=["two-peer", "proto-opts", "three-mesh"],
                       help="Test scenario to run")
    args = parser.parse_args()

    try:
        if args.test == "two-peer":
            test_two_peer()
        elif args.test == "proto-opts":
            test_proto_opts()
        elif args.test == "three-mesh":
            test_three_mesh()
    except KeyboardInterrupt:
        print("\n⚠️  Test interrupted")
        sys.exit(1)


if __name__ == "__main__":
    main()
