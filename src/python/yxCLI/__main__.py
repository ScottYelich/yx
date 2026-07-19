"""
yxCLI entry point

Usage: python -m yxCLI [options]
"""

import sys
import asyncio
import argparse
import signal
from yx.primitives.guid import GUIDFactory, guid_to_hex
from yx.primitives.data_crypto import generate_key
from yx.primitives.logger import Logger
from yx.application.yx_coordinator import YXCoordinator
from yx.application.configuration import YXConfiguration

logger = Logger("yxCLI")


async def main():
    """Main entry point"""
    # Parse arguments
    parser = argparse.ArgumentParser(description="YX Networking CLI")
    parser.add_argument("--port", type=int, default=50000, help="UDP listen port")
    parser.add_argument("--peers", type=str, help="Comma-separated list of host:port peers")
    parser.add_argument("--proto-opts", type=str, help="Protocol options (0x00-0x03)")
    parser.add_argument("--shutdown-after", type=int, help="Shutdown after N seconds")
    parser.add_argument("--key", type=str, help="Hex-encoded shared key (64 hex chars for 32 bytes)")
    args = parser.parse_args()

    # Generate GUID and key
    guid = GUIDFactory.generate()

    # Use shared key if provided, otherwise generate random
    if args.key:
        key = bytes.fromhex(args.key)
        if len(key) != 32:
            logger.error("Key must be exactly 32 bytes (64 hex characters)")
            sys.exit(1)
    else:
        # Default shared key for testing (matching Swift test key)
        key = bytes.fromhex("D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD")
        logger.info("Using default shared test key")

    # Create configuration
    config = YXConfiguration.default()
    config.network.udp_port = args.port

    # Create coordinator
    coordinator = YXCoordinator(guid, key, config)

    # Start coordinator
    logger.tool("Running yxCLI")
    await coordinator.start()

    # Send test packets
    if args.peers:
        peers = args.peers.split(",")
        for peer_str in peers:
            parts = peer_str.strip().split(":")
            if len(parts) == 2:
                host, port = parts[0], int(parts[1])

                # Check if binary protocol test
                if args.proto_opts:
                    proto_opts = int(args.proto_opts, 0)  # Parse hex or decimal
                    test_data = b"Binary test data from Python YX!"
                    logger.test(f"Testing Protocol 1 with protoOpts: 0x{proto_opts:02x}")
                    await coordinator.send_binary_packet(test_data, proto_opts, host, port)
                else:
                    # Send text hello
                    await coordinator.send_hello(f"PyYX-{guid_to_hex(guid)[:8]}", host, port)

    # Run for specified time or indefinitely
    if args.shutdown_after:
        logger.timer(f"Will shutdown after {args.shutdown_after} seconds")
        await asyncio.sleep(args.shutdown_after)
    else:
        logger.info("Running indefinitely (Ctrl+C to stop)")
        # Wait for signal
        stop_event = asyncio.Event()

        def signal_handler(sig, frame):
            stop_event.set()

        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        await stop_event.wait()

    # Shutdown
    await coordinator.stop()
    logger.success("Shutdown complete")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Interrupted")
        sys.exit(0)
