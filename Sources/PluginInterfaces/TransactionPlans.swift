public import InstructionPlans
public import Instructions
public import Promises
public import TransactionMessages

public struct PluginTransactionConfig: Sendable, Equatable {
    public let abortSignal: AbortSignal?

    public init(abortSignal: AbortSignal? = nil) {
        self.abortSignal = abortSignal
    }

    public static func == (lhs: PluginTransactionConfig, rhs: PluginTransactionConfig) -> Bool {
        lhs.abortSignal === rhs.abortSignal
    }
}

public enum SingleTransactionPlanInput: Sendable {
    case instruction(Instruction)
    case instructionPlan(InstructionPlans.InstructionPlan)
    case instructionPlanInput(InstructionPlans.InstructionPlanInput)
    case singleTransactionPlan(InstructionPlans.SingleTransactionPlan)
    case transactionMessage(TransactionMessage)
}

public enum TransactionPlanInput: Sendable {
    case instruction(Instruction)
    case instructionPlan(InstructionPlans.InstructionPlan)
    case instructionPlanInput(InstructionPlans.InstructionPlanInput)
    case transactionPlan(InstructionPlans.TransactionPlan)
}

public protocol ClientWithTransactionPlanning: Sendable {
    func planTransaction(
        _ input: InstructionPlans.InstructionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> TransactionMessage

    func planTransactions(
        _ input: InstructionPlans.InstructionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> InstructionPlans.TransactionPlan
}

public protocol ClientWithTransactionSending: Sendable {
    func sendTransaction(
        _ input: SingleTransactionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> InstructionPlans.SuccessfulSingleTransactionPlanResult

    func sendTransactions(
        _ input: TransactionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> InstructionPlans.TransactionPlanResult
}
