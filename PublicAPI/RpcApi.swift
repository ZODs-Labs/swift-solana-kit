public import Addresses
public import RpcSpec
public import RpcSpecTypes
public import RpcTransformers
public import RpcTypes

public struct SolanaRpcApi: Sendable {
    public init(api: JsonRpcApi)
    public func plan(methodName: String, params: [RpcJsonValue]) throws -> RpcPlan
    public func getAccountInfo(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getBalance(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getBlock(_ slot: Slot, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getBlockCommitment(_ slot: Slot) throws -> RpcPlan
    public func getBlockHeight(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getBlockProduction(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getBlockTime(_ blockNumber: Slot) throws -> RpcPlan
    public func getBlocks(_ startSlotInclusive: Slot, endSlotInclusive: Slot? = nil, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getBlocksWithLimit(_ startSlotInclusive: Slot, limit: Int, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getClusterNodes() throws -> RpcPlan
}

public typealias SolanaRpcApiDevnet = SolanaRpcApi
public typealias SolanaRpcApiTestnet = SolanaRpcApi
public typealias SolanaRpcApiMainnet = SolanaRpcApi

public func createSolanaRpcApi(_ config: RequestTransformerConfig = RequestTransformerConfig()) -> SolanaRpcApi
public func getAllowedNumericKeypathsForSolanaRpcApi() -> [String: [RpcKeyPath]]
