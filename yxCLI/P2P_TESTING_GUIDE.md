# yxCLI P2P Testing Guide

## Overview

The yxCLI now supports full peer-to-peer mesh networking with configurable ports and peer targets. This guide shows you how to test P2P communication between multiple instances.

## New CLI Arguments

### `--port <number>`
Sets the UDP port this instance will listen on.
- **Default**: 9999
- **Example**: `--port 9998`

### `--peers <host:port,host:port,...>`
Comma-separated list of peers to send task.hello packets to.
- **Default**: If not specified, broadcasts to 192.168.1.255:9999
- **Example**: `--peers localhost:9999,localhost:9997`

### `--shutdown-after <seconds>`
Automatically shutdown after N seconds.
- **Default**: Runs indefinitely until Ctrl+C
- **Example**: `--shutdown-after 10`

### `--proto-opts <value>`
Protocol 1 options for binary packet testing (hex or decimal).
- **Default**: If not specified, sends Protocol 0 text packets (task.hello)
- **Values**:
  - `0x00` or `0` = Plaintext, Uncompressed
  - `0x01` or `1` = Plaintext, Compressed
  - `0x02` or `2` = Encrypted, Uncompressed
  - `0x03` or `3` = Encrypted, Compressed
- **Example**: `--proto-opts 0x03` (encrypted and compressed)

### Legacy Arguments
- `--identity <name>` - Identity name for PKI keys
- `--pubkeys <path>` - Path to trusted public keys JSON
- `--privkeys <path>` - Path to private keys JSON

## Quick Start

### Two Instances Communicating

**Terminal 1:**
```bash
swift run yxCLI --port 9998 --peers localhost:9999
```

**Terminal 2:**
```bash
swift run yxCLI --port 9999 --peers localhost:9998
```

### What You'll See

Each instance will:
1. Generate a unique GUID
2. Start listening on its configured port
3. Send PKI-authenticated task.hello packets to configured peers
4. Receive and verify hello packets from other peers
5. Exchange symmetric keys securely using ECDH

**Example Output:**
```
🔧 Running yxCLI
🧩 GUID: C42EA8B37A05
🔐 Key: D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD
🌐 Listening on port: 9998
🌐 UDP listening on port 9998
📤 Sent text packet to localhost:9999
📣 Sent task.hello to localhost:9999
🔄 Running indefinitely (Ctrl+C to stop)
```

## Automated Testing Script

Use the included `test-p2p.sh` script for automated multi-instance testing:

```bash
# Two-peer test (default)
./test-p2p.sh

# Or explicitly:
./test-p2p.sh two-peer

# Three-peer mesh network
./test-p2p.sh three-mesh

# Star topology (hub and spokes)
./test-p2p.sh star

# Protocol options test (all 4 variations)
./test-p2p.sh proto-opts
```

### Test Scenarios

#### 1. Two-Peer Communication
```
Instance A (9998) <-> Instance B (9999)
```
- Both instances send hellos to each other
- Tests basic P2P communication

#### 2. Three-Peer Mesh
```
Instance A (9998) <-> Instance B (9999) <-> Instance C (9997)
        ^                                          |
        |                                          |
        +------------------------------------------+
```
- All instances send to all others
- Tests mesh network topology

#### 3. Star Topology
```
        Hub (9999)
       /    |    \
      /     |     \
  Spoke A  Spoke B  Spoke C
  (9998)   (9997)   (9996)
```
- All spokes send to hub
- Hub receives from all spokes
- Tests hub-and-spoke pattern

#### 4. Protocol Options Test
```
        Hub (9999)
       /    |    |    \
      /     |    |     \
 Sender A  B    C    D
 (9998)  (9997) (9996) (9995)
 0x00    0x01   0x02   0x03
```
- Hub receives all 4 protocol option variations
- Sender A: 0x00 (Plaintext, Uncompressed)
- Sender B: 0x01 (Plaintext, Compressed)
- Sender C: 0x02 (Encrypted, Uncompressed)
- Sender D: 0x03 (Encrypted, Compressed)
- Tests all Protocol 1 encoding options in P2P communication

### Test Output

The script will:
1. Launch all instances in the background
2. Wait for configured timeout (default 10 seconds)
3. Collect logs from each instance
4. Display summary of all communication
5. Clean up processes

**Logs are saved to**: `p2p-test-logs/*.log`

## Manual Testing

### Example 1: Basic Two-Instance Test

**Terminal 1:**
```bash
cd /path/to/yxCLI
swift run yxCLI --port 9998 --peers localhost:9999
```

**Terminal 2:**
```bash
cd /path/to/yxCLI  
swift run yxCLI --port 9999 --peers localhost:9998
```

Leave running for a few seconds, then press Ctrl+C in both terminals.

### Example 2: Timed Test

**Terminal 1:**
```bash
swift run yxCLI --port 9998 --peers localhost:9999 --shutdown-after 5
```

**Terminal 2:**
```bash
swift run yxCLI --port 9999 --peers localhost:9998 --shutdown-after 5
```

Both will automatically shutdown after 5 seconds.

### Example 3: Multi-Peer Mesh

**Terminal 1 (connects to 2 peers):**
```bash
swift run yxCLI --port 9998 --peers localhost:9999,localhost:9997
```

**Terminal 2 (connects to 2 peers):**
```bash
swift run yxCLI --port 9999 --peers localhost:9998,localhost:9997
```

**Terminal 3 (connects to 2 peers):**
```bash
swift run yxCLI --port 9997 --peers localhost:9998,localhost:9999
```

### Example 4: Testing Protocol Options

**Terminal 1 (receiver):**
```bash
swift run yxCLI --port 9999 --shutdown-after 10
```

**Terminal 2 (plaintext uncompressed):**
```bash
swift run yxCLI --port 9998 --peers localhost:9999 --proto-opts 0x00 --shutdown-after 10
```

**Terminal 3 (plaintext compressed):**
```bash
swift run yxCLI --port 9997 --peers localhost:9999 --proto-opts 0x01 --shutdown-after 10
```

**Terminal 4 (encrypted uncompressed):**
```bash
swift run yxCLI --port 9996 --peers localhost:9999 --proto-opts 0x02 --shutdown-after 10
```

**Terminal 5 (encrypted compressed):**
```bash
swift run yxCLI --port 9995 --peers localhost:9999 --proto-opts 0x03 --shutdown-after 10
```

## Understanding the Output

### Connection Establishment
```
🌐 UDP listening on port 9998
```
UDP socket is now listening for incoming packets.

### Sending Hello (Protocol 0)
```
📤 Sent text packet to localhost:9999
📣 Sent task.hello to localhost:9999
```
PKI-authenticated hello packet was sent to peer.

### Sending Binary Test (Protocol 1)
```
🧪 Testing Protocol 1 with protoOpts: 0x03
📤 BinaryProtocol: Sent 1 chunk(s) with opts 0x03 to localhost:9999
📦 Sent binary test (Encrypted, Compressed) to localhost:9999
```
Binary packet with specified encoding options was sent to peer.

### Receiving Hello (in library logs)
```
🔐 [task.hello] Learned verified key for peer 715E943A1148
```
Successfully verified peer's signature and derived shared symmetric key.

### Shutdown
```
⏱️  Shutdown timer expired
🛑 NetworkSystem: Initiating graceful shutdown...
✅ NetworkSystem: Shutdown complete
```

## What's Happening Under the Hood

1. **GUID Generation**: Each instance generates a unique 6-byte GUID
2. **Key Generation**: Ephemeral Curve25519 keypair for ECDH
3. **Signing**: P256 keypair for signing hello packets
4. **Hello Packet**: Contains GUID, timestamp, public keys, and signature
5. **Verification**: Peers verify signatures before accepting keys
6. **Key Derivation**: Shared symmetric keys derived using ECDH
7. **Secure Communication**: Future messages encrypted with derived keys

## Troubleshooting

### "Address already in use"
Two instances trying to use the same port. Ensure each has a unique `--port`.

### No communication happening
Check that:
- Ports are correct in `--peers` argument
- Instances are running simultaneously
- Firewall not blocking localhost communication

### Swift build conflicts
If you see "Another instance of SwiftPM is running", this is normal when launching multiple instances quickly. The second instance waits for the first build to complete.

## Advanced Usage

### Broadcast Mode
Don't specify `--peers` to use broadcast discovery:
```bash
swift run yxCLI --port 9998
```
Sends hello to 192.168.1.255:9999 (LAN broadcast).

### Mixed Mode
Some instances broadcast, others use directed peers:
```bash
# Hub: broadcasts
swift run yxCLI --port 9999

# Spoke: targets hub specifically
swift run yxCLI --port 9998 --peers localhost:9999
```

### Long-Running Test
```bash
swift run yxCLI --port 9998 --peers localhost:9999 --shutdown-after 3600
```
Runs for 1 hour (3600 seconds).

## Next Steps

- Implement message passing beyond hello packets
- Add periodic hello refresh
- Implement peer discovery protocol
- Add connection quality monitoring
- Create interactive REPL for sending messages

---

**Test Environment**: macOS 12+, Swift 6.1+
**Protocol**: UDP with PKI-authenticated key exchange
**Security**: ECDH key agreement + P256 signatures
