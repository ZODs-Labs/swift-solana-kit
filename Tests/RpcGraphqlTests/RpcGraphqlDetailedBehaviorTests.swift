import XCTest
@testable import RpcGraphql

final class RpcGraphqlDetailedBehaviorTests: XCTestCase {
    func testAccountLoaderSplitsLargeBatchesIntoOrderedMultipleAccountCalls() async {
        let recorder = RpcGraphqlDetailedTransportRecorder(responses: [
            .object([
                "value": .list([
                    rpcGraphqlDetailedAccountValue(data: .list([.string("AQID"), .string("base64")])),
                    rpcGraphqlDetailedAccountValue(data: .list([.string("BAUG"), .string("base64")])),
                ]),
            ]),
            .object([
                "value": .list([
                    rpcGraphqlDetailedAccountValue(data: .list([.string("BwgJ"), .string("base64")])),
                    rpcGraphqlDetailedAccountValue(data: .list([.string("CgsM"), .string("base64")])),
                ]),
            ]),
        ])
        let context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(
            transport: recorder.transport(),
            config: RpcGraphqlConfig(maxDataSliceByteRange: 200, maxMultipleAccountsBatchSize: 2)
        )

        _ = await context.loaders.account.loadMany([
            rpcGraphqlDetailedAccountArguments(address: "Address333333333333333333333333333333333"),
            rpcGraphqlDetailedAccountArguments(address: "Address111111111111111111111111111111111"),
            rpcGraphqlDetailedAccountArguments(address: "Address444444444444444444444444444444444"),
            rpcGraphqlDetailedAccountArguments(address: "Address222222222222222222222222222222222"),
        ])

        let calls = await recorder.calls()
        XCTAssertEqual(calls.map(\.method), ["getMultipleAccounts", "getMultipleAccounts"])
        XCTAssertEqual(
            calls[0].params,
            [
                .list([
                    .string("Address111111111111111111111111111111111"),
                    .string("Address222222222222222222222222222222222"),
                ]),
                .object([
                    "commitment": .string("confirmed"),
                    "encoding": .string("base64"),
                ]),
            ]
        )
        XCTAssertEqual(
            calls[1].params,
            [
                .list([
                    .string("Address333333333333333333333333333333333"),
                    .string("Address444444444444444444444444444444444"),
                ]),
                .object([
                    "commitment": .string("confirmed"),
                    "encoding": .string("base64"),
                ]),
            ]
        )
    }

    func testAccountLoaderSeparatesDifferentCommitmentsForTheSameAccount() async {
        let address = "Address111111111111111111111111111111111"
        let recorder = RpcGraphqlDetailedTransportRecorder(responses: [
            .object(["value": rpcGraphqlDetailedAccountValue(data: .list([.string("AQID"), .string("base64")]))]),
            .object(["value": rpcGraphqlDetailedAccountValue(data: .list([.string("BAUG"), .string("base64")]))]),
        ])
        let context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport())

        _ = await context.loaders.account.loadMany([
            rpcGraphqlDetailedAccountArguments(address: address, commitment: nil),
            rpcGraphqlDetailedAccountArguments(address: address, commitment: .finalized),
        ])

        let calls = await recorder.calls()
        XCTAssertEqual(calls.map(\.method), ["getAccountInfo", "getAccountInfo"])
        XCTAssertEqual(calls[0].params, [.string(address), .object(["commitment": .string("confirmed"), "encoding": .string("base64")])])
        XCTAssertEqual(calls[1].params, [.string(address), .object(["commitment": .string("finalized"), "encoding": .string("base64")])])
    }

    func testDataSliceCoalescingMergesWithinLimitSplitsBeyondLimitAndKeepsZstdSeparate() {
        let address = "Address111111111111111111111111111111111"
        let requests = [
            RpcGraphqlLoadRequest(
                key: address,
                arguments: rpcGraphqlDetailedAccountArguments(
                    address: address,
                    dataSlice: RpcGraphqlDataSlice(length: 4, offset: 0),
                    encoding: .base64
                )
            ),
            RpcGraphqlLoadRequest(
                key: address,
                arguments: rpcGraphqlDetailedAccountArguments(
                    address: address,
                    dataSlice: RpcGraphqlDataSlice(length: 4, offset: 4),
                    encoding: .base64
                )
            ),
            RpcGraphqlLoadRequest(
                key: address,
                arguments: rpcGraphqlDetailedAccountArguments(
                    address: address,
                    dataSlice: RpcGraphqlDataSlice(length: 4, offset: 30),
                    encoding: .base64
                )
            ),
            RpcGraphqlLoadRequest(
                key: address,
                arguments: rpcGraphqlDetailedAccountArguments(
                    address: address,
                    dataSlice: RpcGraphqlDataSlice(length: 2, offset: 2),
                    encoding: .base64Zstd
                )
            ),
        ]

        let fetches = RpcGraphqlCoalescer.coalesceDataSlices(requests, maxDataSliceByteRange: 8)

        XCTAssertEqual(fetches.count, 3)
        XCTAssertEqual(fetches[0].arguments.dataSlice, RpcGraphqlDataSlice(length: 8, offset: 0))
        XCTAssertEqual(fetches[0].callbacksByKey[address]?.map(\.requestIndex), [0, 1])
        XCTAssertEqual(fetches[1].arguments.dataSlice, RpcGraphqlDataSlice(length: 4, offset: 30))
        XCTAssertEqual(fetches[2].arguments.encoding, .base64Zstd)
        XCTAssertEqual(fetches[2].arguments.dataSlice, RpcGraphqlDataSlice(length: 2, offset: 2))
    }

    func testBlockQueriesChooseTransactionDetailAndEncodingConfigs() async {
        let recorder = RpcGraphqlDetailedTransportRecorder(responses: [
            .object(["blockhash": .string("Blockhash11111111111111111111111111111111")]),
            .object([
                "blockhash": .string("Blockhash22222222222222222222222222222222"),
                "signatures": .list([.string("Signature1111111111111111111111111111111111111111111111111111111111111")]),
            ]),
            .object([
                "transactions": .list([
                    .object(["transaction": .list([.string("wire-base58"), .string("base58")])]),
                ]),
            ]),
        ])
        let client = createSolanaRpcGraphQL(transport: recorder.transport())

        _ = await client.query(source: "{ block(slot: 511226) { blockhash } }")
        _ = await client.query(source: "{ block(slot: 511226) { signatures } }")
        let transactionResult = await client.query(
            source: "{ block(slot: 511226) { transactions { data(encoding: BASE_58) } } }"
        )

        let calls = await recorder.calls()
        let block = rpcGraphqlDetailedObject(transactionResult.data["block"])
        let transactions = rpcGraphqlDetailedList(block?["transactions"])
        let transaction = rpcGraphqlDetailedObject(transactions?.first)
        XCTAssertEqual(transaction?.values.first, .string("wire-base58"))
        XCTAssertEqual(calls.map(\.method), ["getBlock", "getBlock", "getBlock"])
        XCTAssertEqual(
            calls[0].params,
            [
                .uint(511_226),
                .object([
                    "commitment": .string("confirmed"),
                    "maxSupportedTransactionVersion": .int(0),
                    "transactionDetails": .string("none"),
                ]),
            ]
        )
        XCTAssertEqual(
            calls[1].params,
            [
                .uint(511_226),
                .object([
                    "commitment": .string("confirmed"),
                    "maxSupportedTransactionVersion": .int(0),
                    "transactionDetails": .string("signatures"),
                ]),
            ]
        )
        XCTAssertEqual(
            calls[2].params,
            [
                .uint(511_226),
                .object([
                    "commitment": .string("confirmed"),
                    "encoding": .string("base58"),
                    "maxSupportedTransactionVersion": .int(0),
                    "transactionDetails": .string("full"),
                ]),
            ]
        )
    }

    func testBlockSlotInputsAcceptNumbersStringsAndVariables() async {
        let cases: [(String, [String: RpcGraphqlArgumentValue])] = [
            ("{ block(slot: 511226) { blockhash } }", [:]),
            ("{ block(slot: \"511226\") { blockhash } }", [:]),
            ("query testQuery($block: Slot!) { block(slot: $block) { blockhash } }", ["block": .int(511_226)]),
            ("query testQuery($block: Slot!) { block(slot: $block) { blockhash } }", ["block": .uint(511_226)]),
            ("query testQuery($block: Slot!) { block(slot: $block) { blockhash } }", ["block": .string("511226")]),
        ]

        for (source, variables) in cases {
            let recorder = RpcGraphqlDetailedTransportRecorder(responses: [
                .object(["blockhash": .string("Blockhash11111111111111111111111111111111")]),
            ])
            let client = createSolanaRpcGraphQL(transport: recorder.transport())

            let result = await client.query(source: source, variableValues: variables)
            let calls = await recorder.calls()

            XCTAssertEqual(result.errors, [])
            XCTAssertEqual(calls.first?.params.first, .uint(511_226))
        }
    }

    func testSourceQueriesReportMissingArgumentsUnsupportedRootsAndParseErrors() async {
        let recorder = RpcGraphqlDetailedTransportRecorder(responses: [])
        let client = createSolanaRpcGraphQL(transport: recorder.transport())

        let missing = await client.query(source: "{ account { address } }")
        let unsupported = await client.query(source: "{ identity { gossip } }")
        let malformed = await client.query(source: "query { account(address: \"abc\") { address ")

        XCTAssertEqual(missing.data["account"], .null)
        XCTAssertTrue(missing.errors.contains("Missing GraphQL argument address"))
        XCTAssertEqual(unsupported.data["identity"], .null)
        XCTAssertTrue(unsupported.errors.contains("Unsupported GraphQL root field identity"))
        XCTAssertFalse(malformed.errors.isEmpty)
    }

    func testAddressOnlyAccountSelectionsAvoidTransportCalls() async {
        let address = "Address111111111111111111111111111111111"
        let recorder = RpcGraphqlDetailedTransportRecorder(responses: [])
        let client = createSolanaRpcGraphQL(transport: recorder.transport())

        let result = await client.query(source: "{ account(address: \"\(address)\") { address } }")
        let account = rpcGraphqlDetailedObject(result.data["account"])
        let calls = await recorder.calls()

        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(account?["address"], .string(address))
        XCTAssertEqual(calls, [])
    }

    func testNestedOwnerAddressOnlySelectionsDoNotFetchTheOwnerAccount() async {
        let address = "Address111111111111111111111111111111111"
        let owner = "Owner11111111111111111111111111111111111"
        let recorder = RpcGraphqlDetailedTransportRecorder(responses: [
            .object([
                "value": rpcGraphqlDetailedAccountValue(
                    data: .list([.string("AQID"), .string("base64")]),
                    owner: owner
                ),
            ]),
        ])
        let client = createSolanaRpcGraphQL(transport: recorder.transport())

        let result = await client.query(source: "{ account(address: \"\(address)\") { ownerProgram { address } } }")
        let account = rpcGraphqlDetailedObject(result.data["account"])
        let ownerProgram = rpcGraphqlDetailedObject(account?["ownerProgram"])
        let calls = await recorder.calls()

        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(ownerProgram?["address"], .string(owner))
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.method, "getAccountInfo")
    }

    func testProgramAccountsSourceQueryBuildsFiltersAndMinContextSlot() async {
        let program = "Program111111111111111111111111111111111"
        let account = "Account111111111111111111111111111111111"
        let recorder = RpcGraphqlDetailedTransportRecorder(responses: [
            .list([
                .object([
                    "account": rpcGraphqlDetailedAccountValue(data: .list([.string("AQID"), .string("base64")])),
                    "pubkey": .string(account),
                ]),
            ]),
        ])
        let client = createSolanaRpcGraphQL(transport: recorder.transport())

        let result = await client.query(
            source: """
            query testQuery($program: Address!, $bytes: String!) {
                programAccounts(
                    programAddress: $program
                    commitment: FINALIZED
                    minContextSlot: "99"
                    dataSizeFilters: [{ dataSize: 165 }]
                    memcmpFilters: [{ offset: 32, bytes: $bytes, encoding: "base64" }]
                ) {
                    address
                    data(encoding: BASE_64)
                }
            }
            """,
            variableValues: [
                "program": .string(program),
                "bytes": .string(account),
            ]
        )

        let accounts = rpcGraphqlDetailedList(result.data["programAccounts"])
        let renderedAccount = rpcGraphqlDetailedObject(accounts?.first)
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(renderedAccount?["address"], .string(account))
        XCTAssertEqual(renderedAccount?["data"], .string("AQID"))
        XCTAssertEqual(
            calls.first?.params,
            [
                .string(program),
                .object([
                    "commitment": .string("finalized"),
                    "encoding": .string("base64"),
                    "filters": .list([
                        .object(["dataSize": .int(165)]),
                        .object([
                            "memcmp": .object([
                                "bytes": .string(account),
                                "encoding": .string("base64"),
                                "offset": .int(32),
                            ]),
                        ]),
                    ]),
                    "minContextSlot": .uint(99),
                ]),
            ]
        )
    }
}

private struct RpcGraphqlDetailedRecordedCall: Sendable, Equatable {
    var method: String
    var params: [RpcGraphqlArgumentValue]
}

private actor RpcGraphqlDetailedTransportRecorder {
    private var recordedCalls: [RpcGraphqlDetailedRecordedCall] = []
    private var responses: [RpcGraphqlArgumentValue]

    init(responses: [RpcGraphqlArgumentValue]) {
        self.responses = responses
    }

    nonisolated func transport() -> RpcGraphqlRpcTransport {
        RpcGraphqlRpcTransport { method, params in
            try await self.send(method: method, params: params)
        }
    }

    func calls() -> [RpcGraphqlDetailedRecordedCall] {
        recordedCalls
    }

    private func send(method: String, params: [RpcGraphqlArgumentValue]) throws -> RpcGraphqlArgumentValue {
        recordedCalls.append(RpcGraphqlDetailedRecordedCall(method: method, params: params))
        guard !responses.isEmpty else {
            throw RpcGraphqlRpcError.missingResult
        }
        return responses.removeFirst()
    }
}

private func rpcGraphqlDetailedAccountArguments(
    address: String,
    commitment: RpcGraphqlCommitment? = nil,
    dataSlice: RpcGraphqlDataSlice? = nil,
    encoding: RpcGraphqlAccountEncoding? = .base64,
    minContextSlot: RpcGraphqlSlot? = nil
) -> RpcGraphqlAccountLoaderArguments {
    RpcGraphqlAccountLoaderArguments(
        address: address,
        commitment: commitment,
        dataSlice: dataSlice,
        encoding: encoding,
        minContextSlot: minContextSlot
    )
}

private func rpcGraphqlDetailedAccountValue(
    data: RpcGraphqlArgumentValue,
    owner: String = "Owner11111111111111111111111111111111111"
) -> RpcGraphqlArgumentValue {
    .object([
        "data": data,
        "executable": .bool(false),
        "lamports": .uint(1),
        "owner": .string(owner),
        "space": .uint(8),
    ])
}

private func rpcGraphqlDetailedObject(_ value: RpcGraphqlArgumentValue?) -> [String: RpcGraphqlArgumentValue]? {
    if case let .object(fields)? = value {
        return fields
    }
    return nil
}

private func rpcGraphqlDetailedList(_ value: RpcGraphqlArgumentValue?) -> [RpcGraphqlArgumentValue]? {
    if case let .list(values)? = value {
        return values
    }
    return nil
}
