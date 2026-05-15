public import Foundation
public import RpcSpec
public import RpcSpecTypes

public typealias HttpRequestHeaders = [String: String]

public struct HttpTransportConfig: Sendable {
    public let url: URL
    public let headers: HttpRequestHeaders
    public let toJson: (@Sendable (RpcJsonValue) throws -> String)?
    public let fromJson: (@Sendable (String, RpcJsonValue) throws -> RpcJsonValue)?
    public init(
        url: URL,
        headers: HttpRequestHeaders = [:],
        toJson: (@Sendable (RpcJsonValue) throws -> String)? = nil,
        fromJson: (@Sendable (String, RpcJsonValue) throws -> RpcJsonValue)? = nil
    )
}

public let solanaRpcMethods: Set<String>

public func assertIsAllowedHttpRequestHeaders(_ headers: HttpRequestHeaders) throws
public func normalizeHeaders(_ headers: HttpRequestHeaders) -> HttpRequestHeaders
public func createHttpTransport(_ config: HttpTransportConfig) throws -> RpcTransport
public func createHttpTransportForSolanaRpc(url: URL, headers: HttpRequestHeaders = [:]) throws -> RpcTransport
public func isSolanaRequest(_ payload: RpcJsonValue) -> Bool
