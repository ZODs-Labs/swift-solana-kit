import Addresses
import Foundation
import Instructions
@testable import InstructionPlans
import Promises
import SolanaErrors
import TransactionMessages
import XCTest

final class TransactionPlannerBehaviorTests: XCTestCase {
    func testPlannerReportsEmptyInstructionPlans() async throws {
        let recorder = PlannerRecorder()
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { config in
                await recorder.recordCreate(aborted: config.abortSignal?.aborted ?? false)
                return try Self.makeMessage()
            }
        ))

        do {
            _ = try await planner(sequentialInstructionPlan([InstructionPlan]()), TransactionPlannerRunConfig())
            XCTFail("Expected planner failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.instructionPlansEmptyInstructionPlan.rawValue)
        }
        let createCount = await recorder.createCount()
        XCTAssertEqual(createCount, 0)
    }

    func testPlannerPassesAbortSignalAndRunsUpdateForEachCandidateMutation() async throws {
        let signal = AbortSignal()
        let recorder = PlannerRecorder()
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { config in
                await recorder.recordCreate(aborted: config.abortSignal === signal)
                return try Self.makeMessage()
            },
            onTransactionMessageUpdated: { message, config in
                await recorder.recordUpdate(ids: Self.messageIDs(message), aborted: config.abortSignal === signal)
                return message
            }
        ))

        let result = try await planner(
            sequentialInstructionPlan([try Self.makeInstruction("A"), try Self.makeInstruction("B")]),
            TransactionPlannerRunConfig(abortSignal: signal)
        )

        let createCount = await recorder.createCount()
        let createFlags = await recorder.createAbortFlags()
        let updateIDs = await recorder.updateIDs()
        let updateFlags = await recorder.updateAbortFlags()
        XCTAssertEqual(createCount, 1)
        XCTAssertEqual(createFlags, [true])
        XCTAssertEqual(updateIDs, [["A"], ["A", "B"]])
        XCTAssertEqual(updateFlags, [true, true])
        XCTAssertEqual(flattenTransactionPlan(result).map { Self.messageIDs($0.message) }, [["A", "B"]])
    }

    func testPlannerStopsBeforeWorkWhenSignalIsAlreadyAborted() async throws {
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let recorder = PlannerRecorder()
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in
                await recorder.recordCreate(aborted: false)
                return try Self.makeMessage()
            }
        ))

        do {
            _ = try await planner(singleInstructionPlan(try Self.makeInstruction("A")), TransactionPlannerRunConfig(abortSignal: signal))
            XCTFail("Expected planner failure")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "stop")
        }
        let createCount = await recorder.createCount()
        XCTAssertEqual(createCount, 0)
    }

    func testPlannerThrowsCapacityErrorWhenInstructionCannotFitEmptyMessage() async throws {
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in try Self.makeMessage() }
        ))

        do {
            _ = try await planner(singleInstructionPlan(try Self.makeInstruction("large", dataSize: 50_000)), TransactionPlannerRunConfig())
            XCTFail("Expected planner failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.instructionPlansMessageCannotAccommodatePlan.rawValue)
            XCTAssertNotNil(error.context["numBytesRequired"])
            XCTAssertNotNil(error.context["numFreeBytes"])
        }
    }

    func testPlannerSplitsSequentialInstructionsIntoExactMessageOrder() async throws {
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in try Self.makeMessage() }
        ))
        let result = try await planner(
            sequentialInstructionPlan([
                try Self.makeInstruction("A", dataSize: 700),
                try Self.makeInstruction("B", dataSize: 700),
                try Self.makeInstruction("C"),
            ]),
            TransactionPlannerRunConfig()
        )

        XCTAssertEqual(flattenTransactionPlan(result).map { Self.messageIDs($0.message) }, [["A"], ["B", "C"]])
    }

    func testPlannerMergesMessagePackerInstructionsIntoAvailableParallelCandidate() async throws {
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in try Self.makeMessage() }
        ))
        let packer = getMessagePackerInstructionPlanFromInstructions([
            try Self.makeInstruction("B"),
            try Self.makeInstruction("C"),
        ])

        let result = try await planner(
            parallelInstructionPlan([
                .instruction(try Self.makeInstruction("A")),
                .plan(packer),
            ]),
            TransactionPlannerRunConfig()
        )

        XCTAssertEqual(flattenTransactionPlan(result).map { Self.messageIDs($0.message) }, [["A", "B", "C"]])
    }

    func testPlannerKeepsParallelBranchesSeparateWhenTheyDoNotFitTogether() async throws {
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in try Self.makeMessage() }
        ))

        let result = try await planner(
            parallelInstructionPlan([
                try Self.makeInstruction("A", dataSize: 700),
                try Self.makeInstruction("B", dataSize: 700),
            ]),
            TransactionPlannerRunConfig()
        )

        XCTAssertEqual(flattenTransactionPlan(result).map { Self.messageIDs($0.message) }, [["A"], ["B"]])
        XCTAssertTrue(isParallelTransactionPlan(result))
    }

    func testPlannerSimplifiesSingleChildSequentialAndParallelPlans() async throws {
        let planner = createTransactionPlanner(TransactionPlannerConfig(
            createTransactionMessage: { _ in try Self.makeMessage() }
        ))

        let sequential = try await planner(
            sequentialInstructionPlan([.plan(sequentialInstructionPlan([try Self.makeInstruction("A")]))]),
            TransactionPlannerRunConfig()
        )
        XCTAssertTrue(isSingleTransactionPlan(sequential))
        XCTAssertEqual(flattenTransactionPlan(sequential).map { Self.messageIDs($0.message) }, [["A"]])

        let parallel = try await planner(
            parallelInstructionPlan([.plan(parallelInstructionPlan([try Self.makeInstruction("B")]))]),
            TransactionPlannerRunConfig()
        )
        XCTAssertTrue(isSingleTransactionPlan(parallel))
        XCTAssertEqual(flattenTransactionPlan(parallel).map { Self.messageIDs($0.message) }, [["B"]])
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

    private static func makeMessage() throws -> TransactionMessage {
        let feePayer = try Address("E9Nykp3rSdza2moQutaJ3K3RSC8E5iFERX2SqLTsQfjJ")
        return setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
    }

    private static func messageIDs(_ message: TransactionMessage) -> [String] {
        message.instructions.map { instruction in
            guard let data = instruction.data else {
                return ""
            }
            let raw = String(data: data, encoding: .utf8) ?? ""
            return raw.split(separator: "|").first.map(String.init) ?? raw
        }
    }
}

private actor PlannerRecorder {
    private var creates: [Bool] = []
    private var updates: [[String]] = []
    private var updateFlags: [Bool] = []

    func recordCreate(aborted: Bool) {
        creates.append(aborted)
    }

    func recordUpdate(ids: [String], aborted: Bool) {
        updates.append(ids)
        updateFlags.append(aborted)
    }

    func createCount() -> Int {
        creates.count
    }

    func createAbortFlags() -> [Bool] {
        creates
    }

    func updateIDs() -> [[String]] {
        updates
    }

    func updateAbortFlags() -> [Bool] {
        updateFlags
    }
}
