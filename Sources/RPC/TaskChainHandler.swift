import Foundation
// filename: TaskChainHandler.swift

import Primitives
import CryptoKit
import Transport

/// Handles distributed capability probing and remote step dispatching for `rpc.chain`.
public actor TaskChainHandler: ProtocolInterface {

    public func proto() async -> UInt8 { ProtocolID.taskChain.rawValue }

    private let key: SymmetricKey
    private let dispatcher: RPCDispatcher
    private let localGUID: Data
    private var sendAPI: (@Sendable (Data, String, UInt16) async -> Void)?

    private var pendingRequests: [String: (Data) -> Void] = [:]

    public init(key: SymmetricKey, dispatcher: RPCDispatcher, guid: Data) {
        self.key = key
        self.dispatcher = dispatcher
        self.localGUID = guid
    }

    public func ingest(_ packet: UDPPacket, key: SymmetricKey) async {
        guard let data = packet.bytesAfterGUID.utf8String?.data(using: .utf8) else { return }
        await handleInbound(data)
    }

    // MARK: - Registration

    public func installSendAPI(_ send: @escaping @Sendable (Data, String, UInt16) async -> Void) async {
        self.sendAPI = send
    }

    public func register(with dispatcher: RPCDispatcher) async {
        await dispatcher.register("rpc.chain") { [weak self] req in
            guard let self else { return }
            await self.handleChainRequest(req)
        }

        await dispatcher.register("task.canDoResponse") { [weak self] req in
            guard let self else { return }
            await self.handleCanDoResponse(req)
        }
    }

    // MARK: - Private Helpers

    private func handleInbound(_ data: Data) async {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let dict = json as? [String: Any] {
            await dispatcher.handle(json: dict) { _ in }
        }
    }

    private func handleChainRequest(_ req: RPCRequest) async {
        guard let stepsVal = req.params["chain"],
              case let .array(steps) = stepsVal,
              let firstVal = steps.first,
              case let .object(first) = firstVal,
              let methodVal = first["method"],
              case let .string(method) = methodVal,
              let paramsVal = first["params"],
              case .object = paramsVal
        else {
            req.reply(error: "Invalid rpc.chain format")
            return
        }

        let queryID = UUID().uuidString

        pendingRequests[queryID] = { [weak self] responseData in
            guard let self else { return }
            Task {
                await self.dispatchStep(
                    to: responseData,
                    step: first,
                    reply: { result in req.reply(result: result) },
                    replyError: { error in req.reply(error: error) }
                )
            }
        }

        let payload: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "method": .string("task.canDo"),
            "params": .object(["capability": .string(method)]),
            "id": .string(queryID)
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload.rawValue) {
            await sendAPI?(data, "255.255.255.255", 9999)
        }
    }

    private func handleCanDoResponse(_ req: RPCRequest) async {
        guard let id = req.id,
              let fromVal = req.params["from"],
              case let .string(fromHex) = fromVal,
              let guidData = Data(hex: fromHex),
              let handler = pendingRequests.removeValue(forKey: id)
        else {
            return
        }

        handler(guidData)
    }

    private func dispatchStep(
        to peerGUID: Data,
        step: [String: JSON],
        reply: @Sendable @escaping (Any) -> Void,
        replyError: @Sendable @escaping (String) -> Void
    ) async {
        guard let methodVal = step["method"],
              case let .string(method) = methodVal,
              let paramsVal = step["params"],
              case let .object(params) = paramsVal
        else {
            replyError("Step missing method or params")
            return
        }

        let subID = UUID().uuidString
        let subCall: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "method": .string(method),
            "params": .object(params),
            "id": .string(subID)
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: subCall.rawValue) else {
            replyError("Failed to encode subtask")
            return
        }

        await sendAPI?(data, "255.255.255.255", 9999)

        await dispatcher.register(subID) { response in
            Task {
                if let result = response.raw["result"] {
                    let resultEntry: [String: Any] = ["result": result]
                    reply(["chain": [resultEntry]])
                } else if let error = response.raw["error"] {
                    replyError("Subtask error: \(error)")
                } else {
                    replyError("Invalid subtask response")
                }
            }
        }
    }
}


