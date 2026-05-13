import Assertions
import XCTest

final class AssertionsTests: XCTestCase {
    func testApplePhaseOneCapabilitiesAreAvailable() throws {
        XCTAssertNoThrow(try assertPRNGIsAvailable())
        XCTAssertNoThrow(try assertDigestCapabilityIsAvailable())
        XCTAssertNoThrow(try assertKeyGenerationIsAvailable())
        XCTAssertNoThrow(try assertKeyExporterIsAvailable())
        XCTAssertNoThrow(try assertSigningCapabilityIsAvailable())
        XCTAssertNoThrow(try assertVerificationCapabilityIsAvailable())
    }
}
