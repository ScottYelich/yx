// filename: AppLauncher.swift

import Foundation
import Application
import Transport
import Primitives
import CryptoKit

enum AppLauncher {
    static func launch(using config: CommandLineConfig) async {
        log("🧩 GUID: \(config.guid.hexString)", level: .info)
        log("🔐 Key: \(config.key.withUnsafeBytes { Data($0).hexString })", level: .info)
        log("🌐 Listening on port: \(config.listenPort)", level: .info)

        // Load keys (PKI readiness)
        _ = try? await KeyManager.load(using: config)

        let comms = await AppInitializer.startComms(
            guid: config.guid,
            key: config.key,
            port: config.listenPort
        )

        // Send demo packets to configured peers
        if let protoOpts = config.protoOpts {
            // User specified --proto-opts: send binary test packet
            if let payloadSize = config.payloadSize {
                log("🧪 Testing Protocol 1 with protoOpts: 0x\(String(format: "%02X", protoOpts)), payload size: \(payloadSize) bytes", level: .info)
            } else {
                log("🧪 Testing Protocol 1 with protoOpts: 0x\(String(format: "%02X", protoOpts))", level: .info)
            }
            await DemoSender.sendBinaryTest(using: comms, protoOpts: protoOpts, payloadSize: config.payloadSize, targets: config.peers)
        } else {
            // Default: send text hello packet
            await DemoSender.sendTaskHello(using: comms, targets: config.peers)
        }

        // Set up shutdown timer if configured
        if let shutdownAfter = config.shutdownAfterSeconds {
            log("⏱️  Will shutdown after \(shutdownAfter) seconds", level: .info)
            Task {
                try? await Task.sleep(nanoseconds: UInt64(shutdownAfter) * 1_000_000_000)
                log("⏱️  Shutdown timer expired", level: .info)
                await comms.shutdown()
                exit(0)
            }
        }

        // Keep alive indefinitely if no shutdown timer
        if config.shutdownAfterSeconds == nil {
            log("🔄 Running indefinitely (Ctrl+C to stop)", level: .info)
            try? await Task.sleep(nanoseconds: UInt64.max)
        }
    }
}

