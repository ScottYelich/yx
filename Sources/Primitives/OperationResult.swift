import Foundation
// filename: OperationResult.swift


/// Result type for operations that can fail with multiple error types
public enum OperationResult<Success> {
    case success(Success)
    case failure(Error)

    /// Unwrap success value or throw error
    public func get() throws -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    /// Map successful value
    public func map<T>(_ transform: (Success) -> T) -> OperationResult<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Returns true if this is a success
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    /// Returns true if this is a failure
    public var isFailure: Bool {
        !isSuccess
    }
}
