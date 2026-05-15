public import Addresses
public import Foundation
public import Keys
public import Promises
public import RpcTypes
public import TransactionMessages
public import Transactions

public typealias GetBlockHeightExceedencePromise = @Sendable (BlockHeightExceedenceConfig) async throws -> Void
public typealias GetNonceInvalidationPromise = @Sendable (NonceInvalidationConfig) async throws -> Void
public typealias GetRecentSignatureConfirmationPromise = @Sendable (RecentSignatureConfirmationConfig) async throws -> Void
public typealias GetTimeoutPromise = @Sendable (TimeoutPromiseConfig) async throws -> Void

public struct EpochInfo: Sendable, Equatable, Hashable {
    public let absoluteSlot: Slot
    public let blockHeight: UInt64
    public init(absoluteSlot: Slot, blockHeight: UInt64)
}

public struct SlotNotification: Sendable, Equatable, Hashable {
    public let slot: Slot
    public init(slot: Slot)
}

public struct BlockHeightExceedenceSources: Sendable {
    public let getEpochInfo: @Sendable (Commitment?, AbortSignal) async throws -> EpochInfo
    public let slotNotifications: @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SlotNotification, any Error>
    public init(
        getEpochInfo: @escaping @Sendable (Commitment?, AbortSignal) async throws -> EpochInfo,
        slotNotifications: @escaping @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SlotNotification, any Error>
    )
}

public struct BlockHeightExceedenceConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment?
    public let lastValidBlockHeight: UInt64
    public init(abortSignal: AbortSignal, commitment: Commitment? = nil, lastValidBlockHeight: UInt64)
}

public struct EncodedDataResponse: Sendable, Equatable, Hashable {
    public let data: String
    public let encoding: String
    public init(data: String, encoding: String)
}

public struct NonceAccountInfo: Sendable, Equatable, Hashable {
    public let data: EncodedDataResponse
    public init(data: EncodedDataResponse)
}

public struct AccountNotification: Sendable, Equatable, Hashable {
    public let value: NonceAccountInfo
    public init(value: NonceAccountInfo)
}

public struct NonceInvalidationSources: Sendable {
    public let getAccountInfo: @Sendable (Address, Commitment, AbortSignal) async throws -> NonceAccountInfo?
    public let accountNotifications: @Sendable (Address, Commitment, AbortSignal) async throws -> AsyncThrowingStream<AccountNotification, any Error>
    public init(
        getAccountInfo: @escaping @Sendable (Address, Commitment, AbortSignal) async throws -> NonceAccountInfo?,
        accountNotifications: @escaping @Sendable (Address, Commitment, AbortSignal) async throws -> AsyncThrowingStream<AccountNotification, any Error>
    )
}

public struct NonceInvalidationConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment
    public let currentNonceValue: Nonce
    public let nonceAccountAddress: Address
    public init(abortSignal: AbortSignal, commitment: Commitment, currentNonceValue: Nonce, nonceAccountAddress: Address)
}

public typealias TransactionErrorValue = RpcTransactionError

public struct SignatureStatus: Sendable, Equatable, Hashable {
    public let confirmationStatus: Commitment?
    public let err: TransactionErrorValue?
    public init(confirmationStatus: Commitment? = nil, err: TransactionErrorValue? = nil)
}

public struct SignatureNotification: Sendable, Equatable, Hashable {
    public let value: SignatureStatus
    public init(value: SignatureStatus)
}

public struct RecentSignatureConfirmationSources: Sendable {
    public let getSignatureStatuses: @Sendable ([Signature], AbortSignal) async throws -> [SignatureStatus?]
    public let signatureNotifications: @Sendable (Signature, Commitment, AbortSignal) async throws -> AsyncThrowingStream<SignatureNotification, any Error>
    public init(
        getSignatureStatuses: @escaping @Sendable ([Signature], AbortSignal) async throws -> [SignatureStatus?],
        signatureNotifications: @escaping @Sendable (Signature, Commitment, AbortSignal) async throws -> AsyncThrowingStream<SignatureNotification, any Error>
    )
}

public struct RecentSignatureConfirmationConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment
    public let signature: Signature
    public init(abortSignal: AbortSignal, commitment: Commitment, signature: Signature)
}

public struct TimeoutPromiseConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment
    public init(abortSignal: AbortSignal, commitment: Commitment)
}

public struct TimeoutError: Error, Sendable, Equatable, LocalizedError {
    public let elapsedNanoseconds: UInt64
    public init(elapsedNanoseconds: UInt64)
    public var errorDescription: String? { get }
}

public struct DurableNonceTransactionConfirmationConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment
    public let getNonceInvalidationPromise: GetNonceInvalidationPromise
    public let getRecentSignatureConfirmationPromise: GetRecentSignatureConfirmationPromise
    public let transaction: Transaction
    public init(
        abortSignal: AbortSignal? = nil,
        commitment: Commitment,
        getNonceInvalidationPromise: @escaping GetNonceInvalidationPromise,
        getRecentSignatureConfirmationPromise: @escaping GetRecentSignatureConfirmationPromise,
        transaction: Transaction
    )
}

public struct RecentTransactionConfirmationConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment
    public let getBlockHeightExceedencePromise: GetBlockHeightExceedencePromise
    public let getRecentSignatureConfirmationPromise: GetRecentSignatureConfirmationPromise
    public let transaction: Transaction
    public init(
        abortSignal: AbortSignal? = nil,
        commitment: Commitment,
        getBlockHeightExceedencePromise: @escaping GetBlockHeightExceedencePromise,
        getRecentSignatureConfirmationPromise: @escaping GetRecentSignatureConfirmationPromise,
        transaction: Transaction
    )
}

public struct TimeBasedTransactionConfirmationConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment
    public let getRecentSignatureConfirmationPromise: GetRecentSignatureConfirmationPromise
    public let getTimeoutPromise: GetTimeoutPromise
    public let signature: Signature
    public init(
        abortSignal: AbortSignal? = nil,
        commitment: Commitment,
        getRecentSignatureConfirmationPromise: @escaping GetRecentSignatureConfirmationPromise,
        getTimeoutPromise: @escaping GetTimeoutPromise,
        signature: Signature
    )
}

public func createBlockHeightExceedencePromiseFactory(_ sources: BlockHeightExceedenceSources) -> GetBlockHeightExceedencePromise
public func createNonceInvalidationPromiseFactory(_ sources: NonceInvalidationSources) -> GetNonceInvalidationPromise
public func createRecentSignatureConfirmationPromiseFactory(_ sources: RecentSignatureConfirmationSources) -> GetRecentSignatureConfirmationPromise
public func getTimeoutPromise(_ config: TimeoutPromiseConfig) async throws
public func waitForDurableNonceTransactionConfirmation(_ config: DurableNonceTransactionConfirmationConfig) async throws
public func waitForRecentTransactionConfirmation(_ config: RecentTransactionConfirmationConfig) async throws
public func waitForRecentTransactionConfirmationUntilTimeout(_ config: TimeBasedTransactionConfirmationConfig) async throws
