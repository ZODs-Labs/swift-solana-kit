import FixedPoints
import Foundation
import SolanaErrors
import XCTest

final class FixedPointRuntimeBehaviorTests: XCTestCase {
    func testDecimalComparisonsAllowDifferentSignednessAndWidthsButRejectScaleMismatch() throws {
        let signed = try decimalFixedPoint(.signed, 16, 2)
        let unsigned = try decimalFixedPoint(.unsigned, 64, 2)
        let otherWidth = try decimalFixedPoint(.unsigned, 128, 2)
        let otherDecimals = try decimalFixedPoint(.unsigned, 64, 3)

        XCTAssertEqual(try cmpDecimalFixedPoint(try signed("-1.25"), try unsigned("1.25")), -1)
        XCTAssertEqual(try cmpDecimalFixedPoint(try signed("1.25"), try unsigned("1.25")), 0)
        XCTAssertEqual(try cmpDecimalFixedPoint(try otherWidth("2.50"), try unsigned("1.25")), 1)
        XCTAssertTrue(try ltDecimalFixedPoint(try signed("-1.25"), try unsigned("1.25")))
        XCTAssertTrue(try lteDecimalFixedPoint(try signed("1.25"), try unsigned("1.25")))
        XCTAssertTrue(try gtDecimalFixedPoint(try unsigned("2.50"), try signed("1.25")))
        XCTAssertTrue(try gteDecimalFixedPoint(try signed("1.25"), try unsigned("1.25")))
        XCTAssertFalse(try eqDecimalFixedPoint(try unsigned("1.25"), try unsigned("2.50")))

        try Self.assertSolanaError(
            cmpDecimalFixedPoint(try unsigned("1.25"), try otherDecimals("1.250")),
            code: .fixedPointsShapeMismatch,
            context: ["expectedScale": .int(2), "expectedScaleLabel": .string("decimals")]
        )
    }

    func testBinaryComparisonsAllowDifferentSignednessAndWidthsButRejectScaleMismatch() throws {
        let signed = try binaryFixedPoint(.signed, 16, 15)
        let unsigned = try binaryFixedPoint(.unsigned, 32, 15)
        let otherWidth = try binaryFixedPoint(.unsigned, 64, 15)
        let otherFractionalBits = try binaryFixedPoint(.unsigned, 32, 14)

        XCTAssertEqual(try cmpBinaryFixedPoint(try signed("-0.5"), try unsigned("0.5")), -1)
        XCTAssertEqual(try cmpBinaryFixedPoint(try signed("0.5"), try unsigned("0.5")), 0)
        XCTAssertEqual(try cmpBinaryFixedPoint(try otherWidth("0.75"), try unsigned("0.5")), 1)
        XCTAssertTrue(try ltBinaryFixedPoint(try signed("-0.5"), try unsigned("0.5")))
        XCTAssertTrue(try lteBinaryFixedPoint(try signed("0.5"), try unsigned("0.5")))
        XCTAssertTrue(try gtBinaryFixedPoint(try unsigned("0.75"), try signed("0.5")))
        XCTAssertTrue(try gteBinaryFixedPoint(try signed("0.5"), try unsigned("0.5")))
        XCTAssertFalse(try eqBinaryFixedPoint(try unsigned("0.5"), try unsigned("0.75")))

        try Self.assertSolanaError(
            cmpBinaryFixedPoint(try unsigned("0.5"), try otherFractionalBits("0.5")),
            code: .fixedPointsShapeMismatch,
            context: ["expectedScale": .int(15), "expectedScaleLabel": .string("fractional bits")]
        )
    }

    func testDecimalArithmeticRoundingOverflowAndSignedExtremes() throws {
        let cents = try decimalFixedPoint(.unsigned, 16, 2)
        let basisPoints = try decimalFixedPoint(.unsigned, 32, 4)
        let signedRaw = try rawDecimalFixedPoint(.signed, 8, 0)

        XCTAssertEqual(try multiplyDecimalFixedPoint(try cents("1.00"), try basisPoints("0.2500")).raw, 25)
        try Self.assertSolanaError(
            multiplyDecimalFixedPoint(try cents("1.00"), try basisPoints("0.3333")),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("decimalFixedPoint"), "operation": .string("multiply")]
        )
        XCTAssertEqual(
            try multiplyDecimalFixedPoint(try cents("1.00"), try basisPoints("0.3333"), rounding: .round).raw,
            33
        )

        try Self.assertSolanaError(
            divideDecimalFixedPoint(try cents("1.00"), FixedPointRaw(3)),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("decimalFixedPoint"), "operation": .divideString]
        )
        XCTAssertEqual(try divideDecimalFixedPoint(try cents("1.00"), FixedPointRaw(3), rounding: .round).raw, 33)

        try Self.assertSolanaError(
            addDecimalFixedPoint(try (try rawDecimalFixedPoint(.unsigned, 8, 0))(255), try (try rawDecimalFixedPoint(.unsigned, 8, 0))(1)),
            code: .fixedPointsArithmeticOverflow,
            context: ["operation": .string("add"), "result": .string("256")]
        )
        try Self.assertSolanaError(
            subtractDecimalFixedPoint(try signedRaw(-128), try signedRaw(1)),
            code: .fixedPointsArithmeticOverflow,
            context: ["operation": .string("subtract"), "result": .string("-129")]
        )
        try Self.assertSolanaError(
            negateDecimalFixedPoint(try signedRaw(-128)),
            code: .fixedPointsArithmeticOverflow,
            context: ["operation": .string("negate"), "result": .string("128")]
        )
        try Self.assertSolanaError(
            absoluteDecimalFixedPoint(try signedRaw(-128)),
            code: .fixedPointsArithmeticOverflow,
            context: ["operation": .string("absolute"), "result": .string("128")]
        )
    }

    func testBinaryArithmeticHandlesDifferentScalesRoundingAndSignedExtremes() throws {
        let q1x15 = try binaryFixedPoint(.signed, 16, 15)
        let q16 = try binaryFixedPoint(.signed, 32, 16)
        let rawSigned8 = try rawBinaryFixedPoint(.signed, 8, 0)

        XCTAssertEqual(try multiplyBinaryFixedPoint(try q1x15("0.5"), try q16("0.5")).raw, 8_192)
        XCTAssertEqual(try divideBinaryFixedPoint(try q1x15("0.5"), try q16("1")).raw, 16_384)

        let oneUnit = try (try rawBinaryFixedPoint(.unsigned, 16, 15))(1)
        try Self.assertSolanaError(
            multiplyBinaryFixedPoint(oneUnit, oneUnit),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("binaryFixedPoint"), "operation": .string("multiply")]
        )
        XCTAssertEqual(try multiplyBinaryFixedPoint(oneUnit, oneUnit, rounding: .ceil).raw, 1)
        try Self.assertSolanaError(
            divideBinaryFixedPoint(oneUnit, try (try rawBinaryFixedPoint(.unsigned, 16, 15))(3)),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("binaryFixedPoint"), "operation": .divideString]
        )
        XCTAssertEqual(
            try divideBinaryFixedPoint(oneUnit, try (try rawBinaryFixedPoint(.unsigned, 16, 15))(3), rounding: .round).raw,
            10_923
        )

        try Self.assertSolanaError(
            negateBinaryFixedPoint(try rawSigned8(-128)),
            code: .fixedPointsArithmeticOverflow,
            context: ["operation": .string("negate"), "result": .string("128")]
        )
        try Self.assertSolanaError(
            absoluteBinaryFixedPoint(try rawSigned8(-128)),
            code: .fixedPointsArithmeticOverflow,
            context: ["operation": .string("absolute"), "result": .string("128")]
        )
    }

    func testDecimalCodecsPreserveSignedBytesEndianAndOffsets() throws {
        let signed8 = try rawDecimalFixedPoint(.signed, 8, 0)
        XCTAssertEqual(try getDecimalFixedPointCodec(.signed, 8, 0).encode(try signed8(-1)), Data([0xff]))
        XCTAssertEqual(try getDecimalFixedPointCodec(.signed, 8, 0).decode(Data([0x80])).raw, -128)

        let raw24 = try rawDecimalFixedPoint(.unsigned, 24, 0)
        let value24 = try raw24(try FixedPointRaw(decimalString: "11259375"))
        XCTAssertEqual(try getDecimalFixedPointCodec(.unsigned, 24, 0).encode(value24), Data([0xef, 0xcd, 0xab]))
        XCTAssertEqual(
            try getDecimalFixedPointCodec(.unsigned, 24, 0, config: FixedPointCodecConfig(endian: .big)).encode(value24),
            Data([0xab, 0xcd, 0xef])
        )

        let encoder = try getDecimalFixedPointEncoder(.unsigned, 16, 0)
        let decoder = try getDecimalFixedPointDecoder(.unsigned, 16, 0)
        var bytes = Data([0, 0, 0, 0])
        let nextWriteOffset = try encoder.write(try (try rawDecimalFixedPoint(.unsigned, 16, 0))(0x1234), into: &bytes, at: 1)
        let read = try decoder.read(bytes, at: 1)

        XCTAssertEqual(nextWriteOffset, 3)
        XCTAssertEqual(bytes, Data([0, 0x34, 0x12, 0]))
        XCTAssertEqual(read.0.raw, 0x1234)
        XCTAssertEqual(read.1, 3)

        try Self.assertSolanaError(
            encoder.encode(try (try rawDecimalFixedPoint(.unsigned, 8, 0))(1)),
            code: .fixedPointsShapeMismatch,
            context: ["expectedTotalBits": .int(16)]
        )
    }

    func testGuardsNarrowValidValuesAndReportMismatchedShapes() throws {
        let decimal = try (try rawDecimalFixedPoint(.unsigned, 64, 6))(42)
        let binary = try (try rawBinaryFixedPoint(.signed, 16, 15))(-16_384)

        XCTAssertTrue(isDecimalFixedPoint(decimal))
        XCTAssertTrue(isDecimalFixedPoint(decimal, signedness: .unsigned, totalBits: 64, decimals: 6))
        XCTAssertFalse(isDecimalFixedPoint(decimal, signedness: .signed))
        XCTAssertFalse(isDecimalFixedPoint(decimal, totalBits: 32))
        XCTAssertFalse(isDecimalFixedPoint(decimal, decimals: 2))
        try assertIsDecimalFixedPoint(decimal, signedness: .unsigned, totalBits: 64, decimals: 6)
        try Self.assertSolanaError(
            assertIsDecimalFixedPoint(decimal, signedness: .signed),
            code: .fixedPointsShapeMismatch,
            context: ["expectedSignedness": .string("signed")]
        )

        XCTAssertTrue(isBinaryFixedPoint(binary))
        XCTAssertTrue(isBinaryFixedPoint(binary, signedness: .signed, totalBits: 16, fractionalBits: 15))
        XCTAssertFalse(isBinaryFixedPoint(binary, signedness: .unsigned))
        XCTAssertFalse(isBinaryFixedPoint(binary, totalBits: 32))
        XCTAssertFalse(isBinaryFixedPoint(binary, fractionalBits: 14))
        try assertIsBinaryFixedPoint(binary, signedness: .signed, totalBits: 16, fractionalBits: 15)
        try Self.assertSolanaError(
            assertIsBinaryFixedPoint(binary, fractionalBits: 14),
            code: .fixedPointsShapeMismatch,
            context: ["expectedScale": .int(14), "expectedScaleLabel": .string("fractional bits")]
        )
    }

    func testParsingAndFormattingPreserveEdgeCaseTextSemantics() throws {
        let decimal = try decimalFixedPoint(.signed, 32, 3)
        XCTAssertEqual(try decimal(".5").raw, 500)
        XCTAssertEqual(try decimal("5.").raw, 5_000)
        XCTAssertEqual(try decimal("-.5").raw, -500)

        for invalid in ["", "-", ".", "+1", " 1", "1 ", "1.2.3", "1,5", "１２"] {
            try Self.assertSolanaError(
                decimal(invalid),
                code: .fixedPointsInvalidString,
                context: ["kind": .string("decimalFixedPoint"), "input": .string(invalid)]
            )
        }

        let rawBinary = try rawBinaryFixedPoint(.unsigned, 32, 20)
        XCTAssertEqual(try binaryFixedPointToString(try rawBinary(1)), "0.00000095367431640625")
        XCTAssertEqual(
            try binaryFixedPointToString(
                try rawBinary(1),
                options: FixedPointToStringOptions(decimals: 6, padTrailingZeros: true, rounding: .round)
            ),
            "0.000001"
        )
        try Self.assertSolanaError(
            binaryFixedPointToString(try rawBinary(1), options: FixedPointToStringOptions(decimals: 6)),
            code: .fixedPointsStrictModePrecisionLoss,
            context: ["kind": .string("binaryFixedPoint"), "operation": .string("toString")]
        )
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

private extension SolanaErrorContextValue {
    static var divideString: SolanaErrorContextValue {
        .string("divide")
    }
}
