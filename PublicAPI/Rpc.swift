public import Addresses
public import Foundation
public import RpcApi
public import RpcSpec
public import RpcSpecTypes
public import RpcTransformers
public import RpcTypes
public import SolanaErrors

public typealias RpcTransportDevnet = RpcTransport
public typealias RpcTransportTestnet = RpcTransport
public typealias RpcTransportMainnet = RpcTransport

public struct DefaultRpcTransportConfig: Sendable {
    public let url: URL
    public let headers: [String: String]
    public init(url: URL, headers: [String: String] = [:])
}

public struct SolanaRpc: Sendable {
    public init(api: SolanaRpcApi, transport: @escaping RpcTransport)
    public func request(_ methodName: String, params: [RpcJsonValue]) throws -> PendingRpcRequest
    public func getAccountInfo(_ address: Address, config: RpcJsonValue? = nil) throws -> PendingRpcRequest
    public func getBalance(_ address: Address, config: RpcJsonValue? = nil) throws -> PendingRpcRequest
    public func getBlock(_ slot: Slot, config: RpcJsonValue? = nil) throws -> PendingRpcRequest
    public func getBlockCommitment(_ slot: Slot) throws -> PendingRpcRequest
    public func getBlockHeight(config: RpcJsonValue? = nil) throws -> PendingRpcRequest
    public func getBlockProduction(config: RpcJsonValue? = nil) throws -> PendingRpcRequest
    public func getBlockTime(_ blockNumber: Slot) throws -> PendingRpcRequest
    public func getBlocks(_ startSlotInclusive: Slot, endSlotInclusive: Slot? = nil, config: RpcJsonValue? = nil) throws -> PendingRpcRequest
    public func getBlocksWithLimit(_ startSlotInclusive: Slot, limit: Int, config: RpcJsonValue? = nil) throws -> PendingRpcRequest
    public func getClusterNodes() throws -> PendingRpcRequest
}

public func createSolanaJsonRpcIntegerOverflowError(methodName: String, keyPath: RpcKeyPath, value: String) -> SolanaError
public func defaultRpcConfig() -> RequestTransformerConfig
public func getSolanaRpcPayloadDeduplicationKey(_ payload: RpcJsonValue) throws -> String?
public func getRpcTransportWithRequestCoalescing(_ transport: @escaping RpcTransport, getDeduplicationKey: @escaping @Sendable (RpcJsonValue) throws -> String?) -> RpcTransport
public func createDefaultRpcTransport(_ config: DefaultRpcTransportConfig) throws -> RpcTransport
public func createSolanaRpc(_ clusterUrl: URL, headers: [String: String] = [:]) throws -> SolanaRpc
public func createSolanaRpcFromTransport(_ transport: @escaping RpcTransport) -> SolanaRpc
