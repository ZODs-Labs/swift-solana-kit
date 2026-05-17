import Foundation
import Kit
import os
import Subscribable
import XCTest

final class KitRuntimeBehaviorTests: XCTestCase {
    func testAirdropSendsRequestConfirmsSignatureAndReturnsSignature() async throws {
        let recipient = try address("22222222222222222222222222222222222222222222")
        let recorder = KitRuntimeRpcRecorder(responses: [
            .response(.string("airdrop-signature")),
            .response(.object([
                ("value", .array([
                    .object([
                        ("confirmationStatus", .string("finalized")),
                        ("err", .null),
                    ]),
                ])),
            ])),
        ])
        let airdrop = airdropFactory(
            AirdropFactoryConfig(rpc: recorder.rpc, rpcSubscriptions: kitRuntimeIdleSubscriptions())
        )

        let signature = try await airdrop(
            AirdropConfig(commitment: .finalized, lamports: 500, recipientAddress: recipient)
        )

        let requestPayloadValue = await recorder.payload(at: 0)
        let requestPayload = try XCTUnwrap(requestPayloadValue)
        let requestParams = try kitRuntimeRpcParams(from: requestPayload)
        let requestConfig = try XCTUnwrap(requestParams.dropFirst(2).first)
        XCTAssertEqual(signature.rawValue, "airdrop-signature")
        XCTAssertEqual(requestPayload.kitRuntimeValue(for: "method"), .string("requestAirdrop"))
        XCTAssertEqual(requestParams.first, .string(recipient.rawValue))
        XCTAssertEqual(requestParams.dropFirst().first, .bigint("500"))
        XCTAssertEqual(requestConfig.kitRuntimeValue(for: "commitment"), .string("finalized"))

        let statusPayloadValue = await recorder.payload(at: 1)
        let statusPayload = try XCTUnwrap(statusPayloadValue)
        let statusParams = try kitRuntimeRpcParams(from: statusPayload)
        XCTAssertEqual(statusPayload.kitRuntimeValue(for: "method"), .string("getSignatureStatuses"))
        XCTAssertEqual(statusParams.first, .array([.string("airdrop-signature")]))
    }

    func testAirdropForwardsAbortToPendingRequestAndConfirmationLookup() async throws {
        let recipient = try address("22222222222222222222222222222222222222222222")
        let requestRecorder = KitRuntimeRpcRecorder(responses: [.waitForAbort])
        let requestAbortSignal = AbortSignal()
        let requestAirdrop = airdropFactory(
            AirdropFactoryConfig(rpc: requestRecorder.rpc, rpcSubscriptions: kitRuntimeIdleSubscriptions())
        )
        let requestTask = Task {
            try await requestAirdrop(
                AirdropConfig(
                    abortSignal: requestAbortSignal,
                    commitment: .finalized,
                    lamports: 1,
                    recipientAddress: recipient
                )
            )
        }
        await kitRuntimeWaitUntil { await requestRecorder.callCount() == 1 }
        let requestSignalAbortedBeforeCallerAbort = await requestRecorder.signalAborted(at: 0)
        XCTAssertFalse(requestSignalAbortedBeforeCallerAbort)
        requestAbortSignal.abort(reason: KitRuntimeFailure("request stopped"))
        await kitRuntimeWaitUntil { await requestRecorder.signalAborted(at: 0) }
        requestTask.cancel()

        let confirmationRecorder = KitRuntimeRpcRecorder(responses: [
            .response(.string("airdrop-signature")),
            .waitForAbort,
        ])
        let confirmationAbortSignal = AbortSignal()
        let confirmationAirdrop = airdropFactory(
            AirdropFactoryConfig(rpc: confirmationRecorder.rpc, rpcSubscriptions: kitRuntimeIdleSubscriptions())
        )
        let confirmationTask = Task {
            try await confirmationAirdrop(
                AirdropConfig(
                    abortSignal: confirmationAbortSignal,
                    commitment: .finalized,
                    lamports: 1,
                    recipientAddress: recipient
                )
            )
        }
        await kitRuntimeWaitUntil { await confirmationRecorder.callCount() == 2 }
        let confirmationSignalAbortedBeforeCallerAbort = await confirmationRecorder.signalAborted(at: 1)
        XCTAssertFalse(confirmationSignalAbortedBeforeCallerAbort)
        confirmationAbortSignal.abort(reason: KitRuntimeFailure("confirmation stopped"))
        await kitRuntimeWaitUntil { await confirmationRecorder.signalAborted(at: 1) }
        confirmationTask.cancel()
    }

    func testSendTransactionConfigUsesBase64AndCommitmentSpecificPreflightRules() async throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let transaction = Transaction(
            messageBytes: Data([1, 0, 0, 0]),
            signatures: SignaturesMap([(feePayer, nil)])
        )
        let cases: [(Commitment, Commitment?, RpcJsonValue?)] = [
            (.processed, nil, .string("processed")),
            (.confirmed, nil, .string("confirmed")),
            (.finalized, nil, nil),
            (.processed, .finalized, .string("finalized")),
            (.finalized, .processed, .string("processed")),
        ]

        for (commitment, explicitPreflight, expectedPreflight) in cases {
            let recorder = KitRuntimeRpcRecorder(responses: [.response(.string("transaction-signature"))])
            let send = sendTransactionWithoutConfirmingFactory(
                SendTransactionWithoutConfirmingFactoryConfig(rpc: recorder.rpc)
            )
            try await send(
                transaction,
                SendTransactionConfig(
                    commitment: commitment,
                    maxRetries: 42,
                    minContextSlot: 123,
                    preflightCommitment: explicitPreflight,
                    skipPreflight: false
                )
            )

            let payloadValue = await recorder.payload(at: 0)
            let payload = try XCTUnwrap(payloadValue)
            let params = try kitRuntimeRpcParams(from: payload)
            let config = try XCTUnwrap(params.dropFirst().first)
            XCTAssertEqual(payload.kitRuntimeValue(for: "method"), .string("sendTransaction"))
            XCTAssertEqual(config.kitRuntimeValue(for: "encoding"), .string("base64"))
            XCTAssertEqual(config.kitRuntimeValue(for: "maxRetries"), .bigint("42"))
            XCTAssertEqual(config.kitRuntimeValue(for: "minContextSlot"), .bigint("123"))
            XCTAssertEqual(config.kitRuntimeValue(for: "skipPreflight"), .bool(false))
            XCTAssertEqual(config.kitRuntimeValue(for: "preflightCommitment"), expectedPreflight)
        }
    }

    func testAsyncGeneratorYieldsNewerValuesDropsOlderValuesBuffersAndCompletes() async throws {
        let rpc = KitRuntimeRpcEndpoint<Int>()
        let subscription = KitRuntimeSubscriptionEndpoint<Int>()
        let sequence = createAsyncGeneratorWithInitialValueAndSlotTracking(
            InitialValueAndSlotTrackingConfig(
                abortSignal: AbortSignal(),
                rpcRequest: { signal in try await rpc.request(signal: signal) },
                rpcSubscriptionRequest: { signal in try await subscription.request(signal: signal) },
                rpcSubscriptionValueMapper: { $0 * 10 },
                rpcValueMapper: { $0 }
            )
        )
        let iterator = sequence.makeAsyncIterator()
        let first = Task { try await iterator.next() }
        await kitRuntimeWaitUntil { await subscription.requestCount() == 1 }

        await subscription.yield(slot: 100, value: 1, at: 0)
        let firstValue = try await first.value
        XCTAssertEqual(firstValue, SolanaRpcResponse(context: SolanaRpcContext(slot: 100), value: 10))

        await subscription.yield(slot: 300, value: 3, at: 0)
        await subscription.yield(slot: 200, value: 2, at: 0)
        await rpc.resolve(slot: 50, value: 5, at: 0)
        await subscription.finish(at: 0)

        let secondValue = try await iterator.next()
        let thirdValue = try await iterator.next()
        let fourthValue = try await iterator.next()
        XCTAssertEqual(secondValue, SolanaRpcResponse(context: SolanaRpcContext(slot: 300), value: 30))
        XCTAssertNil(thirdValue)
        XCTAssertNil(fourthValue)
    }

    func testAsyncGeneratorThrowsAfterYieldAndAbortsChildSignals() async throws {
        let rpc = KitRuntimeRpcEndpoint<Int>()
        let subscription = KitRuntimeSubscriptionEndpoint<Int>()
        let sequence = createAsyncGeneratorWithInitialValueAndSlotTracking(
            InitialValueAndSlotTrackingConfig(
                abortSignal: AbortSignal(),
                rpcRequest: { signal in try await rpc.request(signal: signal) },
                rpcSubscriptionRequest: { signal in try await subscription.request(signal: signal) },
                rpcSubscriptionValueMapper: { (value: Int) in value },
                rpcValueMapper: { (value: Int) in value }
            )
        )
        let iterator = sequence.makeAsyncIterator()
        let first = Task { try await iterator.next() }
        await kitRuntimeWaitUntil {
            let rpcCount = await rpc.requestCount()
            let subscriptionCount = await subscription.requestCount()
            return rpcCount == 1 && subscriptionCount == 1
        }

        await rpc.resolve(slot: 100, value: 42, at: 0)
        let firstValue = try await first.value
        XCTAssertEqual(firstValue, SolanaRpcResponse(context: SolanaRpcContext(slot: 100), value: 42))

        await subscription.fail(KitRuntimeFailure("subscription failed"), at: 0)
        do {
            _ = try await iterator.next()
            XCTFail("Expected subscription failure")
        } catch let error as KitRuntimeFailure {
            XCTAssertEqual(error.message, "subscription failed")
        }
        await kitRuntimeWaitUntil {
            let rpcAborted = await rpc.signalAborted(at: 0)
            let subscriptionAborted = await subscription.signalAborted(at: 0)
            return rpcAborted && subscriptionAborted
        }
    }

    func testAsyncGeneratorAbortCompletesAndIgnoresLaterValues() async throws {
        let rpc = KitRuntimeRpcEndpoint<Int>()
        let subscription = KitRuntimeSubscriptionEndpoint<Int>()
        let abortSignal = AbortSignal()
        let sequence = createAsyncGeneratorWithInitialValueAndSlotTracking(
            InitialValueAndSlotTrackingConfig(
                abortSignal: abortSignal,
                rpcRequest: { signal in try await rpc.request(signal: signal) },
                rpcSubscriptionRequest: { signal in try await subscription.request(signal: signal) },
                rpcSubscriptionValueMapper: { (value: Int) in value },
                rpcValueMapper: { (value: Int) in value }
            )
        )
        let iterator = sequence.makeAsyncIterator()
        let first = Task { try await iterator.next() }
        await kitRuntimeWaitUntil {
            let rpcCount = await rpc.requestCount()
            let subscriptionCount = await subscription.requestCount()
            return rpcCount == 1 && subscriptionCount == 1
        }

        abortSignal.abort(reason: KitRuntimeFailure("caller stopped"))
        let firstValue = try await first.value
        XCTAssertNil(firstValue)
        await kitRuntimeWaitUntil {
            let rpcAborted = await rpc.signalAborted(at: 0)
            let subscriptionAborted = await subscription.signalAborted(at: 0)
            return rpcAborted && subscriptionAborted
        }

        await rpc.resolve(slot: 100, value: 1, at: 0)
        await subscription.yield(slot: 200, value: 2, at: 0)
        let nextValue = try await iterator.next()
        XCTAssertNil(nextValue)
    }

    func testReactiveStoreKeepsNewestSlotReportsFirstErrorAndRetries() async throws {
        let rpc = KitRuntimeRpcEndpoint<Int>()
        let subscription = KitRuntimeSubscriptionEndpoint<Int>()
        let subscriberCalls = OSAllocatedUnfairLock(initialState: 0)
        let store = createReactiveStoreWithInitialValueAndSlotTracking(
            InitialValueAndSlotTrackingConfig(
                abortSignal: AbortSignal(),
                rpcRequest: { signal in try await rpc.request(signal: signal) },
                rpcSubscriptionRequest: { signal in try await subscription.request(signal: signal) },
                rpcSubscriptionValueMapper: { (value: Int) in value },
                rpcValueMapper: { (value: Int) in value }
            )
        )
        store.subscribe {
            subscriberCalls.withLock { $0 += 1 }
        }
        XCTAssertEqual(store.getUnifiedState().status, .loading)
        await kitRuntimeWaitUntil {
            let rpcCount = await rpc.requestCount()
            let subscriptionCount = await subscription.requestCount()
            return rpcCount == 1 && subscriptionCount == 1
        }

        await rpc.resolve(slot: 100, value: 42, at: 0)
        await kitRuntimeWaitUntil { store.getUnifiedState().status == .loaded }
        XCTAssertEqual(store.getState(), SolanaRpcResponse(context: SolanaRpcContext(slot: 100), value: 42))

        await subscription.yield(slot: 90, value: 90, at: 0)
        await kitRuntimeSpin()
        XCTAssertEqual(store.getState(), SolanaRpcResponse(context: SolanaRpcContext(slot: 100), value: 42))

        await subscription.fail(KitRuntimeFailure("subscription failed"), at: 0)
        await kitRuntimeWaitUntil { store.getUnifiedState().status == .error }
        XCTAssertEqual(store.getState(), SolanaRpcResponse(context: SolanaRpcContext(slot: 100), value: 42))
        XCTAssertEqual((store.getError() as? KitRuntimeFailure)?.message, "subscription failed")

        try store.retry()
        XCTAssertEqual(store.getUnifiedState().status, .retrying)
        XCTAssertEqual(store.getState(), SolanaRpcResponse(context: SolanaRpcContext(slot: 100), value: 42))
        XCTAssertNil(store.getError())
        await kitRuntimeWaitUntil {
            let rpcCount = await rpc.requestCount()
            let subscriptionCount = await subscription.requestCount()
            return rpcCount == 2 && subscriptionCount == 2
        }

        await rpc.resolve(slot: 95, value: 95, at: 1)
        await kitRuntimeSpin()
        XCTAssertEqual(store.getUnifiedState().status, .retrying)

        await subscription.yield(slot: 120, value: 120, at: 1)
        await kitRuntimeWaitUntil { store.getUnifiedState().status == .loaded && store.getState()?.value == 120 }
        XCTAssertGreaterThanOrEqual(subscriberCalls.withLock { $0 }, 4)
    }

    func testReactiveStoreAbortPreventsLaterUpdatesAndRetryWork() async throws {
        let rpc = KitRuntimeRpcEndpoint<Int>()
        let subscription = KitRuntimeSubscriptionEndpoint<Int>()
        let abortSignal = AbortSignal()
        let subscriberCalls = OSAllocatedUnfairLock(initialState: 0)
        let store = createReactiveStoreWithInitialValueAndSlotTracking(
            InitialValueAndSlotTrackingConfig(
                abortSignal: abortSignal,
                rpcRequest: { signal in try await rpc.request(signal: signal) },
                rpcSubscriptionRequest: { signal in try await subscription.request(signal: signal) },
                rpcSubscriptionValueMapper: { (value: Int) in value },
                rpcValueMapper: { (value: Int) in value }
            )
        )
        store.subscribe {
            subscriberCalls.withLock { $0 += 1 }
        }
        await kitRuntimeWaitUntil {
            let rpcCount = await rpc.requestCount()
            let subscriptionCount = await subscription.requestCount()
            return rpcCount == 1 && subscriptionCount == 1
        }

        abortSignal.abort(reason: KitRuntimeFailure("caller stopped"))
        await kitRuntimeWaitUntil {
            let rpcAborted = await rpc.signalAborted(at: 0)
            let subscriptionAborted = await subscription.signalAborted(at: 0)
            return rpcAborted && subscriptionAborted
        }
        await rpc.resolve(slot: 100, value: 1, at: 0)
        await subscription.yield(slot: 200, value: 2, at: 0)
        await kitRuntimeSpin()

        XCTAssertNil(store.getState())
        XCTAssertNil(store.getError())
        XCTAssertEqual(store.getUnifiedState().status, .loading)
        XCTAssertEqual(subscriberCalls.withLock { $0 }, 0)
        try store.retry()
        await kitRuntimeSpin()
        let rpcCount = await rpc.requestCount()
        let subscriptionCount = await subscription.requestCount()
        XCTAssertEqual(rpcCount, 1)
        XCTAssertEqual(subscriptionCount, 1)
    }
}

private actor KitRuntimeRpcEndpoint<Value: Sendable & Equatable & Hashable> {
    private var continuations: [CheckedContinuation<SolanaRpcResponse<Value>, any Error>] = []
    private var signals: [AbortSignal] = []

    func request(signal: AbortSignal) async throws -> SolanaRpcResponse<Value> {
        signals.append(signal)
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func requestCount() -> Int {
        continuations.count
    }

    func resolve(slot: Slot, value: Value, at index: Int) {
        guard continuations.indices.contains(index) else {
            return
        }
        let continuation = continuations[index]
        continuation.resume(returning: SolanaRpcResponse(context: SolanaRpcContext(slot: slot), value: value))
    }

    func reject(_ error: any Error, at index: Int) {
        guard continuations.indices.contains(index) else {
            return
        }
        continuations[index].resume(throwing: error)
    }

    func signalAborted(at index: Int) -> Bool {
        guard signals.indices.contains(index) else {
            return false
        }
        return signals[index].aborted
    }
}

private actor KitRuntimeSubscriptionEndpoint<Value: Sendable & Equatable & Hashable> {
    private var continuations: [AsyncThrowingStream<SolanaRpcResponse<Value>, any Error>.Continuation] = []
    private var signals: [AbortSignal] = []

    func request(signal: AbortSignal) async throws -> AsyncThrowingStream<SolanaRpcResponse<Value>, any Error> {
        signals.append(signal)
        return AsyncThrowingStream { continuation in
            Task {
                self.appendContinuation(continuation)
            }
        }
    }

    func requestCount() -> Int {
        continuations.count
    }

    func yield(slot: Slot, value: Value, at index: Int) {
        guard continuations.indices.contains(index) else {
            return
        }
        continuations[index].yield(SolanaRpcResponse(context: SolanaRpcContext(slot: slot), value: value))
    }

    func fail(_ error: any Error, at index: Int) {
        guard continuations.indices.contains(index) else {
            return
        }
        continuations[index].finish(throwing: error)
    }

    func finish(at index: Int) {
        guard continuations.indices.contains(index) else {
            return
        }
        continuations[index].finish()
    }

    func signalAborted(at index: Int) -> Bool {
        guard signals.indices.contains(index) else {
            return false
        }
        return signals[index].aborted
    }

    private func appendContinuation(_ continuation: AsyncThrowingStream<SolanaRpcResponse<Value>, any Error>.Continuation) {
        continuations.append(continuation)
    }
}

private enum KitRuntimeRpcResponse: Sendable {
    case response(RpcJsonValue)
    case waitForAbort
}

private actor KitRuntimeRpcRecorder {
    private var payloads: [RpcJsonValue] = []
    private var responses: [KitRuntimeRpcResponse]
    private var signals: [AbortSignal?] = []

    init(responses: [KitRuntimeRpcResponse]) {
        self.responses = responses
    }

    nonisolated var rpc: SolanaRpc {
        SolanaRpc(
            api: SolanaRpcApi(api: createJsonRpcApi()),
            transport: { config in
                try await self.transport(config)
            }
        )
    }

    func transport(_ config: RpcTransportConfig) async throws -> RpcJsonValue {
        payloads.append(config.payload)
        signals.append(config.abortSignal)
        guard !responses.isEmpty else {
            throw SolanaError(.malformedJSONRPCError)
        }
        switch responses.removeFirst() {
        case let .response(response):
            return response
        case .waitForAbort:
            if let signal = config.abortSignal {
                let reason = await signal.waitUntilAborted()
                throw reason
            }
            try await Task.sleep(nanoseconds: 60_000_000_000)
            throw KitRuntimeFailure("missing signal")
        }
    }

    func callCount() -> Int {
        payloads.count
    }

    func payload(at index: Int) -> RpcJsonValue? {
        guard payloads.indices.contains(index) else {
            return nil
        }
        return payloads[index]
    }

    func signalAborted(at index: Int) -> Bool {
        guard signals.indices.contains(index) else {
            return false
        }
        return signals[index]?.aborted ?? false
    }
}

private struct KitRuntimeFailure: Error, Sendable, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

private func kitRuntimeWaitUntil(
    _ predicate: @escaping @Sendable () async -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    for _ in 0 ..< 200 {
        if await predicate() {
            return
        }
        await kitRuntimeSpin()
    }
    XCTFail("Timed out waiting for condition", file: file, line: line)
}

private func kitRuntimeSpin() async {
    await Task.yield()
    try? await Task.sleep(nanoseconds: 1_000_000)
}

private func kitRuntimeIdleSubscriptions() -> RpcSubscriptions {
    RpcSubscriptions(
        config: RpcSubscriptionsConfig(
            api: createRpcSubscriptionsApi(
                RpcSubscriptionsApiConfig(planExecutor: { _ in EventDataPublisher() })
            ),
            transport: { _ in EventDataPublisher() }
        )
    )
}

private func kitRuntimeRpcParams(
    from payload: RpcJsonValue,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> [RpcJsonValue] {
    let params = try XCTUnwrap(payload.kitRuntimeValue(for: "params"), file: file, line: line)
    guard case let .array(values) = params else {
        XCTFail("Expected params array", file: file, line: line)
        return []
    }
    return values
}

private extension RpcJsonValue {
    func kitRuntimeValue(for key: String) -> RpcJsonValue? {
        guard case let .object(members) = self else {
            return nil
        }
        return members.first { $0.key == key }?.value
    }
}
