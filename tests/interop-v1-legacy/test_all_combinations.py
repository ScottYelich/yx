#!/usr/bin/env python3
"""
Comprehensive YX Protocol Interoperability Test

Tests all 4 combinations:
1. Python → Python
2. Python → Swift
3. Swift → Python
4. Swift → Swift

Each test sends a packet from sender to receiver and validates the payload.
"""

import sys
import os
import time
import subprocess
import json
from pathlib import Path

# Add Python implementation to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "canonical" / "python" / "src"))

from yx.transport import PacketBuilder, UDPSocket
from yx.primitives import GUIDFactory

# Test configuration
TEST_PORT = 7777
TEST_KEY = b'\x00' * 32  # Shared key for all tests
TIMEOUT = 2.0

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    YELLOW = '\033[93m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.RESET}\n")

def print_test(num, description):
    print(f"{Colors.BOLD}Test {num}: {description}{Colors.RESET}")

def print_success(message):
    print(f"{Colors.GREEN}✅ {message}{Colors.RESET}")

def print_error(message):
    print(f"{Colors.RED}❌ {message}{Colors.RESET}")

def print_info(message):
    print(f"{Colors.YELLOW}   {message}{Colors.RESET}")

def create_swift_sender_script(payload_text):
    """Create Swift script that sends a packet."""
    script = f'''
import Foundation
import YXProtocol
import Network

let guid = GUIDFactory.generate()
let key = Data(repeating: 0, count: 32)
let payload = "{payload_text}".data(using: .utf8)!

do {{
    let socket = try UDPSocket(port: 0)  // Random sender port
    try socket.sendPacket(guid: guid, payload: payload, key: key, to: "127.0.0.1", port: {TEST_PORT})
    print("SENT: \\(payload_text)")
}} catch {{
    print("ERROR: \\(error)")
    exit(1)
}}
'''
    return script

def create_swift_receiver_script():
    """Create Swift script that receives and validates a packet."""
    script = f'''
import Foundation
import YXProtocol
import Network

let key = Data(repeating: 0, count: 32)

do {{
    let socket = try UDPSocket(port: {TEST_PORT})

    if let packet = try socket.receivePacket(key: key, timeout: {TIMEOUT}) {{
        if let payload = String(data: packet.payload, encoding: .utf8) {{
            print("RECEIVED: \\(payload)")
        }} else {{
            print("ERROR: Could not decode payload")
            exit(1)
        }}
    }} else {{
        print("ERROR: No packet received")
        exit(1)
    }}
}} catch {{
    print("ERROR: \\(error)")
    exit(1)
}}
'''
    return script

def run_swift_script(script, description):
    """Run a Swift script and return output."""
    script_path = Path("/tmp/yx_interop_test.swift")
    script_path.write_text(script)

    # Get path to Swift sources
    swift_src = Path(__file__).parent.parent.parent / "canonical" / "swift"

    # Compile and run
    cmd = f"cd {swift_src} && swift /tmp/yx_interop_test.swift"
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=TIMEOUT + 1
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "TIMEOUT", 1

def test_python_to_python():
    """Test 1: Python sender → Python receiver"""
    print_test(1, "Python → Python")

    try:
        # Create receiver
        receiver = UDPSocket(port=TEST_PORT)
        receiver.bind()
        receiver.socket.settimeout(TIMEOUT)
        print_info(f"Python receiver listening on port {TEST_PORT}")
        time.sleep(0.1)

        # Create sender
        sender = UDPSocket(port=0)  # Random port
        guid = GUIDFactory.generate()
        payload = b"Python to Python test"

        # Send packet
        sender.send_packet(guid=guid, payload=payload, key=TEST_KEY, host="127.0.0.1", port=TEST_PORT)
        print_info(f"Python sender sent: {payload.decode()}")

        # Receive packet
        recv_guid, recv_payload, addr = receiver.receive_packet(key=TEST_KEY)

        if recv_payload == payload:
            print_success(f"Python receiver got: {recv_payload.decode()}")
            receiver.close()
            sender.close()
            return True
        else:
            print_error("Payload mismatch")
            receiver.close()
            sender.close()
            return False

    except Exception as e:
        print_error(f"Exception: {e}")
        try:
            receiver.close()
            sender.close()
        except:
            pass
        return False

def test_python_to_swift():
    """Test 2: Python sender → Swift receiver"""
    print_test(2, "Python → Swift")

    try:
        # Start Swift receiver
        swift_receiver = create_swift_receiver_script()
        script_path = Path("/tmp/yx_receiver.swift")
        script_path.write_text(swift_receiver)

        swift_src = Path(__file__).parent.parent.parent / "canonical" / "swift"
        cmd = f"cd {swift_src} && swift /tmp/yx_receiver.swift"

        print_info(f"Swift receiver listening on port {TEST_PORT}")
        receiver_process = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        # Give receiver time to start
        time.sleep(0.5)

        # Send from Python
        sender = UDPSocket(port=0)
        guid = GUIDFactory.generate()
        payload = b"Python to Swift test"

        sender.send_packet(guid=guid, payload=payload, key=TEST_KEY, host="127.0.0.1", port=TEST_PORT)
        print_info(f"Python sender sent: {payload.decode()}")

        # Wait for Swift to receive
        stdout, stderr = receiver_process.communicate(timeout=TIMEOUT + 1)

        if "RECEIVED: Python to Swift test" in stdout:
            print_success(f"Swift receiver got: {stdout.split('RECEIVED: ')[1].strip()}")
            sender.close()
            return True
        else:
            print_error(f"Swift receiver failed: {stderr}")
            sender.close()
            return False

    except Exception as e:
        print_error(f"Exception: {e}")
        try:
            receiver_process.kill()
        except:
            pass
        return False

def test_swift_to_python():
    """Test 3: Swift sender → Python receiver"""
    print_test(3, "Swift → Python")

    try:
        # Start Python receiver
        receiver = UDPSocket(port=TEST_PORT)
        receiver.bind()
        receiver.socket.settimeout(TIMEOUT)
        print_info(f"Python receiver listening on port {TEST_PORT}")
        time.sleep(0.1)

        # Send from Swift
        payload_text = "Swift to Python test"
        swift_sender = create_swift_sender_script(payload_text)

        swift_src = Path(__file__).parent.parent.parent / "canonical" / "swift"
        script_path = Path("/tmp/yx_sender.swift")
        script_path.write_text(swift_sender)

        cmd = f"cd {swift_src} && swift /tmp/yx_sender.swift"
        sender_process = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=TIMEOUT
        )

        if "SENT:" in sender_process.stdout:
            print_info(f"Swift sender sent: {payload_text}")
        else:
            print_error(f"Swift sender failed: {sender_process.stderr}")
            receiver.close()
            return False

        # Receive in Python
        recv_guid, recv_payload, addr = receiver.receive_packet(key=TEST_KEY)

        if recv_payload.decode() == payload_text:
            print_success(f"Python receiver got: {recv_payload.decode()}")
            receiver.close()
            return True
        else:
            print_error("Payload mismatch")
            receiver.close()
            return False

    except Exception as e:
        print_error(f"Exception: {e}")
        return False

def test_swift_to_swift():
    """Test 4: Swift sender → Swift receiver"""
    print_test(4, "Swift → Swift")

    try:
        # Start Swift receiver
        swift_receiver = create_swift_receiver_script()
        script_path = Path("/tmp/yx_receiver.swift")
        script_path.write_text(swift_receiver)

        swift_src = Path(__file__).parent.parent.parent / "canonical" / "swift"
        cmd = f"cd {swift_src} && swift /tmp/yx_receiver.swift"

        print_info(f"Swift receiver listening on port {TEST_PORT}")
        receiver_process = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        # Give receiver time to start
        time.sleep(0.5)

        # Send from Swift
        payload_text = "Swift to Swift test"
        swift_sender = create_swift_sender_script(payload_text)
        sender_script_path = Path("/tmp/yx_sender.swift")
        sender_script_path.write_text(swift_sender)

        cmd = f"cd {swift_src} && swift /tmp/yx_sender.swift"
        sender_process = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=TIMEOUT
        )

        if "SENT:" in sender_process.stdout:
            print_info(f"Swift sender sent: {payload_text}")
        else:
            print_error(f"Swift sender failed: {sender_process.stderr}")
            receiver_process.kill()
            return False

        # Wait for Swift to receive
        stdout, stderr = receiver_process.communicate(timeout=TIMEOUT + 1)

        if "RECEIVED: Swift to Swift test" in stdout:
            print_success(f"Swift receiver got: {stdout.split('RECEIVED: ')[1].strip()}")
            return True
        else:
            print_error(f"Swift receiver failed: {stderr}")
            return False

    except Exception as e:
        print_error(f"Exception: {e}")
        try:
            receiver_process.kill()
        except:
            pass
        return False

def main():
    print_header("YX Protocol - Comprehensive Interoperability Test")
    print(f"Testing all 4 combinations on localhost:{TEST_PORT}")
    print(f"Using shared 32-byte key: {TEST_KEY.hex()[:32]}...")

    results = []

    # Test 1: Python → Python
    results.append(("Python → Python", test_python_to_python()))
    time.sleep(0.5)

    # Test 2: Python → Swift
    results.append(("Python → Swift", test_python_to_swift()))
    time.sleep(0.5)

    # Test 3: Swift → Python
    results.append(("Swift → Python", test_swift_to_python()))
    time.sleep(0.5)

    # Test 4: Swift → Swift
    results.append(("Swift → Swift", test_swift_to_swift()))

    # Summary
    print_header("Test Results Summary")

    passed = 0
    failed = 0

    for name, result in results:
        if result:
            print_success(f"{name}: PASSED")
            passed += 1
        else:
            print_error(f"{name}: FAILED")
            failed += 1

    print(f"\n{Colors.BOLD}{'='*70}{Colors.RESET}")
    print(f"{Colors.BOLD}Total: {passed + failed} tests{Colors.RESET}")
    print(f"{Colors.GREEN}Passed: {passed}{Colors.RESET}")
    print(f"{Colors.RED}Failed: {failed}{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*70}{Colors.RESET}\n")

    if failed == 0:
        print(f"{Colors.GREEN}{Colors.BOLD}✅ ALL INTEROPERABILITY TESTS PASSED!{Colors.RESET}")
        print(f"{Colors.GREEN}Python and Swift implementations are fully interoperable.{Colors.RESET}\n")
        return 0
    else:
        print(f"{Colors.RED}{Colors.BOLD}❌ SOME TESTS FAILED{Colors.RESET}")
        print(f"{Colors.RED}Check errors above for details.{Colors.RESET}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
