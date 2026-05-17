import os
import Promises
import SolanaErrors
@testable import Subscribable
import XCTest

final class SubscribableRuntimeBehaviorTests: XCTestCase {
    func testAsyncIterableThrowsFirstErrorForActiveAndNewIteratorsThenFinishes() async throws {
        let publisher = EventDataPublisher()
        let sequence = createAsyncIterableFromDataPublisher(
            abortSignal: AbortSignal(),
            dataChannelName: "data",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: String.self
        )
        let firstIterator = sequence.makeAsyncIterator()
        let secondIterator = sequence.makeAsyncIterator()
        let first = Task { try await firstIterator.next() }
        let second = Task { try await secondIterator.next() }
        try await subscribableRuntimeSpin()

        publisher.publish("error", SubscribableRuntimeError(message: "boom"))

        for task in [first, second] {
            do {
                _ = try await task.value
                XCTFail("Expected iterator error")
            } catch let error as SubscribableRuntimeError {
                XCTAssertEqual(error.message, "boom")
            }
        }
        let valueAfterError = try await firstIterator.next()
        XCTAssertNil(valueAfterError)

        let lateIterator = sequence.makeAsyncIterator()
        do {
            _ = try await lateIterator.next()
            XCTFail("Expected first error for late iterator")
        } catch let error as SubscribableRuntimeError {
            XCTAssertEqual(error.message, "boom")
        }
    }

    func testEventPublisherPayloadsChannelsAndIndependentCancellation() {
        let publisher = EventDataPublisher()
        let firstValues = OSAllocatedUnfairLock(initialState: [String]())
        let secondValues = OSAllocatedUnfairLock(initialState: [String]())
        let nilPayloads = OSAllocatedUnfairLock(initialState: 0)
        let abortSignal = AbortSignal()
        let firstUnsubscribe = publisher.on("data", subscriber: { payload in
            if payload == nil {
                nilPayloads.withLock { $0 += 1 }
            }
            if let value = payload as? String {
                firstValues.withLock { $0.append(value) }
            }
        })
        _ = publisher.on("data", subscriber: { payload in
            if let value = payload as? String {
                secondValues.withLock { $0.append(value) }
            }
        }, options: .init(signal: abortSignal))
        _ = publisher.on("other", subscriber: { payload in
            if let value = payload as? String {
                firstValues.withLock { $0.append("other:\(value)") }
            }
        })

        publisher.publish("data")
        publisher.publish("data", "one")
        abortSignal.abort()
        publisher.publish("data", "two")
        firstUnsubscribe()
        firstUnsubscribe()
        publisher.publish("data", "three")

        XCTAssertEqual(nilPayloads.withLock { $0 }, 1)
        XCTAssertEqual(firstValues.withLock { $0 }, ["one", "two"])
        XCTAssertEqual(secondValues.withLock { $0 }, ["one"])
    }

    func testDemultiplexedPublisherSharesSourceUntilLastCancellation() throws {
        let source = SubscribableRuntimeCountingPublisher()
        let transformCount = OSAllocatedUnfairLock(initialState: 0)
        let firstValues = OSAllocatedUnfairLock(initialState: [String]())
        let secondValues = OSAllocatedUnfairLock(initialState: [String]())
        let secondAbortSignal = AbortSignal()
        let demuxed = demultiplexDataPublisher(source, sourceChannelName: "source") { payload in
            transformCount.withLock { $0 += 1 }
            guard let value = payload as? String else {
                return nil
            }
            return ("target:\(value)", value.uppercased())
        }

        source.publish("source", "a")
        XCTAssertEqual(source.subscribeCalls, 0)
        XCTAssertEqual(transformCount.withLock { $0 }, 0)

        let firstUnsubscribe = try demuxed.on("target:a", subscriber: { payload in
            if let value = payload as? String {
                firstValues.withLock { $0.append(value) }
            }
        })
        _ = try demuxed.on("target:a", subscriber: { payload in
            if let value = payload as? String {
                secondValues.withLock { $0.append(value) }
            }
        }, options: .init(signal: secondAbortSignal))
        XCTAssertEqual(source.subscribeCalls, 1)

        source.publish("source", "a")
        XCTAssertEqual(firstValues.withLock { $0 }, ["A"])
        XCTAssertEqual(secondValues.withLock { $0 }, ["A"])
        XCTAssertEqual(transformCount.withLock { $0 }, 1)

        firstUnsubscribe()
        XCTAssertEqual(source.unsubscribeCalls, 0)
        secondAbortSignal.abort()
        secondAbortSignal.abort()
        firstUnsubscribe()
        XCTAssertEqual(source.unsubscribeCalls, 1)
    }

    func testReactiveActionStoreReturnsResultsForwardsInputsAndPreservesDataOnFailure() async throws {
        let inputs = OSAllocatedUnfairLock(initialState: [[String]]())
        let signals = OSAllocatedUnfairLock(initialState: [AbortSignal]())
        let store: ReactiveActionStore<String> = createReactiveActionStore { signal, args in
            signals.withLock { $0.append(signal) }
            let strings = args.compactMap { $0 as? String }
            inputs.withLock { $0.append(strings) }
            if strings.first == "fail" {
                throw SubscribableRuntimeError(message: "failed")
            }
            return strings.joined(separator: ":")
        }

        store.dispatch("fire", "forget")
        try await subscribableRuntimeWaitUntil { store.getState().status == .success }
        XCTAssertEqual(store.getState().data, "fire:forget")

        let result = try await store.dispatchAsync("ok", "value")
        XCTAssertEqual(result, "ok:value")
        XCTAssertEqual(store.getState().status, .success)
        XCTAssertEqual(store.getState().data, "ok:value")

        do {
            _ = try await store.dispatchAsync("fail")
            XCTFail("Expected action failure")
        } catch let error as SubscribableRuntimeError {
            XCTAssertEqual(error.message, "failed")
        }
        XCTAssertEqual(store.getState().status, .error)
        XCTAssertEqual(store.getState().data, "ok:value")
        XCTAssertEqual((store.getState().error as? SubscribableRuntimeError)?.message, "failed")
        XCTAssertFalse(try XCTUnwrap(signals.withLock { $0.last }).aborted)
        XCTAssertEqual(inputs.withLock { $0 }, [["fire", "forget"], ["ok", "value"], ["fail"]])
    }

    func testReactiveStreamFactoryAbortStopsInnerSignalsAndPreventsRetry() async throws {
        let factory = SubscribableRuntimePublisherFactory()
        let abortSignal = AbortSignal()
        let notifications = OSAllocatedUnfairLock(initialState: 0)
        let store = createReactiveStoreFromDataPublisherFactory(
            abortSignal: abortSignal,
            createDataPublisher: { await factory.create() },
            dataChannelName: "data",
            errorChannelName: "error",
            as: String.self
        )
        store.subscribe {
            notifications.withLock { $0 += 1 }
        }
        try await subscribableRuntimeWaitUntil { await factory.callCount() == 1 }
        let firstPublisher = try await factory.publisher(at: 0)
        try await subscribableRuntimeWaitUntil {
            firstPublisher.hasSignal(channel: "data") && firstPublisher.hasSignal(channel: "error")
        }
        firstPublisher.publish("data", "old")
        firstPublisher.publish("error", SubscribableRuntimeError(message: "stream failed"))
        try await subscribableRuntimeWaitUntil { store.getUnifiedState().status == .error }
        XCTAssertEqual(store.getUnifiedState().status, .error)
        XCTAssertEqual(store.getState(), "old")
        XCTAssertEqual((store.getError() as? SubscribableRuntimeError)?.message, "stream failed")

        abortSignal.abort(reason: SubscribableRuntimeError(message: "caller stopped"))
        try await subscribableRuntimeWaitUntil { firstPublisher.signalAborted(channel: "data") }
        let notificationsBeforeRetry = notifications.withLock { $0 }
        try store.retry()
        try await subscribableRuntimeSpin()

        let callCount = await factory.callCount()
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(store.getUnifiedState().status, .error)
        XCTAssertEqual(store.getState(), "old")
        XCTAssertEqual(notifications.withLock { $0 }, notificationsBeforeRetry)
    }
}

private final class SubscribableRuntimeCountingPublisher: DataPublisher {
    private struct State: Sendable {
        var subscribers: [UUID: (channel: String, subscriber: DataPublisherSubscriber)] = [:]
        var subscribeCalls = 0
        var unsubscribeCalls = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var subscribeCalls: Int {
        state.withLock(\.subscribeCalls)
    }

    var unsubscribeCalls: Int {
        state.withLock(\.unsubscribeCalls)
    }

    func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe {
        if options.signal?.aborted == true {
            return {}
        }
        let id = UUID()
        state.withLock { state in
            state.subscribeCalls += 1
            state.subscribers[id] = (channelName, subscriber)
        }
        let once = SubscribableRuntimeOnce()
        return { [state] in
            once.run {
                state.withLock { state in
                    if state.subscribers.removeValue(forKey: id) != nil {
                        state.unsubscribeCalls += 1
                    }
                }
            }
        }
    }

    func publish(_ channelName: String, _ payload: DataPublisherPayload = nil) {
        let subscribers = state.withLock { state in
            state.subscribers.values
                .filter { $0.channel == channelName }
                .map(\.subscriber)
        }
        for subscriber in subscribers {
            subscriber(payload)
        }
    }
}

private actor SubscribableRuntimePublisherFactory {
    private var publishers: [SubscribableRuntimeCapturingPublisher] = []

    func create() -> any DataPublisher {
        let publisher = SubscribableRuntimeCapturingPublisher()
        publishers.append(publisher)
        return publisher
    }

    func publisher(at index: Int) throws -> SubscribableRuntimeCapturingPublisher {
        guard publishers.indices.contains(index) else {
            throw SubscribableRuntimeError(message: "missing publisher")
        }
        return publishers[index]
    }

    func callCount() -> Int {
        publishers.count
    }
}

private final class SubscribableRuntimeCapturingPublisher: DataPublisher {
    private let publisher = EventDataPublisher()
    private let signals = OSAllocatedUnfairLock(initialState: [String: AbortSignal]())

    func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe {
        if let signal = options.signal {
            signals.withLock { $0[channelName] = signal }
        }
        return publisher.on(channelName, subscriber: subscriber, options: options)
    }

    func publish(_ channelName: String, _ payload: DataPublisherPayload = nil) {
        publisher.publish(channelName, payload)
    }

    func signalAborted(channel: String) -> Bool {
        signals.withLock { $0[channel]?.aborted ?? false }
    }

    func hasSignal(channel: String) -> Bool {
        signals.withLock { $0[channel] != nil }
    }
}

private final class SubscribableRuntimeOnce: Sendable {
    private let didRun = OSAllocatedUnfairLock(initialState: false)

    func run(_ body: () -> Void) {
        let shouldRun = didRun.withLock { didRun in
            if didRun {
                return false
            }
            didRun = true
            return true
        }
        if shouldRun {
            body()
        }
    }
}

private struct SubscribableRuntimeError: Error, Sendable, Equatable {
    let message: String
}

private func subscribableRuntimeWaitUntil(
    _ condition: @escaping @Sendable () async -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) async throws {
    for _ in 0 ..< 100 {
        if await condition() {
            return
        }
        try await subscribableRuntimeSpin()
    }
    XCTFail("Condition was not met", file: file, line: line)
}

private func subscribableRuntimeSpin() async throws {
    await Task.yield()
    try await Task.sleep(nanoseconds: 1_000_000)
}
