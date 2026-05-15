import Addresses
import InstructionPlans
import Instructions
import PluginInterfaces
import ProgramClientCore
import Promises
import TransactionMessages
import XCTest

final class SelfPlanAndSendTests: XCTestCase {
    func testSynchronousInstructionDelegatesPlanningAndSendingWithOriginalInput() async throws {
        let recorder = SelfPlanAndSendCallRecorder()
        let client = RecordingTransactionClient(recorder: recorder)
        let instruction = try makeInstruction()
        let item = addSelfPlanAndSendFunctions(client: client, input: instruction)
        let config = PluginTransactionConfig(abortSignal: AbortSignal())

        _ = try await item.planTransaction(config: config)
        _ = try await item.planTransactions(config: config)
        _ = try await item.sendTransaction(config: config)
        _ = try await item.sendTransactions(config: config)

        guard case let .instruction(plannedInstruction)? = await recorder.lastPlanTransactionInput() else {
            return XCTFail("Expected raw instruction planTransaction input")
        }
        XCTAssertEqual(plannedInstruction, instruction)

        guard case let .instruction(plannedTransactionsInstruction)? = await recorder.lastPlanTransactionsInput() else {
            return XCTFail("Expected raw instruction planTransactions input")
        }
        XCTAssertEqual(plannedTransactionsInstruction, instruction)

        guard case let .instruction(sentInstruction)? = await recorder.lastSendTransactionInput() else {
            return XCTFail("Expected raw instruction sendTransaction input")
        }
        XCTAssertEqual(sentInstruction, instruction)

        guard case let .instruction(sentTransactionsInstruction)? = await recorder.lastSendTransactionsInput() else {
            return XCTFail("Expected raw instruction sendTransactions input")
        }
        XCTAssertEqual(sentTransactionsInstruction, instruction)
        let planTransactionConfig = await recorder.lastPlanTransactionConfig()
        XCTAssertEqual(planTransactionConfig, config)
    }

    func testSynchronousInstructionPlanDelegatesSendWithOriginalPlan() async throws {
        let recorder = SelfPlanAndSendCallRecorder()
        let client = RecordingTransactionClient(recorder: recorder)
        let instruction = try makeInstruction()
        let plan = singleInstructionPlan(instruction)
        let item = addSelfPlanAndSendFunctions(client: client, input: plan)

        _ = try await item.sendTransaction()
        _ = try await item.sendTransactions()

        guard case let .instructionPlan(singleSendPlan)? = await recorder.lastSendTransactionInput() else {
            return XCTFail("Expected raw instruction plan sendTransaction input")
        }
        assertSinglePlan(singleSendPlan, contains: instruction)

        guard case let .instructionPlan(multiSendPlan)? = await recorder.lastSendTransactionsInput() else {
            return XCTFail("Expected raw instruction plan sendTransactions input")
        }
        assertSinglePlan(multiSendPlan, contains: instruction)
    }

    func testAsyncInstructionDelegatesResolvedOriginalInput() async throws {
        let recorder = SelfPlanAndSendCallRecorder()
        let client = RecordingTransactionClient(recorder: recorder)
        let instruction = try makeInstruction()
        let item = addSelfPlanAndSendFunctions(client: client, input: { instruction })

        _ = try await item.sendTransaction()
        _ = try await item.sendTransactions()

        guard case let .instruction(sentInstruction)? = await recorder.lastSendTransactionInput() else {
            return XCTFail("Expected resolved instruction sendTransaction input")
        }
        XCTAssertEqual(sentInstruction, instruction)

        guard case let .instruction(sentTransactionsInstruction)? = await recorder.lastSendTransactionsInput() else {
            return XCTFail("Expected resolved instruction sendTransactions input")
        }
        XCTAssertEqual(sentTransactionsInstruction, instruction)
    }

    func testAsyncInstructionPlanDelegatesResolvedOriginalPlan() async throws {
        let recorder = SelfPlanAndSendCallRecorder()
        let client = RecordingTransactionClient(recorder: recorder)
        let instruction = try makeInstruction()
        let plan = singleInstructionPlan(instruction)
        let item = addSelfPlanAndSendFunctions(client: client, input: { plan })

        _ = try await item.sendTransaction()

        guard case let .instructionPlan(sentPlan)? = await recorder.lastSendTransactionInput() else {
            return XCTFail("Expected resolved instruction plan sendTransaction input")
        }
        assertSinglePlan(sentPlan, contains: instruction)
    }
}

private actor SelfPlanAndSendCallRecorder {
    private var planTransactionInputs: [InstructionPlanInput] = []
    private var planTransactionConfigs: [PluginTransactionConfig?] = []
    private var planTransactionsInputs: [InstructionPlanInput] = []
    private var sendTransactionInputs: [PluginInterfaces.SingleTransactionPlanInput] = []
    private var sendTransactionsInputs: [PluginInterfaces.TransactionPlanInput] = []

    func recordPlanTransaction(_ input: InstructionPlanInput, config: PluginTransactionConfig?) {
        planTransactionInputs.append(input)
        planTransactionConfigs.append(config)
    }

    func recordPlanTransactions(_ input: InstructionPlanInput) {
        planTransactionsInputs.append(input)
    }

    func recordSendTransaction(_ input: PluginInterfaces.SingleTransactionPlanInput) {
        sendTransactionInputs.append(input)
    }

    func recordSendTransactions(_ input: PluginInterfaces.TransactionPlanInput) {
        sendTransactionsInputs.append(input)
    }

    func lastPlanTransactionInput() -> InstructionPlanInput? {
        planTransactionInputs.last
    }

    func lastPlanTransactionConfig() -> PluginTransactionConfig? {
        guard let config = planTransactionConfigs.last else {
            return nil
        }
        return config
    }

    func lastPlanTransactionsInput() -> InstructionPlanInput? {
        planTransactionsInputs.last
    }

    func lastSendTransactionInput() -> PluginInterfaces.SingleTransactionPlanInput? {
        sendTransactionInputs.last
    }

    func lastSendTransactionsInput() -> PluginInterfaces.TransactionPlanInput? {
        sendTransactionsInputs.last
    }
}

private struct RecordingTransactionClient: ClientWithTransactionPlanning, ClientWithTransactionSending {
    let recorder: SelfPlanAndSendCallRecorder
    let message = TransactionMessage(version: .legacy)

    func planTransaction(
        _ input: InstructionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> TransactionMessage {
        await recorder.recordPlanTransaction(input, config: config)
        return message
    }

    func planTransactions(
        _ input: InstructionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> TransactionPlan {
        await recorder.recordPlanTransactions(input)
        return .single(SingleTransactionPlan(message: message))
    }

    func sendTransaction(
        _ input: PluginInterfaces.SingleTransactionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> SuccessfulSingleTransactionPlanResult {
        await recorder.recordSendTransaction(input)
        return SuccessfulSingleTransactionPlanResult(
            plannedMessage: message,
            context: TransactionPlanExecutionContext()
        )
    }

    func sendTransactions(
        _ input: PluginInterfaces.TransactionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> TransactionPlanResult {
        await recorder.recordSendTransactions(input)
        return .single(.successful(SuccessfulSingleTransactionPlanResult(
            plannedMessage: message,
            context: TransactionPlanExecutionContext()
        )))
    }
}

private func makeInstruction() throws -> Instruction {
    try Instruction(programAddress: Address("11111111111111111111111111111111"))
}

private func assertSinglePlan(
    _ plan: InstructionPlan,
    contains instruction: Instruction,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard case let .single(singlePlan) = plan else {
        return XCTFail("Expected single instruction plan", file: file, line: line)
    }
    XCTAssertEqual(singlePlan.instruction, instruction, file: file, line: line)
}
