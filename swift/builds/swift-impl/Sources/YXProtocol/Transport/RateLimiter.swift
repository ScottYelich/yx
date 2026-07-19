import Foundation

// Implements: protocol/specs/architecture/security-architecture.md (Rate Limiting)
// CRITICAL: maxRequests = 10,000 (NOT 100!)
// See SDTS Issue #2: wrong default caused HFT failures.
// Reference: protocol/specs/technical/default-values.md (max_requests = 10,000)

/// Per-peer rate limiter using sliding window.
public actor RateLimiter {

    private let maxRequests: Int
    private let windowSeconds: TimeInterval
    private var trustedGUIDs: Set<String>
    private var history: [String: [Date]] = [:]

    public init(
        maxRequests: Int = 10000,
        windowSeconds: TimeInterval = 60.0,
        trustedGUIDs: Set<String> = []
    ) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
        self.trustedGUIDs = trustedGUIDs
    }

    /// Check if peer is within rate limit.
    /// - Returns: true = allowed, false = blocked
    public func checkRateLimit(peerID: String) -> Bool {
        if trustedGUIDs.contains(peerID.uppercased()) { return true }
        let now = Date()
        let cutoff = now.addingTimeInterval(-windowSeconds)
        var timestamps = history[peerID, default: []].filter { $0 > cutoff }
        if timestamps.count >= maxRequests { return false }
        timestamps.append(now)
        history[peerID] = timestamps
        return true
    }

    public func addTrustedGUID(_ guid: String) { trustedGUIDs.insert(guid.uppercased()) }
    public func removeTrustedGUID(_ guid: String) { trustedGUIDs.remove(guid.uppercased()) }
    public func isTrusted(_ guid: String) -> Bool { trustedGUIDs.contains(guid.uppercased()) }
    public func resetPeer(_ peerID: String) { history.removeValue(forKey: peerID) }
    public var configuredMaxRequests: Int { maxRequests }
}
