import Addresses
import Keys
import os
import Promises
import RpcSpecTypes
@testable import RpcSubscriptionsApi
import RpcSubscriptionsSpec
import RpcTransformers
import Subscribable
import XCTest

final class RpcSubscriptionsApiTests: XCTestCase {
    func testNotificationMethodNamesMapToSubscribeAndUnsubscribe() {
        XCTAssertEqual(subscribeMethodName(for: "accountNotifications"), "accountSubscribe")
        XCTAssertEqual(unsubscribeMethodName(for: "accountNotifications"), "accountUnsubscribe")
        XCTAssertEqual(subscribeMethodName(for: "slotsUpdatesNotifications"), "slotsUpdatesSubscribe")
        XCTAssertEqual(unsubscribeMethodName(for: "slotsUpdatesNotifications"), "slotsUpdatesUnsubscribe")
    }

    func testDefaultRequestTransformerAppliesCommitment() throws {
        let api = createSolanaRpcSubscriptionsApi(
            RequestTransformerConfig(defaultCommitment: .confirmed)
        )
        let address = try Addresses.address("Vote111111111111111111111111111111111111111")
        let plan = try api.accountNotifications(address: address)
        guard case let .array(params) = plan.request.params else {
            return XCTFail("Expected params array")
        }
        XCTAssertEqual(params.count, 2)
        XCTAssertEqual(params[0], .string(address.rawValue))
        XCTAssertEqual(params[1].value(for: "commitment"), .string("confirmed"))
    }

    func testSolanaRpcSubscriptionsApiSynthesizesPubSubPlanNames() async throws {
        let api = createSolanaRpcSubscriptionsApi()
        let plan = try api.slotNotifications()
        let recording = makeRecordingChannel()
        let signal = AbortSignal()
        let publisherTask = Task {
            try await plan.execute(RpcSubscriptionsPlanExecutionConfig(channel: recording.channel, signal: signal))
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        let subscribeMessage = try XCTUnwrap(recording.sent.withLock { $0.first as? RpcMessage })
        XCTAssertEqual(subscribeMessage.method, "slotSubscribe")
        recording.publisher.publish("message", RpcResponseData.result(id: subscribeMessage.id, value: .number(1)))
        _ = try await publisherTask.value
        signal.abort()
        try await Task.sleep(nanoseconds: 1_000_000)
        let sentMethods = recording.sent.withLock { $0.compactMap { ($0 as? RpcMessage)?.method } }
        XCTAssertTrue(sentMethods.contains("slotUnsubscribe"))
    }

    func testStableAndUnstableHelpersBuildExpectedPlans() throws {
        let stable = createSolanaRpcSubscriptionsApi()
        let unstable = createSolanaRpcSubscriptionsApi_UNSTABLE()
        let address = try Addresses.address("Vote111111111111111111111111111111111111111")
        XCTAssertEqual(try stable.logsNotifications(filter: .string("all")).request.methodName, "logsNotifications")
        XCTAssertEqual(try stable.programNotifications(programId: address).request.methodName, "programNotifications")
        XCTAssertEqual(try stable.rootNotifications().request.methodName, "rootNotifications")
        XCTAssertEqual(try stable.signatureNotifications(signature: Signature(rawValue: "abc")).request.methodName, "signatureNotifications")
        XCTAssertEqual(try unstable.blockNotifications(filter: .string("all")).request.methodName, "blockNotifications")
        XCTAssertEqual(try unstable.slotsUpdatesNotifications().request.methodName, "slotsUpdatesNotifications")
        XCTAssertEqual(try unstable.voteNotifications().request.methodName, "voteNotifications")
    }

    func testExplicitNullConfigRemainsInParams() throws {
        let api = createSolanaRpcSubscriptionsApi()
        let address = try Addresses.address("Vote111111111111111111111111111111111111111")
        let plan = try api.accountNotifications(address: address, config: .null)

        XCTAssertEqual(plan.request.params, .array([.string(address.rawValue), .null]))
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

private extension RpcJsonValue {
    func value(for key: String) -> RpcJsonValue? {
        guard case let .object(members) = self else {
            return nil
        }
        return members.first { $0.key == key }?.value
    }
}
