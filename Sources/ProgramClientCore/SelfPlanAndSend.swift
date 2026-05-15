public import InstructionPlans
public import Instructions
public import PluginInterfaces
public import TransactionMessages

public struct SelfPlanAndSendItem<Input: Sendable>: Sendable {
    public let input: Input
    private let instructionPlanInput: @Sendable () async throws -> InstructionPlans.InstructionPlanInput
    private let singleTransactionInput: @Sendable () async throws -> PluginInterfaces.SingleTransactionPlanInput
    private let transactionInput: @Sendable () async throws -> PluginInterfaces.TransactionPlanInput
    private let planTransactionBody: @Sendable (PluginTransactionConfig?) async throws -> TransactionMessage
    private let planTransactionsBody: @Sendable (PluginTransactionConfig?) async throws -> InstructionPlans.TransactionPlan
    private let sendTransactionBody: @Sendable (PluginTransactionConfig?) async throws -> InstructionPlans.SuccessfulSingleTransactionPlanResult
    private let sendTransactionsBody: @Sendable (PluginTransactionConfig?) async throws -> InstructionPlans.TransactionPlanResult

    public init(
        input: Input,
        instructionPlanInput: @escaping @Sendable () async throws -> InstructionPlans.InstructionPlanInput,
        singleTransactionInput: @escaping @Sendable () async throws -> PluginInterfaces.SingleTransactionPlanInput,
        transactionInput: @escaping @Sendable () async throws -> PluginInterfaces.TransactionPlanInput,
        client: any ClientWithTransactionPlanning & ClientWithTransactionSending
    ) {
        self.input = input
        self.instructionPlanInput = instructionPlanInput
        self.singleTransactionInput = singleTransactionInput
        self.transactionInput = transactionInput
        self.planTransactionBody = { config in
            try await client.planTransaction(try await instructionPlanInput(), config: config)
        }
        self.planTransactionsBody = { config in
            try await client.planTransactions(try await instructionPlanInput(), config: config)
        }
        self.sendTransactionBody = { config in
            try await client.sendTransaction(try await singleTransactionInput(), config: config)
        }
        self.sendTransactionsBody = { config in
            try await client.sendTransactions(try await transactionInput(), config: config)
        }
    }

    public func planTransaction(config: PluginTransactionConfig? = nil) async throws -> TransactionMessage {
        try await planTransactionBody(config)
    }

    public func planTransactions(config: PluginTransactionConfig? = nil) async throws -> InstructionPlans.TransactionPlan {
        try await planTransactionsBody(config)
    }

    public func sendTransaction(config: PluginTransactionConfig? = nil) async throws -> InstructionPlans.SuccessfulSingleTransactionPlanResult {
        try await sendTransactionBody(config)
    }

    public func sendTransactions(config: PluginTransactionConfig? = nil) async throws -> InstructionPlans.TransactionPlanResult {
        try await sendTransactionsBody(config)
    }
}

public func addSelfPlanAndSendFunctions(
    client: any ClientWithTransactionPlanning & ClientWithTransactionSending,
    input: Instruction
) -> SelfPlanAndSendItem<Instruction> {
    let instructionInput = InstructionPlans.InstructionPlanInput.instruction(input)
    return SelfPlanAndSendItem<Instruction>(
        input: input,
        instructionPlanInput: { instructionInput },
        singleTransactionInput: { PluginInterfaces.SingleTransactionPlanInput.instruction(input) },
        transactionInput: { PluginInterfaces.TransactionPlanInput.instruction(input) },
        client: client
    )
}

public func addSelfPlanAndSendFunctions(
    client: any ClientWithTransactionPlanning & ClientWithTransactionSending,
    input: InstructionPlans.InstructionPlan
) -> SelfPlanAndSendItem<InstructionPlans.InstructionPlan> {
    let instructionInput = InstructionPlans.InstructionPlanInput.plan(input)
    return SelfPlanAndSendItem<InstructionPlans.InstructionPlan>(
        input: input,
        instructionPlanInput: { instructionInput },
        singleTransactionInput: { PluginInterfaces.SingleTransactionPlanInput.instructionPlan(input) },
        transactionInput: { PluginInterfaces.TransactionPlanInput.instructionPlan(input) },
        client: client
    )
}

public func addSelfPlanAndSendFunctions(
    client: any ClientWithTransactionPlanning & ClientWithTransactionSending,
    input: @escaping @Sendable () async throws -> Instruction
) -> SelfPlanAndSendItem<@Sendable () async throws -> Instruction> {
    SelfPlanAndSendItem<@Sendable () async throws -> Instruction>(
        input: input,
        instructionPlanInput: {
            let value = try await input()
            return InstructionPlans.InstructionPlanInput.instruction(value)
        },
        singleTransactionInput: {
            let value = try await input()
            return PluginInterfaces.SingleTransactionPlanInput.instruction(value)
        },
        transactionInput: {
            let value = try await input()
            return PluginInterfaces.TransactionPlanInput.instruction(value)
        },
        client: client
    )
}

public func addSelfPlanAndSendFunctions(
    client: any ClientWithTransactionPlanning & ClientWithTransactionSending,
    input: @escaping @Sendable () async throws -> InstructionPlans.InstructionPlan
) -> SelfPlanAndSendItem<@Sendable () async throws -> InstructionPlans.InstructionPlan> {
    SelfPlanAndSendItem<@Sendable () async throws -> InstructionPlans.InstructionPlan>(
        input: input,
        instructionPlanInput: {
            let value = try await input()
            return InstructionPlans.InstructionPlanInput.plan(value)
        },
        singleTransactionInput: {
            let value = try await input()
            return PluginInterfaces.SingleTransactionPlanInput.instructionPlan(value)
        },
        transactionInput: {
            let value = try await input()
            return PluginInterfaces.TransactionPlanInput.instructionPlan(value)
        },
        client: client
    )
}

public func addSelfPlanAndSendFunctions<Input: Sendable>(
    client: any ClientWithTransactionPlanning & ClientWithTransactionSending,
    input: @escaping @Sendable () async throws -> Input,
    resolveInstructionPlanInput: @escaping @Sendable (Input) throws -> InstructionPlans.InstructionPlanInput
) -> SelfPlanAndSendItem<@Sendable () async throws -> Input> {
    SelfPlanAndSendItem<@Sendable () async throws -> Input>(
        input: input,
        instructionPlanInput: {
            let value = try await input()
            return try resolveInstructionPlanInput(value)
        },
        singleTransactionInput: {
            let value = try await input()
            return try PluginInterfaces.SingleTransactionPlanInput.instructionPlanInput(resolveInstructionPlanInput(value))
        },
        transactionInput: {
            let value = try await input()
            return try PluginInterfaces.TransactionPlanInput.instructionPlanInput(resolveInstructionPlanInput(value))
        },
        client: client
    )
}
