public import SolanaErrors

public func createFailedToExecuteTransactionPlanError(
    _ result: TransactionPlanResult,
    abortReason: String? = nil
) -> FailedToExecuteTransactionPlanError {
    FailedToExecuteTransactionPlanError(result: result, abortReason: abortReason)
}

public func createFailedToSendTransactionError(
    _ result: SingleTransactionPlanResult,
    abortReason: String? = nil
) -> SolanaError {
    switch result {
    case let .failed(result):
        let indicator = result.context.signature.map { " (\($0))" } ?? ""
        return SolanaError(
            .failedToSendTransaction,
            context: [
                "causeMessage": .string("\(indicator): \(result.error.message)"),
                "cause": .string(result.error.message),
            ]
        )
    case .canceled:
        let message = abortReason.map { ". Canceled with abort reason: \($0)" } ?? ": Canceled"
        return SolanaError(
            .failedToSendTransaction,
            context: ["causeMessage": .string(message)]
        )
    case .successful:
        return SolanaError(.failedToSendTransaction)
    }
}

public func createFailedToSendTransactionsError(
    _ result: TransactionPlanResult,
    abortReason: String? = nil
) -> SolanaError {
    let flattened = flattenTransactionPlanResult(result)
    let failedMessages = flattened.enumerated().compactMap { index, single -> String? in
        if case let .failed(result) = single {
            return "[Tx #\(index + 1)] \(result.error.message)"
        }
        return nil
    }
    let causeMessages: String
    if failedMessages.isEmpty {
        causeMessages = abortReason.map { ". Canceled with abort reason: \($0)" } ?? ": Canceled"
    } else {
        causeMessages = ".\n" + failedMessages.joined(separator: "\n")
    }
    return SolanaError(
        .failedToSendTransactions,
        context: ["causeMessages": .string(causeMessages)]
    )
}
