import Foundation
import Kit
import XCTest

final class KitTests: XCTestCase {
    func testKitReExportsUmbrellaEntryPoints() throws {
        let request = RpcRequest(methodName: "getHealth", params: .array([]))
        let message = createRpcMessage(request)
        let response: RpcResponse<RpcJsonValue> = .string("ok")
        let program = try address("11111111111111111111111111111111")
        let instruction = Instruction(programAddress: program)
        let transactionMessage = appendTransactionMessageInstruction(
            instruction,
            createTransactionMessage(version: .legacy)
        )

        _ = createSolanaRpcApi()
        _ = createSolanaRpcSubscriptionsApi()

        XCTAssertEqual(message.method, "getHealth")
        XCTAssertEqual(response, .string("ok"))
        XCTAssertEqual(transactionMessage.instructions, [instruction])
    }

    func testRentExemptionUsesPinnedConstantsAndSaturatesOverflow() {
        XCTAssertEqual(getMinimumBalanceForRentExemption(space: 0), 890_880)
        XCTAssertEqual(getMinimumBalanceForRentExemption(space: 1), 897_840)
        XCTAssertEqual(getMinimumBalanceForRentExemption(space: 165), 2_039_280)
        XCTAssertEqual(getMinimumBalanceForRentExemption(space: UInt64.max), UInt64.max)
    }

    func testSendTransactionWithoutConfirmingBuildsBase64RpcEnvelope() async throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let transaction = Transaction(
            messageBytes: Data([1, 0, 0, 0]),
            signatures: SignaturesMap([(feePayer, nil)])
        )
        let expectedWireTransaction = try getBase64EncodedWireTransaction(transaction)
        let recorder = RpcCallRecorder(responses: [
            .object([
                ("jsonrpc", .string("2.0")),
                ("id", .string("1")),
                ("result", .string("not-a-valid-base58-signature")),
            ]),
        ])
        let rpc = createSolanaRpcFromTransport { config in
            try await recorder.transport(config)
        }

        let send = sendTransactionWithoutConfirmingFactory(SendTransactionWithoutConfirmingFactoryConfig(rpc: rpc))
        try await send(
            transaction,
            SendTransactionConfig(
                commitment: .confirmed,
                maxRetries: 5,
                minContextSlot: 7,
                preflightCommitment: .processed,
                skipPreflight: true
            )
        )

        let recordedPayload = await recorder.payload(at: 0)
        let payload = try XCTUnwrap(recordedPayload)
        let params = try rpcParams(from: payload)
        XCTAssertEqual(payload.value(for: "method"), .string("sendTransaction"))
        XCTAssertEqual(params.first, .string(expectedWireTransaction))
        let config = try XCTUnwrap(params.dropFirst().first)
        XCTAssertEqual(config.value(for: "encoding"), .string("base64"))
        XCTAssertEqual(config.value(for: "maxRetries"), .number(5))
        XCTAssertEqual(config.value(for: "minContextSlot"), .number(7))
        XCTAssertEqual(config.value(for: "preflightCommitment"), .string("processed"))
        XCTAssertEqual(config.value(for: "skipPreflight"), .bool(true))
    }

    func testEstimateComputeUnitLimitAcceptsJsonNumberUnitsConsumed() async throws {
        let rpc = rawRpc(responses: [
            .object([
                ("value", .object([
                    ("err", .null),
                    ("unitsConsumed", .number(123)),
                ])),
            ]),
        ])
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let message = setTransactionMessageLifetimeUsingBlockhash(
            BlockhashLifetimeConstraint(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 42),
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
        )

        let estimate = estimateComputeUnitLimitFactory(EstimateComputeUnitLimitFactoryConfig(rpc: rpc.rpc))
        let units = try await estimate(message, EstimateComputeUnitLimitConfig(commitment: .confirmed, minContextSlot: 9))

        let recordedPayload = await rpc.recorder.payload(at: 0)
        let payload = try XCTUnwrap(recordedPayload)
        let params = try rpcParams(from: payload)
        let config = try XCTUnwrap(params.dropFirst().first)
        XCTAssertEqual(units, 123)
        XCTAssertEqual(payload.value(for: "method"), .string("simulateTransaction"))
        XCTAssertEqual(config.value(for: "encoding"), .string("base64"))
        XCTAssertEqual(config.value(for: "commitment"), .string("confirmed"))
        XCTAssertEqual(config.value(for: "minContextSlot"), .bigint("9"))
        XCTAssertEqual(config.value(for: "replaceRecentBlockhash"), .bool(true))
        XCTAssertEqual(config.value(for: "sigVerify"), .bool(false))
    }

    func testFetchAddressesForLookupTablesUsesJsonParsedAccounts() async throws {
        let lookupTable = try address("AddressLookupTab1e1111111111111111111111111")
        let firstAddress = try address("11111111111111111111111111111111")
        let secondAddress = try address("22222222222222222222222222222222222222222222")
        let rpc = rawRpc(responses: [
            .object([
                ("value", .array([
                    .object([
                        ("data", .object([
                            ("program", .string("address-lookup-table")),
                            ("parsed", .object([
                                ("type", .string("lookupTable")),
                                ("info", .object([
                                    ("addresses", .array([
                                        .string(firstAddress.rawValue),
                                        .string(secondAddress.rawValue),
                                    ])),
                                ])),
                            ])),
                        ])),
                        ("executable", .bool(false)),
                        ("lamports", .number(42)),
                        ("owner", .string(firstAddress.rawValue)),
                        ("space", .number(56)),
                    ]),
                ])),
            ]),
        ])

        let addresses = try await fetchAddressesForLookupTables(lookupTableAddresses: [lookupTable], rpc: rpc.rpc)

        let recordedPayload = await rpc.recorder.payload(at: 0)
        let payload = try XCTUnwrap(recordedPayload)
        let params = try rpcParams(from: payload)
        let config = try XCTUnwrap(params.dropFirst().first)
        XCTAssertEqual(addresses[lookupTable], [firstAddress, secondAddress])
        XCTAssertEqual(payload.value(for: "method"), .string("getMultipleAccounts"))
        XCTAssertEqual(config.value(for: "encoding"), .string("jsonParsed"))
    }

    func testAsyncGeneratorAbortsChildSignalsWhenConsumerStops() async throws {
        let probe = SlotTrackingProbe()
        let sequence = createAsyncGeneratorWithInitialValueAndSlotTracking(
            InitialValueAndSlotTrackingConfig(
                abortSignal: AbortSignal(),
                rpcRequest: { signal in
                    await probe.recordRpcSignal(signal)
                    return SolanaRpcResponse(context: SolanaRpcContext(slot: 1), value: 10)
                },
                rpcSubscriptionRequest: { signal in
                    await probe.recordSubscriptionSignal(signal)
                    return AsyncThrowingStream<SolanaRpcResponse<Int>, any Error> { _ in }
                },
                rpcSubscriptionValueMapper: { $0 },
                rpcValueMapper: { $0 }
            )
        )
        var iterator: InitialValueAndSlotTrackingAsyncSequence<Int, Int, Int>.Iterator? = sequence.makeAsyncIterator()

        let first = try await iterator?.next()
        iterator = nil
        await waitUntil { await probe.childSignalsAborted() }

        XCTAssertEqual(first, SolanaRpcResponse(context: SolanaRpcContext(slot: 1), value: 10))
        let childSignalsAborted = await probe.childSignalsAborted()
        XCTAssertTrue(childSignalsAborted)
    }
}

private actor RpcCallRecorder {
    private var payloads: [RpcJsonValue] = []
    private var responses: [RpcJsonValue]

    init(responses: [RpcJsonValue]) {
        self.responses = responses
    }

    func transport(_ config: RpcTransportConfig) throws -> RpcJsonValue {
        payloads.append(config.payload)
        guard !responses.isEmpty else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return responses.removeFirst()
    }

    func payload(at index: Int) -> RpcJsonValue? {
        guard payloads.indices.contains(index) else {
            return nil
        }
        return payloads[index]
    }
}

private actor SlotTrackingProbe {
    private var rpcSignal: AbortSignal?
    private var subscriptionSignal: AbortSignal?

    func recordRpcSignal(_ signal: AbortSignal) {
        rpcSignal = signal
    }

    func recordSubscriptionSignal(_ signal: AbortSignal) {
        subscriptionSignal = signal
    }

    func childSignalsAborted() -> Bool {
        (rpcSignal?.aborted ?? false) && (subscriptionSignal?.aborted ?? false)
    }
}

private func rawRpc(responses: [RpcJsonValue]) -> (rpc: SolanaRpc, recorder: RpcCallRecorder) {
    let recorder = RpcCallRecorder(responses: responses)
    let rpc = SolanaRpc(
        api: SolanaRpcApi(api: createJsonRpcApi()),
        transport: { config in
            try await recorder.transport(config)
        }
    )
    return (rpc, recorder)
}

private func rpcParams(
    from payload: RpcJsonValue,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> [RpcJsonValue] {
    let paramsValue = try XCTUnwrap(payload.value(for: "params"), file: file, line: line)
    guard case let .array(params) = paramsValue else {
        XCTFail("Expected RPC params array", file: file, line: line)
        return []
    }
    return params
}

private func waitUntil(_ predicate: @escaping @Sendable () async -> Bool) async {
    for _ in 0 ..< 100 {
        if await predicate() {
            return
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}
