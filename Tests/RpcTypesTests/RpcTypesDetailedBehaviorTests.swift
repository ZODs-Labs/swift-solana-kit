import Addresses
import CodecsCore
import CodecsNumbers
import FixedPoints
import RpcTypes
import SolanaErrors
import XCTest

final class RpcTypesDetailedBehaviorTests: XCTestCase {
    func testBlockhashValidationReportsLengthByteLengthAndBaseErrors() throws {
        let invalidBase = "not-a-base-58-encoded-string-but-nice-try"
        XCTAssertThrowsError(try assertIsBlockhash(invalidBase)) { error in
            guard case let AddressValidationError.codecs(.invalidStringForBase(value, base, alphabet)) = error else {
                return XCTFail("Expected invalid base error, got \(error)")
            }
            XCTAssertEqual(value, invalidBase)
            XCTAssertEqual(base, 58)
            XCTAssertEqual(alphabet, "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        }
        try Self.assertError(
            try assertIsBlockhash(String(repeating: "1", count: 31)),
            code: .blockhashStringLengthOutOfRange,
            context: ["actualLength": .int(31)]
        )
        try Self.assertError(
            try assertIsBlockhash(String(repeating: "1", count: 45)),
            code: .blockhashStringLengthOutOfRange,
            context: ["actualLength": .int(45)]
        )
        try Self.assertError(
            try assertIsBlockhash("tVojvhToWjQ8Xvo4UPx2Xz9eRy7auyYMmZBjc2XfN"),
            code: .invalidBlockhashByteLength,
            context: ["actualLength": .int(31)]
        )
        try Self.assertError(
            try assertIsBlockhash("JJEfe6DcPM2ziB2vfUWDV6aHVerXRGkv3TcyvJUNGHZz"),
            code: .invalidBlockhashByteLength,
            context: ["actualLength": .int(33)]
        )

        XCTAssertFalse(isBlockhash(String(repeating: "1", count: 31)))
        XCTAssertFalse(isBlockhash("tVojvhToWjQ8Xvo4UPx2Xz9eRy7auyYMmZBjc2XfN"))
        XCTAssertNoThrow(try assertIsBlockhash("11111111111111111111111111111111"))
        XCTAssertEqual(try blockhash("11111111111111111111111111111111"), "11111111111111111111111111111111")
    }

    func testBlockhashCodecFixedSizeOffsetsAndShortBufferFailures() throws {
        let codec = getBlockhashCodec()
        XCTAssertEqual(codec.fixedSize, 32)

        var bytes = Data(repeating: 0xee, count: 36)
        let offset = try codec.write("11111111111111111111111111111111", into: &bytes, at: 2)
        XCTAssertEqual(offset, 34)
        XCTAssertEqual(bytes.prefix(2), Data([0xee, 0xee]))
        XCTAssertEqual(bytes.dropFirst(2).prefix(32), Data(repeating: 0, count: 32))
        XCTAssertEqual(bytes.suffix(2), Data([0xee, 0xee]))

        let decoded = try codec.read(Data([0xaa, 0xbb] + Array(repeating: 0, count: 32) + [0xcc]), at: 2)
        XCTAssertEqual(decoded.0, "11111111111111111111111111111111")
        XCTAssertEqual(decoded.1, 34)

        try Self.assertError(
            try codec.decode(Data(repeating: 0, count: 31)),
            code: .codecsInvalidByteLength,
            context: [
                "bytesLength": .int(31),
                "codecDescription": .string("fixCodecSize"),
                "expected": .int(32),
            ]
        )
    }

    func testLamportsCodecsExposeSizesEndianChoicesAndBoundaryBytes() throws {
        XCTAssertTrue(isLamports(0))
        XCTAssertTrue(isLamports(UInt64.max))
        XCTAssertNoThrow(try assertIsLamports(UInt64.max))
        XCTAssertEqual(lamports(UInt64.max), UInt64.max)

        XCTAssertEqual(getDefaultLamportsEncoder().fixedSize, 8)
        XCTAssertEqual(getDefaultLamportsDecoder().fixedSize, 8)
        XCTAssertEqual(getDefaultLamportsCodec().fixedSize, 8)
        XCTAssertEqual(
            try getDefaultLamportsDecoder().decode(Data([0, 29, 50, 247, 69, 0, 0, 0])),
            300_500_000_000
        )

        XCTAssertEqual(try getLamportsEncoder(getU8Encoder()).encode(100), Data([100]))
        XCTAssertEqual(
            try getLamportsEncoder(getU16Encoder(NumberCodecConfig(endian: .big))).encode(100),
            Data([0, 100])
        )
        XCTAssertEqual(
            try getLamportsEncoder(getU64Encoder()).encode(UInt64.max),
            Data(repeating: 0xff, count: 8)
        )
        XCTAssertEqual(getLamportsEncoder(getU8Encoder()).fixedSize, 1)

        XCTAssertEqual(try getLamportsDecoder(getU8Decoder()).decode(Data([100])), 100)
        XCTAssertEqual(
            try getLamportsDecoder(getU16Decoder(NumberCodecConfig(endian: .big))).decode(Data([0, 100])),
            100
        )
        XCTAssertEqual(try getLamportsDecoder(getU64Decoder()).decode(Data(repeating: 0xff, count: 8)), UInt64.max)
        XCTAssertEqual(getLamportsDecoder(getU8Decoder()).fixedSize, 1)

        let smallCodec = getLamportsCodec(getU8Codec())
        XCTAssertEqual(try smallCodec.encode(100), Data([100]))
        XCTAssertEqual(try smallCodec.decode(Data([100])), 100)
        XCTAssertEqual(smallCodec.fixedSize, 1)
    }

    func testSolParsingRoundingMetadataAndWireFormat() throws {
        XCTAssertEqual(try sol("1").raw, 1_000_000_000)
        XCTAssertEqual(try sol("1.5").raw, 1_500_000_000)
        XCTAssertEqual(try sol("0").raw, 0)
        XCTAssertEqual(try sol("0.000000001").raw, 1)
        XCTAssertEqual(try sol("1.1234567891", rounding: .round).raw, 1_123_456_789)
        XCTAssertEqual(try sol("1.1234567899", rounding: .floor).raw, 1_123_456_789)
        XCTAssertEqual(try sol("1.1234567891", rounding: .ceil).raw, 1_123_456_790)

        try Self.assertError(
            try sol("1.1234567891"),
            code: .fixedPointsStrictModePrecisionLoss,
            context: [
                "kind": .string("decimalFixedPoint"),
                "operation": .string("fromString"),
            ]
        )
        try Self.assertError(
            try sol("18446744074"),
            code: .fixedPointsValueOutOfRange,
            context: [
                "kind": .string("decimalFixedPoint"),
                "max": .string("18446744073709551615"),
                "min": .string("0"),
                "raw": .string("18446744074000000000"),
                "signedness": .string("unsigned"),
                "totalBits": .int(64),
            ]
        )

        let fractional = try sol("1.5")
        XCTAssertEqual(try solToLamports(fractional), 1_500_000_000)
        XCTAssertEqual(try lamportsToSol(1_500_000_000).raw, 1_500_000_000)
        XCTAssertEqual(try lamportsToSol(UInt64.max).raw, FixedPointRaw(UInt64.max))
        XCTAssertEqual(fractional.kind, .decimalFixedPoint)
        XCTAssertEqual(fractional.signedness, .unsigned)
        XCTAssertEqual(fractional.totalBits, 64)
        XCTAssertEqual(fractional.decimals, 9)

        let expected = Data([0x00, 0x2f, 0x68, 0x59, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(getSolEncoder().fixedSize, 8)
        XCTAssertEqual(getSolDecoder().fixedSize, 8)
        XCTAssertEqual(getSolCodec().fixedSize, 8)
        XCTAssertEqual(try getSolEncoder().encode(fractional), expected)
        XCTAssertEqual(try getSolDecoder().decode(expected).raw, 1_500_000_000)
        XCTAssertEqual(try getSolCodec().decode(try getSolCodec().encode(try sol("42.5"))), try sol("42.5"))
    }

    func testStringifiedCoercionsReturnInputAndReportMalformedContexts() throws {
        XCTAssertEqual(try stringifiedBigInt("1234"), "1234")
        XCTAssertEqual(try stringifiedNumber("1234"), "1234")

        for value in ["abc", "123a", "123.0", "123.5"] {
            try Self.assertError(
                try assertIsStringifiedBigInt(value),
                code: .malformedBigintString,
                context: ["value": .string(value)]
            )
        }
        for value in ["abc", "123a", "NaN"] {
            try Self.assertError(
                try assertIsStringifiedNumber(value),
                code: .malformedNumberString,
                context: ["value": .string(value)]
            )
        }

        for value in ["-123", "0", "123"] {
            XCTAssertNoThrow(try assertIsStringifiedBigInt(value), value)
            XCTAssertNoThrow(try assertIsStringifiedNumber(value), value)
        }
        for value in ["123.0", "123.5", ".5", "1.e2"] {
            XCTAssertNoThrow(try assertIsStringifiedNumber(value), value)
        }
    }

    func testUnixTimestampAcceptsSignedSixtyFourBitRange() throws {
        XCTAssertTrue(isUnixTimestamp(0))
        XCTAssertTrue(isUnixTimestamp(1_000_000_000))
        XCTAssertTrue(isUnixTimestamp(Int64.max))
        XCTAssertTrue(isUnixTimestamp(Int64.min))

        XCTAssertNoThrow(try assertIsUnixTimestamp(0))
        XCTAssertNoThrow(try assertIsUnixTimestamp(1_000_000_000))
        XCTAssertNoThrow(try assertIsUnixTimestamp(Int64.max))
        XCTAssertNoThrow(try assertIsUnixTimestamp(Int64.min))
        XCTAssertEqual(unixTimestamp(Int64.max), Int64.max)
    }

    private static func assertError<T>(
        _ expression: @autoclosure () throws -> T,
        code: SolanaErrorCode,
        context: SolanaErrorContext = .empty,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        do {
            _ = try expression()
            XCTFail("Expected a Solana error", file: file, line: line)
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, code.rawValue, file: file, line: line)
            for (key, value) in context.values {
                XCTAssertEqual(error.context[key], value, key, file: file, line: line)
            }
        } catch let error as CodecsError {
            XCTAssertEqual(error.code, code.rawValue, file: file, line: line)
            for (key, value) in context.values {
                XCTAssertEqual(error.context[key], value, key, file: file, line: line)
            }
        } catch let error as any SolanaErrorCoded {
            XCTAssertEqual(error.code, code.rawValue, file: file, line: line)
            XCTAssertTrue(context.values.isEmpty, file: file, line: line)
        }
    }
}
