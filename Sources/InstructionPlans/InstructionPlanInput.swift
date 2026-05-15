public import Instructions
public import TransactionMessages

public indirect enum InstructionPlanInput: Sendable {
    case instruction(Instruction)
    case plan(InstructionPlan)
    case array([InstructionPlanInput])
}

public indirect enum TransactionPlanInput: Sendable {
    case message(TransactionMessage)
    case plan(TransactionPlan)
    case array([TransactionPlanInput])
}

public enum InstructionOrTransactionPlanInput: Sendable {
    case instruction(InstructionPlanInput)
    case transaction(TransactionPlanInput)
}

public enum InstructionOrTransactionPlan: Sendable {
    case instruction(InstructionPlan)
    case transaction(TransactionPlan)
}

public func parseInstructionPlanInput(_ input: InstructionPlanInput) -> InstructionPlan {
    switch input {
    case let .instruction(instruction):
        return singleInstructionPlan(instruction)
    case let .plan(plan):
        return plan
    case let .array(inputs):
        if inputs.count == 1, let first = inputs.first {
            return parseInstructionPlanInput(first)
        }
        return sequentialInstructionPlan(inputs)
    }
}

public func parseInstructionPlanInput(_ instruction: Instruction) -> InstructionPlan {
    singleInstructionPlan(instruction)
}

public func parseInstructionPlanInput(_ plan: InstructionPlan) -> InstructionPlan {
    plan
}

public func parseInstructionPlanInput(_ inputs: [InstructionPlanInput]) -> InstructionPlan {
    parseInstructionPlanInput(.array(inputs))
}

public func parseTransactionPlanInput(_ input: TransactionPlanInput) -> TransactionPlan {
    switch input {
    case let .message(message):
        return singleTransactionPlan(message)
    case let .plan(plan):
        return plan
    case let .array(inputs):
        if inputs.count == 1, let first = inputs.first {
            return parseTransactionPlanInput(first)
        }
        return sequentialTransactionPlan(inputs)
    }
}

public func parseTransactionPlanInput(_ message: TransactionMessage) -> TransactionPlan {
    singleTransactionPlan(message)
}

public func parseTransactionPlanInput(_ plan: TransactionPlan) -> TransactionPlan {
    plan
}

public func parseTransactionPlanInput(_ inputs: [TransactionPlanInput]) -> TransactionPlan {
    parseTransactionPlanInput(.array(inputs))
}

public func parseInstructionOrTransactionPlanInput(
    _ input: InstructionOrTransactionPlanInput
) -> InstructionOrTransactionPlan {
    switch input {
    case let .instruction(input):
        return .instruction(parseInstructionPlanInput(input))
    case let .transaction(input):
        return .transaction(parseTransactionPlanInput(input))
    }
}
