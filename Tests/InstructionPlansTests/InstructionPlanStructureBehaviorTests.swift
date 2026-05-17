import Addresses
import Foundation
import Instructions
@testable import InstructionPlans
import Keys
import SolanaErrors
import TransactionMessages
import XCTest

final class InstructionPlanStructureBehaviorTests: XCTestCase {
    func testInstructionConstructorsPreserveShapeAndWrapRawInstructions() throws {
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let nested = parallelInstructionPlan([instructionB])

        let single = singleInstructionPlan(instructionA)
        XCTAssertEqual(single.kind, "single")
        XCTAssertEqual(single.planType, "instructionPlan")

        let parallel = parallelInstructionPlan([
            .instruction(instructionA),
            .plan(nested),
        ])
        guard case let .parallel(parallelPlan) = parallel else {
            return XCTFail("Expected a parallel plan")
        }
        XCTAssertEqual(parallelPlan.kind, "parallel")
        XCTAssertEqual(parallelPlan.planType, "instructionPlan")
        XCTAssertEqual(parallelPlan.plans.map(\.kind), ["single", "parallel"])

        let sequential = sequentialInstructionPlan([
            .instruction(instructionA),
            .plan(nested),
        ])
        guard case let .sequential(sequentialPlan) = sequential else {
            return XCTFail("Expected a sequential plan")
        }
        XCTAssertTrue(sequentialPlan.divisible)
        XCTAssertEqual(sequentialPlan.planType, "instructionPlan")
        XCTAssertEqual(sequentialPlan.plans.map(\.kind), ["single", "parallel"])

        let nonDivisible = nonDivisibleSequentialInstructionPlan([
            .instruction(instructionA),
            .plan(nested),
        ])
        guard case let .sequential(nonDivisiblePlan) = nonDivisible else {
            return XCTFail("Expected a sequential plan")
        }
        XCTAssertFalse(nonDivisiblePlan.divisible)
        XCTAssertEqual(nonDivisiblePlan.plans.map(\.kind), ["single", "parallel"])
    }

    func testInstructionInputParsingUnwrapsSingleItemsAndSequencesMultipleItems() throws {
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let nested = parallelInstructionPlan([instructionB])

        XCTAssertTrue(isSingleInstructionPlan(parseInstructionPlanInput(.instruction(instructionA))))
        XCTAssertTrue(isSingleInstructionPlan(parseInstructionPlanInput([.instruction(instructionA)])))

        let parsedPlan = parseInstructionPlanInput(.plan(nested))
        guard case .parallel = parsedPlan else {
            return XCTFail("Expected the provided plan")
        }

        let empty = parseInstructionPlanInput([])
        guard case let .sequential(emptyPlan) = empty else {
            return XCTFail("Expected an empty sequential plan")
        }
        XCTAssertTrue(emptyPlan.divisible)
        XCTAssertTrue(emptyPlan.plans.isEmpty)

        let mixed = parseInstructionPlanInput([
            .instruction(instructionA),
            .plan(nested),
        ])
        guard case let .sequential(mixedPlan) = mixed else {
            return XCTFail("Expected a sequential plan")
        }
        XCTAssertEqual(mixedPlan.plans.map(\.kind), ["single", "parallel"])
    }

    func testInstructionPlanPredicatesAndAssertionsUseExactKinds() throws {
        let single = singleInstructionPlan(try Self.makeInstruction("A"))
        let packer = getMessagePackerInstructionPlanFromInstructions([])
        let sequential = sequentialInstructionPlan([InstructionPlan]())
        let nonDivisible = nonDivisibleSequentialInstructionPlan([InstructionPlan]())
        let parallel = parallelInstructionPlan([InstructionPlan]())

        XCTAssertTrue(isInstructionPlan(single))
        XCTAssertFalse(isInstructionPlan("single"))
        XCTAssertTrue(isSingleInstructionPlan(single))
        XCTAssertFalse(isSingleInstructionPlan(packer))
        XCTAssertTrue(isMessagePackerInstructionPlan(packer))
        XCTAssertFalse(isMessagePackerInstructionPlan(single))
        XCTAssertTrue(isSequentialInstructionPlan(sequential))
        XCTAssertTrue(isSequentialInstructionPlan(nonDivisible))
        XCTAssertTrue(isNonDivisibleSequentialInstructionPlan(nonDivisible))
        XCTAssertFalse(isNonDivisibleSequentialInstructionPlan(sequential))
        XCTAssertTrue(isParallelInstructionPlan(parallel))

        try assertIsSingleInstructionPlan(single)
        try assertIsMessagePackerInstructionPlan(packer)
        try assertIsSequentialInstructionPlan(sequential)
        try assertIsNonDivisibleSequentialInstructionPlan(nonDivisible)
        try assertIsParallelInstructionPlan(parallel)

        try Self.assertSolanaError(
            assertIsSingleInstructionPlan(parallel),
            code: .instructionPlansUnexpectedInstructionPlan,
            context: ["actualKind": .string("parallel"), "expectedKind": .string("single")]
        )
        try Self.assertSolanaError(
            assertIsMessagePackerInstructionPlan(single),
            code: .instructionPlansUnexpectedInstructionPlan,
            context: ["actualKind": .string("single"), "expectedKind": .string("messagePacker")]
        )
        try Self.assertSolanaError(
            assertIsNonDivisibleSequentialInstructionPlan(sequential),
            code: .instructionPlansUnexpectedInstructionPlan,
            context: ["actualKind": .string("divisible sequential"), "expectedKind": .string("non-divisible sequential")]
        )
    }

    func testInstructionPlanSearchTraversalAndFlatteningAreDepthFirst() throws {
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let instructionC = try Self.makeInstruction("C")
        let packer = getMessagePackerInstructionPlanFromInstructions([try Self.makeInstruction("D")])
        let nonDivisible = nonDivisibleSequentialInstructionPlan([instructionB, instructionC])
        let plan = parallelInstructionPlan([
            .plan(sequentialInstructionPlan([instructionA])),
            .plan(nonDivisible),
            .plan(packer),
        ])

        let foundRoot = findInstructionPlan(plan) { $0.kind == "parallel" }
        XCTAssertEqual(foundRoot?.kind, "parallel")

        let foundNonDivisible = findInstructionPlan(plan) { candidate in
            isNonDivisibleSequentialInstructionPlan(candidate)
        }
        XCTAssertEqual(foundNonDivisible?.kind, "sequential")

        var visited: [String] = []
        let everyResult = everyInstructionPlan(plan) { candidate in
            visited.append(candidate.kind)
            return candidate.kind != "messagePacker"
        }
        XCTAssertFalse(everyResult)
        XCTAssertEqual(visited, ["parallel", "sequential", "single", "sequential", "single", "single", "messagePacker"])

        let leaves = flattenInstructionPlan(plan)
        XCTAssertEqual(leaves.map(\.kind), ["single", "single", "single", "messagePacker"])
    }

    func testInstructionPlanTransformRunsBottomUpAndKeepsReturnedShapes() throws {
        let plan = sequentialInstructionPlan([
            .instruction(try Self.makeInstruction("A")),
            .plan(sequentialInstructionPlan([
                try Self.makeInstruction("B"),
                try Self.makeInstruction("C"),
            ])),
        ])
        var seen: [String] = []

        let transformed = try transformInstructionPlan(plan) { candidate in
            switch candidate {
            case let .single(single):
                let id = Self.dataString(single.instruction)
                return singleInstructionPlan(try Self.makeInstruction("New \(id)"))
            case let .sequential(sequential):
                let ids = sequential.plans.compactMap { child -> String? in
                    guard case let .single(single) = child else {
                        return nil
                    }
                    return Self.dataString(single.instruction)
                }
                seen.append(contentsOf: ids)
                return .sequential(sequential)
            case .parallel, .messagePacker:
                return candidate
            }
        }

        XCTAssertEqual(seen, ["New B", "New C", "New A"])
        XCTAssertEqual(
            flattenInstructionPlan(transformed).compactMap(Self.singleInstructionData),
            ["New A", "New B", "New C"]
        )

        let duplicated = transformInstructionPlan(
            sequentialInstructionPlan([try Self.makeInstruction("A"), try Self.makeInstruction("B")])
        ) { candidate in
            guard case let .single(single) = candidate else {
                return candidate
            }
            return sequentialInstructionPlan([single.instruction, single.instruction])
        }
        XCTAssertEqual(
            flattenInstructionPlan(duplicated).compactMap(Self.singleInstructionData),
            ["A", "A", "B", "B"]
        )
    }

    func testMessagePackersAdvanceStateAndReportCompletion() throws {
        let message = try Self.makeMessage()
        let linear = getLinearMessagePackerInstructionPlan(totalLength: 2_000) { offset, length in
            try! Self.makeSizedInstruction(offset: offset, length: length)
        }
        guard case let .messagePacker(linearPlan) = linear else {
            return XCTFail("Expected a message packer")
        }
        let linearPacker = linearPlan.getMessagePacker()
        var totalLength = 0
        var previousOffset = 0
        while !linearPacker.done() {
            let linearMessage = try linearPacker.packMessageToCapacity(message)
            guard let instruction = linearMessage.instructions.last, let data = instruction.data else {
                return XCTFail("Expected instruction data")
            }
            totalLength += data.count
            let prefix = try XCTUnwrap(Self.dataString(instruction).split(separator: "|").first)
            let parts = prefix.split(separator: ":").compactMap { Int($0) }
            XCTAssertEqual(parts.count, 2)
            XCTAssertEqual(parts[0], previousOffset)
            previousOffset += parts[1]
        }
        XCTAssertEqual(totalLength, 2_000)
        XCTAssertEqual(previousOffset, 2_000)

        try Self.assertSolanaError(
            linearPacker.packMessageToCapacity(message),
            code: .instructionPlansMessagePackerAlreadyComplete
        )

        let realloc = getReallocMessagePackerInstructionPlan(totalSize: 15_000) { size in
            try! Self.makeInstruction("Size: \(size)")
        }
        guard case let .messagePacker(reallocPlan) = realloc else {
            return XCTFail("Expected a message packer")
        }
        let reallocPacker = reallocPlan.getMessagePacker()
        let reallocMessage = try reallocPacker.packMessageToCapacity(message)
        XCTAssertTrue(reallocPacker.done())
        XCTAssertEqual(reallocMessage.instructions.map(Self.dataString), ["Size: 10240", "Size: 4760"])
    }

    func testMessagePackerFromInstructionsRollsBackWhenFirstInstructionCannotFit() throws {
        let message = try Self.makeMessage()
        let plan = getMessagePackerInstructionPlanFromInstructions([
            try Self.makeInstruction("large", dataSize: 50_000),
        ])
        guard case let .messagePacker(plan) = plan else {
            return XCTFail("Expected a message packer")
        }

        let packer = plan.getMessagePacker()
        try Self.assertSolanaError(
            packer.packMessageToCapacity(message),
            code: .instructionPlansMessageCannotAccommodatePlan
        )
        XCTAssertFalse(packer.done())
    }

    func testAppendInstructionPlanPreservesExistingInstructionsAndLeafOrder() throws {
        let existing = try Self.makeInstruction("existing")
        let message = appendTransactionMessageInstruction(existing, try Self.makeMessage())
        let plan = sequentialInstructionPlan([
            .instruction(try Self.makeInstruction("A")),
            .plan(parallelInstructionPlan([
                try Self.makeInstruction("B"),
                try Self.makeInstruction("C"),
            ])),
            .plan(getMessagePackerInstructionPlanFromInstructions([
                try Self.makeInstruction("D"),
                try Self.makeInstruction("E"),
            ])),
        ])

        let result = try appendTransactionMessageInstructionPlan(plan, message)

        XCTAssertEqual(result.instructions.map(Self.dataString), ["existing", "A", "B", "C", "D", "E"])
    }

    func testTransactionConstructorsParsingAndFlatteningMirrorInstructionPlanShape() throws {
        let messageA = try Self.makeMessage("A")
        let messageB = try Self.makeMessage("B")
        let messageC = try Self.makeMessage("C")
        let nested = parallelTransactionPlan([messageB, messageC])

        let single = singleTransactionPlan(messageA)
        XCTAssertEqual(single.kind, "single")
        XCTAssertEqual(single.planType, "transactionPlan")

        let parallel = parallelTransactionPlan([
            .message(messageA),
            .plan(nested),
        ])
        guard case let .parallel(parallelPlan) = parallel else {
            return XCTFail("Expected a parallel transaction plan")
        }
        XCTAssertEqual(parallelPlan.plans.map(\.kind), ["single", "parallel"])

        let sequential = sequentialTransactionPlan([
            .message(messageA),
            .plan(nested),
        ])
        guard case let .sequential(sequentialPlan) = sequential else {
            return XCTFail("Expected a sequential transaction plan")
        }
        XCTAssertTrue(sequentialPlan.divisible)

        let nonDivisible = nonDivisibleSequentialTransactionPlan([
            .message(messageA),
            .plan(nested),
        ])
        XCTAssertTrue(isNonDivisibleSequentialTransactionPlan(nonDivisible))

        XCTAssertTrue(isSingleTransactionPlan(parseTransactionPlanInput([.message(messageA)])))
        let empty = parseTransactionPlanInput([])
        guard case let .sequential(emptyPlan) = empty else {
            return XCTFail("Expected an empty sequential transaction plan")
        }
        XCTAssertTrue(emptyPlan.plans.isEmpty)

        XCTAssertEqual(flattenTransactionPlan(parallel).map(Self.messageInstructionData), ["A", "B", "C"])
    }

    func testTransactionPlanPredicatesAssertionsAndTraversalUseExactKinds() throws {
        let single = singleTransactionPlan(try Self.makeMessage("A"))
        let sequential = sequentialTransactionPlan([TransactionPlan]())
        let nonDivisible = nonDivisibleSequentialTransactionPlan([TransactionPlan]())
        let parallel = parallelTransactionPlan([TransactionPlan]())

        XCTAssertTrue(isTransactionPlan(single))
        XCTAssertFalse(isTransactionPlan("single"))
        XCTAssertTrue(isSingleTransactionPlan(single))
        XCTAssertTrue(isSequentialTransactionPlan(sequential))
        XCTAssertTrue(isSequentialTransactionPlan(nonDivisible))
        XCTAssertTrue(isNonDivisibleSequentialTransactionPlan(nonDivisible))
        XCTAssertTrue(isParallelTransactionPlan(parallel))

        try assertIsSingleTransactionPlan(single)
        try assertIsSequentialTransactionPlan(sequential)
        try assertIsNonDivisibleSequentialTransactionPlan(nonDivisible)
        try assertIsParallelTransactionPlan(parallel)

        try Self.assertSolanaError(
            assertIsSingleTransactionPlan(parallel),
            code: .instructionPlansUnexpectedTransactionPlan,
            context: ["actualKind": .string("parallel"), "expectedKind": .string("single")]
        )
        try Self.assertSolanaError(
            assertIsNonDivisibleSequentialTransactionPlan(sequential),
            code: .instructionPlansUnexpectedTransactionPlan,
            context: ["actualKind": .string("divisible sequential"), "expectedKind": .string("non-divisible sequential")]
        )

        let plan = sequentialTransactionPlan([
            .message(try Self.makeMessage("A")),
            .plan(parallelTransactionPlan([try Self.makeMessage("B"), try Self.makeMessage("C")])),
        ])
        let found = findTransactionPlan(plan) { $0.kind == "parallel" }
        XCTAssertEqual(found?.kind, "parallel")

        var visited: [String] = []
        let everyResult = everyTransactionPlan(plan) { candidate in
            visited.append(candidate.kind)
            return candidate.kind != "parallel"
        }
        XCTAssertFalse(everyResult)
        XCTAssertEqual(visited, ["sequential", "single", "parallel"])
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
        let payload = dataSize > 0 ? Data(repeating: UInt8(id.utf8.first ?? 0), count: dataSize) : Data(id.utf8)
        return Instruction(
            programAddress: try Address("11111111111111111111111111111111"),
            data: payload
        )
    }

    private static func makeSizedInstruction(offset: Int, length: Int) throws -> Instruction {
        let prefix = Data("\(offset):\(length)|".utf8)
        let payload = length > prefix.count
            ? prefix + Data(repeating: UInt8(ascii: "x"), count: length - prefix.count)
            : Data(repeating: UInt8(ascii: "x"), count: length)
        return Instruction(
            programAddress: try Address("11111111111111111111111111111111"),
            data: payload
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

    private static func dataString(_ instruction: Instruction) -> String {
        String(data: instruction.data ?? Data(), encoding: .utf8) ?? ""
    }

    private static func singleInstructionData(_ plan: InstructionPlan) -> String? {
        guard case let .single(single) = plan else {
            return nil
        }
        return dataString(single.instruction)
    }

    private static func messageInstructionData(_ plan: SingleTransactionPlan) -> String {
        dataString(plan.message.instructions[0])
    }
}
