import Foundation
public import Promises
import SolanaErrors
import os

public typealias DataPublisherPayload = (any Sendable)?
public typealias DataPublisherSubscriber = @Sendable (DataPublisherPayload) -> Void
public typealias DataPublisherUnsubscribe = @Sendable () -> Void
public typealias ReactiveListener = @Sendable () -> Void

public struct DataPublisherSubscriptionOptions: Sendable {
    public let signal: AbortSignal?

    public init(signal: AbortSignal? = nil) {
        self.signal = signal
    }
}

public protocol DataPublisher: Sendable {
    @discardableResult
    func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe
}

public extension DataPublisher {
    @discardableResult
    func on(_ channelName: String, subscriber: @escaping DataPublisherSubscriber) throws -> DataPublisherUnsubscribe {
        try on(channelName, subscriber: subscriber, options: .init())
    }
}

public final class EventDataPublisher: DataPublisher {
    private struct Subscription: Sendable {
        let channelName: String
        let subscriber: DataPublisherSubscriber
        var removeAbortHandler: DataPublisherUnsubscribe?
    }

    private struct State: Sendable {
        var subscriptions: [UUID: Subscription] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    @discardableResult
    public func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions = .init()
    ) -> DataPublisherUnsubscribe {
        if options.signal?.aborted == true {
            return {}
        }
        let id = UUID()
        state.withLock { state in
            state.subscriptions[id] = Subscription(channelName: channelName, subscriber: subscriber, removeAbortHandler: nil)
        }
        if let signal = options.signal {
            let removeAbortHandler = signal.addAbortHandler { [weak self] _ in
                self?.removeSubscription(id)
            }
            state.withLock { state in
                if var subscription = state.subscriptions[id] {
                    subscription.removeAbortHandler = removeAbortHandler
                    state.subscriptions[id] = subscription
                } else {
                    removeAbortHandler()
                }
            }
            if signal.aborted {
                removeSubscription(id)
            }
        }
        let once = OnceToken()
        return { [weak self] in
            once.run {
                self?.removeSubscription(id)
            }
        }
    }

    public func publish(_ channelName: String, _ payload: DataPublisherPayload = nil) {
        let subscribers = state.withLock { state in
            state.subscriptions.values
                .filter { $0.channelName == channelName }
                .map(\.subscriber)
        }
        for subscriber in subscribers {
            subscriber(payload)
        }
    }

    private func removeSubscription(_ id: UUID) {
        let removeAbortHandler = state.withLock { state in
            state.subscriptions.removeValue(forKey: id)?.removeAbortHandler
        }
        removeAbortHandler?()
    }
}

public func getDataPublisherFromEventEmitter(_ eventEmitter: EventDataPublisher) -> any DataPublisher {
    eventEmitter
}

public func demultiplexDataPublisher(
    _ publisher: any DataPublisher,
    sourceChannelName: String,
    messageTransformer: @escaping @Sendable (DataPublisherPayload) -> (destinationChannelName: String, message: DataPublisherPayload)?
) -> any DataPublisher {
    DemultiplexedDataPublisher(
        publisher: publisher,
        sourceChannelName: sourceChannelName,
        messageTransformer: messageTransformer
    )
}

public struct AsyncDataPublisherSequence<Element: Sendable>: AsyncSequence, Sendable {
    public typealias AsyncIterator = Iterator
    public typealias Element = Element

    private let abortSignal: AbortSignal
    private let state: AsyncPublisherState<Element>

    init(
        abortSignal: AbortSignal,
        dataChannelName: String,
        dataPublisher: any DataPublisher,
        errorChannelName: String
    ) {
        self.abortSignal = abortSignal
        state = AsyncPublisherState<Element>()
        let unsubscribers: (data: DataPublisherUnsubscribe, error: DataPublisherUnsubscribe)
        do {
            let dataUnsubscribe = try dataPublisher.on(dataChannelName, subscriber: { [state] payload in
                guard let value = payload as? Element else {
                    return
                }
                state.publishData(value)
            })
            let errorUnsubscribe = try dataPublisher.on(errorChannelName, subscriber: { [state] payload in
                state.publishError(payload.subscribableError(defaultMessage: "Published subscription error"))
            })
            unsubscribers = (dataUnsubscribe, errorUnsubscribe)
        } catch {
            let sendableError: any Error & Sendable = error
            state.publishError(sendableError)
            unsubscribers = ({}, {})
        }
        _ = abortSignal.addAbortHandler { [state] _ in
            unsubscribers.data()
            unsubscribers.error()
            state.abort()
        }
        if abortSignal.aborted {
            unsubscribers.data()
            unsubscribers.error()
            state.abort()
        }
    }

    public final class Iterator: AsyncIteratorProtocol, Sendable {
        private struct Lifecycle: Sendable {
            var started = false
            var finished = false
        }

        private let abortSignal: AbortSignal
        private let id: UUID
        private let state: AsyncPublisherState<Element>
        private let lifecycle = OSAllocatedUnfairLock(initialState: Lifecycle())

        fileprivate init(abortSignal: AbortSignal, id: UUID, state: AsyncPublisherState<Element>) {
            self.abortSignal = abortSignal
            self.id = id
            self.state = state
        }

        public func next() async throws -> Element? {
            let shouldStart = lifecycle.withLock { lifecycle in
                if lifecycle.finished {
                    return false
                }
                if !lifecycle.started {
                    lifecycle.started = true
                    return true
                }
                return false
            }
            if isFinished {
                return nil
            }
            if shouldStart {
                if abortSignal.aborted {
                    markFinished()
                    return nil
                }
                if let firstError = state.firstError() {
                    markFinished()
                    throw firstError
                }
                state.registerIterator(id)
            }
            do {
                if let value = try await state.next(for: id) {
                    return value
                }
                markFinished()
                return nil
            } catch is ExplicitAbortError {
                markFinished()
                return nil
            } catch {
                markFinished()
                throw error
            }
        }

        private var isFinished: Bool {
            lifecycle.withLock(\.finished)
        }

        private func markFinished() {
            lifecycle.withLock { lifecycle in
                lifecycle.finished = true
            }
        }
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(abortSignal: abortSignal, id: UUID(), state: state)
    }
}

public func createAsyncIterableFromDataPublisher<Element: Sendable>(
    abortSignal: AbortSignal,
    dataChannelName: String,
    dataPublisher: any DataPublisher,
    errorChannelName: String,
    as type: Element.Type
) -> AsyncDataPublisherSequence<Element> {
    AsyncDataPublisherSequence(
        abortSignal: abortSignal,
        dataChannelName: dataChannelName,
        dataPublisher: dataPublisher,
        errorChannelName: errorChannelName
    )
}

public enum ReactiveActionStatus: String, Sendable, Equatable {
    case error
    case idle
    case running
    case success
}

public struct ReactiveActionState<TResult: Sendable>: Sendable {
    public let data: TResult?
    public let error: (any Error & Sendable)?
    public let status: ReactiveActionStatus

    public init(data: TResult?, error: (any Error & Sendable)?, status: ReactiveActionStatus) {
        self.data = data
        self.error = error
        self.status = status
    }
}

public final class ReactiveActionStore<TResult: Sendable>: Sendable {
    private struct DispatchContext: Sendable {
        let controller: AbortSignal
        let previousData: TResult?
    }

    private struct State: Sendable {
        var currentController: AbortSignal?
        var listeners: [UUID: ReactiveListener] = [:]
        var actionState = ReactiveActionState<TResult>(data: nil, error: nil, status: .idle)
    }

    private let action: @Sendable (AbortSignal, [any Sendable]) async throws -> TResult
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(action: @escaping @Sendable (AbortSignal, [any Sendable]) async throws -> TResult) {
        self.action = action
    }

    public func dispatch(_ args: any Sendable...) {
        let context = beginDispatch()
        Task { [self, args, context] in
            _ = try? await finishDispatch(args, context: context)
        }
    }

    public func dispatchAsync(_ args: any Sendable...) async throws -> TResult {
        let context = beginDispatch()
        return try await finishDispatch(args, context: context)
    }

    public func getState() -> ReactiveActionState<TResult> {
        state.withLock(\.actionState)
    }

    public func reset() {
        let controller = state.withLock { state in
            let controller = state.currentController
            state.currentController = nil
            return controller
        }
        controller?.abort()
        setState(.init(data: nil, error: nil, status: .idle))
    }

    @discardableResult
    public func subscribe(_ listener: @escaping ReactiveListener) -> DataPublisherUnsubscribe {
        let id = UUID()
        state.withLock { state in
            state.listeners[id] = listener
        }
        let once = OnceToken()
        return { [weak self] in
            once.run {
                guard let self else {
                    return
                }
                _ = self.state.withLock { state in
                    state.listeners.removeValue(forKey: id)
                }
            }
        }
    }

    private func beginDispatch() -> DispatchContext {
        let controller = AbortSignal()
        let previous = state.withLock { state in
            let previous = (controller: state.currentController, data: state.actionState.data)
            state.currentController = controller
            return previous
        }
        previous.controller?.abort()
        setState(.init(data: previous.data, error: nil, status: .running))
        return DispatchContext(controller: controller, previousData: previous.data)
    }

    private func finishDispatch(_ args: [any Sendable], context: DispatchContext) async throws -> TResult {
        let controller = context.controller
        do {
            let result = try await getAbortablePromise({
                try await self.action(controller, args)
            }, abortSignal: controller)
            if let reason = controller.abortReason() {
                throw reason
            }
            setState(.init(data: result, error: nil, status: .success))
            return result
        } catch {
            if let reason = controller.abortReason() {
                throw reason
            }
            let sendableError: any Error & Sendable = error
            setState(.init(data: context.previousData, error: sendableError, status: .error))
            throw error
        }
    }

    private func setState(_ next: ReactiveActionState<TResult>) {
        let listeners = state.withLock { state -> [ReactiveListener] in
            if actionStatesMatchEnoughForNoop(state.actionState, next) {
                return []
            }
            state.actionState = next
            return Array(state.listeners.values)
        }
        for listener in listeners {
            listener()
        }
    }
}

public func createReactiveActionStore<TResult: Sendable>(
    _ action: @escaping @Sendable (AbortSignal, [any Sendable]) async throws -> TResult
) -> ReactiveActionStore<TResult> {
    ReactiveActionStore(action: action)
}

public func createReactiveActionStore<TResult: Sendable>(
    _ action: @escaping @Sendable (AbortSignal) async throws -> TResult
) -> ReactiveActionStore<TResult> {
    ReactiveActionStore { signal, _ in
        try await action(signal)
    }
}

public enum ReactiveStreamStatus: String, Sendable, Equatable {
    case error
    case loaded
    case loading
    case retrying
}

public struct ReactiveState<T: Sendable>: Sendable {
    public let data: T?
    public let error: (any Error & Sendable)?
    public let status: ReactiveStreamStatus

    public init(data: T?, error: (any Error & Sendable)?, status: ReactiveStreamStatus) {
        self.data = data
        self.error = error
        self.status = status
    }
}

public typealias ReactiveStore<T: Sendable> = ReactiveStreamStore<T>

public final class ReactiveStreamStore<T: Sendable>: Sendable {
    fileprivate enum Mode: Sendable {
        case publisher(any DataPublisher, dataChannelName: String, errorChannelName: String)
        case factory(@Sendable () async throws -> any DataPublisher, dataChannelName: String, errorChannelName: String)
    }

    private struct State: Sendable {
        var currentState = ReactiveState<T>(data: nil, error: nil, status: .loading)
        var listeners: [UUID: ReactiveListener] = [:]
        var innerSignal: AbortSignal?
        var outerAborted = false
    }

    private let abortSignal: AbortSignal
    private let mode: Mode
    private let state = OSAllocatedUnfairLock(initialState: State())

    fileprivate init(
        abortSignal: AbortSignal,
        mode: Mode
    ) {
        self.abortSignal = abortSignal
        self.mode = mode
        _ = abortSignal.addAbortHandler { [weak self] reason in
            self?.abortOuter(reason: reason)
        }
        if let reason = abortSignal.abortReason() {
            abortOuter(reason: reason)
        }
        connect(initial: true)
    }

    public func getError() -> (any Error & Sendable)? {
        state.withLock(\.currentState.error)
    }

    public func getState() -> T? {
        state.withLock(\.currentState.data)
    }

    public func getUnifiedState() -> ReactiveState<T> {
        state.withLock(\.currentState)
    }

    public func retry() throws {
        switch mode {
        case .publisher:
            throw SolanaError(.subscribableRetryNotSupported)
        case .factory:
            let shouldRetry = state.withLock { state -> Bool in
                if state.outerAborted || state.currentState.status != .error {
                    return false
                }
                state.currentState = .init(data: state.currentState.data, error: nil, status: .retrying)
                return true
            }
            if shouldRetry {
                notify()
                connect(initial: false)
            }
        }
    }

    @discardableResult
    public func subscribe(_ callback: @escaping ReactiveListener) -> DataPublisherUnsubscribe {
        let id = UUID()
        state.withLock { state in
            state.listeners[id] = callback
        }
        let once = OnceToken()
        return { [weak self] in
            once.run {
                guard let self else {
                    return
                }
                _ = self.state.withLock { state in
                    state.listeners.removeValue(forKey: id)
                }
            }
        }
    }

    private func connect(initial: Bool) {
        switch mode {
        case let .publisher(publisher, dataChannelName, errorChannelName):
            let inner = AbortSignal()
            state.withLock { state in
                state.innerSignal = inner
            }
            subscribe(publisher: publisher, dataChannelName: dataChannelName, errorChannelName: errorChannelName, innerSignal: inner)
        case let .factory(factory, dataChannelName, errorChannelName):
            let inner = AbortSignal()
            state.withLock { state in
                state.innerSignal = inner
            }
            Task { [weak self] in
                do {
                    let publisher = try await factory()
                    if inner.aborted {
                        return
                    }
                    self?.subscribe(
                        publisher: publisher,
                        dataChannelName: dataChannelName,
                        errorChannelName: errorChannelName,
                        innerSignal: inner
                    )
                } catch {
                    if inner.aborted {
                        return
                    }
                    let sendableError: any Error & Sendable = error
                    self?.setStreamState(.init(data: self?.getUnifiedState().data, error: sendableError, status: .error))
                    Task {
                        inner.abort(reason: sendableError)
                    }
                }
            }
        }
    }

    private func subscribe(
        publisher: any DataPublisher,
        dataChannelName: String,
        errorChannelName: String,
        innerSignal: AbortSignal
    ) {
        let options = DataPublisherSubscriptionOptions(signal: innerSignal)
        do {
            _ = try publisher.on(dataChannelName, subscriber: { [weak self] payload in
                guard let self, let value = payload as? T else {
                    return
                }
                self.setStreamState(.init(data: value, error: nil, status: .loaded))
            }, options: options)
            _ = try publisher.on(errorChannelName, subscriber: { [weak self] payload in
                guard let self else {
                    return
                }
                let error = payload.subscribableError(defaultMessage: "Published stream error")
                let didTransition = self.state.withLock { state -> Bool in
                    if state.currentState.status == .error {
                        return false
                    }
                    state.currentState = .init(data: state.currentState.data, error: error, status: .error)
                    return true
                }
                if didTransition {
                    innerSignal.abort(reason: error)
                    self.notify()
                }
            }, options: options)
        } catch {
            let sendableError: any Error & Sendable = error
            let didTransition = state.withLock { state -> Bool in
                if state.currentState.status == .error {
                    return false
                }
                state.currentState = .init(data: state.currentState.data, error: sendableError, status: .error)
                return true
            }
            if didTransition {
                innerSignal.abort(reason: sendableError)
                notify()
            }
        }
    }

    private func abortOuter(reason: (any Error & Sendable)? = nil) {
        let inner = state.withLock { state -> AbortSignal? in
            state.outerAborted = true
            return state.innerSignal
        }
        inner?.abort(reason: reason)
    }

    private func setStreamState(_ next: ReactiveState<T>) {
        let listeners = state.withLock { state -> [ReactiveListener] in
            state.currentState = next
            return Array(state.listeners.values)
        }
        for listener in listeners {
            listener()
        }
    }

    private func notify() {
        let listeners = state.withLock { state in Array(state.listeners.values) }
        for listener in listeners {
            listener()
        }
    }
}

public func createReactiveStoreFromDataPublisher<TData: Sendable>(
    abortSignal: AbortSignal,
    dataChannelName: String,
    dataPublisher: any DataPublisher,
    errorChannelName: String,
    as type: TData.Type
) -> ReactiveStreamStore<TData> {
    ReactiveStreamStore(
        abortSignal: abortSignal,
        mode: .publisher(dataPublisher, dataChannelName: dataChannelName, errorChannelName: errorChannelName)
    )
}

public func createReactiveStoreFromDataPublisherFactory<TData: Sendable>(
    abortSignal: AbortSignal,
    createDataPublisher: @escaping @Sendable () async throws -> any DataPublisher,
    dataChannelName: String,
    errorChannelName: String,
    as type: TData.Type
) -> ReactiveStreamStore<TData> {
    ReactiveStreamStore(
        abortSignal: abortSignal,
        mode: .factory(createDataPublisher, dataChannelName: dataChannelName, errorChannelName: errorChannelName)
    )
}

private final class DemultiplexedDataPublisher: DataPublisher {
    private struct State: Sendable {
        var innerUnsubscribe: DataPublisherUnsubscribe?
        var subscriberCount = 0
    }

    private let publisher: any DataPublisher
    private let sourceChannelName: String
    private let messageTransformer: @Sendable (DataPublisherPayload) -> (destinationChannelName: String, message: DataPublisherPayload)?
    private let eventTarget = EventDataPublisher()
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(
        publisher: any DataPublisher,
        sourceChannelName: String,
        messageTransformer: @escaping @Sendable (DataPublisherPayload) -> (destinationChannelName: String, message: DataPublisherPayload)?
    ) {
        self.publisher = publisher
        self.sourceChannelName = sourceChannelName
        self.messageTransformer = messageTransformer
    }

    @discardableResult
    func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe {
        if options.signal?.aborted == true {
            return {}
        }
        let shouldOpenSource = state.withLock { state in
            state.innerUnsubscribe == nil
        }
        let sourceUnsubscribe: DataPublisherUnsubscribe?
        if shouldOpenSource {
            sourceUnsubscribe = try publisher.on(sourceChannelName, subscriber: { [eventTarget, messageTransformer] payload in
                guard let transformed = messageTransformer(payload) else {
                    return
                }
                eventTarget.publish(transformed.destinationChannelName, transformed.message)
            })
        } else {
            sourceUnsubscribe = nil
        }
        if let sourceUnsubscribe {
            let shouldCloseUnusedSource = state.withLock { state -> Bool in
                if state.innerUnsubscribe == nil {
                    state.innerUnsubscribe = sourceUnsubscribe
                    state.subscriberCount += 1
                    return false
                }
                state.subscriberCount += 1
                return true
            }
            if shouldCloseUnusedSource {
                sourceUnsubscribe()
            }
        } else {
            state.withLock { state in
                state.subscriberCount += 1
            }
        }
        let eventUnsubscribe = eventTarget.on(channelName, subscriber: subscriber, options: options)
        let once = OnceToken()
        let removeAbortHandler = OSAllocatedUnfairLock(initialState: Optional<DataPublisherUnsubscribe>.none)
        let unsubscribe: DataPublisherUnsubscribe = { [weak self] in
            once.run {
                guard let self else {
                    return
                }
                let abortHandler = removeAbortHandler.withLock { handler -> DataPublisherUnsubscribe? in
                    let abortHandler = handler
                    handler = nil
                    return abortHandler
                }
                abortHandler?()
                let innerUnsubscribe = self.state.withLock { state -> DataPublisherUnsubscribe? in
                    state.subscriberCount -= 1
                    if state.subscriberCount == 0 {
                        let innerUnsubscribe = state.innerUnsubscribe
                        state.innerUnsubscribe = nil
                        return innerUnsubscribe
                    }
                    return nil
                }
                innerUnsubscribe?()
                eventUnsubscribe()
            }
        }
        if let signal = options.signal {
            let abortHandler = signal.addAbortHandler { _ in
                unsubscribe()
            }
            removeAbortHandler.withLock { handler in
                handler = abortHandler
            }
            if signal.aborted {
                unsubscribe()
            }
        }
        return unsubscribe
    }
}

fileprivate final class AsyncPublisherState<Element: Sendable>: Sendable {
    private enum QueueItem: Sendable {
        case data(Element)
        case error(any Error & Sendable)
        case explicitAbort
    }

    private enum IteratorState: Sendable {
        case idle([QueueItem])
        case waiting(CheckedContinuation<Element?, any Error>)
    }

    private struct State: Sendable {
        var aborted = false
        var firstError: (any Error & Sendable)?
        var iterators: [UUID: IteratorState] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func firstError() -> (any Error & Sendable)? {
        state.withLock(\.firstError)
    }

    func registerIterator(_ id: UUID) {
        state.withLock { state in
            state.iterators[id] = .idle([])
        }
    }

    func next(for id: UUID) async throws -> Element? {
        try await withCheckedThrowingContinuation { continuation in
            let immediate = state.withLock { state -> QueueItem? in
                guard let iterator = state.iterators[id] else {
                    state.iterators.removeValue(forKey: id)
                    continuation.resume(throwing: SolanaError(.invariantViolationSubscriptionIteratorStateMissing))
                    return nil
                }
                switch iterator {
                case var .idle(queue):
                    if !queue.isEmpty {
                        let item = queue.removeFirst()
                        state.iterators[id] = .idle(queue)
                        return item
                    }
                    if state.aborted {
                        state.iterators.removeValue(forKey: id)
                        continuation.resume(returning: nil)
                        return nil
                    }
                    state.iterators[id] = .waiting(continuation)
                    return nil
                case .waiting:
                    continuation.resume(
                        throwing: SolanaError(.invariantViolationSubscriptionIteratorMustNotPollBeforeResolvingExistingMessagePromise)
                    )
                    return nil
                }
            }
            if let immediate {
                resume(continuation, with: immediate, id: id)
            }
        }
    }

    func publishData(_ data: Element) {
        let continuations = state.withLock { state -> [CheckedContinuation<Element?, any Error>] in
            var continuations: [CheckedContinuation<Element?, any Error>] = []
            for (id, iterator) in state.iterators {
                switch iterator {
                case .waiting(let continuation):
                    state.iterators[id] = .idle([])
                    continuations.append(continuation)
                case var .idle(queue):
                    queue.append(.data(data))
                    state.iterators[id] = .idle(queue)
                }
            }
            return continuations
        }
        for continuation in continuations {
            continuation.resume(returning: data)
        }
    }

    func publishError(_ error: any Error & Sendable) {
        let continuations = state.withLock { state -> [CheckedContinuation<Element?, any Error>] in
            if state.firstError != nil {
                return []
            }
            state.firstError = error
            var continuations: [CheckedContinuation<Element?, any Error>] = []
            for (id, iterator) in state.iterators {
                switch iterator {
                case .waiting(let continuation):
                    state.iterators.removeValue(forKey: id)
                    continuations.append(continuation)
                case var .idle(queue):
                    queue.append(.error(error))
                    state.iterators[id] = .idle(queue)
                }
            }
            return continuations
        }
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    func abort() {
        let continuations = state.withLock { state -> [CheckedContinuation<Element?, any Error>] in
            if state.aborted {
                return []
            }
            state.aborted = true
            var continuations: [CheckedContinuation<Element?, any Error>] = []
            for (id, iterator) in state.iterators {
                switch iterator {
                case .waiting(let continuation):
                    state.iterators.removeValue(forKey: id)
                    continuations.append(continuation)
                case var .idle(queue):
                    queue.append(.explicitAbort)
                    state.iterators[id] = .idle(queue)
                }
            }
            return continuations
        }
        for continuation in continuations {
            continuation.resume(throwing: ExplicitAbortError())
        }
    }

    private func resume(_ continuation: CheckedContinuation<Element?, any Error>, with item: QueueItem, id: UUID) {
        switch item {
        case let .data(value):
            continuation.resume(returning: value)
        case let .error(error):
            _ = state.withLock { state in
                state.iterators.removeValue(forKey: id)
            }
            continuation.resume(throwing: error)
        case .explicitAbort:
            _ = state.withLock { state in
                state.iterators.removeValue(forKey: id)
            }
            continuation.resume(throwing: ExplicitAbortError())
        }
    }
}

private final class OnceToken: Sendable {
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

private struct ExplicitAbortError: Error, Sendable {}

private struct SubscribableError: Error, Sendable, Equatable {
    let message: String
}

private extension Optional where Wrapped == any Sendable {
    func subscribableError(defaultMessage: String) -> any Error & Sendable {
        if let error = self as? any Error & Sendable {
            return error
        }
        if let message = self as? String {
            return SubscribableError(message: message)
        }
        return SubscribableError(message: defaultMessage)
    }
}

private func actionStatesMatchEnoughForNoop<T>(_ current: ReactiveActionState<T>, _ next: ReactiveActionState<T>) -> Bool {
    current.status == next.status
        && current.data == nil
        && next.data == nil
        && current.error == nil
        && next.error == nil
}
