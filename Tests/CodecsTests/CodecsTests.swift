import Codecs
import Foundation
import XCTest

final class CodecsTests: XCTestCase {
    func testFacadeReExportsCoreCodecPackages() throws {
        let numberCodec = getU16Codec()
        XCTAssertEqual(try numberCodec.encode(42), Data([0x2a, 0x00]))

        let stringCodec = getUtf8Codec()
        XCTAssertEqual(try stringCodec.decode(Data([0x48, 0x69])), "Hi")

        XCTAssertEqual(try getBooleanCodec().encode(true), Data([0x01]))
        XCTAssertEqual(mergeBytes([Data([0x01]), Data([0x02])]), Data([0x01, 0x02]))

        let amount = try decimalFixedPoint(.unsigned, 64, 6)
        XCTAssertEqual(try decimalFixedPointToString(try amount("42.5")), "42.5")

        let optionCodec = try getOptionCodec(getU16Codec())
        XCTAssertEqual(try optionCodec.encode(some(42)), Data([0x01, 0x2a, 0x00]))
    }
}
