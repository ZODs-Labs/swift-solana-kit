public import Promises
public import RpcSpecTypes
public import Subscribable

public struct RpcSubscriptionsChannel: DataPublisher, Sendable {
    public init(
        dataPublisher: any DataPublisher,
        send: @escaping @Sendable (DataPublisherPayload) async throws -> Void
    )

    @discardableResult
    public func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe

    public func send(_ message: DataPublisherPayload) async throws
}

public typealias RpcSubscriptionsChannelCreator = @Sendable (_ abortSignal: AbortSignal) async throws -> RpcSubscriptionsChannel

public func transformChannelInboundMessages(
    _ channel: RpcSubscriptionsChannel,
    transform: @escaping @Sendable (DataPublisherPayload) throws -> DataPublisherPayload
) -> RpcSubscriptionsChannel

public func transformChannelOutboundMessages(
    _ channel: RpcSubscriptionsChannel,
    transform: @escaping @Sendable (DataPublisherPayload) throws -> DataPublisherPayload
) -> RpcSubscriptionsChannel

public struct RpcSubscriptionsPlanExecutionConfig: Sendable {
    public let channel: RpcSubscriptionsChannel
    public let signal: AbortSignal
    public init(channel: RpcSubscriptionsChannel, signal: AbortSignal)
}

public struct RpcSubscriptionsPlan<TNotification: Sendable>: Sendable {
    public let request: RpcRequest
    public let execute: @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher

    public init(
        request: RpcRequest,
        execute: @escaping @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher
    )
}

public struct RpcSubscriptionsPlanExecutorConfig: Sendable {
    public let channel: RpcSubscriptionsChannel
    public let request: RpcRequest
    public let signal: AbortSignal
    public init(channel: RpcSubscriptionsChannel, request: RpcRequest, signal: AbortSignal)
}

public typealias RpcSubscriptionsPlanExecutor = @Sendable (RpcSubscriptionsPlanExecutorConfig) async throws -> any DataPublisher

public struct RpcSubscriptionsApiConfig: Sendable {
    public let planExecutor: RpcSubscriptionsPlanExecutor
    public let requestTransformer: RpcRequestTransformer?

    public init(
        planExecutor: @escaping RpcSubscriptionsPlanExecutor,
        requestTransformer: RpcRequestTransformer? = nil
    )
}

public struct RpcSubscriptionsApi: Sendable {
    public init(
        createPlan: @escaping @Sendable (_ methodName: String, _ params: [RpcJsonValue]) throws -> RpcSubscriptionsPlan<DataPublisherPayload>
    )

    public func plan<TNotification: Sendable>(
        methodName: String,
        params: [RpcJsonValue] = [],
        as type: TNotification.Type
    ) throws -> RpcSubscriptionsPlan<TNotification>
}

public func createRpcSubscriptionsApi(_ config: RpcSubscriptionsApiConfig) -> RpcSubscriptionsApi

public struct RpcSubscriptionNotification<TNotification: Sendable>: Sendable, Equatable where TNotification: Equatable {
    public let method: String
    public let result: TNotification
    public let subscription: Int

    public init(method: String, result: TNotification, subscription: Int)
}

public func executeRpcPubSubSubscriptionPlan<TNotification: Sendable>(
    channel: RpcSubscriptionsChannel,
    responseTransformer: RpcResponseTransformer? = nil,
    signal: AbortSignal,
    subscribeRequest: RpcRequest,
    unsubscribeMethodName: String,
    as type: TNotification.Type
) async throws -> any DataPublisher

public struct RpcSubscriptionsTransportConfig: Sendable {
    public let request: RpcRequest
    public let signal: AbortSignal
    public let execute: @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher

    public init(
        request: RpcRequest,
        signal: AbortSignal,
        execute: @escaping @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher
    )
}

public typealias RpcSubscriptionsTransport = @Sendable (RpcSubscriptionsTransportConfig) async throws -> any DataPublisher

public struct RpcSubscribeOptions: Sendable {
    public let abortSignal: AbortSignal
    public init(abortSignal: AbortSignal)
}

public struct PendingRpcSubscriptionsRequest<TNotification: Sendable>: Sendable {
    public init(transport: @escaping RpcSubscriptionsTransport, plan: RpcSubscriptionsPlan<TNotification>)
    public func reactive(_ options: RpcSubscribeOptions) async throws -> ReactiveStreamStore<TNotification>
    public func reactiveStore(_ options: RpcSubscribeOptions) -> ReactiveStreamStore<TNotification>
    public func subscribe(_ options: RpcSubscribeOptions) async throws -> AsyncDataPublisherSequence<TNotification>
}

public struct RpcSubscriptionsConfig: Sendable {
    public let api: RpcSubscriptionsApi
    public let transport: RpcSubscriptionsTransport
    public init(api: RpcSubscriptionsApi, transport: @escaping RpcSubscriptionsTransport)
}

public struct RpcSubscriptions: Sendable {
    public init(config: RpcSubscriptionsConfig)
    public func request<TNotification: Sendable>(
        _ notificationName: String,
        params: [RpcJsonValue] = [],
        as type: TNotification.Type
    ) throws -> PendingRpcSubscriptionsRequest<TNotification>
}

public func createSubscriptionRpc(_ rpcConfig: RpcSubscriptionsConfig) -> RpcSubscriptions
