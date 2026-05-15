public import Foundation
public import Keys
public import Promises
public import SolanaErrors
public import TransactionMessages
public import Transactions

public enum TransactionPlanExecutionOutput: Sendable {
    case signature(Signature)
    case transaction(Transaction)
}

public typealias TransactionPlanExecutor = @Sendable (
    _ transactionPlan: TransactionPlan,
    _ config: TransactionPlanExecutorRunConfig
) async throws -> TransactionPlanResult

public struct TransactionPlanExecutorRunConfig: Sendable {
    public let abortSignal: AbortSignal?

    public init(abortSignal: AbortSignal? = nil) {
        self.abortSignal = abortSignal
    }
}

public struct TransactionPlanExecutorConfig: Sendable {
    public let executeTransactionMessage: @Sendable (
        _ context: TransactionPlanExecutionContext,
        _ transactionMessage: TransactionMessage,
        _ config: TransactionPlanExecutorRunConfig
    ) async throws -> TransactionPlanExecutionOutput

    public init(
        executeTransactionMessage: @escaping @Sendable (
            _ context: TransactionPlanExecutionContext,
            _ transactionMessage: TransactionMessage,
            _ config: TransactionPlanExecutorRunConfig
        ) async throws -> TransactionPlanExecutionOutput
    ) {
        self.executeTransactionMessage = executeTransactionMessage
    }
}

public struct FailedToExecuteTransactionPlanError: SolanaErrorCoded, Sendable, LocalizedError {
    public let abortReason: String?
    public let result: TransactionPlanResult

    public init(result: TransactionPlanResult, abortReason: String? = nil) {
        self.result = result
        self.abortReason = abortReason
    }

    public var code: Int {
        SolanaErrorCode.instructionPlansFailedToExecuteTransactionPlan.rawValue
    }

    public var contextDescription: String {
        abortReason ?? ""
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: .instructionPlansFailedToExecuteTransactionPlan)
    }
}

public func createTransactionPlanExecutor(_ config: TransactionPlanExecutorConfig) -> TransactionPlanExecutor {
    { transactionPlan, runConfig in
        try assertDivisibleSequentialPlansOnly(transactionPlan)
        let state = ExecutionState()
        let result = await traverse(transactionPlan, config: config, runConfig: runConfig, state: state)
        if await state.isCanceled {
            let abortReason = runConfig.abortSignal?.abortReason().map(errorMessage)
            throw FailedToExecuteTransactionPlanError(result: result, abortReason: abortReason)
        }
        return result
    }
}

private func errorMessage(_ error: any Error) -> String {
    if let localized = error as? any LocalizedError, let description = localized.errorDescription {
        return description
    }
    return String(describing: error)
}

public func passthroughFailedTransactionPlanExecution(
    _ operation: @Sendable () async throws -> TransactionPlanResult
) async throws -> TransactionPlanResult {
    do {
        return try await operation()
    } catch let error as FailedToExecuteTransactionPlanError {
        return error.result
    }
}

private actor ExecutionState {
    private var canceledValue = false

    var isCanceled: Bool {
        canceledValue
    }

    func cancel() {
        canceledValue = true
    }
}

private func traverse(
    _ transactionPlan: TransactionPlan,
    config: TransactionPlanExecutorConfig,
    runConfig: TransactionPlanExecutorRunConfig,
    state: ExecutionState
) async -> TransactionPlanResult {
    switch transactionPlan {
    case let .single(plan):
        return await traverseSingle(plan, config: config, runConfig: runConfig, state: state)
    case let .parallel(plan):
        let results = await withTaskGroup(of: (Int, TransactionPlanResult).self) { group in
            for (index, child) in plan.plans.enumerated() {
                group.addTask {
                    await (index, traverse(child, config: config, runConfig: runConfig, state: state))
                }
            }
            var ordered = Array<TransactionPlanResult?>(repeating: nil, count: plan.plans.count)
            for await (index, result) in group {
                ordered[index] = result
            }
            return ordered.compactMap { $0 }
        }
        return parallelTransactionPlanResult(results)
    case let .sequential(plan):
        var results: [TransactionPlanResult] = []
        for child in plan.plans {
            results.append(await traverse(child, config: config, runConfig: runConfig, state: state))
        }
        return plan.divisible ? sequentialTransactionPlanResult(results) : nonDivisibleSequentialTransactionPlanResult(results)
    }
}

private func traverseSingle(
    _ transactionPlan: SingleTransactionPlan,
    config: TransactionPlanExecutorConfig,
    runConfig: TransactionPlanExecutorRunConfig,
    state: ExecutionState
) async -> TransactionPlanResult {
    if await state.isCanceled {
        return canceledSingleTransactionPlanResult(transactionPlan.message)
    }
    if let reason = runConfig.abortSignal?.abortReason() {
        await state.cancel()
        return failedSingleTransactionPlanResult(transactionPlan.message, reason)
    }
    let context = TransactionPlanExecutionContext()
    do {
        let execute = config.executeTransactionMessage
        let message = transactionPlan.message
        let output = try await getAbortablePromise({
            try await execute(context, message, runConfig)
        }, abortSignal: runConfig.abortSignal)
        switch output {
        case let .signature(signature):
            return successfulSingleTransactionPlanResult(transactionPlan.message, signature: signature)
        case let .transaction(transaction):
            return try successfulSingleTransactionPlanResultFromTransaction(transactionPlan.message, transaction)
        }
    } catch {
        await state.cancel()
        return failedSingleTransactionPlanResult(transactionPlan.message, error, context: context)
    }
}

private func assertDivisibleSequentialPlansOnly(_ transactionPlan: TransactionPlan) throws {
    switch transactionPlan {
    case .single:
        return
    case let .parallel(plan):
        for child in plan.plans {
            try assertDivisibleSequentialPlansOnly(child)
        }
    case let .sequential(plan):
        guard plan.divisible else {
            throw SolanaError(.instructionPlansNonDivisibleTransactionPlansNotSupported)
        }
        for child in plan.plans {
            try assertDivisibleSequentialPlansOnly(child)
        }
    }
}
