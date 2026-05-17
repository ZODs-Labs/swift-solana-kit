import Addresses
import Foundation
import Instructions
@testable import InstructionPlans
import Keys
import SolanaErrors
import TransactionMessages
import XCTest

final class TransactionPlanErrorBehaviorTests: XCTestCase {
    func testSingleSendErrorsUseFailureCauseAndSignatureIndicator() throws {
        let signature = Signature(rawValue: "5wHu1qwD7q5ifaN5nwdcDQNbHUiCfnzJ6vaR98NLugS1CiVfCZLMGmmFaKCAVfPTFE5KPMhSaZaLo2v4xXSHVJk")
        let result = failedSingleTransactionPlanResult(
            try Self.makeMessage("A"),
            TestFailure("Transaction failed"),
            context: TransactionPlanExecutionContext(signature: signature)
        )

        guard case let .single(single) = result else {
            return XCTFail("Expected a single result")
        }
        let error = createFailedToSendTransactionError(single)

        XCTAssertEqual(error.code, SolanaErrorCode.failedToSendTransaction.rawValue)
        XCTAssertEqual(error.context["cause"], .string("Transaction failed"))
        XCTAssertEqual(error.context["causeMessage"], .string(" (\(signature)): Transaction failed"))
        XCTAssertEqual(error.errorDescription, "Failed to send transaction (\(signature)): Transaction failed")
    }

    func testSingleSendErrorsUsePlainFailureWithoutSignature() throws {
        let result = failedSingleTransactionPlanResult(
            try Self.makeMessage("A"),
            TestFailure("Connection refused")
        )

        guard case let .single(single) = result else {
            return XCTFail("Expected a single result")
        }
        let error = createFailedToSendTransactionError(single)

        XCTAssertEqual(error.context["cause"], .string("Connection refused"))
        XCTAssertEqual(error.context["causeMessage"], .string(": Connection refused"))
        XCTAssertEqual(error.errorDescription, "Failed to send transaction: Connection refused")
    }

    func testSingleSendErrorsRepresentCanceledResultsWithAndWithoutReasons() throws {
        let canceled = canceledSingleTransactionPlanResult(try Self.makeMessage("A"))
        guard case let .single(single) = canceled else {
            return XCTFail("Expected a single result")
        }

        let withReason = createFailedToSendTransactionError(single, abortReason: "User canceled")
        XCTAssertEqual(withReason.code, SolanaErrorCode.failedToSendTransaction.rawValue)
        XCTAssertEqual(withReason.context["causeMessage"], .string(". Canceled with abort reason: User canceled"))
        XCTAssertEqual(withReason.errorDescription, "Failed to send transaction. Canceled with abort reason: User canceled")

        let withoutReason = createFailedToSendTransactionError(single)
        XCTAssertEqual(withoutReason.context["causeMessage"], .string(": Canceled"))
        XCTAssertEqual(withoutReason.errorDescription, "Failed to send transaction: Canceled")
    }

    func testMultipleSendErrorsListOnlyFailedTransactionsInFlattenedOrder() throws {
        let success = successfulSingleTransactionPlanResult(try Self.makeMessage("A"), signature: Signature(rawValue: "sigA"))
        let failedB = failedSingleTransactionPlanResult(try Self.makeMessage("B"), TestFailure("B failed"))
        let canceledC = canceledSingleTransactionPlanResult(try Self.makeMessage("C"))
        let failedD = failedSingleTransactionPlanResult(try Self.makeMessage("D"), TestFailure("D failed"))
        let result = sequentialTransactionPlanResult([
            parallelTransactionPlanResult([success, failedB]),
            sequentialTransactionPlanResult([canceledC, failedD]),
        ])

        let error = createFailedToSendTransactionsError(result)

        XCTAssertEqual(error.code, SolanaErrorCode.failedToSendTransactions.rawValue)
        XCTAssertEqual(error.context["causeMessages"], .string(".\n[Tx #2] B failed\n[Tx #4] D failed"))
        XCTAssertEqual(
            error.errorDescription,
            "Failed to send transactions.\n[Tx #2] B failed\n[Tx #4] D failed"
        )
    }

    func testMultipleSendErrorsRepresentAllCanceledResults() throws {
        let result = sequentialTransactionPlanResult([
            canceledSingleTransactionPlanResult(try Self.makeMessage("A")),
            canceledSingleTransactionPlanResult(try Self.makeMessage("B")),
        ])

        let withReason = createFailedToSendTransactionsError(result, abortReason: "User aborted")
        XCTAssertEqual(withReason.context["causeMessages"], .string(". Canceled with abort reason: User aborted"))
        XCTAssertEqual(withReason.errorDescription, "Failed to send transactions. Canceled with abort reason: User aborted")

        let withoutReason = createFailedToSendTransactionsError(result)
        XCTAssertEqual(withoutReason.context["causeMessages"], .string(": Canceled"))
        XCTAssertEqual(withoutReason.errorDescription, "Failed to send transactions: Canceled")
    }

    func testExecutionErrorFactoryPreservesResultAndAbortReason() throws {
        let result = sequentialTransactionPlanResult([
            failedSingleTransactionPlanResult(try Self.makeMessage("A"), TestFailure("A failed")),
        ])

        let withReason = createFailedToExecuteTransactionPlanError(result, abortReason: "stop")
        XCTAssertEqual(withReason.code, SolanaErrorCode.instructionPlansFailedToExecuteTransactionPlan.rawValue)
        XCTAssertEqual(withReason.abortReason, "stop")
        XCTAssertEqual(withReason.result.kind, "sequential")
        XCTAssertEqual(
            withReason.errorDescription,
            "The provided transaction plan failed to execute. See the `transactionPlanResult` attribute for more details. Note that the `cause` property is deprecated, and a future version will not set it."
        )

        let withoutReason = createFailedToExecuteTransactionPlanError(result)
        XCTAssertNil(withoutReason.abortReason)
        XCTAssertEqual(flattenTransactionPlanResult(withoutReason.result).map(\.status), ["failed"])
    }

    private static func makeMessage(_ id: String) throws -> TransactionMessage {
        let feePayer = try Address("E9Nykp3rSdza2moQutaJ3K3RSC8E5iFERX2SqLTsQfjJ")
        let instruction = Instruction(
            programAddress: try Address("11111111111111111111111111111111"),
            data: Data(id.utf8)
        )
        return appendTransactionMessageInstruction(
            instruction,
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
        )
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
