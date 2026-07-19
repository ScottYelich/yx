import Foundation
// filename: RateLimiter.swift

import Primitives

/// Rate limiter to protect against DoS attacks.
///
/// Tracks request counts per peer over a sliding time window.
/// When a peer exceeds the limit, subsequent requests are rejected.
public actor RateLimiter {
    private var requests: [String: [Date]] = [:]
    private let maxRequests: Int
    private let windowDuration: TimeInterval

    /// Creates a rate limiter with specified limits.
    ///
    /// - Parameters:
    ///   - maxRequests: Maximum requests allowed per window (default: 100)
    ///   - windowDuration: Time window in seconds (default: 60 seconds)
    public init(
        maxRequests: Int = 100,
        windowDuration: TimeInterval = 60.0
    ) {
        self.maxRequests = maxRequests
        self.windowDuration = windowDuration
    }

    /// Checks if a peer has exceeded the rate limit.
    ///
    /// - Parameter peer: Peer identifier (typically IP or GUID)
    /// - Returns: true if request is allowed, false if rate limited
    public func checkLimit(for peer: String) -> Bool {
        let now = Date()
        var history = requests[peer] ?? []

        // Remove old requests outside the window
        history = history.filter { now.timeIntervalSince($0) < windowDuration }

        // Check if limit exceeded
        guard history.count < maxRequests else {
            // Rate limited - but update history for accurate tracking
            requests[peer] = history
            return false
        }

        // Record this request
        history.append(now)
        requests[peer] = history
        return true
    }

    /// Returns current request count for a peer in the current window.
    ///
    /// Useful for monitoring and metrics.
    public func requestCount(for peer: String) -> Int {
        let now = Date()
        let history = requests[peer] ?? []
        return history.filter { now.timeIntervalSince($0) < windowDuration }.count
    }

    /// Clears rate limit history for a specific peer.
    ///
    /// Use when a peer is no longer connected or needs forgiveness.
    public func reset(for peer: String) {
        requests.removeValue(forKey: peer)
    }

    /// Clears all rate limit history.
    ///
    /// Useful for testing or administrative reset.
    public func resetAll() {
        requests.removeAll()
    }

    /// Periodic cleanup of stale entries.
    ///
    /// Call this periodically to prevent unbounded memory growth.
    public func cleanup() {
        let now = Date()
        requests = requests.filter { _, history in
            !history.isEmpty && now.timeIntervalSince(history.last!) < windowDuration
        }
    }
}
