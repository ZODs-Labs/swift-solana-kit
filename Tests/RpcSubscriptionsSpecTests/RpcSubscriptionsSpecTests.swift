import os
import Promises
import RpcSpecTypes
@testable import RpcSubscriptionsSpec
import SolanaErrors
import Subscribable
import XCTest

final class RpcSubscriptionsSpecTests: XCTestCase {
    func testCreateRpcSubscriptionsApiBuildsAndTransformsRequests() async throws {
        let captured = OSAllocatedUnfairLock<RpcSubscriptionsPlanExecutorConfig?>(initialState: nil)
        let publisher = EventDataPublisher()
        let api = createRpcSubscriptionsApi(
            RpcSubscriptionsApiConfig(
                planExecutor: { config in
                    captured.withLock { $0 = config }
                    return publisher
                },
                requestTransformer: { request in
                    RpcRequest(methodName: "bar", params: .array([.string("transformed")]))
                }
            )
        )
        let plan: RpcSubscriptionsPlan<String> = try api.plan(methodName: "foo", params: [.string("hi")], as: String.self)
        XCTAssertEqual(plan.request.methodName, "bar")
        XCTAssertEqual(plan.request.params, .array([.string("transformed")]))

        let channel = makeRecordingChannel().channel
        let signal = AbortSignal()
        _ = try await plan.execute(RpcSubscriptionsPlanExecutionConfig(channel: channel, signal: signal))
        XCTAssertEqual(captured.withLock { $0?.request.methodName }, "bar")
    }

    func testChannelInboundAndOutboundTransforms() async throws {
        let publisher = EventDataPublisher()
        let sent = OSAllocatedUnfairLock(initialState: [DataPublisherPayload]())
        let channel = RpcSubscriptionsChannel(dataPublisher: publisher) { payload in
            sent.withLock { $0.append(payload) }
        }
        let inbound = transformChannelInboundMessages(channel) { payload in
            guard let value = payload as? String else { return nil }
            return value.count
        }
        let received = OSAllocatedUnfairLock(initialState: [Int]())
        _ = try inbound.on("message", subscriber: { payload in
            if let value = payload as? Int {
                received.withLock { $0.append(value) }
            }
        })
        publisher.publish("message", "Hello World!")
        XCTAssertEqual(received.withLock { $0 }, [12])

        let outbound = transformChannelOutboundMessages(channel) { payload in
            guard let value = payload as? String else { return nil }
            return value.count
        }
        try await outbound.send("Hello World!")
        XCTAssertEqual(sent.withLock { ($0.last as? Int) }, 12)
    }

    func testPubSubPlanPublishesMatchingNotificationsAndUnsubscribesOnAbort() async throws {
        let recording = makeRecordingChannel()
        let abortSignal = AbortSignal()
        let publisherTask = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: abortSignal,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([.string("a")])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessage = try XCTUnwrap(recording.sent.withLock { $0.first as? RpcMessage })
        XCTAssertEqual(subscribeMessage.method, "thingSubscribe")
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessage.id, value: .number(123)))
        let notifications = try await publisherTask.value

        let received = OSAllocatedUnfairLock(initialState: [String]())
        _ = try notifications.on("notification", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })
        recording.publisher.publish("message", notification(subscription: 999, result: .string("wrong")))
        recording.publisher.publish("message", notification(subscription: 123, result: .string("hi")))
        XCTAssertEqual(received.withLock { $0 }, ["hi"])

        abortSignal.abort()
        try await Task.sleep(nanoseconds: 1_000_000)
        let sentMethods = recording.sent.withLock { messages in
            messages.compactMap { ($0 as? RpcMessage)?.method }
        }
        XCTAssertTrue(sentMethods.contains("thingUnsubscribe"))
    }

    func testPubSubPlanUnsupportedNotificationChannelThrowsSolanaError() async throws {
        let recording = makeRecordingChannel()
        let publisherTask = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: AbortSignal(),
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessage = try XCTUnwrap(recording.sent.withLock { $0.first as? RpcMessage })
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessage.id, value: .number(123)))
        let notifications = try await publisherTask.value

        let code = throwingCode {
            _ = try notifications.on("bad", subscriber: { _ in })
        }

        XCTAssertEqual(code, SolanaErrorCode.invariantViolationDataPublisherChannelUnimplemented.rawValue)
    }

    func testPubSubPlanDoesNotPublishRawNotificationWhenResponseTransformerThrows() async throws {
        let recording = makeRecordingChannel()
        let publisherTask = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                responseTransformer: RpcResponseTransformer { _, _ in
                    throw SolanaError(.rpcIntegerOverflow)
                },
                signal: AbortSignal(),
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessage = try XCTUnwrap(recording.sent.withLock { $0.first as? RpcMessage })
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessage.id, value: .number(123)))
        let notifications = try await publisherTask.value
        let received = OSAllocatedUnfairLock(initialState: [String]())
        _ = try notifications.on("notification", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })

        recording.publisher.publish("message", notification(subscription: 123, result: .string("raw")))
        try await Task.sleep(nanoseconds: 1_000_000)

        XCTAssertEqual(received.withLock { $0 }, [])
    }

    func testPubSubPlanSendsSubscribeMessageEvenWhenAlreadyAborted() async throws {
        let recording = makeRecordingChannel()
        let abortSignal = AbortSignal(abortedWith: AbortError(reason: "done"))

        do {
            _ = try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: abortSignal,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
            XCTFail("Expected already aborted subscription to throw")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "done")
        }

        let sentMethods = recording.sent.withLock { messages in
            messages.compactMap { ($0 as? RpcMessage)?.method }
        }
        XCTAssertEqual(sentMethods, ["thingSubscribe"])
    }

    func testPubSubPlanPreservesSubscribeJsonRpcErrorCode() async throws {
        let recording = makeRecordingChannel()
        let publisherTask = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: AbortSignal(),
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessage = try XCTUnwrap(recording.sent.withLock { $0.first as? RpcMessage })
        recording.publisher.publish(
            "message",
            RpcResponseData.error(
                id: subscribeMessage.id,
                error: RpcResponseErrorPayload(code: -32602, message: "Invalid params")
            )
        )

        do {
            _ = try await publisherTask.value
            XCTFail("Expected JSON-RPC error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.jsonRPCInvalidParams.rawValue)
            XCTAssertEqual(error.context["__serverMessage"], .string("Invalid params"))
        }
    }

    func testPubSubPlanCoalescesUnsubscribeForSharedSubscriptionId() async throws {
        let recording = makeRecordingChannel()
        let firstAbort = AbortSignal()
        let secondAbort = AbortSignal()
        let first = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: firstAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        let second = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: secondAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessages = recording.sent.withLock { $0.compactMap { $0 as? RpcMessage } }
        XCTAssertEqual(subscribeMessages.count, 2)
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessages[0].id, value: .number(777)))
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessages[1].id, value: .number(777)))
        _ = try await first.value
        _ = try await second.value

        recording.sent.withLock { $0.removeAll() }
        firstAbort.abort()
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertFalse(recording.sent.withLock { $0.contains { ($0 as? RpcMessage)?.method == "thingUnsubscribe" } })
        secondAbort.abort()
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertTrue(recording.sent.withLock { $0.contains { ($0 as? RpcMessage)?.method == "thingUnsubscribe" } })
    }

    func testPubSubPlanTransformsSharedSubscriptionNotificationOnce() async throws {
        let recording = makeRecordingChannel()
        let firstAbort = AbortSignal()
        let secondAbort = AbortSignal()
        let transformCount = OSAllocatedUnfairLock(initialState: 0)
        let transformer = RpcResponseTransformer { result, _ in
            transformCount.withLock { $0 += 1 }
            return result
        }
        let first = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                responseTransformer: transformer,
                signal: firstAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        let second = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                responseTransformer: transformer,
                signal: secondAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessages = recording.sent.withLock { $0.compactMap { $0 as? RpcMessage } }
        XCTAssertEqual(subscribeMessages.count, 2)
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessages[0].id, value: .number(123)))
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessages[1].id, value: .number(123)))
        let firstPublisher = try await first.value
        let secondPublisher = try await second.value
        let received = OSAllocatedUnfairLock(initialState: [String]())
        _ = try firstPublisher.on("notification", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })
        _ = try secondPublisher.on("notification", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })

        recording.publisher.publish("message", notification(subscription: 123, result: .string("shared")))

        XCTAssertEqual(received.withLock { $0 }, ["shared", "shared"])
        XCTAssertEqual(transformCount.withLock { $0 }, 1)
    }

    func testPubSubPlanKeepsDistinctResponseTransformersSeparate() async throws {
        let recording = makeRecordingChannel()
        let firstAbort = AbortSignal()
        let secondAbort = AbortSignal()
        let firstTransformer = RpcResponseTransformer { _, _ in .string("first") }
        let secondTransformer = RpcResponseTransformer { _, _ in .string("second") }
        let first = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                responseTransformer: firstTransformer,
                signal: firstAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        let second = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                responseTransformer: secondTransformer,
                signal: secondAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessages = recording.sent.withLock { $0.compactMap { $0 as? RpcMessage } }
        XCTAssertEqual(subscribeMessages.count, 2)
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessages[0].id, value: .number(123)))
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessages[1].id, value: .number(123)))
        let firstPublisher = try await first.value
        let secondPublisher = try await second.value
        let received = OSAllocatedUnfairLock(initialState: [String]())
        _ = try firstPublisher.on("notification", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })
        _ = try secondPublisher.on("notification", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })

        recording.publisher.publish("message", notification(subscription: 123, result: .string("raw")))

        XCTAssertEqual(received.withLock { $0 }.sorted(), ["first", "second"])
    }

    func testPubSubPlanUnsubscribesIndependentSubscriptionIdsSeparately() async throws {
        let recording = makeRecordingChannel()
        let firstAbort = AbortSignal()
        let secondAbort = AbortSignal()
        let first = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: firstAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        let firstSubscribeMessage = await waitUntilRpcMessage(recording.sent) { $0.method == "thingSubscribe" }
        let firstSubscribe = try XCTUnwrap(firstSubscribeMessage)
        recording.publisher.publish("message", RpcResponseData.result(id: firstSubscribe.id, value: .number(123)))
        _ = try await first.value

        recording.sent.withLock { $0.removeAll() }
        let second = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: secondAbort,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        let secondSubscribeMessage = await waitUntilRpcMessage(recording.sent) { $0.method == "thingSubscribe" }
        let secondSubscribe = try XCTUnwrap(secondSubscribeMessage)
        recording.publisher.publish("message", RpcResponseData.result(id: secondSubscribe.id, value: .number(456)))
        _ = try await second.value

        recording.sent.withLock { $0.removeAll() }
        firstAbort.abort()
        let firstUnsubscribeSent = await waitUntilSent(recording.sent) { message in
            guard let rpcMessage = message as? RpcMessage else {
                return false
            }
            return rpcMessage.method == "thingUnsubscribe" && rpcMessage.params == .array([.number(123)])
        }
        XCTAssertTrue(firstUnsubscribeSent)

        recording.sent.withLock { $0.removeAll() }
        secondAbort.abort()
        let secondUnsubscribeSent = await waitUntilSent(recording.sent) { message in
            guard let rpcMessage = message as? RpcMessage else {
                return false
            }
            return rpcMessage.method == "thingUnsubscribe" && rpcMessage.params == .array([.number(456)])
        }
        XCTAssertTrue(secondUnsubscribeSent)
    }

    func testPendingRequestBridgesTransportToReactiveStoreAndIterable() async throws {
        let publisher = EventDataPublisher()
        let transportCalls = OSAllocatedUnfairLock(initialState: [RpcSubscriptionsTransportConfig]())
        let api = createRpcSubscriptionsApi(
            RpcSubscriptionsApiConfig(planExecutor: { _ in publisher })
        )
        let rpc = createSubscriptionRpc(
            RpcSubscriptionsConfig(api: api) { config in
                transportCalls.withLock { $0.append(config) }
                return publisher
            }
        )

        let pending: PendingRpcSubscriptionsRequest<String> = try rpc.request(
            "thingNotifications",
            params: [.string("x")],
            as: String.self
        )
        let signal = AbortSignal()
        let store = try await pending.reactive(RpcSubscribeOptions(abortSignal: signal))
        publisher.publish("notification", "first")
        XCTAssertEqual(store.getState(), "first")
        XCTAssertEqual(transportCalls.withLock(\.count), 1)

        let sequence = try await pending.subscribe(RpcSubscribeOptions(abortSignal: signal))
        let iterator = sequence.makeAsyncIterator()
        let next = Task { try await iterator.next() }
        try await Task.sleep(nanoseconds: 1_000_000)
        publisher.publish("notification", "second")
        let nextValue = try await next.value
        XCTAssertEqual(nextValue, "second")
    }

    func testPendingRequestReactiveStoreRetriesWithFreshTransport() async throws {
        let transportCalls = OSAllocatedUnfairLock(initialState: 0)
        let publishers = OSAllocatedUnfairLock(initialState: [EventDataPublisher]())
        let pending = PendingRpcSubscriptionsRequest<String>(
            transport: { _ in
                transportCalls.withLock { $0 += 1 }
                let publisher = EventDataPublisher()
                publishers.withLock { $0.append(publisher) }
                return publisher
            },
            plan: RpcSubscriptionsPlan(
                request: RpcRequest(methodName: "thingNotifications", params: .array([])),
                execute: { _ in EventDataPublisher() }
            )
        )
        let store = pending.reactiveStore(RpcSubscribeOptions(abortSignal: AbortSignal()))
        try await Task.sleep(nanoseconds: 1_000_000)
        publishers.withLock { $0[0] }.publish("notification", "first")
        XCTAssertEqual(store.getUnifiedState().status, .loaded)
        XCTAssertEqual(store.getUnifiedState().data, "first")

        publishers.withLock { $0[0] }.publish(
            "error",
            SolanaError(.rpcSubscriptionsChannelConnectionClosed)
        )
        XCTAssertEqual(store.getUnifiedState().status, .error)
        try store.retry()
        XCTAssertEqual(store.getUnifiedState().status, .retrying)
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertEqual(transportCalls.withLock { $0 }, 2)
        publishers.withLock { $0[1] }.publish("notification", "second")
        XCTAssertEqual(store.getUnifiedState().status, .loaded)
        XCTAssertEqual(store.getUnifiedState().data, "second")
    }
}

private func makeRecordingChannel() -> (publisher: EventDataPublisher, sent: OSAllocatedUnfairLock<[DataPublisherPayload]>, channel: RpcSubscriptionsChannel) {
    let publisher = EventDataPublisher()
    let sent = OSAllocatedUnfairLock(initialState: [DataPublisherPayload]())
    let channel = RpcSubscriptionsChannel(dataPublisher: publisher) { payload in
        sent.withLock { $0.append(payload) }
    }
    return (publisher, sent, channel)
}

private func waitUntilSent(
    _ sent: OSAllocatedUnfairLock<[DataPublisherPayload]>,
    matches predicate: @escaping @Sendable (DataPublisherPayload) -> Bool
) async -> Bool {
    for _ in 0 ..< 50 {
        if sent.withLock({ $0.contains(where: predicate) }) {
            return true
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return false
}

private func waitUntilRpcMessage(
    _ sent: OSAllocatedUnfairLock<[DataPublisherPayload]>,
    matches predicate: @escaping @Sendable (RpcMessage) -> Bool
) async -> RpcMessage? {
    for _ in 0 ..< 50 {
        if let message = sent.withLock({ $0.compactMap { $0 as? RpcMessage }.first(where: predicate) }) {
            return message
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return nil
}

private func notification(subscription: Int, result: RpcJsonValue) -> RpcJsonValue {
    .object([
        RpcJsonObjectMember("jsonrpc", .string("2.0")),
        RpcJsonObjectMember("method", .string("thingNotification")),
        RpcJsonObjectMember(
            "params",
            .object([
                RpcJsonObjectMember("result", result),
                RpcJsonObjectMember("subscription", .bigint(String(subscription))),
            ])
        ),
    ])
}

private func throwingCode(_ body: () throws -> Void) -> Int? {
    do {
        try body()
        return nil
    } catch let error as any SolanaErrorCoded {
        return error.code
    } catch {
        return nil
    }
}
