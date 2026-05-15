public import Foundation

public struct RpcJsonObjectMember: Sendable, Equatable, Hashable {
    public let key: String
    public let value: RpcJsonValue
    public init(_ key: String, _ value: RpcJsonValue)
}

public indirect enum RpcJsonValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case string(String)
    case number(Double)
    case bigint(String)
    case array([RpcJsonValue])
    case object([RpcJsonObjectMember])

    public static func object(_ pairs: [(String, RpcJsonValue)]) -> RpcJsonValue
    public var objectMembers: [RpcJsonObjectMember]? { get }
    public func value(for key: String) -> RpcJsonValue?
}

public struct RpcRequest: Sendable, Equatable, Hashable {
    public let methodName: String
    public let params: RpcJsonValue
    public init(methodName: String, params: RpcJsonValue)
}

public struct RpcMessage: Sendable, Equatable, Hashable {
    public let id: String
    public let jsonrpc: String
    public let method: String
    public let params: RpcJsonValue
    public init(id: String, jsonrpc: String = "2.0", method: String, params: RpcJsonValue)
    public var jsonValue: RpcJsonValue { get }
}

public struct RpcResponseErrorPayload: Sendable, Equatable, Hashable {
    public let code: Int
    public let message: String
    public let data: RpcJsonValue?
    public init(code: Int, message: String, data: RpcJsonValue? = nil)
}

public enum RpcResponseData: Sendable, Equatable, Hashable {
    case result(id: String, value: RpcJsonValue)
    case error(id: String, error: RpcResponseErrorPayload)
}

public typealias RpcRequestTransformer = @Sendable (RpcRequest) throws -> RpcRequest

public struct RpcResponseTransformer: Sendable {
    public init(_ transform: @escaping @Sendable (RpcJsonValue, RpcRequest) throws -> RpcJsonValue)
    public func callAsFunction(_ response: RpcJsonValue, _ request: RpcRequest) throws -> RpcJsonValue
}

public func parseJsonWithBigInts(_ json: String) throws -> RpcJsonValue
public func stringifyJsonWithBigInts(_ value: RpcJsonValue, space: Int? = nil) throws -> String
public func stringifyJsonWithBigInts(_ value: RpcJsonValue, space: String) throws -> String
public func createRpcMessage(_ request: RpcRequest) -> RpcMessage
