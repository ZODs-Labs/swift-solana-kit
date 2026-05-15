public import Promises

public typealias DataPublisherPayload = (any Sendable)?
public typealias DataPublisherSubscriber = @Sendable (DataPublisherPayload) -> Void
public typealias DataPublisherUnsubscribe = @Sendable () -> Void
public typealias ReactiveListener = @Sendable () -> Void

public struct DataPublisherSubscriptionOptions: Sendable {
    public let signal: AbortSignal?
    public init(signal: AbortSignal? = nil)
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
    func on(_ channelName: String, subscriber: @escaping DataPublisherSubscriber) throws -> DataPublisherUnsubscribe
}

public final class EventDataPublisher: DataPublisher {
    public init()

    @discardableResult
    public func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions = .init()
    ) -> DataPublisherUnsubscribe

    public func publish(_ channelName: String, _ payload: DataPublisherPayload = nil)
}

public func getDataPublisherFromEventEmitter(_ eventEmitter: EventDataPublisher) -> any DataPublisher

public func demultiplexDataPublisher(
    _ publisher: any DataPublisher,
    sourceChannelName: String,
    messageTransformer: @escaping @Sendable (DataPublisherPayload) -> (destinationChannelName: String, message: DataPublisherPayload)?
) -> any DataPublisher

public struct AsyncDataPublisherSequence<Element: Sendable>: AsyncSequence, Sendable {
    public typealias AsyncIterator = Iterator
    public typealias Element = Element

    public final class Iterator: AsyncIteratorProtocol, Sendable {
        public func next() async throws -> Element?
    }

    public func makeAsyncIterator() -> Iterator
}

public func createAsyncIterableFromDataPublisher<Element: Sendable>(
    abortSignal: AbortSignal,
    dataChannelName: String,
    dataPublisher: any DataPublisher,
    errorChannelName: String,
    as type: Element.Type
) -> AsyncDataPublisherSequence<Element>

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

    public init(data: TResult?, error: (any Error & Sendable)?, status: ReactiveActionStatus)
}

public final class ReactiveActionStore<TResult: Sendable>: Sendable {
    public func dispatch(_ args: any Sendable...)
    public func dispatchAsync(_ args: any Sendable...) async throws -> TResult
    public func getState() -> ReactiveActionState<TResult>
    public func reset()
    @discardableResult
    public func subscribe(_ listener: @escaping ReactiveListener) -> DataPublisherUnsubscribe
}

public func createReactiveActionStore<TResult: Sendable>(
    _ action: @escaping @Sendable (AbortSignal, [any Sendable]) async throws -> TResult
) -> ReactiveActionStore<TResult>

public func createReactiveActionStore<TResult: Sendable>(
    _ action: @escaping @Sendable (AbortSignal) async throws -> TResult
) -> ReactiveActionStore<TResult>

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

    public init(data: T?, error: (any Error & Sendable)?, status: ReactiveStreamStatus)
}

public typealias ReactiveStore<T: Sendable> = ReactiveStreamStore<T>

public final class ReactiveStreamStore<T: Sendable>: Sendable {
    public func getError() -> (any Error & Sendable)?
    public func getState() -> T?
    public func getUnifiedState() -> ReactiveState<T>
    public func retry() throws
    @discardableResult
    public func subscribe(_ callback: @escaping ReactiveListener) -> DataPublisherUnsubscribe
}

public func createReactiveStoreFromDataPublisher<TData: Sendable>(
    abortSignal: AbortSignal,
    dataChannelName: String,
    dataPublisher: any DataPublisher,
    errorChannelName: String,
    as type: TData.Type
) -> ReactiveStreamStore<TData>

public func createReactiveStoreFromDataPublisherFactory<TData: Sendable>(
    abortSignal: AbortSignal,
    createDataPublisher: @escaping @Sendable () async throws -> any DataPublisher,
    dataChannelName: String,
    errorChannelName: String,
    as type: TData.Type
) -> ReactiveStreamStore<TData>
