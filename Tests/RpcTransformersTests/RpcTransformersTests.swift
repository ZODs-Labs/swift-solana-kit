import RpcSpecTypes
import RpcTransformers
import RpcTypes
import SolanaErrors
import XCTest
import os

final class RpcTransformersTests: XCTestCase {
    func testDefaultRequestTransformerChecksOverflowDowncastsBigintsAndAppliesCommitment() throws {
        let overflow = OSAllocatedUnfairLock<(RpcKeyPath, String)?>(initialState: nil)
        let transformer = getDefaultRequestTransformerForSolanaRpc(
            RequestTransformerConfig(defaultCommitment: .confirmed) { _, keyPath, value in
                overflow.withLock { captured in
                    captured = (keyPath, value)
                }
            }
        )

        let request = RpcRequest(methodName: "getBalance", params: .array([.string("address")]))
        let transformed = try transformer(request)

        XCTAssertEqual(transformed.params, .array([
            .string("address"),
            .object([RpcJsonObjectMember("commitment", .string("confirmed"))]),
        ]))

        let downcast = try transformer(RpcRequest(methodName: "getBlockCommitment", params: .array([.bigint("42")])))
        XCTAssertEqual(downcast.params, .array([.number(42)]))

        let unsafeDowncast = try transformer(RpcRequest(methodName: "getBlockCommitment", params: .array([.bigint("9007199254740993")])))
        XCTAssertEqual(unsafeDowncast.params, .array([.number(9_007_199_254_740_992)]))

        _ = try transformer(RpcRequest(methodName: "getBlocks", params: .array([.bigint("9007199254740992")])))
        let captured = overflow.withLock { $0 }
        XCTAssertEqual(captured?.0, [.index(0)])
        XCTAssertEqual(captured?.1, "9007199254740992")
    }

    func testDefaultCommitmentRemovesFinalizedConfig() throws {
        let transformer = getDefaultCommitmentRequestTransformer(
            defaultCommitment: .confirmed,
            optionsObjectPositionByMethod: optionsObjectPositionByMethod
        )
        let transformed = try transformer(
            RpcRequest(methodName: "getBlockHeight", params: .array([
                .object([RpcJsonObjectMember("commitment", .string("finalized"))]),
            ]))
        )
        XCTAssertEqual(transformed.params, .array([]))
    }

    func testDefaultCommitmentWithoutOverrideKeepsEmptyConfigObjectShape() throws {
        let transformer = getDefaultCommitmentRequestTransformer(
            defaultCommitment: nil,
            optionsObjectPositionByMethod: ["testMethod": 2]
        )

        let transformed = try transformer(RpcRequest(methodName: "testMethod", params: .array([])))

        XCTAssertEqual(transformed.params, .array([.null, .null, .object([RpcJsonObjectMember]())]))
    }

    func testDefaultCommitmentRemovesFalsyExistingCommitmentValues() throws {
        let transformer = getDefaultCommitmentRequestTransformer(
            defaultCommitment: .confirmed,
            optionsObjectPositionByMethod: ["testMethod": 0]
        )
        let values: [RpcJsonValue] = [.null, .bool(false), .number(0), .bigint("0"), .string("")]

        for value in values {
            let transformed = try transformer(
                RpcRequest(methodName: "testMethod", params: .array([
                    .object([
                        RpcJsonObjectMember("commitment", value),
                        RpcJsonObjectMember("other", .string("property")),
                    ]),
                ]))
            )
            XCTAssertEqual(
                transformed.params,
                .array([.object([RpcJsonObjectMember("other", .string("property"))])]),
                "\(value)"
            )
        }
    }

    func testDefaultCommitmentUsesLastDuplicateCommitmentMember() throws {
        let transformer = getDefaultCommitmentRequestTransformer(
            defaultCommitment: .confirmed,
            optionsObjectPositionByMethod: ["testMethod": 0]
        )

        let removed = try transformer(
            RpcRequest(methodName: "testMethod", params: .array([
                .object([
                    RpcJsonObjectMember("commitment", .string("processed")),
                    RpcJsonObjectMember("other", .string("property")),
                    RpcJsonObjectMember("commitment", .string("finalized")),
                ]),
            ]))
        )
        XCTAssertEqual(
            removed.params,
            .array([.object([RpcJsonObjectMember("other", .string("property"))])])
        )

        let retained = try transformer(
            RpcRequest(methodName: "testMethod", params: .array([
                .object([
                    RpcJsonObjectMember("commitment", .string("finalized")),
                    RpcJsonObjectMember("commitment", .string("processed")),
                ]),
            ]))
        )
        XCTAssertEqual(
            retained.params,
            .array([
                .object([
                    RpcJsonObjectMember("commitment", .string("finalized")),
                    RpcJsonObjectMember("commitment", .string("processed")),
                ]),
            ])
        )
    }

    func testResponseTransformerThrowsErrorsExtractsResultAndUpcastsIntegers() throws {
        let transformer = getDefaultResponseTransformerForSolanaRpc(ResponseTransformerConfig())
        let request = RpcRequest(methodName: "getBlockHeight", params: .array([]))
        let response = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("id", .string("1")),
            ("result", .object([("slot", .number(42))])),
        ])

        XCTAssertEqual(try transformer(response, request).value(for: "slot"), .bigint("42"))

        let errorResponse = RpcJsonValue.object([
            ("error", .object([("code", .bigint("-32004")), ("message", .string("Block not available"))])),
        ])
        XCTAssertThrowsError(try transformer(errorResponse, request)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.code, -32004)
            XCTAssertEqual(solanaError?.context["__serverMessage"], .string("Block not available"))
        }
    }

    func testBigIntUpcastDoesNotTrapForLargeIntegerNumbers() throws {
        let transformer = getBigIntUpcastResponseTransformer(allowedNumericKeyPaths: [])
        let request = RpcRequest(methodName: "getBlockHeight", params: .array([]))

        XCTAssertEqual(try transformer(.number(1e20), request), .bigint("100000000000000000000"))
        XCTAssertEqual(try transformer(.number(1e23), request), .bigint("99999999999999991611392"))
        XCTAssertEqual(
            try transformer(.number(1.2345678901234568e20), request),
            .bigint("123456789012345683968")
        )
        XCTAssertEqual(try transformer(.number(-0.0), request), .bigint("0"))
        XCTAssertEqual(try transformer(.number(10.5), request), .number(10.5))
    }

    func testErrorTransformerKeepsStructuredDataContext() throws {
        let transformer = getThrowSolanaErrorResponseTransformer()
        let request = RpcRequest(methodName: "getBlockHeight", params: .array([]))
        let response = RpcJsonValue.object([
            ("error", .object([
                ("code", .number(-32005)),
                ("message", .string("Node unhealthy")),
                ("data", .object([
                    ("numSlotsBehind", .bigint("12")),
                    ("details", .object([("leader", .string("behind"))])),
                ])),
            ])),
        ])

        XCTAssertThrowsError(try transformer(response, request)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.code, SolanaErrorCode.jsonRPCServerErrorNodeUnhealthy.rawValue)
            XCTAssertEqual(solanaError?.context["numSlotsBehind"], .bigint("12"))
            XCTAssertEqual(solanaError?.context["details"], .object(["leader": .string("behind")]))
        }
    }

    func testErrorTransformerThrowsMalformedErrorForPresentNonObjectError() throws {
        let transformer = getThrowSolanaErrorResponseTransformer()
        let request = RpcRequest(methodName: "getBlockHeight", params: .array([]))

        XCTAssertThrowsError(try transformer(.object([("error", .null)]), request)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.code, SolanaErrorCode.malformedJSONRPCError.rawValue)
            XCTAssertEqual(solanaError?.context["error"], .null)
        }
    }

    func testErrorTransformerContextObjectsUseLastDuplicateMember() throws {
        let transformer = getThrowSolanaErrorResponseTransformer()
        let request = RpcRequest(methodName: "getBlockHeight", params: .array([]))
        let response = RpcJsonValue.object([
            ("error", .object([
                ("code", .number(-32005)),
                ("message", .string("Node unhealthy")),
                ("data", .object([
                    ("details", .object([
                        ("leader", .string("first")),
                        ("leader", .string("second")),
                    ])),
                ])),
            ])),
        ])

        XCTAssertThrowsError(try transformer(response, request)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.context["details"], .object(["leader": .string("second")]))
        }
    }

    func testPreflightFailureDropsTransactionErrorFromContextAndDowncastsAllowedNumbers() throws {
        let transformer = getThrowSolanaErrorResponseTransformer()
        let request = RpcRequest(methodName: "sendTransaction", params: .array([]))
        let response = RpcJsonValue.object([
            ("error", .object([
                ("code", .number(-32002)),
                ("message", .string("simulation failed")),
                ("data", .object([
                    ("err", .string("BlockhashNotFound")),
                    ("loadedAccountsDataSize", .bigint("64")),
                    ("unitsConsumed", .bigint("5000")),
                ])),
            ])),
        ])

        XCTAssertThrowsError(try transformer(response, request)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.code, SolanaErrorCode.jsonRPCServerErrorSendTransactionPreflightFailure.rawValue)
            XCTAssertNil(solanaError?.context["err"])
            XCTAssertEqual(solanaError?.context["loadedAccountsDataSize"], .int(64))
            XCTAssertEqual(solanaError?.context["unitsConsumed"], .bigint("5000"))
            XCTAssertEqual(
                solanaError?.context["cause"],
                .object(["code": .int(SolanaErrorCode.transactionErrorBlockhashNotFound.rawValue)])
            )
        }
    }

    func testPreflightFailureMapsNestedInstructionCause() throws {
        let transformer = getThrowSolanaErrorResponseTransformer()
        let request = RpcRequest(methodName: "sendTransaction", params: .array([]))
        let response = RpcJsonValue.object([
            ("error", .object([
                ("code", .number(-32002)),
                ("message", .string("simulation failed")),
                ("data", .object([
                    ("err", .object([("InstructionError", .array([.bigint("3"), .object([("Custom", .bigint("6000"))])]))])),
                ])),
            ])),
        ])

        XCTAssertThrowsError(try transformer(response, request)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(
                solanaError?.context["cause"],
                .object([
                    "code": .int(SolanaErrorCode.instructionErrorCustom.rawValue),
                    "context": .object(["code": .int(6000), "index": .int(3)]),
                ])
            )
        }
    }

    func testPreflightFailureKeepsParsedTokenExtensionRatesNumeric() throws {
        let transformer = getThrowSolanaErrorResponseTransformer()
        let request = RpcRequest(methodName: "sendTransaction", params: .array([]))
        let response = RpcJsonValue.object([
            ("error", .object([
                ("code", .number(-32002)),
                ("message", .string("simulation failed")),
                ("data", .object([
                    ("accounts", .array([
                        .object([
                            ("data", .object([
                                ("parsed", .object([
                                    ("info", .object([
                                        ("extensions", .array([
                                            .object([
                                                ("state", .object([
                                                    ("olderTransferFee", .object([
                                                        ("transferFeeBasisPoints", .bigint("25")),
                                                    ])),
                                                    ("preUpdateAverageRate", .bigint("9")),
                                                ])),
                                            ]),
                                        ])),
                                    ])),
                                ])),
                            ])),
                        ]),
                    ])),
                    ("unitsConsumed", .bigint("5000")),
                ])),
            ])),
        ])

        XCTAssertThrowsError(try transformer(response, request)) { error in
            let solanaError = error as? SolanaError
            let accounts = solanaError?.context["accounts"]
            XCTAssertEqual(
                accounts,
                .array([
                    .object([
                        "data": .object([
                            "parsed": .object([
                                "info": .object([
                                    "extensions": .array([
                                        .object([
                                            "state": .object([
                                                "olderTransferFee": .object(["transferFeeBasisPoints": .int(25)]),
                                                "preUpdateAverageRate": .int(9),
                                            ]),
                                        ]),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ])
            )
            XCTAssertEqual(solanaError?.context["unitsConsumed"], .bigint("5000"))
        }
    }
}
