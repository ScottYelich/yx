import Foundation

/// Rate limiting using sliding window per peer
///
/// ⚠️ CRITICAL DEFAULT: maxRequests = 10,000 (SDTS Issue #2)
/// Swift v1.0.2 used 100 req/60s while Python used 10,000, which blocked
/// high-frequency trading. The default MUST be 10,000.
actor RateLimiter {

    private let maxRequests: Int
    private let windowSeconds: TimeInterval
    private var peerRequests: [String: [Date]] = [:]

    init(maxRequests: Int = 10_000, windowSeconds: TimeInterval = 60.0) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds

        if maxRequests < 10_000 {
            print("⚠️  WARNING: RateLimiter maxRequests (\(maxRequests)) is below recommended 10,000")
            print("   This may block high-frequency trading systems (see SDTS Issue #2)")
        }
    }

    /// Check if request is allowed for peer (sliding window).
    func checkRateLimit(peerID: String, sourceAddr: String) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-windowSeconds)

        let key = peerID.isEmpty ? sourceAddr : peerID
        var requests = peerRequests[key, default: []]
        requests = requests.filter { $0 > cutoff }

        if requests.count >= maxRequests {
            peerRequests[key] = requests
            return false  // RATE LIMIT EXCEEDED
        }

        requests.append(now)
        peerRequests[key] = requests
        return true
    }

    /// Get current request count for peer in the window.
    func getCurrentCount(peerID: String) -> Int {
        let now = Date()
        let cutoff = now.addingTimeInterval(-windowSeconds)
        guard let requests = peerRequests[peerID] else {
            return 0
        }
        return requests.filter { $0 > cutoff }.count
    }

    func clear() {
        peerRequests.removeAll()
    }

    func getConfig() -> (maxRequests: Int, windowSeconds: TimeInterval) {
        return (maxRequests, windowSeconds)
    }
}
