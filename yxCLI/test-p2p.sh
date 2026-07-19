#!/bin/bash
#
# test-p2p.sh - Test peer-to-peer communication between yxCLI instances
#
# This script launches multiple yxCLI instances with different ports
# and configures them to communicate with each other.

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/p2p-test-logs"
SHUTDOWN_AFTER=10  # seconds

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    pkill -f "yxCLI --port" 2>/dev/null || true
    echo -e "${GREEN}Done!${NC}"
}

# Set up trap for cleanup on exit
trap cleanup EXIT INT TERM

# Parse command line arguments
SCENARIO="two-peer"
if [[ $# -gt 0 ]]; then
    SCENARIO="$1"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}yxCLI P2P Communication Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create log directory
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log

case "$SCENARIO" in
    "two-peer")
        echo -e "${GREEN}Scenario: Two-Peer Communication${NC}"
        echo "Both instances listen on port 50000, filtered by GUID"
        echo ""

        # Start Instance A (port 50000)
        echo -e "${YELLOW}Starting Instance A on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/instance-a.log" 2>&1 &
        INSTANCE_A_PID=$!

        # Give it a moment to start
        sleep 1

        # Start Instance B (also port 50000)
        echo -e "${YELLOW}Starting Instance B on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/instance-b.log" 2>&1 &
        INSTANCE_B_PID=$!

        echo ""
        echo -e "${GREEN}Both instances running!${NC}"
        echo "Instance A PID: $INSTANCE_A_PID (port 50000)"
        echo "Instance B PID: $INSTANCE_B_PID (port 50000)"
        echo ""
        echo -e "${BLUE}Will shutdown after ${SHUTDOWN_AFTER} seconds...${NC}"
        echo ""
        
        # Wait for instances to finish
        wait $INSTANCE_A_PID $INSTANCE_B_PID 2>/dev/null || true
        ;;
        
    "three-mesh")
        echo -e "${GREEN}Scenario: Three-Peer Mesh Network${NC}"
        echo "All three instances listen on port 50000, filtered by GUID"
        echo ""

        # Start Instance A (port 50000)
        echo -e "${YELLOW}Starting Instance A on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/instance-a.log" 2>&1 &
        INSTANCE_A_PID=$!

        sleep 1

        # Start Instance B (port 50000)
        echo -e "${YELLOW}Starting Instance B on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/instance-b.log" 2>&1 &
        INSTANCE_B_PID=$!

        sleep 1

        # Start Instance C (port 50000)
        echo -e "${YELLOW}Starting Instance C on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/instance-c.log" 2>&1 &
        INSTANCE_C_PID=$!

        echo ""
        echo -e "${GREEN}All three instances running!${NC}"
        echo "Instance A PID: $INSTANCE_A_PID (port 50000)"
        echo "Instance B PID: $INSTANCE_B_PID (port 50000)"
        echo "Instance C PID: $INSTANCE_C_PID (port 50000)"
        echo ""
        echo -e "${BLUE}Will shutdown after ${SHUTDOWN_AFTER} seconds...${NC}"
        echo ""
        
        # Wait for instances to finish
        wait $INSTANCE_A_PID $INSTANCE_B_PID $INSTANCE_C_PID 2>/dev/null || true
        ;;
        
    "star")
        echo -e "${GREEN}Scenario: Star Topology (Hub and Spokes)${NC}"
        echo "All instances listen on port 50000, filtered by GUID"
        echo ""

        # Start Hub (port 50000, no peers - just listens)
        echo -e "${YELLOW}Starting Hub on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/hub.log" 2>&1 &
        HUB_PID=$!

        sleep 1

        # Start Spoke A (port 50000, sends to hub)
        echo -e "${YELLOW}Starting Spoke A on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/spoke-a.log" 2>&1 &
        SPOKE_A_PID=$!

        # Start Spoke B (port 50000, sends to hub)
        echo -e "${YELLOW}Starting Spoke B on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/spoke-b.log" 2>&1 &
        SPOKE_B_PID=$!

        # Start Spoke C (port 50000, sends to hub)
        echo -e "${YELLOW}Starting Spoke C on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/spoke-c.log" 2>&1 &
        SPOKE_C_PID=$!

        echo ""
        echo -e "${GREEN}Hub and all spokes running!${NC}"
        echo "Hub PID: $HUB_PID (port 50000)"
        echo "Spoke A PID: $SPOKE_A_PID (port 50000)"
        echo "Spoke B PID: $SPOKE_B_PID (port 50000)"
        echo "Spoke C PID: $SPOKE_C_PID (port 50000)"
        echo ""
        echo -e "${BLUE}Will shutdown after ${SHUTDOWN_AFTER} seconds...${NC}"
        echo ""

        # Wait for instances to finish
        wait $HUB_PID $SPOKE_A_PID $SPOKE_B_PID $SPOKE_C_PID 2>/dev/null || true
        ;;

    "proto-opts")
        echo -e "${GREEN}Scenario: Protocol Options Test (All 4 Variations)${NC}"
        echo "Testing all 4 protoOpts combinations with peer-to-peer communication"
        echo "All instances listen on port 50000, filtered by GUID"
        echo ""
        echo "Hub listens for all protocol types"
        echo "Sender A -> 0x00 (Plaintext, Uncompressed)"
        echo "Sender B -> 0x01 (Plaintext, Compressed)"
        echo "Sender C -> 0x02 (Encrypted, Uncompressed)"
        echo "Sender D -> 0x03 (Encrypted, Compressed)"
        echo ""

        # Start Hub (port 50000, no peers - just listens)
        echo -e "${YELLOW}Starting Hub (receiver) on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/hub.log" 2>&1 &
        HUB_PID=$!

        sleep 1

        # Start Sender A - 0x00 (Plaintext, Uncompressed)
        echo -e "${YELLOW}Starting Sender A (0x00 - Plaintext, Uncompressed) on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --proto-opts 0x00 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/sender-0x00.log" 2>&1 &
        SENDER_A_PID=$!

        sleep 1

        # Start Sender B - 0x01 (Plaintext, Compressed)
        echo -e "${YELLOW}Starting Sender B (0x01 - Plaintext, Compressed) on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --proto-opts 0x01 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/sender-0x01.log" 2>&1 &
        SENDER_B_PID=$!

        sleep 1

        # Start Sender C - 0x02 (Encrypted, Uncompressed)
        echo -e "${YELLOW}Starting Sender C (0x02 - Encrypted, Uncompressed) on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --proto-opts 0x02 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/sender-0x02.log" 2>&1 &
        SENDER_C_PID=$!

        sleep 1

        # Start Sender D - 0x03 (Encrypted, Compressed)
        echo -e "${YELLOW}Starting Sender D (0x03 - Encrypted, Compressed) on port 50000...${NC}"
        swift run yxCLI \
            --port 50000 \
            --peers localhost:50000 \
            --proto-opts 0x03 \
            --shutdown-after $SHUTDOWN_AFTER \
            > "$LOG_DIR/sender-0x03.log" 2>&1 &
        SENDER_D_PID=$!

        echo ""
        echo -e "${GREEN}Hub and all senders running!${NC}"
        echo "Hub PID: $HUB_PID (port 50000)"
        echo "Sender A PID: $SENDER_A_PID (port 50000, proto-opts 0x00)"
        echo "Sender B PID: $SENDER_B_PID (port 50000, proto-opts 0x01)"
        echo "Sender C PID: $SENDER_C_PID (port 50000, proto-opts 0x02)"
        echo "Sender D PID: $SENDER_D_PID (port 50000, proto-opts 0x03)"
        echo ""
        echo -e "${BLUE}Will shutdown after ${SHUTDOWN_AFTER} seconds...${NC}"
        echo ""

        # Wait for instances to finish
        wait $HUB_PID $SENDER_A_PID $SENDER_B_PID $SENDER_C_PID $SENDER_D_PID 2>/dev/null || true
        ;;
        
    *)
        echo -e "${RED}Unknown scenario: $SCENARIO${NC}"
        echo ""
        echo "Usage: $0 [scenario]"
        echo ""
        echo "Available scenarios:"
        echo "  two-peer    - Two instances talking to each other (default)"
        echo "  three-mesh  - Three instances in a mesh network"
        echo "  star        - One hub with multiple spokes"
        echo "  proto-opts  - Test all 4 protoOpts variations (0x00-0x03) P2P"
        echo ""
        exit 1
        ;;
esac

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Logs saved to: ${LOG_DIR}${NC}"
echo ""
echo "To view the logs:"
echo "  cat ${LOG_DIR}/instance-*.log"
echo "  cat ${LOG_DIR}/*.log"
echo ""

# Show summary of what happened
echo -e "${YELLOW}Log Summary:${NC}"
for logfile in "$LOG_DIR"/*.log; do
    if [[ -f "$logfile" ]]; then
        echo ""
        echo -e "${BLUE}=== $(basename "$logfile") ===${NC}"
        cat "$logfile"
    fi
done

