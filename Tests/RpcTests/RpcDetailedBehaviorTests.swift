import Addresses
import Promises
@testable import Rpc
import RpcSpec
import RpcSpecTypes
import RpcTypes
import SolanaErrors
import XCTest

final class RpcDetailedBehaviorTests: XCTestCase {
    func testIntegerOverflowErrorLabelsAllOrdinalBoundaries() {
        let cases: [(Int, String)] = [
            (0, "1st"),
            (1, "2nd"),
            (2, "3rd"),
            (3, "4th"),
            (10, "11th"),
            (11, "12th"),
            (12, "13th"),
            (20, "21st"),
            (21, "22nd"),
            (22, "23rd"),
            (99, "100th"),
        ]

        for (index, expectedLabel) in cases {
            let error = createSolanaJsonRpcIntegerOverflowError(
                methodName: "someMethod",
                keyPath: [.index(index)],
                value: "1"
            )
            XCTAssertEqual(error.context["argumentLabel"], .string(expectedLabel))
            XCTAssertEqual(error.context["optionalPathLabel"], .string(""))
            XCTAssertNil(error.context["path"])
        }
    }

    func testIntegerOverflowErrorRendersKeyWildcardAndNestedPaths() {
        let keyError = createSolanaJsonRpcIntegerOverflowError(
            methodName: "someMethod",
            keyPath: [.key("config"), .key("foo"), .index(2), .wildcard],
            value: "9007199254740992"
        )
        XCTAssertEqual(keyError.context["argumentLabel"], .string("`config`"))
        XCTAssertEqual(keyError.context["keyPath"], .string("config.foo.2.*"))
        XCTAssertEqual(keyError.context["optionalPathLabel"], .string(" at path `foo.[2].*`"))
        XCTAssertEqual(keyError.context["path"], .string("foo.[2].*"))
        XCTAssertEqual(keyError.context["value"], .string("9007199254740992"))
    }

    func testDeduplicationKeyReturnsNilForNonJsonRpcPayloads() throws {
        let values: [RpcJsonValue] = [
            .null,
            .bool(true),
            .string("o hai"),
            .number(123),
            .bigint("123"),
            .array([]),
            .object([RpcJsonObjectMember]()),
            .object([("jsonrpc", .string("2.0")), ("method", .string("getFoo"))]),
            .object([("jsonrpc", .string("2.0")), ("params", .array([]))]),
        ]

        for value in values {
            XCTAssertNil(try getSolanaRpcPayloadDeduplicationKey(value))
        }
    }

    func testDeduplicationKeyIgnoresMessageIdAndSortsNestedObjectKeys() throws {
        let first = RpcJsonValue.object([
            ("id", .number(1)),
            ("jsonrpc", .string("2.0")),
            ("method", .string("getFoo")),
            ("params", .object([
                ("a", .number(1)),
                ("b", .object([
                    ("c", .array([.number(2), .number(3)])),
                    ("d", .number(4)),
                ])),
            ])),
        ])
        let second = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("method", .string("getFoo")),
            ("params", .object([
                ("b", .object([
                    ("d", .number(4)),
                    ("c", .array([.number(2), .number(3)])),
                ])),
                ("a", .number(1)),
            ])),
            ("id", .number(2)),
        ])

        XCTAssertEqual(try getSolanaRpcPayloadDeduplicationKey(first), try getSolanaRpcPayloadDeduplicationKey(second))
        XCTAssertEqual(
            try getSolanaRpcPayloadDeduplicationKey(first),
            #"["getFoo",{"a":1,"b":{"c":[2,3],"d":4}}]"#
        )
    }

    func testCreateSolanaRpcFromTransportBuildsRequestsWithDefaultConfig() async throws {
        let recorder = RpcDetailedTransportRecorder(response: .object([
            ("result", .object([("value", .number(5))])),
        ]))
        let rpc = createSolanaRpcFromTransport { config in
            await recorder.record(config)
        }
        let address = try Address("11111111111111111111111111111111")

        let result = try await rpc.getBalance(address).send()

        XCTAssertEqual(result.value(for: "value"), .bigint("5"))
        let payload = try await recorder.onlyPayload()
        XCTAssertEqual(payload.value(for: "jsonrpc"), .string("2.0"))
        XCTAssertEqual(payload.value(for: "method"), .string("getBalance"))
        guard case let .array(params)? = payload.value(for: "params") else {
            return XCTFail("Expected params array")
        }
        XCTAssertEqual(params.first, .string(address.rawValue))
        XCTAssertEqual(params.dropFirst().first?.value(for: "commitment"), .string("confirmed"))
    }

    func testRequestCoalescingUsesDistinctKeysInTheSameSchedulingWindow() async throws {
        let recorder = RpcDetailedTransportRecorder()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            await recorder.record(config)
        }) { payload in
            payload.value(for: "method").map(String.init(describing:))
        }

        async let first = transport(.init(payload: .object([("method", .string("a"))])))
        async let second = transport(.init(payload: .object([("method", .string("b"))])))
        let responses = try await [first, second]

        XCTAssertEqual(Set(responses), [.string("response-1"), .string("response-2")])
        let payloads = await recorder.allPayloads()
        XCTAssertEqual(payloads.count, 2)
    }
}

private actor RpcDetailedTransportRecorder {
    private var payloads: [RpcJsonValue] = []
    private var calls = 0
    private let fixedResponse: RpcJsonValue?

    init(response: RpcJsonValue? = nil) {
        fixedResponse = response
    }

    func record(_ config: RpcTransportConfig) -> RpcJsonValue {
        calls += 1
        payloads.append(config.payload)
        return fixedResponse ?? .string("response-\(calls)")
    }

    func onlyPayload() throws -> RpcJsonValue {
        try XCTUnwrap(payloads.first)
    }

    func allPayloads() -> [RpcJsonValue] {
        payloads
    }
}
