import Foundation
import Keys
import Promises
import Rpc
import RpcSpecTypes
import RpcTypes
import SolanaErrors
import TransactionConfirmation
import Transactions

func kitRpcConfig(_ members: [(String, RpcJsonValue?)]) -> RpcJsonValue {
    .object(members.compactMap { key, value in
        value.map { (key, $0) }
    })
}

func kitSendTransactionConfig(_ config: SendTransactionConfig) -> RpcJsonValue {
    let preflightCommitment = kitAdjustedPreflightCommitment(commitment: config.commitment, config: config)
    return kitRpcConfig([
        ("encoding", .string("base64")),
        ("maxRetries", config.maxRetries.map { .bigint(String($0)) }),
        ("minContextSlot", config.minContextSlot.map { .bigint(String($0)) }),
        ("preflightCommitment", preflightCommitment.map { .string($0.rawValue) }),
        ("skipPreflight", config.skipPreflight.map(RpcJsonValue.bool)),
    ])
}

func kitAdjustedPreflightCommitment(commitment: Commitment, config: SendTransactionConfig) -> Commitment? {
    if let preflightCommitment = config.preflightCommitment {
        return preflightCommitment
    }
    if commitmentComparator(commitment, .finalized) < 0 {
        return commitment
    }
    return nil
}

func kitString(_ value: RpcJsonValue) -> String? {
    if case let .string(string) = value {
        return string
    }
    return nil
}

func kitBool(_ value: RpcJsonValue) -> Bool? {
    if case let .bool(bool) = value {
        return bool
    }
    return nil
}

func kitUInt64(_ value: RpcJsonValue) -> UInt64? {
    switch value {
    case let .number(value):
        return UInt64(exactly: value)
    case let .bigint(string):
        return UInt64(string)
    case let .string(string):
        return UInt64(string)
    default:
        return nil
    }
}

func kitRpcTypeJsonValue(_ value: RpcJsonValue) -> RpcTypeJsonValue {
    switch value {
    case .null:
        return .null
    case let .bool(value):
        return .bool(value)
    case let .string(value):
        return .string(value)
    case let .number(value):
        return .number(String(describing: value))
    case let .bigint(value):
        return .number(value)
    case let .array(values):
        return .array(values.map(kitRpcTypeJsonValue))
    case let .object(members):
        var object: [String: RpcTypeJsonValue] = [:]
        for member in members {
            object[member.key] = kitRpcTypeJsonValue(member.value)
        }
        return .object(object)
    }
}

func kitInt(_ value: RpcJsonValue) -> Int? {
    switch value {
    case let .number(value):
        return Int(exactly: value)
    case let .bigint(string):
        return Int(string)
    case let .string(string):
        return Int(string)
    default:
        return nil
    }
}

func kitCommitment(_ value: RpcJsonValue?) -> Commitment? {
    guard let value, case let .string(rawValue) = value else {
        return nil
    }
    return Commitment(rawValue: rawValue)
}

func kitContextSlot(from value: RpcJsonValue) -> Slot? {
    value.value(for: "context")
        .flatMap { $0.value(for: "slot") }
        .flatMap(kitUInt64)
}

func kitSignatureStatus(from value: RpcJsonValue) -> SignatureStatus? {
    if value == .null {
        return nil
    }
    let status = kitCommitment(value.value(for: "confirmationStatus"))
    let error = value.value(for: "err").flatMap(kitRpcTransactionError)
    return SignatureStatus(confirmationStatus: status, err: error)
}

func kitSignatureStatuses(from value: RpcJsonValue) -> [SignatureStatus?] {
    let values = value.value(for: "value") ?? value
    guard case let .array(items) = values else {
        return []
    }
    return items.map(kitSignatureStatus)
}

func kitSignatureNotification(from value: RpcJsonValue) -> SignatureNotification? {
    let notificationValue = value.value(for: "value") ?? value
    guard let status = kitSignatureStatus(from: notificationValue) else {
        return nil
    }
    return SignatureNotification(value: status)
}

func kitSlotNotification(from value: RpcJsonValue) -> SlotNotification? {
    let notificationValue = value.value(for: "value") ?? value
    if let slot = notificationValue.value(for: "slot").flatMap(kitUInt64) ?? kitUInt64(notificationValue) {
        return SlotNotification(slot: slot)
    }
    return nil
}

func kitEpochInfo(from value: RpcJsonValue) throws -> EpochInfo {
    guard let absoluteSlot = value.value(for: "absoluteSlot").flatMap(kitUInt64),
          let blockHeight = value.value(for: "blockHeight").flatMap(kitUInt64)
    else {
        throw SolanaError(.malformedJSONRPCError)
    }
    return EpochInfo(absoluteSlot: absoluteSlot, blockHeight: blockHeight)
}

func kitNonceAccountInfo(from value: RpcJsonValue?) throws -> NonceAccountInfo? {
    guard let value, value != .null else {
        return nil
    }
    let accountValue = value.value(for: "value") ?? value
    guard accountValue != .null else {
        return nil
    }
    guard let data = accountValue.value(for: "data") else {
        throw SolanaError(.malformedJSONRPCError)
    }
    if case let .array(items) = data,
       items.count >= 2,
       let encoded = kitString(items[0]),
       let encoding = kitString(items[1]) {
        return NonceAccountInfo(data: EncodedDataResponse(data: encoded, encoding: encoding))
    }
    if let encoded = data.value(for: "data").flatMap(kitString),
       let encoding = data.value(for: "encoding").flatMap(kitString) {
        return NonceAccountInfo(data: EncodedDataResponse(data: encoded, encoding: encoding))
    }
    throw SolanaError(.malformedJSONRPCError)
}

func kitAccountNotification(from value: RpcJsonValue) throws -> AccountNotification? {
    guard let info = try kitNonceAccountInfo(from: value.value(for: "value") ?? value) else {
        return nil
    }
    return AccountNotification(value: info)
}

func kitRpcTransactionError(_ value: RpcJsonValue) -> RpcTransactionError? {
    if value == .null {
        return nil
    }
    if let name = kitString(value) {
        return kitRpcTransactionError(name: name)
    }
    guard case let .object(members) = value, let member = members.last else {
        return .unknown(String(describing: value))
    }
    if member.key == "InstructionError",
       case let .array(values) = member.value,
       values.count >= 2,
       let index = kitInt(values[0]) {
        return .instructionError(index: index, error: kitRpcInstructionError(values[1]))
    }
    if member.key == "DuplicateInstruction", let index = kitInt(member.value) {
        return .duplicateInstruction(index)
    }
    if member.key == "InsufficientFundsForRent", let index = kitAccountIndex(member.value) {
        return .insufficientFundsForRent(accountIndex: index)
    }
    if member.key == "ProgramExecutionTemporarilyRestricted", let index = kitAccountIndex(member.value) {
        return .programExecutionTemporarilyRestricted(accountIndex: index)
    }
    return kitRpcTransactionError(name: member.key) ?? .unknown(member.key)
}

func kitAccountIndex(_ value: RpcJsonValue) -> Int? {
    if case let .object(members) = value,
       let accountIndex = members.last(where: { $0.key == "account_index" })?.value {
        return kitInt(accountIndex)
    }
    return kitInt(value)
}

func kitRpcTransactionError(name: String) -> RpcTransactionError? {
    switch name {
    case "AccountBorrowOutstanding":
        return .accountBorrowOutstanding
    case "AccountInUse":
        return .accountInUse
    case "AccountLoadedTwice":
        return .accountLoadedTwice
    case "AccountNotFound":
        return .accountNotFound
    case "AddressLookupTableNotFound":
        return .addressLookupTableNotFound
    case "AlreadyProcessed":
        return .alreadyProcessed
    case "BlockhashNotFound":
        return .blockhashNotFound
    case "CallChainTooDeep":
        return .callChainTooDeep
    case "ClusterMaintenance":
        return .clusterMaintenance
    case "InsufficientFundsForFee":
        return .insufficientFundsForFee
    case "InvalidAccountForFee":
        return .invalidAccountForFee
    case "InvalidAccountIndex":
        return .invalidAccountIndex
    case "InvalidAddressLookupTableData":
        return .invalidAddressLookupTableData
    case "InvalidAddressLookupTableIndex":
        return .invalidAddressLookupTableIndex
    case "InvalidAddressLookupTableOwner":
        return .invalidAddressLookupTableOwner
    case "InvalidLoadedAccountsDataSizeLimit":
        return .invalidLoadedAccountsDataSizeLimit
    case "InvalidProgramForExecution":
        return .invalidProgramForExecution
    case "InvalidRentPayingAccount":
        return .invalidRentPayingAccount
    case "InvalidWritableAccount":
        return .invalidWritableAccount
    case "MaxLoadedAccountsDataSizeExceeded":
        return .maxLoadedAccountsDataSizeExceeded
    case "MissingSignatureForFee":
        return .missingSignatureForFee
    case "ProgramAccountNotFound":
        return .programAccountNotFound
    case "ResanitizationNeeded":
        return .resanitizationNeeded
    case "SanitizeFailure":
        return .sanitizeFailure
    case "SignatureFailure":
        return .signatureFailure
    case "TooManyAccountLocks":
        return .tooManyAccountLocks
    case "UnbalancedTransaction":
        return .unbalancedTransaction
    case "UnsupportedVersion":
        return .unsupportedVersion
    case "WouldExceedAccountDataBlockLimit":
        return .wouldExceedAccountDataBlockLimit
    case "WouldExceedAccountDataTotalLimit":
        return .wouldExceedAccountDataTotalLimit
    case "WouldExceedMaxAccountCostLimit":
        return .wouldExceedMaxAccountCostLimit
    case "WouldExceedMaxBlockCostLimit":
        return .wouldExceedMaxBlockCostLimit
    case "WouldExceedMaxVoteCostLimit":
        return .wouldExceedMaxVoteCostLimit
    default:
        return nil
    }
}

func kitRpcInstructionError(_ value: RpcJsonValue) -> RpcInstructionError {
    if let name = kitString(value) {
        return kitRpcInstructionError(name: name)
    }
    if case let .object(members) = value, let member = members.last {
        if member.key == "Custom", let code = kitInt(member.value) {
            return .custom(code)
        }
        return kitRpcInstructionError(name: member.key)
    }
    return .genericError
}

func kitRpcInstructionError(name: String) -> RpcInstructionError {
    switch name {
    case "AccountAlreadyInitialized":
        return .accountAlreadyInitialized
    case "AccountBorrowFailed":
        return .accountBorrowFailed
    case "AccountBorrowOutstanding":
        return .accountBorrowOutstanding
    case "AccountDataSizeChanged":
        return .accountDataSizeChanged
    case "AccountDataTooSmall":
        return .accountDataTooSmall
    case "AccountNotExecutable":
        return .accountNotExecutable
    case "AccountNotRentExempt":
        return .accountNotRentExempt
    case "ArithmeticOverflow":
        return .arithmeticOverflow
    case "BorshIoError":
        return .borshIoError
    case "BuiltinProgramsMustConsumeComputeUnits":
        return .builtinProgramsMustConsumeComputeUnits
    case "CallDepth":
        return .callDepth
    case "ComputationalBudgetExceeded":
        return .computationalBudgetExceeded
    case "DuplicateAccountIndex":
        return .duplicateAccountIndex
    case "DuplicateAccountOutOfSync":
        return .duplicateAccountOutOfSync
    case "ExecutableAccountNotRentExempt":
        return .executableAccountNotRentExempt
    case "ExecutableDataModified":
        return .executableDataModified
    case "ExecutableLamportChange":
        return .executableLamportChange
    case "ExecutableModified":
        return .executableModified
    case "ExternalAccountDataModified":
        return .externalAccountDataModified
    case "ExternalAccountLamportSpend":
        return .externalAccountLamportSpend
    case "IllegalOwner":
        return .illegalOwner
    case "Immutable":
        return .immutable
    case "IncorrectAuthority":
        return .incorrectAuthority
    case "IncorrectProgramId":
        return .incorrectProgramId
    case "InsufficientFunds":
        return .insufficientFunds
    case "InvalidAccountData":
        return .invalidAccountData
    case "InvalidAccountOwner":
        return .invalidAccountOwner
    case "InvalidArgument":
        return .invalidArgument
    case "InvalidError":
        return .invalidError
    case "InvalidInstructionData":
        return .invalidInstructionData
    case "InvalidRealloc":
        return .invalidRealloc
    case "InvalidSeeds":
        return .invalidSeeds
    case "MaxAccountsDataAllocationsExceeded":
        return .maxAccountsDataAllocationsExceeded
    case "MaxAccountsExceeded":
        return .maxAccountsExceeded
    case "MaxInstructionTraceLengthExceeded":
        return .maxInstructionTraceLengthExceeded
    case "MaxSeedLengthExceeded":
        return .maxSeedLengthExceeded
    case "MissingAccount":
        return .missingAccount
    case "MissingRequiredSignature":
        return .missingRequiredSignature
    case "ModifiedProgramId":
        return .modifiedProgramId
    case "NotEnoughAccountKeys":
        return .notEnoughAccountKeys
    case "PrivilegeEscalation":
        return .privilegeEscalation
    case "ProgramEnvironmentSetupFailure":
        return .programEnvironmentSetupFailure
    case "ProgramFailedToCompile":
        return .programFailedToCompile
    case "ProgramFailedToComplete":
        return .programFailedToComplete
    case "ReadonlyDataModified":
        return .readonlyDataModified
    case "ReadonlyLamportChange":
        return .readonlyLamportChange
    case "ReentrancyNotAllowed":
        return .reentrancyNotAllowed
    case "RentEpochModified":
        return .rentEpochModified
    case "UnbalancedInstruction":
        return .unbalancedInstruction
    case "UninitializedAccount":
        return .uninitializedAccount
    case "UnsupportedProgramId":
        return .unsupportedProgramId
    case "UnsupportedSysvar":
        return .unsupportedSysvar
    default:
        return .genericError
    }
}

func kitSolanaError(from error: RpcTransactionError) -> SolanaError {
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
    case let .unknown(name):
        return SolanaError(.transactionErrorUnknown, context: ["errorName": .string(name)])
    case let .instructionError(index, error):
        return SolanaError(kitSolanaErrorCode(for: error), context: kitInstructionErrorContext(index: index, error: error))
    }
}

func kitSimulationErrorContext(
    from value: RpcJsonValue,
    transactionError: RpcTransactionError
) -> SolanaErrorContext {
    var context = kitContextFromObjectData(value, droppingKeys: ["err"])
    let cause = kitSolanaError(from: transactionError)
    context.values["cause"] = kitSolanaErrorContextValue(cause)
    return context
}

func kitContextFromObjectData(_ value: RpcJsonValue, droppingKeys keysToDrop: Set<String> = []) -> SolanaErrorContext {
    guard case let .object(members) = value else {
        return .empty
    }
    var values: [String: SolanaErrorContextValue] = [:]
    for member in members where !keysToDrop.contains(member.key) {
        values[member.key] = kitRpcJsonContextValue(member.value)
    }
    return SolanaErrorContext(values)
}

func kitRpcJsonContextValue(_ value: RpcJsonValue) -> SolanaErrorContextValue {
    switch value {
    case .null:
        return .null
    case let .bool(value):
        return .bool(value)
    case let .string(value):
        return .string(value)
    case let .number(value):
        if let intValue = Int(exactly: value) {
            return .int(intValue)
        }
        return .string(String(describing: value))
    case let .bigint(value):
        return .bigint(value)
    case let .array(values):
        return .array(values.map(kitRpcJsonContextValue))
    case let .object(members):
        var object: [String: SolanaErrorContextValue] = [:]
        for member in members {
            object[member.key] = kitRpcJsonContextValue(member.value)
        }
        return .object(object)
    }
}

func kitSolanaErrorContextValue(_ error: SolanaError) -> SolanaErrorContextValue {
    var object: [String: SolanaErrorContextValue] = ["code": .int(error.code)]
    if !error.context.values.isEmpty {
        object["context"] = .object(error.context.values)
    }
    return .object(object)
}

func kitInstructionErrorContext(index: Int, error: RpcInstructionError) -> SolanaErrorContext {
    if case let .custom(code) = error {
        return ["code": .int(code), "index": .int(index)]
    }
    return ["index": .int(index)]
}

func kitSolanaErrorCode(for error: RpcInstructionError) -> SolanaErrorCode {
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
    case .custom:
        return .instructionErrorCustom
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
    }
}
