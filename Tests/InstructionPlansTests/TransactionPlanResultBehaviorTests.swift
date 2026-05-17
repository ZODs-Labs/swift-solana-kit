import Addresses
import Foundation
import Instructions
@testable import InstructionPlans
import Keys
import SolanaErrors
import TransactionMessages
import Transactions
import XCTest

final class TransactionPlanResultBehaviorTests: XCTestCase {
    func testSingleResultConstructorsPreserveStatusContextAndMessages() throws {
        let message = try Self.makeMessage("A")
        let signature = Signature(rawValue: "sigA")
        let success = successfulSingleTransactionPlanResult(
            message,
            context: TransactionPlanExecutionContext(
                metadata: ["slot": .int(5)],
                signature: signature
            )
        )

        guard case let .single(.successful(successResult)) = success else {
            return XCTFail("Expected a successful single result")
        }
        XCTAssertEqual(successResult.kind, "single")
        XCTAssertEqual(successResult.planType, "transactionPlanResult")
        XCTAssertEqual(successResult.status, "successful")
        XCTAssertEqual(successResult.context.signature, signature)
        XCTAssertEqual(successResult.context.metadata["slot"], .int(5))
        XCTAssertEqual(Self.messageID(successResult.plannedMessage), "A")

        let failure = failedSingleTransactionPlanResult(
            message,
            SolanaError(.transactionFeePayerSignatureMissing),
            context: TransactionPlanExecutionContext(metadata: ["attempt": .int(2)])
        )
        guard case let .single(.failed(failedResult)) = failure else {
            return XCTFail("Expected a failed single result")
        }
        XCTAssertEqual(failedResult.status, "failed")
        XCTAssertEqual(failedResult.error.code, SolanaErrorCode.transactionFeePayerSignatureMissing.rawValue)
        XCTAssertEqual(failedResult.context.metadata["attempt"], .int(2))

        let canceled = canceledSingleTransactionPlanResult(
            message,
            context: TransactionPlanExecutionContext(metadata: ["reason": .string("user")])
        )
        guard case let .single(.canceled(canceledResult)) = canceled else {
            return XCTFail("Expected a canceled single result")
        }
        XCTAssertEqual(canceledResult.status, "canceled")
        XCTAssertEqual(canceledResult.context.metadata["reason"], .string("user"))
    }

    func testSuccessfulResultFromTransactionUsesTransactionSignatureAndKeepsContext() throws {
        let message = try Self.makeMessage("A")
        let address = try Self.address()
        let signatureBytes = try SignatureBytes(Data(repeating: 7, count: 64))
        let signature = base58EncodedSignature(signatureBytes)
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(address, signatureBytes)])
        )

        let result = try successfulSingleTransactionPlanResultFromTransaction(
            message,
            transaction,
            context: TransactionPlanExecutionContext(
                metadata: ["source": .string("unit")],
                signature: Signature(rawValue: "old")
            )
        )

        guard case let .single(.successful(success)) = result else {
            return XCTFail("Expected a successful single result")
        }
        XCTAssertEqual(success.context.signature, signature)
        XCTAssertEqual(success.context.transaction, transaction)
        XCTAssertEqual(success.context.metadata["source"], .string("unit"))
    }

    func testResultTreeConstructorsPreserveKindsDivisibilityAndNesting() throws {
        let successA = successfulSingleTransactionPlanResult(try Self.makeMessage("A"), signature: Signature(rawValue: "A"))
        let successB = successfulSingleTransactionPlanResult(try Self.makeMessage("B"), signature: Signature(rawValue: "B"))
        let canceledC = canceledSingleTransactionPlanResult(try Self.makeMessage("C"))

        let parallel = parallelTransactionPlanResult([successA, successB])
        guard case let .parallel(parallelResult) = parallel else {
            return XCTFail("Expected a parallel result")
        }
        XCTAssertEqual(parallelResult.kind, "parallel")
        XCTAssertEqual(parallelResult.planType, "transactionPlanResult")
        XCTAssertEqual(parallelResult.plans.map(\.kind), ["single", "single"])

        let sequential = sequentialTransactionPlanResult([parallel, canceledC])
        guard case let .sequential(sequentialResult) = sequential else {
            return XCTFail("Expected a sequential result")
        }
        XCTAssertTrue(sequentialResult.divisible)
        XCTAssertEqual(sequentialResult.plans.map(\.kind), ["parallel", "single"])

        let nonDivisible = nonDivisibleSequentialTransactionPlanResult([successA, canceledC])
        guard case let .sequential(nonDivisibleResult) = nonDivisible else {
            return XCTFail("Expected a sequential result")
        }
        XCTAssertFalse(nonDivisibleResult.divisible)
    }

    func testResultPredicatesAndAssertionsUseStatusAwareKinds() throws {
        let successful = successfulSingleTransactionPlanResult(try Self.makeMessage("A"), signature: Signature(rawValue: "A"))
        let failed = failedSingleTransactionPlanResult(try Self.makeMessage("B"), TestFailure("boom"))
        let canceled = canceledSingleTransactionPlanResult(try Self.makeMessage("C"))
        let sequential = sequentialTransactionPlanResult([])
        let nonDivisible = nonDivisibleSequentialTransactionPlanResult([])
        let parallel = parallelTransactionPlanResult([])

        XCTAssertTrue(isTransactionPlanResult(successful))
        XCTAssertFalse(isTransactionPlanResult("result"))
        XCTAssertTrue(isSingleTransactionPlanResult(successful))
        XCTAssertTrue(isSingleTransactionPlanResult(failed))
        XCTAssertTrue(isSingleTransactionPlanResult(canceled))
        XCTAssertTrue(isSuccessfulSingleTransactionPlanResult(successful))
        XCTAssertFalse(isSuccessfulSingleTransactionPlanResult(failed))
        XCTAssertTrue(isFailedSingleTransactionPlanResult(failed))
        XCTAssertTrue(isCanceledSingleTransactionPlanResult(canceled))
        XCTAssertTrue(isSequentialTransactionPlanResult(sequential))
        XCTAssertTrue(isSequentialTransactionPlanResult(nonDivisible))
        XCTAssertTrue(isNonDivisibleSequentialTransactionPlanResult(nonDivisible))
        XCTAssertTrue(isParallelTransactionPlanResult(parallel))

        try assertIsSuccessfulSingleTransactionPlanResult(successful)
        try assertIsFailedSingleTransactionPlanResult(failed)
        try assertIsCanceledSingleTransactionPlanResult(canceled)
        try assertIsSequentialTransactionPlanResult(sequential)
        try assertIsNonDivisibleSequentialTransactionPlanResult(nonDivisible)
        try assertIsParallelTransactionPlanResult(parallel)

        try Self.assertSolanaError(
            assertIsSuccessfulSingleTransactionPlanResult(failed),
            code: .instructionPlansUnexpectedTransactionPlanResult,
            context: ["actualKind": .string("failed single"), "expectedKind": .string("successful single")]
        )
        try Self.assertSolanaError(
            assertIsFailedSingleTransactionPlanResult(canceled),
            code: .instructionPlansUnexpectedTransactionPlanResult,
            context: ["actualKind": .string("canceled single"), "expectedKind": .string("failed single")]
        )
        try Self.assertSolanaError(
            assertIsNonDivisibleSequentialTransactionPlanResult(sequential),
            code: .instructionPlansUnexpectedTransactionPlanResult,
            context: ["actualKind": .string("divisible sequential"), "expectedKind": .string("non-divisible sequential")]
        )
        try Self.assertSolanaError(
            assertIsParallelTransactionPlanResult(successful),
            code: .instructionPlansUnexpectedTransactionPlanResult,
            context: ["actualKind": .string("successful single"), "expectedKind": .string("parallel")]
        )
    }

    func testSuccessfulResultChecksTreatEmptyTreesAsSuccessful() throws {
        let successful = successfulSingleTransactionPlanResult(try Self.makeMessage("A"), signature: Signature(rawValue: "A"))
        let failed = failedSingleTransactionPlanResult(try Self.makeMessage("B"), TestFailure("boom"))
        let canceled = canceledSingleTransactionPlanResult(try Self.makeMessage("C"))

        XCTAssertTrue(isSuccessfulTransactionPlanResult(successful))
        XCTAssertTrue(isSuccessfulTransactionPlanResult(parallelTransactionPlanResult([])))
        XCTAssertTrue(isSuccessfulTransactionPlanResult(sequentialTransactionPlanResult([])))
        XCTAssertTrue(isSuccessfulTransactionPlanResult(parallelTransactionPlanResult([
            successful,
            sequentialTransactionPlanResult([successful]),
        ])))
        XCTAssertFalse(isSuccessfulTransactionPlanResult(parallelTransactionPlanResult([successful, failed])))
        XCTAssertFalse(isSuccessfulTransactionPlanResult(sequentialTransactionPlanResult([successful, canceled])))

        try assertIsSuccessfulTransactionPlanResult(parallelTransactionPlanResult([]))
        try Self.assertSolanaError(
            assertIsSuccessfulTransactionPlanResult(parallelTransactionPlanResult([successful, failed])),
            code: .instructionPlansExpectedSuccessfulTransactionPlanResult
        )
    }

    func testResultTreeTraversalFlatteningAndTransformAreDepthFirst() throws {
        let successA = successfulSingleTransactionPlanResult(try Self.makeMessage("A"), signature: Signature(rawValue: "A"))
        let failedB = failedSingleTransactionPlanResult(try Self.makeMessage("B"), TestFailure("B failed"))
        let canceledC = canceledSingleTransactionPlanResult(try Self.makeMessage("C"))
        let result = parallelTransactionPlanResult([
            sequentialTransactionPlanResult([successA, failedB]),
            nonDivisibleSequentialTransactionPlanResult([canceledC]),
        ])

        XCTAssertEqual(flattenTransactionPlanResult(result).map(\.status), ["successful", "failed", "canceled"])
        let firstFailed = try getFirstFailedSingleTransactionPlanResult(result)
        XCTAssertEqual(Self.messageID(firstFailed.plannedMessage), "B")

        let found = findTransactionPlanResult(result) { candidate in
            isNonDivisibleSequentialTransactionPlanResult(candidate)
        }
        XCTAssertEqual(found?.kind, "sequential")

        var visited: [String] = []
        let everyResult = everyTransactionPlanResult(result) { candidate in
            visited.append(candidate.kind)
            return candidate.kind != "single" || !isFailedSingleTransactionPlanResult(candidate)
        }
        XCTAssertFalse(everyResult)
        XCTAssertEqual(visited, ["parallel", "sequential", "single", "single"])

        let transformed = transformTransactionPlanResult(result) { candidate in
            guard case let .single(.canceled(canceled)) = candidate else {
                return candidate
            }
            return failedSingleTransactionPlanResult(canceled.plannedMessage, TestFailure("converted"))
        }
        XCTAssertEqual(flattenTransactionPlanResult(transformed).map(\.status), ["successful", "failed", "failed"])
    }

    func testResultSummariesGroupStatusesAndReportFirstFailure() throws {
        let successA = successfulSingleTransactionPlanResult(try Self.makeMessage("A"), signature: Signature(rawValue: "A"))
        let failedB = failedSingleTransactionPlanResult(try Self.makeMessage("B"), TestFailure("B failed"))
        let canceledC = canceledSingleTransactionPlanResult(try Self.makeMessage("C"))
        let result = sequentialTransactionPlanResult([
            successA,
            parallelTransactionPlanResult([failedB, canceledC]),
        ])

        let summary = summarizeTransactionPlanResult(result)

        XCTAssertFalse(summary.successful)
        XCTAssertEqual(summary.successfulTransactions.map { Self.messageID($0.plannedMessage) }, ["A"])
        XCTAssertEqual(summary.failedTransactions.map { Self.messageID($0.plannedMessage) }, ["B"])
        XCTAssertEqual(summary.canceledTransactions.map { Self.messageID($0.plannedMessage) }, ["C"])
        XCTAssertEqual(try getFirstFailedSingleTransactionPlanResult(result).error.message, "B failed")

        try Self.assertSolanaError(
            getFirstFailedSingleTransactionPlanResult(parallelTransactionPlanResult([successA])),
            code: .instructionPlansFailedSingleTransactionPlanResultNotFound
        )
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

private struct TestFailure: Error, LocalizedError, Sendable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
