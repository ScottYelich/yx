import Foundation
// filename: RPCChainHandler.swift

import Primitives
import CryptoKit
import Transport

/// Handles execution of a chain of JSON-RPC calls in sequence, allowing
/// parameter substitution and per-step result tracking.
public actor RPCChainHandler: ProtocolInterface {

    public func proto() async -> UInt8 { ProtocolID.rpcChain.rawValue }

    private var dispatcher: RPCDispatcher?
    private var sendAPI: (@Sendable (Data, String, UInt16) async -> Void)?
    private let localGUID: Data
    private let origin: String

    private var refData: [String: JSON] = [:]
    private var refResults: [[String: JSON]] = []

    public init(localGUID: Data) {
        self.localGUID = localGUID
        self.origin = localGUID.hexString
    }

    public func ingest(_ packet: UDPPacket, key: SymmetricKey) async {
        guard let data = packet.bytesAfterGUID.utf8String?.data(using: .utf8) else { return }
        await handleInbound(data)
    }

    // MARK: - Registration

    public func register(with dispatcher: RPCDispatcher) async {
        self.dispatcher = dispatcher
        await dispatcher.register("rpc.chain") { [weak self] req in
            guard let self else { return }
            await self.handleChain(req)
        }
    }

    public func installSendAPI(_ send: @escaping @Sendable (Data, String, UInt16) async -> Void) async {
        self.sendAPI = send
    }

    // MARK: - Private Helpers

    private func handleInbound(_ data: Data) async {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let dict = json as? [String: Any] {
            await dispatcher?.handle(json: dict) { _ in }
        }
    }

    private func handleChain(_ req: RPCRequest) async {
        guard let stepsRaw = req.params["steps"],
              case let .array(stepsArray) = stepsRaw else {
            req.reply(error: "Missing 'steps' in rpc.chain")
            return
        }

        let steps = stepsArray.compactMap { v -> [String: JSON]? in
            if case let .object(map) = v { return map } else { return nil }
        }

        if case let .object(initialData)? = req.params["data"] {
            self.refData = initialData
        } else {
            self.refData = [:]
        }

        self.refResults = []

        let taskID = req.id ?? UUID().uuidString

        await runNextStep(index: 0, steps: steps, taskID: taskID, req: req)
    }

    private func runNextStep(
        index: Int,
        steps: [[String: JSON]],
        taskID: String,
        req: RPCRequest
    ) async {
        guard index < steps.count else {
            let result: [String: JSON] = [
                "chain": .array(refResults.map { .object($0) })
            ]
            req.reply(result: JSON.object(result).rawValue)
            return
        }

        let step = steps[index]

        guard let methodValue = step["method"],
              case let .string(method) = methodValue else {
            req.reply(error: "Step \(index) missing method")
            return
        }

        guard let rawParams = step["params"] else {
            req.reply(error: "Step \(index) missing params")
            return
        }

        let substituted = substitute(rawParams)
        let subID = UUID().uuidString

        let subCall: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "method": .string(method),
            "params": substituted,
            "id": .string(subID)
        ]

        let rawSubCall = subCall.rawValue

        log("🔁 [rpc.chain] Step \(index): dispatching method '\(method)' with params: \(substituted)", level: .debug)

        await dispatcher?.handle(json: rawSubCall) { [weak self] incoming in
            guard let self else { return }

            let responseDict = incoming as? [String: Sendable] ?? [:]

            Task {
                await self.handleResponse(
                    index: index,
                    response: responseDict,
                    method: method,
                    storeAs: step["storeAs"],
                    steps: steps,
                    taskID: taskID,
                    req: req
                )
            }
        }
    }

    private func handleResponse(
        index: Int,
        response: [String: Sendable],
        method: String,
        storeAs: JSON?,
        steps: [[String: JSON]],
        taskID: String,
        req: RPCRequest
    ) async {
        if let resultVal = response["result"],
           let result = JSON(resultVal) {
            let storeKey = (storeAs?.rawValue as? String) ?? method
            refData[storeKey] = result
            let dataRef = "dataRef://\(origin)/\(taskID)/\(storeKey)"
            refData[storeKey + ".ref"] = .string(dataRef)
            refResults.append(["step": .string(method), "result": result])
            await runNextStep(index: index + 1, steps: steps, taskID: taskID, req: req)
        } else if let error = response["error"] {
            req.reply(error: "Step \(index) failed: \(error)")
        } else {
            req.reply(error: "Step \(index) produced no result")
        }
    }

    private func substitute(_ node: JSON) -> JSON {
        switch node {
        case let .string(str):
            return substituteString(str)
        case let .object(dict):
            var newDict: [String: JSON] = [:]
            for (k, v) in dict {
                newDict[k] = substitute(v)
            }
            return .object(newDict)
        case let .array(arr):
            return .array(arr.map { substitute($0) })
        default:
            return node
        }
    }

    private func substituteString(_ str: String) -> JSON {
        if let key = extractExactPlaceholder(from: str), let val = refData[key] {
            return val
        }

        var result = str
        let pattern = #"\$\{([^}]+)\}"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: str, range: NSRange(str.startIndex..., in: str))

        for match in matches.reversed() {
            let range = match.range(at: 1)
            let key = (str as NSString).substring(with: range)
            if let value = refData[key] {
                let valueStr = "\(value.rawValue)"
                let fullRange = match.range(at: 0)
                if let swiftRange = Range(fullRange, in: result) {
                    result.replaceSubrange(swiftRange, with: valueStr)
                }
            }
        }

        return .string(result)
    }

    private func extractExactPlaceholder(from str: String) -> String? {
        let pattern = #"^\$\{([^}]+)\}$"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        guard let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) else {
            return nil
        }
        let range = match.range(at: 1)
        return (str as NSString).substring(with: range)
    }
}
