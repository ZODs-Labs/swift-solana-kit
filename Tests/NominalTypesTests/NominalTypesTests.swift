import NominalTypes
import XCTest

private enum TestMarker: NominalMarker {}

final class NominalTypesTests: XCTestCase {
    func testBrandWrapsRawValueWithoutChangingIt() {
        let branded = Brand<String, TestMarker>(rawValue: "value")
        XCTAssertEqual(branded.rawValue, "value")
    }

    func testEncodedStringBrandsStringEncoding() {
        let encoded = EncodedString<Base58Encoding>(rawValue: "11111111111111111111111111111111")
        XCTAssertEqual(encoded.rawValue, "11111111111111111111111111111111")
    }
}
