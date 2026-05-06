// Smoke test that proves the harness wires test discovery correctly.
// Phase 1 replaces this with real domain-model tests.
//
// Wrapped in `#if canImport(XCTest)` so a contributor without Xcode (CommandLineTools
// only) can still build the package. CI runs on a macos-14 runner with Xcode and
// exercises the test target normally. Phase 1 will require XCTest to compile.

#if canImport(XCTest)
import XCTest
@testable import Conductor

final class HarnessSmokeTests: XCTestCase {
    func testHarnessIsAlive() {
        XCTAssertTrue(true, "If this fails the universe has bigger problems than Conductor.")
    }
}
#endif
