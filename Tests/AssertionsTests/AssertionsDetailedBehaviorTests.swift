import Assertions
import XCTest

final class AssertionsDetailedBehaviorTests: XCTestCase {
    func testCapabilityChecksAreIdempotent() {
        for _ in 0..<3 {
            XCTAssertNoThrow(try assertPRNGIsAvailable())
            XCTAssertNoThrow(try assertDigestCapabilityIsAvailable())
            XCTAssertNoThrow(try assertKeyGenerationIsAvailable())
            XCTAssertNoThrow(try assertKeyExporterIsAvailable())
            XCTAssertNoThrow(try assertSigningCapabilityIsAvailable())
            XCTAssertNoThrow(try assertVerificationCapabilityIsAvailable())
        }
    }

    func testCapabilityChecksCanBeStoredAndCalledAsThrowingOperations() {
        let cryptoChecks: [() throws -> Void] = [
            assertPRNGIsAvailable,
            assertDigestCapabilityIsAvailable,
            assertKeyGenerationIsAvailable,
            assertKeyExporterIsAvailable,
            assertSigningCapabilityIsAvailable,
            assertVerificationCapabilityIsAvailable,
        ]

        for check in cryptoChecks {
            XCTAssertNoThrow(try check())
        }
    }
}
