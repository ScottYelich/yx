import Foundation
// filename: NonceCache.swift

import Primitives

/// Cache for tracking nonces to prevent replay attacks.
///
/// Stores nonces with timestamps and automatically expires old entries.
/// Used to ensure each packet is processed only once.
public actor ReplayProtection {
    private var seenNonces: [Data: Date] = [:]
    private let maxAge: TimeInterval

    /// Creates a nonce cache with specified max age.
    ///
    /// - Parameter maxAge: How long nonces are remembered (default: 300 seconds / 5 minutes)
    public init(maxAge: TimeInterval = 300.0) {
        self.maxAge = maxAge
    }

    /// Checks if a nonce has been seen before.
    ///
    /// - Parameter nonce: The nonce to check
    /// - Returns: true if already seen, false if new
    public func hasSeen(_ nonce: Data) -> Bool {
        cleanup()
        return seenNonces[nonce] != nil
    }

    /// Records a nonce as seen.
    ///
    /// - Parameter nonce: The nonce to record
    public func record(_ nonce: Data) {
        seenNonces[nonce] = Date()

        // Cleanup after every 100 records to prevent unbounded growth
        if seenNonces.count % 100 == 0 {
            cleanup()
        }
    }

    /// Checks and records a nonce in one operation.
    ///
    /// - Parameter nonce: The nonce to check and record
    /// - Returns: true if this is a new nonce (allowed), false if already seen (replay)
    public func checkAndRecord(_ nonce: Data) -> Bool {
        if hasSeen(nonce) {
            return false  // Replay detected
        }
        record(nonce)
        return true  // New nonce, allowed
    }

    /// Returns the number of nonces currently cached.
    public var count: Int {
        seenNonces.count
    }

    /// Clears all cached nonces.
    public func clear() {
        seenNonces.removeAll()
    }

    /// Removes nonces older than maxAge.
    private func cleanup() {
        let now = Date()
        seenNonces = seenNonces.filter { _, timestamp in
            now.timeIntervalSince(timestamp) < maxAge
        }
    }
}

/// Extension for packet timestamp validation
extension Date {
    /// Checks if this timestamp is within acceptable age.
    ///
    /// - Parameter maxAge: Maximum allowed age in seconds
    /// - Returns: true if timestamp is recent enough
    public func isRecent(maxAge: TimeInterval) -> Bool {
        let now = Date()
        let age = now.timeIntervalSince(self)
        return age >= 0 && age <= maxAge
    }
}
