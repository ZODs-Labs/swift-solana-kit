import Addresses
import RpcApi
import RpcSpec
import RpcSpecTypes
import RpcTransformers
import RpcTypes
import SolanaErrors
import XCTest

final class RpcApiDetailedBehaviorTests: XCTestCase {
    func testOptionalParametersPreserveRequiredNullPlaceholdersAndTrimTrailingValues() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = SolanaRpcApi(api: createJsonRpcApi())
        let recorder = RpcApiPayloadRecorder(response: .object([RpcJsonObjectMember("result", .null)]))
        let transport: RpcTransport = { config in await recorder.transport(config) }
        let config = RpcJsonValue.object([("commitment", .string("processed"))])

        _ = try await api.getBlocks(13, config: config).execute(transport: transport)
        _ = try await api.getBlocks(13).execute(transport: transport)
        _ = try await api.getLeaderSchedule(nil, config: config).execute(transport: transport)
        _ = try await api.getLeaderSchedule().execute(transport: transport)
        _ = try await api.getRecentPrioritizationFees().execute(transport: transport)
        _ = try await api.getRecentPrioritizationFees([]).execute(transport: transport)
        _ = try await api.getInflationReward([], config: config).execute(transport: transport)
        _ = try await api.getMultipleAccounts([address], config: nil).execute(transport: transport)

        let blockParams = try await recorder.params(at: 0)
        let trimmedBlockParams = try await recorder.params(at: 1)
        let currentLeaderParams = try await recorder.params(at: 2)
        let leaderParams = try await recorder.params(at: 3)
        let noFeeAddressParams = try await recorder.params(at: 4)
        let emptyFeeAddressParams = try await recorder.params(at: 5)
        let emptyRewardAddressParams = try await recorder.params(at: 6)
        let accountParams = try await recorder.params(at: 7)

        XCTAssertEqual(blockParams, .array([.bigint("13"), .null, config]))
        XCTAssertEqual(trimmedBlockParams, .array([.bigint("13")]))
        XCTAssertEqual(currentLeaderParams, .array([.null, config]))
        XCTAssertEqual(leaderParams, .array([]))
        XCTAssertEqual(noFeeAddressParams, .array([]))
        XCTAssertEqual(emptyFeeAddressParams, .array([.array([])]))
        XCTAssertEqual(emptyRewardAddressParams, .array([.array([]), config]))
        XCTAssertEqual(accountParams, .array([.array([.string(address.rawValue)])]))
    }

    func testDefaultCommitmentPreservesExplicitValuesAndRemovesFinalizedLikeValues() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi(RequestTransformerConfig(defaultCommitment: .confirmed))
        let recorder = RpcApiPayloadRecorder(response: .object([RpcJsonObjectMember("result", .null)]))
        let transport: RpcTransport = { config in await recorder.transport(config) }

        _ = try await api.getBalance(address, config: .object([("commitment", .string("processed"))])).execute(transport: transport)
        _ = try await api.getBalance(address, config: .object([("commitment", .string("finalized"))])).execute(transport: transport)
        _ = try await api.getAccountInfo(
            address,
            config: .object([
                ("encoding", .string("base64")),
                ("commitment", .null),
            ])
        ).execute(transport: transport)
        _ = try await api.getBlockHeight(config: .object([("minContextSlot", .bigint("0"))])).execute(transport: transport)
        _ = try await api.sendTransaction("wire", config: .object([("encoding", .string("base64"))])).execute(transport: transport)

        let explicitCommitmentParams = try await recorder.params(at: 0)
        let finalizedCommitmentParams = try await recorder.params(at: 1)
        let accountInfoParams = try await recorder.params(at: 2)
        let blockHeightParams = try await recorder.params(at: 3)
        let sendTransactionParams = try await recorder.params(at: 4)

        XCTAssertEqual(
            explicitCommitmentParams,
            .array([.string(address.rawValue), .object([RpcJsonObjectMember("commitment", .string("processed"))])])
        )
        XCTAssertEqual(finalizedCommitmentParams, .array([.string(address.rawValue)]))
        XCTAssertEqual(
            accountInfoParams,
            .array([.string(address.rawValue), .object([RpcJsonObjectMember("encoding", .string("base64"))])])
        )
        XCTAssertEqual(
            blockHeightParams,
            .array([
                .object([
                    RpcJsonObjectMember("minContextSlot", .number(0)),
                    RpcJsonObjectMember("commitment", .string("confirmed")),
                ]),
            ])
        )
        XCTAssertEqual(
            sendTransactionParams,
            .array([
                .string("wire"),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("preflightCommitment", .string("confirmed")),
                ]),
            ])
        )
    }

    func testLargeIntegerRequestValuesAreDowncastAndResponseValuesAreUpcast() async throws {
        let largeSlot: Slot = 9_007_199_254_740_992
        let api = createSolanaRpcApi()
        let recorder = RpcApiPayloadRecorder(
            response: .object([
                RpcJsonObjectMember("result", .array([.number(9_007_199_254_740_992)])),
            ])
        )

        let result = try await api.getBlocks(
            largeSlot,
            endSlotInclusive: largeSlot + 2,
            config: .object([("commitment", .string("processed"))])
        ).execute(transport: { config in await recorder.transport(config) })

        let params = try await recorder.params(at: 0)

        XCTAssertEqual(
            params,
            .array([
                .number(9_007_199_254_740_992),
                .number(9_007_199_254_740_994),
                .object([RpcJsonObjectMember("commitment", .string("processed"))]),
            ])
        )
        XCTAssertEqual(result, .array([.bigint("9007199254740992")]))
    }

    func testServerErrorsAreThrownWithStructuredContext() async throws {
        let api = createSolanaRpcApi()
        let response = RpcJsonValue.object([
            ("error", .object([
                ("code", .number(-32005)),
                ("message", .string("Node is unhealthy")),
                ("data", .object([
                    ("numSlotsBehind", .number(123)),
                    ("details", .object([("leader", .string("behind"))])),
                ])),
            ])),
        ])

        do {
            _ = try await api.getHealth().execute(transport: { _ in response })
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.jsonRPCServerErrorNodeUnhealthy.rawValue)
            XCTAssertEqual(error.context["numSlotsBehind"], .int(123))
            XCTAssertEqual(error.context["details"], .object(["leader": .string("behind")]))
        }
    }

    func testSendTransactionPreflightFailureMapsCauseAndNumericData() async throws {
        let api = createSolanaRpcApi()
        let response = RpcJsonValue.object([
            ("error", .object([
                ("code", .number(-32002)),
                ("message", .string("Transaction simulation failed")),
                ("data", .object([
                    ("err", .string("BlockhashNotFound")),
                    ("loadedAccountsDataSize", .bigint("64")),
                    ("unitsConsumed", .bigint("5000")),
                ])),
            ])),
        ])

        do {
            _ = try await api.sendTransaction("wire").execute(transport: { _ in response })
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.jsonRPCServerErrorSendTransactionPreflightFailure.rawValue)
            XCTAssertNil(error.context["err"])
            XCTAssertEqual(error.context["loadedAccountsDataSize"], .int(64))
            XCTAssertEqual(error.context["unitsConsumed"], .bigint("5000"))
            XCTAssertEqual(
                error.context["cause"],
                .object(["code": .int(SolanaErrorCode.transactionErrorBlockhashNotFound.rawValue)])
            )
        }
    }

    func testSmallNumericResponseFieldsStayNumericAtMethodSpecificPaths() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi()

        let nodes = try await api.getClusterNodes().execute(transport: rpcApiTransportReturningResult(
            .array([
                .object([
                    RpcJsonObjectMember("featureSet", .number(1)),
                    RpcJsonObjectMember("shredVersion", .number(2)),
                    RpcJsonObjectMember("pubkey", .string(address.rawValue)),
                ]),
            ])
        ))
        XCTAssertEqual(nodes.value(at: [.index(0), .key("featureSet")]), .number(1))
        XCTAssertEqual(nodes.value(at: [.index(0), .key("shredVersion")]), .number(2))

        let inflationGovernor = try await api.getInflationGovernor().execute(transport: rpcApiTransportReturningResult(
            .object([
                RpcJsonObjectMember("initial", .number(8)),
                RpcJsonObjectMember("foundation", .number(5)),
                RpcJsonObjectMember("foundationTerm", .number(7)),
                RpcJsonObjectMember("taper", .number(15)),
                RpcJsonObjectMember("terminal", .number(1.5)),
            ])
        ))
        XCTAssertEqual(inflationGovernor.value(at: [.key("initial")]), .number(8))
        XCTAssertEqual(inflationGovernor.value(at: [.key("terminal")]), .number(1.5))

        let inflationReward = try await api.getInflationReward([address]).execute(transport: rpcApiTransportReturningResult(
            .array([
                .object([
                    RpcJsonObjectMember("amount", .number(1000)),
                    RpcJsonObjectMember("commission", .number(9)),
                ]),
            ])
        ))
        XCTAssertEqual(inflationReward.value(at: [.index(0), .key("commission")]), .number(9))
        XCTAssertEqual(inflationReward.value(at: [.index(0), .key("amount")]), .bigint("1000"))

        let samples = try await api.getRecentPerformanceSamples(limit: 1).execute(transport: rpcApiTransportReturningResult(
            .array([
                .object([
                    RpcJsonObjectMember("numSlots", .number(120)),
                    RpcJsonObjectMember("samplePeriodSecs", .number(60)),
                ]),
            ])
        ))
        XCTAssertEqual(samples.value(at: [.index(0), .key("samplePeriodSecs")]), .number(60))
        XCTAssertEqual(samples.value(at: [.index(0), .key("numSlots")]), .bigint("120"))

        let largestAccounts = try await api.getTokenLargestAccounts(address).execute(transport: rpcApiTransportReturningResult(
            .object([
                RpcJsonObjectMember(
                    "value",
                    .array([
                        .object([
                            RpcJsonObjectMember("amount", .number(1000)),
                            RpcJsonObjectMember("decimals", .number(6)),
                            RpcJsonObjectMember("uiAmount", .number(10)),
                        ]),
                    ])
                ),
            ])
        ))
        XCTAssertEqual(largestAccounts.value(at: [.key("value"), .index(0), .key("amount")]), .bigint("1000"))
        XCTAssertEqual(largestAccounts.value(at: [.key("value"), .index(0), .key("decimals")]), .number(6))
        XCTAssertEqual(largestAccounts.value(at: [.key("value"), .index(0), .key("uiAmount")]), .number(10))

        let voteAccounts = try await api.getVoteAccounts().execute(transport: rpcApiTransportReturningResult(
            .object([
                RpcJsonObjectMember("current", .array([.object([RpcJsonObjectMember("commission", .number(5))])])),
                RpcJsonObjectMember("delinquent", .array([.object([RpcJsonObjectMember("commission", .number(6))])])),
                RpcJsonObjectMember("epochCredits", .number(1000)),
            ])
        ))
        XCTAssertEqual(voteAccounts.value(at: [.key("current"), .index(0), .key("commission")]), .number(5))
        XCTAssertEqual(voteAccounts.value(at: [.key("delinquent"), .index(0), .key("commission")]), .number(6))
        XCTAssertEqual(voteAccounts.value(at: [.key("epochCredits")]), .bigint("1000"))
    }

    func testStructuredRequestConfigsKeepFiltersDataSlicesAndSimulationOptions() async throws {
        let owner = try Addresses.address("11111111111111111111111111111111")
        let program = try Addresses.address("Sysvar1111111111111111111111111111111111111")
        let api = createSolanaRpcApi()
        let recorder = RpcApiPayloadRecorder(response: .object([RpcJsonObjectMember("result", .null)]))
        let transport: RpcTransport = { config in await recorder.transport(config) }
        let programConfig = RpcJsonValue.object([
            ("encoding", .string("base64")),
            ("dataSlice", .object([
                ("offset", .bigint("2")),
                ("length", .bigint("8")),
            ])),
            ("filters", .array([
                .object([RpcJsonObjectMember("dataSize", .bigint("165"))]),
                .object([RpcJsonObjectMember("memcmp", .object([
                    ("offset", .bigint("32")),
                    ("bytes", .string(owner.rawValue)),
                ]))]),
            ])),
        ])
        let simulationConfig = RpcJsonValue.object([
            ("encoding", .string("base64")),
            ("accounts", .object([
                ("addresses", .array([.string(owner.rawValue), .string(program.rawValue)])),
                ("encoding", .string("jsonParsed")),
            ])),
            ("sigVerify", .bool(false)),
            ("replaceRecentBlockhash", .bool(true)),
            ("innerInstructions", .bool(true)),
            ("minContextSlot", .bigint("123")),
        ])

        _ = try await api.getProgramAccounts(program, config: programConfig).execute(transport: transport)
        _ = try await api.getTokenAccountsByOwner(
            owner,
            filter: .object([("programId", .string(program.rawValue))]),
            config: .object([
                ("encoding", .string("jsonParsed")),
                ("minContextSlot", .bigint("456")),
            ])
        ).execute(transport: transport)
        _ = try await api.simulateTransaction("wire", config: simulationConfig).execute(transport: transport)

        let programAccountParams = try await recorder.params(at: 0)
        let tokenAccountParams = try await recorder.params(at: 1)
        let simulationParams = try await recorder.params(at: 2)

        XCTAssertEqual(
            programAccountParams,
            .array([
                .string(program.rawValue),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("dataSlice", .object([
                        ("offset", .number(2)),
                        ("length", .number(8)),
                    ])),
                    RpcJsonObjectMember("filters", .array([
                        .object([RpcJsonObjectMember("dataSize", .number(165))]),
                        .object([RpcJsonObjectMember("memcmp", .object([
                            ("offset", .number(32)),
                            ("bytes", .string(owner.rawValue)),
                        ]))]),
                    ])),
                ]),
            ])
        )
        XCTAssertEqual(
            tokenAccountParams,
            .array([
                .string(owner.rawValue),
                .object([RpcJsonObjectMember("programId", .string(program.rawValue))]),
                .object([
                    RpcJsonObjectMember("encoding", .string("jsonParsed")),
                    RpcJsonObjectMember("minContextSlot", .number(456)),
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
                        ("encoding", .string("jsonParsed")),
                    ])),
                    RpcJsonObjectMember("sigVerify", .bool(false)),
                    RpcJsonObjectMember("replaceRecentBlockhash", .bool(true)),
                    RpcJsonObjectMember("innerInstructions", .bool(true)),
                    RpcJsonObjectMember("minContextSlot", .number(123)),
                ]),
            ])
        )
    }
}

private func rpcApiTransportReturningResult(_ result: RpcJsonValue) -> RpcTransport {
    { _ in .object([RpcJsonObjectMember("result", result)]) }
}

private actor RpcApiPayloadRecorder {
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
        try XCTUnwrap(capturedPayloads[rpcApiSafe: index])
    }

    func params(at index: Int) throws -> RpcJsonValue? {
        try payload(at: index).value(for: "params")
    }
}

private extension Array {
    subscript(rpcApiSafe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension RpcJsonValue {
    func value(at path: [RpcApiTestJsonPathComponent]) -> RpcJsonValue? {
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

private enum RpcApiTestJsonPathComponent {
    case key(String)
    case index(Int)
}
