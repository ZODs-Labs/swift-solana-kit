public import Promises
public import RpcTypes
public import Subscribable

public struct InitialValueAndSlotTrackingConfig<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
>: Sendable {
    public let abortSignal: AbortSignal
    public let rpcRequest: @Sendable (AbortSignal) async throws -> SolanaRpcResponse<TRpcValue>
    public let rpcSubscriptionRequest: @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SolanaRpcResponse<TSubscriptionValue>, any Error>
    public let rpcSubscriptionValueMapper: @Sendable (TSubscriptionValue) -> TItem
    public let rpcValueMapper: @Sendable (TRpcValue) -> TItem

    public init(
        abortSignal: AbortSignal,
        rpcRequest: @escaping @Sendable (AbortSignal) async throws -> SolanaRpcResponse<TRpcValue>,
        rpcSubscriptionRequest: @escaping @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SolanaRpcResponse<TSubscriptionValue>, any Error>,
        rpcSubscriptionValueMapper: @escaping @Sendable (TSubscriptionValue) -> TItem,
        rpcValueMapper: @escaping @Sendable (TRpcValue) -> TItem
    ) {
        self.abortSignal = abortSignal
        self.rpcRequest = rpcRequest
        self.rpcSubscriptionRequest = rpcSubscriptionRequest
        self.rpcSubscriptionValueMapper = rpcSubscriptionValueMapper
        self.rpcValueMapper = rpcValueMapper
    }
}

public typealias CreateReactiveStoreWithInitialValueAndSlotTrackingConfig<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
> = InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>

public func createAsyncGeneratorWithInitialValueAndSlotTracking<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
>(
    _ config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>
) -> InitialValueAndSlotTrackingAsyncSequence<TRpcValue, TSubscriptionValue, TItem> {
    kitCreateAsyncGeneratorWithInitialValueAndSlotTracking(config, slotState: KitSlotTrackingSlotState())
}

func kitCreateAsyncGeneratorWithInitialValueAndSlotTracking<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
>(
    _ config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>,
    slotState: KitSlotTrackingSlotState
) -> InitialValueAndSlotTrackingAsyncSequence<TRpcValue, TSubscriptionValue, TItem> {
    InitialValueAndSlotTrackingAsyncSequence(config: config, slotState: slotState)
}

public struct InitialValueAndSlotTrackingAsyncSequence<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
>: AsyncSequence, Sendable {
    public typealias Element = SolanaRpcResponse<TItem>
    public typealias AsyncIterator = Iterator

    private let runner: KitSlotTrackingAsyncRunner<TRpcValue, TSubscriptionValue, TItem>

    init(
        config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>,
        slotState: KitSlotTrackingSlotState
    ) {
        runner = KitSlotTrackingAsyncRunner(config: config, slotState: slotState)
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(runner: runner)
    }

    public final class Iterator: AsyncIteratorProtocol, Sendable {
        private let runner: KitSlotTrackingAsyncRunner<TRpcValue, TSubscriptionValue, TItem>

        init(runner: KitSlotTrackingAsyncRunner<TRpcValue, TSubscriptionValue, TItem>) {
            self.runner = runner
        }

        deinit {
            Task { [runner] in
                await runner.cancelFromConsumer()
            }
        }

        public func next() async throws -> Element? {
            try await runner.next()
        }
    }
}

public func createReactiveStoreWithInitialValueAndSlotTracking<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
>(
    _ config: CreateReactiveStoreWithInitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>
) -> Subscribable.ReactiveStreamStore<SolanaRpcResponse<TItem>> {
    let slotState = KitSlotTrackingSlotState()
    return createReactiveStoreFromDataPublisherFactory(
        abortSignal: config.abortSignal,
        createDataPublisher: {
            KitSlotTrackingDataPublisher(
                config: config,
                slotState: slotState,
                dataChannelName: "message",
                errorChannelName: "error"
            )
        },
        dataChannelName: "message",
        errorChannelName: "error",
        as: SolanaRpcResponse<TItem>.self
    )
}

actor KitSlotTrackingSlotState {
    private var lastUpdateSlot: Slot?

    func shouldAccept(slot: Slot) -> Bool {
        if let lastUpdateSlot, slot < lastUpdateSlot {
            return false
        }
        lastUpdateSlot = slot
        return true
    }
}

final class KitSlotTrackingDataPublisher<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
>: DataPublisher {
    private let coordinator = KitSlotTrackingDataPublisherCoordinator()
    private let config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>
    private let dataChannelName: String
    private let errorChannelName: String
    private let eventTarget = EventDataPublisher()
    private let slotState: KitSlotTrackingSlotState

    init(
        config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>,
        slotState: KitSlotTrackingSlotState,
        dataChannelName: String,
        errorChannelName: String
    ) {
        self.config = config
        self.slotState = slotState
        self.dataChannelName = dataChannelName
        self.errorChannelName = errorChannelName
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
        let unsubscribe = eventTarget.on(channelName, subscriber: subscriber, options: options)
        Task {
            if options.signal?.aborted == true {
                return
            }
            let startRequest = await coordinator.register(
                channelName: channelName,
                dataChannelName: dataChannelName,
                errorChannelName: errorChannelName,
                retrySignal: options.signal
            )
            if startRequest.shouldStart {
                start(retrySignal: startRequest.signal ?? AbortSignal())
            }
        }
        return unsubscribe
    }

    private func start(retrySignal: AbortSignal) {
        let childSignal = AbortSignal()
        let callerAbortTask = Task {
            let reason = await config.abortSignal.waitUntilAborted()
            childSignal.abort(reason: reason)
        }
        let retryAbortTask = Task {
            let reason = await retrySignal.waitUntilAborted()
            childSignal.abort(reason: reason)
        }
        let streamConfig = InitialValueAndSlotTrackingConfig(
            abortSignal: childSignal,
            rpcRequest: config.rpcRequest,
            rpcSubscriptionRequest: config.rpcSubscriptionRequest,
            rpcSubscriptionValueMapper: config.rpcSubscriptionValueMapper,
            rpcValueMapper: config.rpcValueMapper
        )
        let stream = kitCreateAsyncGeneratorWithInitialValueAndSlotTracking(streamConfig, slotState: slotState)
        Task {
            defer {
                callerAbortTask.cancel()
                retryAbortTask.cancel()
            }
            do {
                for try await item in stream {
                    eventTarget.publish(dataChannelName, item)
                }
            } catch {
                if config.abortSignal.aborted || retrySignal.aborted {
                    return
                }
                let sendableError: any Error & Sendable = error
                eventTarget.publish(errorChannelName, sendableError)
            }
        }
    }
}

actor KitSlotTrackingDataPublisherCoordinator {
    private var dataSubscriberReady = false
    private var errorSubscriberReady = false
    private var started = false
    private var retrySignal: AbortSignal?

    func register(
        channelName: String,
        dataChannelName: String,
        errorChannelName: String,
        retrySignal: AbortSignal?
    ) -> (shouldStart: Bool, signal: AbortSignal?) {
        if channelName == dataChannelName {
            dataSubscriberReady = true
        }
        if channelName == errorChannelName {
            errorSubscriberReady = true
        }
        if self.retrySignal == nil {
            self.retrySignal = retrySignal
        }
        guard !started, dataSubscriberReady, errorSubscriberReady else {
            return (false, nil)
        }
        started = true
        return (true, self.retrySignal ?? retrySignal)
    }
}

actor KitSlotTrackingAsyncRunner<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
> {
    typealias Element = SolanaRpcResponse<TItem>

    private let childSignal = AbortSignal()
    private let config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>
    private let slotState: KitSlotTrackingSlotState
    private var abortTask: Task<Void, Never>?
    private var done = false
    private var pendingError: (any Error & Sendable)?
    private var queue: [Element] = []
    private var rpcDone = false
    private var rpcTask: Task<Void, Never>?
    private var started = false
    private var subscriptionDone = false
    private var subscriptionTask: Task<Void, Never>?
    private var waiting: CheckedContinuation<Element?, any Error>?

    init(
        config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>,
        slotState: KitSlotTrackingSlotState
    ) {
        self.config = config
        self.slotState = slotState
    }

    deinit {
        childSignal.abort()
        abortTask?.cancel()
        rpcTask?.cancel()
        subscriptionTask?.cancel()
    }

    func next() async throws -> Element? {
        startIfNeeded()
        if let pendingError {
            throw pendingError
        }
        if !queue.isEmpty {
            return queue.removeFirst()
        }
        if done {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            if let waiting {
                waiting.resume(throwing: SolanaError(.invariantViolationSubscriptionIteratorStateMissing))
            }
            waiting = continuation
        }
    }

    private func startIfNeeded() {
        guard !started else {
            return
        }
        started = true
        guard !config.abortSignal.aborted else {
            done = true
            return
        }
        abortTask = Task { [weak self, config, childSignal] in
            let reason = await config.abortSignal.waitUntilAborted()
            await self?.abortFromCaller(reason: reason)
            childSignal.abort(reason: reason)
        }
        rpcTask = Task { [weak self, config, childSignal, slotState] in
            do {
                let response = try await config.rpcRequest(childSignal)
                if await slotState.shouldAccept(slot: response.context.slot) {
                    await self?.enqueue(
                        SolanaRpcResponse(
                            context: response.context,
                            value: config.rpcValueMapper(response.value)
                        )
                    )
                }
                await self?.markRpcDone()
            } catch {
                if childSignal.aborted {
                    return
                }
                let sendableError: any Error & Sendable = error
                await self?.fail(sendableError)
            }
        }
        subscriptionTask = Task { [weak self, config, childSignal, slotState] in
            do {
                let notifications = try await config.rpcSubscriptionRequest(childSignal)
                for try await response in notifications {
                    if await slotState.shouldAccept(slot: response.context.slot) {
                        await self?.enqueue(
                            SolanaRpcResponse(
                                context: response.context,
                                value: config.rpcSubscriptionValueMapper(response.value)
                            )
                        )
                    }
                }
                await self?.markSubscriptionDone()
            } catch {
                if childSignal.aborted {
                    return
                }
                let sendableError: any Error & Sendable = error
                await self?.fail(sendableError)
            }
        }
    }

    private func enqueue(_ element: Element) {
        guard !done, !childSignal.aborted else {
            return
        }
        if let waiting {
            self.waiting = nil
            waiting.resume(returning: element)
            return
        }
        queue.append(element)
    }

    private func fail(_ error: any Error & Sendable) {
        guard !childSignal.aborted else {
            return
        }
        done = true
        pendingError = error
        childSignal.abort(reason: error)
        resumeWaiting(.failure(error))
    }

    private func abortFromCaller(reason: (any Error & Sendable)?) {
        done = true
        childSignal.abort(reason: reason)
        resumeWaiting(.success(nil))
    }

    func cancelFromConsumer() {
        done = true
        childSignal.abort()
        abortTask?.cancel()
        rpcTask?.cancel()
        subscriptionTask?.cancel()
        resumeWaiting(.success(nil))
    }

    private func markRpcDone() {
        rpcDone = true
        finishIfBothDone()
    }

    private func markSubscriptionDone() {
        subscriptionDone = true
        finishIfBothDone()
    }

    private func finishIfBothDone() {
        guard rpcDone, subscriptionDone else {
            return
        }
        done = true
        if queue.isEmpty {
            resumeWaiting(.success(nil))
        }
    }

    private func resumeWaiting(_ result: Result<Element?, any Error>) {
        guard let waiting else {
            return
        }
        self.waiting = nil
        waiting.resume(with: result)
    }
}
