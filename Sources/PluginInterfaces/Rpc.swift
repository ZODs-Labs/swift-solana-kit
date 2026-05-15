public import RpcSpec
public import RpcSubscriptionsSpec

public protocol ClientWithRpc: Sendable {
    var rpc: Rpc { get }
}

public protocol ClientWithRpcSubscriptions: Sendable {
    var rpcSubscriptions: RpcSubscriptions { get }
}
