import FixedPoints
import Foundation
import SolanaErrors
import XCTest

final class FixedPointDetailedBehaviorTests: XCTestCase {
    func testDecimalFactoriesExposeShapeFieldsAndErrorContexts() throws {
        let usdc = try decimalFixedPoint(.unsigned, 64, 6)
        let value = try usdc("1.5")
        XCTAssertEqual(value.kind, .decimalFixedPoint)
        XCTAssertEqual(value.signedness, .unsigned)
        XCTAssertEqual(value.totalBits, 64)
        XCTAssertEqual(value.decimals, 6)
        XCTAssertEqual(value.raw, 1_500_000)

        try Self.assertSolanaError(
            (try rawDecimalFixedPoint(.unsigned, 8, 0))(256),
            code: .fixedPointsValueOutOfRange,
            context: [
                "kind": .string("decimalFixedPoint"),
                "max": .string("255"),
                "min": .string("0"),
                "raw": .string("256"),
                "signedness": .string("unsigned"),
                "totalBits": .int(8),
            ]
        )
        try Self.assertSolanaError(
            (try rawDecimalFixedPoint(.signed, 8, 0))(-129),
            code: .fixedPointsValueOutOfRange,
            context: [
                "kind": .string("decimalFixedPoint"),
                "max": .string("127"),
                "min": .string("-128"),
                "raw": .string("-129"),
                "signedness": .string("signed"),
                "totalBits": .int(8),
            ]
        )
        try Self.assertSolanaError(
            decimalFixedPoint(.unsigned, 0, 6),
            code: .fixedPointsInvalidTotalBits,
            context: ["kind": .string("decimalFixedPoint"), "totalBits": .int(0)]
        )
        try Self.assertSolanaError(
            decimalFixedPoint(.unsigned, 64, -1),
            code: .fixedPointsInvalidDecimals,
            context: ["decimals": .int(-1)]
        )

        let tiny = try decimalFixedPoint(.unsigned, 8, 10)
        XCTAssertEqual(try tiny("0").raw, 0)
    }

    func testDecimalRatioRoundingAndErrorContexts() throws {
        let probability = try ratioDecimalFixedPoint(.unsigned, 64, 4)
        XCTAssertEqual(try probability(1, 4).raw, 2_500)
        XCTAssertEqual(try probability(1, 3, rounding: .round).raw, 3_333)

        try Self.assertSolanaError(
            probability(1, 3),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("decimalFixedPoint"), "operation": .string("fromRatio")]
        )
        try Self.assertSolanaError(
            probability(1, 0),
            code: .fixedPointsInvalidZeroDenominatorRatio,
            context: [
                "denominator": .string("0"),
                "kind": .string("decimalFixedPoint"),
                "numerator": .string("1"),
            ]
        )
    }

    func testDecimalFormattingOptionsCoverZeroPaddingAndLossyCaps() throws {
        let raw6 = try rawDecimalFixedPoint(.unsigned, 64, 6)
        XCTAssertEqual(try decimalFixedPointToString(try raw6(0)), "0")
        XCTAssertEqual(try decimalFixedPointToString(try raw6(42_000_000)), "42")
        XCTAssertEqual(try decimalFixedPointToString(try raw6(42_500_000)), "42.5")
        XCTAssertEqual(
            try decimalFixedPointToString(
                try raw6(42_500_000),
                options: FixedPointToStringOptions(decimals: 10)
            ),
            "42.5"
        )
        XCTAssertEqual(
            try decimalFixedPointToString(
                try raw6(42_500_000),
                options: FixedPointToStringOptions(decimals: 6, padTrailingZeros: true)
            ),
            "42.500000"
        )
        XCTAssertEqual(
            try decimalFixedPointToString(
                try raw6(0),
                options: FixedPointToStringOptions(padTrailingZeros: true)
            ),
            "0.000000"
        )
        XCTAssertEqual(
            try decimalFixedPointToString(
                try (try rawDecimalFixedPoint(.unsigned, 64, 1))(425),
                options: FixedPointToStringOptions(decimals: 0, rounding: .round)
            ),
            "43"
        )
        try Self.assertSolanaError(
            decimalFixedPointToString(
                try (try rawDecimalFixedPoint(.unsigned, 64, 1))(425),
                options: FixedPointToStringOptions(decimals: 0)
            ),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("decimalFixedPoint"), "operation": .string("toString")]
        )
        XCTAssertEqual(
            decimalFixedPointToNumber(try (try rawDecimalFixedPoint(.signed, 16, 2))(-5)),
            -0.05
        )
    }

    func testDecimalSignednessConversionsPreserveShapeAndRejectOutOfRangeValues() throws {
        let signed = try rawDecimalFixedPoint(.signed, 8, 2)
        let unsigned = try rawDecimalFixedPoint(.unsigned, 8, 2)

        let convertedToUnsigned = try toUnsignedDecimalFixedPoint(try signed(100))
        XCTAssertEqual(convertedToUnsigned.signedness, .unsigned)
        XCTAssertEqual(convertedToUnsigned.totalBits, 8)
        XCTAssertEqual(convertedToUnsigned.decimals, 2)
        XCTAssertEqual(convertedToUnsigned.raw, 100)

        let convertedToSigned = try toSignedDecimalFixedPoint(try unsigned(100))
        XCTAssertEqual(convertedToSigned.signedness, .signed)
        XCTAssertEqual(convertedToSigned.totalBits, 8)
        XCTAssertEqual(convertedToSigned.decimals, 2)
        XCTAssertEqual(convertedToSigned.raw, 100)

        try Self.assertSolanaError(
            toUnsignedDecimalFixedPoint(try signed(-1)),
            code: .fixedPointsValueOutOfRange,
            context: ["raw": .string("-1"), "signedness": .string("unsigned")]
        )
        try Self.assertSolanaError(
            toSignedDecimalFixedPoint(try unsigned(200)),
            code: .fixedPointsValueOutOfRange,
            context: ["raw": .string("200"), "signedness": .string("signed")]
        )
    }

    func testBinaryBase10AndSignednessConversionsMatchExactScaling() throws {
        let zero = try (try rawBinaryFixedPoint(.signed, 16, 15))(0)
        let zeroBase10 = binaryFixedPointToBase10(zero)
        XCTAssertEqual(zeroBase10.raw, 0)
        XCTAssertEqual(zeroBase10.decimals, 15)

        let smallest = try (try rawBinaryFixedPoint(.unsigned, 16, 15))(1)
        let smallestBase10 = binaryFixedPointToBase10(smallest)
        XCTAssertEqual(smallestBase10.raw, 30_517_578_125)
        XCTAssertEqual(smallestBase10.decimals, 15)

        let negative = try (try rawBinaryFixedPoint(.signed, 16, 15))(-16_384)
        let negativeBase10 = binaryFixedPointToBase10(negative)
        XCTAssertEqual(negativeBase10.raw, -500_000_000_000_000)
        XCTAssertEqual(negativeBase10.decimals, 15)

        let convertedToUnsigned = try toUnsignedBinaryFixedPoint(try (try rawBinaryFixedPoint(.signed, 8, 4))(100))
        XCTAssertEqual(convertedToUnsigned.signedness, .unsigned)
        XCTAssertEqual(convertedToUnsigned.fractionalBits, 4)

        let convertedToSigned = try toSignedBinaryFixedPoint(try (try rawBinaryFixedPoint(.unsigned, 8, 4))(100))
        XCTAssertEqual(convertedToSigned.signedness, .signed)
        XCTAssertEqual(convertedToSigned.fractionalBits, 4)

        try Self.assertSolanaError(
            toUnsignedBinaryFixedPoint(try (try rawBinaryFixedPoint(.signed, 8, 4))(-1)),
            code: .fixedPointsValueOutOfRange,
            context: ["raw": .string("-1"), "signedness": .string("unsigned")]
        )
        try Self.assertSolanaError(
            toSignedBinaryFixedPoint(try (try rawBinaryFixedPoint(.unsigned, 8, 4))(200)),
            code: .fixedPointsValueOutOfRange,
            context: ["raw": .string("200"), "signedness": .string("signed")]
        )
    }

    func testBinaryRescaleExactPathsAndOverflowContexts() throws {
        let source = try (try rawBinaryFixedPoint(.unsigned, 8, 2))(1)
        XCTAssertEqual(try rescaleBinaryFixedPoint(source, 8, 4).raw, 4)
        XCTAssertEqual(try rescaleBinaryFixedPoint(try (try rawBinaryFixedPoint(.unsigned, 8, 4))(16), 8, 2).raw, 4)
        XCTAssertEqual(try rescaleBinaryFixedPoint(try (try rawBinaryFixedPoint(.unsigned, 16, 0))(100), 8, 0).raw, 100)

        try Self.assertSolanaError(
            rescaleBinaryFixedPoint(source, 8, 1),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("binaryFixedPoint"), "operation": .string("rescale")]
        )
        XCTAssertEqual(try rescaleBinaryFixedPoint(source, 8, 1, rounding: .floor).raw, 0)
        XCTAssertEqual(try rescaleBinaryFixedPoint(source, 8, 1, rounding: .ceil).raw, 1)

        try Self.assertSolanaError(
            rescaleBinaryFixedPoint(try (try rawBinaryFixedPoint(.unsigned, 16, 0))(300), 8, 0),
            code: .fixedPointsArithmeticOverflow,
            context: [
                "kind": .string("binaryFixedPoint"),
                "operation": .string("rescale"),
                "result": .string("300"),
                "signedness": .string("unsigned"),
                "totalBits": .int(8),
            ]
        )
    }

    func testBinaryCodecResidualWidthsAndEndianness() throws {
        try assertBinaryEncoding(.unsigned, 24, 0, "11259375", .little, [0xef, 0xcd, 0xab])
        try assertBinaryEncoding(.unsigned, 24, 0, "11259375", .big, [0xab, 0xcd, 0xef])
        try assertBinaryEncoding(.unsigned, 40, 0, "73588229205", .little, [0x55, 0x44, 0x33, 0x22, 0x11])
        try assertBinaryEncoding(.unsigned, 40, 0, "73588229205", .big, [0x11, 0x22, 0x33, 0x44, 0x55])
        try assertBinaryEncoding(.unsigned, 48, 0, "18838586676582", .little, [0x66, 0x55, 0x44, 0x33, 0x22, 0x11])
        try assertBinaryEncoding(.unsigned, 48, 0, "18838586676582", .big, [0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
        try assertBinaryEncoding(.unsigned, 56, 0, "4822678189205111", .little, [0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11])
        try assertBinaryEncoding(.unsigned, 56, 0, "4822678189205111", .big, [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77])
        try assertBinaryEncoding(.unsigned, 72, 0, "316059037807746189465", .little, [0x99, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11])
        try assertBinaryEncoding(.unsigned, 72, 0, "316059037807746189465", .big, [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99])
        try assertBinaryEncoding(
            .unsigned,
            128,
            0,
            "1339673755198158349044581307228491536",
            .little,
            [0x10, 0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]
        )
    }

    func testBinaryCodecRejectsInvalidShapesAndShortBuffers() throws {
        try Self.assertSolanaError(
            getBinaryFixedPointEncoder(.unsigned, 12, 4),
            code: .fixedPointsTotalBitsNotByteAligned,
            context: ["kind": .string("binaryFixedPoint"), "totalBits": .int(12)]
        )
        try Self.assertSolanaError(
            getBinaryFixedPointEncoder(.unsigned, 0, 0),
            code: .fixedPointsInvalidTotalBits,
            context: ["kind": .string("binaryFixedPoint"), "totalBits": .int(0)]
        )
        try Self.assertSolanaError(
            getBinaryFixedPointEncoder(.signed, 16, -1),
            code: .fixedPointsInvalidFractionalBits,
            context: ["fractionalBits": .int(-1)]
        )
        try Self.assertSolanaError(
            getBinaryFixedPointEncoder(.signed, 8, 16),
            code: .fixedPointsFractionalBitsExceedTotalBits,
            context: ["fractionalBits": .int(16), "totalBits": .int(8)]
        )
        try Self.assertSolanaError(
            try getBinaryFixedPointDecoder(.unsigned, 16, 0).decode(Data()),
            code: .codecsCannotDecodeEmptyByteArray,
            context: ["codecDescription": .string("getBinaryFixedPointDecoder")]
        )
        try Self.assertSolanaError(
            try getBinaryFixedPointDecoder(.unsigned, 32, 0).decode(Data([0x01, 0x02])),
            code: .codecsInvalidByteLength,
            context: [
                "bytesLength": .int(2),
                "codecDescription": .string("getBinaryFixedPointDecoder"),
                "expected": .int(4),
            ]
        )
    }

    private func assertBinaryEncoding(
        _ signedness: Signedness,
        _ totalBits: Int,
        _ fractionalBits: Int,
        _ raw: String,
        _ endian: FixedPointEndian,
        _ expectedBytes: [UInt8]
    ) throws {
        let factory = try rawBinaryFixedPoint(signedness, totalBits, fractionalBits)
        let value = try factory(try FixedPointRaw(decimalString: raw))
        let codec = try getBinaryFixedPointCodec(
            signedness,
            totalBits,
            fractionalBits,
            config: FixedPointCodecConfig(endian: endian)
        )
        let encoded = try codec.encode(value)
        XCTAssertEqual(Array(encoded), expectedBytes)
        XCTAssertEqual(try codec.decode(Data(expectedBytes)).raw, value.raw)
        XCTAssertEqual(codec.fixedSize, totalBits / 8)
    }

    private static func assertSolanaError<T>(
        _ expression: @autoclosure () throws -> T,
        code: SolanaErrorCode,
        context: SolanaErrorContext = .empty
    ) throws {
        do {
            _ = try expression()
            XCTFail("Expected a Solana error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, code.rawValue)
            for (key, value) in context.values {
                XCTAssertEqual(error.context[key], value, key)
            }
        } catch let error as CodecsError {
            XCTAssertEqual(error.code, code.rawValue)
            for (key, value) in context.values {
                XCTAssertEqual(error.context[key], value, key)
            }
        } catch let error as any SolanaErrorCoded {
            XCTAssertEqual(error.code, code.rawValue)
            XCTAssertTrue(context.values.isEmpty)
        }
    }
}
