import Addresses
import RpcApi
import RpcSpec
import RpcSpecTypes
import RpcTransformers
import RpcTypes
import SolanaErrors
import XCTest

final class RpcApiRuntimeBehaviorTests: XCTestCase {
    func testAccountResponsesKeepNullEncodedParsedAndSliceShapes() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi()
        let recorder = RpcApiRuntimePayloadRecorder(response: rpcApiRuntimeResult(.object([
            RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(14))])),
            RpcJsonObjectMember("value", .object([
                RpcJsonObjectMember("data", .array([.string("3Bxs"), .string("base64")])),
                RpcJsonObjectMember("executable", .bool(false)),
                RpcJsonObjectMember("lamports", .number(2_039_280)),
                RpcJsonObjectMember("owner", .string(address.rawValue)),
                RpcJsonObjectMember("rentEpoch", .number(0)),
                RpcJsonObjectMember("space", .number(165)),
            ])),
        ])))
        let transport: RpcTransport = { config in await recorder.transport(config) }

        _ = try await api.getAccountInfo(
            address,
            config: .object([
                ("encoding", .string("base64")),
                ("dataSlice", .object([
                    ("offset", .bigint("2")),
                    ("length", .bigint("4")),
                ])),
            ])
        ).execute(transport: transport)
        let encoded = try await api.getAccountInfo(address).execute(transport: rpcApiRuntimeTransportReturningResult(.object([
            RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(15))])),
            RpcJsonObjectMember("value", .object([
                RpcJsonObjectMember("data", .string("3Bxs")),
                RpcJsonObjectMember("executable", .bool(false)),
                RpcJsonObjectMember("lamports", .number(1)),
                RpcJsonObjectMember("owner", .string(address.rawValue)),
                RpcJsonObjectMember("rentEpoch", .number(0)),
            ])),
        ])))
        let parsed = try await api.getAccountInfo(address).execute(transport: rpcApiRuntimeTransportReturningResult(.object([
            RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(16))])),
            RpcJsonObjectMember("value", .object([
                RpcJsonObjectMember("data", .object([
                    RpcJsonObjectMember("program", .string("spl-token")),
                    RpcJsonObjectMember("parsed", .object([
                        RpcJsonObjectMember("type", .string("mint")),
                        RpcJsonObjectMember("info", .object([
                            RpcJsonObjectMember("decimals", .number(6)),
                            RpcJsonObjectMember("mintAuthority", .null),
                            RpcJsonObjectMember("supply", .number(1_000_000)),
                        ])),
                    ])),
                ])),
                RpcJsonObjectMember("lamports", .number(1)),
                RpcJsonObjectMember("owner", .string(address.rawValue)),
                RpcJsonObjectMember("space", .number(82)),
            ])),
        ])))
        let missing = try await api.getAccountInfo(address).execute(transport: rpcApiRuntimeTransportReturningResult(.object([
            RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(17))])),
            RpcJsonObjectMember("value", .null),
        ])))

        let params = try await recorder.params(at: 0)

        XCTAssertEqual(
            params,
            .array([
                .string(address.rawValue),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("dataSlice", .object([
                        ("offset", .number(2)),
                        ("length", .number(4)),
                    ])),
                ]),
            ])
        )
        XCTAssertEqual(encoded.value(at: [.key("value"), .key("data")]), .string("3Bxs"))
        XCTAssertEqual(encoded.value(at: [.key("value"), .key("lamports")]), .bigint("1"))
        XCTAssertEqual(parsed.value(at: [.key("value"), .key("data"), .key("parsed"), .key("info"), .key("decimals")]), .number(6))
        XCTAssertEqual(parsed.value(at: [.key("value"), .key("data"), .key("parsed"), .key("info"), .key("supply")]), .bigint("1000000"))
        XCTAssertEqual(parsed.value(at: [.key("context"), .key("slot")]), .bigint("16"))
        XCTAssertEqual(missing.value(at: [.key("value")]), .null)
    }

    func testAccountListsKeepNullEntriesWrappedContextAndBareProgramAccounts() async throws {
        let owner = try Addresses.address("11111111111111111111111111111111")
        let program = try Addresses.address("Sysvar1111111111111111111111111111111111111")
        let api = createSolanaRpcApi()

        let multipleAccounts = try await api.getMultipleAccounts([owner, program]).execute(transport: rpcApiRuntimeTransportReturningResult(.object([
            RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(21))])),
            RpcJsonObjectMember("value", .array([
                .null,
                .object([
                    RpcJsonObjectMember("data", .array([.string("AA=="), .string("base64")])),
                    RpcJsonObjectMember("executable", .bool(false)),
                    RpcJsonObjectMember("lamports", .number(44)),
                    RpcJsonObjectMember("owner", .string(owner.rawValue)),
                    RpcJsonObjectMember("rentEpoch", .number(0)),
                    RpcJsonObjectMember("space", .number(8)),
                ]),
            ])),
        ])))
        let bareProgramAccounts = try await api.getProgramAccounts(program).execute(transport: rpcApiRuntimeTransportReturningResult(.array([
            .object([
                RpcJsonObjectMember("pubkey", .string(owner.rawValue)),
                RpcJsonObjectMember("account", .object([
                    RpcJsonObjectMember("data", .object([
                        RpcJsonObjectMember("program", .string("vote")),
                        RpcJsonObjectMember("parsed", .object([
                            RpcJsonObjectMember("type", .string("vote")),
                            RpcJsonObjectMember("info", .object([
                                RpcJsonObjectMember("commission", .number(5)),
                                RpcJsonObjectMember("votes", .array([
                                    .object([RpcJsonObjectMember("confirmationCount", .number(31))]),
                                ])),
                            ])),
                        ])),
                    ])),
                    RpcJsonObjectMember("lamports", .number(55)),
                    RpcJsonObjectMember("owner", .string(program.rawValue)),
                ])),
            ]),
        ])))
        let wrappedProgramAccounts = try await api.getProgramAccounts(program).execute(transport: rpcApiRuntimeTransportReturningResult(.object([
            RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(22))])),
            RpcJsonObjectMember("value", .array([
                .object([
                    RpcJsonObjectMember("pubkey", .string(owner.rawValue)),
                    RpcJsonObjectMember("account", .object([
                        RpcJsonObjectMember("data", .array([.string("AA=="), .string("base64+zstd")])),
                        RpcJsonObjectMember("lamports", .number(66)),
                        RpcJsonObjectMember("owner", .string(program.rawValue)),
                    ])),
                ]),
            ])),
        ])))

        XCTAssertEqual(multipleAccounts.value(at: [.key("context"), .key("slot")]), .bigint("21"))
        XCTAssertEqual(multipleAccounts.value(at: [.key("value"), .index(0)]), .null)
        XCTAssertEqual(multipleAccounts.value(at: [.key("value"), .index(1), .key("data"), .index(1)]), .string("base64"))
        XCTAssertEqual(multipleAccounts.value(at: [.key("value"), .index(1), .key("lamports")]), .bigint("44"))
        XCTAssertEqual(bareProgramAccounts.value(at: [.index(0), .key("account"), .key("data"), .key("parsed"), .key("info"), .key("commission")]), .number(5))
        XCTAssertEqual(
            bareProgramAccounts.value(at: [.index(0), .key("account"), .key("data"), .key("parsed"), .key("info"), .key("votes"), .index(0), .key("confirmationCount")]),
            .number(31)
        )
        XCTAssertEqual(bareProgramAccounts.value(at: [.index(0), .key("account"), .key("lamports")]), .bigint("55"))
        XCTAssertEqual(wrappedProgramAccounts.value(at: [.key("context"), .key("slot")]), .bigint("22"))
        XCTAssertEqual(wrappedProgramAccounts.value(at: [.key("value"), .index(0), .key("account"), .key("data"), .index(1)]), .string("base64+zstd"))
    }

    func testTransactionRequestsKeepEncodingRetryAndSimulationOptions() async throws {
        let owner = try Addresses.address("11111111111111111111111111111111")
        let program = try Addresses.address("Sysvar1111111111111111111111111111111111111")
        let api = createSolanaRpcApi(RequestTransformerConfig(defaultCommitment: .confirmed))
        let recorder = RpcApiRuntimePayloadRecorder(response: rpcApiRuntimeResult(.null))
        let transport: RpcTransport = { config in await recorder.transport(config) }

        _ = try await api.sendTransaction(
            "wire",
            config: RpcJsonValue.object([
                ("encoding", .string("base64")),
                ("maxRetries", .bigint("3")),
                ("minContextSlot", .bigint("123")),
                ("skipPreflight", .bool(true)),
            ])
        ).execute(transport: transport)
        _ = try await api.simulateTransaction(
            "wire",
            config: RpcJsonValue.object([
                ("encoding", .string("base64")),
                ("accounts", .object([
                    ("addresses", .array([.string(owner.rawValue), .string(program.rawValue)])),
                    ("encoding", .string("base64+zstd")),
                ])),
                ("sigVerify", .bool(true)),
                ("replaceRecentBlockhash", .bool(false)),
                ("innerInstructions", .bool(true)),
                ("minContextSlot", .bigint("456")),
            ])
        ).execute(transport: transport)
        _ = try await api.getFeeForMessage("message", config: RpcJsonValue.object([
            ("commitment", .string("processed")),
            ("minContextSlot", .bigint("789")),
        ])).execute(transport: transport)
        let sendParams = try await recorder.params(at: 0)
        let simulationParams = try await recorder.params(at: 1)
        let feeParams = try await recorder.params(at: 2)

        XCTAssertEqual(
            sendParams,
            .array([
                .string("wire"),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("maxRetries", .number(3)),
                    RpcJsonObjectMember("minContextSlot", .number(123)),
                    RpcJsonObjectMember("skipPreflight", .bool(true)),
                    RpcJsonObjectMember("preflightCommitment", .string("confirmed")),
                ]),
            ])
        )
        XCTAssertEqual(
            simulationParams,
            .array([
                .string("wire"),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("accounts", .object([
                        ("addresses", .array([.string(owner.rawValue), .string(program.rawValue)])),
                        ("encoding", .string("base64+zstd")),
                    ])),
                    RpcJsonObjectMember("sigVerify", .bool(true)),
                    RpcJsonObjectMember("replaceRecentBlockhash", .bool(false)),
                    RpcJsonObjectMember("innerInstructions", .bool(true)),
                    RpcJsonObjectMember("minContextSlot", .number(456)),
                    RpcJsonObjectMember("commitment", .string("confirmed")),
                ]),
            ])
        )
        XCTAssertEqual(
            feeParams,
            .array([
                .string("message"),
                .object([
                    RpcJsonObjectMember("commitment", .string("processed")),
                    RpcJsonObjectMember("minContextSlot", .number(789)),
                ]),
            ])
        )
    }

    func testServerErrorsMapInvalidParamsMinContextAndTransactionCauses() async throws {
        let api = createSolanaRpcApi()

        do {
            _ = try await api.getFeeForMessage("invalid").execute(transport: { _ in
                .object([
                    RpcJsonObjectMember("error", .object([
                        ("code", .number(-32602)),
                        ("message", .string("invalid base64 encoding: InvalidPadding")),
                    ])),
                ])
            })
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.jsonRPCInvalidParams.rawValue)
            XCTAssertEqual(error.context["__serverMessage"], .string("invalid base64 encoding: InvalidPadding"))
        }

        do {
            _ = try await api.sendTransaction("wire").execute(transport: { _ in
                .object([
                    RpcJsonObjectMember("error", .object([
                        ("code", .number(-32016)),
                        ("message", .string("Minimum context slot has not been reached")),
                        ("data", .object([
                            ("contextSlot", .bigint("9007199254740993")),
                        ])),
                    ])),
                ])
            })
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.jsonRPCServerErrorMinContextSlotNotReached.rawValue)
            XCTAssertEqual(error.context["contextSlot"], .bigint("9007199254740993"))
        }

        do {
            _ = try await api.sendTransaction("wire").execute(transport: { _ in
                .object([
                    RpcJsonObjectMember("error", .object([
                        ("code", .number(-32002)),
                        ("message", .string("Transaction simulation failed")),
                        ("data", .object([
                            ("err", .object([
                                RpcJsonObjectMember("InsufficientFundsForRent", .object([
                                    ("account_index", .number(2)),
                                ])),
                            ])),
                            ("accounts", .null),
                            ("loadedAccountsDataSize", .number(0)),
                            ("logs", .array([])),
                            ("unitsConsumed", .number(0)),
                        ])),
                    ])),
                ])
            })
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.jsonRPCServerErrorSendTransactionPreflightFailure.rawValue)
            XCTAssertNil(error.context["err"])
            XCTAssertEqual(error.context["accounts"], .null)
            XCTAssertEqual(error.context["loadedAccountsDataSize"], .int(0))
            XCTAssertEqual(error.context["unitsConsumed"], .bigint("0"))
            XCTAssertEqual(
                error.context["cause"],
                .object([
                    "code": .int(SolanaErrorCode.transactionErrorInsufficientFundsForRent.rawValue),
                    "context": .object(["accountIndex": .int(2)]),
                ])
            )
        }
    }

    func testSimulationResponseKeepsErrorAccountAndReplacementShapes() async throws {
        let owner = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi()

        let result = try await api.simulateTransaction("wire").execute(transport: rpcApiRuntimeTransportReturningResult(.object([
            RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(41))])),
            RpcJsonObjectMember("value", .object([
                RpcJsonObjectMember("accounts", .array([
                    .null,
                    .object([
                        RpcJsonObjectMember("data", .array([.string("AA=="), .string("base64")])),
                        RpcJsonObjectMember("executable", .bool(false)),
                        RpcJsonObjectMember("lamports", .number(1)),
                        RpcJsonObjectMember("owner", .string(owner.rawValue)),
                    ]),
                    .object([
                        RpcJsonObjectMember("data", .object([
                            RpcJsonObjectMember("program", .string("vote")),
                            RpcJsonObjectMember("parsed", .object([
                                RpcJsonObjectMember("type", .string("vote")),
                                RpcJsonObjectMember("info", .object([
                                    RpcJsonObjectMember("commission", .number(7)),
                                    RpcJsonObjectMember("votes", .array([
                                        .object([RpcJsonObjectMember("confirmationCount", .number(9))]),
                                    ])),
                                    RpcJsonObjectMember("rootSlot", .number(123)),
                                ])),
                            ])),
                        ])),
                        RpcJsonObjectMember("lamports", .number(2)),
                        RpcJsonObjectMember("owner", .string(owner.rawValue)),
                    ]),
                ])),
                RpcJsonObjectMember("err", .string("SignatureFailure")),
                RpcJsonObjectMember("fee", .number(5_000)),
                RpcJsonObjectMember("innerInstructions", .array([
                    .object([
                        RpcJsonObjectMember("index", .number(0)),
                        RpcJsonObjectMember("instructions", .array([
                            .object([
                                RpcJsonObjectMember("programIdIndex", .number(3)),
                                RpcJsonObjectMember("stackHeight", .number(1)),
                            ]),
                        ])),
                    ]),
                ])),
                RpcJsonObjectMember("loadedAccountsDataSize", .number(64)),
                RpcJsonObjectMember("logs", .array([.string("Program log")]),
                ),
                RpcJsonObjectMember("replacementBlockhash", .object([
                    ("blockhash", .string("11111111111111111111111111111111")),
                    ("lastValidBlockHeight", .number(222)),
                ])),
                RpcJsonObjectMember("unitsConsumed", .number(12_345)),
            ])),
        ])))

        XCTAssertEqual(result.value(at: [.key("context"), .key("slot")]), .bigint("41"))
        XCTAssertEqual(result.value(at: [.key("value"), .key("accounts"), .index(0)]), .null)
        XCTAssertEqual(result.value(at: [.key("value"), .key("accounts"), .index(1), .key("data"), .index(1)]), .string("base64"))
        XCTAssertEqual(result.value(at: [.key("value"), .key("accounts"), .index(1), .key("lamports")]), .bigint("1"))
        XCTAssertEqual(result.value(at: [.key("value"), .key("accounts"), .index(2), .key("data"), .key("parsed"), .key("info"), .key("commission")]), .number(7))
        XCTAssertEqual(
            result.value(at: [.key("value"), .key("accounts"), .index(2), .key("data"), .key("parsed"), .key("info"), .key("votes"), .index(0), .key("confirmationCount")]),
            .number(9)
        )
        XCTAssertEqual(result.value(at: [.key("value"), .key("accounts"), .index(2), .key("data"), .key("parsed"), .key("info"), .key("rootSlot")]), .bigint("123"))
        XCTAssertEqual(result.value(at: [.key("value"), .key("err")]), .string("SignatureFailure"))
        XCTAssertEqual(result.value(at: [.key("value"), .key("fee")]), .bigint("5000"))
        XCTAssertEqual(result.value(at: [.key("value"), .key("innerInstructions"), .index(0), .key("index")]), .number(0))
        XCTAssertEqual(
            result.value(at: [.key("value"), .key("innerInstructions"), .index(0), .key("instructions"), .index(0), .key("programIdIndex")]),
            .number(3)
        )
        XCTAssertEqual(result.value(at: [.key("value"), .key("loadedAccountsDataSize")]), .number(64))
        XCTAssertEqual(result.value(at: [.key("value"), .key("replacementBlockhash"), .key("lastValidBlockHeight")]), .bigint("222"))
        XCTAssertEqual(result.value(at: [.key("value"), .key("unitsConsumed")]), .bigint("12345"))
    }
}

private func rpcApiRuntimeResult(_ result: RpcJsonValue) -> RpcJsonValue {
    .object([RpcJsonObjectMember("result", result)])
}

private func rpcApiRuntimeTransportReturningResult(_ result: RpcJsonValue) -> RpcTransport {
    { _ in rpcApiRuntimeResult(result) }
}

private actor RpcApiRuntimePayloadRecorder {
    private var capturedPayloads: [RpcJsonValue] = []
    private let response: RpcJsonValue

    init(response: RpcJsonValue) {
        self.response = response
    }

    func transport(_ config: RpcTransportConfig) -> RpcJsonValue {
        capturedPayloads.append(config.payload)
        return response
    }

    func payload(at index: Int) throws -> RpcJsonValue {
        try XCTUnwrap(capturedPayloads[rpcApiRuntimeSafe: index])
    }

    func params(at index: Int) throws -> RpcJsonValue? {
        try payload(at: index).value(for: "params")
    }
}

private extension Array {
    subscript(rpcApiRuntimeSafe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension RpcJsonValue {
    func value(at path: [RpcApiRuntimeJsonPathComponent]) -> RpcJsonValue? {
        var current: RpcJsonValue? = self
        for component in path {
            guard let value = current else {
                return nil
            }
            switch (component, value) {
            case let (.key(key), .object(members)):
                current = members.first { $0.key == key }?.value
            case let (.index(index), .array(values)):
                current = values.indices.contains(index) ? values[index] : nil
            default:
                return nil
            }
        }
        return current
    }
}

private enum RpcApiRuntimeJsonPathComponent {
    case key(String)
    case index(Int)
}
