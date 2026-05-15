@_exported import Accounts
@_exported import Addresses
@_exported import Codecs
@_exported import Functional
@_exported import InstructionPlans
@_exported import Instructions
@_exported import Keys
@_exported import OffchainMessages
@_exported import PluginCore
@_exported import PluginInterfaces
@_exported import Programs
public import Promises
@_exported import Rpc
@_exported import RpcApi
@_exported import RpcParsedTypes
@_exported import RpcSpec
@_exported import RpcSpecTypes
@_exported import RpcSubscriptions
@_exported import RpcSubscriptionsApi
@_exported import RpcSubscriptionsSpec
@_exported import RpcTypes
@_exported import Signers
@_exported import SolanaErrors
public import Subscribable
@_exported import TransactionMessages
@_exported import Transactions

public typealias AbortSignal = Promises.AbortSignal
public typealias RpcResponse<TResponse> = TResponse

public struct AirdropFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public let rpcSubscriptions: RpcSubscriptions
    public init(rpc: SolanaRpc, rpcSubscriptions: RpcSubscriptions)
}

public struct AirdropConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment
    public let lamports: Lamports
    public let recipientAddress: Address
    public init(abortSignal: AbortSignal? = nil, commitment: Commitment, lamports: Lamports, recipientAddress: Address)
}

public typealias AirdropFunction = @Sendable (AirdropConfig) async throws -> Signature
public func airdropFactory(_ config: AirdropFactoryConfig) -> AirdropFunction

public func getMinimumBalanceForRentExemption(space: UInt64) -> Lamports

public struct EstimateComputeUnitLimitFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public init(rpc: SolanaRpc)
}

public struct EstimateComputeUnitLimitConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment?
    public let minContextSlot: Slot?
    public init(abortSignal: AbortSignal? = nil, commitment: Commitment? = nil, minContextSlot: Slot? = nil)
}

public typealias EstimateComputeUnitLimitFunction = @Sendable (TransactionMessage, EstimateComputeUnitLimitConfig?) async throws -> UInt32
public typealias EstimateAndSetComputeUnitLimitFunction = @Sendable (TransactionMessage, EstimateComputeUnitLimitConfig?) async throws -> TransactionMessage

public func estimateComputeUnitLimitFactory(_ config: EstimateComputeUnitLimitFactoryConfig) -> EstimateComputeUnitLimitFunction
public func estimateAndSetComputeUnitLimitFactory(_ estimateComputeUnitLimit: @escaping EstimateComputeUnitLimitFunction) -> EstimateAndSetComputeUnitLimitFunction
public func fillTransactionMessageProvisoryComputeUnitLimit(_ transactionMessage: TransactionMessage) throws -> TransactionMessage

public struct SendTransactionConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment
    public let maxRetries: UInt64?
    public let minContextSlot: Slot?
    public let preflightCommitment: Commitment?
    public let skipPreflight: Bool?
    public init(
        abortSignal: AbortSignal? = nil,
        commitment: Commitment,
        maxRetries: UInt64? = nil,
        minContextSlot: Slot? = nil,
        preflightCommitment: Commitment? = nil,
        skipPreflight: Bool? = nil
    )
}

public typealias SendTransactionWithoutConfirmingFunction = @Sendable (Transaction, SendTransactionConfig) async throws -> Void
public typealias SendAndConfirmTransactionFunction = @Sendable (Transaction, SendTransactionConfig) async throws -> Void
public typealias SendAndConfirmDurableNonceTransactionFunction = @Sendable (Transaction, SendTransactionConfig) async throws -> Void

public struct SendTransactionWithoutConfirmingFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public init(rpc: SolanaRpc)
}

public struct SendAndConfirmTransactionFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public let rpcSubscriptions: RpcSubscriptions
    public init(rpc: SolanaRpc, rpcSubscriptions: RpcSubscriptions)
}

public struct SendAndConfirmDurableNonceTransactionFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public let rpcSubscriptions: RpcSubscriptions
    public init(rpc: SolanaRpc, rpcSubscriptions: RpcSubscriptions)
}

public func sendTransactionWithoutConfirmingFactory(_ config: SendTransactionWithoutConfirmingFactoryConfig) -> SendTransactionWithoutConfirmingFunction
public func sendAndConfirmTransactionFactory(_ config: SendAndConfirmTransactionFactoryConfig) -> SendAndConfirmTransactionFunction
public func sendAndConfirmDurableNonceTransactionFactory(_ config: SendAndConfirmDurableNonceTransactionFactoryConfig) -> SendAndConfirmDurableNonceTransactionFunction

public func fetchAddressesForLookupTables(
    lookupTableAddresses: [Address],
    rpc: SolanaRpc,
    config: FetchAccountsConfig = FetchAccountsConfig()
) async throws -> AddressesByLookupTableAddress

public func decompileTransactionMessageFetchingLookupTables(
    _ compiledTransactionMessage: CompiledTransactionMessage,
    rpc: SolanaRpc,
    config: FetchAccountsConfig = FetchAccountsConfig(),
    lastValidBlockHeight: UInt64? = nil
) async throws -> TransactionMessage

public struct InitialValueAndSlotTrackingConfig<TRpcValue: Sendable & Equatable & Hashable, TSubscriptionValue: Sendable & Equatable & Hashable, TItem: Sendable & Equatable & Hashable>: Sendable {
    public let abortSignal: AbortSignal
    public let rpcRequest: @Sendable (AbortSignal) async throws -> SolanaRpcResponse<TRpcValue>
    public let rpcSubscriptionRequest: @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SolanaRpcResponse<TSubscriptionValue>, any Error>
    public let rpcSubscriptionValueMapper: @Sendable (TSubscriptionValue) -> TItem
    public let rpcValueMapper: @Sendable (TRpcValue) -> TItem
    public init(
        abortSignal: AbortSignal,
        rpcRequest: @escaping @Sendable (AbortSignal) async throws -> SolanaRpcResponse<TRpcValue>,
        rpcSubscriptionRequest: @escaping @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SolanaRpcResponse<TSubscriptionValue>, any Error>,
        rpcSubscriptionValueMapper: @escaping @Sendable (TSubscriptionValue) -> TItem,
        rpcValueMapper: @escaping @Sendable (TRpcValue) -> TItem
    )
}

public typealias CreateReactiveStoreWithInitialValueAndSlotTrackingConfig<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
> = InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>

public struct InitialValueAndSlotTrackingAsyncSequence<
    TRpcValue: Sendable & Equatable & Hashable,
    TSubscriptionValue: Sendable & Equatable & Hashable,
    TItem: Sendable & Equatable & Hashable
>: AsyncSequence, Sendable {
    public typealias AsyncIterator = Iterator
    public typealias Element = SolanaRpcResponse<TItem>

    public final class Iterator: AsyncIteratorProtocol, Sendable {
        public func next() async throws -> Element?
    }

    public func makeAsyncIterator() -> Iterator
}

public func createAsyncGeneratorWithInitialValueAndSlotTracking<TRpcValue: Sendable & Equatable & Hashable, TSubscriptionValue: Sendable & Equatable & Hashable, TItem: Sendable & Equatable & Hashable>(
    _ config: InitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>
) -> InitialValueAndSlotTrackingAsyncSequence<TRpcValue, TSubscriptionValue, TItem>

public func createReactiveStoreWithInitialValueAndSlotTracking<TRpcValue: Sendable & Equatable & Hashable, TSubscriptionValue: Sendable & Equatable & Hashable, TItem: Sendable & Equatable & Hashable>(
    _ config: CreateReactiveStoreWithInitialValueAndSlotTrackingConfig<TRpcValue, TSubscriptionValue, TItem>
) -> Subscribable.ReactiveStreamStore<SolanaRpcResponse<TItem>>
