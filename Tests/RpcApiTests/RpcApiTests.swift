import Addresses
import RpcApi
import RpcSpec
import RpcSpecTypes
import RpcTransformers
import RpcTypes
import XCTest

final class RpcApiTests: XCTestCase {
    func testPilotMethodsProduceExpectedJsonRpcMethodNamesAndParams() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi(RequestTransformerConfig(defaultCommitment: .confirmed))
        let recorder = RpcTransportRecorder(response: .object([RpcJsonObjectMember("result", .bigint("1"))]))

        let transport: RpcTransport = { config in await recorder.transport(config) }

        _ = try await api.getAccountInfo(address).execute(transport: transport)
        _ = try await api.getBalance(address).execute(transport: transport)
        _ = try await api.getBlock(10).execute(transport: transport)
        _ = try await api.getBlockCommitment(11).execute(transport: transport)
        _ = try await api.getBlockHeight().execute(transport: transport)
        _ = try await api.getBlockProduction().execute(transport: transport)
        _ = try await api.getBlockTime(12).execute(transport: transport)
        _ = try await api.getBlocks(13, endSlotInclusive: 14).execute(transport: transport)
        _ = try await api.getBlocksWithLimit(15, limit: 2).execute(transport: transport)
        _ = try await api.getClusterNodes().execute(transport: transport)

        let methods = try await recorder.payloads().map { try XCTUnwrap($0.value(for: "method")) }
        XCTAssertEqual(methods, [
            .string("getAccountInfo"),
            .string("getBalance"),
            .string("getBlock"),
            .string("getBlockCommitment"),
            .string("getBlockHeight"),
            .string("getBlockProduction"),
            .string("getBlockTime"),
            .string("getBlocks"),
            .string("getBlocksWithLimit"),
            .string("getClusterNodes"),
        ])

        let blockPayload = try await recorder.payload(at: 2)
        XCTAssertEqual(blockPayload.value(for: "params"), .array([.number(10), .object([RpcJsonObjectMember("commitment", .string("confirmed"))])]))
    }

    func testRemainingMethodsProduceExpectedJsonRpcMethodNamesAndParams() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let secondAddress = try Addresses.address("Sysvar1111111111111111111111111111111111111")
        let api = createSolanaRpcApi()
        let recorder = RpcTransportRecorder(response: .object([RpcJsonObjectMember("result", .null)]))
        let transport: RpcTransport = { config in await recorder.transport(config) }
        let config = RpcJsonValue.object([("commitment", .string("confirmed"))])
        let filter = RpcJsonValue.object([("programId", .string(secondAddress.rawValue))])

        _ = try await api.getEpochInfo().execute(transport: transport)
        _ = try await api.getEpochSchedule().execute(transport: transport)
        _ = try await api.getFeeForMessage("message", config: config).execute(transport: transport)
        _ = try await api.getFirstAvailableBlock().execute(transport: transport)
        _ = try await api.getGenesisHash().execute(transport: transport)
        _ = try await api.getHealth().execute(transport: transport)
        _ = try await api.getHighestSnapshotSlot().execute(transport: transport)
        _ = try await api.getIdentity().execute(transport: transport)
        _ = try await api.getInflationGovernor().execute(transport: transport)
        _ = try await api.getInflationRate().execute(transport: transport)
        _ = try await api.getInflationReward([address, secondAddress], config: config).execute(transport: transport)
        _ = try await api.getLargestAccounts(config: config).execute(transport: transport)
        _ = try await api.getLatestBlockhash().execute(transport: transport)
        _ = try await api.getLeaderSchedule().execute(transport: transport)
        _ = try await api.getLeaderSchedule(nil, config: config).execute(transport: transport)
        _ = try await api.getLeaderSchedule(99, config: config).execute(transport: transport)
        _ = try await api.getMaxRetransmitSlot().execute(transport: transport)
        _ = try await api.getMaxShredInsertSlot().execute(transport: transport)
        _ = try await api.getMinimumBalanceForRentExemption(128, config: config).execute(transport: transport)
        _ = try await api.getMultipleAccounts([address, secondAddress], config: config).execute(transport: transport)
        _ = try await api.getProgramAccounts(address, config: config).execute(transport: transport)
        _ = try await api.getRecentPerformanceSamples(limit: 2).execute(transport: transport)
        _ = try await api.getRecentPrioritizationFees([address, secondAddress]).execute(transport: transport)
        _ = try await api.getSignatureStatuses(["sig1", "sig2"], config: config).execute(transport: transport)
        _ = try await api.getSignaturesForAddress(address, config: config).execute(transport: transport)
        _ = try await api.getSlot().execute(transport: transport)
        _ = try await api.getSlotLeader().execute(transport: transport)
        _ = try await api.getSlotLeaders(7, limit: 3).execute(transport: transport)
        _ = try await api.getStakeMinimumDelegation().execute(transport: transport)
        _ = try await api.getSupply(config: config).execute(transport: transport)
        _ = try await api.getTokenAccountBalance(address, config: config).execute(transport: transport)
        _ = try await api.getTokenAccountsByDelegate(address, filter: filter, config: config).execute(transport: transport)
        _ = try await api.getTokenAccountsByOwner(address, filter: filter, config: config).execute(transport: transport)
        _ = try await api.getTokenLargestAccounts(address, config: config).execute(transport: transport)
        _ = try await api.getTokenSupply(address, config: config).execute(transport: transport)
        _ = try await api.getTransaction("txsig", config: config).execute(transport: transport)
        _ = try await api.getTransactionCount().execute(transport: transport)
        _ = try await api.getVersion().execute(transport: transport)
        _ = try await api.getVoteAccounts(config: config).execute(transport: transport)
        _ = try await api.isBlockhashValid("11111111111111111111111111111111", config: config).execute(transport: transport)
        _ = try await api.minimumLedgerSlot().execute(transport: transport)
        _ = try await api.requestAirdrop(address, lamports: 5, config: config).execute(transport: transport)
        _ = try await api.sendTransaction("wire", config: config).execute(transport: transport)
        _ = try await api.simulateTransaction("wire", config: config).execute(transport: transport)

        let methods = try await recorder.payloads().map { try XCTUnwrap($0.value(for: "method")) }
        XCTAssertEqual(methods, [
            .string("getEpochInfo"),
            .string("getEpochSchedule"),
            .string("getFeeForMessage"),
            .string("getFirstAvailableBlock"),
            .string("getGenesisHash"),
            .string("getHealth"),
            .string("getHighestSnapshotSlot"),
            .string("getIdentity"),
            .string("getInflationGovernor"),
            .string("getInflationRate"),
            .string("getInflationReward"),
            .string("getLargestAccounts"),
            .string("getLatestBlockhash"),
            .string("getLeaderSchedule"),
            .string("getLeaderSchedule"),
            .string("getLeaderSchedule"),
            .string("getMaxRetransmitSlot"),
            .string("getMaxShredInsertSlot"),
            .string("getMinimumBalanceForRentExemption"),
            .string("getMultipleAccounts"),
            .string("getProgramAccounts"),
            .string("getRecentPerformanceSamples"),
            .string("getRecentPrioritizationFees"),
            .string("getSignatureStatuses"),
            .string("getSignaturesForAddress"),
            .string("getSlot"),
            .string("getSlotLeader"),
            .string("getSlotLeaders"),
            .string("getStakeMinimumDelegation"),
            .string("getSupply"),
            .string("getTokenAccountBalance"),
            .string("getTokenAccountsByDelegate"),
            .string("getTokenAccountsByOwner"),
            .string("getTokenLargestAccounts"),
            .string("getTokenSupply"),
            .string("getTransaction"),
            .string("getTransactionCount"),
            .string("getVersion"),
            .string("getVoteAccounts"),
            .string("isBlockhashValid"),
            .string("minimumLedgerSlot"),
            .string("requestAirdrop"),
            .string("sendTransaction"),
            .string("simulateTransaction"),
        ])

        let inflationRewardParams = try await recorder.payload(at: 10).value(for: "params")
        let currentLeaderScheduleParams = try await recorder.payload(at: 14).value(for: "params")
        let leaderScheduleParams = try await recorder.payload(at: 15).value(for: "params")
        let recentPerformanceParams = try await recorder.payload(at: 21).value(for: "params")
        let slotLeadersParams = try await recorder.payload(at: 27).value(for: "params")
        let tokenDelegateParams = try await recorder.payload(at: 31).value(for: "params")
        let minimumLedgerSlotParams = try await recorder.payload(at: 40).value(for: "params")
        let requestAirdropParams = try await recorder.payload(at: 41).value(for: "params")

        XCTAssertEqual(inflationRewardParams, .array([.array([.string(address.rawValue), .string(secondAddress.rawValue)]), config]))
        XCTAssertEqual(currentLeaderScheduleParams, .array([.null, config]))
        XCTAssertEqual(leaderScheduleParams, .array([.number(99), config]))
        XCTAssertEqual(recentPerformanceParams, .array([.number(2)]))
        XCTAssertEqual(slotLeadersParams, .array([.number(7), .number(3)]))
        XCTAssertEqual(tokenDelegateParams, .array([.string(address.rawValue), filter, config]))
        XCTAssertEqual(minimumLedgerSlotParams, .array([]))
        XCTAssertEqual(requestAirdropParams, .array([.string(address.rawValue), .number(5), config]))
    }

    func testDefaultCommitmentIsAppliedAtConfiguredOptionPositions() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi(RequestTransformerConfig(defaultCommitment: .confirmed))
        let recorder = RpcTransportRecorder(response: .object([RpcJsonObjectMember("result", .null)]))
        let transport: RpcTransport = { config in await recorder.transport(config) }
        let filter = RpcJsonValue.object([("programId", .string(address.rawValue))])

        _ = try await api.getEpochInfo().execute(transport: transport)
        _ = try await api.getFeeForMessage("message").execute(transport: transport)
        _ = try await api.getTokenAccountsByOwner(address, filter: filter).execute(transport: transport)
        _ = try await api.sendTransaction("wire").execute(transport: transport)
        _ = try await api.getEpochSchedule().execute(transport: transport)

        let epochInfoParams = try await recorder.payload(at: 0).value(for: "params")
        let feeForMessageParams = try await recorder.payload(at: 1).value(for: "params")
        let tokenAccountsParams = try await recorder.payload(at: 2).value(for: "params")
        let sendTransactionParams = try await recorder.payload(at: 3).value(for: "params")
        let epochScheduleParams = try await recorder.payload(at: 4).value(for: "params")

        XCTAssertEqual(epochInfoParams, .array([.object([RpcJsonObjectMember("commitment", .string("confirmed"))])]))
        XCTAssertEqual(feeForMessageParams, .array([.string("message"), .object([RpcJsonObjectMember("commitment", .string("confirmed"))])]))
        XCTAssertEqual(
            tokenAccountsParams,
            .array([.string(address.rawValue), filter, .object([RpcJsonObjectMember("commitment", .string("confirmed"))])])
        )
        XCTAssertEqual(sendTransactionParams, .array([.string("wire"), .object([RpcJsonObjectMember("preflightCommitment", .string("confirmed"))])]))
        XCTAssertEqual(epochScheduleParams, .array([]))
    }

    func testAllowedNumericKeypathsPreserveParsedAccountNumbers() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi()
        let recorder = RpcTransportRecorder(
            response: .object([
                RpcJsonObjectMember(
                    "result",
                    .object([
                        RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .number(9))])),
                        RpcJsonObjectMember(
                            "value",
                            .object([
                                RpcJsonObjectMember(
                                    "data",
                                    .object([
                                        RpcJsonObjectMember(
                                            "parsed",
                                            .object([
                                                RpcJsonObjectMember(
                                                    "info",
                                                    .object([
                                                        RpcJsonObjectMember("decimals", .number(6)),
                                                        RpcJsonObjectMember("amount", .number(123)),
                                                        RpcJsonObjectMember(
                                                            "votes",
                                                            .array([
                                                                .object([RpcJsonObjectMember("confirmationCount", .number(32))]),
                                                            ])
                                                        ),
                                                    ])
                                                ),
                                            ])
                                        ),
                                    ])
                                ),
                            ])
                        ),
                    ])
                ),
            ])
        )

        let result = try await api.getAccountInfo(address).execute(transport: { config in await recorder.transport(config) })

        XCTAssertEqual(result.value(at: [.key("value"), .key("data"), .key("parsed"), .key("info"), .key("decimals")]), .number(6))
        XCTAssertEqual(
            result.value(at: [.key("value"), .key("data"), .key("parsed"), .key("info"), .key("votes"), .index(0), .key("confirmationCount")]),
            .number(32)
        )
        XCTAssertEqual(result.value(at: [.key("value"), .key("data"), .key("parsed"), .key("info"), .key("amount")]), .bigint("123"))
        XCTAssertEqual(result.value(at: [.key("context"), .key("slot")]), .bigint("9"))
    }

    func testAllowedNumericKeypathsPreserveGetBlockSmallNumbers() async throws {
        let api = createSolanaRpcApi()
        let recorder = RpcTransportRecorder(
            response: .object([
                RpcJsonObjectMember(
                    "result",
                    .object([
                        RpcJsonObjectMember(
                            "transactions",
                            .array([
                                .object([
                                    RpcJsonObjectMember(
                                        "meta",
                                        .object([
                                            RpcJsonObjectMember("fee", .number(5000)),
                                            RpcJsonObjectMember(
                                                "preTokenBalances",
                                                .array([
                                                    .object([
                                                        RpcJsonObjectMember("accountIndex", .number(0)),
                                                        RpcJsonObjectMember(
                                                            "uiTokenAmount",
                                                            .object([RpcJsonObjectMember("decimals", .number(6))])
                                                        ),
                                                    ]),
                                                ])
                                            ),
                                        ])
                                    ),
                                    RpcJsonObjectMember(
                                        "transaction",
                                        .object([
                                            RpcJsonObjectMember(
                                                "message",
                                                .object([
                                                    RpcJsonObjectMember(
                                                        "header",
                                                        .object([RpcJsonObjectMember("numRequiredSignatures", .number(2))])
                                                    ),
                                                    RpcJsonObjectMember(
                                                        "instructions",
                                                        .array([
                                                            .object([
                                                                RpcJsonObjectMember("accounts", .array([.number(4)])),
                                                                RpcJsonObjectMember("programIdIndex", .number(3)),
                                                                RpcJsonObjectMember("stackHeight", .number(1)),
                                                            ]),
                                                        ])
                                                    ),
                                                ])
                                            ),
                                        ])
                                    ),
                                ]),
                            ])
                        ),
                        RpcJsonObjectMember(
                            "rewards",
                            .array([
                                .object([
                                    RpcJsonObjectMember("commission", .number(10)),
                                    RpcJsonObjectMember("lamports", .number(123)),
                                ]),
                            ])
                        ),
                    ])
                ),
            ])
        )

        let result = try await api.getBlock(1).execute(transport: { config in await recorder.transport(config) })

        XCTAssertEqual(result.value(at: [.key("transactions"), .index(0), .key("meta"), .key("preTokenBalances"), .index(0), .key("accountIndex")]), .number(0))
        XCTAssertEqual(
            result.value(at: [.key("transactions"), .index(0), .key("meta"), .key("preTokenBalances"), .index(0), .key("uiTokenAmount"), .key("decimals")]),
            .number(6)
        )
        XCTAssertEqual(
            result.value(at: [.key("transactions"), .index(0), .key("transaction"), .key("message"), .key("header"), .key("numRequiredSignatures")]),
            .number(2)
        )
        XCTAssertEqual(
            result.value(at: [.key("transactions"), .index(0), .key("transaction"), .key("message"), .key("instructions"), .index(0), .key("programIdIndex")]),
            .number(3)
        )
        XCTAssertEqual(result.value(at: [.key("transactions"), .index(0), .key("meta"), .key("fee")]), .bigint("5000"))
        XCTAssertEqual(result.value(at: [.key("rewards"), .index(0), .key("commission")]), .number(10))
        XCTAssertEqual(result.value(at: [.key("rewards"), .index(0), .key("lamports")]), .bigint("123"))
    }

    func testAllowedNumericKeypathsPreserveRemainingSmallNumbers() async throws {
        let address = try Addresses.address("11111111111111111111111111111111")
        let api = createSolanaRpcApi()

        let tokenSupply = try await api.getTokenSupply(address).execute(transport: transportReturningResult(
            .object([
                RpcJsonObjectMember("value", .object([
                    RpcJsonObjectMember("amount", .number(1000)),
                    RpcJsonObjectMember("decimals", .number(6)),
                    RpcJsonObjectMember("uiAmount", .number(0.001)),
                ])),
            ])
        ))
        XCTAssertEqual(tokenSupply.value(at: [.key("value"), .key("amount")]), .bigint("1000"))
        XCTAssertEqual(tokenSupply.value(at: [.key("value"), .key("decimals")]), .number(6))
        XCTAssertEqual(tokenSupply.value(at: [.key("value"), .key("uiAmount")]), .number(0.001))

        let programAccounts = try await api.getProgramAccounts(address).execute(transport: transportReturningResult(
            .array([
                .object([
                    RpcJsonObjectMember("account", .object([
                        RpcJsonObjectMember("data", .object([
                            RpcJsonObjectMember("parsed", .object([
                                RpcJsonObjectMember("info", .object([
                                    RpcJsonObjectMember("decimals", .number(9)),
                                    RpcJsonObjectMember("amount", .number(500)),
                                ])),
                            ])),
                        ])),
                    ])),
                ]),
            ])
        ))
        XCTAssertEqual(programAccounts.value(at: [.index(0), .key("account"), .key("data"), .key("parsed"), .key("info"), .key("decimals")]), .number(9))
        XCTAssertEqual(programAccounts.value(at: [.index(0), .key("account"), .key("data"), .key("parsed"), .key("info"), .key("amount")]), .bigint("500"))

        let transaction = try await api.getTransaction("sig").execute(transport: transportReturningResult(
            .object([
                RpcJsonObjectMember("meta", .object([
                    RpcJsonObjectMember("preTokenBalances", .array([
                        .object([
                            RpcJsonObjectMember("accountIndex", .number(1)),
                            RpcJsonObjectMember("uiTokenAmount", .object([RpcJsonObjectMember("decimals", .number(6))])),
                        ]),
                    ])),
                    RpcJsonObjectMember("fee", .number(5000)),
                ])),
                RpcJsonObjectMember("transaction", .object([
                    RpcJsonObjectMember("message", .object([
                        RpcJsonObjectMember("addressTableLookups", .array([
                            .object([RpcJsonObjectMember("readonlyIndexes", .array([.number(2)]))]),
                        ])),
                        RpcJsonObjectMember("instructions", .array([
                            .object([RpcJsonObjectMember("programIdIndex", .number(4))]),
                        ])),
                    ])),
                ])),
            ])
        ))
        XCTAssertEqual(transaction.value(at: [.key("meta"), .key("preTokenBalances"), .index(0), .key("accountIndex")]), .number(1))
        XCTAssertEqual(transaction.value(at: [.key("meta"), .key("preTokenBalances"), .index(0), .key("uiTokenAmount"), .key("decimals")]), .number(6))
        XCTAssertEqual(transaction.value(at: [.key("transaction"), .key("message"), .key("addressTableLookups"), .index(0), .key("readonlyIndexes"), .index(0)]), .number(2))
        XCTAssertEqual(transaction.value(at: [.key("transaction"), .key("message"), .key("instructions"), .index(0), .key("programIdIndex")]), .number(4))
        XCTAssertEqual(transaction.value(at: [.key("meta"), .key("fee")]), .bigint("5000"))

        let simulate = try await api.simulateTransaction("wire").execute(transport: transportReturningResult(
            .object([
                RpcJsonObjectMember("value", .object([
                    RpcJsonObjectMember("loadedAccountsDataSize", .number(64)),
                    RpcJsonObjectMember("unitsConsumed", .number(12345)),
                    RpcJsonObjectMember("innerInstructions", .array([
                        .object([
                            RpcJsonObjectMember("index", .number(0)),
                            RpcJsonObjectMember("instructions", .array([
                                .object([RpcJsonObjectMember("stackHeight", .number(1))]),
                            ])),
                        ]),
                    ])),
                ])),
            ])
        ))
        XCTAssertEqual(simulate.value(at: [.key("value"), .key("loadedAccountsDataSize")]), .number(64))
        XCTAssertEqual(simulate.value(at: [.key("value"), .key("innerInstructions"), .index(0), .key("index")]), .number(0))
        XCTAssertEqual(simulate.value(at: [.key("value"), .key("innerInstructions"), .index(0), .key("instructions"), .index(0), .key("stackHeight")]), .number(1))
        XCTAssertEqual(simulate.value(at: [.key("value"), .key("unitsConsumed")]), .bigint("12345"))

        let version = try await api.getVersion().execute(transport: transportReturningResult(.object([RpcJsonObjectMember("feature-set", .number(42))])))
        XCTAssertEqual(version.value(at: [.key("feature-set")]), .number(42))
    }
}

private func transportReturningResult(_ result: RpcJsonValue) -> RpcTransport {
    { _ in .object([RpcJsonObjectMember("result", result)]) }
}

private actor RpcTransportRecorder {
    private var capturedPayloads: [RpcJsonValue] = []
    private let response: RpcJsonValue

    init(response: RpcJsonValue) {
        self.response = response
    }

    func transport(_ config: RpcTransportConfig) -> RpcJsonValue {
        capturedPayloads.append(config.payload)
        return response
    }

    func payloads() -> [RpcJsonValue] {
        capturedPayloads
    }

    func payload(at index: Int) throws -> RpcJsonValue {
        try XCTUnwrap(capturedPayloads[safe: index])
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension RpcJsonValue {
    func value(at path: [TestJsonPathComponent]) -> RpcJsonValue? {
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

private enum TestJsonPathComponent {
    case key(String)
    case index(Int)
}
