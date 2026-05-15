public import Addresses
internal import CodecsStrings
public import Foundation
public import Keys
public import Promises
public import RpcTypes
internal import SolanaErrors
public import TransactionMessages
public import Transactions

public typealias GetBlockHeightExceedencePromise = @Sendable (BlockHeightExceedenceConfig) async throws -> Void
public typealias GetNonceInvalidationPromise = @Sendable (NonceInvalidationConfig) async throws -> Void
public typealias GetRecentSignatureConfirmationPromise = @Sendable (RecentSignatureConfirmationConfig) async throws -> Void
public typealias GetTimeoutPromise = @Sendable (TimeoutPromiseConfig) async throws -> Void

public struct EpochInfo: Sendable, Equatable, Hashable {
    public let absoluteSlot: Slot
    public let blockHeight: UInt64

    public init(absoluteSlot: Slot, blockHeight: UInt64) {
        self.absoluteSlot = absoluteSlot
        self.blockHeight = blockHeight
    }
}

public struct SlotNotification: Sendable, Equatable, Hashable {
    public let slot: Slot

    public init(slot: Slot) {
        self.slot = slot
    }
}

public struct BlockHeightExceedenceSources: Sendable {
    public let getEpochInfo: @Sendable (Commitment?, AbortSignal) async throws -> EpochInfo
    public let slotNotifications: @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SlotNotification, any Error>

    public init(
        getEpochInfo: @escaping @Sendable (Commitment?, AbortSignal) async throws -> EpochInfo,
        slotNotifications: @escaping @Sendable (AbortSignal) async throws -> AsyncThrowingStream<SlotNotification, any Error>
    ) {
        self.getEpochInfo = getEpochInfo
        self.slotNotifications = slotNotifications
    }
}

public struct BlockHeightExceedenceConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment?
    public let lastValidBlockHeight: UInt64

    public init(abortSignal: AbortSignal, commitment: Commitment? = nil, lastValidBlockHeight: UInt64) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.lastValidBlockHeight = lastValidBlockHeight
    }
}

public struct EncodedDataResponse: Sendable, Equatable, Hashable {
    public let data: String
    public let encoding: String

    public init(data: String, encoding: String) {
        self.data = data
        self.encoding = encoding
    }
}

public struct NonceAccountInfo: Sendable, Equatable, Hashable {
    public let data: EncodedDataResponse

    public init(data: EncodedDataResponse) {
        self.data = data
    }
}

public struct AccountNotification: Sendable, Equatable, Hashable {
    public let value: NonceAccountInfo

    public init(value: NonceAccountInfo) {
        self.value = value
    }
}

public struct NonceInvalidationSources: Sendable {
    public let getAccountInfo: @Sendable (Address, Commitment, AbortSignal) async throws -> NonceAccountInfo?
    public let accountNotifications: @Sendable (Address, Commitment, AbortSignal) async throws -> AsyncThrowingStream<AccountNotification, any Error>

    public init(
        getAccountInfo: @escaping @Sendable (Address, Commitment, AbortSignal) async throws -> NonceAccountInfo?,
        accountNotifications: @escaping @Sendable (Address, Commitment, AbortSignal) async throws -> AsyncThrowingStream<AccountNotification, any Error>
    ) {
        self.getAccountInfo = getAccountInfo
        self.accountNotifications = accountNotifications
    }
}

public struct NonceInvalidationConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment
    public let currentNonceValue: Nonce
    public let nonceAccountAddress: Address

    public init(abortSignal: AbortSignal, commitment: Commitment, currentNonceValue: Nonce, nonceAccountAddress: Address) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.currentNonceValue = currentNonceValue
        self.nonceAccountAddress = nonceAccountAddress
    }
}

public typealias TransactionErrorValue = RpcTransactionError

public struct SignatureStatus: Sendable, Equatable, Hashable {
    public let confirmationStatus: Commitment?
    public let err: TransactionErrorValue?

    public init(confirmationStatus: Commitment? = nil, err: TransactionErrorValue? = nil) {
        self.confirmationStatus = confirmationStatus
        self.err = err
    }
}

public struct SignatureNotification: Sendable, Equatable, Hashable {
    public let value: SignatureStatus

    public init(value: SignatureStatus) {
        self.value = value
    }
}

public struct RecentSignatureConfirmationSources: Sendable {
    public let getSignatureStatuses: @Sendable ([Signature], AbortSignal) async throws -> [SignatureStatus?]
    public let signatureNotifications: @Sendable (Signature, Commitment, AbortSignal) async throws -> AsyncThrowingStream<SignatureNotification, any Error>

    public init(
        getSignatureStatuses: @escaping @Sendable ([Signature], AbortSignal) async throws -> [SignatureStatus?],
        signatureNotifications: @escaping @Sendable (Signature, Commitment, AbortSignal) async throws -> AsyncThrowingStream<SignatureNotification, any Error>
    ) {
        self.getSignatureStatuses = getSignatureStatuses
        self.signatureNotifications = signatureNotifications
    }
}

public struct RecentSignatureConfirmationConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment
    public let signature: Signature

    public init(abortSignal: AbortSignal, commitment: Commitment, signature: Signature) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.signature = signature
    }
}

public struct TimeoutPromiseConfig: Sendable {
    public let abortSignal: AbortSignal
    public let commitment: Commitment

    public init(abortSignal: AbortSignal, commitment: Commitment) {
        self.abortSignal = abortSignal
        self.commitment = commitment
    }
}

public struct TimeoutError: Error, Sendable, Equatable, LocalizedError {
    public let elapsedNanoseconds: UInt64

    public init(elapsedNanoseconds: UInt64) {
        self.elapsedNanoseconds = elapsedNanoseconds
    }

    public var errorDescription: String? {
        "Timeout elapsed after \(elapsedNanoseconds / 1_000_000) ms"
    }
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
    ) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.getNonceInvalidationPromise = getNonceInvalidationPromise
        self.getRecentSignatureConfirmationPromise = getRecentSignatureConfirmationPromise
        self.transaction = transaction
    }
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
    ) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.getBlockHeightExceedencePromise = getBlockHeightExceedencePromise
        self.getRecentSignatureConfirmationPromise = getRecentSignatureConfirmationPromise
        self.transaction = transaction
    }
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
    ) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.getRecentSignatureConfirmationPromise = getRecentSignatureConfirmationPromise
        self.getTimeoutPromise = getTimeoutPromise
        self.signature = signature
    }
}

public func createBlockHeightExceedencePromiseFactory(_ sources: BlockHeightExceedenceSources) -> GetBlockHeightExceedencePromise {
    { config in
        let childAbortSignal = AbortSignal()
        let removeAbortForwarder = config.abortSignal.addAbortHandler { reason in
            childAbortSignal.abort(reason: reason)
        }
        defer {
            removeAbortForwarder()
            childAbortSignal.abort()
        }
        try await getAbortablePromise({
            async let notifications = sources.slotNotifications(childAbortSignal)
            async let epochInfo = sources.getEpochInfo(config.commitment, childAbortSignal)
            let (slotNotifications, initialEpochInfo) = try await (notifications, epochInfo)
            if let reason = config.abortSignal.abortReason() {
                throw reason
            }
            var currentBlockHeight = initialEpochInfo.blockHeight
            if currentBlockHeight <= config.lastValidBlockHeight {
                var slotHeightBlockHeightDelta = initialEpochInfo.absoluteSlot - initialEpochInfo.blockHeight
                for try await notification in slotNotifications {
                    if notification.slot > slotHeightBlockHeightDelta,
                       notification.slot - slotHeightBlockHeightDelta > config.lastValidBlockHeight
                    {
                        let rechecked = try await sources.getEpochInfo(config.commitment, childAbortSignal)
                        currentBlockHeight = rechecked.blockHeight
                        if currentBlockHeight > config.lastValidBlockHeight {
                            break
                        }
                        slotHeightBlockHeightDelta = rechecked.absoluteSlot - rechecked.blockHeight
                    }
                }
            }
            if let reason = config.abortSignal.abortReason() {
                throw reason
            }
            throw SolanaError(
                .blockHeightExceeded,
                context: [
                    "currentBlockHeight": .uint(currentBlockHeight),
                    "lastValidBlockHeight": .uint(config.lastValidBlockHeight),
                ]
            )
        }, abortSignal: config.abortSignal)
    }
}

public func createNonceInvalidationPromiseFactory(_ sources: NonceInvalidationSources) -> GetNonceInvalidationPromise {
    { config in
        let childAbortSignal = AbortSignal()
        let removeAbortForwarder = config.abortSignal.addAbortHandler { reason in
            childAbortSignal.abort(reason: reason)
        }
        defer {
            removeAbortForwarder()
            childAbortSignal.abort()
        }
        let notifications = try await sources.accountNotifications(
            config.nonceAccountAddress,
            config.commitment,
            childAbortSignal
        )
        let nonceAccountDidAdvance: @Sendable () async throws -> Void = {
            for try await notification in notifications {
                let nonceValue = try nonceValueFromBase64AccountData(notification.value.data)
                if nonceValue != config.currentNonceValue {
                    throw invalidNonceError(actual: nonceValue, expected: config.currentNonceValue)
                }
            }
        }
        let nonceIsAlreadyInvalid: @Sendable () async throws -> Void = {
            guard let account = try await sources.getAccountInfo(
                config.nonceAccountAddress,
                config.commitment,
                childAbortSignal
            ) else {
                throw SolanaError(
                    .nonceAccountNotFound,
                    context: ["nonceAccountAddress": .string(config.nonceAccountAddress.rawValue)]
                )
            }
            let nonceValue = try nonceValueFromSlicedAccountData(account.data)
            if nonceValue != config.currentNonceValue {
                throw invalidNonceError(actual: nonceValue, expected: config.currentNonceValue)
            }
            try await neverVoid()
        }
        try await safeRace([
            nonceAccountDidAdvance,
            nonceIsAlreadyInvalid,
        ])
    }
}

public func createRecentSignatureConfirmationPromiseFactory(_ sources: RecentSignatureConfirmationSources) -> GetRecentSignatureConfirmationPromise {
    { config in
        let childAbortSignal = AbortSignal()
        let removeAbortForwarder = config.abortSignal.addAbortHandler { reason in
            childAbortSignal.abort(reason: reason)
        }
        defer {
            removeAbortForwarder()
            childAbortSignal.abort()
        }
        let notifications = try await sources.signatureNotifications(
            config.signature,
            config.commitment,
            childAbortSignal
        )
        let signatureDidCommit: @Sendable () async throws -> Void = {
            for try await notification in notifications {
                if let error = notification.value.err {
                    throw solanaErrorFromTransactionError(error)
                }
                return ()
            }
        }
        let signatureStatusLookup: @Sendable () async throws -> Void = {
            let statuses = try await sources.getSignatureStatuses([config.signature], childAbortSignal)
            guard let status = statuses.first ?? nil else {
                try await neverVoid()
                return
            }
            if let error = status.err {
                throw solanaErrorFromTransactionError(error)
            }
            if let confirmationStatus = status.confirmationStatus,
               commitmentComparator(confirmationStatus, config.commitment) >= 0
            {
                return ()
            }
            try await neverVoid()
        }
        try await safeRace([
            signatureDidCommit,
            signatureStatusLookup,
        ])
    }
}

public func getTimeoutPromise(_ config: TimeoutPromiseConfig) async throws {
    try await getTimeoutPromise(config, timeoutNanoseconds: timeoutNanoseconds(for: config.commitment))
}

public func waitForDurableNonceTransactionConfirmation(_ config: DurableNonceTransactionConfirmationConfig) async throws {
    let signature = try getSignatureFromTransaction(config.transaction)
    guard case let .nonce(lifetimeConstraint) = config.transaction.lifetimeConstraint else {
        throw SolanaError(.transactionExpectedNonceLifetime)
    }
    try await raceStrategies(
        signature: signature,
        abortSignal: config.abortSignal,
        commitment: config.commitment,
        getRecentSignatureConfirmationPromise: config.getRecentSignatureConfirmationPromise
    ) { abortSignal in
        [
            {
                try await config.getNonceInvalidationPromise(
                    NonceInvalidationConfig(
                        abortSignal: abortSignal,
                        commitment: config.commitment,
                        currentNonceValue: lifetimeConstraint.nonce,
                        nonceAccountAddress: lifetimeConstraint.nonceAccountAddress
                    )
                )
            },
        ]
    }
}

/// Waits until a blockhash-based transaction is confirmed or its lifetime expires.
public func waitForRecentTransactionConfirmation(_ config: RecentTransactionConfirmationConfig) async throws {
    let signature = try getSignatureFromTransaction(config.transaction)
    guard case let .blockhash(lifetimeConstraint) = config.transaction.lifetimeConstraint else {
        throw SolanaError(.transactionExpectedBlockhashLifetime)
    }
    try await raceStrategies(
        signature: signature,
        abortSignal: config.abortSignal,
        commitment: config.commitment,
        getRecentSignatureConfirmationPromise: config.getRecentSignatureConfirmationPromise
    ) { abortSignal in
        [
            {
                try await config.getBlockHeightExceedencePromise(
                    BlockHeightExceedenceConfig(
                        abortSignal: abortSignal,
                        commitment: config.commitment,
                        lastValidBlockHeight: lifetimeConstraint.lastValidBlockHeight
                    )
                )
            },
        ]
    }
}

public func waitForRecentTransactionConfirmationUntilTimeout(_ config: TimeBasedTransactionConfirmationConfig) async throws {
    try await raceStrategies(
        signature: config.signature,
        abortSignal: config.abortSignal,
        commitment: config.commitment,
        getRecentSignatureConfirmationPromise: config.getRecentSignatureConfirmationPromise
    ) { abortSignal in
        [
            {
                try await config.getTimeoutPromise(TimeoutPromiseConfig(abortSignal: abortSignal, commitment: config.commitment))
            },
        ]
    }
}

func timeoutNanoseconds(for commitment: Commitment) -> UInt64 {
    commitment == .processed ? 30_000_000_000 : 60_000_000_000
}

func getTimeoutPromise(_ config: TimeoutPromiseConfig, timeoutNanoseconds: UInt64) async throws {
    let start = ContinuousClock.now
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            let reason = await config.abortSignal.waitUntilFutureAbort()
            if Task.isCancelled {
                return
            }
            throw reason
        }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            let elapsed = start.duration(to: ContinuousClock.now)
            throw TimeoutError(elapsedNanoseconds: elapsed.nanoseconds)
        }
        defer {
            group.cancelAll()
        }
        _ = try await group.next()
    }
}

private func raceStrategies(
    signature: Signature,
    abortSignal callerAbortSignal: AbortSignal?,
    commitment: Commitment,
    getRecentSignatureConfirmationPromise: @escaping GetRecentSignatureConfirmationPromise,
    getSpecificStrategiesForRace: @escaping @Sendable (AbortSignal) -> [@Sendable () async throws -> Void]
) async throws {
    let childAbortSignal = AbortSignal()
    let removeAbortForwarder: (@Sendable () -> Void)?
    if let callerAbortSignal {
        if let reason = callerAbortSignal.abortReason() {
            throw reason
        }
        removeAbortForwarder = callerAbortSignal.addAbortHandler { reason in
            childAbortSignal.abort(reason: reason)
        }
    } else {
        removeAbortForwarder = nil
    }
    defer {
        removeAbortForwarder?()
        childAbortSignal.abort()
    }
    try await getAbortablePromise({
        let recent: @Sendable () async throws -> Void = {
            try await getRecentSignatureConfirmationPromise(
                RecentSignatureConfirmationConfig(
                    abortSignal: childAbortSignal,
                    commitment: commitment,
                    signature: signature
                )
            )
        }
        try await safeRace([recent] + getSpecificStrategiesForRace(childAbortSignal))
    }, abortSignal: callerAbortSignal)
}

private func nonceValueFromSlicedAccountData(_ data: EncodedDataResponse) throws -> Nonce {
    if data.encoding == "base58" {
        return data.data
    }
    if data.encoding == "base64" {
        return try nonceValueFromBase64AccountData(data)
    }
    throw CodecsError.invalidPatternMatchValue
}

private func nonceValueFromBase64AccountData(_ data: EncodedDataResponse) throws -> Nonce {
    guard data.encoding == "base64" else {
        throw CodecsError.invalidPatternMatchValue
    }
    let decoded = try getBase64Encoder().encode(data.data)
    let start = nonceValueOffset
    let end = start + 32
    guard decoded.count >= end else {
        throw CodecsError.invalidByteLength(codecDescription: "nonce account", expected: end, bytesLength: decoded.count)
    }
    return try getBase58Decoder().decode(Data(decoded[start ..< end]))
}

private func invalidNonceError(actual: Nonce, expected: Nonce) -> SolanaError {
    SolanaError(
        .invalidNonce,
        context: [
            "actualNonceValue": .string(actual),
            "expectedNonceValue": .string(expected),
        ]
    )
}

private func solanaErrorFromTransactionError(_ error: TransactionErrorValue) -> SolanaError {
    switch error {
    case .accountBorrowOutstanding:
        return SolanaError(.transactionErrorAccountBorrowOutstanding)
    case .accountInUse:
        return SolanaError(.transactionErrorAccountInUse)
    case .accountLoadedTwice:
        return SolanaError(.transactionErrorAccountLoadedTwice)
    case .accountNotFound:
        return SolanaError(.transactionErrorAccountNotFound)
    case .addressLookupTableNotFound:
        return SolanaError(.transactionErrorAddressLookupTableNotFound)
    case .alreadyProcessed:
        return SolanaError(.transactionErrorAlreadyProcessed)
    case .blockhashNotFound:
        return SolanaError(.transactionErrorBlockhashNotFound)
    case .callChainTooDeep:
        return SolanaError(.transactionErrorCallChainTooDeep)
    case .clusterMaintenance:
        return SolanaError(.transactionErrorClusterMaintenance)
    case .insufficientFundsForFee:
        return SolanaError(.transactionErrorInsufficientFundsForFee)
    case .invalidAccountForFee:
        return SolanaError(.transactionErrorInvalidAccountForFee)
    case .invalidAccountIndex:
        return SolanaError(.transactionErrorInvalidAccountIndex)
    case .invalidAddressLookupTableData:
        return SolanaError(.transactionErrorInvalidAddressLookupTableData)
    case .invalidAddressLookupTableIndex:
        return SolanaError(.transactionErrorInvalidAddressLookupTableIndex)
    case .invalidAddressLookupTableOwner:
        return SolanaError(.transactionErrorInvalidAddressLookupTableOwner)
    case .invalidLoadedAccountsDataSizeLimit:
        return SolanaError(.transactionErrorInvalidLoadedAccountsDataSizeLimit)
    case .invalidProgramForExecution:
        return SolanaError(.transactionErrorInvalidProgramForExecution)
    case .invalidRentPayingAccount:
        return SolanaError(.transactionErrorInvalidRentPayingAccount)
    case .invalidWritableAccount:
        return SolanaError(.transactionErrorInvalidWritableAccount)
    case .maxLoadedAccountsDataSizeExceeded:
        return SolanaError(.transactionErrorMaxLoadedAccountsDataSizeExceeded)
    case .missingSignatureForFee:
        return SolanaError(.transactionErrorMissingSignatureForFee)
    case .programAccountNotFound:
        return SolanaError(.transactionErrorProgramAccountNotFound)
    case .resanitizationNeeded:
        return SolanaError(.transactionErrorResanitizationNeeded)
    case .sanitizeFailure:
        return SolanaError(.transactionErrorSanitizeFailure)
    case .signatureFailure:
        return SolanaError(.transactionErrorSignatureFailure)
    case .tooManyAccountLocks:
        return SolanaError(.transactionErrorTooManyAccountLocks)
    case .unbalancedTransaction:
        return SolanaError(.transactionErrorUnbalancedTransaction)
    case .unsupportedVersion:
        return SolanaError(.transactionErrorUnsupportedVersion)
    case .wouldExceedAccountDataBlockLimit:
        return SolanaError(.transactionErrorWouldExceedAccountDataBlockLimit)
    case .wouldExceedAccountDataTotalLimit:
        return SolanaError(.transactionErrorWouldExceedAccountDataTotalLimit)
    case .wouldExceedMaxAccountCostLimit:
        return SolanaError(.transactionErrorWouldExceedMaxAccountCostLimit)
    case .wouldExceedMaxBlockCostLimit:
        return SolanaError(.transactionErrorWouldExceedMaxBlockCostLimit)
    case .wouldExceedMaxVoteCostLimit:
        return SolanaError(.transactionErrorWouldExceedMaxVoteCostLimit)
    case let .duplicateInstruction(index):
        return SolanaError(.transactionErrorDuplicateInstruction, context: ["index": .int(index)])
    case let .insufficientFundsForRent(accountIndex):
        return SolanaError(.transactionErrorInsufficientFundsForRent, context: ["accountIndex": .int(accountIndex)])
    case let .programExecutionTemporarilyRestricted(accountIndex):
        return SolanaError(.transactionErrorProgramExecutionTemporarilyRestricted, context: ["accountIndex": .int(accountIndex)])
    case let .unknown(errorName):
        return SolanaError(.transactionErrorUnknown, context: ["errorName": .string(errorName)])
    case let .instructionError(index, instructionError):
        return solanaErrorFromInstructionError(index: index, error: instructionError)
    }
}

private func solanaErrorFromInstructionError(index: Int, error: RpcInstructionError) -> SolanaError {
    let context: SolanaErrorContext
    if case let .custom(code) = error {
        context = ["code": .int(code), "index": .int(index)]
    } else {
        context = ["index": .int(index)]
    }
    return SolanaError(solanaErrorCode(for: error), context: context)
}

private func solanaErrorCode(for error: RpcInstructionError) -> SolanaErrorCode {
    switch error {
    case .accountAlreadyInitialized:
        return .instructionErrorAccountAlreadyInitialized
    case .accountBorrowFailed:
        return .instructionErrorAccountBorrowFailed
    case .accountBorrowOutstanding:
        return .instructionErrorAccountBorrowOutstanding
    case .accountDataSizeChanged:
        return .instructionErrorAccountDataSizeChanged
    case .accountDataTooSmall:
        return .instructionErrorAccountDataTooSmall
    case .accountNotExecutable:
        return .instructionErrorAccountNotExecutable
    case .accountNotRentExempt:
        return .instructionErrorAccountNotRentExempt
    case .arithmeticOverflow:
        return .instructionErrorArithmeticOverflow
    case .borshIoError:
        return .instructionErrorBorshIoError
    case .builtinProgramsMustConsumeComputeUnits:
        return .instructionErrorBuiltinProgramsMustConsumeComputeUnits
    case .callDepth:
        return .instructionErrorCallDepth
    case .computationalBudgetExceeded:
        return .instructionErrorComputationalBudgetExceeded
    case .duplicateAccountIndex:
        return .instructionErrorDuplicateAccountIndex
    case .duplicateAccountOutOfSync:
        return .instructionErrorDuplicateAccountOutOfSync
    case .executableAccountNotRentExempt:
        return .instructionErrorExecutableAccountNotRentExempt
    case .executableDataModified:
        return .instructionErrorExecutableDataModified
    case .executableLamportChange:
        return .instructionErrorExecutableLamportChange
    case .executableModified:
        return .instructionErrorExecutableModified
    case .externalAccountDataModified:
        return .instructionErrorExternalAccountDataModified
    case .externalAccountLamportSpend:
        return .instructionErrorExternalAccountLamportSpend
    case .genericError:
        return .instructionErrorGenericError
    case .illegalOwner:
        return .instructionErrorIllegalOwner
    case .immutable:
        return .instructionErrorImmutable
    case .incorrectAuthority:
        return .instructionErrorIncorrectAuthority
    case .incorrectProgramId:
        return .instructionErrorIncorrectProgramID
    case .insufficientFunds:
        return .instructionErrorInsufficientFunds
    case .invalidAccountData:
        return .instructionErrorInvalidAccountData
    case .invalidAccountOwner:
        return .instructionErrorInvalidAccountOwner
    case .invalidArgument:
        return .instructionErrorInvalidArgument
    case .invalidError:
        return .instructionErrorInvalidError
    case .invalidInstructionData:
        return .instructionErrorInvalidInstructionData
    case .invalidRealloc:
        return .instructionErrorInvalidRealloc
    case .invalidSeeds:
        return .instructionErrorInvalidSeeds
    case .maxAccountsDataAllocationsExceeded:
        return .instructionErrorMaxAccountsDataAllocationsExceeded
    case .maxAccountsExceeded:
        return .instructionErrorMaxAccountsExceeded
    case .maxInstructionTraceLengthExceeded:
        return .instructionErrorMaxInstructionTraceLengthExceeded
    case .maxSeedLengthExceeded:
        return .instructionErrorMaxSeedLengthExceeded
    case .missingAccount:
        return .instructionErrorMissingAccount
    case .missingRequiredSignature:
        return .instructionErrorMissingRequiredSignature
    case .modifiedProgramId:
        return .instructionErrorModifiedProgramID
    case .notEnoughAccountKeys:
        return .instructionErrorNotEnoughAccountKeys
    case .privilegeEscalation:
        return .instructionErrorPrivilegeEscalation
    case .programEnvironmentSetupFailure:
        return .instructionErrorProgramEnvironmentSetupFailure
    case .programFailedToCompile:
        return .instructionErrorProgramFailedToCompile
    case .programFailedToComplete:
        return .instructionErrorProgramFailedToComplete
    case .readonlyDataModified:
        return .instructionErrorReadonlyDataModified
    case .readonlyLamportChange:
        return .instructionErrorReadonlyLamportChange
    case .reentrancyNotAllowed:
        return .instructionErrorReentrancyNotAllowed
    case .rentEpochModified:
        return .instructionErrorRentEpochModified
    case .unbalancedInstruction:
        return .instructionErrorUnbalancedInstruction
    case .uninitializedAccount:
        return .instructionErrorUninitializedAccount
    case .unsupportedProgramId:
        return .instructionErrorUnsupportedProgramID
    case .unsupportedSysvar:
        return .instructionErrorUnsupportedSysvar
    case .custom:
        return .instructionErrorCustom
    }
}

private func neverVoid() async throws {
    while true {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

private let nonceValueOffset = 4 + 4 + 32

private extension Duration {
    var nanoseconds: UInt64 {
        let components = self.components
        let seconds = UInt64(max(0, components.seconds))
        let attoseconds = UInt64(max(0, components.attoseconds))
        return seconds * 1_000_000_000 + attoseconds / 1_000_000_000
    }
}
