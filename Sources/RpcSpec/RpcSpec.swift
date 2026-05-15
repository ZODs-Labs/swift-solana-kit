public import Promises
public import RpcSpecTypes
public import Subscribable
import SolanaErrors

public struct RpcTransportConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let payload: RpcJsonValue

    public init(payload: RpcJsonValue, abortSignal: AbortSignal? = nil) {
        self.payload = payload
        self.abortSignal = abortSignal
    }
}

public typealias RpcTransport = @Sendable (RpcTransportConfig) async throws -> RpcJsonValue

public struct RpcApiConfig: Sendable {
    public let requestTransformer: RpcRequestTransformer?
    public let responseTransformer: RpcResponseTransformer?

    public init(
        requestTransformer: RpcRequestTransformer? = nil,
        responseTransformer: RpcResponseTransformer? = nil
    ) {
        self.requestTransformer = requestTransformer
        self.responseTransformer = responseTransformer
    }
}

public struct RpcPlan: Sendable {
    private let executeBody: @Sendable (RpcTransport, AbortSignal?) async throws -> RpcJsonValue

    public init(execute: @escaping @Sendable (RpcTransport, AbortSignal?) async throws -> RpcJsonValue) {
        executeBody = execute
    }

    public func execute(transport: RpcTransport, abortSignal: AbortSignal? = nil) async throws -> RpcJsonValue {
        try await executeBody(transport, abortSignal)
    }
}

public struct JsonRpcApi: Sendable {
    private let config: RpcApiConfig

    public init(config: RpcApiConfig = RpcApiConfig()) {
        self.config = config
    }

    public func plan(methodName: String, params: [RpcJsonValue]) throws -> RpcPlan {
        let rawRequest = RpcRequest(methodName: methodName, params: .array(params))
        let request = try config.requestTransformer?(rawRequest) ?? rawRequest
        return RpcPlan { transport, abortSignal in
            let message = createRpcMessage(request)
            let response = try await transport(RpcTransportConfig(payload: message.jsonValue, abortSignal: abortSignal))
            guard let responseTransformer = config.responseTransformer else {
                return response
            }
            return try responseTransformer(response, request)
        }
    }
}

public func createJsonRpcApi(config: RpcApiConfig = RpcApiConfig()) -> JsonRpcApi {
    JsonRpcApi(config: config)
}

public struct PendingRpcRequest: Sendable {
    private let plan: RpcPlan
    private let transport: RpcTransport

    public init(plan: RpcPlan, transport: @escaping RpcTransport) {
        self.plan = plan
        self.transport = transport
    }

    public func send(abortSignal: AbortSignal? = nil) async throws -> RpcJsonValue {
        try await plan.execute(transport: transport, abortSignal: abortSignal)
    }

    public func reactiveStore() -> ReactiveActionStore<RpcJsonValue> {
        let store: ReactiveActionStore<RpcJsonValue> = createReactiveActionStore { signal in
            try await plan.execute(transport: transport, abortSignal: signal)
        }
        store.dispatch()
        return store
    }
}

public struct Rpc: Sendable {
    private let api: JsonRpcApi
    private let transport: RpcTransport

    public init(api: JsonRpcApi, transport: @escaping RpcTransport) {
        self.api = api
        self.transport = transport
    }

    public func request(_ methodName: String, params: [RpcJsonValue]) throws -> PendingRpcRequest {
        let plan = try api.plan(methodName: methodName, params: params)
        return PendingRpcRequest(plan: plan, transport: transport)
    }
}

public func createRpc(api: JsonRpcApi, transport: @escaping RpcTransport) -> Rpc {
    Rpc(api: api, transport: transport)
}

public func isJsonRpcPayload(_ payload: RpcJsonValue) -> Bool {
    guard case let .object(members) = payload else { return false }
    let hasVersion = members.contains { $0.key == "jsonrpc" && $0.value == .string("2.0") }
    let hasMethod = members.contains {
        if case .string = $0.value, $0.key == "method" { return true }
        return false
    }
    let hasParams = members.contains { $0.key == "params" }
    return hasVersion && hasMethod && hasParams
}
