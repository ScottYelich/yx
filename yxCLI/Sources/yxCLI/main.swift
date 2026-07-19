// filename: main.swift

import Foundation
import Primitives
import Transport

log("🔧 Running yxCLI", level: .info)

// Validate protocol IDs at startup
ProtocolID.validateUniqueness()

// Load config (GUID, Key, Flags)
let config = CommandLineConfig.load()

// Launch async runtime and wait for completion
await AppLauncher.launch(using: config)
