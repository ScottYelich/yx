import Foundation

/// Replay attack protection using nonce cache
///
/// Tracks seen nonces and rejects duplicates within max_age window.
/// Implements automatic cleanup to prevent memory exhaustion.
actor ReplayProtection {

    private let maxAge: TimeInterval
    private let cleanupInterval: Int
    private var seenNonces: [Data: Date] = [:]
    private var checkCounter: Int = 0

    init(maxAge: TimeInterval = 300.0, cleanupInterval: Int = 100) {
        self.maxAge = maxAge
        self.cleanupInterval = cleanupInterval
    }

    /// Check if nonce is valid and record it.
    /// - Returns: true if allowed (first time), false if replay detected
    func checkAndRecord(nonce: Data) -> Bool {
        let now = Date()

        if seenNonces[nonce] != nil {
            return false  // REPLAY DETECTED
        }

        seenNonces[nonce] = now

        checkCounter += 1
        if checkCounter >= cleanupInterval {
            cleanup()
            checkCounter = 0
        }

        return true
    }

    /// Check if nonce has been seen (without recording).
    func hasSeen(nonce: Data) -> Bool {
        return seenNonces[nonce] != nil
    }

    private func cleanup() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        seenNonces = seenNonces.filter { _, timestamp in timestamp > cutoff }
    }

    func count() -> Int {
        return seenNonces.count
    }

    func clear() {
        seenNonces.removeAll()
        checkCounter = 0
    }
}
