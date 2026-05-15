public import Foundation
public import Keys
public import SolanaErrors
public import TransactionMessages
public import Transactions

public struct TransactionPlanFailure: Error, Sendable, Equatable, LocalizedError {
    public let code: Int?
    public let message: String

    public init(_ error: any Error) {
        code = (error as? any SolanaErrorCoded)?.code
        if let localized = error as? any LocalizedError, let description = localized.errorDescription {
            message = description
        } else {
            message = String(describing: error)
        }
    }

    public init(code: Int? = nil, message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

public struct TransactionPlanExecutionContext: Sendable, Equatable {
    public var message: TransactionMessage?
    public var metadata: SolanaErrorContext
    public var signature: Signature?
    public var transaction: Transaction?

    public init(
        message: TransactionMessage? = nil,
        metadata: SolanaErrorContext = .empty,
        signature: Signature? = nil,
        transaction: Transaction? = nil
    ) {
        self.message = message
        self.metadata = metadata
        self.signature = signature
        self.transaction = transaction
    }
}

public struct SuccessfulSingleTransactionPlanResult: Sendable {
    public let context: TransactionPlanExecutionContext
    public let kind = "single"
    public let planType = "transactionPlanResult"
    public let plannedMessage: TransactionMessage
    public let status = "successful"

    public init(plannedMessage: TransactionMessage, context: TransactionPlanExecutionContext) {
        self.context = context
        self.plannedMessage = plannedMessage
    }
}

public struct FailedSingleTransactionPlanResult: Sendable {
    public let context: TransactionPlanExecutionContext
    public let error: TransactionPlanFailure
    public let kind = "single"
    public let planType = "transactionPlanResult"
    public let plannedMessage: TransactionMessage
    public let status = "failed"

    public init(
        plannedMessage: TransactionMessage,
        error: TransactionPlanFailure,
        context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()
    ) {
        self.context = context
        self.error = error
        self.plannedMessage = plannedMessage
    }
}

public struct CanceledSingleTransactionPlanResult: Sendable {
    public let context: TransactionPlanExecutionContext
    public let kind = "single"
    public let planType = "transactionPlanResult"
    public let plannedMessage: TransactionMessage
    public let status = "canceled"

    public init(
        plannedMessage: TransactionMessage,
        context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()
    ) {
        self.context = context
        self.plannedMessage = plannedMessage
    }
}

public enum SingleTransactionPlanResult: Sendable {
    case successful(SuccessfulSingleTransactionPlanResult)
    case failed(FailedSingleTransactionPlanResult)
    case canceled(CanceledSingleTransactionPlanResult)

    public var status: String {
        switch self {
        case .successful:
            "successful"
        case .failed:
            "failed"
        case .canceled:
            "canceled"
        }
    }

    public var plannedMessage: TransactionMessage {
        switch self {
        case let .successful(result):
            result.plannedMessage
        case let .failed(result):
            result.plannedMessage
        case let .canceled(result):
            result.plannedMessage
        }
    }
}

public struct ParallelTransactionPlanResult: Sendable {
    public let kind = "parallel"
    public let planType = "transactionPlanResult"
    public let plans: [TransactionPlanResult]

    public init(plans: [TransactionPlanResult]) {
        self.plans = plans
    }
}

public struct SequentialTransactionPlanResult: Sendable {
    public let divisible: Bool
    public let kind = "sequential"
    public let planType = "transactionPlanResult"
    public let plans: [TransactionPlanResult]

    public init(plans: [TransactionPlanResult], divisible: Bool = true) {
        self.divisible = divisible
        self.plans = plans
    }
}

public indirect enum TransactionPlanResult: Sendable {
    case single(SingleTransactionPlanResult)
    case parallel(ParallelTransactionPlanResult)
    case sequential(SequentialTransactionPlanResult)

    public var kind: String {
        switch self {
        case .single:
            "single"
        case .parallel:
            "parallel"
        case .sequential:
            "sequential"
        }
    }

    public var planType: String {
        "transactionPlanResult"
    }
}

public struct TransactionPlanResultSummary: Sendable {
    public let canceledTransactions: [CanceledSingleTransactionPlanResult]
    public let failedTransactions: [FailedSingleTransactionPlanResult]
    public let successful: Bool
    public let successfulTransactions: [SuccessfulSingleTransactionPlanResult]

    public init(
        canceledTransactions: [CanceledSingleTransactionPlanResult],
        failedTransactions: [FailedSingleTransactionPlanResult],
        successful: Bool,
        successfulTransactions: [SuccessfulSingleTransactionPlanResult]
    ) {
        self.canceledTransactions = canceledTransactions
        self.failedTransactions = failedTransactions
        self.successful = successful
        self.successfulTransactions = successfulTransactions
    }
}

public func successfulSingleTransactionPlanResult(
    _ plannedMessage: TransactionMessage,
    context: TransactionPlanExecutionContext
) -> TransactionPlanResult {
    .single(.successful(SuccessfulSingleTransactionPlanResult(plannedMessage: plannedMessage, context: context)))
}

public func successfulSingleTransactionPlanResult(
    _ plannedMessage: TransactionMessage,
    signature: Signature
) -> TransactionPlanResult {
    successfulSingleTransactionPlanResult(
        plannedMessage,
        context: TransactionPlanExecutionContext(signature: signature)
    )
}

public func successfulSingleTransactionPlanResultFromTransaction(
    _ plannedMessage: TransactionMessage,
    _ transaction: Transaction,
    context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()
) throws -> TransactionPlanResult {
    var nextContext = context
    nextContext.transaction = transaction
    nextContext.signature = try getSignatureFromTransaction(transaction)
    return successfulSingleTransactionPlanResult(plannedMessage, context: nextContext)
}

public func failedSingleTransactionPlanResult(
    _ plannedMessage: TransactionMessage,
    _ error: any Error,
    context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()
) -> TransactionPlanResult {
    .single(.failed(FailedSingleTransactionPlanResult(
        plannedMessage: plannedMessage,
        error: TransactionPlanFailure(error),
        context: context
    )))
}

public func canceledSingleTransactionPlanResult(
    _ plannedMessage: TransactionMessage,
    context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()
) -> TransactionPlanResult {
    .single(.canceled(CanceledSingleTransactionPlanResult(plannedMessage: plannedMessage, context: context)))
}

public func parallelTransactionPlanResult(_ plans: [TransactionPlanResult]) -> TransactionPlanResult {
    .parallel(ParallelTransactionPlanResult(plans: plans))
}

public func sequentialTransactionPlanResult(_ plans: [TransactionPlanResult]) -> TransactionPlanResult {
    .sequential(SequentialTransactionPlanResult(plans: plans, divisible: true))
}

public func nonDivisibleSequentialTransactionPlanResult(_ plans: [TransactionPlanResult]) -> TransactionPlanResult {
    .sequential(SequentialTransactionPlanResult(plans: plans, divisible: false))
}

public func isTransactionPlanResult(_ value: Any) -> Bool {
    value is TransactionPlanResult
}

public func isSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    if case .single = result {
        return true
    }
    return false
}

public func assertIsSingleTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isSingleTransactionPlanResult(result) else {
        throw unexpectedTransactionPlanResult(result, expectedKind: "single")
    }
}

public func isSuccessfulSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    if case let .single(.successful(single)) = result {
        return single.status == "successful"
    }
    return false
}

public func assertIsSuccessfulSingleTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isSuccessfulSingleTransactionPlanResult(result) else {
        throw unexpectedTransactionPlanResult(result, expectedKind: "successful single")
    }
}

public func isFailedSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    if case .single(.failed) = result {
        return true
    }
    return false
}

public func assertIsFailedSingleTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isFailedSingleTransactionPlanResult(result) else {
        throw unexpectedTransactionPlanResult(result, expectedKind: "failed single")
    }
}

public func isCanceledSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    if case .single(.canceled) = result {
        return true
    }
    return false
}

public func assertIsCanceledSingleTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isCanceledSingleTransactionPlanResult(result) else {
        throw unexpectedTransactionPlanResult(result, expectedKind: "canceled single")
    }
}

public func isSequentialTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    if case .sequential = result {
        return true
    }
    return false
}

public func assertIsSequentialTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isSequentialTransactionPlanResult(result) else {
        throw unexpectedTransactionPlanResult(result, expectedKind: "sequential")
    }
}

public func isNonDivisibleSequentialTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    if case let .sequential(result) = result {
        return !result.divisible
    }
    return false
}

public func assertIsNonDivisibleSequentialTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isNonDivisibleSequentialTransactionPlanResult(result) else {
        let actualKind = result.kind == "sequential" ? "divisible sequential" : result.kind
        throw SolanaError(
            .instructionPlansUnexpectedTransactionPlanResult,
            context: ["actualKind": .string(actualKind), "expectedKind": .string("non-divisible sequential")]
        )
    }
}

public func isParallelTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    if case .parallel = result {
        return true
    }
    return false
}

public func assertIsParallelTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isParallelTransactionPlanResult(result) else {
        throw unexpectedTransactionPlanResult(result, expectedKind: "parallel")
    }
}

public func isSuccessfulTransactionPlanResult(_ result: TransactionPlanResult) -> Bool {
    everyTransactionPlanResult(result) { isSuccessfulSingleTransactionPlanResult($0) || !isSingleTransactionPlanResult($0) }
}

public func assertIsSuccessfulTransactionPlanResult(_ result: TransactionPlanResult) throws {
    guard isSuccessfulTransactionPlanResult(result) else {
        throw SolanaError(.instructionPlansExpectedSuccessfulTransactionPlanResult)
    }
}

public func flattenTransactionPlanResult(_ result: TransactionPlanResult) -> [SingleTransactionPlanResult] {
    switch result {
    case let .single(single):
        return [single]
    case let .parallel(result):
        return result.plans.flatMap(flattenTransactionPlanResult)
    case let .sequential(result):
        return result.plans.flatMap(flattenTransactionPlanResult)
    }
}

public func findTransactionPlanResult(
    _ result: TransactionPlanResult,
    where predicate: (TransactionPlanResult) throws -> Bool
) rethrows -> TransactionPlanResult? {
    if try predicate(result) {
        return result
    }
    switch result {
    case .single:
        return nil
    case let .parallel(result):
        for child in result.plans {
            if let found = try findTransactionPlanResult(child, where: predicate) {
                return found
            }
        }
    case let .sequential(result):
        for child in result.plans {
            if let found = try findTransactionPlanResult(child, where: predicate) {
                return found
            }
        }
    }
    return nil
}

public func everyTransactionPlanResult(
    _ result: TransactionPlanResult,
    satisfies predicate: (TransactionPlanResult) throws -> Bool
) rethrows -> Bool {
    guard try predicate(result) else {
        return false
    }
    switch result {
    case .single:
        return true
    case let .parallel(result):
        for child in result.plans where try !everyTransactionPlanResult(child, satisfies: predicate) {
            return false
        }
    case let .sequential(result):
        for child in result.plans where try !everyTransactionPlanResult(child, satisfies: predicate) {
            return false
        }
    }
    return true
}

public func transformTransactionPlanResult(
    _ result: TransactionPlanResult,
    _ transform: (TransactionPlanResult) throws -> TransactionPlanResult
) rethrows -> TransactionPlanResult {
    switch result {
    case .single:
        return try transform(result)
    case let .parallel(result):
        return try transform(.parallel(ParallelTransactionPlanResult(
            plans: result.plans.map { try transformTransactionPlanResult($0, transform) }
        )))
    case let .sequential(result):
        return try transform(.sequential(SequentialTransactionPlanResult(
            plans: result.plans.map { try transformTransactionPlanResult($0, transform) },
            divisible: result.divisible
        )))
    }
}

public func getFirstFailedSingleTransactionPlanResult(
    _ result: TransactionPlanResult
) throws -> FailedSingleTransactionPlanResult {
    for single in flattenTransactionPlanResult(result) {
        if case let .failed(result) = single {
            return result
        }
    }
    throw SolanaError(.instructionPlansFailedSingleTransactionPlanResultNotFound)
}

public func summarizeTransactionPlanResult(_ result: TransactionPlanResult) -> TransactionPlanResultSummary {
    var successful: [SuccessfulSingleTransactionPlanResult] = []
    var failed: [FailedSingleTransactionPlanResult] = []
    var canceled: [CanceledSingleTransactionPlanResult] = []
    for single in flattenTransactionPlanResult(result) {
        switch single {
        case let .successful(result):
            successful.append(result)
        case let .failed(result):
            failed.append(result)
        case let .canceled(result):
            canceled.append(result)
        }
    }
    return TransactionPlanResultSummary(
        canceledTransactions: canceled,
        failedTransactions: failed,
        successful: failed.isEmpty && canceled.isEmpty,
        successfulTransactions: successful
    )
}

func unexpectedTransactionPlanResult(_ result: TransactionPlanResult, expectedKind: String) -> SolanaError {
    let actualKind: String
    if case let .single(single) = result {
        actualKind = "\(single.status) single"
    } else {
        actualKind = result.kind
    }
    return SolanaError(
        .instructionPlansUnexpectedTransactionPlanResult,
        context: ["actualKind": .string(actualKind), "expectedKind": .string(expectedKind)]
    )
}
