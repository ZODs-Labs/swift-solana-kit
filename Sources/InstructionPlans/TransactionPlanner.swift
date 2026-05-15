public import Instructions
public import Promises
public import SolanaErrors
public import TransactionMessages
public import Transactions

public typealias TransactionPlanner = @Sendable (
    _ instructionPlan: InstructionPlan,
    _ config: TransactionPlannerRunConfig
) async throws -> TransactionPlan

public struct TransactionPlannerRunConfig: Sendable {
    public let abortSignal: AbortSignal?

    public init(abortSignal: AbortSignal? = nil) {
        self.abortSignal = abortSignal
    }
}

public struct TransactionPlannerConfig: Sendable {
    public let createTransactionMessage: @Sendable (_ config: TransactionPlannerRunConfig) async throws -> TransactionMessage
    public let onTransactionMessageUpdated: (@Sendable (_ transactionMessage: TransactionMessage, _ config: TransactionPlannerRunConfig) async throws -> TransactionMessage)?

    public init(
        createTransactionMessage: @escaping @Sendable (_ config: TransactionPlannerRunConfig) async throws -> TransactionMessage,
        onTransactionMessageUpdated: (@Sendable (_ transactionMessage: TransactionMessage, _ config: TransactionPlannerRunConfig) async throws -> TransactionMessage)? = nil
    ) {
        self.createTransactionMessage = createTransactionMessage
        self.onTransactionMessageUpdated = onTransactionMessageUpdated
    }
}

public func createTransactionPlanner(_ config: TransactionPlannerConfig) -> TransactionPlanner {
    { instructionPlan, runConfig in
        let context = TransactionPlannerContext(
            abortSignal: runConfig.abortSignal,
            config: config,
            parent: nil,
            parentCandidates: []
        )
        let plan = try await traverse(instructionPlan, context: context)
        guard let plan else {
            throw SolanaError(.instructionPlansEmptyInstructionPlan)
        }
        return freezeTransactionPlan(plan)
    }
}

private final class MutableSingleTransactionPlan {
    var message: TransactionMessage

    init(message: TransactionMessage) {
        self.message = message
    }
}

private indirect enum MutableTransactionPlan {
    case single(MutableSingleTransactionPlan)
    case parallel([MutableTransactionPlan])
    case sequential(plans: [MutableTransactionPlan], divisible: Bool)
}

private struct TransactionPlannerContext {
    let abortSignal: AbortSignal?
    let config: TransactionPlannerConfig
    let parent: InstructionPlan?
    let parentCandidates: [MutableSingleTransactionPlan]

    var runConfig: TransactionPlannerRunConfig {
        TransactionPlannerRunConfig(abortSignal: abortSignal)
    }

    func child(parent: InstructionPlan, parentCandidates: [MutableSingleTransactionPlan]) -> TransactionPlannerContext {
        TransactionPlannerContext(
            abortSignal: abortSignal,
            config: config,
            parent: parent,
            parentCandidates: parentCandidates
        )
    }
}

private func traverse(
    _ instructionPlan: InstructionPlan,
    context: TransactionPlannerContext
) async throws -> MutableTransactionPlan? {
    if let reason = context.abortSignal?.abortReason() {
        throw reason
    }
    switch instructionPlan {
    case let .single(plan):
        return try await traverseSingle(plan, context: context)
    case let .parallel(plan):
        return try await traverseParallel(plan, context: context)
    case let .sequential(plan):
        return try await traverseSequential(plan, context: context)
    case let .messagePacker(plan):
        return try await traverseMessagePacker(plan, context: context)
    }
}

private func traverseSequential(
    _ instructionPlan: SequentialInstructionPlan,
    context: TransactionPlannerContext
) async throws -> MutableTransactionPlan? {
    var candidate: MutableSingleTransactionPlan?
    let currentPlan = InstructionPlan.sequential(instructionPlan)
    let mustEntirelyFitInParentCandidate = context.parent != nil
        && (context.parent?.kind == "parallel" || !instructionPlan.divisible)

    if mustEntirelyFitInParentCandidate {
        let selected = try await selectAndMutateCandidate(context: context, candidates: context.parentCandidates) { message in
            try fitEntirePlanInsideMessage(currentPlan, message)
        }
        if selected != nil {
            return nil
        }
    } else {
        candidate = context.parentCandidates.first
    }

    var transactionPlans: [MutableTransactionPlan] = []
    for plan in instructionPlan.plans {
        let childContext = context.child(
            parent: currentPlan,
            parentCandidates: candidate.map { [$0] } ?? []
        )
        if let transactionPlan = try await traverse(plan, context: childContext) {
            candidate = getSequentialCandidate(transactionPlan)
            let newPlans: [MutableTransactionPlan]
            if case let .sequential(plans, divisible) = transactionPlan,
               divisible || !instructionPlan.divisible {
                newPlans = plans
            } else {
                newPlans = [transactionPlan]
            }
            transactionPlans.append(contentsOf: newPlans)
        }
    }

    if transactionPlans.isEmpty {
        return nil
    }
    if transactionPlans.count == 1 {
        return transactionPlans[0]
    }
    return .sequential(plans: transactionPlans, divisible: instructionPlan.divisible)
}

private func traverseParallel(
    _ instructionPlan: ParallelInstructionPlan,
    context: TransactionPlannerContext
) async throws -> MutableTransactionPlan? {
    var candidates = context.parentCandidates
    var transactionPlans: [MutableTransactionPlan] = []
    let currentPlan = InstructionPlan.parallel(instructionPlan)
    let sortedChildren = instructionPlan.plans.sorted {
        NumberBool($0.kind == "messagePacker") < NumberBool($1.kind == "messagePacker")
    }

    for plan in sortedChildren {
        let childContext = context.child(parent: currentPlan, parentCandidates: candidates)
        if let transactionPlan = try await traverse(plan, context: childContext) {
            candidates.append(contentsOf: getParallelCandidates(transactionPlan))
            if case let .parallel(plans) = transactionPlan {
                transactionPlans.append(contentsOf: plans)
            } else {
                transactionPlans.append(transactionPlan)
            }
        }
    }

    if transactionPlans.isEmpty {
        return nil
    }
    if transactionPlans.count == 1 {
        return transactionPlans[0]
    }
    return .parallel(transactionPlans)
}

private func traverseSingle(
    _ instructionPlan: SingleInstructionPlan,
    context: TransactionPlannerContext
) async throws -> MutableTransactionPlan? {
    let selected = try await selectAndMutateCandidate(context: context, candidates: context.parentCandidates) { message in
        try appendInstruction(instructionPlan.instruction, to: message)
    }
    if selected != nil {
        return nil
    }
    let message = try await createNewMessage(context: context) { message in
        try appendInstruction(instructionPlan.instruction, to: message)
    }
    return .single(MutableSingleTransactionPlan(message: message))
}

private func traverseMessagePacker(
    _ instructionPlan: MessagePackerInstructionPlan,
    context: TransactionPlannerContext
) async throws -> MutableTransactionPlan? {
    let messagePacker = instructionPlan.getMessagePacker()
    var transactionPlans: [MutableTransactionPlan] = []
    var candidates = context.parentCandidates

    while !messagePacker.done() {
        let selected = try await selectAndMutateCandidate(context: context, candidates: candidates) { message in
            try messagePacker.packMessageToCapacity(message)
        }
        if selected == nil {
            let message = try await createNewMessage(context: context) { message in
                try messagePacker.packMessageToCapacity(message)
            }
            let newPlan = MutableSingleTransactionPlan(message: message)
            transactionPlans.append(.single(newPlan))
            candidates.append(newPlan)
        }
    }

    if transactionPlans.isEmpty {
        return nil
    }
    if transactionPlans.count == 1 {
        return transactionPlans[0]
    }
    if context.parent?.kind == "parallel" {
        return .parallel(transactionPlans)
    }
    let divisible = if case let .sequential(plan)? = context.parent {
        plan.divisible
    } else {
        true
    }
    return .sequential(plans: transactionPlans, divisible: divisible)
}

private func selectAndMutateCandidate(
    context: TransactionPlannerContext,
    candidates: [MutableSingleTransactionPlan],
    predicate: (TransactionMessage) throws -> TransactionMessage
) async throws -> MutableSingleTransactionPlan? {
    for candidate in candidates {
        do {
            let proposed = try predicate(candidate.message)
            let updated = try await update(proposed, context: context)
            if try getTransactionMessageSize(updated) <= getTransactionMessageSizeLimit(updated) {
                candidate.message = updated
                return candidate
            }
        } catch let error as SolanaError where isCandidateCapacityError(error) {
        }
    }
    return nil
}

private func createNewMessage(
    context: TransactionPlannerContext,
    predicate: (TransactionMessage) throws -> TransactionMessage
) async throws -> TransactionMessage {
    let createTransactionMessage = context.config.createTransactionMessage
    let runConfig = context.runConfig
    let newMessage = try await getAbortablePromise({
        try await createTransactionMessage(runConfig)
    }, abortSignal: context.abortSignal)
    let updatedMessage = try await update(try predicate(newMessage), context: context)
    let updatedMessageSize = try getTransactionMessageSize(updatedMessage)
    if updatedMessageSize > getTransactionMessageSizeLimit(updatedMessage) {
        let newMessageSize = try getTransactionMessageSize(newMessage)
        throw SolanaError(
            .instructionPlansMessageCannotAccommodatePlan,
            context: [
                "numBytesRequired": .int(updatedMessageSize - newMessageSize),
                "numFreeBytes": .int(getTransactionMessageSizeLimit(newMessage) - newMessageSize),
            ]
        )
    }
    return updatedMessage
}

private func update(_ message: TransactionMessage, context: TransactionPlannerContext) async throws -> TransactionMessage {
    guard let update = context.config.onTransactionMessageUpdated else {
        if let reason = context.abortSignal?.abortReason() {
            throw reason
        }
        return message
    }
    let runConfig = context.runConfig
    return try await getAbortablePromise({
        try await update(message, runConfig)
    }, abortSignal: context.abortSignal)
}

private func appendInstruction(_ instruction: Instruction, to message: TransactionMessage) throws -> TransactionMessage {
    let newMessage = appendTransactionMessageInstruction(instruction, message)
    let newMessageSize = try getTransactionMessageSize(newMessage)
    if newMessageSize > getTransactionMessageSizeLimit(newMessage) {
        let baseMessageSize = try getTransactionMessageSize(message)
        throw SolanaError(
            .instructionPlansMessageCannotAccommodatePlan,
            context: [
                "numBytesRequired": .int(newMessageSize - baseMessageSize),
                "numFreeBytes": .int(getTransactionMessageSizeLimit(message) - baseMessageSize),
            ]
        )
    }
    return newMessage
}

private func fitEntirePlanInsideMessage(
    _ instructionPlan: InstructionPlan,
    _ message: TransactionMessage
) throws -> TransactionMessage {
    var newMessage = message
    switch instructionPlan {
    case let .sequential(plan):
        for child in plan.plans {
            newMessage = try fitEntirePlanInsideMessage(child, newMessage)
        }
    case let .parallel(plan):
        for child in plan.plans {
            newMessage = try fitEntirePlanInsideMessage(child, newMessage)
        }
    case let .single(plan):
        newMessage = try appendInstruction(plan.instruction, to: newMessage)
    case let .messagePacker(plan):
        let messagePacker = plan.getMessagePacker()
        while !messagePacker.done() {
            newMessage = try messagePacker.packMessageToCapacity(newMessage)
        }
    }
    return newMessage
}

private func getSequentialCandidate(_ latestPlan: MutableTransactionPlan) -> MutableSingleTransactionPlan? {
    switch latestPlan {
    case let .single(plan):
        return plan
    case let .sequential(plans, _):
        guard let last = plans.last else {
            return nil
        }
        return getSequentialCandidate(last)
    case .parallel:
        return nil
    }
}

private func getParallelCandidates(_ latestPlan: MutableTransactionPlan) -> [MutableSingleTransactionPlan] {
    switch latestPlan {
    case let .single(plan):
        return [plan]
    case let .parallel(plans):
        return plans.flatMap(getParallelCandidates)
    case let .sequential(plans, _):
        return plans.flatMap(getParallelCandidates)
    }
}

private func freezeTransactionPlan(_ plan: MutableTransactionPlan) -> TransactionPlan {
    switch plan {
    case let .single(plan):
        return singleTransactionPlan(plan.message)
    case let .parallel(plans):
        return parallelTransactionPlan(plans.map(freezeTransactionPlan))
    case let .sequential(plans, divisible):
        let frozen = plans.map(freezeTransactionPlan)
        return divisible ? sequentialTransactionPlan(frozen) : nonDivisibleSequentialTransactionPlan(frozen)
    }
}

private struct NumberBool: Comparable {
    let value: Int

    init(_ bool: Bool) {
        value = bool ? 1 : 0
    }

    static func < (lhs: NumberBool, rhs: NumberBool) -> Bool {
        lhs.value < rhs.value
    }
}

private func isCandidateCapacityError(_ error: SolanaError) -> Bool {
    [
        SolanaErrorCode.instructionPlansMessageCannotAccommodatePlan.rawValue,
        SolanaErrorCode.transactionTooManyAccountAddresses.rawValue,
        SolanaErrorCode.transactionTooManyAccountsInInstruction.rawValue,
        SolanaErrorCode.transactionTooManyInstructions.rawValue,
        SolanaErrorCode.transactionTooManySignerAddresses.rawValue,
    ].contains(error.code)
}
