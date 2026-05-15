public import RpcSpecTypes
public import RpcTypes

public enum RpcKeyPathComponent: Sendable, Equatable, Hashable {
    case key(String)
    case index(Int)
    case wildcard
}

public typealias RpcKeyPath = [RpcKeyPathComponent]
public typealias IntegerOverflowHandler = @Sendable (RpcRequest, RpcKeyPath, String) throws -> Void

public struct RequestTransformerConfig: Sendable {
    public let defaultCommitment: Commitment?
    public let onIntegerOverflow: IntegerOverflowHandler?
    public init(defaultCommitment: Commitment? = nil, onIntegerOverflow: IntegerOverflowHandler? = nil)
}

public struct ResponseTransformerConfig: Sendable {
    public let allowedNumericKeyPaths: [String: [RpcKeyPath]]
    public init(allowedNumericKeyPaths: [String: [RpcKeyPath]] = [:])
}

public let keyPathWildcard: RpcKeyPathComponent
public let optionsObjectPositionByMethod: [String: Int]

public func downcastNodeToNumberIfBigint(_ value: RpcJsonValue) -> RpcJsonValue
public func getBigIntDowncastRequestTransformer() -> RpcRequestTransformer
public func getIntegerOverflowRequestTransformer(_ onIntegerOverflow: @escaping IntegerOverflowHandler) -> RpcRequestTransformer
public func getDefaultCommitmentRequestTransformer(defaultCommitment: Commitment?, optionsObjectPositionByMethod: [String: Int]) -> RpcRequestTransformer
public func getDefaultRequestTransformerForSolanaRpc(_ config: RequestTransformerConfig) -> RpcRequestTransformer

public func getBigIntUpcastResponseTransformer(allowedNumericKeyPaths: [RpcKeyPath]) -> RpcResponseTransformer
public func getResultResponseTransformer() -> RpcResponseTransformer
public func getThrowSolanaErrorResponseTransformer() -> RpcResponseTransformer
public func getDefaultResponseTransformerForSolanaRpc(_ config: ResponseTransformerConfig) -> RpcResponseTransformer
public func getDefaultResponseTransformerForSolanaRpcSubscriptions(_ config: ResponseTransformerConfig) -> RpcResponseTransformer
