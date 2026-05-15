public import Promises
public import RpcSubscriptionsSpec
public import RpcTypes

public struct DefaultRpcSubscriptionsChannelConfig: Sendable {
    public let intervalMs: Int
    public let maxSubscriptionsPerChannel: Int
    public let minChannels: Int
    public let sendBufferHighWatermark: Int
    public let url: ClusterUrl
    public init(
        url: ClusterUrl,
        intervalMs: Int = 5_000,
        maxSubscriptionsPerChannel: Int = 100,
        minChannels: Int = 1,
        sendBufferHighWatermark: Int = 131_072
    )
}

public struct ChannelPoolingConfig: Sendable {
    public let maxSubscriptionsPerChannel: Int
    public let minChannels: Int
    public init(maxSubscriptionsPerChannel: Int, minChannels: Int)
}

public let defaultRpcSubscriptionsCommitment: Commitment

public func getRpcSubscriptionsChannelWithAutoping(
    abortSignal: AbortSignal,
    channel: RpcSubscriptionsChannel,
    intervalMs: Int
) -> RpcSubscriptionsChannel

public func getChannelPoolingChannelCreator(
    _ createChannel: @escaping RpcSubscriptionsChannelCreator,
    config: ChannelPoolingConfig
) -> RpcSubscriptionsChannelCreator

public func getRpcSubscriptionsChannelWithJSONSerialization(_ channel: RpcSubscriptionsChannel) -> RpcSubscriptionsChannel
public func getRpcSubscriptionsChannelWithBigIntJSONSerialization(_ channel: RpcSubscriptionsChannel) -> RpcSubscriptionsChannel
public func getRpcSubscriptionsTransportWithSubscriptionCoalescing(_ transport: @escaping RpcSubscriptionsTransport) -> RpcSubscriptionsTransport

public func createRpcSubscriptionsTransportFromChannelCreator(
    _ createChannel: @escaping RpcSubscriptionsChannelCreator
) -> RpcSubscriptionsTransport

public func createDefaultRpcSubscriptionsChannelCreator(
    _ config: DefaultRpcSubscriptionsChannelConfig
) throws -> RpcSubscriptionsChannelCreator

public func createDefaultSolanaRpcSubscriptionsChannelCreator(
    _ config: DefaultRpcSubscriptionsChannelConfig
) throws -> RpcSubscriptionsChannelCreator

public func createDefaultRpcSubscriptionsTransport(
    createChannel: @escaping RpcSubscriptionsChannelCreator
) -> RpcSubscriptionsTransport

public func createSolanaRpcSubscriptionsFromTransport(_ transport: @escaping RpcSubscriptionsTransport) -> RpcSubscriptions
public func createSolanaRpcSubscriptions(_ clusterUrl: ClusterUrl, config: DefaultRpcSubscriptionsChannelConfig?) throws -> RpcSubscriptions
public func createSolanaRpcSubscriptions(_ clusterUrl: ClusterUrl) throws -> RpcSubscriptions
public func createSolanaRpcSubscriptions_UNSTABLE(_ clusterUrl: ClusterUrl, config: DefaultRpcSubscriptionsChannelConfig?) throws -> RpcSubscriptions
public func createSolanaRpcSubscriptions_UNSTABLE(_ clusterUrl: ClusterUrl) throws -> RpcSubscriptions
