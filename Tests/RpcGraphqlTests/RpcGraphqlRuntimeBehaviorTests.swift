import XCTest
@testable import RpcGraphql

final class RpcGraphqlRuntimeBehaviorTests: XCTestCase {
    func testAccountQueryCombinesEncodedSlicesParsedFieldsAndTypeName() async {
        let address = "Account111111111111111111111111111111111"
        let recorder = RpcGraphqlRuntimeTransportRecorder(responses: [
            .object([
                "value": rpcGraphqlRuntimeAccountValue(data: .string("base58-data"), lamports: 100),
            ]),
            .object([
                "value": rpcGraphqlRuntimeAccountValue(data: .list([.string("AwQFBg=="), .string("base64")]), lamports: 100),
            ]),
            .object([
                "value": rpcGraphqlRuntimeAccountValue(data: .list([.string("zstd-data"), .string("base64+zstd")]), lamports: 100),
            ]),
            .object([
                "value": rpcGraphqlRuntimeAccountValue(
                    data: .object([
                        "parsed": .object([
                            "info": .object([
                                "decimals": .int(6),
                                "supply": .string("1000000"),
                            ]),
                            "type": .string("mint"),
                        ]),
                        "program": .string("spl-token-2022"),
                    ]),
                    lamports: 100
                ),
            ]),
        ])
        let client = createSolanaRpcGraphQL(transport: recorder.transport())

        let result = await client.query(
            source: """
            {
                account(address: "\(address)") {
                    __typename
                    lamports
                    raw: data(encoding: BASE_58)
                    sliced: data(encoding: BASE_64, dataSlice: { offset: 2, length: 4 })
                    zipped: data(encoding: BASE_64_ZSTD)
                    ... on MintAccount {
                        decimals
                        supply
                    }
                }
            }
            """
        )

        let account = rpcGraphqlRuntimeObject(result.data["account"])
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(account?["__typename"], .string("MintAccount"))
        XCTAssertEqual(account?["lamports"], .uint(100))
        XCTAssertEqual(account?["raw"], .string("base58-data"))
        XCTAssertEqual(account?["sliced"], .string("AwQFBg=="))
        XCTAssertEqual(account?["zipped"], .string("zstd-data"))
        XCTAssertEqual(account?["decimals"], .int(6))
        XCTAssertEqual(account?["supply"], .string("1000000"))
        XCTAssertEqual(calls.map(\.method), ["getAccountInfo", "getAccountInfo", "getAccountInfo", "getAccountInfo"])
        XCTAssertEqual(calls[0].params.last, .object(["commitment": .string("confirmed"), "encoding": .string("base58")]))
        XCTAssertEqual(
            calls[1].params.last,
            .object([
                "commitment": .string("confirmed"),
                "dataSlice": .object(["length": .int(4), "offset": .int(2)]),
                "encoding": .string("base64"),
            ])
        )
        XCTAssertEqual(calls[2].params.last, .object(["commitment": .string("confirmed"), "encoding": .string("base64+zstd")]))
        XCTAssertEqual(calls[3].params.last, .object(["commitment": .string("confirmed"), "encoding": .string("jsonParsed")]))
    }

    func testProgramAccountsLoaderMergesSlicesAndKeepsZstdRequestsSeparate() {
        let program = "Program111111111111111111111111111111111"
        let requests = [
            RpcGraphqlLoadRequest(
                key: program,
                arguments: rpcGraphqlRuntimeProgramArguments(program: program)
            ),
            RpcGraphqlLoadRequest(
                key: program,
                arguments: rpcGraphqlRuntimeProgramArguments(
                    program: program,
                    dataSlice: RpcGraphqlDataSlice(length: 4, offset: 0),
                    encoding: .base64
                )
            ),
            RpcGraphqlLoadRequest(
                key: program,
                arguments: rpcGraphqlRuntimeProgramArguments(
                    program: program,
                    dataSlice: RpcGraphqlDataSlice(length: 4, offset: 5),
                    encoding: .base64
                )
            ),
            RpcGraphqlLoadRequest(
                key: program,
                arguments: rpcGraphqlRuntimeProgramArguments(
                    program: program,
                    dataSlice: RpcGraphqlDataSlice(length: 4, offset: 5),
                    encoding: .base64Zstd
                )
            ),
        ]

        let fetches = RpcGraphqlCoalescer.coalesceDataSlices(requests, maxDataSliceByteRange: 9)

        XCTAssertEqual(fetches.count, 2)
        XCTAssertEqual(fetches[0].arguments.encoding, .base64)
        XCTAssertEqual(fetches[0].arguments.dataSlice, RpcGraphqlDataSlice(length: 9, offset: 0))
        XCTAssertEqual(fetches[0].callbacksByKey[program]?.map(\.requestIndex), [1, 2, 0])
        XCTAssertEqual(fetches[1].arguments.encoding, .base64Zstd)
        XCTAssertEqual(fetches[1].arguments.dataSlice, RpcGraphqlDataSlice(length: 4, offset: 5))
        XCTAssertEqual(fetches[1].callbacksByKey[program]?.map(\.requestIndex), [3])
    }

    func testBlockAndTransactionPlannersIncludeBaseParsedAndEncodedPayloadShapes() {
        let transactionInfo = RpcGraphqlResolveInfo(selections: [
            .field(name: "data", arguments: ["encoding": .enumCase("BASE_64")], selections: []),
            .field(name: "data", arguments: ["encoding": .enumCase("BASE_58")], selections: []),
            .field(name: "message", arguments: [:], selections: [
                .field(name: "instructions", arguments: [:], selections: []),
            ]),
            .field(name: "meta", arguments: [:], selections: [
                .field(name: "computeUnitsConsumed", arguments: [:], selections: []),
            ]),
        ])
        let blockInfo = RpcGraphqlResolveInfo(selections: [
            .field(name: "signatures", arguments: [:], selections: []),
            .field(name: "transactions", arguments: [:], selections: transactionInfo.selections),
        ])

        let transactionArguments = RpcGraphqlResolvers.transactionLoaderArguments(
            signature: "Signature1111111111111111111111111111111111111111111111111111111111111",
            info: transactionInfo
        )
        let blockArguments = RpcGraphqlResolvers.blockLoaderArguments(slot: 123, info: blockInfo)

        XCTAssertEqual(transactionArguments.map(\.encoding), [nil, .base64, .base58, .jsonParsed])
        XCTAssertEqual(blockArguments.count, 6)
        XCTAssertEqual(blockArguments.map(\.transactionDetails), [nil, .signatures, .full, .full, .full, .full])
        XCTAssertEqual(blockArguments.map(\.encoding), [nil, nil, nil, .base64, .base58, .jsonParsed])
        XCTAssertEqual(blockArguments.dropFirst(2).map(\.maxSupportedTransactionVersion), [0, 0, 0, 0])
    }

    func testProgramAccountsQueryAppliesMultipleFiltersAndSlicesRenderedData() async {
        let program = "Program111111111111111111111111111111111"
        let account = "Account111111111111111111111111111111111"
        let recorder = RpcGraphqlRuntimeTransportRecorder(responses: [
            .list([
                .object([
                    "account": rpcGraphqlRuntimeAccountValue(data: .list([.string("AwQFBg=="), .string("base64")]), lamports: 2),
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
                    dataSizeFilters: [{ dataSize: 8 }]
                    memcmpFilters: [
                        { offset: 0, bytes: $bytes, encoding: "base64" }
                        { offset: 4, bytes: "memo" }
                    ]
                ) {
                    address
                    lamports
                    data(encoding: BASE_64, dataSlice: { offset: 2, length: 4 })
                }
            }
            """,
            variableValues: [
                "program": .string(program),
                "bytes": .string("AQID"),
            ]
        )

        let accounts = rpcGraphqlRuntimeList(result.data["programAccounts"])
        let rendered = rpcGraphqlRuntimeObject(accounts?.first)
        let calls = await recorder.calls()
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(rendered?["address"], .string(account))
        XCTAssertEqual(rendered?["lamports"], .uint(2))
        XCTAssertEqual(rendered?["data"], .string("AwQFBg=="))
        XCTAssertEqual(
            calls.first?.params.last,
            .object([
                "commitment": .string("confirmed"),
                "dataSlice": .object(["length": .int(4), "offset": .int(2)]),
                "encoding": .string("base64"),
                "filters": .list([
                    .object(["dataSize": .int(8)]),
                    .object(["memcmp": .object(["bytes": .string("AQID"), "encoding": .string("base64"), "offset": .int(0)])]),
                    .object(["memcmp": .object(["bytes": .string("memo"), "offset": .int(4)])]),
                ]),
            ])
        )
    }
}

private struct RpcGraphqlRuntimeRecordedCall: Sendable, Equatable {
    var method: String
    var params: [RpcGraphqlArgumentValue]
}

private actor RpcGraphqlRuntimeTransportRecorder {
    private var recordedCalls: [RpcGraphqlRuntimeRecordedCall] = []
    private var responses: [RpcGraphqlArgumentValue]

    init(responses: [RpcGraphqlArgumentValue]) {
        self.responses = responses
    }

    nonisolated func transport() -> RpcGraphqlRpcTransport {
        RpcGraphqlRpcTransport { method, params in
            try await self.send(method: method, params: params)
        }
    }

    func calls() -> [RpcGraphqlRuntimeRecordedCall] {
        recordedCalls
    }

    private func send(method: String, params: [RpcGraphqlArgumentValue]) throws -> RpcGraphqlArgumentValue {
        recordedCalls.append(RpcGraphqlRuntimeRecordedCall(method: method, params: params))
        guard !responses.isEmpty else {
            throw RpcGraphqlRpcError.missingResult
        }
        return responses.removeFirst()
    }
}

private func rpcGraphqlRuntimeProgramArguments(
    program: String,
    dataSlice: RpcGraphqlDataSlice? = nil,
    encoding: RpcGraphqlAccountEncoding? = nil
) -> RpcGraphqlProgramAccountsLoaderArguments {
    RpcGraphqlProgramAccountsLoaderArguments(
        programAddress: program,
        commitment: .confirmed,
        dataSlice: dataSlice,
        encoding: encoding,
        filters: nil,
        minContextSlot: nil
    )
}

private func rpcGraphqlRuntimeAccountValue(
    data: RpcGraphqlArgumentValue,
    lamports: UInt64,
    owner: String = "Owner11111111111111111111111111111111111"
) -> RpcGraphqlArgumentValue {
    .object([
        "data": data,
        "executable": .bool(false),
        "lamports": .uint(lamports),
        "owner": .string(owner),
        "space": .uint(8),
    ])
}

private func rpcGraphqlRuntimeObject(_ value: RpcGraphqlArgumentValue?) -> [String: RpcGraphqlArgumentValue]? {
    if case let .object(fields)? = value {
        return fields
    }
    return nil
}

private func rpcGraphqlRuntimeList(_ value: RpcGraphqlArgumentValue?) -> [RpcGraphqlArgumentValue]? {
    if case let .list(values)? = value {
        return values
    }
    return nil
}
