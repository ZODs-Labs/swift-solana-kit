import os
import Promises
import SolanaErrors
@testable import Subscribable
import XCTest

final class SubscribableDetailedBehaviorTests: XCTestCase {
    func testEventPublisherFiltersChannelsAndSnapshotsSubscribersDuringPublish() {
        let publisher = EventDataPublisher()
        let received = OSAllocatedUnfairLock(initialState: [String]())
        let firstUnsubscribe = OSAllocatedUnfairLock<DataPublisherUnsubscribe?>(initialState: nil)

        let unsubscribe = publisher.on("data", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append("first:\(value)") }
            }
            firstUnsubscribe.withLock { $0 }?()
        })
        firstUnsubscribe.withLock { $0 = unsubscribe }
        _ = publisher.on("data", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append("second:\(value)") }
            }
        })
        _ = publisher.on("other", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append("other:\(value)") }
            }
        })

        publisher.publish("data", "one")
        publisher.publish("data", "two")

        let values = received.withLock { $0 }
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(Set(values.prefix(2)), Set(["first:one", "second:one"]))
        XCTAssertEqual(values.dropFirst(2), ["second:two"])
    }

    func testAsyncIterableRejectsConcurrentPollAndIgnoresWrongPayloadType() async throws {
        let publisher = EventDataPublisher()
        let sequence = createAsyncIterableFromDataPublisher(
            abortSignal: AbortSignal(),
            dataChannelName: "data",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: String.self
        )
        let iterator = sequence.makeAsyncIterator()
        let first = Task { try await iterator.next() }
        try await Task.sleep(nanoseconds: 1_000_000)

        publisher.publish("data", 42)
        let second = Task { try await iterator.next() }

        do {
            _ = try await second.value
            XCTFail("Expected concurrent poll to throw")
        } catch let error as SolanaError {
            XCTAssertEqual(
                error.code,
                SolanaErrorCode.invariantViolationSubscriptionIteratorMustNotPollBeforeResolvingExistingMessagePromise.rawValue
            )
        }

        publisher.publish("data", "value")
        let firstValue = try await first.value
        XCTAssertEqual(firstValue, "value")
    }

    func testReactiveActionStoreListenersObserveTransitionsAndCanUnsubscribe() async throws {
        let store: ReactiveActionStore<String> = createReactiveActionStore { _ in
            "done"
        }
        let statuses = OSAllocatedUnfairLock(initialState: [ReactiveActionStatus]())
        let unsubscribe = store.subscribe {
            statuses.withLock { $0.append(store.getState().status) }
        }

        let result = try await store.dispatchAsync()
        unsubscribe()
        store.reset()

        XCTAssertEqual(result, "done")
        XCTAssertEqual(statuses.withLock { $0 }, [.running, .success])
        XCTAssertEqual(store.getState().status, .idle)
    }

    func testReactiveStoreFactoryFailureCanRetryToLoadedState() async throws {
        let factory = SubscribableThrowingPublisherFactory()
        let store = createReactiveStoreFromDataPublisherFactory(
            abortSignal: AbortSignal(),
            createDataPublisher: { try await factory.create() },
            dataChannelName: "data",
            errorChannelName: "error",
            as: String.self
        )
        try await subscribableWaitUntil { store.getUnifiedState().status == .error }

        XCTAssertEqual((store.getError() as? SubscribableDetailedError)?.message, "start")
        try store.retry()
        XCTAssertEqual(store.getUnifiedState().status, .retrying)

        let publisher = try await factory.waitForPublisher(at: 0)
        publisher.publish("data", "fresh")

        XCTAssertEqual(store.getUnifiedState().status, .loaded)
        XCTAssertEqual(store.getState(), "fresh")
    }
}

private actor SubscribableThrowingPublisherFactory {
    private var calls = 0
    private var publishers: [EventDataPublisher] = []

    func create() throws -> any DataPublisher {
        calls += 1
        if calls == 1 {
            throw SubscribableDetailedError(message: "start")
        }
        let publisher = EventDataPublisher()
        publishers.append(publisher)
        return publisher
    }

    func publisher(at index: Int) throws -> EventDataPublisher {
        guard publishers.indices.contains(index) else {
            throw SubscribableDetailedError(message: "missing publisher")
        }
        return publishers[index]
    }

    func waitForPublisher(at index: Int) async throws -> EventDataPublisher {
        for _ in 0..<100 {
            if publishers.indices.contains(index) {
                return publishers[index]
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw SubscribableDetailedError(message: "missing publisher")
    }
}

private struct SubscribableDetailedError: Error, Sendable, Equatable {
    let message: String
}

private func subscribableWaitUntil(_ condition: @escaping @Sendable () -> Bool) async throws {
    for _ in 0..<100 {
        if condition() {
            return
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTFail("Condition was not met")
}
