import CodecsCore
import CodecsNumbers
import CodecsStrings
import Foundation
import SolanaErrors
import XCTest

final class CodecsStringsDetailedBehaviorTests: XCTestCase {
    func testBase58SizeBoundariesAndLeadingZeroes() throws {
        let codec = getBase58Codec()

        XCTAssertEqual(try codec.getSizeFromValue("1"), 1)
        XCTAssertEqual(try codec.getSizeFromValue("11"), 2)
        XCTAssertEqual(try codec.getSizeFromValue("11111"), 5)
        XCTAssertEqual(try codec.getSizeFromValue(String(repeating: "1", count: 32)), 32)
        XCTAssertEqual(try codec.getSizeFromValue("5Q"), 1)
        XCTAssertEqual(try codec.getSizeFromValue("5R"), 2)
        XCTAssertEqual(try codec.getSizeFromValue("LUv"), 2)
        XCTAssertEqual(try codec.getSizeFromValue("LUw"), 3)
        XCTAssertEqual(try codec.getSizeFromValue("2UzHL"), 3)
        XCTAssertEqual(try codec.getSizeFromValue("2UzHM"), 4)
        XCTAssertEqual(try codec.getSizeFromValue("4uQeVj5tqViQh7yWWGStvkEG1Zmhx6uasJtWCJziofL"), 31)
        XCTAssertEqual(try codec.getSizeFromValue("4uQeVj5tqViQh7yWWGStvkEG1Zmhx6uasJtWCJziofM"), 32)
        XCTAssertEqual(try codec.getSizeFromValue("JEKNVnkbo3jma5nREBBJCDoXFVeKkD56V3xKrvRmWxFG"), 32)
        XCTAssertEqual(try codec.getSizeFromValue("JEKNVnkbo3jma5nREBBJCDoXFVeKkD56V3xKrvRmWxFH"), 33)
    }

    func testBaseXResliceSingleByteLittleAndBigOrderCases() throws {
        let base8 = getBaseXResliceCodec("01234567", bits: 3)

        let littleOrderCases = [
            ("000", "00"),
            ("100", "20"),
            ("200", "40"),
            ("300", "60"),
            ("400", "80"),
            ("500", "a0"),
            ("600", "c0"),
            ("700", "e0"),
        ]
        let bigOrderCases = [
            ("000", "00"),
            ("002", "01"),
            ("004", "02"),
            ("006", "03"),
            ("010", "04"),
            ("012", "05"),
            ("014", "06"),
            ("016", "07"),
        ]

        for (value, hex) in littleOrderCases + bigOrderCases {
            XCTAssertEqual(try base8.encode(value).stringsDetailedHex, hex)
            XCTAssertEqual(try base8.decode(Data(stringsDetailedHex: hex)), value)
        }
        XCTAssertEqual(try base8.encode("77777777").stringsDetailedHex, "ffffff")
        XCTAssertEqual(try base8.read(Data(stringsDetailedHex: "00ffffff"), at: 1).0, "77777777")
        XCTAssertEqual(try base8.read(Data(stringsDetailedHex: "00ffffff"), at: 1).1, 4)
    }

    func testSizedStringCompositionReportsSizesAndOffsetLayout() throws {
        let u8PrefixedString = addCodecSizePrefix(getUtf8Codec(), prefix: getU8Codec())
        let fixedString = fixCodecSize(getUtf8Codec(), fixedBytes: 12)
        let offsetPrefixed = addCodecSizePrefix(
            getUtf8Codec(),
            prefix: offsetCodec(
                getU8Codec(),
                config: OffsetConfig(
                    preOffset: { $0.wrapBytes(-1) },
                    postOffset: { _ in 0 }
                )
            )
        )

        XCTAssertEqual(try u8PrefixedString.encode("ABC").stringsDetailedHex, "03414243")
        XCTAssertEqual(try u8PrefixedString.decode(Data(stringsDetailedHex: "03414243")), "ABC")
        XCTAssertEqual(try u8PrefixedString.getSizeFromValue("ABC"), 4)
        XCTAssertNil(u8PrefixedString.maxSize)
        XCTAssertThrowsError(try u8PrefixedString.decode(Data(stringsDetailedHex: "0341"))) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsInvalidByteLength.rawValue)
        }

        XCTAssertEqual(try fixedString.encode("Hello World!").stringsDetailedHex, "48656c6c6f20576f726c6421")
        let fixedRead = try fixedString.read(Data(stringsDetailedHex: "48656c6c6f20576f726c6421"), at: 0)
        XCTAssertEqual(fixedRead.0, "Hello World!")
        XCTAssertEqual(fixedRead.1, 12)
        XCTAssertEqual(fixedString.fixedSize, 12)

        XCTAssertEqual(try getUtf8Codec().getSizeFromValue("ABC"), 3)
        XCTAssertNil(getUtf8Codec().maxSize)
        XCTAssertEqual(try offsetPrefixed.encode("ABC").stringsDetailedHex, "41424303")
        XCTAssertEqual(try offsetPrefixed.decode(Data(stringsDetailedHex: "41424303")), "ABC")
    }

    func testBaseStringValidationUsesOriginalReportedValue() {
        assertStringInvalidBase(
            try assertValidBaseString("01", "012", givenValue: "binary:012"),
            value: "binary:012",
            base: 2,
            alphabet: "01"
        )
        XCTAssertNoThrow(try assertValidBaseString("01", "010101"))
    }
}

private func assertStringInvalidBase<T>(
    _ expression: @autoclosure () throws -> T,
    value: String,
    base: Int,
    alphabet: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        guard case let CodecsError.invalidStringForBase(actualValue, actualBase, actualAlphabet) = error else {
            return XCTFail("Expected invalidStringForBase", file: file, line: line)
        }
        XCTAssertEqual(actualValue, value, file: file, line: line)
        XCTAssertEqual(actualBase, base, file: file, line: line)
        XCTAssertEqual(actualAlphabet, alphabet, file: file, line: line)
    }
}

private extension Data {
    init(stringsDetailedHex: String) throws {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(stringsDetailedHex.count / 2)
        var index = stringsDetailedHex.startIndex
        while index < stringsDetailedHex.endIndex {
            let next = stringsDetailedHex.index(index, offsetBy: 2)
            let byte = try XCTUnwrap(UInt8(stringsDetailedHex[index ..< next], radix: 16))
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var stringsDetailedHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
