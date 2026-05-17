import os
import Promises
import RpcSpecTypes
@testable import RpcSubscriptionsSpec
import SolanaErrors
import Subscribable
import XCTest

final class RpcSubscriptionsSpecRuntimeBehaviorTests: XCTestCase {
    func testPubSubPlanRejectsMissingAndMalformedSubscriptionIds() async throws {
        let cases: [RpcJsonValue?] = [
            nil,
            .null,
            .number(1.5),
            .string("not-a-number"),
            .object([]),
        ]

        for result in cases {
            let recording = makeRpcSubscriptionsSpecRuntimeRecordingChannel()
            let publisherTask = Task {
                try await executeRpcPubSubSubscriptionPlan(
                    channel: recording.channel,
                    signal: AbortSignal(),
                    subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                    unsubscribeMethodName: "thingUnsubscribe",
                    as: String.self
                )
            }
            let subscribe = try await rpcSubscriptionsSpecRuntimeWaitForMessage(recording.sent)
            var members: [RpcJsonObjectMember] = [
                RpcJsonObjectMember("jsonrpc", .string("2.0")),
                RpcJsonObjectMember("id", .string(subscribe.id)),
            ]
            if let result {
                members.append(RpcJsonObjectMember("result", result))
            }
            recording.publisher.publish("message", RpcJsonValue.object(members))

            do {
                _ = try await publisherTask.value
                XCTFail("Expected subscription id failure")
            } catch let error as SolanaError {
                XCTAssertEqual(error.code, SolanaErrorCode.rpcSubscriptionsExpectedServerSubscriptionID.rawValue)
            }
        }
    }

    func testPubSubPlanDoesNotSendUnsubscribeWhenAbortedBeforeAcknowledgement() async throws {
        let recording = makeRpcSubscriptionsSpecRuntimeRecordingChannel()
        let signal = AbortSignal()
        let publisherTask = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: signal,
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        _ = try await rpcSubscriptionsSpecRuntimeWaitForMessage(recording.sent)
        recording.sent.withLock { $0.removeAll() }

        signal.abort(reason: AbortError(reason: "cancelled"))

        do {
            _ = try await publisherTask.value
            XCTFail("Expected abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "cancelled")
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertFalse(recording.sent.withLock { messages in
            messages.contains { ($0 as? RpcMessage)?.method == "thingUnsubscribe" }
        })
    }
}

private func makeRpcSubscriptionsSpecRuntimeRecordingChannel() -> (
    publisher: EventDataPublisher,
    sent: OSAllocatedUnfairLock<[DataPublisherPayload]>,
    channel: RpcSubscriptionsChannel
) {
    let publisher = EventDataPublisher()
    let sent = OSAllocatedUnfairLock(initialState: [DataPublisherPayload]())
    let channel = RpcSubscriptionsChannel(dataPublisher: publisher) { payload in
        sent.withLock { $0.append(payload) }
    }
    return (publisher, sent, channel)
}

private func rpcSubscriptionsSpecRuntimeWaitForMessage(
    _ sent: OSAllocatedUnfairLock<[DataPublisherPayload]>
) async throws -> RpcMessage {
    for _ in 0..<100 {
        if let message = sent.withLock({ $0.compactMap { $0 as? RpcMessage }.first }) {
            return message
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    throw RpcSubscriptionsSpecRuntimeError(message: "missing message")
}

private struct RpcSubscriptionsSpecRuntimeError: Error, Sendable, Equatable {
    let message: String
}
