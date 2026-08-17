import Foundation
import YX
import Primitives
import CryptoKit

// yxnode — the base YX mesh node daemon (ADR D09; yx-message-bus design).
// One long-lived process per machine: joins the mesh, heartbeats presence,
// answers node-info, and spools inbound (msg …) verbatim as .sxp files.
// Speaks Protocol-0 S-expressions exclusively (ADR D11); the yx core still
// accepts legacy JSON-RPC `{…}` payloads via the shim.
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
    yxnode — base YX mesh node daemon (Protocol-0 s-expr)

    USAGE: yxnode [--node ID] [--port N] [--peers h:p,h:p] [--mesh NAME]
                  [--agents a,b] [--heartbeat SEC] [--spool DIR]
                  [--broadcast IP] [--shutdown-after SEC]
                  [--trusted-signers PATH]
                  [--send-test TO --send-body TEXT]
                  [--send-command TO --send-body TEXT [--sign-as AGENT]]

    Defaults: node=hostname port=9720 mesh=agents heartbeat=5
              spool=~/ai/mail  broadcast=(none; use --peers on loopback)
              trusted-signers=~/.config/yx/trusted-signers.sxp
    Key: resolved via MeshKey (--key > YX_KEY > Keychain(mesh) > dev key).
    --send-test: send one (msg …) to TO via each peer, then exit (loopback proof).
    --send-command: send one (msg (type command) …) to TO via each peer, then exit.
      With --sign-as, signs with that agent's Ed25519 Keychain key (ADR D12);
      without it the command goes out UNSIGNED (receivers will refuse it).
    """)
    exit(0)
}

let nodeID     = arg("--node") ?? (ProcessInfo.processInfo.hostName
                    .split(separator: ".").first.map(String.init) ?? "node")
let port       = arg("--port").flatMap { UInt16($0) } ?? 9720
let mesh       = arg("--mesh") ?? "agents"
let heartbeat  = arg("--heartbeat").flatMap { Double($0) } ?? 5.0
let agents     = (arg("--agents") ?? "\(nodeID)/claude").split(separator: ",").map(String.init)
/// State root, ADR D13: ~/.yx (NOT ~/ai — that is the LLM stack's deploy
/// target). YX_HOME wins, then XDG_STATE_HOME, then ~/.yx. Must resolve
/// identically to _meshlib._yx_dirs() or the reader and the writer disagree,
/// which is exactly the two-spool split this replaced.
func yxState() -> String {
    let env = ProcessInfo.processInfo.environment
    if let h = env["YX_HOME"], !h.isEmpty { return (h as NSString).expandingTildeInPath }
    if let s = env["XDG_STATE_HOME"], !s.isEmpty {
        return (s as NSString).expandingTildeInPath + "/yx"
    }
    return NSHomeDirectory() + "/.yx"
}

// Per-node Maildir, matching _meshlib.spool(): <state>/spool/<node>/{tmp,new,…}.
// The YYYY/MM sharding this replaced also broke launchd WatchPaths — creating a
// file two levels down does not modify the watched directory's mtime.
let spoolDir   = arg("--spool").map { ($0 as NSString).expandingTildeInPath }
                    ?? (ProcessInfo.processInfo.environment["YX_SPOOL"]
                        .map { ($0 as NSString).expandingTildeInPath + "/\(nodeID)" }
                        ?? yxState() + "/spool/\(nodeID)")
let broadcast  = arg("--broadcast")            // e.g. 192.168.1.255 (LAN) — optional
let shutdownAfter = arg("--shutdown-after").flatMap { Double($0) }
let peers: [(host: String, port: UInt16)] = (arg("--peers") ?? "")
    .split(separator: ",").compactMap { s in
        let p = s.split(separator: ":")
        guard p.count == 2, let pt = UInt16(p[1]) else { return nil }
        return (String(p[0]), pt)
    }

let (key, keySource) = MeshKey.resolve(explicitHex: arg("--key"), mesh: mesh)

// D12: trusted-signers store — loaded once at boot. Missing ⇒ nothing trusted.
let trustedPath = arg("--trusted-signers").map { ($0 as NSString).expandingTildeInPath }
                    ?? TrustedSigners.defaultPath
let trustedSigners = TrustedSigners.load(path: trustedPath)

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

// MARK: - Mail spool (.sxp — the raw S-expression IS the message)

/// Microsecond, sortable id = filename stem = msg-id.
func unfID(_ date: Date = Date()) -> String {
    let t = date.timeIntervalSince1970
    let usec = Int((t - floor(t)) * 1_000_000)
    let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; f.timeZone = TimeZone.current
    return String(format: "%@%06d", f.string(from: date), usec)
}

/// A filename derived from a PEER-SUPPLIED id. Never trust the id itself: this
/// used to interpolate it straight into a path, so `(id "../../../../tmp/x")`
/// escaped the spool and the atomic write silently replaced whatever was there.
/// Mirrors _meshlib.safe_name() — the two must agree or one side accepts names
/// the other rejects.
func safeName(_ s: String) -> String {
    let ok = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
    let cleaned = String(String(s.map { ok.contains($0) ? $0 : "_" }).prefix(120))
    // An all-dots name is still a directory reference; the charset filter alone
    // passes "." and ".." because "." is a legal filename character.
    if cleaned.isEmpty || cleaned.allSatisfy({ $0 == "." }) {
        return String(SHA256.hash(data: Data(s.utf8))
            .map { String(format: "%02x", $0) }.joined().prefix(16))
    }
    return cleaned
}

/// Spool one received (msg …) verbatim as <spool>/new/<id>.sxp, Maildir-style.
///
/// Written into tmp/ and made visible by RENAME into new/, so a file appearing
/// there is necessarily complete — a reader can never see a half-written
/// message. Foundation's `atomically: true` is not sufficient: it stages the
/// temp file in the SAME directory, so a watcher on new/ sees the staging file.
/// (message-format.md §Storage: never UNF/YAML.)
@discardableResult
func writeSxp(id: String, raw: String) -> String? {
    let name = safeName(id) + ".sxp"
    let fm = FileManager.default
    do {
        for sub in ["tmp", "new", "cur", "done", "dead"] {
            try fm.createDirectory(atPath: "\(spoolDir)/\(sub)",
                                   withIntermediateDirectories: true)
        }
        let tmp = "\(spoolDir)/tmp/\(name)"
        let dst = "\(spoolDir)/new/\(name)"
        try raw.write(toFile: tmp, atomically: false, encoding: .utf8)
        // Same filesystem, so this is an atomic rename(2).
        if fm.fileExists(atPath: dst) { try? fm.removeItem(atPath: tmp); return dst }
        try fm.moveItem(atPath: tmp, toPath: dst)
        return dst
    } catch {
        FileHandle.standardError.write(Data("❌ spool write failed: \(error)\n".utf8))
        return nil
    }
}

// MARK: - Boot

func p(_ s: String) { print(s); fflush(stdout) }

p("🧩 yxnode '\(nodeID)' agents=\(agents) port=\(port) mesh=\(mesh) key=\(keySource.rawValue)")
p("📬 spool: \(spoolDir)")
p("🔏 trusted signers: \(trustedSigners.count) (\(trustedPath))")

let yx = await YX(port: port, key: key)

// node-hello — presence beacon (heartbeat + startup). Updates the directory.
await yx.registerSexp("node-hello") { expr in
    let from = expr.field("node")?.stringValue ?? "?"
    let ag = (expr.field("agents")?.stringValue ?? "").split(separator: ",").map(String.init)
    if await presence.seen(from, agents: ag) {
        p("🟢 discovered node '\(from)' agents=\(ag)")
    }
}

// node-info — identity query. (Answering needs a sender address; Protocol-0 s-expr
// carries none yet, so log receipt. A (node-info-reply …) goes out once the
// receive path exposes the source endpoint.)
let started = Date()
await yx.registerSexp("node-info") { _ in
    let up = Int(Date().timeIntervalSince(started))
    p("📨 node-info received (node=\(nodeID) agents=\(agents.joined(separator: ",")) uptime=\(up)s)")
}

// msg — inbound agent message → spool verbatim as .sxp if addressed to a local agent.
await yx.registerSexp("msg") { expr in
    let to = (expr.field("to")?.stringValue ?? "")
        .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let localHit = to.contains("@all") || to.contains { t in
        agents.contains(t) || t == nodeID || t.hasPrefix("\(nodeID)/")
    }
    guard localHit else { return }   // not for us; ignore (filtering, message-format.md)

    // D12 authority: (type command) / (type order) is ACTED ON only with a
    // valid (sig) from a trusted (key-id). Never trust `from` — the signature
    // is the truth. (signing.md §4)
    let msgType = expr.field("type")?.symValue ?? expr.field("type")?.stringValue ?? ""
    if msgType == "command" || msgType == "order" {
        let body = expr.field("body")?.stringValue ?? ""
        if let keyID = expr.field("key-id")?.stringValue,
           let sig = expr.field("sig")?.stringValue,
           let pubkey = trustedSigners[keyID],          // key-id ∈ trusted-signers
           Signer.verify(SExpr.canonicalMsgBytes(expr), sig: sig, pubkeyB64: pubkey) {
            p("✅ EXECUTED command from \(keyID): \(body)")
        } else {
            p("🚫 REFUSED command (untrusted/unsigned): \(body)")
        }
        return
    }

    let givenID = expr.field("id")?.stringValue ?? ""
    let id = givenID.isEmpty ? unfID() : givenID
    if let path = writeSxp(id: id, raw: expr.serialize()) {
        p("📥 delivered → \(path)")
    }
}

p("✅ yxnode up. peers=\(peers.map { "\($0.host):\($0.port)" })")

// MARK: - Send-test (throwaway loopback proof: one (msg …) to each peer, then exit)

if let testTo = arg("--send-test") {
    let body = arg("--send-body") ?? "loopback test"
    let iso = ISO8601DateFormatter()
    try? await Task.sleep(nanoseconds: 500_000_000)   // let peers come up
    let msg = SExpr.list([
        .sym("msg"),
        .list([.sym("v"), .num(1)]),
        .list([.sym("id"), .str(unfID())]),
        .list([.sym("type"), .sym("note")]),
        .list([.sym("from"), .str(agents.first ?? "\(nodeID)/claude")]),
        .list([.sym("to"), .str(testTo)]),
        .list([.sym("created"), .str(iso.string(from: Date()))]),
        .list([.sym("subject"), .str("send-test")]),
        .list([.sym("body"), .str(body)]),
    ])
    for peer in peers { await yx.sendSexpr(msg, to: peer.host, port: peer.port) }
    p("📤 send-test (msg …) → \(testTo) via \(peers.count) peer(s)")
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // let the send land
    await yx.shutdown()
    exit(0)
}

// MARK: - Send-command (D12: one (msg (type command) …), signed or unsigned, then exit)

if let cmdTo = arg("--send-command") {
    let body = arg("--send-body") ?? "command"
    let signAs = arg("--sign-as")
    let iso = ISO8601DateFormatter()
    try? await Task.sleep(nanoseconds: 500_000_000)   // let peers come up
    var children: [SExpr] = [
        .sym("msg"),
        .list([.sym("v"), .num(1)]),
        .list([.sym("id"), .str(unfID())]),
        .list([.sym("type"), .sym("command")]),
        .list([.sym("from"), .str(signAs ?? agents.first ?? "\(nodeID)/claude")]),
        .list([.sym("to"), .str(cmdTo)]),
        .list([.sym("created"), .str(iso.string(from: Date()))]),
        .list([.sym("body"), .str(body)]),
    ]
    if let signAs {
        // Bind the signer identity via (key-id …), sign the canonical bytes
        // (which include key-id, exclude sig), then append (sig …).
        children.append(.list([.sym("key-id"), .str(signAs)]))
        let canonical = SExpr.canonicalMsgBytes(.list(children))
        guard let sig = Signer.sign(canonical, agentID: signAs) else {
            FileHandle.standardError.write(Data(
                "❌ no signing key for '\(signAs)' — run: yxkey sign-gen --id \(signAs)\n".utf8))
            await yx.shutdown()
            exit(1)
        }
        children.append(.list([.sym("sig"), .str(sig)]))
    }
    let msg = SExpr.list(children)
    for peer in peers { await yx.sendSexpr(msg, to: peer.host, port: peer.port) }
    p("📤 send-command (\(signAs.map { "signed as \($0)" } ?? "UNSIGNED")) → \(cmdTo) via \(peers.count) peer(s)")
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // let the send land
    await yx.shutdown()
    exit(0)
}

// MARK: - Heartbeat + keep-alive

// Heartbeat: announce presence to explicit peers + optional broadcast every N sec.
// Runs detached; the process is kept alive by the inline await below.
let agentCSV = agents.joined(separator: ",")
func hello() -> SExpr {
    .list([.sym("node-hello"),
           .list([.sym("node"), .str(nodeID)]),
           .list([.sym("agents"), .str(agentCSV)])])
}
let hbTask = Task {
    while !Task.isCancelled {
        for peer in peers { await yx.sendSexpr(hello(), to: peer.host, port: peer.port) }
        if let b = broadcast { await yx.sendSexpr(hello(), to: b, port: port) }
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
