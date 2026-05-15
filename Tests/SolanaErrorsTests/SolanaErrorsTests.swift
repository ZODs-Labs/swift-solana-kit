@testable import SolanaErrors
import XCTest

final class SolanaErrorsTests: XCTestCase {
    func testFullErrorTableIsPresent() {
        XCTAssertEqual(solanaErrorMessages.count, 308)
        XCTAssertEqual(SolanaErrorCode.transactionErrorWouldExceedMaxVoteCostLimit.rawValue, 7_050_028)
        XCTAssertEqual(SolanaErrorCode.walletSignerNotAvailable.rawValue, 8_900_002)
    }

    func testNumericCodesAreStable() {
        XCTAssertEqual(SolanaErrorCode.jsonRPCParseError.rawValue, -32700)
        XCTAssertEqual(SolanaErrorCode.keysInvalidPrivateKeyByteLength.rawValue, 3_704_001)
        XCTAssertEqual(SolanaErrorCode.codecsOffsetOutOfRange.rawValue, 8_078_014)
    }

    func testDomainErrorsExposeCodesAndContext() {
        let error = KeysError.invalidPrivateKeyByteLength(actualLength: 31)
        XCTAssertEqual(error.code, 3_704_001)
        XCTAssertEqual(error.contextDescription, "actualLength=31")
        XCTAssertTrue(error.localizedDescription.contains("31"))
    }

    func testContextLiteralUsesLastDuplicateKey() {
        let context: SolanaErrorContext = ["value": .string("first"), "value": .string("second")]

        XCTAssertEqual(context.values.count, 1)
        XCTAssertEqual(context["value"], .string("second"))
    }

    func testContextBigintRendersAsDecimalString() {
        let context: SolanaErrorContext = ["slot": .bigint("9007199254740993")]

        XCTAssertEqual(context.renderedDescription, "slot=9007199254740993")
        XCTAssertEqual(render(format: "slot $slot", context: context), "slot 9007199254740993")
    }

    func testSignedJsonRpcCodesRoundTripThroughGenericSolanaError() {
        let error = SolanaError(.jsonRPCParseError)
        XCTAssertEqual(error.code, -32700)
        XCTAssertEqual(error.errorCode, -32700)
    }

    func testMessagesRenderExactlyWithContext() {
        XCTAssertEqual(
            solanaErrorMessage(
                code: .keysInvalidKeyPairByteLength,
                context: ["byteLength": .int(63)]
            ),
            "Key pair bytes must be of length 64, got 63."
        )
        XCTAssertEqual(
            solanaErrorMessage(
                code: .instructionErrorCustom,
                context: ["code": .int(42), "index": .int(2)]
            ),
            "Custom program error: #42 (instruction #3)"
        )
        XCTAssertEqual(
            solanaErrorMessage(code: .codecsInvalidConstant),
            "Expected byte array constant [$hexConstant] to be present in data [$hexData] at offset [$offset]."
        )
    }

    func testCodecSentinelMessagesIncludeHexContext() {
        let encodedError = CodecsError.encodedBytesMustNotIncludeSentinel(
            encodedBytes: Data([0x68, 0x65, 0x6C, 0x6C, 0x6F]),
            sentinel: Data([0x6C, 0x6C])
        )
        XCTAssertEqual(
            encodedError.errorDescription,
            "Sentinel [6c6c] must not be present in encoded bytes [68656c6c6f]."
        )

        let decodedError = CodecsError.sentinelMissingInDecodedBytes(
            decodedBytes: Data([0x01, 0x02]),
            sentinel: Data([0xFF])
        )
        XCTAssertEqual(
            decodedError.errorDescription,
            "Expected sentinel [ff] to be present in decoded bytes [0102]."
        )
    }

    func testCodecErrorSurfaceCoversDeclaredCodecCodes() {
        let errors: [(CodecsError, Int)] = [
            (.invalidNumberOfItems(codecDescription: "array", expected: 2, actual: 3), SolanaErrorCode.codecsInvalidNumberOfItems.rawValue),
            (.enumDiscriminatorOutOfRange(discriminator: 9, formattedValidDiscriminators: "0, 1", validDiscriminators: [0, 1]), SolanaErrorCode.codecsEnumDiscriminatorOutOfRange.rawValue),
            (.invalidDiscriminatedUnionVariant(value: "z", variants: ["a", "b"]), SolanaErrorCode.codecsInvalidDiscriminatedUnionVariant.rawValue),
            (.invalidEnumVariant(variant: "z", stringValues: ["a"], numericalValues: [1], formattedNumericalValues: "1"), SolanaErrorCode.codecsInvalidEnumVariant.rawValue),
            (.numberOutOfRange(codecDescription: "u8", min: "0", max: "255", value: "256"), SolanaErrorCode.codecsNumberOutOfRange.rawValue),
            (.invalidStringForBase(value: "0", base: 58, alphabet: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"), SolanaErrorCode.codecsInvalidStringForBase.rawValue),
            (.invalidLiteralUnionVariant(value: "z", variants: ["a", "b"]), SolanaErrorCode.codecsInvalidLiteralUnionVariant.rawValue),
            (.literalUnionDiscriminatorOutOfRange(discriminator: 9, minRange: 0, maxRange: 1), SolanaErrorCode.codecsLiteralUnionDiscriminatorOutOfRange.rawValue),
            (.unionVariantOutOfRange(variant: 9, minRange: 0, maxRange: 1), SolanaErrorCode.codecsUnionVariantOutOfRange.rawValue),
            (.invalidConstant(constant: Data([0xAB]), data: Data([0xCD]), offset: 0), SolanaErrorCode.codecsInvalidConstant.rawValue),
            (.expectedZeroValueToMatchItemFixedSize(codecDescription: "struct", zeroValue: Data([0]), expectedSize: 2), SolanaErrorCode.codecsExpectedZeroValueToMatchItemFixedSize.rawValue),
            (.cannotUseLexicalValuesAsEnumDiscriminators(stringValues: ["a", "b"]), SolanaErrorCode.codecsCannotUseLexicalValuesAsEnumDiscriminators.rawValue),
        ]

        for (error, code) in errors {
            XCTAssertEqual(error.code, code)
            XCTAssertEqual(error.errorCode, code)
            XCTAssertNotNil(error.errorDescription)
        }

        XCTAssertEqual(
            CodecsError.invalidStringForBase(
                value: "INVALID_INPUT",
                base: 58,
                alphabet: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
            ).errorDescription,
            "Invalid value INVALID_INPUT for base 58 with alphabet 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz."
        )
    }

    func testMessageRendererUsesUTF16CodeUnitStateMachine() {
        XCTAssertEqual(
            render(format: "emoji \u{1f680} $value", context: ["value": .string("ok")]),
            "emoji \u{1f680} ok"
        )
    }
}
