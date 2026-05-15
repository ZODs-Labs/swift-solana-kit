import Foundation
public import Instructions
import SolanaErrors
public import TransactionMessages
import Transactions
import os

public struct SingleInstructionPlan: Sendable {
    public let instruction: Instruction
    public let kind = "single"
    public let planType = "instructionPlan"

    public init(instruction: Instruction) {
        self.instruction = instruction
    }
}

public struct ParallelInstructionPlan: Sendable {
    public let kind = "parallel"
    public let planType = "instructionPlan"
    public let plans: [InstructionPlan]

    public init(plans: [InstructionPlan]) {
        self.plans = plans
    }
}

public struct SequentialInstructionPlan: Sendable {
    public let divisible: Bool
    public let kind = "sequential"
    public let planType = "instructionPlan"
    public let plans: [InstructionPlan]

    public init(plans: [InstructionPlan], divisible: Bool = true) {
        self.divisible = divisible
        self.plans = plans
    }
}

public struct MessagePackerInstructionPlan: Sendable {
    public let kind = "messagePacker"
    public let planType = "instructionPlan"
    private let makeMessagePacker: @Sendable () -> MessagePacker

    public init(getMessagePacker: @escaping @Sendable () -> MessagePacker) {
        makeMessagePacker = getMessagePacker
    }

    public func getMessagePacker() -> MessagePacker {
        makeMessagePacker()
    }
}

public final class MessagePacker: Sendable {
    private let doneHandler: @Sendable () -> Bool
    private let packHandler: @Sendable (TransactionMessage) throws -> TransactionMessage

    public init(
        done: @escaping @Sendable () -> Bool,
        packMessageToCapacity: @escaping @Sendable (TransactionMessage) throws -> TransactionMessage
    ) {
        doneHandler = done
        packHandler = packMessageToCapacity
    }

    public func done() -> Bool {
        doneHandler()
    }

    public func packMessageToCapacity(_ transactionMessage: TransactionMessage) throws -> TransactionMessage {
        try packHandler(transactionMessage)
    }
}

public indirect enum InstructionPlan: Sendable {
    case single(SingleInstructionPlan)
    case parallel(ParallelInstructionPlan)
    case sequential(SequentialInstructionPlan)
    case messagePacker(MessagePackerInstructionPlan)

    public var kind: String {
        switch self {
        case .single:
            "single"
        case .parallel:
            "parallel"
        case .sequential:
            "sequential"
        case .messagePacker:
            "messagePacker"
        }
    }

    public var planType: String {
        "instructionPlan"
    }
}

public func singleInstructionPlan(_ instruction: Instruction) -> InstructionPlan {
    .single(SingleInstructionPlan(instruction: instruction))
}

public func parallelInstructionPlan(_ plans: [InstructionPlan]) -> InstructionPlan {
    .parallel(ParallelInstructionPlan(plans: plans))
}

public func parallelInstructionPlan(_ instructions: [Instruction]) -> InstructionPlan {
    .parallel(ParallelInstructionPlan(plans: instructions.map(singleInstructionPlan)))
}

public func parallelInstructionPlan(_ inputs: [InstructionPlanInput]) -> InstructionPlan {
    .parallel(ParallelInstructionPlan(plans: inputs.map(parseInstructionPlanInput)))
}

public func sequentialInstructionPlan(_ plans: [InstructionPlan]) -> InstructionPlan {
    .sequential(SequentialInstructionPlan(plans: plans, divisible: true))
}

public func sequentialInstructionPlan(_ instructions: [Instruction]) -> InstructionPlan {
    .sequential(SequentialInstructionPlan(plans: instructions.map(singleInstructionPlan), divisible: true))
}

public func sequentialInstructionPlan(_ inputs: [InstructionPlanInput]) -> InstructionPlan {
    .sequential(SequentialInstructionPlan(plans: inputs.map(parseInstructionPlanInput), divisible: true))
}

public func nonDivisibleSequentialInstructionPlan(_ plans: [InstructionPlan]) -> InstructionPlan {
    .sequential(SequentialInstructionPlan(plans: plans, divisible: false))
}

public func nonDivisibleSequentialInstructionPlan(_ instructions: [Instruction]) -> InstructionPlan {
    .sequential(SequentialInstructionPlan(plans: instructions.map(singleInstructionPlan), divisible: false))
}

public func nonDivisibleSequentialInstructionPlan(_ inputs: [InstructionPlanInput]) -> InstructionPlan {
    .sequential(SequentialInstructionPlan(plans: inputs.map(parseInstructionPlanInput), divisible: false))
}

public func isInstructionPlan(_ value: Any) -> Bool {
    value is InstructionPlan
}

public func isSingleInstructionPlan(_ plan: InstructionPlan) -> Bool {
    if case .single = plan {
        return true
    }
    return false
}

public func assertIsSingleInstructionPlan(_ plan: InstructionPlan) throws {
    guard isSingleInstructionPlan(plan) else {
        throw unexpectedInstructionPlan(plan, expectedKind: "single")
    }
}

public func isMessagePackerInstructionPlan(_ plan: InstructionPlan) -> Bool {
    if case .messagePacker = plan {
        return true
    }
    return false
}

public func assertIsMessagePackerInstructionPlan(_ plan: InstructionPlan) throws {
    guard isMessagePackerInstructionPlan(plan) else {
        throw unexpectedInstructionPlan(plan, expectedKind: "messagePacker")
    }
}

public func isSequentialInstructionPlan(_ plan: InstructionPlan) -> Bool {
    if case .sequential = plan {
        return true
    }
    return false
}

public func assertIsSequentialInstructionPlan(_ plan: InstructionPlan) throws {
    guard isSequentialInstructionPlan(plan) else {
        throw unexpectedInstructionPlan(plan, expectedKind: "sequential")
    }
}

public func isNonDivisibleSequentialInstructionPlan(_ plan: InstructionPlan) -> Bool {
    if case let .sequential(plan) = plan {
        return !plan.divisible
    }
    return false
}

public func assertIsNonDivisibleSequentialInstructionPlan(_ plan: InstructionPlan) throws {
    guard isNonDivisibleSequentialInstructionPlan(plan) else {
        let actualKind = plan.kind == "sequential" ? "divisible sequential" : plan.kind
        throw SolanaError(
            .instructionPlansUnexpectedInstructionPlan,
            context: ["actualKind": .string(actualKind), "expectedKind": .string("non-divisible sequential")]
        )
    }
}

public func isParallelInstructionPlan(_ plan: InstructionPlan) -> Bool {
    if case .parallel = plan {
        return true
    }
    return false
}

public func assertIsParallelInstructionPlan(_ plan: InstructionPlan) throws {
    guard isParallelInstructionPlan(plan) else {
        throw unexpectedInstructionPlan(plan, expectedKind: "parallel")
    }
}

public func findInstructionPlan(
    _ instructionPlan: InstructionPlan,
    where predicate: (InstructionPlan) throws -> Bool
) rethrows -> InstructionPlan? {
    if try predicate(instructionPlan) {
        return instructionPlan
    }
    switch instructionPlan {
    case .single, .messagePacker:
        return nil
    case let .parallel(plan):
        for subPlan in plan.plans {
            if let found = try findInstructionPlan(subPlan, where: predicate) {
                return found
            }
        }
    case let .sequential(plan):
        for subPlan in plan.plans {
            if let found = try findInstructionPlan(subPlan, where: predicate) {
                return found
            }
        }
    }
    return nil
}

public func everyInstructionPlan(
    _ instructionPlan: InstructionPlan,
    satisfies predicate: (InstructionPlan) throws -> Bool
) rethrows -> Bool {
    guard try predicate(instructionPlan) else {
        return false
    }
    switch instructionPlan {
    case .single, .messagePacker:
        return true
    case let .parallel(plan):
        for subPlan in plan.plans where try !everyInstructionPlan(subPlan, satisfies: predicate) {
            return false
        }
    case let .sequential(plan):
        for subPlan in plan.plans where try !everyInstructionPlan(subPlan, satisfies: predicate) {
            return false
        }
    }
    return true
}

public func transformInstructionPlan(
    _ instructionPlan: InstructionPlan,
    _ transform: (InstructionPlan) throws -> InstructionPlan
) rethrows -> InstructionPlan {
    switch instructionPlan {
    case .single, .messagePacker:
        return try transform(instructionPlan)
    case let .parallel(plan):
        return try transform(.parallel(ParallelInstructionPlan(
            plans: plan.plans.map { try transformInstructionPlan($0, transform) }
        )))
    case let .sequential(plan):
        return try transform(.sequential(SequentialInstructionPlan(
            plans: plan.plans.map { try transformInstructionPlan($0, transform) },
            divisible: plan.divisible
        )))
    }
}

public func flattenInstructionPlan(_ instructionPlan: InstructionPlan) -> [InstructionPlan] {
    switch instructionPlan {
    case .single, .messagePacker:
        return [instructionPlan]
    case let .parallel(plan):
        return plan.plans.flatMap(flattenInstructionPlan)
    case let .sequential(plan):
        return plan.plans.flatMap(flattenInstructionPlan)
    }
}

public func getLinearMessagePackerInstructionPlan(
    totalLength: Int,
    getInstruction: @escaping @Sendable (_ offset: Int, _ length: Int) -> Instruction
) -> InstructionPlan {
    .messagePacker(MessagePackerInstructionPlan {
        let offset = OSAllocatedUnfairLock(initialState: 0)
        return MessagePacker {
            offset.withLock { $0 >= totalLength }
        } packMessageToCapacity: { message in
            try offset.withLock { currentOffset in
                if currentOffset >= totalLength {
                    throw SolanaError(.instructionPlansMessagePackerAlreadyComplete)
                }
                let baseMessage = appendTransactionMessageInstruction(getInstruction(currentOffset, 0), message)
                let baseSize = try getTransactionMessageSize(baseMessage)
                let freeSpace = getTransactionMessageSizeLimit(message) - baseSize - 1
                if freeSpace <= 0 {
                    let messageSize = try getTransactionMessageSize(message)
                    throw SolanaError(
                        .instructionPlansMessageCannotAccommodatePlan,
                        context: [
                            "numBytesRequired": .int(baseSize - messageSize + 1),
                            "numFreeBytes": .int(getTransactionMessageSizeLimit(message) - messageSize - 1),
                        ]
                    )
                }
                let length = min(totalLength - currentOffset, freeSpace)
                let instruction = getInstruction(currentOffset, length)
                currentOffset += length
                return appendTransactionMessageInstruction(instruction, message)
            }
        }
    })
}

public func getMessagePackerInstructionPlanFromInstructions(_ instructions: [Instruction]) -> InstructionPlan {
    .messagePacker(MessagePackerInstructionPlan {
        let instructionIndex = OSAllocatedUnfairLock(initialState: 0)
        return MessagePacker {
            instructionIndex.withLock { $0 >= instructions.count }
        } packMessageToCapacity: { originalMessage in
            try instructionIndex.withLock { index in
                if index >= instructions.count {
                    throw SolanaError(.instructionPlansMessagePackerAlreadyComplete)
                }
                let originalMessageSize = try getTransactionMessageSize(originalMessage)
                var message = originalMessage
                var nextIndex = index
                while nextIndex < instructions.count {
                    message = appendTransactionMessageInstruction(instructions[nextIndex], message)
                    let messageSize = try getTransactionMessageSize(message)
                    if messageSize > getTransactionMessageSizeLimit(message) {
                        if nextIndex == index {
                            throw SolanaError(
                                .instructionPlansMessageCannotAccommodatePlan,
                                context: [
                                    "numBytesRequired": .int(messageSize - originalMessageSize),
                                    "numFreeBytes": .int(getTransactionMessageSizeLimit(message) - originalMessageSize),
                                ]
                            )
                        }
                        index = nextIndex
                        return message
                    }
                    nextIndex += 1
                }
                index = instructions.count
                return message
            }
        }
    })
}

public func getReallocMessagePackerInstructionPlan(
    totalSize: Int,
    getInstruction: @escaping @Sendable (_ size: Int) -> Instruction
) -> InstructionPlan {
    let reallocLimit = 10_240
    let numberOfInstructions = totalSize == 0 ? 0 : (totalSize + reallocLimit - 1) / reallocLimit
    let lastInstructionSize = totalSize % reallocLimit
    let instructions = (0..<numberOfInstructions).map { index in
        getInstruction(index == numberOfInstructions - 1 ? lastInstructionSize : reallocLimit)
    }
    return getMessagePackerInstructionPlanFromInstructions(instructions)
}

public func appendTransactionMessageInstructionPlan(
    _ instructionPlan: InstructionPlan,
    _ transactionMessage: TransactionMessage
) throws -> TransactionMessage {
    var message = transactionMessage
    for leafPlan in flattenInstructionPlan(instructionPlan) {
        switch leafPlan {
        case let .single(plan):
            message = appendTransactionMessageInstruction(plan.instruction, message)
        case let .messagePacker(plan):
            let packer = plan.getMessagePacker()
            while !packer.done() {
                message = try packer.packMessageToCapacity(message)
            }
        case .parallel, .sequential:
            throw unexpectedInstructionPlan(leafPlan, expectedKind: "single or messagePacker")
        }
    }
    return message
}

func unexpectedInstructionPlan(_ plan: InstructionPlan, expectedKind: String) -> SolanaError {
    SolanaError(
        .instructionPlansUnexpectedInstructionPlan,
        context: ["actualKind": .string(plan.kind), "expectedKind": .string(expectedKind)]
    )
}
