import Addresses
import Promises
@testable import Rpc
import RpcSpec
import RpcSpecTypes
import RpcTypes
import SolanaErrors
import XCTest
import os

final class RpcTests: XCTestCase {
    func testIntegerOverflowErrorContextUsesOrdinalLabels() {
        let error = createSolanaJsonRpcIntegerOverflowError(methodName: "someMethod", keyPath: [.index(2)], value: "1")
        XCTAssertEqual(error.code, SolanaErrorCode.rpcIntegerOverflow.rawValue)
        XCTAssertEqual(error.context["argumentLabel"], .string("3rd"))
        XCTAssertEqual(error.context["optionalPathLabel"], .string(""))
    }

    func testCreateSolanaRpcFromTransportThrowsOnUnsafeIntegerBeforeTransport() throws {
        let recorder = RpcTransportRecorder()
        let rpc = createSolanaRpcFromTransport { config in await recorder.transport(config) }

        XCTAssertNoThrow(try rpc.getBlocks(9_007_199_254_740_991))
        XCTAssertThrowsError(try rpc.getBlocks(9_007_199_254_740_992)) { error in
            XCTAssertEqual((error as? SolanaError)?.code, SolanaErrorCode.rpcIntegerOverflow.rawValue)
        }
    }

    func testDeduplicationKeyUsesStableMethodAndParams() throws {
        let payload = RpcJsonValue.object([
            ("id", .string("1")),
            ("jsonrpc", .string("2.0")),
            ("method", .string("getFoo")),
            ("params", .array([.string("foo")])),
        ])
        XCTAssertEqual(try getSolanaRpcPayloadDeduplicationKey(payload), #"["getFoo",["foo"]]"#)
    }

    func testDeduplicationKeyDoesNotTrapForLargeIntegerNumbers() throws {
        let payload = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("method", .string("getFoo")),
            ("params", .array([.number(1e20), .number(1e21), .number(1e-6), .number(1e-7)])),
        ])

        XCTAssertEqual(
            try getSolanaRpcPayloadDeduplicationKey(payload),
            #"["getFoo",[100000000000000000000,1e+21,0.000001,1e-7]]"#
        )
    }

    func testDeduplicationKeyUsesJavaScriptNumberRendering() throws {
        let payload = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("method", .string("getFoo")),
            ("params", .array([
                .number(1.2345678901234567),
                .number(0.0000012345678901234567),
                .number(12_345_678_901_234_568),
            ])),
        ])

        XCTAssertEqual(
            try getSolanaRpcPayloadDeduplicationKey(payload),
            #"["getFoo",[1.2345678901234567,0.0000012345678901234567,12345678901234568]]"#
        )
    }

    func testDefaultTransportHeadersLowercaseUserHeadersAndOverrideSolanaClient() {
        let headers = defaultRpcTransportHeaders([
            "Authorization": "Bearer token",
            "Solana-Client": "custom",
        ])

        XCTAssertEqual(headers["authorization"], "Bearer token")
        XCTAssertEqual(headers["solana-client"], "UNKNOWN")
        XCTAssertNil(headers["Solana-Client"])
    }

    func testRequestCoalescingSharesTransportWithinSchedulingWindow() async throws {
        let recorder = RpcTransportRecorder()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            await recorder.transport(config)
        }) { _ in "samehash" }
        let config = RpcTransportConfig(payload: .null)

        async let responseA = transport(config)
        async let responseB = transport(config)
        let responses = try await [responseA, responseB]

        XCTAssertEqual(responses, [.string("response-1"), .string("response-1")])
        let callCount = await recorder.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testRequestCoalescingDoesNotShareAcrossSchedulingWindows() async throws {
        let recorder = RpcTransportRecorder()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            await recorder.transport(config)
        }) { _ in "samehash" }
        let config = RpcTransportConfig(payload: .null)

        let responseA = try await transport(config)
        try await Task.sleep(nanoseconds: 3_000_000)
        let responseB = try await transport(config)

        XCTAssertEqual(responseA, .string("response-1"))
        XCTAssertEqual(responseB, .string("response-2"))
        let callCount = await recorder.callCount
        XCTAssertEqual(callCount, 2)
    }

    func testRequestCoalescingDoesNotShareSequentialAwaits() async throws {
        let recorder = RpcTransportRecorder()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            await recorder.transport(config)
        }) { _ in "samehash" }
        let config = RpcTransportConfig(payload: .null)

        let responseA = try await transport(config)
        let responseB = try await transport(config)

        XCTAssertEqual(responseA, .string("response-1"))
        XCTAssertEqual(responseB, .string("response-2"))
        let callCount = await recorder.callCount
        XCTAssertEqual(callCount, 2)
    }

    func testRequestCoalescingSkipsRequestsWithoutDeduplicationKey() async throws {
        let recorder = RpcTransportRecorder()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            await recorder.transport(config)
        }) { _ in nil }
        let config = RpcTransportConfig(payload: .null)

        async let responseA = transport(config)
        async let responseB = transport(config)
        let responses = try await [responseA, responseB]

        XCTAssertEqual(Set(responses), [.string("response-1"), .string("response-2")])
        let callCount = await recorder.callCount
        XCTAssertEqual(callCount, 2)
    }

    func testRequestCoalescingSharesTransportFailureWithinSchedulingWindow() async {
        let recorder = RpcTransportRecorder(failure: SolanaError(.rpcTransportHTTPHeaderForbidden, context: [:]))
        let transport = getRpcTransportWithRequestCoalescing({ config in
            try await recorder.throwingTransport(config)
        }) { _ in "samehash" }
        let config = RpcTransportConfig(payload: .null)

        async let responseA = transport(config)
        async let responseB = transport(config)

        do {
            _ = try await responseA
            _ = try await responseB
            XCTFail("Expected shared coalesced error")
        } catch {
            XCTAssertEqual((error as? SolanaError)?.code, SolanaErrorCode.rpcTransportHTTPHeaderForbidden.rawValue)
        }
        let callCount = await recorder.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testRequestCoalescingIsolatesCallerAbortFromSharedTransport() async throws {
        let recorder = DelayedRpcTransport()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            try await recorder.transport(config)
        }) { _ in "samehash" }
        let abortSignalA = AbortSignal()
        let abortSignalB = AbortSignal()

        async let responseA: RpcJsonValue = transport(RpcTransportConfig(payload: .null, abortSignal: abortSignalA))
        async let responseB: RpcJsonValue = transport(RpcTransportConfig(payload: .null, abortSignal: abortSignalB))
        try await Task.sleep(nanoseconds: 1_000_000)

        abortSignalA.abort(reason: AbortError(reason: "first"))
        do {
            _ = try await responseA
            XCTFail("Expected first request to abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "first")
        }

        let callCount = recorder.callCount
        let transportAborted = recorder.transportAbortSignalAborted
        XCTAssertEqual(callCount, 1)
        XCTAssertFalse(transportAborted)

        let resolvedB = try await responseB
        XCTAssertEqual(resolvedB, .string("ok"))
    }

    func testRequestCoalescingAbortsSharedTransportOnlyAfterAllConsumersAbort() async throws {
        let recorder = DelayedRpcTransport()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            try await recorder.transport(config)
        }) { _ in "samehash" }
        let abortSignalA = AbortSignal()
        let abortSignalB = AbortSignal()

        async let responseA: RpcJsonValue = transport(RpcTransportConfig(payload: .null, abortSignal: abortSignalA))
        async let responseB: RpcJsonValue = transport(RpcTransportConfig(payload: .null, abortSignal: abortSignalB))
        try await Task.sleep(nanoseconds: 1_000_000)

        abortSignalA.abort(reason: AbortError(reason: "first"))
        try await Task.sleep(nanoseconds: 1_000_000)
        let transportAbortedAfterFirstAbort = recorder.transportAbortSignalAborted
        XCTAssertFalse(transportAbortedAfterFirstAbort)

        abortSignalB.abort(reason: AbortError(reason: "second"))
        let transportAbortedSynchronously = recorder.transportAbortSignalAborted
        XCTAssertFalse(transportAbortedSynchronously)

        try await Task.sleep(nanoseconds: 5_000_000)
        let transportAbortedAfterSecondAbort = recorder.transportAbortSignalAborted
        XCTAssertTrue(transportAbortedAfterSecondAbort)

        do {
            _ = try await responseA
            XCTFail("Expected first request to abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "first")
        }
        do {
            _ = try await responseB
            XCTFail("Expected second request to abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "second")
        }
    }

    func testRequestCoalescingStartsNewTransportWhenRecoveryOccursAfterCoalescingWindow() async throws {
        let recorder = DelayedRpcTransport()
        let transport = getRpcTransportWithRequestCoalescing({ config in
            try await recorder.transport(config)
        }) { _ in "samehash" }
        let abortSignalA = AbortSignal()
        let abortSignalB = AbortSignal()

        async let responseA: RpcJsonValue = transport(RpcTransportConfig(payload: .null, abortSignal: abortSignalA))
        async let responseB: RpcJsonValue = transport(RpcTransportConfig(payload: .null, abortSignal: abortSignalB))
        try await Task.sleep(nanoseconds: 1_000_000)

        abortSignalA.abort(reason: AbortError(reason: "first"))
        abortSignalB.abort(reason: AbortError(reason: "second"))
        do {
            _ = try await responseA
            XCTFail("Expected first request to abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "first")
        }
        do {
            _ = try await responseB
            XCTFail("Expected second request to abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "second")
        }

        let responseCValue = try await transport(RpcTransportConfig(payload: .null))

        XCTAssertEqual(recorder.callCount, 2)
        XCTAssertEqual(responseCValue, .string("ok"))
    }
}

private func waitUntil(
    _ predicate: @escaping @Sendable () -> Bool
) async {
    for _ in 0 ..< 50 {
        if predicate() {
            return
        }
        await Task.yield()
    }
}

private actor RpcTransportRecorder {
    private let failure: SolanaError?
    private var calls = 0

    init(failure: SolanaError? = nil) {
        self.failure = failure
    }

    var callCount: Int {
        calls
    }

    func transport(_ config: RpcTransportConfig) -> RpcJsonValue {
        calls += 1
        return .string("response-\(calls)")
    }

    func throwingTransport(_ config: RpcTransportConfig) throws -> RpcJsonValue {
        calls += 1
        if let failure {
            throw failure
        }
        return .string("response-\(calls)")
    }
}

private final class DelayedRpcTransport: Sendable {
    private struct State: Sendable {
        var calls = 0
        var signal: AbortSignal?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var callCount: Int {
        state.withLock(\.calls)
    }

    var transportAbortSignalAborted: Bool {
        state.withLock { $0.signal?.aborted ?? false }
    }

    func transport(_ config: RpcTransportConfig) async throws -> RpcJsonValue {
        state.withLock { state in
            state.calls += 1
            state.signal = config.abortSignal
        }
        try await Task.sleep(nanoseconds: 25_000_000)
        if let reason = config.abortSignal?.abortReason() {
            throw reason
        }
        return .string("ok")
    }
}
