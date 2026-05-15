import XCTest
@testable import RpcGraphql

final class RpcGraphqlLoaderFactoryTests: XCTestCase {
    func testAccountLoaderUsesMultipleAccountsWithDefaultCommitment() async {
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "value": .list([
                    accountValue(data: .list([.string("AQIDBA=="), .string("base64")])),
                    accountValue(data: .list([.string("BQYHCA=="), .string("base64")])),
                ]),
            ]),
        ])
        let context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(
            transport: recorder.transport(),
            config: RpcGraphqlConfig(maxDataSliceByteRange: 200, maxMultipleAccountsBatchSize: 100)
        )

        let results = await context.loaders.account.loadMany([
            RpcGraphqlAccountLoaderArguments(
                address: "Address111111111111111111111111111111111",
                commitment: nil,
                dataSlice: nil,
                encoding: .base64,
                minContextSlot: nil
            ),
            RpcGraphqlAccountLoaderArguments(
                address: "Address222222222222222222222222222222222",
                commitment: nil,
                dataSlice: nil,
                encoding: .base64,
                minContextSlot: nil
            ),
        ])

        let calls = await recorder.calls()
        XCTAssertEqual(calls.map(\.method), ["getMultipleAccounts"])
        XCTAssertEqual(
            calls.first?.params,
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
        XCTAssertEqual(accountData(from: results[0]), .encoded("AQIDBA==", encoding: .base64))
        XCTAssertEqual(accountData(from: results[1]), .encoded("BQYHCA==", encoding: .base64))
    }

    func testAccountLoaderSlicesCallbacksFromMergedFetch() async {
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "value": accountValue(data: .list([.string("AQIDBAUGBwg="), .string("base64")])),
            ]),
        ])
        let context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport())
        let address = "Address111111111111111111111111111111111"

        let results = await context.loaders.account.loadMany([
            RpcGraphqlAccountLoaderArguments(
                address: address,
                commitment: .confirmed,
                dataSlice: RpcGraphqlDataSlice(length: 4, offset: 0),
                encoding: .base64,
                minContextSlot: nil
            ),
            RpcGraphqlAccountLoaderArguments(
                address: address,
                commitment: .confirmed,
                dataSlice: RpcGraphqlDataSlice(length: 4, offset: 2),
                encoding: .base64,
                minContextSlot: nil
            ),
        ])

        let calls = await recorder.calls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(
            calls.first?.params.last,
            .object([
                "commitment": .string("confirmed"),
                "dataSlice": .object([
                    "length": .int(6),
                    "offset": .int(0),
                ]),
                "encoding": .string("base64"),
            ])
        )
        XCTAssertEqual(accountData(from: results[0]), .encoded("AQIDBA==", encoding: .base64))
        XCTAssertEqual(accountData(from: results[1]), .encoded("AwQFBg==", encoding: .base64))
    }

    func testTransactionLoaderDefaultsOrphanEncodingToBase64() async {
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "slot": .uint(42),
                "transaction": .list([.string("opaque"), .string("base64")]),
            ]),
        ])
        let context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport())

        let results = await context.loaders.transaction.loadMany([
            RpcGraphqlTransactionLoaderArguments(
                signature: "Signature1111111111111111111111111111111111111111111111111111111111111",
                commitment: nil,
                encoding: nil
            ),
        ])

        let calls = await recorder.calls()
        XCTAssertEqual(calls.map(\.method), ["getTransaction"])
        XCTAssertEqual(
            calls.first?.params.last,
            .object([
                "commitment": .string("confirmed"),
                "encoding": .string("base64"),
            ])
        )
        guard case let .value(transaction?) = results[0] else {
            XCTFail("Expected a transaction value")
            return
        }
        XCTAssertEqual(RpcGraphqlValueAccess.uint(RpcGraphqlValueAccess.object(transaction)?["slot"]), 42)
    }

    func testResolveAccountMergesEncodedAndParsedPayloads() async {
        let address = "Address111111111111111111111111111111111"
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "value": accountValue(data: .list([.string("AQIDBA=="), .string("base64")])),
            ]),
            .object([
                "value": accountValue(data: .object([
                    "parsed": .object([
                        "info": .object(["supply": .string("1000")]),
                        "type": .string("mint"),
                    ]),
                    "program": .string("spl-token"),
                    "programId": .string("TokenProgram11111111111111111111111111111"),
                ])),
            ]),
        ])
        let context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport())
        let info = RpcGraphqlResolveInfo(selections: [
            .field(
                name: "data",
                arguments: ["encoding": .enumCase("BASE_64")],
                selections: []
            ),
            .inlineFragment(typeCondition: "MintAccount", selections: [
                .field(name: "supply", arguments: [:], selections: []),
            ]),
        ])

        let result = await RpcGraphqlResolvers.resolveAccount(
            address: address,
            context: context,
            info: info
        )

        XCTAssertEqual(result?.fields["supply"], .string("1000"))
        XCTAssertEqual(result?.jsonParsedConfigs["accountType"], "mint")
        XCTAssertEqual(
            RpcGraphqlResolvers.resolveAccountData(parent: result, encoding: .base64),
            "AQIDBA=="
        )
    }

    func testClientExecutesTypedRootAccountQuery() async {
        let address = "Address111111111111111111111111111111111"
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "value": accountValue(data: .list([.string("AQIDBA=="), .string("base64")])),
            ]),
        ])
        let context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport())
        let client = RpcGraphqlClient(context: context)
        let info = RpcGraphqlResolveInfo(selections: [
            .field(
                name: "data",
                arguments: ["encoding": .enumCase("BASE_64")],
                selections: []
            ),
        ])

        let result = await client.query([
            .account(
                alias: "account",
                address: address,
                commitment: nil,
                minContextSlot: nil,
                info: info
            ),
        ])

        let account = RpcGraphqlValueAccess.object(result.data["account"])
        let encodedData = RpcGraphqlValueAccess.object(account?["encodedData"])
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(encodedData?.values.first, .string("AQIDBA=="))
    }

    func testClientExecutesSourceAccountQuery() async {
        let address = "Address111111111111111111111111111111111"
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "value": accountValue(data: .list([.string("AQIDBA=="), .string("base64")])),
            ]),
        ])
        let client = RpcGraphqlClient(context: RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport()))

        let result = await client.query(
            source: """
            query testQuery($address: Address!) {
                account(address: $address) {
                    address
                    lamports
                    data(encoding: BASE_64)
                }
            }
            """,
            variableValues: ["address": .string(address)]
        )

        let account = RpcGraphqlValueAccess.object(result.data["account"])
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(account?["address"], .string(address))
        XCTAssertEqual(account?["lamports"], .uint(1))
        XCTAssertEqual(account?["data"], .string("AQIDBA=="))
        XCTAssertEqual(calls.map(\.method), ["getAccountInfo"])
        XCTAssertEqual(
            calls.first?.params.last,
            .object([
                "commitment": .string("confirmed"),
                "encoding": .string("base64"),
            ])
        )
    }

    func testClientExecutesSourceAccountQueryWithFragmentAndSliceVariables() async {
        let address = "Address111111111111111111111111111111111"
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "value": accountValue(data: .list([.string("AwQFBg=="), .string("base64")])),
            ]),
        ])
        let client = RpcGraphqlClient(context: RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport()))

        let result = await client.query(
            source: """
            query testQuery($address: Address!, $encoding: AccountEncoding!, $slice: DataSlice) {
                account(address: $address) {
                    ...AccountFields
                    data(encoding: $encoding, dataSlice: $slice)
                }
            }

            fragment AccountFields on Account {
                address
                space
            }
            """,
            variableValues: [
                "address": .string(address),
                "encoding": .enumCase("BASE_64"),
                "slice": .object(["length": .int(4), "offset": .int(2)]),
            ]
        )

        let account = RpcGraphqlValueAccess.object(result.data["account"])
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(account?["address"], .string(address))
        XCTAssertEqual(account?["space"], .uint(8))
        XCTAssertEqual(account?["data"], .string("AwQFBg=="))
        XCTAssertEqual(
            calls.first?.params.last,
            .object([
                "commitment": .string("confirmed"),
                "dataSlice": .object([
                    "length": .int(4),
                    "offset": .int(2),
                ]),
                "encoding": .string("base64"),
            ])
        )
    }

    func testClientExecutesNestedOwnerProgramSourceQuery() async {
        let address = "Address111111111111111111111111111111111"
        let owner = "Owner11111111111111111111111111111111111"
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object(["value": accountValue(data: .list([.string("AQIDBA=="), .string("base64")]))]),
            .object([
                "value": .object([
                    "data": .list([.string("BQYHCA=="), .string("base64")]),
                    "executable": .bool(true),
                    "lamports": .uint(2),
                    "owner": .string("Loader111111111111111111111111111111111"),
                    "space": .uint(16),
                ]),
            ]),
        ])
        let client = RpcGraphqlClient(context: RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport()))

        let result = await client.query(
            source: """
            {
                account(address: "\(address)") {
                    ownerProgram {
                        address
                        executable
                        lamports
                    }
                }
            }
            """
        )

        let account = RpcGraphqlValueAccess.object(result.data["account"])
        let ownerProgram = RpcGraphqlValueAccess.object(account?["ownerProgram"])
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(calls.map(\.method), ["getAccountInfo", "getAccountInfo"])
        XCTAssertEqual(ownerProgram?["address"], .string(owner))
        XCTAssertEqual(ownerProgram?["executable"], .bool(true))
        XCTAssertEqual(ownerProgram?["lamports"], .uint(2))
    }

    func testClientExecutesSourceProgramAccountsQuery() async {
        let programAddress = "Program111111111111111111111111111111111"
        let accountAddress = "Account111111111111111111111111111111111"
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .list([
                .object([
                    "account": accountValue(data: .list([.string("AQIDBA=="), .string("base64")])),
                    "pubkey": .string(accountAddress),
                ]),
            ]),
        ])
        let client = RpcGraphqlClient(context: RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport()))

        let result = await client.query(
            source: """
            query testQuery($programAddress: Address!, $filters: [ProgramAccountsDataSizeFilter!]) {
                programAccounts(programAddress: $programAddress, dataSizeFilters: $filters) {
                    address
                    executable
                    data(encoding: BASE_64)
                }
            }
            """,
            variableValues: [
                "programAddress": .string(programAddress),
                "filters": .list([.object(["dataSize": .int(8)])]),
            ]
        )

        let accounts = RpcGraphqlValueAccess.list(result.data["programAccounts"])
        let account = RpcGraphqlValueAccess.object(accounts?.first)
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(account?["address"], .string(accountAddress))
        XCTAssertEqual(account?["executable"], .bool(false))
        XCTAssertEqual(account?["data"], .string("AQIDBA=="))
        XCTAssertEqual(calls.map(\.method), ["getProgramAccounts"])
        XCTAssertEqual(
            calls.first?.params,
            [
                .string(programAddress),
                .object([
                    "commitment": .string("confirmed"),
                    "encoding": .string("base64"),
                    "filters": .list([.object(["dataSize": .int(8)])]),
                ]),
            ]
        )
    }

    func testClientExecutesSourceTransactionDataQueryWithAlias() async {
        let signature = "Signature1111111111111111111111111111111111111111111111111111111111111"
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "blockTime": .uint(1_699_617_771),
                "slot": .uint(257_316_391),
                "transaction": .list([.string("wire-base64"), .string("base64")]),
            ]),
        ])
        let client = RpcGraphqlClient(context: RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport()))

        let result = await client.query(
            source: """
            query testQuery($signature: Signature!) {
                transaction(signature: $signature) {
                    slot
                    encoded: data(encoding: BASE_64)
                }
            }
            """,
            variableValues: ["signature": .string(signature)]
        )

        let transaction = RpcGraphqlValueAccess.object(result.data["transaction"])
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(transaction?["slot"], .uint(257_316_391))
        XCTAssertEqual(transaction?["encoded"], .string("wire-base64"))
        XCTAssertEqual(calls.map(\.method), ["getTransaction"])
        XCTAssertEqual(
            calls.first?.params,
            [
                .string(signature),
                .object([
                    "commitment": .string("confirmed"),
                    "encoding": .string("base64"),
                ]),
            ]
        )
    }

    func testClientExecutesSourceBlockTransactionDataQuery() async {
        let recorder = RpcGraphqlTransportRecorder(responses: [
            .object([
                "blockHeight": .uint(257_317_189),
                "blockhash": .string("Blockhash11111111111111111111111111111111"),
                "transactions": .list([
                    .object([
                        "slot": .uint(257_316_391),
                        "transaction": .list([.string("block-wire-base64"), .string("base64")]),
                    ]),
                ]),
            ]),
        ])
        let client = RpcGraphqlClient(context: RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: recorder.transport()))

        let result = await client.query(
            source: """
            query testQuery($slot: Slot!) {
                block(slot: $slot) {
                    blockhash
                    transactions {
                        data(encoding: BASE_64)
                    }
                }
            }
            """,
            variableValues: ["slot": .uint(257_317_189)]
        )

        let block = RpcGraphqlValueAccess.object(result.data["block"])
        let transactions = RpcGraphqlValueAccess.list(block?["transactions"])
        let transaction = RpcGraphqlValueAccess.object(transactions?.first)
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(block?["blockhash"], .string("Blockhash11111111111111111111111111111111"))
        XCTAssertEqual(transaction?["data"], .string("block-wire-base64"))
        XCTAssertEqual(calls.map(\.method), ["getBlock"])
        XCTAssertEqual(
            calls.first?.params,
            [
                .uint(257_317_189),
                .object([
                    "commitment": .string("confirmed"),
                    "encoding": .string("base64"),
                    "maxSupportedTransactionVersion": .int(0),
                    "transactionDetails": .string("full"),
                ]),
            ]
        )
    }
}

private struct RpcGraphqlRecordedCall: Sendable, Equatable {
    var method: String
    var params: [RpcGraphqlArgumentValue]
}

private actor RpcGraphqlTransportRecorder {
    private var recordedCalls: [RpcGraphqlRecordedCall] = []
    private var responses: [RpcGraphqlArgumentValue]

    init(responses: [RpcGraphqlArgumentValue]) {
        self.responses = responses
    }

    nonisolated func transport() -> RpcGraphqlRpcTransport {
        RpcGraphqlRpcTransport { method, params in
            try await self.send(method: method, params: params)
        }
    }

    func calls() -> [RpcGraphqlRecordedCall] {
        recordedCalls
    }

    private func send(method: String, params: [RpcGraphqlArgumentValue]) throws -> RpcGraphqlArgumentValue {
        recordedCalls.append(RpcGraphqlRecordedCall(method: method, params: params))
        guard !responses.isEmpty else {
            throw RpcGraphqlRpcError.missingResult
        }
        return responses.removeFirst()
    }
}

private func accountValue(data: RpcGraphqlArgumentValue) -> RpcGraphqlArgumentValue {
    .object([
        "data": data,
        "executable": .bool(false),
        "lamports": .uint(1),
        "owner": .string("Owner11111111111111111111111111111111111"),
        "space": .uint(8),
    ])
}

private func accountData(
    from result: RpcGraphqlLoadResult<RpcGraphqlAccountRecord?>
) -> RpcGraphqlAccountData? {
    guard case let .value(account?) = result else {
        return nil
    }
    return account.data
}
