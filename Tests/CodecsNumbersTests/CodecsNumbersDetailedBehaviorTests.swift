import CodecsCore
import CodecsNumbers
import Foundation
import SolanaErrors
import XCTest

final class CodecsNumbersDetailedBehaviorTests: XCTestCase {
    func testUnsignedSixtyFourBitPreBoundaryBytesAndDecodeOffsets() throws {
        let little = getU64Codec()
        let big = getU64Codec(NumberCodecConfig(endian: .big))

        try assertNumberBytes(little, UInt64(1), "0100000000000000")
        try assertNumberBytes(big, UInt64(1), "0000000000000001")
        try assertNumberBytes(little, UInt64.max - 1, "feffffffffffffff")
        try assertNumberBytes(big, UInt64.max - 1, "fffffffffffffffe")
        try assertNumberBytes(little, UInt64.min, "0000000000000000")
        try assertNumberBytes(big, UInt64.min, "0000000000000000")
    }

    func testSignedSixtyFourBitPreBoundaryBytesAndDecodeOffsets() throws {
        let little = getI64Codec()
        let big = getI64Codec(NumberCodecConfig(endian: .big))

        try assertNumberBytes(little, Int64(1), "0100000000000000")
        try assertNumberBytes(big, Int64(1), "0000000000000001")
        try assertNumberBytes(little, Int64(-1), "ffffffffffffffff")
        try assertNumberBytes(big, Int64(-1), "ffffffffffffffff")
        try assertNumberBytes(little, Int64.min + 1, "0100000000000080")
        try assertNumberBytes(big, Int64.min + 1, "8000000000000001")
        try assertNumberBytes(little, Int64.max - 1, "feffffffffffff7f")
        try assertNumberBytes(big, Int64.max - 1, "7ffffffffffffffe")
    }

    func testFloatingPointNegativeAndBigEndianBitPatterns() throws {
        let f32Pi = Double(Float(Double.pi))
        try assertNumberBytes(getF32Codec(), -1, "000080bf")
        try assertNumberBytes(getF32Codec(NumberCodecConfig(endian: .big)), -1, "bf800000")
        try assertNumberBytes(getF32Codec(), -42, "000028c2")
        try assertNumberBytes(getF32Codec(NumberCodecConfig(endian: .big)), -42, "c2280000")
        try assertNumberBytes(getF32Codec(NumberCodecConfig(endian: .big)), Double.pi, "40490fdb", decoded: f32Pi)
        try assertNumberBytes(getF32Codec(), -Double.pi, "db0f49c0", decoded: -f32Pi)

        try assertNumberBytes(getF64Codec(), 0, "0000000000000000")
        try assertNumberBytes(getF64Codec(NumberCodecConfig(endian: .big)), 0, "0000000000000000")
        try assertNumberBytes(getF64Codec(NumberCodecConfig(endian: .big)), 42, "4045000000000000")
        try assertNumberBytes(getF64Codec(NumberCodecConfig(endian: .big)), Double.pi, "400921fb54442d18")
        try assertNumberBytes(getF64Codec(), -Double.pi, "182d4454fb2109c0")
        try assertNumberBytes(getF64Codec(NumberCodecConfig(endian: .big)), -Double.pi, "c00921fb54442d18")
    }

    func testShortU16ReserializesEveryValueAndReportsBoundarySizes() throws {
        let codec = getShortU16Codec()

        XCTAssertEqual(try codec.getSizeFromValue(0), 1)
        XCTAssertEqual(try codec.getSizeFromValue(127), 1)
        XCTAssertEqual(try codec.getSizeFromValue(128), 2)
        XCTAssertEqual(try codec.getSizeFromValue(16_383), 2)
        XCTAssertEqual(try codec.getSizeFromValue(16_384), 3)
        XCTAssertEqual(try codec.getSizeFromValue(65_534), 3)
        XCTAssertEqual(try codec.getSizeFromValue(65_535), 3)

        try assertNumberBytes(codec, 1, "01")
        try assertNumberBytes(codec, 65_534, "feff03")
        for value in 0...65_535 {
            let bytes = try codec.encode(value)
            XCTAssertEqual(try codec.decode(bytes, at: 0), value)
        }
    }

    func testNumberRangeHelperReportsStableContext() {
        assertNumberRangeError(
            try assertNumberIsBetweenForCodec("u8", min: 0, max: 255, value: -1),
            codecDescription: "u8",
            min: "0",
            max: "255",
            value: "-1"
        )
        assertNumberRangeError(
            try assertNumberIsBetweenForCodec("i16", min: -32_768, max: 32_767, value: 32_768),
            codecDescription: "i16",
            min: "-32768",
            max: "32767",
            value: "32768"
        )
        XCTAssertNoThrow(try assertNumberIsBetweenForCodec("shortU16", min: 0, max: 65_535, value: 65_535))
    }
}

private func assertNumberBytes<C: Codec>(
    _ codec: C,
    _ value: C.Encoded,
    _ expectedHex: String,
    decoded expectedDecoded: C.Decoded? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) throws where C.Decoded: Equatable {
    let encoded = try codec.encode(value)
    XCTAssertEqual(encoded.numberTestHex, expectedHex, file: file, line: line)
    let expectedValue = try XCTUnwrap(expectedDecoded ?? value as? C.Decoded, file: file, line: line)
    let decoded = try codec.read(encoded, at: 0)
    XCTAssertEqual(decoded.0, expectedValue, file: file, line: line)
    XCTAssertEqual(decoded.1, encoded.count, file: file, line: line)

    let prefixed = try Data(numberTestHex: "ffffff\(expectedHex)")
    let offsetDecoded = try codec.read(prefixed, at: 3)
    XCTAssertEqual(offsetDecoded.0, expectedValue, file: file, line: line)
    XCTAssertEqual(offsetDecoded.1, encoded.count + 3, file: file, line: line)
}

private func assertNumberRangeError<T>(
    _ expression: @autoclosure () throws -> T,
    codecDescription: String,
    min: String,
    max: String,
    value: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        guard case let CodecsError.numberOutOfRange(actualDescription, actualMin, actualMax, actualValue) = error else {
            return XCTFail("Expected numberOutOfRange", file: file, line: line)
        }
        XCTAssertEqual(actualDescription, codecDescription, file: file, line: line)
        XCTAssertEqual(actualMin, min, file: file, line: line)
        XCTAssertEqual(actualMax, max, file: file, line: line)
        XCTAssertEqual(actualValue, value, file: file, line: line)
        XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsNumberOutOfRange.rawValue, file: file, line: line)
    }
}

private extension Data {
    init(numberTestHex: String) throws {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(numberTestHex.count / 2)
        var index = numberTestHex.startIndex
        while index < numberTestHex.endIndex {
            let next = numberTestHex.index(index, offsetBy: 2)
            let byte = try XCTUnwrap(UInt8(numberTestHex[index ..< next], radix: 16))
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var numberTestHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
