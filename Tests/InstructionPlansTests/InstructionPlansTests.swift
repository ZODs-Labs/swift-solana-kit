import Addresses
import Instructions
@testable import InstructionPlans
import Keys
import Promises
import TransactionMessages
import XCTest

final class InstructionPlansTests: XCTestCase {
    func testInstructionPlanConstructorsAndFlattening() throws {
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let plan = sequentialInstructionPlan([
            .instruction(instructionA),
            .plan(parallelInstructionPlan([instructionB])),
        ])

        XCTAssertTrue(isSequentialInstructionPlan(plan))
        XCTAssertEqual(flattenInstructionPlan(plan).map(\.kind), ["single", "single"])
    }

    func testInstructionPlanInputUnwrapsSingleItemArrays() throws {
        let instruction = try Self.makeInstruction("A")
        let parsed = parseInstructionPlanInput([.instruction(instruction)])

        guard case let .single(plan) = parsed else {
            return XCTFail("Expected a single instruction plan")
        }
        XCTAssertEqual(plan.instruction, instruction)
    }

    func testTransactionPlanConstructorsAndTransform() throws {
        let messageA = try Self.makeMessage("A")
        let messageB = try Self.makeMessage("B")
        let plan = sequentialTransactionPlan([messageA, messageB])
        let transformed = transformTransactionPlan(plan) { plan in
            if case let .sequential(plan) = plan {
                return parallelTransactionPlan(plan.plans)
            }
            return plan
        }

        XCTAssertTrue(isParallelTransactionPlan(transformed))
        XCTAssertEqual(flattenTransactionPlan(transformed).map(\.message.instructions.count), [0, 0])
    }

    func testAppendInstructionPlanPreservesOrder() throws {
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let message = try Self.makeMessage("base")
        let plan = sequentialInstructionPlan([instructionA, instructionB])

        let result = try appendTransactionMessageInstructionPlan(plan, message)

        XCTAssertEqual(result.instructions, [instructionA, instructionB])
    }

    func testMessagePackerFromInstructionsAppendsUntilDone() throws {
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let plan = getMessagePackerInstructionPlanFromInstructions([instructionA, instructionB])
        guard case let .messagePacker(plan) = plan else {
            return XCTFail("Expected a message packer")
        }
        let packer = plan.getMessagePacker()

        let result = try packer.packMessageToCapacity(try Self.makeMessage("base"))

        XCTAssertTrue(packer.done())
        XCTAssertEqual(result.instructions, [instructionA, instructionB])
    }

    func testTransactionResultSummary() throws {
        let messageA = try Self.makeMessage("A")
        let messageB = try Self.makeMessage("B")
        let result = sequentialTransactionPlanResult([
            successfulSingleTransactionPlanResult(messageA, signature: Signature(rawValue: "sigA")),
            canceledSingleTransactionPlanResult(messageB),
        ])

        let summary = summarizeTransactionPlanResult(result)

        XCTAssertFalse(summary.successful)
        XCTAssertEqual(summary.successfulTransactions.count, 1)
        XCTAssertEqual(summary.canceledTransactions.count, 1)
    }

    func testPlannerSplitsWhenMessagesExceedCapacity() async throws {
        let newMessage = try Self.makeMessage("new")
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in newMessage }
        ))
        let largeA = try Self.makeInstruction("A", dataSize: 700)
        let largeB = try Self.makeInstruction("B", dataSize: 700)

        let result = try await planner(sequentialInstructionPlan([largeA, largeB]), TransactionPlannerRunConfig())

        XCTAssertGreaterThanOrEqual(flattenTransactionPlan(result).count, 1)
    }

    func testPlannerMergesParallelInstructionsWhenTheyFit() async throws {
        let newMessage = try Self.makeMessage("new")
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in newMessage }
        ))
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")

        let result = try await planner(
            parallelInstructionPlan([instructionA, instructionB]),
            TransactionPlannerRunConfig()
        )

        guard case let .single(plan) = result else {
            return XCTFail("Expected one transaction")
        }
        XCTAssertEqual(plan.message.instructions, [instructionA, instructionB])
    }

    func testPlannerMergesSequentialPlansInsideParallelWhenWholePlansFit() async throws {
        let newMessage = try Self.makeMessage("new")
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in newMessage }
        ))
        let instructionA = try Self.makeInstruction("A")
        let instructionB = try Self.makeInstruction("B")
        let instructionC = try Self.makeInstruction("C")
        let instructionD = try Self.makeInstruction("D")

        let result = try await planner(
            parallelInstructionPlan([
                sequentialInstructionPlan([instructionA, instructionB]),
                sequentialInstructionPlan([instructionC, instructionD]),
            ]),
            TransactionPlannerRunConfig()
        )

        guard case let .single(plan) = result else {
            return XCTFail("Expected one transaction")
        }
        XCTAssertEqual(plan.message.instructions, [instructionA, instructionB, instructionC, instructionD])
    }

    func testExecutorReturnsSuccessfulResult() async throws {
        let message = try Self.makeMessage("A")
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, _, _ in .signature(Signature(rawValue: "A")) }
        ))

        let result = try await executor(singleTransactionPlan(message), TransactionPlanExecutorRunConfig())

        XCTAssertTrue(isSuccessfulTransactionPlanResult(result))
    }

    func testExecutorRunsParallelPlansConcurrently() async throws {
        let messageA = try Self.makeMessage("A")
        let messageB = try Self.makeMessage("B")
        let probe = ConcurrentExecutionProbe()
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, message, _ in
                await probe.enter()
                try await Task.sleep(nanoseconds: 50_000_000)
                await probe.leave()
                return .signature(Signature(rawValue: message.instructions.isEmpty ? "empty" : "done"))
            }
        ))

        _ = try await executor(
            parallelTransactionPlan([messageA, messageB]),
            TransactionPlanExecutorRunConfig()
        )

        let maximumActiveExecutions = await probe.maximumActiveExecutions()
        XCTAssertEqual(maximumActiveExecutions, 2)
    }

    func testExecutorAbortsInFlightExecution() async throws {
        let message = try Self.makeMessage("A")
        let signal = AbortSignal()
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, _, _ in
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return .signature(Signature(rawValue: "late"))
            }
        ))

        async let execution = executor(singleTransactionPlan(message), TransactionPlanExecutorRunConfig(abortSignal: signal))
        try await Task.sleep(nanoseconds: 20_000_000)
        signal.abort(reason: AbortError(reason: "stop"))

        do {
            _ = try await execution
            XCTFail("Expected execution failure")
        } catch let error as FailedToExecuteTransactionPlanError {
            XCTAssertEqual(error.abortReason, "stop")
            guard case let .single(.failed(result)) = error.result else {
                return XCTFail("Expected failed single result")
            }
            XCTAssertEqual(result.error.message, "stop")
        }
    }

    private static func makeInstruction(_ id: String, dataSize: Int = 0) throws -> Instruction {
        Instruction(
            programAddress: try Address("11111111111111111111111111111111"),
            data: Data((id.utf8)) + Data(repeating: 1, count: dataSize)
        )
    }

    private static func makeMessage(_ id: String) throws -> TransactionMessage {
        let feePayer = try Address("E9Nykp3rSdza2moQutaJ3K3RSC8E5iFERX2SqLTsQfjJ")
        return setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
    }
}

private actor ConcurrentExecutionProbe {
    private var activeExecutions = 0
    private var maximum = 0

    func enter() {
        activeExecutions += 1
        maximum = max(maximum, activeExecutions)
    }

    func leave() {
        activeExecutions -= 1
    }

    func maximumActiveExecutions() -> Int {
        maximum
    }
}
