import os
import Promises
import RpcSpec
import RpcSpecTypes
import Subscribable
import XCTest

final class RpcSpecTests: XCTestCase {
    func testIsJsonRpcPayloadRecognizesRequiredShape() {
        XCTAssertTrue(isJsonRpcPayload(.object([
            RpcJsonObjectMember("jsonrpc", .string("2.0")),
            RpcJsonObjectMember("method", .string("getFoo")),
            RpcJsonObjectMember("params", .array([.number(123)])),
        ])))
        XCTAssertFalse(isJsonRpcPayload(.object([
            RpcJsonObjectMember("jsonrpc", .string("42.0")),
            RpcJsonObjectMember("method", .string("getFoo")),
            RpcJsonObjectMember("params", .array([.number(123)])),
        ])))
        XCTAssertFalse(isJsonRpcPayload(.array([])))
    }

    func testJsonRpcApiAppliesRequestAndResponseTransformers() async throws {
        let api = createJsonRpcApi(
            config: RpcApiConfig(
                requestTransformer: { request in
                    RpcRequest(methodName: "\(request.methodName)Transformed", params: request.params)
                },
                responseTransformer: RpcResponseTransformer { response, _ in
                    response.value(for: "result") ?? .null
                }
            )
        )
        let recorder = RpcTransportRecorder(response: .object([RpcJsonObjectMember("result", .number(84))]))
        let result = try await api.plan(methodName: "someMethod", params: [.number(1)])
            .execute(transport: { config in await recorder.transport(config) })

        let payload = try await recorder.onlyPayload()
        XCTAssertEqual(payload.value(for: "method"), .string("someMethodTransformed"))
        XCTAssertEqual(result, .number(84))
    }

    func testPendingRequestForwardsAbortSignal() async throws {
        let api = createJsonRpcApi()
        let signal = AbortSignal()
        let recorder = RpcTransportRecorder(response: .object([RpcJsonObjectMember("result", .number(1))]))

        _ = try await api.plan(methodName: "someMethod", params: [])
            .execute(transport: { config in await recorder.transport(config) }, abortSignal: signal)

        let capturedSignal = await recorder.onlyAbortSignal()
        XCTAssertTrue(capturedSignal === signal)
    }

    func testPendingRequestReactiveStoreStartsRunningAndFiresRequest() async throws {
        let probe = ReactivePlanProbe()
        let recorder = RpcTransportRecorder(response: .string("transport"))
        let request = PendingRpcRequest(
            plan: RpcPlan { transport, abortSignal in
                try await probe.execute(transport: transport, abortSignal: abortSignal)
            },
            transport: { config in await recorder.transport(config) }
        )

        let store = request.reactiveStore()

        XCTAssertEqual(store.getState().status, .running)
        try await waitUntil { await probe.callCount() == 1 }
        let maybeSignal = await probe.signal(at: 0)
        let signal = try XCTUnwrap(maybeSignal)
        XCTAssertFalse(signal.aborted)
        let payload = try await recorder.onlyPayload()
        XCTAssertEqual(payload, .string("reactive"))

        await probe.resolveNext(.number(42))
        try await waitUntil { store.getState().status == .success }
        XCTAssertEqual(store.getState().data, .number(42))
    }

    func testPendingRequestReactiveStoreTransitionsToErrorAndNotifiesSubscribers() async throws {
        let probe = ReactivePlanProbe()
        let request = PendingRpcRequest(
            plan: RpcPlan { transport, abortSignal in
                try await probe.execute(transport: transport, abortSignal: abortSignal)
            },
            transport: { _ in .null }
        )
        let store = request.reactiveStore()
        let notifications = OSAllocatedUnfairLock(initialState: 0)
        store.subscribe {
            notifications.withLock { $0 += 1 }
        }

        try await waitUntil { await probe.callCount() == 1 }
        await probe.rejectNext(TestError(message: "boom"))
        try await waitUntil { store.getState().status == .error }

        XCTAssertEqual((store.getState().error as? TestError)?.message, "boom")
        XCTAssertGreaterThan(notifications.withLock { $0 }, 0)
    }

    func testPendingRequestReactiveStoreResetAbortsInFlightSignalAndDispatchReruns() async throws {
        let probe = ReactivePlanProbe()
        let request = PendingRpcRequest(
            plan: RpcPlan { transport, abortSignal in
                try await probe.execute(transport: transport, abortSignal: abortSignal)
            },
            transport: { _ in .null }
        )
        let store = request.reactiveStore()
        try await waitUntil { await probe.callCount() == 1 }
        let maybeFirstSignal = await probe.signal(at: 0)
        let firstSignal = try XCTUnwrap(maybeFirstSignal)

        store.reset()

        XCTAssertTrue(firstSignal.aborted)
        XCTAssertEqual(store.getState().status, .idle)

        store.dispatch()
        try await waitUntil { await probe.callCount() == 2 }
        let maybeSecondSignal = await probe.signal(at: 1)
        let secondSignal = try XCTUnwrap(maybeSecondSignal)
        XCTAssertFalse(secondSignal.aborted)
        await probe.resolveLast(.string("done"))
        try await waitUntil { store.getState().status == .success }
    }
}

private actor RpcTransportRecorder {
    private var payloads: [RpcJsonValue] = []
    private var abortSignals: [AbortSignal?] = []
    private let response: RpcJsonValue

    init(response: RpcJsonValue) {
        self.response = response
    }

    func transport(_ config: RpcTransportConfig) -> RpcJsonValue {
        payloads.append(config.payload)
        abortSignals.append(config.abortSignal)
        return response
    }

    func onlyPayload() throws -> RpcJsonValue {
        try XCTUnwrap(payloads.first)
    }

    func onlyAbortSignal() -> AbortSignal? {
        abortSignals.first ?? nil
    }
}

private actor ReactivePlanProbe {
    private var continuations: [CheckedContinuation<RpcJsonValue, any Error>] = []
    private var signals: [AbortSignal?] = []

    func execute(transport: RpcTransport, abortSignal: AbortSignal?) async throws -> RpcJsonValue {
        signals.append(abortSignal)
        _ = try await transport(RpcTransportConfig(payload: .string("reactive"), abortSignal: abortSignal))
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func callCount() -> Int {
        signals.count
    }

    func signal(at index: Int) -> AbortSignal? {
        guard signals.indices.contains(index) else {
            return nil
        }
        return signals[index]
    }

    func resolveNext(_ value: RpcJsonValue) {
        guard !continuations.isEmpty else {
            return
        }
        continuations.removeFirst().resume(returning: value)
    }

    func resolveLast(_ value: RpcJsonValue) {
        guard !continuations.isEmpty else {
            return
        }
        continuations.removeLast().resume(returning: value)
    }

    func rejectNext(_ error: any Error) {
        guard !continuations.isEmpty else {
            return
        }
        continuations.removeFirst().resume(throwing: error)
    }
}

private struct TestError: Error, Sendable, Equatable {
    let message: String
}

private func waitUntil(_ condition: @escaping @Sendable () async -> Bool) async throws {
    for _ in 0..<100 {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTFail("Condition was not met")
}
