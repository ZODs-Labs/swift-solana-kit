public import Promises
public import RpcSpecTypes
public import Subscribable

public struct RpcTransportConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let payload: RpcJsonValue
    public init(payload: RpcJsonValue, abortSignal: AbortSignal? = nil)
}

public typealias RpcTransport = @Sendable (RpcTransportConfig) async throws -> RpcJsonValue

public struct RpcApiConfig: Sendable {
    public let requestTransformer: RpcRequestTransformer?
    public let responseTransformer: RpcResponseTransformer?
    public init(
        requestTransformer: RpcRequestTransformer? = nil,
        responseTransformer: RpcResponseTransformer? = nil
    )
}

public struct RpcPlan: Sendable {
    public init(execute: @escaping @Sendable (RpcTransport, AbortSignal?) async throws -> RpcJsonValue)
    public func execute(transport: RpcTransport, abortSignal: AbortSignal? = nil) async throws -> RpcJsonValue
}

public struct JsonRpcApi: Sendable {
    public init(config: RpcApiConfig = RpcApiConfig())
    public func plan(methodName: String, params: [RpcJsonValue]) throws -> RpcPlan
}

public func createJsonRpcApi(config: RpcApiConfig = RpcApiConfig()) -> JsonRpcApi

public struct PendingRpcRequest: Sendable {
    public init(plan: RpcPlan, transport: @escaping RpcTransport)
    public func send(abortSignal: AbortSignal? = nil) async throws -> RpcJsonValue
    public func reactiveStore() -> ReactiveActionStore<RpcJsonValue>
}

public struct Rpc: Sendable {
    public init(api: JsonRpcApi, transport: @escaping RpcTransport)
    public func request(_ methodName: String, params: [RpcJsonValue]) throws -> PendingRpcRequest
}

public func createRpc(api: JsonRpcApi, transport: @escaping RpcTransport) -> Rpc
public func isJsonRpcPayload(_ payload: RpcJsonValue) -> Bool
