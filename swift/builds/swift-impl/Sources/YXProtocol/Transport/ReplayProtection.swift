import Foundation

// Implements: protocol/specs/architecture/security-architecture.md (Replay Protection)
// Default maxAge: 300s per protocol/specs/technical/default-values.md

/// Replay attack protection using nonce cache.
public actor ReplayProtection {

    private let maxAge: TimeInterval
    private var seen: [Data: Date] = [:]
    private var checkCount = 0
    private let cleanupInterval: Int

    public init(maxAge: TimeInterval = 300.0, cleanupInterval: Int = 100) {
        self.maxAge = maxAge
        self.cleanupInterval = cleanupInterval
    }

    /// Check nonce and record if new.
    /// - Returns: true = allowed (first time), false = replay detected
    public func checkAndRecord(nonce: Data) -> Bool {
        if seen[nonce] != nil { return false }
        seen[nonce] = Date()
        checkCount += 1
        if checkCount >= cleanupInterval {
            cleanup()
            checkCount = 0
        }
        return true
    }

    public var count: Int { seen.count }

    public func clear() { seen.removeAll() }

    private func cleanup() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        seen = seen.filter { $0.value > cutoff }
    }
}
