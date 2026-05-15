import Foundation
public import Promises
public import RpcSpecTypes
import SolanaErrors
public import Subscribable
import os

public struct RpcSubscriptionsChannel: DataPublisher, Sendable {
    fileprivate let identity: UUID
    private let dataPublisher: any DataPublisher
    private let sendHandler: @Sendable (DataPublisherPayload) async throws -> Void

    public init(
        dataPublisher: any DataPublisher,
        send: @escaping @Sendable (DataPublisherPayload) async throws -> Void
    ) {
        identity = UUID()
        self.dataPublisher = dataPublisher
        sendHandler = send
    }

    fileprivate init(
        identity: UUID,
        dataPublisher: any DataPublisher,
        send: @escaping @Sendable (DataPublisherPayload) async throws -> Void
    ) {
        self.identity = identity
        self.dataPublisher = dataPublisher
        sendHandler = send
    }

    @discardableResult
    public func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe {
        try dataPublisher.on(channelName, subscriber: subscriber, options: options)
    }

    public func send(_ message: DataPublisherPayload) async throws {
        try await sendHandler(message)
    }
}

public typealias RpcSubscriptionsChannelCreator = @Sendable (_ abortSignal: AbortSignal) async throws -> RpcSubscriptionsChannel

public func transformChannelInboundMessages(
    _ channel: RpcSubscriptionsChannel,
    transform: @escaping @Sendable (DataPublisherPayload) throws -> DataPublisherPayload
) -> RpcSubscriptionsChannel {
    let transformed = TransformedInboundPublisher(channel: channel, transform: transform)
    return RpcSubscriptionsChannel(identity: channel.identity, dataPublisher: transformed, send: { message in
        try await channel.send(message)
    })
}

public func transformChannelOutboundMessages(
    _ channel: RpcSubscriptionsChannel,
    transform: @escaping @Sendable (DataPublisherPayload) throws -> DataPublisherPayload
) -> RpcSubscriptionsChannel {
    RpcSubscriptionsChannel(identity: channel.identity, dataPublisher: channel, send: { message in
        try await channel.send(try transform(message))
    })
}

public struct RpcSubscriptionsPlanExecutionConfig: Sendable {
    public let channel: RpcSubscriptionsChannel
    public let signal: AbortSignal

    public init(channel: RpcSubscriptionsChannel, signal: AbortSignal) {
        self.channel = channel
        self.signal = signal
    }
}

public struct RpcSubscriptionsPlan<TNotification: Sendable>: Sendable {
    public let request: RpcRequest
    public let execute: @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher

    public init(
        request: RpcRequest,
        execute: @escaping @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher
    ) {
        self.request = request
        self.execute = execute
    }
}

public struct RpcSubscriptionsPlanExecutorConfig: Sendable {
    public let channel: RpcSubscriptionsChannel
    public let request: RpcRequest
    public let signal: AbortSignal

    public init(channel: RpcSubscriptionsChannel, request: RpcRequest, signal: AbortSignal) {
        self.channel = channel
        self.request = request
        self.signal = signal
    }
}

public typealias RpcSubscriptionsPlanExecutor = @Sendable (RpcSubscriptionsPlanExecutorConfig) async throws -> any DataPublisher

public struct RpcSubscriptionsApiConfig: Sendable {
    public let planExecutor: RpcSubscriptionsPlanExecutor
    public let requestTransformer: RpcRequestTransformer?

    public init(
        planExecutor: @escaping RpcSubscriptionsPlanExecutor,
        requestTransformer: RpcRequestTransformer? = nil
    ) {
        self.planExecutor = planExecutor
        self.requestTransformer = requestTransformer
    }
}

public struct RpcSubscriptionsApi: Sendable {
    private let createPlan: @Sendable (_ methodName: String, _ params: [RpcJsonValue]) throws -> RpcSubscriptionsPlan<DataPublisherPayload>

    public init(
        createPlan: @escaping @Sendable (_ methodName: String, _ params: [RpcJsonValue]) throws -> RpcSubscriptionsPlan<DataPublisherPayload>
    ) {
        self.createPlan = createPlan
    }

    public func plan<TNotification: Sendable>(
        methodName: String,
        params: [RpcJsonValue] = [],
        as type: TNotification.Type
    ) throws -> RpcSubscriptionsPlan<TNotification> {
        let plan = try createPlan(methodName, params)
        return RpcSubscriptionsPlan<TNotification>(request: plan.request, execute: plan.execute)
    }
}

public func createRpcSubscriptionsApi(_ config: RpcSubscriptionsApiConfig) -> RpcSubscriptionsApi {
    RpcSubscriptionsApi { methodName, params in
        let rawRequest = RpcRequest(methodName: methodName, params: .array(params))
        let request = try config.requestTransformer?(rawRequest) ?? rawRequest
        return RpcSubscriptionsPlan<DataPublisherPayload>(request: request) { executionConfig in
            try await config.planExecutor(
                RpcSubscriptionsPlanExecutorConfig(
                    channel: executionConfig.channel,
                    request: request,
                    signal: executionConfig.signal
                )
            )
        }
    }
}

public struct RpcSubscriptionNotification<TNotification: Sendable>: Sendable {
    public let method: String
    public let result: TNotification
    public let subscription: Int

    public init(method: String, result: TNotification, subscription: Int) {
        self.method = method
        self.result = result
        self.subscription = subscription
    }
}

extension RpcSubscriptionNotification: Equatable where TNotification: Equatable {}

public func executeRpcPubSubSubscriptionPlan<TNotification: Sendable>(
    channel: RpcSubscriptionsChannel,
    responseTransformer: RpcResponseTransformer? = nil,
    signal: AbortSignal,
    subscribeRequest: RpcRequest,
    unsubscribeMethodName: String,
    as type: TNotification.Type
) async throws -> any DataPublisher {
    _ = try channel.on("error", subscriber: { _ in
        subscriptionCounts.withLock { counts in
            _ = counts.removeValue(forKey: channel.identity)
        }
        clearNotificationPublisherCache(channelID: channel.identity)
    }, options: .init(signal: signal))

    let subscribePayload = createRpcMessage(subscribeRequest)
    try await channel.send(subscribePayload)

    let subscriptionId = try await waitForSubscriptionId(
        subscribePayloadId: subscribePayload.id,
        channel: channel,
        signal: signal
    )
    incrementSubscriberCount(channelID: channel.identity, subscriptionID: subscriptionId)

    _ = signal.addAbortHandler { _ in
        if decrementSubscriberCount(channelID: channel.identity, subscriptionID: subscriptionId) == 0 {
            let unsubscribePayload = createRpcMessage(
                RpcRequest(methodName: unsubscribeMethodName, params: .array([.number(Double(subscriptionId))]))
            )
            Task {
                try? await channel.send(unsubscribePayload)
            }
        }
    }

    return RpcPubSubNotificationPublisher<TNotification>(
        channel: channel,
        subscriptionId: subscriptionId,
        subscribeRequest: subscribeRequest,
        responseTransformer: responseTransformer
    )
}

public struct RpcSubscriptionsTransportConfig: Sendable {
    public let request: RpcRequest
    public let signal: AbortSignal
    public let execute: @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher

    public init(
        request: RpcRequest,
        signal: AbortSignal,
        execute: @escaping @Sendable (RpcSubscriptionsPlanExecutionConfig) async throws -> any DataPublisher
    ) {
        self.request = request
        self.signal = signal
        self.execute = execute
    }
}

public typealias RpcSubscriptionsTransport = @Sendable (RpcSubscriptionsTransportConfig) async throws -> any DataPublisher

public struct RpcSubscribeOptions: Sendable {
    public let abortSignal: AbortSignal

    public init(abortSignal: AbortSignal) {
        self.abortSignal = abortSignal
    }
}

public struct PendingRpcSubscriptionsRequest<TNotification: Sendable>: Sendable {
    private let transport: RpcSubscriptionsTransport
    private let plan: RpcSubscriptionsPlan<TNotification>

    public init(transport: @escaping RpcSubscriptionsTransport, plan: RpcSubscriptionsPlan<TNotification>) {
        self.transport = transport
        self.plan = plan
    }

    public func reactive(_ options: RpcSubscribeOptions) async throws -> ReactiveStreamStore<TNotification> {
        let publisher = try await transport(
            RpcSubscriptionsTransportConfig(
                request: plan.request,
                signal: options.abortSignal,
                execute: plan.execute
            )
        )
        return createReactiveStoreFromDataPublisher(
            abortSignal: options.abortSignal,
            dataChannelName: "notification",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: TNotification.self
        )
    }

    public func reactiveStore(_ options: RpcSubscribeOptions) -> ReactiveStreamStore<TNotification> {
        createReactiveStoreFromDataPublisherFactory(
            abortSignal: options.abortSignal,
            createDataPublisher: {
                try await transport(
                    RpcSubscriptionsTransportConfig(
                        request: plan.request,
                        signal: options.abortSignal,
                        execute: plan.execute
                    )
                )
            },
            dataChannelName: "notification",
            errorChannelName: "error",
            as: TNotification.self
        )
    }

    public func subscribe(_ options: RpcSubscribeOptions) async throws -> AsyncDataPublisherSequence<TNotification> {
        let publisher = try await transport(
            RpcSubscriptionsTransportConfig(
                request: plan.request,
                signal: options.abortSignal,
                execute: plan.execute
            )
        )
        return createAsyncIterableFromDataPublisher(
            abortSignal: options.abortSignal,
            dataChannelName: "notification",
            dataPublisher: publisher,
            errorChannelName: "error",
            as: TNotification.self
        )
    }
}

public struct RpcSubscriptionsConfig: Sendable {
    public let api: RpcSubscriptionsApi
    public let transport: RpcSubscriptionsTransport

    public init(api: RpcSubscriptionsApi, transport: @escaping RpcSubscriptionsTransport) {
        self.api = api
        self.transport = transport
    }
}

public struct RpcSubscriptions: Sendable {
    private let config: RpcSubscriptionsConfig

    public init(config: RpcSubscriptionsConfig) {
        self.config = config
    }

    public func request<TNotification: Sendable>(
        _ notificationName: String,
        params: [RpcJsonValue] = [],
        as type: TNotification.Type
    ) throws -> PendingRpcSubscriptionsRequest<TNotification> {
        let plan = try config.api.plan(methodName: notificationName, params: params, as: TNotification.self)
        return PendingRpcSubscriptionsRequest(transport: config.transport, plan: plan)
    }
}

public func createSubscriptionRpc(_ rpcConfig: RpcSubscriptionsConfig) -> RpcSubscriptions {
    RpcSubscriptions(config: rpcConfig)
}

private let subscriptionCounts = OSAllocatedUnfairLock(initialState: [UUID: [Int: Int]]())

private enum NotificationPublisherTransformerKey: Hashable, Sendable {
    case absent
    case transformer(String)
}

private struct NotificationPublisherCacheKey: Hashable, Sendable {
    let channelID: UUID
    let transformerKey: NotificationPublisherTransformerKey
}

private let notificationPublisherCache = OSAllocatedUnfairLock(
    initialState: [NotificationPublisherCacheKey: any DataPublisher]()
)

private let jsonRpcCodesThatCarryServerMessage: Set<Int> = [
    SolanaErrorCode.jsonRPCInternalError.rawValue,
    SolanaErrorCode.jsonRPCInvalidParams.rawValue,
    SolanaErrorCode.jsonRPCInvalidRequest.rawValue,
    SolanaErrorCode.jsonRPCMethodNotFound.rawValue,
    SolanaErrorCode.jsonRPCParseError.rawValue,
    SolanaErrorCode.jsonRPCScanError.rawValue,
    SolanaErrorCode.jsonRPCServerErrorBlockCleanedUp.rawValue,
    SolanaErrorCode.jsonRPCServerErrorBlockNotAvailable.rawValue,
    SolanaErrorCode.jsonRPCServerErrorBlockStatusNotAvailableYet.rawValue,
    SolanaErrorCode.jsonRPCServerErrorKeyExcludedFromSecondaryIndex.rawValue,
    SolanaErrorCode.jsonRPCServerErrorLongTermStorageSlotSkipped.rawValue,
    SolanaErrorCode.jsonRPCServerErrorSlotSkipped.rawValue,
    SolanaErrorCode.jsonRPCServerErrorTransactionPrecompileVerificationFailure.rawValue,
    SolanaErrorCode.jsonRPCServerErrorUnsupportedTransactionVersion.rawValue,
]

private func incrementSubscriberCount(channelID: UUID, subscriptionID: Int) {
    subscriptionCounts.withLock { counts in
        var channelCounts = counts[channelID] ?? [:]
        channelCounts[subscriptionID, default: 0] += 1
        counts[channelID] = channelCounts
    }
}

private func decrementSubscriberCount(channelID: UUID, subscriptionID: Int) -> Int? {
    subscriptionCounts.withLock { counts in
        guard var channelCounts = counts[channelID], let current = channelCounts[subscriptionID] else {
            return nil
        }
        let next = current - 1
        if next <= 0 {
            channelCounts.removeValue(forKey: subscriptionID)
        } else {
            channelCounts[subscriptionID] = next
        }
        counts[channelID] = channelCounts.isEmpty ? nil : channelCounts
        return next
    }
}

private func clearNotificationPublisherCache(channelID: UUID) {
    notificationPublisherCache.withLock { cache in
        cache = cache.filter { $0.key.channelID != channelID }
    }
}

private func getMemoizedNotificationPublisher(
    channel: RpcSubscriptionsChannel,
    subscribeRequest: RpcRequest,
    responseTransformer: RpcResponseTransformer?
) -> any DataPublisher {
    let key = NotificationPublisherCacheKey(
        channelID: channel.identity,
        transformerKey: responseTransformer.map { .transformer($0.identity) } ?? .absent
    )
    if let cached = notificationPublisherCache.withLock({ $0[key] }) {
        return cached
    }
    let publisher = demultiplexDataPublisher(channel, sourceChannelName: "message") { payload in
        guard let (subscription, result) = notificationResult(from: payload) else {
            return nil
        }
        let transformed: RpcJsonValue
        do {
            transformed = try responseTransformer?(result, subscribeRequest) ?? result
        } catch {
            return nil
        }
        return ("notification:\(subscription)", transformed)
    }
    return notificationPublisherCache.withLock { cache in
        if let cached = cache[key] {
            return cached
        }
        cache[key] = publisher
        return publisher
    }
}

private final class TransformedInboundPublisher: DataPublisher {
    private let channel: RpcSubscriptionsChannel
    private let transform: @Sendable (DataPublisherPayload) throws -> DataPublisherPayload

    init(
        channel: RpcSubscriptionsChannel,
        transform: @escaping @Sendable (DataPublisherPayload) throws -> DataPublisherPayload
    ) {
        self.channel = channel
        self.transform = transform
    }

    @discardableResult
    func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe {
        if channelName != "message" {
            return try channel.on(channelName, subscriber: subscriber, options: options)
        }
        return try channel.on("message", subscriber: { [transform] payload in
            if let transformed = try? transform(payload) {
                subscriber(transformed)
            }
        }, options: options)
    }
}

private func waitForSubscriptionId(
    subscribePayloadId: String,
    channel: RpcSubscriptionsChannel,
    signal: AbortSignal
) async throws -> Int {
    let waiter = SubscriptionIDWaiter()
    return try await waiter.wait { waiter in
        let errorUnsubscribe: DataPublisherUnsubscribe
        let messageUnsubscribe: DataPublisherUnsubscribe
        do {
            errorUnsubscribe = try channel.on("error", subscriber: { payload in
                waiter.resume(throwing: payload.rpcSubscriptionError(defaultMessage: "Subscription channel error"))
            })
            messageUnsubscribe = try channel.on("message", subscriber: { payload in
                do {
                    guard let result = try subscriptionIDResult(from: payload, matching: subscribePayloadId) else {
                        return
                    }
                    switch result {
                    case let .success(id):
                        waiter.resume(returning: id)
                    case let .failure(error):
                        waiter.resume(throwing: error)
                    }
                } catch {
                    waiter.resume(throwing: error)
                }
            })
        } catch {
            waiter.resume(throwing: error)
            return
        }
        let removeAbortHandler = signal.addAbortHandler { reason in
            waiter.resume(throwing: reason)
        }
        let abortTask = Task {
            let reason = await signal.waitUntilAborted()
            waiter.resume(throwing: reason)
        }
        waiter.setCleanup {
            errorUnsubscribe()
            messageUnsubscribe()
            removeAbortHandler()
            abortTask.cancel()
        }
    }
}

private enum SubscriptionIDResult: Sendable {
    case success(Int)
    case failure(any Error & Sendable)
}

private func subscriptionIDResult(
    from payload: DataPublisherPayload,
    matching subscribePayloadId: String
) throws -> SubscriptionIDResult? {
    if let response = payload as? RpcResponseData {
        switch response {
        case let .result(id, value) where id == subscribePayloadId:
            return .success(try subscriptionID(from: value))
        case let .error(id, error) where id == subscribePayloadId:
            return .failure(solanaErrorFromRpcResponseError(error))
        default:
            return nil
        }
    }
    if let value = payload as? RpcJsonValue,
       case let .object(members) = value,
       let id = members.value(for: "id"),
       rpcJSONIDString(id) == subscribePayloadId {
        if let error = members.value(for: "error"), error != .null {
            return .failure(solanaErrorFromRpcJsonError(error))
        }
        guard let result = members.value(for: "result") else {
            return .failure(SolanaError(.rpcSubscriptionsExpectedServerSubscriptionID))
        }
        return .success(try subscriptionID(from: result))
    }
    return nil
}

private func solanaErrorFromRpcResponseError(_ error: RpcResponseErrorPayload) -> SolanaError {
    solanaErrorFromJsonRpcError(code: error.code, message: error.message, data: error.data)
}

private func solanaErrorFromRpcJsonError(_ error: RpcJsonValue) -> SolanaError {
    guard case let .object(members) = error else {
        return malformedJsonRpcError(from: error)
    }
    let code = integerCode(from: members.value(for: "code"))
    let messageValue = members.value(for: "message")
    guard let code,
          case let .string(message)? = messageValue else {
        return malformedJsonRpcError(from: error)
    }
    return solanaErrorFromJsonRpcError(code: code, message: message, data: members.value(for: "data"))
}

private func solanaErrorFromJsonRpcError(code: Int, message: String, data: RpcJsonValue?) -> SolanaError {
    if jsonRpcCodesThatCarryServerMessage.contains(code) {
        return SolanaError(SolanaErrorCode(rawValue: code), context: ["__serverMessage": .string(message)])
    }
    return SolanaError(SolanaErrorCode(rawValue: code), context: contextFromObjectData(data))
}

private func malformedJsonRpcError(from error: RpcJsonValue) -> SolanaError {
    let message: String
    if case let .string(serverMessage)? = error.value(for: "message") {
        message = serverMessage
    } else {
        message = "Malformed JSON-RPC error with no message attribute"
    }
    return SolanaError(
        .malformedJSONRPCError,
        context: [
            "error": rpcJsonValueToContextValue(error),
            "message": .string(message),
        ]
    )
}

private func integerCode(from value: RpcJsonValue?) -> Int? {
    switch value {
    case let .number(number)? where number.isFinite:
        return Int(number)
    case let .bigint(value)?:
        return Int(value)
    default:
        return nil
    }
}

private func contextFromObjectData(_ data: RpcJsonValue?) -> SolanaErrorContext {
    guard case let .object(members)? = data else {
        return .empty
    }
    return SolanaErrorContext(contextObject(from: members))
}

private func rpcJsonValueToContextValue(_ value: RpcJsonValue) -> SolanaErrorContextValue {
    switch value {
    case .null:
        return .null
    case let .bool(value):
        return .bool(value)
    case let .string(value):
        return .string(value)
    case let .number(value):
        if value.isFinite,
           value.rounded(.towardZero) == value,
           value >= Double(Int.min),
           value <= Double(Int.max) {
            return .int(Int(value))
        }
        return .string(String(value))
    case let .bigint(value):
        if let int = Int(value) {
            return .int(int)
        }
        if let uint = UInt64(value) {
            return .uint(uint)
        }
        return .string(value)
    case let .array(values):
        return .array(values.map(rpcJsonValueToContextValue))
    case let .object(members):
        return .object(contextObject(from: members))
    }
}

private func contextObject(from members: [RpcJsonObjectMember]) -> [String: SolanaErrorContextValue] {
    var out: [String: SolanaErrorContextValue] = [:]
    for member in members {
        out[member.key] = rpcJsonValueToContextValue(member.value)
    }
    return out
}

private func subscriptionID(from value: RpcJsonValue) throws -> Int {
    switch value {
    case let .number(number):
        guard number.rounded(.towardZero) == number,
              let int = Int(exactly: number) else {
            throw SolanaError(.rpcSubscriptionsExpectedServerSubscriptionID)
        }
        return int
    case let .bigint(value), let .string(value):
        guard let int = Int(value) else {
            throw SolanaError(.rpcSubscriptionsExpectedServerSubscriptionID)
        }
        return int
    default:
        throw SolanaError(.rpcSubscriptionsExpectedServerSubscriptionID)
    }
}

private final class RpcPubSubNotificationPublisher<TNotification: Sendable>: DataPublisher {
    private let channel: RpcSubscriptionsChannel
    private let notificationKey: String
    private let notificationPublisher: any DataPublisher

    init(
        channel: RpcSubscriptionsChannel,
        subscriptionId: Int,
        subscribeRequest: RpcRequest,
        responseTransformer: RpcResponseTransformer?
    ) {
        self.channel = channel
        notificationKey = "notification:\(subscriptionId)"
        notificationPublisher = getMemoizedNotificationPublisher(
            channel: channel,
            subscribeRequest: subscribeRequest,
            responseTransformer: responseTransformer
        )
    }

    @discardableResult
    func on(
        _ channelName: String,
        subscriber: @escaping DataPublisherSubscriber,
        options: DataPublisherSubscriptionOptions
    ) throws -> DataPublisherUnsubscribe {
        switch channelName {
        case "notification":
            return try notificationPublisher.on(notificationKey, subscriber: { payload in
                guard let value = payload as? RpcJsonValue else {
                    return
                }
                if TNotification.self == RpcJsonValue.self {
                    subscriber(value)
                    return
                }
                if let scalar = value.scalarValue as? TNotification {
                    subscriber(scalar)
                }
            }, options: options)
        case "error":
            return try channel.on("error", subscriber: subscriber, options: options)
        default:
            throw SolanaError(
                .invariantViolationDataPublisherChannelUnimplemented,
                context: [
                    "channelName": .string(channelName),
                    "supportedChannelNames": .stringArray(["notification", "error"]),
                ]
            )
        }
    }
}

private func notificationResult(from payload: DataPublisherPayload) -> (subscription: Int, result: RpcJsonValue)? {
    if let notification = payload as? RpcSubscriptionNotification<RpcJsonValue> {
        return (notification.subscription, notification.result)
    }
    guard let value = payload as? RpcJsonValue,
          case let .object(members) = value,
          let params = members.value(for: "params"),
          case let .object(paramMembers) = params,
          let result = paramMembers.value(for: "result"),
          let subscriptionValue = paramMembers.value(for: "subscription"),
          let subscription = try? subscriptionID(from: subscriptionValue) else {
        return nil
    }
    return (subscription, result)
}

private final class SubscriptionIDWaiter: Sendable {
    private struct State: Sendable {
        var continuation: CheckedContinuation<Int, any Error>?
        var cleanup: (@Sendable () -> Void)?
        var completed = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func wait(_ install: (SubscriptionIDWaiter) -> Void) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock { state in
                state.continuation = continuation
            }
            install(self)
        }
    }

    func setCleanup(_ cleanup: @escaping @Sendable () -> Void) {
        let shouldRun = state.withLock { state -> Bool in
            if state.completed {
                return true
            }
            state.cleanup = cleanup
            return false
        }
        if shouldRun {
            cleanup()
        }
    }

    func resume(returning value: Int) {
        let pending = state.withLock { state -> (CheckedContinuation<Int, any Error>?, (@Sendable () -> Void)?) in
            if state.completed {
                return (nil, nil)
            }
            state.completed = true
            let continuation = state.continuation
            let cleanup = state.cleanup
            state.continuation = nil
            state.cleanup = nil
            return (continuation, cleanup)
        }
        pending.1?()
        pending.0?.resume(returning: value)
    }

    func resume(throwing error: any Error) {
        let pending = state.withLock { state -> (CheckedContinuation<Int, any Error>?, (@Sendable () -> Void)?) in
            if state.completed {
                return (nil, nil)
            }
            state.completed = true
            let continuation = state.continuation
            let cleanup = state.cleanup
            state.continuation = nil
            state.cleanup = nil
            return (continuation, cleanup)
        }
        pending.1?()
        pending.0?.resume(throwing: error)
    }
}

private extension Optional where Wrapped == any Sendable {
    func rpcSubscriptionError(defaultMessage: String) -> any Error & Sendable {
        if let error = self as? (any Error & Sendable) {
            return error
        }
        if let message = self as? String {
            return RpcSubscriptionsSpecError(message: message)
        }
        return RpcSubscriptionsSpecError(message: defaultMessage)
    }
}

private struct RpcSubscriptionsSpecError: Error, Sendable, Equatable {
    let message: String
}

private extension Array where Element == RpcJsonObjectMember {
    func value(for key: String) -> RpcJsonValue? {
        last { $0.key == key }?.value
    }
}

private extension RpcJsonValue {
    var scalarValue: DataPublisherPayload {
        switch self {
        case .null:
            return nil
        case let .bool(value):
            return value
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .bigint(value):
            return value
        case .array, .object:
            return self
        }
    }
}

private func rpcJSONIDString(_ value: RpcJsonValue) -> String? {
    switch value {
    case let .string(value), let .bigint(value):
        return value
    case let .number(value) where value.rounded(.towardZero) == value:
        return String(Int(value))
    default:
        return nil
    }
}
