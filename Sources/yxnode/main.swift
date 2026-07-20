import Foundation
import YX
import Primitives
import CryptoKit

// yxnode — the base YX mesh node daemon (ADR D09; yx-message-bus design).
// One long-lived process per machine: joins the mesh, heartbeats presence,
// answers node.info, and lands inbound msg.deliver as Unified Node Format files.
// This is generic protocol infrastructure AND the canonical "how to build a
// service on yx" example. Machine-specific reporting stays out — injected via args.

// MARK: - Args

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}
func flag(_ name: String) -> Bool { CommandLine.arguments.contains(name) }

if flag("-h") || flag("--help") {
    print("""
    yxnode — base YX mesh node daemon

    USAGE: yxnode [--node ID] [--port N] [--peers h:p,h:p] [--mesh NAME]
                  [--agents a,b] [--heartbeat SEC] [--spool DIR]
                  [--broadcast IP] [--shutdown-after SEC]

    Defaults: node=hostname port=9720 mesh=agents heartbeat=5
              spool=~/ai/mail  broadcast=(none; use --peers on loopback)
    Key: resolved via MeshKey (--key > YX_KEY > Keychain(mesh) > dev key).
    """)
    exit(0)
}

let nodeID     = arg("--node") ?? (ProcessInfo.processInfo.hostName
                    .split(separator: ".").first.map(String.init) ?? "node")
let port       = arg("--port").flatMap { UInt16($0) } ?? 9720
let mesh       = arg("--mesh") ?? "agents"
let heartbeat  = arg("--heartbeat").flatMap { Double($0) } ?? 5.0
let agents     = (arg("--agents") ?? "\(nodeID)/claude").split(separator: ",").map(String.init)
let spoolDir   = arg("--spool").map { ($0 as NSString).expandingTildeInPath }
                    ?? (NSHomeDirectory() + "/ai/mail")
let broadcast  = arg("--broadcast")            // e.g. 192.168.1.255 (LAN) — optional
let shutdownAfter = arg("--shutdown-after").flatMap { Double($0) }
let peers: [(host: String, port: UInt16)] = (arg("--peers") ?? "")
    .split(separator: ",").compactMap { s in
        let p = s.split(separator: ":")
        guard p.count == 2, let pt = UInt16(p[1]) else { return nil }
        return (String(p[0]), pt)
    }

let (key, keySource) = MeshKey.resolve(explicitHex: arg("--key"), mesh: mesh)

// MARK: - Presence directory

/// Who's online: nodeID → (agents, lastSeen). Aged out at 3× heartbeat.
actor Presence {
    struct Entry { var agents: [String]; var lastSeen: Date }
    private var table: [String: Entry] = [:]
    func seen(_ node: String, agents: [String]) -> Bool {
        let isNew = table[node] == nil
        table[node] = Entry(agents: agents, lastSeen: Date())
        return isNew
    }
    func online(ttl: TimeInterval) -> [(String, [String])] {
        let cut = Date().addingTimeInterval(-ttl)
        return table.filter { $0.value.lastSeen >= cut }
                    .sorted { $0.key < $1.key }.map { ($0.key, $0.value.agents) }
    }
}
let presence = Presence()

// MARK: - UNF spool write

/// Microsecond, sortable id = filename stem = msg-id.
func unfID(_ date: Date = Date()) -> String {
    let t = date.timeIntervalSince1970
    let usec = Int((t - floor(t)) * 1_000_000)
    let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; f.timeZone = TimeZone.current
    return String(format: "%@%06d", f.string(from: date), usec)
}

/// Write one received message as a Unified Node Format markdown file.
/// Returns the path, or nil on failure.
@discardableResult
func writeUNF(id: String, from: String, to: [String], type: String,
              subject: String, refs: [String], body: String) -> String? {
    let now = Date()
    let f = DateFormatter(); f.dateFormat = "yyyy/MM"; f.timeZone = TimeZone.current
    let dir = "\(spoolDir)/\(f.string(from: now))"
    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let toList = to.map { "\"\($0)\"" }.joined(separator: ", ")
    let refList = refs.map { "\"\($0)\"" }.joined(separator: ", ")
    let theme = type.split(separator: ".").first.map(String.init) ?? type
    let doc = """
    ---
    id: "\(id)"
    type: message
    status: unread
    source: yxbus
    from: "\(from)"
    to: [\(toList)]
    subject: "\(subject)"
    themes: [\(theme)]
    refs: [\(refList)]
    created: "\(iso.string(from: now))"
    ---
    \(body)
    """
    do {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = "\(dir)/\(id).md"
        try doc.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    } catch {
        FileHandle.standardError.write(Data("❌ spool write failed: \(error)\n".utf8))
        return nil
    }
}

// MARK: - Boot

func p(_ s: String) { print(s); fflush(stdout) }

p("🧩 yxnode '\(nodeID)' agents=\(agents) port=\(port) mesh=\(mesh) key=\(keySource.rawValue)")
p("📬 spool: \(spoolDir)")

let yx = await YX(port: port, key: key)

// node.hello — presence beacon (heartbeat + startup). Updates the directory.
await yx.registerRPC("node.hello") { req in
    let from = req.params["node"]?.stringValue ?? "?"
    let ag = (req.params["agents"]?.stringValue ?? "").split(separator: ",").map(String.init)
    if await presence.seen(from, agents: ag) {
        p("🟢 discovered node '\(from)' agents=\(ag)")
    }
}

// node.info — RPC query: reply with this node's identity + uptime + agents.
let started = Date()
await yx.registerRPC("node.info") { req in
    let up = Int(Date().timeIntervalSince(started))
    req.reply(result: ["node": nodeID, "agents": agents, "uptime_s": up, "port": Int(port)])
    p("📨 node.info answered for \(req.id ?? "-")")
}

// msg.deliver — inbound agent message → land as a UNF file if addressed to a local agent.
await yx.registerRPC("msg.deliver") { req in
    let to = (req.params["to"]?.stringValue ?? "").split(separator: ",").map(String.init)
    let localHit = to.contains("@all") || to.contains { t in
        agents.contains(t) || t == nodeID || t.hasPrefix("\(nodeID)/")
    }
    guard localHit else { return }   // not for us; ignore (filtering, §4)
    let givenID = req.params["id"]?.stringValue ?? ""
    let id = givenID.isEmpty ? unfID() : givenID
    let path = writeUNF(
        id: id,
        from: req.params["from"]?.stringValue ?? "?",
        to: to,
        type: req.params["type"]?.stringValue ?? "note",
        subject: req.params["subject"]?.stringValue ?? "",
        refs: (req.params["refs"]?.stringValue ?? "").split(separator: ",").map(String.init),
        body: req.params["body"]?.stringValue ?? "")
    if let path { p("📥 delivered → \(path)") }
}

p("✅ yxnode up. peers=\(peers.map { "\($0.host):\($0.port)" })")

// Heartbeat: announce presence to explicit peers + optional broadcast every N sec.
// Runs detached; the process is kept alive by the inline await below.
let agentCSV = agents.joined(separator: ",")
func hello() -> [String: Any] {
    ["method": "node.hello", "params": ["node": nodeID, "agents": agentCSV]]
}
let hbTask = Task {
    while !Task.isCancelled {
        for peer in peers { await yx.sendText(hello(), to: peer.host, port: peer.port) }
        if let b = broadcast { await yx.sendText(hello(), to: b, port: port) }
        try? await Task.sleep(nanoseconds: UInt64(heartbeat * 1_000_000_000))
    }
}

// Keep alive INLINE (never fire-and-forget the keep-alive — that killed yxCLI, bug 8f87db1).
if let s = shutdownAfter {
    try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
    hbTask.cancel()
    let dir = await presence.online(ttl: heartbeat * 3)
    p("🛑 shutdown. online nodes seen: \(dir.map { $0.0 })")
    await yx.shutdown()
} else {
    p("🔄 running (Ctrl+C to stop)")
    try? await Task.sleep(nanoseconds: UInt64.max)
}
