import Foundation

/// Log levels for filtering message importance
public enum LogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Thread-safe logger actor
public actor Logger {
    public var isEnabled: Bool
    public var minimumLevel: LogLevel

    public init(enabled: Bool = true, minimumLevel: LogLevel = .debug) {
        self.isEnabled = enabled
        self.minimumLevel = minimumLevel
    }

    public func log(_ message: String, level: LogLevel) {
        guard isEnabled, level >= minimumLevel else { return }
        print(message)
        fflush(stdout)  // Force immediate output for background processes
    }

    public func configure(enabled: Bool, minimumLevel: LogLevel) {
        self.isEnabled = enabled
        self.minimumLevel = minimumLevel
    }

    public func getConfig() -> (enabled: Bool, minimumLevel: LogLevel) {
        return (isEnabled, minimumLevel)
    }
}

/// Global logger instance
public let Log = Logger()

/// Global logging function
public func log(_ message: String, level: LogLevel = .info) {
    Task {
        await Log.log(message, level: level)
    }
}
