import RpcSpecTypes
import SolanaErrors
import XCTest

final class RpcSpecTypesDetailedBehaviorTests: XCTestCase {
    func testParseJsonWithBigIntsCoversSafeIntegerBoundariesAndSignedExponents() throws {
        XCTAssertEqual(try parseJsonWithBigInts("9007199254740991"), .bigint("9007199254740991"))
        XCTAssertEqual(try parseJsonWithBigInts("9007199254740992"), .bigint("9007199254740992"))
        XCTAssertEqual(try parseJsonWithBigInts("-9007199254740992"), .bigint("-9007199254740992"))
        XCTAssertEqual(try parseJsonWithBigInts("123E+32"), .bigint("12300000000000000000000000000000000"))
        XCTAssertEqual(try parseJsonWithBigInts("-123e+32"), .bigint("-12300000000000000000000000000000000"))
        XCTAssertEqual(try parseJsonWithBigInts("-1E-5"), .number(-0.00001))
        XCTAssertEqual(try parseJsonWithBigInts("-1189e-32"), .number(-1189e-32))
    }

    func testParseJsonWithBigIntsPreservesEscapedStringsAndBase64Tuples() throws {
        XCTAssertEqual(try parseJsonWithBigInts(#""He said: \"I will eat 3 bananas\"""#), .string(#"He said: "I will eat 3 bananas""#))
        XCTAssertEqual(try parseJsonWithBigInts(#""\\\"base64""#), .string(#"\"base64"#))
        XCTAssertEqual(
            try parseJsonWithBigInts(#"{"data":["","base64"],"message_200":"Hello to the \"2nd World\""}"#),
            .object([
                ("data", .array([.string(""), .string("base64")])),
                ("message_200", .string(#"Hello to the "2nd World""#)),
            ])
        )
    }

    func testParseJsonWithBigIntsHandlesAccountPayloadShapes() throws {
        let parsed = try parseJsonWithBigInts(
            #"{"context":{"slot":293820184},"value":[{"pubkey":"11111111111111111111111111111111","account":{"lamports":142302234983644260,"data":["","base64"],"owner":"11111111111111111111111111111111","executable":false,"rentEpoch":361}}]}"#
        )

        XCTAssertEqual(parsed.value(for: "context")?.value(for: "slot"), .bigint("293820184"))
        guard case let .array(accounts)? = parsed.value(for: "value") else {
            return XCTFail("Expected account array")
        }
        let account = accounts.first?.value(for: "account")
        XCTAssertEqual(account?.value(for: "lamports"), .bigint("142302234983644260"))
        XCTAssertEqual(account?.value(for: "data"), .array([.string(""), .string("base64")]))
        XCTAssertEqual(account?.value(for: "executable"), .bool(false))
        XCTAssertEqual(account?.value(for: "rentEpoch"), .bigint("361"))
    }

    func testMalformedJsonInputsThrowSolanaErrors() {
        let inputs = [
            "",
            "{",
            "[1,]",
            #"{"a":}"#,
            #""\uD800""#,
            #""\x""#,
            "01",
            "1e",
            "1e+",
        ]

        for input in inputs {
            XCTAssertThrowsError(try parseJsonWithBigInts(input)) { error in
                XCTAssertEqual((error as? SolanaError)?.solanaCode, .malformedJSONRPCError)
            }
        }
    }

    func testStringifyJsonWithBigIntsCoversNumberAndStringEdgeCases() throws {
        XCTAssertEqual(try stringifyJsonWithBigInts(.bigint("00042")), "42")
        XCTAssertEqual(try stringifyJsonWithBigInts(.bigint("-00042")), "-42")
        XCTAssertEqual(try stringifyJsonWithBigInts(.number(-0.00001)), "-0.00001")
        XCTAssertEqual(try stringifyJsonWithBigInts(.number(1e-32)), "1e-32")
        XCTAssertEqual(try stringifyJsonWithBigInts(.number(-1189e-32)), "-1.189e-29")
        XCTAssertEqual(try stringifyJsonWithBigInts(.number(.infinity)), "null")
        XCTAssertEqual(try stringifyJsonWithBigInts(.number(.nan)), "null")
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.string("line\nquote\"slash\\tab\t")),
            #""line\nquote\"slash\\tab\t""#
        )
    }

    func testPlainJsonBigIntSerializationReportsTheJsonStringifyFailure() {
        XCTAssertThrowsError(try stringifyJson(.bigint("42"))) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.solanaCode, .malformedJSONRPCError)
            XCTAssertEqual(solanaError?.context["message"], .string("BigInt value cannot be serialized with JSON.stringify"))
        }
    }

    func testRpcMessageJsonValuePreservesMemberOrderAndGeneratedId() {
        let message = RpcMessage(id: "abc", method: "someMethod", params: .array([.number(1)]))

        XCTAssertEqual(
            message.jsonValue.objectMembers,
            [
                RpcJsonObjectMember("id", .string("abc")),
                RpcJsonObjectMember("jsonrpc", .string("2.0")),
                RpcJsonObjectMember("method", .string("someMethod")),
                RpcJsonObjectMember("params", .array([.number(1)])),
            ]
        )
    }
}
