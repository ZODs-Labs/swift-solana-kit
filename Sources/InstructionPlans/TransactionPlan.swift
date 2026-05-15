import SolanaErrors
public import TransactionMessages

public struct SingleTransactionPlan: Sendable {
    public let kind = "single"
    public let message: TransactionMessage
    public let planType = "transactionPlan"

    public init(message: TransactionMessage) {
        self.message = message
    }
}

public struct ParallelTransactionPlan: Sendable {
    public let kind = "parallel"
    public let planType = "transactionPlan"
    public let plans: [TransactionPlan]

    public init(plans: [TransactionPlan]) {
        self.plans = plans
    }
}

public struct SequentialTransactionPlan: Sendable {
    public let divisible: Bool
    public let kind = "sequential"
    public let planType = "transactionPlan"
    public let plans: [TransactionPlan]

    public init(plans: [TransactionPlan], divisible: Bool = true) {
        self.divisible = divisible
        self.plans = plans
    }
}

public indirect enum TransactionPlan: Sendable {
    case single(SingleTransactionPlan)
    case parallel(ParallelTransactionPlan)
    case sequential(SequentialTransactionPlan)

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
        "transactionPlan"
    }
}

public func singleTransactionPlan(_ transactionMessage: TransactionMessage) -> TransactionPlan {
    .single(SingleTransactionPlan(message: transactionMessage))
}

public func parallelTransactionPlan(_ plans: [TransactionPlan]) -> TransactionPlan {
    .parallel(ParallelTransactionPlan(plans: plans))
}

public func parallelTransactionPlan(_ messages: [TransactionMessage]) -> TransactionPlan {
    .parallel(ParallelTransactionPlan(plans: messages.map(singleTransactionPlan)))
}

public func parallelTransactionPlan(_ inputs: [TransactionPlanInput]) -> TransactionPlan {
    .parallel(ParallelTransactionPlan(plans: inputs.map(parseTransactionPlanInput)))
}

public func sequentialTransactionPlan(_ plans: [TransactionPlan]) -> TransactionPlan {
    .sequential(SequentialTransactionPlan(plans: plans, divisible: true))
}

public func sequentialTransactionPlan(_ messages: [TransactionMessage]) -> TransactionPlan {
    .sequential(SequentialTransactionPlan(plans: messages.map(singleTransactionPlan), divisible: true))
}

public func sequentialTransactionPlan(_ inputs: [TransactionPlanInput]) -> TransactionPlan {
    .sequential(SequentialTransactionPlan(plans: inputs.map(parseTransactionPlanInput), divisible: true))
}

public func nonDivisibleSequentialTransactionPlan(_ plans: [TransactionPlan]) -> TransactionPlan {
    .sequential(SequentialTransactionPlan(plans: plans, divisible: false))
}

public func nonDivisibleSequentialTransactionPlan(_ messages: [TransactionMessage]) -> TransactionPlan {
    .sequential(SequentialTransactionPlan(plans: messages.map(singleTransactionPlan), divisible: false))
}

public func nonDivisibleSequentialTransactionPlan(_ inputs: [TransactionPlanInput]) -> TransactionPlan {
    .sequential(SequentialTransactionPlan(plans: inputs.map(parseTransactionPlanInput), divisible: false))
}

public func isTransactionPlan(_ value: Any) -> Bool {
    value is TransactionPlan
}

public func isSingleTransactionPlan(_ plan: TransactionPlan) -> Bool {
    if case .single = plan {
        return true
    }
    return false
}

public func assertIsSingleTransactionPlan(_ plan: TransactionPlan) throws {
    guard isSingleTransactionPlan(plan) else {
        throw unexpectedTransactionPlan(plan, expectedKind: "single")
    }
}

public func isSequentialTransactionPlan(_ plan: TransactionPlan) -> Bool {
    if case .sequential = plan {
        return true
    }
    return false
}

public func assertIsSequentialTransactionPlan(_ plan: TransactionPlan) throws {
    guard isSequentialTransactionPlan(plan) else {
        throw unexpectedTransactionPlan(plan, expectedKind: "sequential")
    }
}

public func isNonDivisibleSequentialTransactionPlan(_ plan: TransactionPlan) -> Bool {
    if case let .sequential(plan) = plan {
        return !plan.divisible
    }
    return false
}

public func assertIsNonDivisibleSequentialTransactionPlan(_ plan: TransactionPlan) throws {
    guard isNonDivisibleSequentialTransactionPlan(plan) else {
        let actualKind = plan.kind == "sequential" ? "divisible sequential" : plan.kind
        throw SolanaError(
            .instructionPlansUnexpectedTransactionPlan,
            context: ["actualKind": .string(actualKind), "expectedKind": .string("non-divisible sequential")]
        )
    }
}

public func isParallelTransactionPlan(_ plan: TransactionPlan) -> Bool {
    if case .parallel = plan {
        return true
    }
    return false
}

public func assertIsParallelTransactionPlan(_ plan: TransactionPlan) throws {
    guard isParallelTransactionPlan(plan) else {
        throw unexpectedTransactionPlan(plan, expectedKind: "parallel")
    }
}

public func flattenTransactionPlan(_ transactionPlan: TransactionPlan) -> [SingleTransactionPlan] {
    switch transactionPlan {
    case let .single(plan):
        return [plan]
    case let .parallel(plan):
        return plan.plans.flatMap(flattenTransactionPlan)
    case let .sequential(plan):
        return plan.plans.flatMap(flattenTransactionPlan)
    }
}

public func findTransactionPlan(
    _ transactionPlan: TransactionPlan,
    where predicate: (TransactionPlan) throws -> Bool
) rethrows -> TransactionPlan? {
    if try predicate(transactionPlan) {
        return transactionPlan
    }
    switch transactionPlan {
    case .single:
        return nil
    case let .parallel(plan):
        for subPlan in plan.plans {
            if let found = try findTransactionPlan(subPlan, where: predicate) {
                return found
            }
        }
    case let .sequential(plan):
        for subPlan in plan.plans {
            if let found = try findTransactionPlan(subPlan, where: predicate) {
                return found
            }
        }
    }
    return nil
}

public func everyTransactionPlan(
    _ transactionPlan: TransactionPlan,
    satisfies predicate: (TransactionPlan) throws -> Bool
) rethrows -> Bool {
    guard try predicate(transactionPlan) else {
        return false
    }
    switch transactionPlan {
    case .single:
        return true
    case let .parallel(plan):
        for subPlan in plan.plans where try !everyTransactionPlan(subPlan, satisfies: predicate) {
            return false
        }
    case let .sequential(plan):
        for subPlan in plan.plans where try !everyTransactionPlan(subPlan, satisfies: predicate) {
            return false
        }
    }
    return true
}

public func transformTransactionPlan(
    _ transactionPlan: TransactionPlan,
    _ transform: (TransactionPlan) throws -> TransactionPlan
) rethrows -> TransactionPlan {
    switch transactionPlan {
    case .single:
        return try transform(transactionPlan)
    case let .parallel(plan):
        return try transform(.parallel(ParallelTransactionPlan(
            plans: plan.plans.map { try transformTransactionPlan($0, transform) }
        )))
    case let .sequential(plan):
        return try transform(.sequential(SequentialTransactionPlan(
            plans: plan.plans.map { try transformTransactionPlan($0, transform) },
            divisible: plan.divisible
        )))
    }
}

func unexpectedTransactionPlan(_ plan: TransactionPlan, expectedKind: String) -> SolanaError {
    SolanaError(
        .instructionPlansUnexpectedTransactionPlan,
        context: ["actualKind": .string(plan.kind), "expectedKind": .string(expectedKind)]
    )
}
