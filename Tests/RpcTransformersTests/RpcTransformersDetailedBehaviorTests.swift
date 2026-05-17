import RpcSpecTypes
import RpcTransformers
import RpcTypes
import SolanaErrors
import XCTest
import os

final class RpcTransformersDetailedBehaviorTests: XCTestCase {
    func testDefaultCommitmentUsesPreflightCommitmentForSendTransaction() throws {
        let transformer = getDefaultRequestTransformerForSolanaRpc(
            RequestTransformerConfig(defaultCommitment: .processed)
        )

        let added = try transformer(
            RpcRequest(methodName: "sendTransaction", params: .array([.string("tx")]))
        )
        XCTAssertEqual(
            added.params,
            .array([
                .string("tx"),
                .object([RpcJsonObjectMember("preflightCommitment", .string("processed"))]),
            ])
        )

        let cleaned = try transformer(
            RpcRequest(
                methodName: "sendTransaction",
                params: .array([
                    .string("tx"),
                    .object([
                        RpcJsonObjectMember("preflightCommitment", .string("finalized")),
                        RpcJsonObjectMember("skipPreflight", .bool(true)),
                    ]),
                ])
            )
        )
        XCTAssertEqual(
            cleaned.params,
            .array([
                .string("tx"),
                .object([RpcJsonObjectMember("skipPreflight", .bool(true))]),
            ])
        )
    }

    func testDefaultCommitmentLeavesNonObjectOptionsInPlace() throws {
        let transformer = getDefaultCommitmentRequestTransformer(
            defaultCommitment: .processed,
            optionsObjectPositionByMethod: ["testMethod": 1]
        )

        for value in [RpcJsonValue.null, .number(1), .bigint("1"), .string("1"), .array([.number(1)])] {
            let request = RpcRequest(methodName: "testMethod", params: .array([.string("first"), value]))
            XCTAssertEqual(try transformer(request), request, "\(value)")
        }
    }

    func testDefaultCommitmentLeavesNullPlaceholderWhenRemovedOptionsAreNotLast() throws {
        let transformer = getDefaultCommitmentRequestTransformer(
            defaultCommitment: .processed,
            optionsObjectPositionByMethod: ["testMethod": 1]
        )

        let transformed = try transformer(
            RpcRequest(
                methodName: "testMethod",
                params: .array([
                    .string("first"),
                    .object([RpcJsonObjectMember("commitment", .string("finalized"))]),
                    .string("third"),
                ])
            )
        )

        XCTAssertEqual(
            transformed.params,
            .array([.string("first"), .null, .string("third")])
        )
    }

    func testIntegerOverflowHandlerSeesNestedPathsBeforeDowncast() throws {
        let captures = OSAllocatedUnfairLock(initialState: [(RpcKeyPath, String)]())
        let transformer = getDefaultRequestTransformerForSolanaRpc(
            RequestTransformerConfig { _, keyPath, value in
                captures.withLock { $0.append((keyPath, value)) }
            }
        )

        let request = RpcRequest(
            methodName: "testMethod",
            params: .object([
                ("safe", .bigint("9007199254740991")),
                ("positive", .array([.bigint("9007199254740992")])),
                ("negative", .object([("value", .bigint("-9007199254740992"))])),
            ])
        )
        let transformed = try transformer(request)

        XCTAssertEqual(
            transformed.params,
            .object([
                ("safe", .number(9_007_199_254_740_991)),
                ("positive", .array([.number(9_007_199_254_740_992)])),
                ("negative", .object([("value", .number(-9_007_199_254_740_992))])),
            ])
        )
        let recorded = captures.withLock { $0 }
        XCTAssertEqual(recorded.map(\.0), [[.key("positive"), .index(0)], [.key("negative"), .key("value")]])
        XCTAssertEqual(recorded.map(\.1), ["9007199254740992", "-9007199254740992"])
    }

    func testResponseUpcastHonorsWildcardAllowedNumericKeyPaths() throws {
        let transformer = getBigIntUpcastResponseTransformer(
            allowedNumericKeyPaths: [
                [.key("items"), .wildcard, .key("decimals")],
            ]
        )
        let request = RpcRequest(methodName: "testMethod", params: .array([]))
        let response = RpcJsonValue.object([
            ("items", .array([
                .object([("amount", .number(1)), ("decimals", .number(9))]),
                .object([("amount", .number(2)), ("decimals", .bigint("6"))]),
            ])),
        ])

        XCTAssertEqual(
            try transformer(response, request),
            .object([
                ("items", .array([
                    .object([("amount", .bigint("1")), ("decimals", .number(9))]),
                    .object([("amount", .bigint("2")), ("decimals", .number(6))]),
                ])),
            ])
        )
    }

    func testThrowingResponseTransformerReportsMalformedErrorObjects() throws {
        let transformer = getThrowSolanaErrorResponseTransformer()
        let request = RpcRequest(methodName: "getBalance", params: .array([]))

        XCTAssertThrowsError(
            try transformer(.object([("error", .object([("message", .string("missing code"))]))]), request)
        ) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.code, SolanaErrorCode.malformedJSONRPCError.rawValue)
            XCTAssertEqual(solanaError?.context["message"], .string("missing code"))
            XCTAssertEqual(solanaError?.context["error"], .object(["message": .string("missing code")]))
        }

        XCTAssertThrowsError(
            try transformer(.object([("error", .object([("code", .number(-32004))]))]), request)
        ) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.code, SolanaErrorCode.malformedJSONRPCError.rawValue)
            XCTAssertEqual(solanaError?.context["message"], .string("Malformed JSON-RPC error with no message attribute"))
        }
    }

    func testSubscriptionResponseTransformerUpcastsPayloadWithoutResultExtraction() throws {
        let transformer = getDefaultResponseTransformerForSolanaRpcSubscriptions(
            ResponseTransformerConfig(
                allowedNumericKeyPaths: [
                    "accountNotifications": [[.key("value"), .key("decimals")]],
                ]
            )
        )
        let request = RpcRequest(methodName: "accountNotifications", params: .array([]))
        let response = RpcJsonValue.object([
            ("value", .object([
                ("amount", .number(42)),
                ("decimals", .number(9)),
            ])),
        ])

        XCTAssertEqual(
            try transformer(response, request),
            .object([
                ("value", .object([
                    ("amount", .bigint("42")),
                    ("decimals", .number(9)),
                ])),
            ])
        )
    }
}
