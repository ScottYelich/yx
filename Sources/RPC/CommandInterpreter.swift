import Foundation
// MARK: - Interpreter Protocol (Async + Sendable)

public protocol Interpreter: Sendable {
    var name: String { get }
    func evaluate(input: String) async -> String
}
