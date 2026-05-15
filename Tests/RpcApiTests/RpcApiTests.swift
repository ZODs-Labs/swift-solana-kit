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
