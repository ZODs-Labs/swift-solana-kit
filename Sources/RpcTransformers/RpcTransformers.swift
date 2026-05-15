public import RpcSpecTypes
public import RpcTypes
import Foundation
import SolanaErrors

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

    public init(defaultCommitment: Commitment? = nil, onIntegerOverflow: IntegerOverflowHandler? = nil) {
        self.defaultCommitment = defaultCommitment
        self.onIntegerOverflow = onIntegerOverflow
    }
}

public struct ResponseTransformerConfig: Sendable {
    public let allowedNumericKeyPaths: [String: [RpcKeyPath]]

    public init(allowedNumericKeyPaths: [String: [RpcKeyPath]] = [:]) {
        self.allowedNumericKeyPaths = allowedNumericKeyPaths
    }
}

public let keyPathWildcard: RpcKeyPathComponent = .wildcard

private let jsonRpcCodesThatCarryServerMessage: Set<Int> = [
    SolanaErrorCode.jsonRPCInternalError.rawValue,
    SolanaErrorCode.jsonRPCInvalidParams.rawValue,
    SolanaErrorCode.jsonRPCInvalidRequest.rawValue,
    SolanaErrorCode.jsonRPCMethodNotFound.rawValue,
    SolanaErrorCode.jsonRPCParseError.rawValue,
    SolanaErrorCode.jsonRPCScanError.rawValue,
    SolanaErrorCode.jsonRPCServerErrorBlockCleanedUp.rawValue,
    SolanaErrorCode.jsonRPCServerErrorBlockNotAvailable.rawValue,
    SolanaErrorCode.jsonRPCServerErrorBlockStatusNotAvailableYet.rawValue,
    SolanaErrorCode.jsonRPCServerErrorKeyExcludedFromSecondaryIndex.rawValue,
    SolanaErrorCode.jsonRPCServerErrorLongTermStorageSlotSkipped.rawValue,
    SolanaErrorCode.jsonRPCServerErrorSlotSkipped.rawValue,
    SolanaErrorCode.jsonRPCServerErrorTransactionPrecompileVerificationFailure.rawValue,
    SolanaErrorCode.jsonRPCServerErrorUnsupportedTransactionVersion.rawValue,
]

private let simulateTransactionAllowedNumericKeyPaths: [RpcKeyPath] = [
    [.key("loadedAccountsDataSize")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("tokenAmount"), .key("decimals")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("tokenAmount"), .key("uiAmount")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("rentExemptReserve"), .key("decimals")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("rentExemptReserve"), .key("uiAmount")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("delegatedAmount"), .key("decimals")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("delegatedAmount"), .key("uiAmount")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("olderTransferFee"), .key("transferFeeBasisPoints")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("newerTransferFee"), .key("transferFeeBasisPoints")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("preUpdateAverageRate")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("currentRate")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("lastExtendedSlotStartIndex")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("slashPenalty")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("warmupCooldownRate")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("decimals")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("numRequiredSigners")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("numValidSigners")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("stake"), .key("delegation"), .key("warmupCooldownRate")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("exemptionThreshold")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("burnPercent")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("commission")],
    [.key("accounts"), .wildcard, .key("data"), .key("parsed"), .key("info"), .key("votes"), .wildcard, .key("confirmationCount")],
    [.key("innerInstructions"), .wildcard, .key("index")],
    [.key("innerInstructions"), .wildcard, .key("instructions"), .wildcard, .key("accounts"), .wildcard],
    [.key("innerInstructions"), .wildcard, .key("instructions"), .wildcard, .key("programIdIndex")],
    [.key("innerInstructions"), .wildcard, .key("instructions"), .wildcard, .key("stackHeight")],
]

private let orderedInstructionErrorCodes: [String: SolanaErrorCode] = [
    "GenericError": .instructionErrorGenericError,
    "InvalidArgument": .instructionErrorInvalidArgument,
    "InvalidInstructionData": .instructionErrorInvalidInstructionData,
    "InvalidAccountData": .instructionErrorInvalidAccountData,
    "AccountDataTooSmall": .instructionErrorAccountDataTooSmall,
    "InsufficientFunds": .instructionErrorInsufficientFunds,
    "IncorrectProgramId": .instructionErrorIncorrectProgramID,
    "MissingRequiredSignature": .instructionErrorMissingRequiredSignature,
    "AccountAlreadyInitialized": .instructionErrorAccountAlreadyInitialized,
    "UninitializedAccount": .instructionErrorUninitializedAccount,
    "UnbalancedInstruction": .instructionErrorUnbalancedInstruction,
    "ModifiedProgramId": .instructionErrorModifiedProgramID,
    "ExternalAccountLamportSpend": .instructionErrorExternalAccountLamportSpend,
    "ExternalAccountDataModified": .instructionErrorExternalAccountDataModified,
    "ReadonlyLamportChange": .instructionErrorReadonlyLamportChange,
    "ReadonlyDataModified": .instructionErrorReadonlyDataModified,
    "DuplicateAccountIndex": .instructionErrorDuplicateAccountIndex,
    "ExecutableModified": .instructionErrorExecutableModified,
    "RentEpochModified": .instructionErrorRentEpochModified,
    "NotEnoughAccountKeys": .instructionErrorNotEnoughAccountKeys,
    "AccountDataSizeChanged": .instructionErrorAccountDataSizeChanged,
    "AccountNotExecutable": .instructionErrorAccountNotExecutable,
    "AccountBorrowFailed": .instructionErrorAccountBorrowFailed,
    "AccountBorrowOutstanding": .instructionErrorAccountBorrowOutstanding,
    "DuplicateAccountOutOfSync": .instructionErrorDuplicateAccountOutOfSync,
    "InvalidError": .instructionErrorInvalidError,
    "ExecutableDataModified": .instructionErrorExecutableDataModified,
    "ExecutableLamportChange": .instructionErrorExecutableLamportChange,
    "ExecutableAccountNotRentExempt": .instructionErrorExecutableAccountNotRentExempt,
    "UnsupportedProgramId": .instructionErrorUnsupportedProgramID,
    "CallDepth": .instructionErrorCallDepth,
    "MissingAccount": .instructionErrorMissingAccount,
    "ReentrancyNotAllowed": .instructionErrorReentrancyNotAllowed,
    "MaxSeedLengthExceeded": .instructionErrorMaxSeedLengthExceeded,
    "InvalidSeeds": .instructionErrorInvalidSeeds,
    "InvalidRealloc": .instructionErrorInvalidRealloc,
    "ComputationalBudgetExceeded": .instructionErrorComputationalBudgetExceeded,
    "PrivilegeEscalation": .instructionErrorPrivilegeEscalation,
    "ProgramEnvironmentSetupFailure": .instructionErrorProgramEnvironmentSetupFailure,
    "ProgramFailedToComplete": .instructionErrorProgramFailedToComplete,
    "ProgramFailedToCompile": .instructionErrorProgramFailedToCompile,
    "Immutable": .instructionErrorImmutable,
    "IncorrectAuthority": .instructionErrorIncorrectAuthority,
    "BorshIoError": .instructionErrorBorshIoError,
    "AccountNotRentExempt": .instructionErrorAccountNotRentExempt,
    "InvalidAccountOwner": .instructionErrorInvalidAccountOwner,
    "ArithmeticOverflow": .instructionErrorArithmeticOverflow,
    "UnsupportedSysvar": .instructionErrorUnsupportedSysvar,
    "IllegalOwner": .instructionErrorIllegalOwner,
    "MaxAccountsDataAllocationsExceeded": .instructionErrorMaxAccountsDataAllocationsExceeded,
    "MaxAccountsExceeded": .instructionErrorMaxAccountsExceeded,
    "MaxInstructionTraceLengthExceeded": .instructionErrorMaxInstructionTraceLengthExceeded,
    "BuiltinProgramsMustConsumeComputeUnits": .instructionErrorBuiltinProgramsMustConsumeComputeUnits,
]

private let orderedTransactionErrorCodes: [String: SolanaErrorCode] = [
    "AccountInUse": .transactionErrorAccountInUse,
    "AccountLoadedTwice": .transactionErrorAccountLoadedTwice,
    "AccountNotFound": .transactionErrorAccountNotFound,
    "ProgramAccountNotFound": .transactionErrorProgramAccountNotFound,
    "InsufficientFundsForFee": .transactionErrorInsufficientFundsForFee,
    "InvalidAccountForFee": .transactionErrorInvalidAccountForFee,
    "AlreadyProcessed": .transactionErrorAlreadyProcessed,
    "BlockhashNotFound": .transactionErrorBlockhashNotFound,
    "CallChainTooDeep": .transactionErrorCallChainTooDeep,
    "MissingSignatureForFee": .transactionErrorMissingSignatureForFee,
    "InvalidAccountIndex": .transactionErrorInvalidAccountIndex,
    "SignatureFailure": .transactionErrorSignatureFailure,
    "InvalidProgramForExecution": .transactionErrorInvalidProgramForExecution,
    "SanitizeFailure": .transactionErrorSanitizeFailure,
    "ClusterMaintenance": .transactionErrorClusterMaintenance,
    "AccountBorrowOutstanding": .transactionErrorAccountBorrowOutstanding,
    "WouldExceedMaxBlockCostLimit": .transactionErrorWouldExceedMaxBlockCostLimit,
    "UnsupportedVersion": .transactionErrorUnsupportedVersion,
    "InvalidWritableAccount": .transactionErrorInvalidWritableAccount,
    "WouldExceedMaxAccountCostLimit": .transactionErrorWouldExceedMaxAccountCostLimit,
    "WouldExceedAccountDataBlockLimit": .transactionErrorWouldExceedAccountDataBlockLimit,
    "TooManyAccountLocks": .transactionErrorTooManyAccountLocks,
    "AddressLookupTableNotFound": .transactionErrorAddressLookupTableNotFound,
    "InvalidAddressLookupTableOwner": .transactionErrorInvalidAddressLookupTableOwner,
    "InvalidAddressLookupTableData": .transactionErrorInvalidAddressLookupTableData,
    "InvalidAddressLookupTableIndex": .transactionErrorInvalidAddressLookupTableIndex,
    "InvalidRentPayingAccount": .transactionErrorInvalidRentPayingAccount,
    "WouldExceedMaxVoteCostLimit": .transactionErrorWouldExceedMaxVoteCostLimit,
    "WouldExceedAccountDataTotalLimit": .transactionErrorWouldExceedAccountDataTotalLimit,
    "MaxLoadedAccountsDataSizeExceeded": .transactionErrorMaxLoadedAccountsDataSizeExceeded,
    "InvalidLoadedAccountsDataSizeLimit": .transactionErrorInvalidLoadedAccountsDataSizeLimit,
    "ResanitizationNeeded": .transactionErrorResanitizationNeeded,
    "UnbalancedTransaction": .transactionErrorUnbalancedTransaction,
]

public let optionsObjectPositionByMethod: [String: Int] = [
    "accountNotifications": 1,
    "blockNotifications": 1,
    "getAccountInfo": 1,
    "getBalance": 1,
    "getBlock": 1,
    "getBlockHeight": 0,
    "getBlockProduction": 0,
    "getBlocks": 2,
    "getBlocksWithLimit": 2,
    "getEpochInfo": 0,
    "getFeeForMessage": 1,
    "getInflationGovernor": 0,
    "getInflationReward": 1,
    "getLargestAccounts": 0,
    "getLatestBlockhash": 0,
    "getLeaderSchedule": 1,
    "getMinimumBalanceForRentExemption": 1,
    "getMultipleAccounts": 1,
    "getProgramAccounts": 1,
    "getSignaturesForAddress": 1,
    "getSlot": 0,
    "getSlotLeader": 0,
    "getStakeMinimumDelegation": 0,
    "getSupply": 0,
    "getTokenAccountBalance": 1,
    "getTokenAccountsByDelegate": 2,
    "getTokenAccountsByOwner": 2,
    "getTokenLargestAccounts": 1,
    "getTokenSupply": 1,
    "getTransaction": 1,
    "getTransactionCount": 0,
    "getVoteAccounts": 0,
    "isBlockhashValid": 1,
    "logsNotifications": 1,
    "programNotifications": 1,
    "requestAirdrop": 2,
    "sendTransaction": 1,
    "signatureNotifications": 1,
    "simulateTransaction": 1,
]

private let maxSafeInteger = "9007199254740991"

public func downcastNodeToNumberIfBigint(_ value: RpcJsonValue) -> RpcJsonValue {
    guard case let .bigint(bigint) = value else { return value }
    return .number(Double(bigint) ?? 0)
}

public func getBigIntDowncastRequestTransformer() -> RpcRequestTransformer {
    { request in
        RpcRequest(methodName: request.methodName, params: walk(request.params, keyPath: []) { value, _ in
            downcastNodeToNumberIfBigint(value)
        })
    }
}

public func getIntegerOverflowRequestTransformer(_ onIntegerOverflow: @escaping IntegerOverflowHandler) -> RpcRequestTransformer {
    { request in
        let params = try walkThrowing(request.params, keyPath: []) { value, keyPath in
            if case let .bigint(bigint) = value, bigintExceedsJavaScriptSafeInteger(bigint) {
                try onIntegerOverflow(request, keyPath, bigint)
            }
            return value
        }
        return RpcRequest(methodName: request.methodName, params: params)
    }
}

public func getDefaultCommitmentRequestTransformer(
    defaultCommitment: Commitment?,
    optionsObjectPositionByMethod: [String: Int]
) -> RpcRequestTransformer {
    { request in
        guard case let .array(params) = request.params,
              let optionsPosition = optionsObjectPositionByMethod[request.methodName]
        else {
            return request
        }
        let transformed = applyDefaultCommitment(
            params: params,
            optionsObjectPositionInParams: optionsPosition,
            commitmentPropertyName: request.methodName == "sendTransaction" ? "preflightCommitment" : "commitment",
            overrideCommitment: defaultCommitment
        )
        return RpcRequest(methodName: request.methodName, params: .array(transformed))
    }
}

public func getDefaultRequestTransformerForSolanaRpc(_ config: RequestTransformerConfig = RequestTransformerConfig()) -> RpcRequestTransformer {
    { request in
        var transformed = request
        if let handler = config.onIntegerOverflow {
            transformed = try getIntegerOverflowRequestTransformer(handler)(transformed)
        }
        transformed = try getBigIntDowncastRequestTransformer()(transformed)
        transformed = try getDefaultCommitmentRequestTransformer(
            defaultCommitment: config.defaultCommitment,
            optionsObjectPositionByMethod: optionsObjectPositionByMethod
        )(transformed)
        return transformed
    }
}

public func getBigIntUpcastResponseTransformer(allowedNumericKeyPaths: [RpcKeyPath]) -> RpcResponseTransformer {
    RpcResponseTransformer { response, _ in
        walk(response, keyPath: []) { value, keyPath in
            let isInteger: Bool
            switch value {
            case let .number(number):
                isInteger = number.isFinite && number.rounded(.towardZero) == number
            case .bigint:
                isInteger = true
            default:
                isInteger = false
            }
            guard isInteger else { return value }
            if keyPathIsAllowedToBeNumeric(keyPath, allowedNumericKeyPaths) {
                switch value {
                case let .bigint(bigint):
                    return .number(Double(bigint) ?? 0)
                default:
                    return value
                }
            }
            switch value {
            case let .number(number):
                return .bigint(decimalIntegerString(from: number))
            case .bigint:
                return value
            default:
                return value
            }
        }
    }
}

public func getResultResponseTransformer() -> RpcResponseTransformer {
    RpcResponseTransformer { response, _ in
        response.value(for: "result") ?? .null
    }
}

public func getThrowSolanaErrorResponseTransformer() -> RpcResponseTransformer {
    RpcResponseTransformer { response, _ in
        guard case let .object(responseMembers) = response,
              let error = responseMembers.last(where: { $0.key == "error" })?.value
        else {
            return response
        }
        guard case let .object(members) = error else {
            throw malformedJsonRpcError(from: error)
        }
        let codeValue = members.last { $0.key == "code" }?.value
        let messageValue = members.last { $0.key == "message" }?.value
        guard let code = integerCode(from: codeValue),
              case let .string(message)? = messageValue
        else {
            throw malformedJsonRpcError(from: error)
        }
        throw solanaErrorFromJsonRpcError(code: code, message: message, data: members.last { $0.key == "data" }?.value)
    }
}

public func getDefaultResponseTransformerForSolanaRpc(_ config: ResponseTransformerConfig = ResponseTransformerConfig()) -> RpcResponseTransformer {
    RpcResponseTransformer { response, request in
        let checked = try getThrowSolanaErrorResponseTransformer()(response, request)
        let result = try getResultResponseTransformer()(checked, request)
        let keyPaths = config.allowedNumericKeyPaths[request.methodName] ?? []
        return try getBigIntUpcastResponseTransformer(allowedNumericKeyPaths: keyPaths)(result, request)
    }
}

public func getDefaultResponseTransformerForSolanaRpcSubscriptions(_ config: ResponseTransformerConfig = ResponseTransformerConfig()) -> RpcResponseTransformer {
    RpcResponseTransformer { response, request in
        let keyPaths = config.allowedNumericKeyPaths[request.methodName] ?? []
        return try getBigIntUpcastResponseTransformer(allowedNumericKeyPaths: keyPaths)(response, request)
    }
}

private func applyDefaultCommitment(
    params: [RpcJsonValue],
    optionsObjectPositionInParams: Int,
    commitmentPropertyName: String,
    overrideCommitment: Commitment?
) -> [RpcJsonValue] {
    let target = optionsObjectPositionInParams < params.count ? params[optionsObjectPositionInParams] : nil
    guard target == nil || target?.objectMembers != nil else {
        return params
    }

    if let target, case let .object(members) = target {
        guard let existingIndex = members.lastIndex(where: { $0.key == commitmentPropertyName }) else {
            return addCommitmentIfNeeded(params, at: optionsObjectPositionInParams, commitmentPropertyName: commitmentPropertyName, overrideCommitment: overrideCommitment, existingMembers: members)
        }
        let existing = members[existingIndex].value
        if shouldRemoveExistingCommitment(existing) {
            let nextMembers = members.filter { $0.key != commitmentPropertyName }
            var nextParams = params
            if nextMembers.isEmpty {
                if optionsObjectPositionInParams == nextParams.count - 1 {
                    nextParams.removeLast()
                } else {
                    nextParams[optionsObjectPositionInParams] = .null
                }
            } else {
                nextParams[optionsObjectPositionInParams] = .object(nextMembers)
            }
            return nextParams
        }
        return params
    }

    return addCommitmentIfNeeded(
        params,
        at: optionsObjectPositionInParams,
        commitmentPropertyName: commitmentPropertyName,
        overrideCommitment: overrideCommitment,
        existingMembers: []
    )
}

private func shouldRemoveExistingCommitment(_ value: RpcJsonValue) -> Bool {
    switch value {
    case .null:
        return true
    case let .bool(value):
        return !value
    case let .number(value):
        return value == 0 || value.isNaN
    case let .bigint(value):
        return canonicalInteger(value) == "0"
    case let .string(value):
        return value.isEmpty || value == Commitment.finalized.rawValue
    default:
        return false
    }
}

private func addCommitmentIfNeeded(
    _ params: [RpcJsonValue],
    at index: Int,
    commitmentPropertyName: String,
    overrideCommitment: Commitment?,
    existingMembers: [RpcJsonObjectMember]
) -> [RpcJsonValue] {
    guard overrideCommitment != .finalized else {
        return params
    }
    var nextParams = params
    while nextParams.count <= index {
        nextParams.append(.null)
    }
    if let commitment = overrideCommitment {
        nextParams[index] = .object(existingMembers + [RpcJsonObjectMember(commitmentPropertyName, .string(commitment.rawValue))])
    } else if nextParams[index].objectMembers == nil {
        nextParams[index] = .object(existingMembers)
    }
    return nextParams
}

private func walk(
    _ value: RpcJsonValue,
    keyPath: RpcKeyPath,
    visitor: (RpcJsonValue, RpcKeyPath) -> RpcJsonValue
) -> RpcJsonValue {
    switch value {
    case let .array(values):
        return .array(values.enumerated().map { index, value in
            walk(value, keyPath: keyPath + [.index(index)], visitor: visitor)
        })
    case let .object(members):
        return .object(members.map { member in
            RpcJsonObjectMember(member.key, walk(member.value, keyPath: keyPath + [.key(member.key)], visitor: visitor))
        })
    default:
        return visitor(value, keyPath)
    }
}

private func walkThrowing(
    _ value: RpcJsonValue,
    keyPath: RpcKeyPath,
    visitor: (RpcJsonValue, RpcKeyPath) throws -> RpcJsonValue
) throws -> RpcJsonValue {
    switch value {
    case let .array(values):
        return .array(try values.enumerated().map { index, value in
            try walkThrowing(value, keyPath: keyPath + [.index(index)], visitor: visitor)
        })
    case let .object(members):
        return .object(try members.map { member in
            RpcJsonObjectMember(member.key, try walkThrowing(member.value, keyPath: keyPath + [.key(member.key)], visitor: visitor))
        })
    default:
        return try visitor(value, keyPath)
    }
}

private func keyPathIsAllowedToBeNumeric(_ keyPath: RpcKeyPath, _ allowedNumericKeyPaths: [RpcKeyPath]) -> Bool {
    allowedNumericKeyPaths.contains { allowed in
        guard allowed.count == keyPath.count else { return false }
        for (allowedComponent, component) in zip(allowed, keyPath) {
            if allowedComponent == component {
                continue
            }
            if allowedComponent == .wildcard, case .index = component {
                continue
            }
            return false
        }
        return true
    }
}

private func bigintExceedsJavaScriptSafeInteger(_ value: String) -> Bool {
    let canonical = canonicalInteger(value)
    if canonical.hasPrefix("-") {
        return decimalMagnitudeGreaterThan(String(canonical.dropFirst()), maxSafeInteger)
    }
    return decimalMagnitudeGreaterThan(canonical, maxSafeInteger)
}

private func decimalMagnitudeGreaterThan(_ lhs: String, _ rhs: String) -> Bool {
    let lhsTrimmed = trimLeadingZeros(lhs)
    let rhsTrimmed = trimLeadingZeros(rhs)
    if lhsTrimmed.count != rhsTrimmed.count {
        return lhsTrimmed.count > rhsTrimmed.count
    }
    return lhsTrimmed.lexicographicallyPrecedes(rhsTrimmed) == false && lhsTrimmed != rhsTrimmed
}

private func canonicalInteger(_ value: String) -> String {
    let negative = value.hasPrefix("-")
    let digits = negative ? String(value.dropFirst()) : value
    let trimmed = trimLeadingZeros(digits)
    if trimmed == "0" { return "0" }
    return negative ? "-\(trimmed)" : trimmed
}

private func trimLeadingZeros(_ value: String) -> String {
    let trimmed = value.drop { $0 == "0" }
    return trimmed.isEmpty ? "0" : String(trimmed)
}

private func integerCode(from value: RpcJsonValue?) -> Int? {
    switch value {
    case let .number(number)? where number.isFinite:
        return Int(number)
    case let .bigint(bigint)?:
        return Int(bigint)
    default:
        return nil
    }
}

private func malformedJsonRpcError(from error: RpcJsonValue) -> SolanaError {
    let message: String
    if case let .string(serverMessage)? = error.value(for: "message") {
        message = serverMessage
    } else {
        message = "Malformed JSON-RPC error with no message attribute"
    }
    return SolanaError(
        .malformedJSONRPCError,
        context: [
            "error": rpcJsonValueToContextValue(error),
            "message": .string(message),
        ]
    )
}

private func solanaErrorFromJsonRpcError(code: Int, message: String, data: RpcJsonValue?) -> SolanaError {
    if code == SolanaErrorCode.jsonRPCServerErrorSendTransactionPreflightFailure.rawValue {
        return SolanaError(
            SolanaErrorCode(rawValue: code),
            context: preflightFailureContext(from: data)
        )
    }

    if jsonRpcCodesThatCarryServerMessage.contains(code) {
        return SolanaError(SolanaErrorCode(rawValue: code), context: ["__serverMessage": .string(message)])
    }

    return SolanaError(SolanaErrorCode(rawValue: code), context: contextFromObjectData(data))
}

private func transformPreflightFailureData(_ data: RpcJsonValue) -> RpcJsonValue {
    do {
        return try getBigIntUpcastResponseTransformer(
            allowedNumericKeyPaths: simulateTransactionAllowedNumericKeyPaths
        )(data, RpcRequest(methodName: "sendTransaction", params: .array([])))
    } catch {
        return data
    }
}

private func preflightFailureContext(from data: RpcJsonValue?) -> SolanaErrorContext {
    let transformedData = data.map(transformPreflightFailureData)
    var context = contextFromObjectData(transformedData, droppingKeys: ["err"])
    guard let err = transformedData?.value(for: "err"), err != .null else {
        return context
    }
    context.values["cause"] = transactionErrorContextValue(from: err)
    return context
}

private func contextFromObjectData(_ data: RpcJsonValue?, droppingKeys keysToDrop: Set<String> = []) -> SolanaErrorContext {
    guard case let .object(members)? = data else {
        return .empty
    }
    var values: [String: SolanaErrorContextValue] = [:]
    for member in members where !keysToDrop.contains(member.key) {
        values[member.key] = rpcJsonValueToContextValue(member.value)
    }
    return SolanaErrorContext(values)
}

private func rpcJsonValueToContextValue(_ value: RpcJsonValue) -> SolanaErrorContextValue {
    switch value {
    case .null:
        return .null
    case let .bool(value):
        return .bool(value)
    case let .string(value):
        return .string(value)
    case let .number(value):
        return contextNumberValue(value)
    case let .bigint(value):
        return contextIntegerStringValue(value)
    case let .array(values):
        return .array(values.map(rpcJsonValueToContextValue))
    case let .object(members):
        return .object(contextObject(from: members))
    }
}

private func contextObject(from members: [RpcJsonObjectMember]) -> [String: SolanaErrorContextValue] {
    var out: [String: SolanaErrorContextValue] = [:]
    for member in members {
        out[member.key] = rpcJsonValueToContextValue(member.value)
    }
    return out
}

private func transactionErrorContextValue(from error: RpcJsonValue) -> SolanaErrorContextValue {
    switch error {
    case let .string(name):
        let code = orderedTransactionErrorCodes[name] ?? .transactionErrorUnknown
        let context: SolanaErrorContext = code == .transactionErrorUnknown ? ["errorName": .string(name)] : .empty
        return solanaErrorContextValue(code: code, context: context)
    case let .object(members):
        guard let member = members.last else {
            return solanaErrorContextValue(
                code: .transactionErrorUnknown,
                context: ["errorName": .string(""), "transactionErrorContext": rpcJsonValueToContextValue(error)]
            )
        }
        switch member.key {
        case "InstructionError":
            guard case let .array(values) = member.value, values.count == 2 else {
                return solanaErrorContextValue(
                    code: .transactionErrorUnknown,
                    context: ["errorName": .string(member.key), "transactionErrorContext": rpcJsonValueToContextValue(member.value)]
                )
            }
            return instructionErrorContextValue(index: values[0], error: values[1])
        case "DuplicateInstruction":
            return solanaErrorContextValue(
                code: .transactionErrorDuplicateInstruction,
                context: ["index": contextIndexValue(member.value)]
            )
        case "InsufficientFundsForRent":
            return solanaErrorContextValue(
                code: .transactionErrorInsufficientFundsForRent,
                context: ["accountIndex": contextAccountIndexValue(member.value)]
            )
        case "ProgramExecutionTemporarilyRestricted":
            return solanaErrorContextValue(
                code: .transactionErrorProgramExecutionTemporarilyRestricted,
                context: ["accountIndex": contextAccountIndexValue(member.value)]
            )
        default:
            if let code = orderedTransactionErrorCodes[member.key] {
                return solanaErrorContextValue(code: code, context: .empty)
            }
            return solanaErrorContextValue(
                code: .transactionErrorUnknown,
                context: [
                    "errorName": .string(member.key),
                    "transactionErrorContext": rpcJsonValueToContextValue(member.value),
                ]
            )
        }
    default:
        return solanaErrorContextValue(
            code: .transactionErrorUnknown,
            context: ["errorName": rpcJsonValueToContextValue(error)]
        )
    }
}

private func instructionErrorContextValue(index: RpcJsonValue, error: RpcJsonValue) -> SolanaErrorContextValue {
    let instructionIndex = contextIndexValue(index)
    switch error {
    case let .string(name):
        let code = orderedInstructionErrorCodes[name] ?? .instructionErrorUnknown
        let context: SolanaErrorContext = code == .instructionErrorUnknown
            ? ["errorName": .string(name), "index": instructionIndex]
            : ["index": instructionIndex]
        return solanaErrorContextValue(code: code, context: context)
    case let .object(members):
        guard let member = members.last else {
            return solanaErrorContextValue(
                code: .instructionErrorUnknown,
                context: ["errorName": .string(""), "index": instructionIndex, "instructionErrorContext": rpcJsonValueToContextValue(error)]
            )
        }
        if member.key == "Custom" {
            return solanaErrorContextValue(
                code: .instructionErrorCustom,
                context: ["code": contextIndexValue(member.value), "index": instructionIndex]
            )
        }
        if let code = orderedInstructionErrorCodes[member.key] {
            return solanaErrorContextValue(code: code, context: ["index": instructionIndex])
        }
        return solanaErrorContextValue(
            code: .instructionErrorUnknown,
            context: [
                "errorName": .string(member.key),
                "index": instructionIndex,
                "instructionErrorContext": rpcJsonValueToContextValue(member.value),
            ]
        )
    default:
        return solanaErrorContextValue(
            code: .instructionErrorUnknown,
            context: ["errorName": rpcJsonValueToContextValue(error), "index": instructionIndex]
        )
    }
}

private func solanaErrorContextValue(code: SolanaErrorCode, context: SolanaErrorContext) -> SolanaErrorContextValue {
    var object: [String: SolanaErrorContextValue] = ["code": .int(code.rawValue)]
    if !context.values.isEmpty {
        object["context"] = .object(context.values)
    }
    return .object(object)
}

private func contextIndexValue(_ value: RpcJsonValue) -> SolanaErrorContextValue {
    switch rpcJsonValueToContextValue(value) {
    case let .int(value):
        return .int(value)
    case let .uint(value):
        if value <= UInt64(Int.max) {
            return .int(Int(value))
        }
        return .uint(value)
    case let .bigint(value):
        if let intValue = Int(value) {
            return .int(intValue)
        }
        if let uintValue = UInt64(value) {
            return .uint(uintValue)
        }
        return .bigint(value)
    case let .string(value):
        if let intValue = Int(value) {
            return .int(intValue)
        }
        if let uintValue = UInt64(value) {
            return .uint(uintValue)
        }
        return .string(value)
    case let other:
        return other
    }
}

private func contextAccountIndexValue(_ value: RpcJsonValue) -> SolanaErrorContextValue {
    if case let .object(members) = value, let accountIndex = members.last(where: { $0.key == "account_index" })?.value {
        return contextIndexValue(accountIndex)
    }
    return contextIndexValue(value)
}

private func contextNumberValue(_ value: Double) -> SolanaErrorContextValue {
    guard value.isFinite else {
        return .string(String(value))
    }
    if value.rounded(.towardZero) == value,
       value >= Double(Int.min),
       value <= Double(Int.max)
    {
        return .int(Int(value))
    }
    return .string(String(value))
}

private func decimalIntegerString(from value: Double) -> String {
    if value == 0 {
        return "0"
    }
    let bits = value.bitPattern
    let isNegative = (bits >> 63) == 1
    let exponentBits = Int((bits >> 52) & 0x7ff)
    let fraction = bits & ((UInt64(1) << 52) - 1)
    let mantissa: UInt64
    let exponent: Int
    if exponentBits == 0 {
        mantissa = fraction
        exponent = -1022
    } else {
        mantissa = (UInt64(1) << 52) | fraction
        exponent = exponentBits - 1023
    }
    var decimal = String(mantissa)
    let shift = exponent - 52
    if shift >= 0 {
        for _ in 0 ..< shift {
            decimal = decimalMultiplyByTwo(decimal)
        }
    } else {
        for _ in 0 ..< -shift {
            decimal = decimalDivideByTwo(decimal)
        }
    }
    return isNegative ? "-\(decimal)" : decimal
}

private func decimalMultiplyByTwo(_ value: String) -> String {
    var carry = 0
    var digits: [Character] = []
    digits.reserveCapacity(value.count + 1)
    for character in value.reversed() {
        let doubled = Int(character.wholeNumberValue ?? 0) * 2 + carry
        digits.append(Character(String(doubled % 10)))
        carry = doubled / 10
    }
    if carry > 0 {
        digits.append(Character(String(carry)))
    }
    return String(digits.reversed())
}

private func decimalDivideByTwo(_ value: String) -> String {
    var remainder = 0
    var out = ""
    out.reserveCapacity(value.count)
    for character in value {
        let current = remainder * 10 + Int(character.wholeNumberValue ?? 0)
        let digit = current / 2
        remainder = current % 2
        if !out.isEmpty || digit != 0 {
            out.append(String(digit))
        }
    }
    return out.isEmpty ? "0" : out
}

private func contextIntegerStringValue(_ value: String) -> SolanaErrorContextValue {
    .bigint(value)
}
