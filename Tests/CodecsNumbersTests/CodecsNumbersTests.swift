import CodecsCore
import CodecsNumbers
import Foundation
import SolanaErrors
import XCTest

final class CodecsNumbersTests: XCTestCase {
    func testUnsignedFixedIntegers() throws {
        try assertValid(getU8Codec(), 1, "01")
        try assertValid(getU8Codec(), 42, "2a")
        try assertValid(getU8Codec(), 0, "00")
        try assertValid(getU8Codec(), 255, "ff")
        assertRangeError(getU8Codec(), value: -1, codecDescription: "u8", min: "0", max: "255", valueDescription: "-1")
        assertRangeError(getU8Codec(), value: 256, codecDescription: "u8", min: "0", max: "255", valueDescription: "256")
        XCTAssertEqual(getU8Codec().fixedSize, 1)

        try assertValid(getU16Codec(), 42, "2a00")
        try assertValid(getU16Codec(NumberCodecConfig(endian: .big)), 42, "002a")
        try assertValid(getU16Codec(), 255, "ff00")
        try assertValid(getU16Codec(NumberCodecConfig(endian: .big)), 255, "00ff")
        try assertValid(getU16Codec(), 65_535, "ffff")
        assertRangeError(getU16Codec(), value: -1, codecDescription: "u16", min: "0", max: "65535", valueDescription: "-1")
        assertRangeError(getU16Codec(), value: 65_536, codecDescription: "u16", min: "0", max: "65535", valueDescription: "65536")
        XCTAssertEqual(getU16Codec().fixedSize, 2)

        try assertValid(getU32Codec(), 42, "2a000000")
        try assertValid(getU32Codec(NumberCodecConfig(endian: .big)), 42, "0000002a")
        try assertValid(getU32Codec(), 65_535, "ffff0000")
        try assertValid(getU32Codec(NumberCodecConfig(endian: .big)), 65_535, "0000ffff")
        try assertValid(getU32Codec(), 4_294_967_295, "ffffffff")
        assertRangeError(getU32Codec(), value: -1, codecDescription: "u32", min: "0", max: "4294967295", valueDescription: "-1")
        assertRangeError(getU32Codec(), value: 4_294_967_296, codecDescription: "u32", min: "0", max: "4294967295", valueDescription: "4294967296")
        XCTAssertEqual(getU32Codec().fixedSize, 4)
    }

    func testSignedFixedIntegers() throws {
        try assertValid(getI8Codec(), 0, "00")
        try assertValid(getI8Codec(), 42, "2a")
        try assertValid(getI8Codec(), -1, "ff")
        try assertValid(getI8Codec(), -42, "d6")
        try assertValid(getI8Codec(), -128, "80")
        try assertValid(getI8Codec(), 127, "7f")
        assertRangeError(getI8Codec(), value: -129, codecDescription: "i8", min: "-128", max: "127", valueDescription: "-129")
        assertRangeError(getI8Codec(), value: 128, codecDescription: "i8", min: "-128", max: "127", valueDescription: "128")
        XCTAssertEqual(getI8Codec().fixedSize, 1)

        try assertValid(getI16Codec(), -42, "d6ff")
        try assertValid(getI16Codec(NumberCodecConfig(endian: .big)), -42, "ffd6")
        try assertValid(getI16Codec(), -32_768, "0080")
        try assertValid(getI16Codec(NumberCodecConfig(endian: .big)), -32_768, "8000")
        try assertValid(getI16Codec(), 32_767, "ff7f")
        try assertValid(getI16Codec(NumberCodecConfig(endian: .big)), 32_767, "7fff")
        assertRangeError(getI16Codec(), value: -32_769, codecDescription: "i16", min: "-32768", max: "32767", valueDescription: "-32769")
        assertRangeError(getI16Codec(), value: 32_768, codecDescription: "i16", min: "-32768", max: "32767", valueDescription: "32768")
        XCTAssertEqual(getI16Codec().fixedSize, 2)

        try assertValid(getI32Codec(), -42, "d6ffffff")
        try assertValid(getI32Codec(NumberCodecConfig(endian: .big)), -42, "ffffffd6")
        try assertValid(getI32Codec(), -2_147_483_648, "00000080")
        try assertValid(getI32Codec(NumberCodecConfig(endian: .big)), -2_147_483_648, "80000000")
        try assertValid(getI32Codec(), 2_147_483_647, "ffffff7f")
        try assertValid(getI32Codec(NumberCodecConfig(endian: .big)), 2_147_483_647, "7fffffff")
        assertRangeError(getI32Codec(), value: -2_147_483_649, codecDescription: "i32", min: "-2147483648", max: "2147483647", valueDescription: "-2147483649")
        assertRangeError(getI32Codec(), value: 2_147_483_648, codecDescription: "i32", min: "-2147483648", max: "2147483647", valueDescription: "2147483648")
        XCTAssertEqual(getI32Codec().fixedSize, 4)
    }

    func testSixtyFourBitIntegers() throws {
        try assertValid(getU64Codec(), UInt64(42), "2a00000000000000")
        try assertValid(getU64Codec(NumberCodecConfig(endian: .big)), UInt64(42), "000000000000002a")
        try assertValid(getU64Codec(), UInt64(0xFFFF_FFFF), "ffffffff00000000")
        try assertValid(getU64Codec(NumberCodecConfig(endian: .big)), UInt64(0xFFFF_FFFF), "00000000ffffffff")
        try assertValid(getU64Codec(), UInt64.max, "ffffffffffffffff")
        XCTAssertEqual(getU64Codec().fixedSize, 8)

        try assertValid(getI64Codec(), Int64(0), "0000000000000000")
        try assertValid(getI64Codec(), Int64(-42), "d6ffffffffffffff")
        try assertValid(getI64Codec(NumberCodecConfig(endian: .big)), Int64(-42), "ffffffffffffffd6")
        try assertValid(getI64Codec(), Int64.min, "0000000000000080")
        try assertValid(getI64Codec(NumberCodecConfig(endian: .big)), Int64.min, "8000000000000000")
        try assertValid(getI64Codec(), Int64.max, "ffffffffffffff7f")
        try assertValid(getI64Codec(NumberCodecConfig(endian: .big)), Int64.max, "7fffffffffffffff")
        XCTAssertEqual(getI64Codec().fixedSize, 8)
    }

    func testOneHundredTwentyEightBitIntegers() throws {
        let u64Max = UInt128Value(high: 0, low: UInt64.max)
        let u128AlmostMax = UInt128Value(high: UInt64.max, low: UInt64.max - 1)
        try assertValid(getU128Codec(), UInt128Value(42), "2a000000000000000000000000000000")
        try assertValid(getU128Codec(NumberCodecConfig(endian: .big)), UInt128Value(42), "0000000000000000000000000000002a")
        try assertValid(getU128Codec(), u64Max, "ffffffffffffffff0000000000000000")
        try assertValid(getU128Codec(NumberCodecConfig(endian: .big)), u64Max, "0000000000000000ffffffffffffffff")
        try assertValid(getU128Codec(), u128AlmostMax, "feffffffffffffffffffffffffffffff")
        try assertValid(getU128Codec(NumberCodecConfig(endian: .big)), u128AlmostMax, "fffffffffffffffffffffffffffffffe")
        try assertValid(getU128Codec(), UInt128Value.max, "ffffffffffffffffffffffffffffffff")
        XCTAssertEqual(getU128Codec().fixedSize, 16)

        let i128MinPlusOne = Int128Value(bitPattern: UInt128Value(high: 0x8000_0000_0000_0000, low: 1))
        let i128MaxMinusOne = Int128Value(bitPattern: UInt128Value(high: 0x7FFF_FFFF_FFFF_FFFF, low: UInt64.max - 1))
        try assertValid(getI128Codec(), Int128Value(42), "2a000000000000000000000000000000")
        try assertValid(getI128Codec(NumberCodecConfig(endian: .big)), Int128Value(42), "0000000000000000000000000000002a")
        try assertValid(getI128Codec(), Int128Value(-42), "d6ffffffffffffffffffffffffffffff")
        try assertValid(getI128Codec(NumberCodecConfig(endian: .big)), Int128Value(-42), "ffffffffffffffffffffffffffffffd6")
        try assertValid(getI128Codec(), i128MinPlusOne, "01000000000000000000000000000080")
        try assertValid(getI128Codec(NumberCodecConfig(endian: .big)), i128MinPlusOne, "80000000000000000000000000000001")
        try assertValid(getI128Codec(), i128MaxMinusOne, "feffffffffffffffffffffffffffff7f")
        try assertValid(getI128Codec(NumberCodecConfig(endian: .big)), i128MaxMinusOne, "7ffffffffffffffffffffffffffffffe")
        try assertValid(getI128Codec(), Int128Value.min, "00000000000000000000000000000080")
        try assertValid(getI128Codec(NumberCodecConfig(endian: .big)), Int128Value.min, "80000000000000000000000000000000")
        try assertValid(getI128Codec(), Int128Value.max, "ffffffffffffffffffffffffffffff7f")
        XCTAssertEqual(getI128Codec().fixedSize, 16)
    }

    func testFloatingPointCodecs() throws {
        let f32Pi = Double(Float(Double.pi))
        try assertValid(getF32Codec(), 0, "00000000")
        try assertValid(getF32Codec(NumberCodecConfig(endian: .big)), 1, "3f800000")
        try assertValid(getF32Codec(), 42, "00002842")
        try assertValid(getF32Codec(NumberCodecConfig(endian: .big)), 42, "42280000")
        try assertValid(getF32Codec(), Double.pi, "db0f4940", decoded: f32Pi)
        try assertValid(getF32Codec(NumberCodecConfig(endian: .big)), -Double.pi, "c0490fdb", decoded: -f32Pi)
        XCTAssertEqual(getF32Codec().fixedSize, 4)

        try assertValid(getF64Codec(), 1, "000000000000f03f")
        try assertValid(getF64Codec(NumberCodecConfig(endian: .big)), 1, "3ff0000000000000")
        try assertValid(getF64Codec(), 42, "0000000000004540")
        try assertValid(getF64Codec(NumberCodecConfig(endian: .big)), -42, "c045000000000000")
        try assertValid(getF64Codec(), Double.pi, "182d4454fb210940", decoded: Double.pi)
        XCTAssertEqual(getF64Codec().fixedSize, 8)
    }

    func testShortU16Codec() throws {
        let codec = getShortU16Codec()
        try assertValid(codec, 0, "00")
        try assertValid(codec, 42, "2a")
        try assertValid(codec, 127, "7f")
        try assertValid(codec, 128, "8001")
        try assertValid(codec, 16_383, "ff7f")
        try assertValid(codec, 16_384, "808001")
        try assertValid(codec, 65_535, "ffff03")
        assertRangeError(codec, value: -1, codecDescription: "shortU16", min: "0", max: "65535", valueDescription: "-1")
        assertRangeError(codec, value: 65_536, codecDescription: "shortU16", min: "0", max: "65535", valueDescription: "65536")

        XCTAssertEqual(codec.maxSize, 3)
        XCTAssertEqual(try codec.getSizeFromValue(1), 1)
        XCTAssertEqual(try codec.getSizeFromValue(127), 1)
        XCTAssertEqual(try codec.getSizeFromValue(128), 2)
        XCTAssertEqual(try codec.getSizeFromValue(16_383), 2)
        XCTAssertEqual(try codec.getSizeFromValue(16_384), 3)
        XCTAssertEqual(try codec.getSizeFromValue(-1), 1)

        let emptyRead = try getShortU16Decoder().read(Data(), at: 0)
        XCTAssertEqual(emptyRead.0, 0)
        XCTAssertEqual(emptyRead.1, 1)
    }

    func testFixedDecodersUseExpectedErrorCodes() {
        XCTAssertThrowsError(try getU16Decoder().decode(Data())) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsCannotDecodeEmptyByteArray.rawValue)
        }
        XCTAssertThrowsError(try getU16Decoder().decode(Data([0x01]))) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsInvalidByteLength.rawValue)
        }
    }

    func testOneHundredTwentyEightBitDescriptions() {
        XCTAssertEqual(UInt128Value.max.description, "340282366920938463463374607431768211455")
        XCTAssertEqual(Int128Value.min.description, "-170141183460469231731687303715884105728")
        XCTAssertEqual(Int128Value.max.description, "170141183460469231731687303715884105727")
        XCTAssertLessThan(Int128Value.min, Int128Value(-42))
        XCTAssertLessThan(Int128Value(-42), Int128Value(0))
    }
}

private func assertValid<C: Codec>(
    _ codec: C,
    _ value: C.Encoded,
    _ expectedHex: String,
    decoded expectedDecoded: C.Decoded? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) throws where C.Decoded: Equatable {
    let actualBytes = try codec.encode(value)
    XCTAssertEqual(actualBytes.hex, expectedHex, file: file, line: line)

    let expectedValue = try XCTUnwrap(expectedDecoded ?? value as? C.Decoded, file: file, line: line)
    let read = try codec.read(actualBytes, at: 0)
    XCTAssertEqual(read.0, expectedValue, file: file, line: line)
    XCTAssertEqual(read.1, actualBytes.count, file: file, line: line)

    let offsetRead = try codec.read(Data(hex: "ffffff\(expectedHex)"), at: 3)
    XCTAssertEqual(offsetRead.0, expectedValue, file: file, line: line)
    XCTAssertEqual(offsetRead.1, actualBytes.count + 3, file: file, line: line)
}

private func assertRangeError<E: Encoder>(
    _ encoder: E,
    value: E.Encoded,
    codecDescription: String,
    min: String,
    max: String,
    valueDescription: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try encoder.encode(value), file: file, line: line) { error in
        guard case let CodecsError.numberOutOfRange(actualCodecDescription, actualMin, actualMax, actualValue) = error else {
            XCTFail("Expected numberOutOfRange, got \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(actualCodecDescription, codecDescription, file: file, line: line)
        XCTAssertEqual(actualMin, min, file: file, line: line)
        XCTAssertEqual(actualMax, max, file: file, line: line)
        XCTAssertEqual(actualValue, valueDescription, file: file, line: line)
        XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsNumberOutOfRange.rawValue, file: file, line: line)
    }
}

private extension Data {
    init(hex: String) throws {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let byte = try XCTUnwrap(UInt8(hex[index ..< next], radix: 16))
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
