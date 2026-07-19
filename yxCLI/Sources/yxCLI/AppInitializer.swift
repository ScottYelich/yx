//
//  AppInitializer.swift
//  yxCLI
//
//  Created by Scott Yelich on 5/20/25.
//


// filename: AppInitializer.swift

import Foundation
import YX
import Primitives

enum AppInitializer {
    static func startComms(guid: Data, key: SymmetricKey, port: UInt16) async -> NetworkSystem {
        var config = Configuration.default
        config.network.udpPort = port

        return await NetworkSystem(
            guid: guid,
            key: key,
            config: config,
            onText: { text in
                log("📝 Received text: \(text)", level: .info)
            }
        )
    }
}
