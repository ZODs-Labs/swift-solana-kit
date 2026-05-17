import Addresses
import Foundation
import Instructions
@testable import InstructionPlans
import Keys
import Promises
import SolanaErrors
import TransactionMessages
import Transactions
import XCTest

final class TransactionPlanExecutorBehaviorTests: XCTestCase {
    func testExecutorPassesAbortSignalAndUsesReturnedSignature() async throws {
        let signal = AbortSignal()
        let recorder = ExecutionRecorder()
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, message, config in
                await recorder.record(message: Self.messageID(message), sawExpectedSignal: config.abortSignal === signal)
                return .signature(Signature(rawValue: "sig-\(Self.messageID(message))"))
            }
        ))

        let result = try await executor(singleTransactionPlan(try Self.makeMessage("A")), TransactionPlanExecutorRunConfig(abortSignal: signal))

        let recordedMessages = await recorder.messages()
        let recordedSignalMatches = await recorder.signalMatches()
        XCTAssertEqual(recordedMessages, ["A"])
        XCTAssertEqual(recordedSignalMatches, [true])
        guard case let .single(.successful(success)) = result else {
            return XCTFail("Expected a successful result")
        }
        XCTAssertEqual(success.context.signature, Signature(rawValue: "sig-A"))
    }

    func testExecutorUsesSignatureFromReturnedTransaction() async throws {
        let transaction = try Self.makeTransaction(signatureByte: 9)
        let expectedSignature = try getSignatureFromTransaction(transaction)
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, _, _ in .transaction(transaction) }
        ))

        let result = try await executor(singleTransactionPlan(try Self.makeMessage("A")), TransactionPlanExecutorRunConfig())

        guard case let .single(.successful(success)) = result else {
            return XCTFail("Expected a successful result")
        }
        XCTAssertEqual(success.context.signature, expectedSignature)
        XCTAssertEqual(success.context.transaction, transaction)
    }

    func testExecutorRejectsNonDivisibleTransactionPlansBeforeExecution() async throws {
        let recorder = ExecutionRecorder()
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, message, _ in
                await recorder.record(message: Self.messageID(message), sawExpectedSignal: false)
                return .signature(Signature(rawValue: "unused"))
            }
        ))
        let plan = nonDivisibleSequentialTransactionPlan([try Self.makeMessage("A")])

        do {
            _ = try await executor(plan, TransactionPlanExecutorRunConfig())
            XCTFail("Expected executor failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.instructionPlansNonDivisibleTransactionPlansNotSupported.rawValue)
        }
        let recordedMessages = await recorder.messages()
        XCTAssertTrue(recordedMessages.isEmpty)
    }

    func testExecutorCancelsLaterSequentialPlansAfterFailure() async throws {
        let recorder = ExecutionRecorder()
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, message, _ in
                let id = Self.messageID(message)
                await recorder.record(message: id, sawExpectedSignal: false)
                if id == "B" {
                    throw TestFailure("B failed")
                }
                return .signature(Signature(rawValue: "sig-\(id)"))
            }
        ))
        let plan = sequentialTransactionPlan([
            try Self.makeMessage("A"),
            try Self.makeMessage("B"),
            try Self.makeMessage("C"),
        ])

        do {
            _ = try await executor(plan, TransactionPlanExecutorRunConfig())
            XCTFail("Expected executor failure")
        } catch let error as FailedToExecuteTransactionPlanError {
            XCTAssertNil(error.abortReason)
            XCTAssertEqual(flattenTransactionPlanResult(error.result).map(\.status), ["successful", "failed", "canceled"])
            let recordedMessages = await recorder.messages()
            XCTAssertEqual(recordedMessages, ["A", "B"])
        }
    }

    func testExecutorPreservesInputOrderForParallelResults() async throws {
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, message, _ in
                if Self.messageID(message) == "A" {
                    try await Task.sleep(nanoseconds: 30_000_000)
                }
                return .signature(Signature(rawValue: "sig-\(Self.messageID(message))"))
            }
        ))

        let result = try await executor(
            parallelTransactionPlan([try Self.makeMessage("A"), try Self.makeMessage("B")]),
            TransactionPlanExecutorRunConfig()
        )

        let signatures = flattenTransactionPlanResult(result).compactMap { single -> Signature? in
            guard case let .successful(success) = single else {
                return nil
            }
            return success.context.signature
        }
        XCTAssertEqual(signatures, [Signature(rawValue: "sig-A"), Signature(rawValue: "sig-B")])
    }

    func testExecutorFailsImmediatelyWhenSignalIsAlreadyAborted() async throws {
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let recorder = ExecutionRecorder()
        let executor = createTransactionPlanExecutor(TransactionPlanExecutorConfig(
            executeTransactionMessage: { _, message, _ in
                await recorder.record(message: Self.messageID(message), sawExpectedSignal: false)
                return .signature(Signature(rawValue: "late"))
            }
        ))

        do {
            _ = try await executor(singleTransactionPlan(try Self.makeMessage("A")), TransactionPlanExecutorRunConfig(abortSignal: signal))
            XCTFail("Expected executor failure")
        } catch let error as FailedToExecuteTransactionPlanError {
            XCTAssertEqual(error.abortReason, "stop")
            XCTAssertEqual(flattenTransactionPlanResult(error.result).map(\.status), ["failed"])
            let recordedMessages = await recorder.messages()
            XCTAssertTrue(recordedMessages.isEmpty)
        }
    }

    func testPassthroughReturnsFailedExecutionResultsOnly() async throws {
        let result = sequentialTransactionPlanResult([
            failedSingleTransactionPlanResult(try Self.makeMessage("A"), TestFailure("A failed")),
        ])

        let passedThrough = try await passthroughFailedTransactionPlanExecution {
            throw FailedToExecuteTransactionPlanError(result: result, abortReason: "stop")
        }
        XCTAssertEqual(flattenTransactionPlanResult(passedThrough).map(\.status), ["failed"])

        do {
            _ = try await passthroughFailedTransactionPlanExecution {
                throw TestFailure("plain")
            }
            XCTFail("Expected passthrough to rethrow")
        } catch let error as TestFailure {
            XCTAssertEqual(error.message, "plain")
        }
    }

    private static func makeMessage(_ id: String) throws -> TransactionMessage {
        let feePayer = try address()
        let instruction = Instruction(
            programAddress: try Address("11111111111111111111111111111111"),
            data: Data(id.utf8)
        )
        return appendTransactionMessageInstruction(
            instruction,
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
        )
    }

    private static func makeTransaction(signatureByte: UInt8) throws -> Transaction {
        Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([
                (try address(), try SignatureBytes(Data(repeating: signatureByte, count: 64))),
            ])
        )
    }

    private static func messageID(_ message: TransactionMessage) -> String {
        guard let data = message.instructions.first?.data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func address() throws -> Address {
        try Address("E9Nykp3rSdza2moQutaJ3K3RSC8E5iFERX2SqLTsQfjJ")
    }
}

private actor ExecutionRecorder {
    private var recordedMessages: [String] = []
    private var recordedSignalMatches: [Bool] = []

    func record(message: String, sawExpectedSignal: Bool) {
        recordedMessages.append(message)
        recordedSignalMatches.append(sawExpectedSignal)
    }

    func messages() -> [String] {
        recordedMessages
    }

    func signalMatches() -> [Bool] {
        recordedSignalMatches
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
