public import Foundation
public import Promises
public import RpcSubscriptionsSpec

public struct WebSocketChannelConfig: Sendable {
    public let sendBufferHighWatermark: Int
    public let signal: AbortSignal
    public let url: URL

    public init(sendBufferHighWatermark: Int, signal: AbortSignal, url: URL)
}

public func createWebSocketChannel(_ config: WebSocketChannelConfig) async throws -> RpcSubscriptionsChannel
