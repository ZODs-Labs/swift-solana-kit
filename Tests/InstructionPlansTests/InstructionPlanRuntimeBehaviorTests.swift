import Addresses
import Foundation
import Instructions
@testable import InstructionPlans
import Keys
import SolanaErrors
import TransactionMessages
import XCTest

final class InstructionPlanRuntimeBehaviorTests: XCTestCase {
    func testInputParsingCoversDirectSingleEmptyNestedAndMixedValues() throws {
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let nestedInstructionPlan = parallelInstructionPlan([instructionB])

        XCTAssertTrue(isSingleInstructionPlan(parseInstructionPlanInput(instructionA)))
        XCTAssertEqual(parseInstructionPlanInput(nestedInstructionPlan).kind, "parallel")
        XCTAssertTrue(isSingleInstructionPlan(parseInstructionPlanInput([.instruction(instructionA)])))
        XCTAssertEqual(parseInstructionPlanInput([.plan(nestedInstructionPlan)]).kind, "parallel")

        guard case let .sequential(emptyInstructions) = parseInstructionPlanInput([InstructionPlanInput]()) else {
            return XCTFail("Expected an empty sequential instruction plan")
        }
        XCTAssertTrue(emptyInstructions.divisible)
        XCTAssertTrue(emptyInstructions.plans.isEmpty)

        guard case let .sequential(parsedInstructions) = parseInstructionPlanInput([
            .instruction(instructionA),
            .instruction(instructionB),
        ]) else {
            return XCTFail("Expected a sequential instruction plan")
        }
        XCTAssertEqual(parsedInstructions.plans.map(\.kind), ["single", "single"])

        guard case let .sequential(parsedMixedInstructions) = parseInstructionPlanInput([
            .plan(nestedInstructionPlan),
            .instruction(instructionA),
        ]) else {
            return XCTFail("Expected a mixed sequential instruction plan")
        }
        XCTAssertEqual(parsedMixedInstructions.plans.map(\.kind), ["parallel", "single"])

        let messageA = try Self.makeMessage("A")
        let messageB = try Self.makeMessage("B")
        let nestedTransactionPlan = parallelTransactionPlan([messageB])

        XCTAssertTrue(isSingleTransactionPlan(parseTransactionPlanInput(messageA)))
        XCTAssertEqual(parseTransactionPlanInput(nestedTransactionPlan).kind, "parallel")
        XCTAssertTrue(isSingleTransactionPlan(parseTransactionPlanInput([.message(messageA)])))
        XCTAssertEqual(parseTransactionPlanInput([.plan(nestedTransactionPlan)]).kind, "parallel")

        guard case let .sequential(emptyTransactions) = parseTransactionPlanInput([TransactionPlanInput]()) else {
            return XCTFail("Expected an empty sequential transaction plan")
        }
        XCTAssertTrue(emptyTransactions.divisible)
        XCTAssertTrue(emptyTransactions.plans.isEmpty)

        guard case let .sequential(parsedTransactions) = parseTransactionPlanInput([
            .message(messageA),
            .message(messageB),
        ]) else {
            return XCTFail("Expected a sequential transaction plan")
        }
        XCTAssertEqual(parsedTransactions.plans.map(\.kind), ["single", "single"])

        guard case let .instruction(unionInstruction) = parseInstructionOrTransactionPlanInput(.instruction(.plan(nestedInstructionPlan))) else {
            return XCTFail("Expected an instruction plan")
        }
        XCTAssertEqual(unionInstruction.kind, "parallel")

        guard case let .transaction(unionTransaction) = parseInstructionOrTransactionPlanInput(.transaction(.plan(nestedTransactionPlan))) else {
            return XCTFail("Expected a transaction plan")
        }
        XCTAssertEqual(unionTransaction.kind, "parallel")
    }

    func testPredicatesRejectOtherShapesWithExactErrorContexts() throws {
        let singleInstruction = singleInstructionPlan(try Self.makeInstruction("A"))
        let messagePacker = getMessagePackerInstructionPlanFromInstructions([])
        let sequentialInstruction = sequentialInstructionPlan([InstructionPlan]())
        let nonDivisibleInstruction = nonDivisibleSequentialInstructionPlan([InstructionPlan]())
        let parallelInstruction = parallelInstructionPlan([InstructionPlan]())

        XCTAssertFalse(isSingleInstructionPlan(parallelInstruction))
        XCTAssertFalse(isMessagePackerInstructionPlan(singleInstruction))
        XCTAssertFalse(isSequentialInstructionPlan(messagePacker))
        XCTAssertFalse(isNonDivisibleSequentialInstructionPlan(sequentialInstruction))
        XCTAssertFalse(isParallelInstructionPlan(nonDivisibleInstruction))

        try Self.assertSolanaError(
            assertIsSingleInstructionPlan(parallelInstruction),
            code: .instructionPlansUnexpectedInstructionPlan,
            context: ["actualKind": .string("parallel"), "expectedKind": .string("single")]
        )
        try Self.assertSolanaError(
            assertIsSequentialInstructionPlan(messagePacker),
            code: .instructionPlansUnexpectedInstructionPlan,
            context: ["actualKind": .string("messagePacker"), "expectedKind": .string("sequential")]
        )
        try Self.assertSolanaError(
            assertIsParallelInstructionPlan(singleInstruction),
            code: .instructionPlansUnexpectedInstructionPlan,
            context: ["actualKind": .string("single"), "expectedKind": .string("parallel")]
        )

        let singleTransaction = singleTransactionPlan(try Self.makeMessage("A"))
        let sequentialTransaction = sequentialTransactionPlan([TransactionPlan]())
        let nonDivisibleTransaction = nonDivisibleSequentialTransactionPlan([TransactionPlan]())
        let parallelTransaction = parallelTransactionPlan([TransactionPlan]())

        XCTAssertFalse(isSingleTransactionPlan(parallelTransaction))
        XCTAssertFalse(isNonDivisibleSequentialTransactionPlan(sequentialTransaction))
        XCTAssertFalse(isParallelTransactionPlan(nonDivisibleTransaction))

        try Self.assertSolanaError(
            assertIsSequentialTransactionPlan(singleTransaction),
            code: .instructionPlansUnexpectedTransactionPlan,
            context: ["actualKind": .string("single"), "expectedKind": .string("sequential")]
        )
        try Self.assertSolanaError(
            assertIsNonDivisibleSequentialTransactionPlan(sequentialTransaction),
            code: .instructionPlansUnexpectedTransactionPlan,
            context: ["actualKind": .string("divisible sequential"), "expectedKind": .string("non-divisible sequential")]
        )
        try Self.assertSolanaError(
            assertIsParallelTransactionPlan(singleTransaction),
            code: .instructionPlansUnexpectedTransactionPlan,
            context: ["actualKind": .string("single"), "expectedKind": .string("parallel")]
        )
    }

    func testTraversalFindsTopDownAndStopsBeforeLaterSiblings() throws {
        let packer = getMessagePackerInstructionPlanFromInstructions([try Self.makeInstruction("D")])
        let instructionPlan = parallelInstructionPlan([
            .plan(sequentialInstructionPlan([try Self.makeInstruction("A")])),
            .plan(nonDivisibleSequentialInstructionPlan([try Self.makeInstruction("B"), try Self.makeInstruction("C")])),
            .plan(packer),
        ])

        XCTAssertEqual(findInstructionPlan(instructionPlan) { $0.kind == "parallel" }?.kind, "parallel")
        XCTAssertNil(findInstructionPlan(parallelInstructionPlan([InstructionPlan]())) { $0.kind == "single" })
        XCTAssertEqual(findInstructionPlan(packer) { isMessagePackerInstructionPlan($0) }?.kind, "messagePacker")

        var instructionVisits: [String] = []
        let allInstructionsMatch = everyInstructionPlan(instructionPlan) { candidate in
            instructionVisits.append(candidate.kind)
            return candidate.kind != "sequential" || instructionVisits.count < 3
        }
        XCTAssertFalse(allInstructionsMatch)
        XCTAssertEqual(instructionVisits, ["parallel", "sequential", "single", "sequential"])

        let transactionPlan = parallelTransactionPlan([
            .plan(sequentialTransactionPlan([try Self.makeMessage("A")])),
            .plan(nonDivisibleSequentialTransactionPlan([try Self.makeMessage("B")])),
            .message(try Self.makeMessage("C")),
        ])
        XCTAssertEqual(findTransactionPlan(transactionPlan) { isNonDivisibleSequentialTransactionPlan($0) }?.kind, "sequential")
        XCTAssertNil(findTransactionPlan(parallelTransactionPlan([TransactionPlan]())) { $0.kind == "single" })

        var transactionVisits: [String] = []
        let allTransactionsMatch = everyTransactionPlan(transactionPlan) { candidate in
            transactionVisits.append(candidate.kind)
            return candidate.kind != "sequential" || transactionVisits.count < 3
        }
        XCTAssertFalse(allTransactionsMatch)
        XCTAssertEqual(transactionVisits, ["parallel", "sequential", "single", "sequential"])
    }

    func testTransformsCanDuplicateFlattenAndPreserveDivisibility() throws {
        let instructionPlan = sequentialInstructionPlan([
            .instruction(try Self.makeInstruction("A")),
            .plan(parallelInstructionPlan([try Self.makeInstruction("B"), try Self.makeInstruction("C")])),
        ])
        let flattenedInstructions = transformInstructionPlan(instructionPlan) { candidate in
            guard case let .parallel(parallel) = candidate else {
                return candidate
            }
            return sequentialInstructionPlan(parallel.plans)
        }
        XCTAssertEqual(flattenInstructionPlan(flattenedInstructions).compactMap(Self.instructionID), ["A", "B", "C"])

        let duplicatedInstructions = transformInstructionPlan(sequentialInstructionPlan([try Self.makeInstruction("D")])) { candidate in
            guard case let .single(single) = candidate else {
                return candidate
            }
            return sequentialInstructionPlan([single.instruction, single.instruction])
        }
        XCTAssertEqual(flattenInstructionPlan(duplicatedInstructions).compactMap(Self.instructionID), ["D", "D"])

        let transactionPlan = nonDivisibleSequentialTransactionPlan([
            .message(try Self.makeMessage("A")),
            .plan(parallelTransactionPlan([try Self.makeMessage("B"), try Self.makeMessage("C")])),
        ])
        let flattenedTransactions = transformTransactionPlan(transactionPlan) { candidate in
            guard case let .parallel(parallel) = candidate else {
                return candidate
            }
            return sequentialTransactionPlan(parallel.plans)
        }
        guard case let .sequential(transformed) = flattenedTransactions else {
            return XCTFail("Expected a sequential transaction plan")
        }
        XCTAssertFalse(transformed.divisible)
        XCTAssertEqual(flattenTransactionPlan(flattenedTransactions).map { Self.messageIDs($0.message).joined() }, ["A", "B", "C"])
    }

    func testAppendInstructionPlanHandlesEmptyPlansPackersAndCapacityFailures() throws {
        let base = try Self.makeMessage("base")
        XCTAssertEqual(try appendTransactionMessageInstructionPlan(sequentialInstructionPlan([InstructionPlan]()), base), base)
        XCTAssertEqual(try appendTransactionMessageInstructionPlan(parallelInstructionPlan([InstructionPlan]()), base), base)

        let packer = getMessagePackerInstructionPlanFromInstructions([
            try Self.makeInstruction("B"),
            try Self.makeInstruction("C"),
        ])
        let combined = sequentialInstructionPlan([
            .instruction(try Self.makeInstruction("A")),
            .plan(parallelInstructionPlan([try Self.makeInstruction("P")])),
            .plan(packer),
        ])
        let appended = try appendTransactionMessageInstructionPlan(combined, base)
        XCTAssertEqual(Self.messageIDs(appended), ["base", "A", "P", "B", "C"])

        let tooLarge = getMessagePackerInstructionPlanFromInstructions([
            try Self.makeInstruction("large", dataSize: 50_000),
        ])
        try Self.assertSolanaError(
            appendTransactionMessageInstructionPlan(tooLarge, try Self.makeMessage()),
            code: .instructionPlansMessageCannotAccommodatePlan
        )
    }

    func testMessagePackersUseBoundedChunksAndCompletionErrors() throws {
        let emptyLinear = getLinearMessagePackerInstructionPlan(totalLength: 0) { offset, length in
            try! Self.makeInstruction("\(offset):\(length)")
        }
        guard case let .messagePacker(emptyLinearPlan) = emptyLinear else {
            return XCTFail("Expected a message packer")
        }
        let emptyPacker = emptyLinearPlan.getMessagePacker()
        XCTAssertTrue(emptyPacker.done())
        try Self.assertSolanaError(
            emptyPacker.packMessageToCapacity(try Self.makeMessage()),
            code: .instructionPlansMessagePackerAlreadyComplete
        )

        let realloc = getReallocMessagePackerInstructionPlan(totalSize: 20_500) { size in
            try! Self.makeInstruction("size:\(size)")
        }
        guard case let .messagePacker(reallocPlan) = realloc else {
            return XCTFail("Expected a message packer")
        }
        let reallocPacker = reallocPlan.getMessagePacker()
        let packed = try reallocPacker.packMessageToCapacity(try Self.makeMessage())
        XCTAssertTrue(reallocPacker.done())
        XCTAssertEqual(Self.messageIDs(packed), ["size:10240", "size:10240", "size:20"])
    }

    func testResultTraversalTransformSummaryAndFailureSelectionCoverStatusShapes() throws {
        let successA = successfulSingleTransactionPlanResult(try Self.makeMessage("A"), signature: Signature(rawValue: "sigA"))
        let failedB = failedSingleTransactionPlanResult(try Self.makeMessage("B"), TestFailure("B failed"))
        let canceledC = canceledSingleTransactionPlanResult(try Self.makeMessage("C"))
        let failedD = failedSingleTransactionPlanResult(try Self.makeMessage("D"), TestFailure("D failed"))
        let result = parallelTransactionPlanResult([
            sequentialTransactionPlanResult([successA, failedB]),
            nonDivisibleSequentialTransactionPlanResult([canceledC, failedD]),
        ])

        XCTAssertEqual(flattenTransactionPlanResult(result).map(\.status), ["successful", "failed", "canceled", "failed"])
        XCTAssertEqual(findTransactionPlanResult(result) { isFailedSingleTransactionPlanResult($0) }?.kind, "single")
        XCTAssertNil(findTransactionPlanResult(parallelTransactionPlanResult([])) { isSingleTransactionPlanResult($0) })

        var visits: [String] = []
        let everyResult = everyTransactionPlanResult(result) { candidate in
            visits.append(candidate.kind)
            return !isCanceledSingleTransactionPlanResult(candidate)
        }
        XCTAssertFalse(everyResult)
        XCTAssertEqual(visits, ["parallel", "sequential", "single", "single", "sequential", "single"])

        let transformed = transformTransactionPlanResult(result) { candidate in
            guard case let .single(.canceled(canceled)) = candidate else {
                return candidate
            }
            return failedSingleTransactionPlanResult(canceled.plannedMessage, TestFailure("converted"))
        }
        XCTAssertEqual(flattenTransactionPlanResult(transformed).map(\.status), ["successful", "failed", "failed", "failed"])

        let summary = summarizeTransactionPlanResult(result)
        XCTAssertFalse(summary.successful)
        XCTAssertEqual(summary.successfulTransactions.map { Self.messageIDs($0.plannedMessage).joined() }, ["A"])
        XCTAssertEqual(summary.failedTransactions.map { Self.messageIDs($0.plannedMessage).joined() }, ["B", "D"])
        XCTAssertEqual(summary.canceledTransactions.map { Self.messageIDs($0.plannedMessage).joined() }, ["C"])
        XCTAssertEqual(try getFirstFailedSingleTransactionPlanResult(result).error.message, "B failed")
    }

    private static func assertSolanaError<T>(
        _ expression: @autoclosure () throws -> T,
        code: SolanaErrorCode,
        context: SolanaErrorContext = .empty
    ) throws {
        do {
            _ = try expression()
            XCTFail("Expected a Solana error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, code.rawValue)
            for (key, value) in context.values {
                XCTAssertEqual(error.context[key], value)
            }
        }
    }

    private static func makeInstruction(_ id: String, dataSize: Int = 0) throws -> Instruction {
        let data: Data
        if dataSize > 0 {
            let prefix = Data("\(id)|".utf8)
            data = prefix + Data(repeating: UInt8(ascii: "x"), count: max(0, dataSize - prefix.count))
        } else {
            data = Data(id.utf8)
        }
        return Instruction(
            programAddress: try Address("11111111111111111111111111111111"),
            data: data
        )
    }

    private static func makeMessage(_ id: String? = nil) throws -> TransactionMessage {
        let feePayer = try Address("E9Nykp3rSdza2moQutaJ3K3RSC8E5iFERX2SqLTsQfjJ")
        var message = setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
        if let id {
            message = appendTransactionMessageInstruction(try makeInstruction(id), message)
        }
        return message
    }

    private static func instructionID(_ plan: InstructionPlan) -> String? {
        guard case let .single(single) = plan else {
            return nil
        }
        return String(data: single.instruction.data ?? Data(), encoding: .utf8)
    }

    private static func messageIDs(_ message: TransactionMessage) -> [String] {
        message.instructions.map { instruction in
            let raw = String(data: instruction.data ?? Data(), encoding: .utf8) ?? ""
            return raw.split(separator: "|").first.map(String.init) ?? raw
        }
    }
}

private struct TestFailure: Error, LocalizedError, Sendable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
