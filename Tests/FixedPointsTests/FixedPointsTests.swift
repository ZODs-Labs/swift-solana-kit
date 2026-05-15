import FixedPoints
import Foundation
import SolanaErrors
import XCTest

final class FixedPointsTests: XCTestCase {
    func testDecimalFactoriesParseScaleAndBounds() throws {
        let usdc = try decimalFixedPoint(.unsigned, 64, 6)
        XCTAssertEqual(try usdc("0").raw, 0)
        XCTAssertEqual(try usdc("1").raw, 1_000_000)
        XCTAssertEqual(try usdc("42.5").raw, 42_500_000)
        XCTAssertEqual(try usdc("0.000001").raw, 1)
        XCTAssertEqual(try usdc("1234567890.123456").raw, try FixedPointRaw(decimalString: "1234567890123456"))

        let signed = try decimalFixedPoint(.signed, 32, 2)
        XCTAssertEqual(try signed("-1.5").raw, -150)
        XCTAssertEqual(try signed("-0").raw, 0)
        XCTAssertEqual(try signed(".5").raw, 50)
        XCTAssertEqual(try signed("-.25").raw, -25)
        XCTAssertEqual(try signed("5.").raw, 500)

        XCTAssertEqual(
            throwingSolanaCode { _ = try (try decimalFixedPoint(.unsigned, 16, 2))("1.234") },
            SolanaErrorCode.fixedPointsStrictModePrecisionLoss.rawValue
        )
        let cents = try decimalFixedPoint(.unsigned, 16, 2)
        XCTAssertEqual(try cents("1.234", rounding: .floor).raw, 123)
        XCTAssertEqual(try cents("1.234", rounding: .ceil).raw, 124)
        XCTAssertEqual(try cents("1.235", rounding: .round).raw, 124)
        XCTAssertEqual(try cents("1.234", rounding: .trunc).raw, 123)

        let tiny = try decimalFixedPoint(.unsigned, 8, 0)
        XCTAssertEqual(
            throwingSolanaCode { _ = try tiny("256") },
            SolanaErrorCode.fixedPointsValueOutOfRange.rawValue
        )
        XCTAssertEqual(
            throwingSolanaCode { _ = try usdc("abc") },
            SolanaErrorCode.fixedPointsInvalidString.rawValue
        )
        for invalid in ["", "-", ".", "+1", " 1", "1 ", "1.2.3", "1,5", "0x10", "１２", "١", "1.²"] {
            XCTAssertEqual(
                throwingSolanaCode { _ = try usdc(invalid) },
                SolanaErrorCode.fixedPointsInvalidString.rawValue,
                invalid
            )
        }

        XCTAssertEqual(
            throwingSolanaCode { _ = try FixedPointRaw(decimalString: "١") },
            SolanaErrorCode.fixedPointsInvalidString.rawValue
        )
    }

    func testDecimalRatioArithmeticComparisonsAndConversions() throws {
        let probability = try ratioDecimalFixedPoint(.unsigned, 64, 4)
        XCTAssertEqual(try probability(1, 4).raw, 2_500)
        XCTAssertEqual(
            throwingSolanaCode { _ = try probability(1, 3) },
            SolanaErrorCode.fixedPointsStrictModePrecisionLoss.rawValue
        )
        XCTAssertEqual(try probability(1, 3, rounding: .floor).raw, 3_333)
        XCTAssertEqual(try probability(1, 3, rounding: .ceil).raw, 3_334)
        XCTAssertEqual(
            throwingSolanaCode { _ = try probability(1, 0) },
            SolanaErrorCode.fixedPointsInvalidZeroDenominatorRatio.rawValue
        )

        let usd = try decimalFixedPoint(.unsigned, 64, 2)
        XCTAssertEqual(try addDecimalFixedPoint(try usd("1.50"), try usd("2.25")).raw, 375)
        XCTAssertEqual(try subtractDecimalFixedPoint(try usd("10"), try usd("3.5")).raw, 650)
        XCTAssertEqual(try multiplyDecimalFixedPoint(try usd("1.50"), FixedPointRaw(3)).raw, 450)
        XCTAssertEqual(try multiplyDecimalFixedPoint(try usd("100"), try (try decimalFixedPoint(.unsigned, 32, 4))("0.0025")).raw, 25)
        XCTAssertEqual(try divideDecimalFixedPoint(try usd("10.50"), FixedPointRaw(3), rounding: .round).raw, 350)
        XCTAssertEqual(try divideDecimalFixedPoint(try usd("10"), try (try decimalFixedPoint(.unsigned, 32, 4))("0.05")).raw, 20_000)

        let raw8 = try rawDecimalFixedPoint(.unsigned, 8, 0)
        XCTAssertEqual(
            throwingSolanaCode { _ = try addDecimalFixedPoint(try raw8(200), try raw8(100)) },
            SolanaErrorCode.fixedPointsArithmeticOverflow.rawValue
        )
        XCTAssertEqual(
            throwingSolanaCode { _ = try divideDecimalFixedPoint(try usd("10"), FixedPointRaw(0)) },
            SolanaErrorCode.fixedPointsDivisionByZero.rawValue
        )
        XCTAssertEqual(
            throwingSolanaCode { _ = try divideDecimalFixedPoint(try usd("10"), try usd("0")) },
            SolanaErrorCode.fixedPointsDivisionByZero.rawValue
        )

        let signed = try decimalFixedPoint(.signed, 32, 2)
        XCTAssertEqual(try negateDecimalFixedPoint(try signed("1.5")).raw, -150)
        XCTAssertEqual(try absoluteDecimalFixedPoint(try signed("-1.5")).raw, 150)
        XCTAssertEqual(try cmpDecimalFixedPoint(try signed("-1.25"), try signed("-2.50")), 1)
        XCTAssertTrue(try eqDecimalFixedPoint(try usd("2.50"), try usd("2.50")))
        XCTAssertTrue(try ltDecimalFixedPoint(try usd("1.25"), try usd("2.50")))
        XCTAssertTrue(try gteDecimalFixedPoint(try usd("3.75"), try usd("2.50")))

        let fourDecimals = try rawDecimalFixedPoint(.unsigned, 64, 4)
        XCTAssertEqual(
            throwingSolanaCode { _ = try addDecimalFixedPoint(try usd("1"), try fourDecimals(1)) },
            SolanaErrorCode.fixedPointsShapeMismatch.rawValue
        )
    }

    func testDecimalRoundingModesMatchSignedBigIntDivision() throws {
        let raw = try rawDecimalFixedPoint(.signed, 16, 0)
        let minusTen = try raw(-10)
        XCTAssertEqual(try divideDecimalFixedPoint(minusTen, FixedPointRaw(3), rounding: .trunc).raw, -3)
        XCTAssertEqual(try divideDecimalFixedPoint(minusTen, FixedPointRaw(3), rounding: .floor).raw, -4)
        XCTAssertEqual(try divideDecimalFixedPoint(minusTen, FixedPointRaw(3), rounding: .ceil).raw, -3)
        XCTAssertEqual(try divideDecimalFixedPoint(try raw(10), FixedPointRaw(-3), rounding: .floor).raw, -4)
        XCTAssertEqual(try divideDecimalFixedPoint(try raw(10), FixedPointRaw(-3), rounding: .ceil).raw, -3)
        XCTAssertEqual(try divideDecimalFixedPoint(try raw(10), FixedPointRaw(4), rounding: .round).raw, 3)
        XCTAssertEqual(try divideDecimalFixedPoint(try raw(-10), FixedPointRaw(4), rounding: .round).raw, -3)
        XCTAssertEqual(try divideDecimalFixedPoint(try raw(6), FixedPointRaw(4), rounding: .round).raw, 2)
        XCTAssertEqual(try divideDecimalFixedPoint(try raw(-6), FixedPointRaw(4), rounding: .round).raw, -2)
    }

    func testDecimalFormattingAndRescaleKeepLargeIntegerPrecision() throws {
        let raw = try rawDecimalFixedPoint(.unsigned, 128, 6)
        let large = try raw(try FixedPointRaw(decimalString: "100000000000000000000"))
        XCTAssertEqual(try decimalFixedPointToString(large), "100000000000000")
        XCTAssertEqual(try decimalFixedPointToString(try raw(42_500_000)), "42.5")
        XCTAssertEqual(try decimalFixedPointToString(try raw(42_500_000), options: FixedPointToStringOptions(padTrailingZeros: true)), "42.500000")

        let d3 = try rawDecimalFixedPoint(.unsigned, 64, 3)
        XCTAssertEqual(
            try decimalFixedPointToString(try d3(42_678), options: FixedPointToStringOptions(decimals: 2, rounding: .floor)),
            "42.67"
        )
        XCTAssertEqual(
            throwingSolanaCode { _ = try decimalFixedPointToString(try (try rawDecimalFixedPoint(.unsigned, 64, 1))(425), options: FixedPointToStringOptions(decimals: 0)) },
            SolanaErrorCode.fixedPointsStrictModePrecisionLoss.rawValue
        )

        let evmUsdc = try decimalFixedPoint(.unsigned, 128, 18)
        let bridged = try rescaleDecimalFixedPoint(try evmUsdc("100.123456789012345678"), 64, 6, rounding: .floor)
        XCTAssertEqual(bridged.raw, 100_123_456)
        XCTAssertEqual(bridged.totalBits, 64)
        XCTAssertEqual(bridged.decimals, 6)

        let currency = NumberFormatter()
        currency.locale = Locale(identifier: "en_US")
        currency.numberStyle = .currency
        XCTAssertEqual(formatDecimalFixedPoint(currency, try (try decimalFixedPoint(.unsigned, 64, 2))("1234.5")), "$1,234.50")

        let grouped = NumberFormatter()
        grouped.locale = Locale(identifier: "en_US")
        grouped.numberStyle = .decimal
        grouped.usesGroupingSeparator = false
        grouped.minimumFractionDigits = 2
        grouped.maximumFractionDigits = 2
        XCTAssertEqual(formatDecimalFixedPoint(grouped, try (try decimalFixedPoint(.signed, 64, 4))("-42.5")), "-42.50")
    }

    func testBinaryFactoriesArithmeticConversionsAndFormatting() throws {
        let q1_15 = try binaryFixedPoint(.signed, 16, 15)
        XCTAssertEqual(try q1_15("0.5").raw, 16_384)
        XCTAssertEqual(try q1_15("0.25").raw, 8_192)
        XCTAssertEqual(try q1_15("-0.5").raw, -16_384)
        XCTAssertEqual(
            throwingSolanaCode { _ = try q1_15("0.1") },
            SolanaErrorCode.fixedPointsStrictModePrecisionLoss.rawValue
        )
        XCTAssertEqual(try q1_15("0.1", rounding: .floor).raw, 3_276)
        XCTAssertEqual(try q1_15("0.1", rounding: .ceil).raw, 3_277)
        XCTAssertEqual(try q1_15("0.1", rounding: .round).raw, 3_277)

        XCTAssertEqual(try addBinaryFixedPoint(try q1_15("0.25"), try q1_15("0.5")).raw, 24_576)
        XCTAssertEqual(try subtractBinaryFixedPoint(try q1_15("0.75"), try q1_15("0.5")).raw, 8_192)
        XCTAssertEqual(try multiplyBinaryFixedPoint(try q1_15("0.25"), FixedPointRaw(2)).raw, 16_384)
        XCTAssertEqual(try multiplyBinaryFixedPoint(try q1_15("0.5"), try q1_15("0.5")).raw, 8_192)
        XCTAssertEqual(try divideBinaryFixedPoint(try q1_15("0.5"), FixedPointRaw(2)).raw, 8_192)

        let base10 = binaryFixedPointToBase10(try (try rawBinaryFixedPoint(.unsigned, 16, 15))(1))
        XCTAssertEqual(base10.decimals, 15)
        XCTAssertEqual(base10.raw, 30_517_578_125)
        XCTAssertEqual(try binaryFixedPointToString(try (try rawBinaryFixedPoint(.unsigned, 16, 15))(1)), "0.000030517578125")
        XCTAssertEqual(
            try binaryFixedPointToString(try q1_15("0.5"), options: FixedPointToStringOptions(padTrailingZeros: true)),
            "0.500000000000000"
        )
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        XCTAssertEqual(formatBinaryFixedPoint(formatter, try q1_15("0.1", rounding: .round)), "0.1")

        let wideRaw = try FixedPointRaw(decimalString: "1152921504607895551")
        let wideValue = try (try rawBinaryFixedPoint(.unsigned, 128, 20))(wideRaw)
        XCTAssertEqual(binaryFixedPointToNumber(wideValue), pow(2, 40) + (pow(2, 20) - 1) / pow(2, 20))
    }

    func testBinaryRescaleAndErrorCodes() throws {
        let source = try (try rawBinaryFixedPoint(.unsigned, 8, 2))(1)
        XCTAssertEqual(try rescaleBinaryFixedPoint(source, 8, 4).raw, 4)
        XCTAssertEqual(
            throwingSolanaCode { _ = try rescaleBinaryFixedPoint(source, 8, 1) },
            SolanaErrorCode.fixedPointsStrictModePrecisionLoss.rawValue
        )
        XCTAssertEqual(try rescaleBinaryFixedPoint(source, 8, 1, rounding: .floor).raw, 0)
        XCTAssertEqual(try rescaleBinaryFixedPoint(source, 8, 1, rounding: .ceil).raw, 1)
        XCTAssertEqual(
            throwingSolanaCode { _ = try rescaleBinaryFixedPoint(source, 8, 16) },
            SolanaErrorCode.fixedPointsFractionalBitsExceedTotalBits.rawValue
        )
        XCTAssertEqual(
            throwingSolanaCode { _ = try divideBinaryFixedPoint(source, FixedPointRaw(0)) },
            SolanaErrorCode.fixedPointsDivisionByZero.rawValue
        )
        XCTAssertEqual(
            throwingSolanaCode { _ = try divideBinaryFixedPoint(source, try (try rawBinaryFixedPoint(.unsigned, 8, 2))(0)) },
            SolanaErrorCode.fixedPointsDivisionByZero.rawValue
        )

        let int8 = try rawBinaryFixedPoint(.signed, 8, 0)
        XCTAssertEqual(
            throwingSolanaCode { _ = try multiplyBinaryFixedPoint(try int8(100), FixedPointRaw(2)) },
            SolanaErrorCode.fixedPointsArithmeticOverflow.rawValue
        )
        XCTAssertEqual(
            throwingSolanaCode { _ = try negateBinaryFixedPoint(try (try rawBinaryFixedPoint(.unsigned, 16, 15))(1)) },
            SolanaErrorCode.fixedPointsShapeMismatch.rawValue
        )
    }

    func testFixedPointCodecsUseTwosComplementAndEndianConfig() throws {
        let decimal = try decimalFixedPoint(.unsigned, 64, 6)
        let decimalCodec = try getDecimalFixedPointCodec(.unsigned, 64, 6)
        let encoded = try decimalCodec.encode(try decimal("42.5"))
        XCTAssertEqual(encoded.hex, "a07f880200000000")
        let decoded = try decimalCodec.decode(encoded)
        XCTAssertEqual(decoded.raw, 42_500_000)
        XCTAssertEqual(decoded.decimals, 6)

        let signedBinary = try rawBinaryFixedPoint(.signed, 16, 15)
        XCTAssertEqual(try getBinaryFixedPointCodec(.signed, 16, 15).encode(try signedBinary(-16_384)).hex, "00c0")
        XCTAssertEqual(
            try getBinaryFixedPointCodec(.signed, 16, 15, config: FixedPointCodecConfig(endian: .big)).encode(try signedBinary(-16_384)).hex,
            "c000"
        )
        XCTAssertEqual(
            try getBinaryFixedPointDecoder(.signed, 16, 15).decode(Data(hex: "00c0")).raw,
            -16_384
        )

        XCTAssertEqual(
            throwingSolanaCode { _ = try getBinaryFixedPointCodec(.signed, 7, 0) },
            SolanaErrorCode.fixedPointsTotalBitsNotByteAligned.rawValue
        )
    }
}

private func throwingSolanaCode(_ body: () throws -> Void) -> Int? {
    do {
        try body()
        return nil
    } catch let error as any SolanaErrorCoded {
        return error.code
    } catch {
        return nil
    }
}

private extension Data {
    init(hex: String) {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index ..< next], radix: 16) ?? 0)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
