import os
import Promises
import RpcSpecTypes
@testable import RpcSubscriptions
import RpcSubscriptionsSpec
import RpcTypes
import SolanaErrors
import Subscribable
import XCTest

final class RpcSubscriptionsTests: XCTestCase {
    func testPlainJsonSerializationUsesNormalJsonRules() async throws {
        let publisher = EventDataPublisher()
        let sent = OSAllocatedUnfairLock(initialState: [DataPublisherPayload]())
        let raw = RpcSubscriptionsChannel(dataPublisher: publisher) { payload in
            sent.withLock { $0.append(payload) }
        }
        let channel = getRpcSubscriptionsChannelWithJSONSerialization(raw)
        let received = OSAllocatedUnfairLock(initialState: [RpcJsonValue]())
        _ = try channel.on("message", subscriber: { payload in
            if let value = payload as? RpcJsonValue {
                received.withLock { $0.append(value) }
            }
        })

        publisher.publish("message", #"{"value":9007199254740992}"#)
        XCTAssertEqual(received.withLock { $0.first?.value(for: "value") }, .number(9_007_199_254_740_992))

        try await channel.send("hello")
        XCTAssertEqual(sent.withLock { $0.first as? String }, #""hello""#)

        do {
            try await channel.send(RpcJsonValue.bigint("42"))
            XCTFail("Expected plain JSON serialization to reject bigint values")
        } catch {
            XCTAssertEqual((error as? SolanaError)?.code, SolanaErrorCode.malformedJSONRPCError.rawValue)
        }
    }

    func testBigIntJsonSerializationParsesInboundAndStringifiesOutbound() async throws {
        let publisher = EventDataPublisher()
        let sent = OSAllocatedUnfairLock(initialState: [DataPublisherPayload]())
        let raw = RpcSubscriptionsChannel(dataPublisher: publisher) { payload in
            sent.withLock { $0.append(payload) }
        }
        let channel = getRpcSubscriptionsChannelWithBigIntJSONSerialization(raw)
        let received = OSAllocatedUnfairLock(initialState: [RpcJsonValue]())
        _ = try channel.on("message", subscriber: { payload in
            if let value = payload as? RpcJsonValue {
                received.withLock { $0.append(value) }
            }
        })
        publisher.publish("message", #"{"value":9007199254740992}"#)
        XCTAssertEqual(received.withLock { $0.first?.value(for: "value") }, .bigint("9007199254740992"))

        try await channel.send(createRpcMessage(RpcRequest(methodName: "thingSubscribe", params: .array([.bigint("9007199254740992")]))))
        let sentString = try XCTUnwrap(sent.withLock { $0.first as? String })
        let sentJson = try parseJsonWithBigInts(sentString)
        XCTAssertEqual(sentJson.value(for: "method"), .string("thingSubscribe"))
        XCTAssertEqual(sentJson.value(for: "params"), .array([.bigint("9007199254740992")]))
    }

    func testTransportFromChannelCreatorExecutesPlanWithCreatedChannel() async throws {
        let publisher = EventDataPublisher()
        let channel = RpcSubscriptionsChannel(dataPublisher: publisher) { _ in }
        let didCreate = OSAllocatedUnfairLock(initialState: false)
        let didExecute = OSAllocatedUnfairLock(initialState: false)
        let transport = createRpcSubscriptionsTransportFromChannelCreator { _ in
            didCreate.withLock { $0 = true }
            return channel
        }
        _ = try await transport(
            RpcSubscriptionsTransportConfig(
                request: RpcRequest(methodName: "thingNotifications", params: .array([])),
                signal: AbortSignal(),
                execute: { config in
                    didExecute.withLock { $0 = true }
                    return config.channel
                }
            )
        )
        XCTAssertTrue(didCreate.withLock { $0 })
        XCTAssertTrue(didExecute.withLock { $0 })
    }

    func testCoalescingTransportSharesIdenticalSubscriptionsUntilAllAbort() async throws {
        let publisher = EventDataPublisher()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let innerSignal = OSAllocatedUnfairLock<AbortSignal?>(initialState: nil)
        let transport = getRpcSubscriptionsTransportWithSubscriptionCoalescing { config in
            calls.withLock { $0 += 1 }
            innerSignal.withLock { $0 = config.signal }
            return publisher
        }
        let signalA = AbortSignal()
        let signalB = AbortSignal()
        let request = RpcRequest(methodName: "accountNotifications", params: .array([.string("abc")]))
        let configA = RpcSubscriptionsTransportConfig(request: request, signal: signalA, execute: { _ in publisher })
        let configB = RpcSubscriptionsTransportConfig(request: request, signal: signalB, execute: { _ in publisher })

        async let publisherA = transport(configA)
        async let publisherB = transport(configB)
        _ = try await (publisherA, publisherB)
        XCTAssertEqual(calls.withLock { $0 }, 1)

        signalA.abort()
        try await Task.sleep(nanoseconds: 2_000_000)
        let capturedInnerSignal = try XCTUnwrap(innerSignal.withLock { $0 })
        let afterFirstAbort = capturedInnerSignal.aborted
        XCTAssertFalse(afterFirstAbort)

        signalB.abort()
        try await Task.sleep(nanoseconds: 2_000_000)
        let afterSecondAbort = capturedInnerSignal.aborted
        XCTAssertTrue(afterSecondAbort)
    }

    func testCoalescingTransportDoesNotTrapForLargeIntegerNumberParams() async throws {
        let publisher = EventDataPublisher()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let transport = getRpcSubscriptionsTransportWithSubscriptionCoalescing { _ in
            calls.withLock { $0 += 1 }
            return publisher
        }
        let request = RpcRequest(methodName: "accountNotifications", params: .array([.number(1e20)]))
        let configA = RpcSubscriptionsTransportConfig(request: request, signal: AbortSignal(), execute: { _ in publisher })
        let configB = RpcSubscriptionsTransportConfig(request: request, signal: AbortSignal(), execute: { _ in publisher })

        async let publisherA = transport(configA)
        async let publisherB = transport(configB)
        _ = try await (publisherA, publisherB)

        XCTAssertEqual(calls.withLock { $0 }, 1)
    }

    func testCoalescingNumberFormattingMatchesJSONStringifyThresholds() {
        XCTAssertEqual(subscriptionNumberString(42), "42")
        XCTAssertEqual(subscriptionNumberString(1e20), "100000000000000000000")
        XCTAssertEqual(subscriptionNumberString(1e21), "1e+21")
        XCTAssertEqual(subscriptionNumberString(1e-7), "1e-7")
        XCTAssertEqual(subscriptionNumberString(0.000001), "0.000001")
        XCTAssertEqual(subscriptionNumberString(1.2345678901234567), "1.2345678901234567")
        XCTAssertEqual(subscriptionNumberString(0.0000012345678901234567), "0.0000012345678901234567")
        XCTAssertEqual(subscriptionNumberString(12_345_678_901_234_568), "12345678901234568")
    }

    func testCoalescingTransportIgnoresOldSubscriberAbortAfterPublisherError() async throws {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let publishers = OSAllocatedUnfairLock(initialState: [EventDataPublisher]())
        let transport = getRpcSubscriptionsTransportWithSubscriptionCoalescing { _ in
            calls.withLock { $0 += 1 }
            let publisher = EventDataPublisher()
            publishers.withLock { $0.append(publisher) }
            return publisher
        }
        let request = RpcRequest(methodName: "accountNotifications", params: .array([.string("abc")]))
        let signalA = AbortSignal()
        _ = try await transport(
            RpcSubscriptionsTransportConfig(request: request, signal: signalA, execute: { _ in EventDataPublisher() })
        )
        publishers.withLock { $0.first }?.publish(
            "error",
            SolanaError(.rpcSubscriptionsChannelConnectionClosed)
        )
        try await Task.sleep(nanoseconds: 1_000_000)

        _ = try await transport(
            RpcSubscriptionsTransportConfig(request: request, signal: AbortSignal(), execute: { _ in EventDataPublisher() })
        )
        signalA.abort()
        try await Task.sleep(nanoseconds: 2_000_000)
        _ = try await transport(
            RpcSubscriptionsTransportConfig(request: request, signal: AbortSignal(), execute: { _ in EventDataPublisher() })
        )

        XCTAssertEqual(calls.withLock { $0 }, 2)
    }

    func testCoalescingTransportKeepsEntryWhenNewSubscriberArrivesAfterAbortTurn() async throws {
        let publisher = EventDataPublisher()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let innerSignal = OSAllocatedUnfairLock<AbortSignal?>(initialState: nil)
        let transport = getRpcSubscriptionsTransportWithSubscriptionCoalescing { config in
            calls.withLock { $0 += 1 }
            innerSignal.withLock { $0 = config.signal }
            return publisher
        }
        let request = RpcRequest(methodName: "accountNotifications", params: .array([.string("abc")]))
        let firstSignal = AbortSignal()

        _ = try await transport(
            RpcSubscriptionsTransportConfig(request: request, signal: firstSignal, execute: { _ in publisher })
        )
        firstSignal.abort()
        _ = try await transport(
            RpcSubscriptionsTransportConfig(request: request, signal: AbortSignal(), execute: { _ in publisher })
        )
        try await Task.sleep(nanoseconds: 2_000_000)

        XCTAssertEqual(calls.withLock { $0 }, 1)
        XCTAssertFalse(try XCTUnwrap(innerSignal.withLock { $0 }).aborted)
    }

    func testChannelPoolReusesChannelUntilCapacityIsReached() async throws {
        let createCount = OSAllocatedUnfairLock(initialState: 0)
        let createdSignals = OSAllocatedUnfairLock(initialState: [AbortSignal]())
        let createChannel: RpcSubscriptionsChannelCreator = { signal in
            createCount.withLock { $0 += 1 }
            createdSignals.withLock { $0.append(signal) }
            return RpcSubscriptionsChannel(dataPublisher: EventDataPublisher()) { _ in }
        }
        let pooled = getChannelPoolingChannelCreator(
            createChannel,
            config: ChannelPoolingConfig(maxSubscriptionsPerChannel: Int.max, minChannels: 1)
        )
        let signalA = AbortSignal()
        let signalB = AbortSignal()
        _ = try await pooled(signalA)
        _ = try await pooled(signalB)
        XCTAssertEqual(createCount.withLock { $0 }, 1)

        signalA.abort()
        try await Task.sleep(nanoseconds: 1_000_000)
        let pooledSignal = try XCTUnwrap(createdSignals.withLock { $0.first })
        let afterFirstAbort = pooledSignal.aborted
        XCTAssertFalse(afterFirstAbort)

        signalB.abort()
        try await Task.sleep(nanoseconds: 1_000_000)
        let afterSecondAbort = pooledSignal.aborted
        XCTAssertTrue(afterSecondAbort)
    }

    func testChannelPoolAbortsCreatedSignalSynchronouslyWhenLastConsumerAborts() async throws {
        let createdSignals = OSAllocatedUnfairLock(initialState: [AbortSignal]())
        let createChannel: RpcSubscriptionsChannelCreator = { signal in
            createdSignals.withLock { $0.append(signal) }
            return RpcSubscriptionsChannel(dataPublisher: EventDataPublisher()) { _ in }
        }
        let pooled = getChannelPoolingChannelCreator(
            createChannel,
            config: ChannelPoolingConfig(maxSubscriptionsPerChannel: Int.max, minChannels: 1)
        )
        let outerSignal = AbortSignal()

        _ = try await pooled(outerSignal)
        let createdSignal = try XCTUnwrap(createdSignals.withLock { $0.first })
        outerSignal.abort()

        XCTAssertTrue(createdSignal.aborted)
    }

    func testChannelPoolCreatesNewChannelAtCapacity() async throws {
        let createCount = OSAllocatedUnfairLock(initialState: 0)
        let createChannel: RpcSubscriptionsChannelCreator = { _ in
            createCount.withLock { $0 += 1 }
            return RpcSubscriptionsChannel(dataPublisher: EventDataPublisher()) { _ in }
        }
        let pooled = getChannelPoolingChannelCreator(
            createChannel,
            config: ChannelPoolingConfig(maxSubscriptionsPerChannel: 1, minChannels: 1)
        )
        _ = try await pooled(AbortSignal())
        _ = try await pooled(AbortSignal())
        XCTAssertEqual(createCount.withLock { $0 }, 2)
    }

    func testAutopingSendsPingPayloadAndStopsOnAbort() async throws {
        let publisher = EventDataPublisher()
        let sent = OSAllocatedUnfairLock(initialState: [RpcJsonValue]())
        let signal = AbortSignal()
        let channel = RpcSubscriptionsChannel(dataPublisher: publisher) { payload in
            if let value = payload as? RpcJsonValue {
                sent.withLock { $0.append(value) }
            }
        }
        let autopingChannel = getRpcSubscriptionsChannelWithAutoping(abortSignal: signal, channel: channel, intervalMs: 1)
        try await Task.sleep(nanoseconds: 10_000_000)
        signal.abort()
        _ = autopingChannel
        let ping = try XCTUnwrap(sent.withLock { $0.first })
        XCTAssertEqual(ping.value(for: "jsonrpc"), .string("2.0"))
        XCTAssertEqual(ping.value(for: "method"), .string("ping"))
    }

    func testAutopingContinuesAfterNonConnectionClosedSendError() async throws {
        let publisher = EventDataPublisher()
        let sendCount = OSAllocatedUnfairLock(initialState: 0)
        let autopingChannel = getRpcSubscriptionsChannelWithAutoping(
            abortSignal: AbortSignal(),
            channel: RpcSubscriptionsChannel(dataPublisher: publisher) { _ in
                sendCount.withLock { $0 += 1 }
                throw AbortError(reason: "temporary")
            },
            intervalMs: 1
        )

        try await Task.sleep(nanoseconds: 10_000_000)

        _ = autopingChannel
        XCTAssertGreaterThanOrEqual(sendCount.withLock { $0 }, 2)
    }

    func testAutopingStopsAfterConnectionClosedSendError() async throws {
        let publisher = EventDataPublisher()
        let sendCount = OSAllocatedUnfairLock(initialState: 0)
        let autopingChannel = getRpcSubscriptionsChannelWithAutoping(
            abortSignal: AbortSignal(),
            channel: RpcSubscriptionsChannel(dataPublisher: publisher) { _ in
                sendCount.withLock { $0 += 1 }
                throw SolanaError(.rpcSubscriptionsChannelConnectionClosed)
            },
            intervalMs: 1
        )

        try await Task.sleep(nanoseconds: 10_000_000)

        _ = autopingChannel
        XCTAssertEqual(sendCount.withLock { $0 }, 1)
    }

    func testDefaultTransportCoalescesSubscriptions() async throws {
        let publisher = EventDataPublisher()
        let channel = RpcSubscriptionsChannel(dataPublisher: publisher) { _ in }
        let createCount = OSAllocatedUnfairLock(initialState: 0)
        let transport = createDefaultRpcSubscriptionsTransport { _ in
            createCount.withLock { $0 += 1 }
            return channel
        }
        let request = RpcRequest(methodName: "accountNotifications", params: .array([.string("abc")]))
        let configA = RpcSubscriptionsTransportConfig(request: request, signal: AbortSignal(), execute: { _ in publisher })
        let configB = RpcSubscriptionsTransportConfig(request: request, signal: AbortSignal(), execute: { _ in publisher })

        async let first = transport(configA)
        async let second = transport(configB)
        _ = try await (first, second)
        XCTAssertEqual(createCount.withLock { $0 }, 1)
    }

    func testCreateSolanaRpcSubscriptionsFromTransportUsesDefaultApiConfig() async throws {
        let publisher = EventDataPublisher()
        let captured = OSAllocatedUnfairLock<RpcSubscriptionsTransportConfig?>(initialState: nil)
        let rpc = createSolanaRpcSubscriptionsFromTransport { config in
            captured.withLock { $0 = config }
            return publisher
        }
        let pending: PendingRpcSubscriptionsRequest<RpcJsonValue> = try rpc.request(
            "accountNotifications",
            params: [.string("Vote111111111111111111111111111111111111111")],
            as: RpcJsonValue.self
        )
        _ = try await pending.reactive(RpcSubscribeOptions(abortSignal: AbortSignal()))
        let request = try XCTUnwrap(captured.withLock { $0?.request })
        XCTAssertEqual(request.methodName, "accountNotifications")
        XCTAssertEqual(request.params.value(at: 1)?.value(for: "commitment"), .string("confirmed"))
    }

    func testDefaultChannelCreatorRejectsMalformedURL() async throws {
        do {
            _ = try createDefaultSolanaRpcSubscriptionsChannelCreator(
                DefaultRpcSubscriptionsChannelConfig(url: "%%%")
            )
            XCTFail("Expected malformed URL to throw during channel creator construction")
        } catch let error as any SolanaErrorCoded {
            XCTAssertEqual(error.code, SolanaErrorCode.rpcSubscriptionsChannelFailedToConnect.rawValue)
        }
    }

    func testSolanaRpcSubscriptionsRejectsMalformedURLDuringConstruction() throws {
        XCTAssertThrowsError(try createSolanaRpcSubscriptions("%%%")) { error in
            XCTAssertEqual((error as? any SolanaErrorCoded)?.code, SolanaErrorCode.rpcSubscriptionsChannelFailedToConnect.rawValue)
        }
    }

    func testSolanaRpcSubscriptionsConfigUsesClusterUrlAsTransportUrl() {
        let config = defaultRpcSubscriptionsChannelConfig(
            clusterUrl: "wss://api.devnet.solana.com",
            config: DefaultRpcSubscriptionsChannelConfig(
                url: "wss://example.invalid",
                intervalMs: 123,
                maxSubscriptionsPerChannel: 7,
                minChannels: 2,
                sendBufferHighWatermark: 4_096
            )
        )

        XCTAssertEqual(config.url, "wss://api.devnet.solana.com")
        XCTAssertEqual(config.intervalMs, 123)
        XCTAssertEqual(config.maxSubscriptionsPerChannel, 7)
        XCTAssertEqual(config.minChannels, 2)
        XCTAssertEqual(config.sendBufferHighWatermark, 4_096)
    }
}

private extension RpcJsonValue {
    func value(for key: String) -> RpcJsonValue? {
        guard case let .object(members) = self else {
            return nil
        }
        return members.first { $0.key == key }?.value
    }

    func value(at index: Int) -> RpcJsonValue? {
        guard case let .array(values) = self, values.indices.contains(index) else {
            return nil
        }
        return values[index]
    }
}
