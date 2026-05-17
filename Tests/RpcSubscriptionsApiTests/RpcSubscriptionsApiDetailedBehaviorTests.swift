import Addresses
import Keys
import Promises
import RpcSpecTypes
@testable import RpcSubscriptionsApi
import RpcSubscriptionsSpec
import RpcTransformers
import Subscribable
import XCTest
import os

final class RpcSubscriptionsApiDetailedBehaviorTests: XCTestCase {
    func testNotificationNameMappingCoversEveryKnownNotificationAndPlainNames() {
        let expected: [(SolanaRpcSubscriptionNotificationName, String, String)] = [
            (.accountNotifications, "accountSubscribe", "accountUnsubscribe"),
            (.blockNotifications, "blockSubscribe", "blockUnsubscribe"),
            (.logsNotifications, "logsSubscribe", "logsUnsubscribe"),
            (.programNotifications, "programSubscribe", "programUnsubscribe"),
            (.rootNotifications, "rootSubscribe", "rootUnsubscribe"),
            (.signatureNotifications, "signatureSubscribe", "signatureUnsubscribe"),
            (.slotNotifications, "slotSubscribe", "slotUnsubscribe"),
            (.slotsUpdatesNotifications, "slotsUpdatesSubscribe", "slotsUpdatesUnsubscribe"),
            (.voteNotifications, "voteSubscribe", "voteUnsubscribe"),
        ]

        XCTAssertEqual(SolanaRpcSubscriptionNotificationName.allCases.map(\.rawValue), expected.map { $0.0.rawValue })
        for (name, subscribe, unsubscribe) in expected {
            XCTAssertEqual(subscribeMethodName(for: name.rawValue), subscribe)
            XCTAssertEqual(unsubscribeMethodName(for: name.rawValue), unsubscribe)
        }
        XCTAssertEqual(subscribeMethodName(for: "customSubscribe"), "customSubscribe")
        XCTAssertEqual(unsubscribeMethodName(for: "customUnsubscribe"), "customUnsubscribe")
    }

    func testSubscriptionHelpersPreserveInputsAndDefaultConfigSlots() throws {
        let api = createSolanaRpcSubscriptionsApi()
        let address = try Address("Vote111111111111111111111111111111111111111")
        let signature = Signature(rawValue: "3W4fkjpjUy9ntpfk4uT1cvX6VkVsfQtTb1g7fJQeLwBMKqN1")
        let filter = RpcJsonValue.object([("mentions", .array([.string(address.rawValue)]))])
        let config = RpcJsonValue.object([("commitment", .string("processed"))])
        let emptyConfig = RpcJsonValue.object([RpcJsonObjectMember]())

        XCTAssertEqual(try api.accountNotifications(address: address).request.params, .array([.string(address.rawValue), emptyConfig]))
        XCTAssertEqual(try api.blockNotifications(filter: .string("all"), config: config).request.params, .array([.string("all"), config]))
        XCTAssertEqual(try api.logsNotifications(filter: filter, config: config).request.params, .array([filter, config]))
        XCTAssertEqual(try api.programNotifications(programId: address, config: config).request.params, .array([.string(address.rawValue), config]))
        XCTAssertEqual(try api.rootNotifications().request.params, .array([]))
        XCTAssertEqual(try api.signatureNotifications(signature: signature).request.params, .array([.string(signature.rawValue), emptyConfig]))
        XCTAssertEqual(try api.slotNotifications().request.params, .array([]))
        XCTAssertEqual(try api.slotsUpdatesNotifications().request.params, .array([]))
        XCTAssertEqual(try api.voteNotifications().request.params, .array([]))
    }

    func testDefaultCommitmentDoesNotReplaceExplicitNonDefaultCommitment() throws {
        let api = createSolanaRpcSubscriptionsApi(RequestTransformerConfig(defaultCommitment: .confirmed))
        let address = try Address("Vote111111111111111111111111111111111111111")
        let explicit = RpcJsonValue.object([("commitment", .string("processed"))])

        let plan = try api.accountNotifications(address: address, config: explicit)
        guard case let .array(params) = plan.request.params else {
            return XCTFail("Expected params array")
        }

        guard params.count == 2 else {
            return XCTFail("Expected explicit config to remain")
        }
        XCTAssertEqual(params[1].value(for: "commitment"), .string("processed"))
    }

    func testSlotNotificationsTransformIntegerFieldsToBigInts() async throws {
        let api = createSolanaRpcSubscriptionsApi()
        let recording = makeRpcSubscriptionsApiRecordingChannel()
        let signal = AbortSignal()
        let plan = try api.slotNotifications()
        let publisherTask = Task {
            try await plan.execute(RpcSubscriptionsPlanExecutionConfig(channel: recording.channel, signal: signal))
        }

        try await rpcSubscriptionsApiWaitUntil {
            recording.sent.withLock { !$0.isEmpty }
        }
        let subscribeMessage = try XCTUnwrap(recording.sent.withLock { $0.first as? RpcMessage })
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessage.id, value: .number(123)))
        let publisher = try await publisherTask.value
        let received = OSAllocatedUnfairLock(initialState: [RpcJsonValue]())
        _ = try publisher.on("notification", subscriber: { payload in
            if let value = payload as? RpcJsonValue {
                received.withLock { $0.append(value) }
            }
        })

        recording.publisher.publish("message", RpcSubscriptionNotification<RpcJsonValue>(
            method: "slotNotification",
            result: .object([
                ("parent", .number(1)),
                ("root", .number(2)),
                ("slot", .number(3)),
            ]),
            subscription: 123
        ))

        XCTAssertEqual(
            received.withLock { $0.first },
            .object([
                ("parent", .bigint("1")),
                ("root", .bigint("2")),
                ("slot", .bigint("3")),
            ])
        )
        signal.abort()
    }
}

private func makeRpcSubscriptionsApiRecordingChannel() -> (
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

private func rpcSubscriptionsApiWaitUntil(_ predicate: @escaping @Sendable () -> Bool) async throws {
    for _ in 0..<100 {
        if predicate() {
            return
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTFail("Condition was not met")
}
