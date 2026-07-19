//
//  DemoPackets.swift
//  yxCLI
//
//  Created by Scott Yelich on 5/20/25.
//


// filename: DemoPackets.swift

import Foundation

enum DemoPackets {
    /// Creates a PKI-authenticated task.hello packet
    /// - Parameter fields: Dictionary from IdentityManager.exportHelloFields()
    /// - Returns: JSON-RPC 2.0 formatted packet
    static func taskHelloPacket(fields: [String: String]) -> [String: Any] {
        return [
            "jsonrpc": "2.0",
            "method": "task.hello",
            "params": fields,
            "id": UUID().uuidString
        ]
    }
}
