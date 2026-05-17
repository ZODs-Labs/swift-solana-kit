@testable import SolanaErrors
import XCTest

final class SolanaErrorsDetailedBehaviorTests: XCTestCase {
    func testContextDescriptionsSortKeysAndRenderNestedValues() {
        let context = SolanaErrorContext([
            "z": .bytes(Data([1, 2, 3])),
            "a": .object(["b": .string("two"), "a": .int(1)]),
            "m": .array([.bool(true), .null, .string("x")]),
        ])

        XCTAssertEqual(context.renderedDescription, "a={a:1,b:two}, m=[true,null,x], z=1,2,3")
        XCTAssertEqual(render(format: "values $a $m $z", context: context), "values {a:1,b:two} [true,null,x] 1,2,3")
    }

    func testUnknownMessageFallbackInterpolatesTheCodePlaceholder() {
        XCTAssertEqual(solanaErrorMessage(code: SolanaErrorCode(rawValue: 123_456)), "Solana error #$code")
        XCTAssertEqual(
            render(format: "Solana error #$code", context: ["code": .int(123_456)]),
            "Solana error #123456"
        )
    }

    func testRpcIntegerOverflowMessagesIncludeOptionalPathLabels() {
        XCTAssertEqual(
            SolanaError(
                .rpcIntegerOverflow,
                context: [
                    "argumentLabel": .string("3rd"),
                    "keyPath": .array([.int(2)]),
                    "methodName": .string("someMethod"),
                    "optionalPathLabel": .string(""),
                    "value": .bigint("1"),
                ]
            ).errorDescription,
            "The 3rd argument to the `someMethod` RPC method was `1`. This number is unsafe for use with the Solana JSON-RPC because it exceeds `Number.MAX_SAFE_INTEGER`."
        )

        XCTAssertEqual(
            SolanaError(
                .rpcIntegerOverflow,
                context: [
                    "argumentLabel": .string("1st"),
                    "keyPath": .array([.int(0), .string("foo"), .string("bar")]),
                    "methodName": .string("someMethod"),
                    "optionalPathLabel": .string(" at path `foo.bar`"),
                    "path": .string("foo.bar"),
                    "value": .bigint("1"),
                ]
            ).errorDescription,
            "The 1st argument to the `someMethod` RPC method at path `foo.bar` was `1`. This number is unsafe for use with the Solana JSON-RPC because it exceeds `Number.MAX_SAFE_INTEGER`."
        )
    }

    func testJsonRpcAndTransportErrorsExposeServerContextAndMessages() {
        let parseError = RpcError.jsonRPC(code: SolanaErrorCode.jsonRPCParseError.rawValue, message: "bad json")
        XCTAssertEqual(parseError.code, -32700)
        XCTAssertEqual(parseError.context["__serverMessage"], .string("bad json"))
        XCTAssertEqual(
            parseError.errorDescription,
            "JSON-RPC error: An error occurred on the server while parsing the JSON text (bad json)"
        )

        let httpError = RpcError.transportHTTPError(
            statusCode: 429,
            message: "too many requests",
            headers: ["retry-after": "1"]
        )
        XCTAssertEqual(httpError.code, SolanaErrorCode.rpcTransportHTTPError.rawValue)
        XCTAssertEqual(httpError.context["statusCode"], .int(429))
        XCTAssertEqual(httpError.context["message"], .string("too many requests"))
        XCTAssertEqual(httpError.errorDescription, "HTTP error (429): too many requests")

        let forbidden = RpcError.transportHTTPHeaderForbidden(headers: ["cookie", "host"])
        XCTAssertEqual(forbidden.context["headers"], .stringArray(["cookie", "host"]))
        XCTAssertEqual(
            forbidden.errorDescription,
            "HTTP header(s) forbidden: cookie,host. Learn more at https://developer.mozilla.org/en-US/docs/Glossary/Forbidden_header_name."
        )
    }

    func testInstructionMessageNumberingUsesZeroBasedContext() {
        XCTAssertEqual(
            solanaErrorMessage(code: .instructionErrorUnknown, context: ["index": .int(0)]),
            "The instruction failed with the error: $errorName (instruction #1)"
        )
        XCTAssertEqual(
            solanaErrorMessage(
                code: SolanaErrorCode(rawValue: SolanaErrorCode.instructionErrorUnknown.rawValue + 999),
                context: ["index": .int(2)]
            ),
            "Solana error #$code (instruction #3)"
        )
        XCTAssertEqual(
            solanaErrorMessage(code: .lamportsOutOfRange, context: ["index": .int(0)]),
            "Lamports value must be in the range [0, 2e64-1]"
        )
    }

    func testCodecErrorContextsIncludeRawBytesAndHexStrings() {
        let invalidConstant = CodecsError.invalidConstant(
            constant: Data([0xab]),
            data: Data([0xcd]),
            offset: 3
        )
        XCTAssertEqual(invalidConstant.context["constant"], .bytes(Data([0xab])))
        XCTAssertEqual(invalidConstant.context["data"], .bytes(Data([0xcd])))
        XCTAssertEqual(invalidConstant.context["hexConstant"], .string("ab"))
        XCTAssertEqual(invalidConstant.context["hexData"], .string("cd"))
        XCTAssertEqual(invalidConstant.context["offset"], .int(3))
        XCTAssertEqual(
            invalidConstant.errorDescription,
            "Expected byte array constant [ab] to be present in data [cd] at offset [3]."
        )

        let zeroValue = CodecsError.expectedZeroValueToMatchItemFixedSize(
            codecDescription: "struct",
            zeroValue: Data([0]),
            expectedSize: 2
        )
        XCTAssertEqual(zeroValue.context["hexZeroValue"], .string("00"))
        XCTAssertEqual(
            zeroValue.errorDescription,
            "Codec [struct] expected zero-value [00] to have the same size as the provided fixed-size item [2 bytes]."
        )
    }

    func testTransactionAndDomainErrorsExposeStableContexts() {
        let signatures = TransactionError.signaturesMissing(addresses: ["a", "b"])
        XCTAssertEqual(signatures.code, SolanaErrorCode.transactionSignaturesMissing.rawValue)
        XCTAssertEqual(signatures.context["addresses"], .stringArray(["a", "b"]))
        XCTAssertEqual(signatures.errorDescription, "Transaction is missing signatures for addresses: a,b.")

        let address = AddressError.maxPDASeedLengthExceeded(actual: 33, index: 2, maxSeedLength: 32)
        XCTAssertEqual(address.context["actual"], .int(33))
        XCTAssertEqual(address.context["index"], .int(2))
        XCTAssertEqual(address.context["maxSeedLength"], .int(32))

        let key = KeysError.invalidKeyPairByteLength(byteLength: 63)
        XCTAssertEqual(key.contextDescription, "byteLength=63")
        XCTAssertEqual(key.errorDescription, "Key pair bytes must be of length 64, got 63.")
    }

    func testCustomNSErrorSurfacesDescriptionsAndContextUserInfo() {
        let error = SolanaError(.keysInvalidPrivateKeyByteLength, context: ["actualLength": .int(31)])
        let userInfo = error.errorUserInfo

        XCTAssertEqual(SolanaError.errorDomain, "org.solana.swift-solana-kit")
        XCTAssertEqual(error.errorCode, SolanaErrorCode.keysInvalidPrivateKeyByteLength.rawValue)
        XCTAssertEqual(userInfo[NSLocalizedDescriptionKey] as? String, "Expected private key bytes with length 32. Actual length: 31.")
        XCTAssertEqual(userInfo["context"] as? String, "actualLength=31")
    }
}
