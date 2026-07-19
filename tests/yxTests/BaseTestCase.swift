// filename: BaseTestCase.swift

import XCTest
@testable import Primitives

/// Base test case that disables logging for cleaner test output
open class BaseTestCase: XCTestCase {

    open override func setUpWithError() throws {
        try super.setUpWithError()

        // Disable logging during tests
        Task {
            await Log.configure(enabled: false, minimumLevel: .error)
        }
    }

    open override func tearDownWithError() throws {
        // Re-enable logging after tests (optional)
        Task {
            await Log.configure(enabled: true, minimumLevel: .debug)
        }

        try super.tearDownWithError()
    }
}
