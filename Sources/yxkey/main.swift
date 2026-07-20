import Foundation
import Primitives
import CryptoKit

// yxkey — manage YX mesh HMAC keys in the macOS Keychain.
// Spec: protocol/specs/architecture/key-management.md (ADR D08).

func usage() {
    print("""
    yxkey — YX mesh key manager (macOS Keychain: service \(MeshKey.service))

    USAGE:
      yxkey generate [--mesh NAME]   create + store a random 32-byte key; prints hex
      yxkey set      [--mesh NAME]   read 64 hex chars from STDIN, validate, store
      yxkey get      [--mesh NAME]   print the stored key hex to STDOUT
      yxkey list                     list mesh names stored in the Keychain
      yxkey remove   [--mesh NAME]   delete the named key

    Default mesh name: "\(MeshKey.defaultMesh)".
    Key = 32 bytes / 64 hex chars. Never passed on argv (set reads stdin).
    """)
}

func meshArg(_ args: [String]) -> String {
    if let i = args.firstIndex(of: "--mesh"), i + 1 < args.count { return args[i + 1] }
    return MeshKey.defaultMesh
}

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { usage(); exit(2) }
let mesh = meshArg(args)

switch cmd {
case "generate":
    let key = SymmetricKey(size: .bits256)
    let hex = MeshKey.encode(key)
    guard MeshKey.keychainSet(mesh: mesh, hex: hex) else {
        FileHandle.standardError.write(Data("failed to store key for mesh '\(mesh)'\n".utf8)); exit(1)
    }
    print(hex)  // stdout so it can be captured/distributed to other nodes
    FileHandle.standardError.write(Data("stored 32-byte key for mesh '\(mesh)'\n".utf8))

case "set":
    let raw = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard MeshKey.decode(hex) != nil else {
        FileHandle.standardError.write(Data("invalid key: expected 64 hex chars (32 bytes)\n".utf8)); exit(1)
    }
    guard MeshKey.keychainSet(mesh: mesh, hex: hex) else {
        FileHandle.standardError.write(Data("failed to store key for mesh '\(mesh)'\n".utf8)); exit(1)
    }
    FileHandle.standardError.write(Data("stored key for mesh '\(mesh)'\n".utf8))

case "get":
    guard let d = MeshKey.keychainGet(mesh: mesh) else {
        FileHandle.standardError.write(Data("no key stored for mesh '\(mesh)'\n".utf8)); exit(1)
    }
    print(MeshKey.encode(SymmetricKey(data: d)))

case "list":
    // Dump the yx service entries; parse account (mesh) names.
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = ["dump-keychain"]
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
    try? p.run()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    p.waitUntilExit()
    // Attributes are alphabetical, so "acct" precedes "svce" within an item.
    // Capture the pending account; emit it when a matching "svce" line appears.
    func quoted(_ s: Substring) -> String? {
        guard let r = s.range(of: "=\"", options: .backwards), s.hasSuffix("\"") else { return nil }
        return String(s[r.upperBound...].dropLast())
    }
    var meshes = Set<String>(); var pendingAcct: String? = nil
    for line in out.split(separator: "\n") {
        if line.contains("\"acct\"<blob>=") { pendingAcct = quoted(line) }
        if line.contains("\"svce\"<blob>=\"\(MeshKey.service)\""), let a = pendingAcct {
            meshes.insert(a)
        }
    }
    if meshes.isEmpty { FileHandle.standardError.write(Data("no yx mesh keys stored\n".utf8)) }
    else { meshes.sorted().forEach { print($0) } }

case "remove":
    if MeshKey.keychainRemove(mesh: mesh) {
        FileHandle.standardError.write(Data("removed key for mesh '\(mesh)'\n".utf8))
    } else {
        FileHandle.standardError.write(Data("no key to remove for mesh '\(mesh)'\n".utf8)); exit(1)
    }

case "-h", "--help":
    usage()

default:
    FileHandle.standardError.write(Data("unknown command: \(cmd)\n".utf8)); usage(); exit(2)
}
