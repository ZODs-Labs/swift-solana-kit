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
    public func getEpochInfo(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getEpochSchedule() throws -> RpcPlan
    public func getFeeForMessage(_ message: String, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getFirstAvailableBlock() throws -> RpcPlan
    public func getGenesisHash() throws -> RpcPlan
    public func getHealth() throws -> RpcPlan
    public func getHighestSnapshotSlot() throws -> RpcPlan
    public func getIdentity() throws -> RpcPlan
    public func getInflationGovernor(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getInflationRate() throws -> RpcPlan
    public func getInflationReward(_ addresses: [Address], config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getLargestAccounts(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getLatestBlockhash(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getLeaderSchedule() throws -> RpcPlan
    public func getLeaderSchedule(_ slot: Slot?, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getMaxRetransmitSlot() throws -> RpcPlan
    public func getMaxShredInsertSlot() throws -> RpcPlan
    public func getMinimumBalanceForRentExemption(_ size: UInt64, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getMultipleAccounts(_ addresses: [Address], config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getProgramAccounts(_ program: Address, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getRecentPerformanceSamples(limit: Int? = nil) throws -> RpcPlan
    public func getRecentPrioritizationFees(_ addresses: [Address]? = nil) throws -> RpcPlan
    public func getSignatureStatuses(_ signatures: [String], config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getSignaturesForAddress(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getSlot(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getSlotLeader(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getSlotLeaders(_ startSlotInclusive: Slot, limit: Int) throws -> RpcPlan
    public func getStakeMinimumDelegation(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getSupply(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getTokenAccountBalance(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getTokenAccountsByDelegate(_ delegate: Address, filter: RpcJsonValue, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getTokenAccountsByOwner(_ owner: Address, filter: RpcJsonValue, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getTokenLargestAccounts(_ tokenMint: Address, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getTokenSupply(_ tokenMint: Address, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getTransaction(_ signature: String, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getTransactionCount(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func getVersion() throws -> RpcPlan
    public func getVoteAccounts(config: RpcJsonValue? = nil) throws -> RpcPlan
    public func isBlockhashValid(_ blockhash: Blockhash, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func minimumLedgerSlot() throws -> RpcPlan
    public func requestAirdrop(_ recipientAccount: Address, lamports: Lamports, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func sendTransaction(_ base64EncodedWireTransaction: String, config: RpcJsonValue? = nil) throws -> RpcPlan
    public func simulateTransaction(_ wireTransaction: String, config: RpcJsonValue? = nil) throws -> RpcPlan
}

public typealias SolanaRpcApiDevnet = SolanaRpcApi
public typealias SolanaRpcApiTestnet = SolanaRpcApi
public typealias SolanaRpcApiMainnet = SolanaRpcApi

public func createSolanaRpcApi(_ config: RequestTransformerConfig = RequestTransformerConfig()) -> SolanaRpcApi
public func getAllowedNumericKeypathsForSolanaRpcApi() -> [String: [RpcKeyPath]]
