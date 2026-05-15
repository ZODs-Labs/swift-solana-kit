import RpcSpecTypes
import SolanaErrors
import XCTest

final class RpcSpecTypesTests: XCTestCase {
    func testParseJsonWithBigIntsPreservesUnsafeIntegers() throws {
        let parsed = try parseJsonWithBigInts(#"{ "alice": 42, "bob": [3.14, 1e5, 1e-5, { "baz": 123456789012345678901234567890 }] }"#)

        XCTAssertEqual(parsed.value(for: "alice"), .bigint("42"))
        guard case let .array(bob)? = parsed.value(for: "bob") else {
            return XCTFail("Expected bob array")
        }
        XCTAssertEqual(bob[0], .number(3.14))
        XCTAssertEqual(bob[1], .bigint("100000"))
        XCTAssertEqual(bob[2], .number(0.00001))
        XCTAssertEqual(bob[3].value(for: "baz"), .bigint("123456789012345678901234567890"))
    }

    func testParseJsonWithBigIntsUsesAsciiJsonNumberGrammar() throws {
        XCTAssertEqual(try parseJsonWithBigInts("123e+32"), .bigint("12300000000000000000000000000000000"))
        XCTAssertEqual(try parseJsonWithBigInts("-123E+32"), .bigint("-12300000000000000000000000000000000"))
        XCTAssertEqual(try parseJsonWithBigInts("1e-5"), .number(0.00001))

        XCTAssertThrowsError(try parseJsonWithBigInts("１２３")) { error in
            XCTAssertEqual((error as? SolanaError)?.code, SolanaErrorCode.malformedJSONRPCError.rawValue)
        }
    }

    func testStringifyJsonWithBigIntsEmitsNumericBigInts() throws {
        let value = RpcJsonValue.object([
            ("alice", .bigint("42")),
            ("bob", .array([.number(3.14), .bigint("300000000"), .object([("baz", .bigint("12345678901234567890"))])])),
        ])

        XCTAssertEqual(
            try stringifyJsonWithBigInts(value),
            #"{"alice":42,"bob":[3.14,300000000,{"baz":12345678901234567890}]}"#
        )
    }

    func testParseJsonWithBigIntsPreservesObjectMemberOrder() throws {
        let parsed = try parseJsonWithBigInts(#"{ "alice": 42, "bob": [3.14, { "baz": 12345678901234567890 }] }"#)

        XCTAssertEqual(
            try stringifyJsonWithBigInts(parsed),
            #"{"alice":42,"bob":[3.14,{"baz":12345678901234567890}]}"#
        )
    }

    func testObjectValueLookupUsesLastDuplicateMember() {
        let value = RpcJsonValue.object([
            ("slot", .number(1)),
            ("slot", .number(2)),
        ])

        XCTAssertEqual(value.value(for: "slot"), .number(2))
        XCTAssertEqual(value.objectMembers, [RpcJsonObjectMember("slot", .number(2))])
    }

    func testParseAndStringifyCollapseDuplicateObjectMembersLikeJSONParse() throws {
        let parsed = try parseJsonWithBigInts(#"{ "slot": 1, "other": true, "slot": 2 }"#)

        XCTAssertEqual(
            parsed.objectMembers,
            [
                RpcJsonObjectMember("slot", .bigint("2")),
                RpcJsonObjectMember("other", .bool(true)),
            ]
        )
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.object([
                RpcJsonObjectMember("slot", .bigint("1")),
                RpcJsonObjectMember("other", .bool(true)),
                RpcJsonObjectMember("slot", .bigint("2")),
            ])),
            #"{"slot":2,"other":true}"#
        )
    }

    func testStringifyJsonNumberFormattingMatchesJavaScriptThresholds() throws {
        XCTAssertEqual(try stringifyJsonWithBigInts(.array([.number(1e20), .number(1e21)])), "[100000000000000000000,1e+21]")
        XCTAssertEqual(try stringifyJsonWithBigInts(.array([.number(1e-6), .number(1e-7)])), "[0.000001,1e-7]")
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.array([.number(1.2345678901234567), .number(0.0000012345678901234567)])),
            "[1.2345678901234567,0.0000012345678901234567]"
        )
    }

    func testStringifyJsonWithBigIntsMatchesJsonStringifyIndentation() throws {
        let value = RpcJsonValue.object([
            ("alice", .bigint("42")),
            ("bob", .array([.bigint("300000000")])),
        ])

        XCTAssertEqual(
            try stringifyJsonWithBigInts(value, space: 2),
            """
            {
              "alice": 42,
              "bob": [
                300000000
              ]
            }
            """
        )
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.array([.bigint("1")]), space: 99),
            "[\n          1\n]"
        )
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.object([("value", .bigint("1"))]), space: "-->"),
            "{\n-->\"value\": 1\n}"
        )
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.array([.bigint("1")]), space: "0123456789XYZ"),
            "[\n01234567891\n]"
        )
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.array([.bigint("1")]), space: "😀😀😀😀😀😀"),
            "[\n😀😀😀😀😀1\n]"
        )
        XCTAssertEqual(
            try stringifyJsonWithBigInts(.array([.bigint("1")]), space: "abcdefghi😀"),
            "[\nabcdefghi�1\n]"
        )
    }

    func testPlainJsonDoesNotApplyBigintParsingOrSerialization() throws {
        let parsed = try parseJson(#"{ "slot": 12345678901234567890 }"#)
        XCTAssertEqual(parsed.value(for: "slot"), .number(Double("12345678901234567890") ?? 0))

        XCTAssertThrowsError(try stringifyJson(.object([("slot", .bigint("42"))])))
        XCTAssertEqual(try stringifyJson(.object([("slot", .number(42))])), #"{"slot":42}"#)
    }

    func testCreateRpcMessageAutoIncrementsIdsAndUsesJsonRpcTwo() {
        let request = RpcRequest(methodName: "someMethod", params: .array([.number(1), .number(2)]))
        let first = createRpcMessage(request)
        let second = createRpcMessage(request)

        XCTAssertEqual(Int(second.id).map { $0 - (Int(first.id) ?? 0) }, 1)
        XCTAssertEqual(first.jsonrpc, "2.0")
        XCTAssertEqual(first.method, "someMethod")
        XCTAssertEqual(first.params, .array([.number(1), .number(2)]))
    }
}
