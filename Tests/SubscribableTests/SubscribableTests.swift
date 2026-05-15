import os
import Promises
import SolanaErrors
@testable import Subscribable
import XCTest

final class SubscribableTests: XCTestCase {
    func testEventDataPublisherUnsubscribeAndAbortAreIdempotent() async throws {
        let publisher = EventDataPublisher()
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let abortSignal = AbortSignal()
        let unsubscribe = publisher.on("data", subscriber: { _ in
            counter.withLock { $0 += 1 }
        }, options: .init(signal: abortSignal))

        publisher.publish("data", "one")
        XCTAssertEqual(counter.withLock { $0 }, 1)

        unsubscribe()
        unsubscribe()
        publisher.publish("data", "two")
        XCTAssertEqual(counter.withLock { $0 }, 1)

        let abortCounter = OSAllocatedUnfairLock(initialState: 0)
        _ = publisher.on("data", subscriber: { _ in
            abortCounter.withLock { $0 += 1 }
        }, options: .init(signal: abortSignal))
        abortSignal.abort()
        publisher.publish("data", "three")
        XCTAssertEqual(abortCounter.withLock { $0 }, 0)
    }

    func testAlreadyAbortedPublisherSubscriptionNeverReceivesSynchronousPublish() {
        let publisher = EventDataPublisher()
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let abortSignal = AbortSignal(abortedWith: AbortError(reason: "done"))

        _ = publisher.on("data", subscriber: { _ in
            counter.withLock { $0 += 1 }
        }, options: .init(signal: abortSignal))
        publisher.publish("data", "value")

        XCTAssertEqual(counter.withLock { $0 }, 0)
    }

    func testAlreadyAbortedDemultiplexedSubscriptionDoesNotOpenSourceSubscription() throws {
        let publisher = EventDataPublisher()
        let transformCount = OSAllocatedUnfairLock(initialState: 0)
        let received = OSAllocatedUnfairLock(initialState: [String]())
        let abortSignal = AbortSignal(abortedWith: AbortError(reason: "done"))
        let demuxed = demultiplexDataPublisher(publisher, sourceChannelName: "source") { payload in
            transformCount.withLock { $0 += 1 }
            guard let value = payload as? String else {
                return nil
            }
            return ("target", value)
        }

        _ = try demuxed.on("target", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        }, options: .init(signal: abortSignal))
        publisher.publish("source", "value")

        XCTAssertEqual(transformCount.withLock { $0 }, 0)
        XCTAssertTrue(received.withLock { $0.isEmpty })
    }

    func testDemultiplexedSubscriptionAbortDisposesSourceSynchronously() throws {
        let publisher = EventDataPublisher()
        let abortSignal = AbortSignal()
        let transformCount = OSAllocatedUnfairLock(initialState: 0)
        let demuxed = demultiplexDataPublisher(publisher, sourceChannelName: "source") { payload in
            transformCount.withLock { $0 += 1 }
            return ("target", payload)
        }

        _ = try demuxed.on("target", subscriber: { _ in }, options: .init(signal: abortSignal))
        abortSignal.abort()
        publisher.publish("source", "late")

        XCTAssertEqual(transformCount.withLock { $0 }, 0)
    }

    func testAsyncIterableDropsPrePollDataAndQueuesBeforeErrors() async throws {
        let publisher = EventDataPublisher()
        let sequence = createAsyncIterableFromDataPublisher(
            abortSignal: AbortSignal(),
            dataChannelName: "data",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: String.self
        )
        let iterator = sequence.makeAsyncIterator()

        publisher.publish("data", "lost")
        let first = Task { try await iterator.next() }
        try await Task.sleep(nanoseconds: 1_000_000)
        publisher.publish("data", "consumed")
        let firstValue = try await first.value
        XCTAssertEqual(firstValue, "consumed")

        publisher.publish("data", "queued")
        publisher.publish("error", TestError(message: "boom"))
        let queuedValue = try await iterator.next()
        XCTAssertEqual(queuedValue, "queued")
        do {
            _ = try await iterator.next()
            XCTFail("Expected queued error")
        } catch let error as TestError {
            XCTAssertEqual(error.message, "boom")
        }
    }

    func testAsyncIterableAbortFlushesQueuedDataThenEnds() async throws {
        let publisher = EventDataPublisher()
        let abortSignal = AbortSignal()
        let sequence = createAsyncIterableFromDataPublisher(
            abortSignal: abortSignal,
            dataChannelName: "data",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: String.self
        )
        let iterator = sequence.makeAsyncIterator()

        let first = Task { try await iterator.next() }
        try await Task.sleep(nanoseconds: 1_000_000)
        publisher.publish("data", "first")
        let firstValue = try await first.value
        XCTAssertEqual(firstValue, "first")

        publisher.publish("data", "queued")
        abortSignal.abort()
        let queuedValue = try await iterator.next()
        XCTAssertEqual(queuedValue, "queued")
        let ended = try await iterator.next()
        XCTAssertNil(ended)
    }

    func testDemultiplexDataPublisherIsLazyAndDisposesAfterLastSubscriber() throws {
        let publisher = EventDataPublisher()
        let transformCount = OSAllocatedUnfairLock(initialState: 0)
        let received = OSAllocatedUnfairLock(initialState: [String]())
        let demuxed = demultiplexDataPublisher(publisher, sourceChannelName: "source") { payload in
            transformCount.withLock { $0 += 1 }
            guard let value = payload as? String else {
                return nil
            }
            return ("target:\(value)", value.uppercased())
        }

        publisher.publish("source", "a")
        XCTAssertEqual(transformCount.withLock { $0 }, 0)

        let unsubscribe = try demuxed.on("target:a", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })
        publisher.publish("source", "a")
        XCTAssertEqual(transformCount.withLock { $0 }, 1)
        XCTAssertEqual(received.withLock { $0 }, ["A"])

        unsubscribe()
        unsubscribe()
        publisher.publish("source", "a")
        XCTAssertEqual(transformCount.withLock { $0 }, 1)
    }

    func testReactiveActionStorePreservesStaleDataAndAbortsSupersededDispatch() async throws {
        let store: ReactiveActionStore<String> = createReactiveActionStore { signal, args in
            let value = args.first as? String ?? "value"
            return try await getAbortablePromise({
                try await Task.sleep(nanoseconds: 20_000_000)
                return value
            }, abortSignal: signal)
        }

        XCTAssertEqual(store.getState().status, .idle)
        let firstResult = try await store.dispatchAsync("first")
        XCTAssertEqual(firstResult, "first")
        XCTAssertEqual(store.getState().status, .success)
        XCTAssertEqual(store.getState().data, "first")

        let first = Task { try await store.dispatchAsync("late") }
        try await Task.sleep(nanoseconds: 5_000_000)
        store.dispatch("winner")
        do {
            _ = try await first.value
            XCTFail("Expected superseded dispatch to abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, nil)
        }
        XCTAssertEqual(store.getState().status, .running)
        XCTAssertEqual(store.getState().data, "first")
        store.reset()
        XCTAssertEqual(store.getState().status, .idle)
        XCTAssertNil(store.getState().data)
    }

    func testReactiveActionStoreDispatchSetsRunningBeforeReturning() {
        let store: ReactiveActionStore<String> = createReactiveActionStore { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return "late"
        }

        store.dispatch()

        XCTAssertEqual(store.getState().status, .running)
        XCTAssertNil(store.getState().data)
        XCTAssertNil(store.getState().error)
    }

    func testReactiveActionStoreResetAbortsCurrentSignalSynchronously() async throws {
        let signals = OSAllocatedUnfairLock(initialState: [AbortSignal]())
        let store: ReactiveActionStore<String> = createReactiveActionStore { signal in
            signals.withLock { $0.append(signal) }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return "late"
        }

        store.dispatch()
        try await waitUntil { !signals.withLock(\.isEmpty) }
        let signal = try XCTUnwrap(signals.withLock { $0.first })

        store.reset()

        XCTAssertTrue(signal.aborted)
        XCTAssertEqual(store.getState().status, .idle)
    }

    func testReactiveStreamStorePreservesFirstErrorAndRejectsRetryWithoutFactory() throws {
        let publisher = EventDataPublisher()
        let store = createReactiveStoreFromDataPublisher(
            abortSignal: AbortSignal(),
            dataChannelName: "data",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: String.self
        )

        XCTAssertEqual(store.getUnifiedState().status, .loading)
        publisher.publish("data", "first")
        XCTAssertEqual(store.getUnifiedState().status, .loaded)
        XCTAssertEqual(store.getState(), "first")

        publisher.publish("error", TestError(message: "first"))
        publisher.publish("error", TestError(message: "second"))
        XCTAssertEqual(store.getUnifiedState().status, .error)
        XCTAssertEqual(store.getState(), "first")
        XCTAssertEqual((store.getError() as? TestError)?.message, "first")
        XCTAssertEqual(throwingCode { try store.retry() }, SolanaErrorCode.subscribableRetryNotSupported.rawValue)
    }

    func testReactiveStreamStoreAbortStopsUpdatesSynchronously() {
        let publisher = EventDataPublisher()
        let abortSignal = AbortSignal()
        let store = createReactiveStoreFromDataPublisher(
            abortSignal: abortSignal,
            dataChannelName: "data",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: String.self
        )

        abortSignal.abort(reason: TestError(message: "stop"))
        publisher.publish("data", "late")

        XCTAssertEqual(store.getUnifiedState().status, .loading)
        XCTAssertNil(store.getState())
    }

    func testReactiveStreamStoreFactoryRetriesWithFreshPublisher() async throws {
        let factory = PublisherFactory()
        let store = createReactiveStoreFromDataPublisherFactory(
            abortSignal: AbortSignal(),
            createDataPublisher: { await factory.create() },
            dataChannelName: "data",
            errorChannelName: "error",
            as: String.self
        )
        try await Task.sleep(nanoseconds: 10_000_000)
        let first = try await factory.publisher(at: 0)
        first.publish("data", "old")
        first.publish("error", TestError(message: "fail"))
        XCTAssertEqual(store.getUnifiedState().status, .error)
        XCTAssertEqual(store.getState(), "old")

        try store.retry()
        XCTAssertEqual(store.getUnifiedState().status, .retrying)
        XCTAssertEqual(store.getState(), "old")
        try await Task.sleep(nanoseconds: 10_000_000)
        let second = try await factory.publisher(at: 1)
        second.publish("data", "fresh")
        XCTAssertEqual(store.getUnifiedState().status, .loaded)
        XCTAssertEqual(store.getState(), "fresh")
    }
}

private actor PublisherFactory {
    private var publishers: [EventDataPublisher] = []

    func create() -> any DataPublisher {
        let publisher = EventDataPublisher()
        publishers.append(publisher)
        return publisher
    }

    func publisher(at index: Int) throws -> EventDataPublisher {
        guard publishers.indices.contains(index) else {
            throw TestError(message: "missing publisher")
        }
        return publishers[index]
    }
}

private struct TestError: Error, Sendable, Equatable {
    let message: String
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

private func waitUntil(_ condition: @escaping @Sendable () async -> Bool) async throws {
    for _ in 0..<100 {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTFail("Condition was not met")
}
