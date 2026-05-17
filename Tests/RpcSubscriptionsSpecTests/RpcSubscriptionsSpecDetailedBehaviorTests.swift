import os
import Promises
import RpcSpecTypes
@testable import RpcSubscriptionsSpec
import SolanaErrors
import Subscribable
import XCTest

final class RpcSubscriptionsSpecDetailedBehaviorTests: XCTestCase {
    func testInboundTransformDropsThrownMessagesAndContinues() throws {
        let publisher = EventDataPublisher()
        let channel = RpcSubscriptionsChannel(dataPublisher: publisher) { _ in }
        let transformed = transformChannelInboundMessages(channel) { payload in
            guard let value = payload as? String else {
                return nil
            }
            if value == "bad" {
                throw RpcSubscriptionsSpecDetailedError(message: "bad")
            }
            return value.uppercased()
        }
        let received = OSAllocatedUnfairLock(initialState: [String]())
        _ = try transformed.on("message", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })

        publisher.publish("message", "bad")
        publisher.publish("message", "good")

        XCTAssertEqual(received.withLock { $0 }, ["GOOD"])
    }

    func testOutboundTransformFailurePreventsSend() async throws {
        let sent = OSAllocatedUnfairLock(initialState: [DataPublisherPayload]())
        let channel = RpcSubscriptionsChannel(dataPublisher: EventDataPublisher()) { payload in
            sent.withLock { $0.append(payload) }
        }
        let transformed = transformChannelOutboundMessages(channel) { _ in
            throw RpcSubscriptionsSpecDetailedError(message: "stop")
        }

        do {
            try await transformed.send("value")
            XCTFail("Expected outbound transform to throw")
        } catch let error as RpcSubscriptionsSpecDetailedError {
            XCTAssertEqual(error.message, "stop")
        }
        XCTAssertTrue(sent.withLock { $0.isEmpty })
    }

    func testPubSubPlanAcceptsStringSubscriptionIdFromJsonResponse() async throws {
        let recording = makeRpcSubscriptionsSpecRecordingChannel()
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
        let subscribe = try await rpcSubscriptionsSpecWaitForMessage(recording.sent)
        recording.publisher.publish(
            "message",
            RpcJsonValue.object([
                ("jsonrpc", .string("2.0")),
                ("id", .string(subscribe.id)),
                ("result", .string("42")),
            ])
        )
        let notifications = try await publisherTask.value
        let received = OSAllocatedUnfairLock(initialState: [String]())
        _ = try notifications.on("notification", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })

        recording.publisher.publish("message", rpcSubscriptionsSpecNotification(subscription: 42, result: .string("ok")))

        XCTAssertEqual(received.withLock { $0 }, ["ok"])
        signal.abort()
    }

    func testPubSubPlanRejectsMalformedJsonRpcErrorObject() async throws {
        let recording = makeRpcSubscriptionsSpecRecordingChannel()
        let publisherTask = Task {
            try await executeRpcPubSubSubscriptionPlan(
                channel: recording.channel,
                signal: AbortSignal(),
                subscribeRequest: RpcRequest(methodName: "thingSubscribe", params: .array([])),
                unsubscribeMethodName: "thingUnsubscribe",
                as: String.self
            )
        }
        let subscribe = try await rpcSubscriptionsSpecWaitForMessage(recording.sent)
        recording.publisher.publish(
            "message",
            RpcJsonValue.object([
                ("jsonrpc", .string("2.0")),
                ("id", .string(subscribe.id)),
                ("error", .object([("message", .string("Missing code"))])),
            ])
        )

        do {
            _ = try await publisherTask.value
            XCTFail("Expected malformed error to throw")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.malformedJSONRPCError.rawValue)
            XCTAssertEqual(error.context["message"], .string("Missing code"))
        }
    }
}

private struct RpcSubscriptionsSpecDetailedError: Error, Sendable, Equatable {
    let message: String
}

private func makeRpcSubscriptionsSpecRecordingChannel() -> (
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

private func rpcSubscriptionsSpecWaitForMessage(_ sent: OSAllocatedUnfairLock<[DataPublisherPayload]>) async throws -> RpcMessage {
    for _ in 0..<100 {
        if let message = sent.withLock({ $0.compactMap { $0 as? RpcMessage }.first }) {
            return message
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    throw RpcSubscriptionsSpecDetailedError(message: "missing message")
}

private func rpcSubscriptionsSpecNotification(subscription: Int, result: RpcJsonValue) -> RpcJsonValue {
    .object([
        ("jsonrpc", .string("2.0")),
        ("method", .string("thingNotification")),
        (
            "params",
            .object([
                ("result", result),
                ("subscription", .string(String(subscription))),
            ])
        ),
    ])
}
