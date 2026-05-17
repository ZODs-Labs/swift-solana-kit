import os
import Promises
import RpcSpecTypes
@testable import RpcSubscriptions
import RpcSubscriptionsSpec
import RpcTypes
import SolanaErrors
import Subscribable
import XCTest

final class RpcSubscriptionsDetailedBehaviorTests: XCTestCase {
    func testCoalescingUsesStableKeysForObjectOrderAndNonFiniteNumbers() async throws {
        let publisher = EventDataPublisher()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let transport = getRpcSubscriptionsTransportWithSubscriptionCoalescing { _ in
            calls.withLock { $0 += 1 }
            return publisher
        }
        let firstObjectRequest = RpcRequest(
            methodName: "accountNotifications",
            params: .array([
                .object([
                    RpcJsonObjectMember("z", .number(2)),
                    RpcJsonObjectMember("a", .number(1)),
                ]),
            ])
        )
        let secondObjectRequest = RpcRequest(
            methodName: "accountNotifications",
            params: .array([
                .object([
                    RpcJsonObjectMember("a", .number(1)),
                    RpcJsonObjectMember("z", .number(2)),
                ]),
            ])
        )
        let firstNanRequest = RpcRequest(methodName: "logsNotifications", params: .array([.number(.nan)]))
        let secondNanRequest = RpcRequest(methodName: "logsNotifications", params: .array([.number(.nan)]))

        _ = try await transport(rpcSubscriptionsDetailedConfig(request: firstObjectRequest))
        _ = try await transport(rpcSubscriptionsDetailedConfig(request: secondObjectRequest))
        _ = try await transport(rpcSubscriptionsDetailedConfig(request: firstNanRequest))
        _ = try await transport(rpcSubscriptionsDetailedConfig(request: secondNanRequest))

        XCTAssertEqual(calls.withLock { $0 }, 2)
    }

    func testCoalescingForwardsRequestSignalAndExecuteFromFirstSubscriber() async throws {
        let returnedPublisher = EventDataPublisher()
        let channel = RpcSubscriptionsChannel(dataPublisher: EventDataPublisher()) { _ in }
        let capturedRequest = OSAllocatedUnfairLock<RpcRequest?>(initialState: nil)
        let capturedSignal = OSAllocatedUnfairLock<AbortSignal?>(initialState: nil)
        let executeCount = OSAllocatedUnfairLock(initialState: 0)
        let transport = getRpcSubscriptionsTransportWithSubscriptionCoalescing { config in
            capturedRequest.withLock { $0 = config.request }
            capturedSignal.withLock { $0 = config.signal }
            return try await config.execute(RpcSubscriptionsPlanExecutionConfig(channel: channel, signal: config.signal))
        }
        let request = RpcRequest(methodName: "accountNotifications", params: .array([.string("abc")]))
        let result = try await transport(
            RpcSubscriptionsTransportConfig(
                request: request,
                signal: AbortSignal(),
                execute: { config in
                    executeCount.withLock { $0 += 1 }
                    XCTAssertTrue(config.signal === capturedSignal.withLock { $0 })
                    return returnedPublisher
                }
            )
        )

        XCTAssertEqual(capturedRequest.withLock { $0 }, request)
        XCTAssertEqual(executeCount.withLock { $0 }, 1)
        XCTAssertTrue((result as? EventDataPublisher) === returnedPublisher)
    }

    func testChannelPoolCreatesMinimumChannelsBeforeReusingCapacity() async throws {
        let createCount = OSAllocatedUnfairLock(initialState: 0)
        let createChannel: RpcSubscriptionsChannelCreator = { _ in
            createCount.withLock { $0 += 1 }
            return RpcSubscriptionsChannel(dataPublisher: EventDataPublisher()) { _ in }
        }
        let pooled = getChannelPoolingChannelCreator(
            createChannel,
            config: ChannelPoolingConfig(maxSubscriptionsPerChannel: 2, minChannels: 2)
        )

        _ = try await pooled(AbortSignal())
        _ = try await pooled(AbortSignal())
        _ = try await pooled(AbortSignal())

        XCTAssertEqual(createCount.withLock { $0 }, 2)
    }

    func testChannelPoolDestroysErroredEntriesAndCreatesFreshChannels() async throws {
        let createCount = OSAllocatedUnfairLock(initialState: 0)
        let createdSignals = OSAllocatedUnfairLock(initialState: [AbortSignal]())
        let publishers = OSAllocatedUnfairLock(initialState: [EventDataPublisher]())
        let createChannel: RpcSubscriptionsChannelCreator = { signal in
            createCount.withLock { $0 += 1 }
            createdSignals.withLock { $0.append(signal) }
            let publisher = EventDataPublisher()
            publishers.withLock { $0.append(publisher) }
            return RpcSubscriptionsChannel(dataPublisher: publisher) { _ in }
        }
        let pooled = getChannelPoolingChannelCreator(
            createChannel,
            config: ChannelPoolingConfig(maxSubscriptionsPerChannel: Int.max, minChannels: 1)
        )

        _ = try await pooled(AbortSignal())
        publishers.withLock { $0.first }?.publish("error", AbortError(reason: "closed"))
        _ = try await pooled(AbortSignal())

        XCTAssertEqual(createCount.withLock { $0 }, 2)
        XCTAssertTrue(try XCTUnwrap(createdSignals.withLock { $0.first }).aborted)
        XCTAssertFalse(try XCTUnwrap(createdSignals.withLock { $0.last }).aborted)
    }

    func testDefaultSubscriptionClientReportsIntegerOverflowContext() {
        let rpc = createSolanaRpcSubscriptionsFromTransport { _ in
            EventDataPublisher()
        }

        do {
            _ = try rpc.request(
                "logsNotifications",
                params: [
                    .object([
                        RpcJsonObjectMember("mentions", .array([.bigint("9007199254740992")])),
                    ]),
                ],
                as: RpcJsonValue.self
            )
            XCTFail("Expected integer overflow")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.rpcIntegerOverflow.rawValue)
            XCTAssertEqual(error.context["argumentLabel"], .string("params"))
            XCTAssertEqual(error.context["methodName"], .string("logsNotifications"))
            XCTAssertEqual(error.context["optionalPathLabel"], .string(" at key path 0.mentions.0"))
            XCTAssertEqual(error.context["value"], .string("9007199254740992"))
        } catch {
            XCTFail("Expected SolanaError, got \(error)")
        }
    }

    func testDefaultChannelCreatorAcceptsOnlyWebSocketSchemes() throws {
        XCTAssertNoThrow(try createDefaultSolanaRpcSubscriptionsChannelCreator(
            DefaultRpcSubscriptionsChannelConfig(url: "wss://example.invalid")
        ))
        rpcSubscriptionsDetailedAssertThrowsCode(.rpcSubscriptionsChannelFailedToConnect) {
            _ = try createDefaultSolanaRpcSubscriptionsChannelCreator(
                DefaultRpcSubscriptionsChannelConfig(url: "https://example.invalid")
            )
        }
    }
}

private func rpcSubscriptionsDetailedConfig(request: RpcRequest) -> RpcSubscriptionsTransportConfig {
    RpcSubscriptionsTransportConfig(
        request: request,
        signal: AbortSignal(),
        execute: { _ in EventDataPublisher() }
    )
}

private func rpcSubscriptionsDetailedAssertThrowsCode(
    _ code: SolanaErrorCode,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () throws -> Void
) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
        guard let coded = error as? any SolanaErrorCoded else {
            return XCTFail("Expected SolanaErrorCoded, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(coded.code, code.rawValue, file: file, line: line)
    }
}
