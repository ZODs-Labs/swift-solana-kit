public import Foundation
public import Instructions
public import Keys
public import Promises
public import SolanaErrors
public import TransactionMessages
public import Transactions

public struct SingleInstructionPlan: Sendable
public let SingleInstructionPlan.instruction: Instruction
public let SingleInstructionPlan.kind: String
public let SingleInstructionPlan.planType: String
public init SingleInstructionPlan(instruction: Instruction)

public struct ParallelInstructionPlan: Sendable
public let ParallelInstructionPlan.kind: String
public let ParallelInstructionPlan.planType: String
public let ParallelInstructionPlan.plans: [InstructionPlan]
public init ParallelInstructionPlan(plans: [InstructionPlan])

public struct SequentialInstructionPlan: Sendable
public let SequentialInstructionPlan.divisible: Bool
public let SequentialInstructionPlan.kind: String
public let SequentialInstructionPlan.planType: String
public let SequentialInstructionPlan.plans: [InstructionPlan]
public init SequentialInstructionPlan(plans: [InstructionPlan], divisible: Bool = true)

public struct MessagePackerInstructionPlan: Sendable
public let MessagePackerInstructionPlan.kind: String
public let MessagePackerInstructionPlan.planType: String
public init MessagePackerInstructionPlan(getMessagePacker: @escaping @Sendable () -> MessagePacker)
public func MessagePackerInstructionPlan.getMessagePacker() -> MessagePacker

public final class MessagePacker: Sendable
public init MessagePacker(done: @escaping @Sendable () -> Bool, packMessageToCapacity: @escaping @Sendable (TransactionMessage) throws -> TransactionMessage)
public func MessagePacker.done() -> Bool
public func MessagePacker.packMessageToCapacity(_ transactionMessage: TransactionMessage) throws -> TransactionMessage

public enum InstructionPlan: Sendable
public enum InstructionPlan.case single(SingleInstructionPlan)
public enum InstructionPlan.case parallel(ParallelInstructionPlan)
public enum InstructionPlan.case sequential(SequentialInstructionPlan)
public enum InstructionPlan.case messagePacker(MessagePackerInstructionPlan)
public var InstructionPlan.kind: String { get }
public var InstructionPlan.planType: String { get }

public indirect enum InstructionPlanInput: Sendable
public enum InstructionPlanInput.case instruction(Instruction)
public enum InstructionPlanInput.case plan(InstructionPlan)
public enum InstructionPlanInput.case array([InstructionPlanInput])

public indirect enum TransactionPlanInput: Sendable
public enum TransactionPlanInput.case message(TransactionMessage)
public enum TransactionPlanInput.case plan(TransactionPlan)
public enum TransactionPlanInput.case array([TransactionPlanInput])

public enum InstructionOrTransactionPlanInput: Sendable
public enum InstructionOrTransactionPlanInput.case instruction(InstructionPlanInput)
public enum InstructionOrTransactionPlanInput.case transaction(TransactionPlanInput)

public enum InstructionOrTransactionPlan: Sendable
public enum InstructionOrTransactionPlan.case instruction(InstructionPlan)
public enum InstructionOrTransactionPlan.case transaction(TransactionPlan)

public struct SingleTransactionPlan: Sendable
public let SingleTransactionPlan.kind: String
public let SingleTransactionPlan.message: TransactionMessage
public let SingleTransactionPlan.planType: String
public init SingleTransactionPlan(message: TransactionMessage)

public struct ParallelTransactionPlan: Sendable
public let ParallelTransactionPlan.kind: String
public let ParallelTransactionPlan.planType: String
public let ParallelTransactionPlan.plans: [TransactionPlan]
public init ParallelTransactionPlan(plans: [TransactionPlan])

public struct SequentialTransactionPlan: Sendable
public let SequentialTransactionPlan.divisible: Bool
public let SequentialTransactionPlan.kind: String
public let SequentialTransactionPlan.planType: String
public let SequentialTransactionPlan.plans: [TransactionPlan]
public init SequentialTransactionPlan(plans: [TransactionPlan], divisible: Bool = true)

public indirect enum TransactionPlan: Sendable
public enum TransactionPlan.case single(SingleTransactionPlan)
public enum TransactionPlan.case parallel(ParallelTransactionPlan)
public enum TransactionPlan.case sequential(SequentialTransactionPlan)
public var TransactionPlan.kind: String { get }
public var TransactionPlan.planType: String { get }

public struct TransactionPlanFailure: Error, Sendable, Equatable, LocalizedError
public let TransactionPlanFailure.code: Int?
public let TransactionPlanFailure.message: String
public init TransactionPlanFailure(_ error: any Error)
public init TransactionPlanFailure(code: Int? = nil, message: String)
public var TransactionPlanFailure.errorDescription: String? { get }

public struct TransactionPlanExecutionContext: Sendable, Equatable
public var TransactionPlanExecutionContext.message: TransactionMessage?
public var TransactionPlanExecutionContext.metadata: SolanaErrorContext
public var TransactionPlanExecutionContext.signature: Signature?
public var TransactionPlanExecutionContext.transaction: Transaction?
public init TransactionPlanExecutionContext(message: TransactionMessage? = nil, metadata: SolanaErrorContext = .empty, signature: Signature? = nil, transaction: Transaction? = nil)

public struct SuccessfulSingleTransactionPlanResult: Sendable
public let SuccessfulSingleTransactionPlanResult.context: TransactionPlanExecutionContext
public let SuccessfulSingleTransactionPlanResult.kind: String
public let SuccessfulSingleTransactionPlanResult.planType: String
public let SuccessfulSingleTransactionPlanResult.plannedMessage: TransactionMessage
public let SuccessfulSingleTransactionPlanResult.status: String
public init SuccessfulSingleTransactionPlanResult(plannedMessage: TransactionMessage, context: TransactionPlanExecutionContext)

public struct FailedSingleTransactionPlanResult: Sendable
public let FailedSingleTransactionPlanResult.context: TransactionPlanExecutionContext
public let FailedSingleTransactionPlanResult.error: TransactionPlanFailure
public let FailedSingleTransactionPlanResult.kind: String
public let FailedSingleTransactionPlanResult.planType: String
public let FailedSingleTransactionPlanResult.plannedMessage: TransactionMessage
public let FailedSingleTransactionPlanResult.status: String
public init FailedSingleTransactionPlanResult(plannedMessage: TransactionMessage, error: TransactionPlanFailure, context: TransactionPlanExecutionContext = TransactionPlanExecutionContext())

public struct CanceledSingleTransactionPlanResult: Sendable
public let CanceledSingleTransactionPlanResult.context: TransactionPlanExecutionContext
public let CanceledSingleTransactionPlanResult.kind: String
public let CanceledSingleTransactionPlanResult.planType: String
public let CanceledSingleTransactionPlanResult.plannedMessage: TransactionMessage
public let CanceledSingleTransactionPlanResult.status: String
public init CanceledSingleTransactionPlanResult(plannedMessage: TransactionMessage, context: TransactionPlanExecutionContext = TransactionPlanExecutionContext())

public enum SingleTransactionPlanResult: Sendable
public enum SingleTransactionPlanResult.case successful(SuccessfulSingleTransactionPlanResult)
public enum SingleTransactionPlanResult.case failed(FailedSingleTransactionPlanResult)
public enum SingleTransactionPlanResult.case canceled(CanceledSingleTransactionPlanResult)
public var SingleTransactionPlanResult.status: String { get }
public var SingleTransactionPlanResult.plannedMessage: TransactionMessage { get }

public struct ParallelTransactionPlanResult: Sendable
public let ParallelTransactionPlanResult.kind: String
public let ParallelTransactionPlanResult.planType: String
public let ParallelTransactionPlanResult.plans: [TransactionPlanResult]
public init ParallelTransactionPlanResult(plans: [TransactionPlanResult])

public struct SequentialTransactionPlanResult: Sendable
public let SequentialTransactionPlanResult.divisible: Bool
public let SequentialTransactionPlanResult.kind: String
public let SequentialTransactionPlanResult.planType: String
public let SequentialTransactionPlanResult.plans: [TransactionPlanResult]
public init SequentialTransactionPlanResult(plans: [TransactionPlanResult], divisible: Bool = true)

public indirect enum TransactionPlanResult: Sendable
public enum TransactionPlanResult.case single(SingleTransactionPlanResult)
public enum TransactionPlanResult.case parallel(ParallelTransactionPlanResult)
public enum TransactionPlanResult.case sequential(SequentialTransactionPlanResult)
public var TransactionPlanResult.kind: String { get }
public var TransactionPlanResult.planType: String { get }

public struct TransactionPlanResultSummary: Sendable
public let TransactionPlanResultSummary.canceledTransactions: [CanceledSingleTransactionPlanResult]
public let TransactionPlanResultSummary.failedTransactions: [FailedSingleTransactionPlanResult]
public let TransactionPlanResultSummary.successful: Bool
public let TransactionPlanResultSummary.successfulTransactions: [SuccessfulSingleTransactionPlanResult]
public init TransactionPlanResultSummary(canceledTransactions: [CanceledSingleTransactionPlanResult], failedTransactions: [FailedSingleTransactionPlanResult], successful: Bool, successfulTransactions: [SuccessfulSingleTransactionPlanResult])

public enum TransactionPlanExecutionOutput: Sendable
public enum TransactionPlanExecutionOutput.case signature(Signature)
public enum TransactionPlanExecutionOutput.case transaction(Transaction)

public typealias TransactionPlanner = @Sendable (_ instructionPlan: InstructionPlan, _ config: TransactionPlannerRunConfig) async throws -> TransactionPlan

public struct TransactionPlannerRunConfig: Sendable
public let TransactionPlannerRunConfig.abortSignal: AbortSignal?
public init TransactionPlannerRunConfig(abortSignal: AbortSignal? = nil)

public struct TransactionPlannerConfig: Sendable
public let TransactionPlannerConfig.createTransactionMessage: @Sendable (_ config: TransactionPlannerRunConfig) async throws -> TransactionMessage
public let TransactionPlannerConfig.onTransactionMessageUpdated: (@Sendable (_ transactionMessage: TransactionMessage, _ config: TransactionPlannerRunConfig) async throws -> TransactionMessage)?
public init TransactionPlannerConfig(createTransactionMessage: @escaping @Sendable (_ config: TransactionPlannerRunConfig) async throws -> TransactionMessage, onTransactionMessageUpdated: (@Sendable (_ transactionMessage: TransactionMessage, _ config: TransactionPlannerRunConfig) async throws -> TransactionMessage)? = nil)

public typealias TransactionPlanExecutor = @Sendable (_ transactionPlan: TransactionPlan, _ config: TransactionPlanExecutorRunConfig) async throws -> TransactionPlanResult

public struct TransactionPlanExecutorRunConfig: Sendable
public let TransactionPlanExecutorRunConfig.abortSignal: AbortSignal?
public init TransactionPlanExecutorRunConfig(abortSignal: AbortSignal? = nil)

public struct TransactionPlanExecutorConfig: Sendable
public let TransactionPlanExecutorConfig.executeTransactionMessage: @Sendable (_ context: TransactionPlanExecutionContext, _ transactionMessage: TransactionMessage, _ config: TransactionPlanExecutorRunConfig) async throws -> TransactionPlanExecutionOutput
public init TransactionPlanExecutorConfig(executeTransactionMessage: @escaping @Sendable (_ context: TransactionPlanExecutionContext, _ transactionMessage: TransactionMessage, _ config: TransactionPlanExecutorRunConfig) async throws -> TransactionPlanExecutionOutput)

public struct FailedToExecuteTransactionPlanError: SolanaErrorCoded, Sendable, LocalizedError
public let FailedToExecuteTransactionPlanError.abortReason: String?
public let FailedToExecuteTransactionPlanError.result: TransactionPlanResult
public init FailedToExecuteTransactionPlanError(result: TransactionPlanResult, abortReason: String? = nil)
public var FailedToExecuteTransactionPlanError.code: Int { get }
public var FailedToExecuteTransactionPlanError.contextDescription: String { get }
public var FailedToExecuteTransactionPlanError.errorDescription: String? { get }

public func singleInstructionPlan(_ instruction: Instruction) -> InstructionPlan
public func parallelInstructionPlan(_ plans: [InstructionPlan]) -> InstructionPlan
public func parallelInstructionPlan(_ instructions: [Instruction]) -> InstructionPlan
public func parallelInstructionPlan(_ inputs: [InstructionPlanInput]) -> InstructionPlan
public func sequentialInstructionPlan(_ plans: [InstructionPlan]) -> InstructionPlan
public func sequentialInstructionPlan(_ instructions: [Instruction]) -> InstructionPlan
public func sequentialInstructionPlan(_ inputs: [InstructionPlanInput]) -> InstructionPlan
public func nonDivisibleSequentialInstructionPlan(_ plans: [InstructionPlan]) -> InstructionPlan
public func nonDivisibleSequentialInstructionPlan(_ instructions: [Instruction]) -> InstructionPlan
public func nonDivisibleSequentialInstructionPlan(_ inputs: [InstructionPlanInput]) -> InstructionPlan
public func isInstructionPlan(_ value: Any) -> Bool
public func isSingleInstructionPlan(_ plan: InstructionPlan) -> Bool
public func assertIsSingleInstructionPlan(_ plan: InstructionPlan) throws
public func isMessagePackerInstructionPlan(_ plan: InstructionPlan) -> Bool
public func assertIsMessagePackerInstructionPlan(_ plan: InstructionPlan) throws
public func isSequentialInstructionPlan(_ plan: InstructionPlan) -> Bool
public func assertIsSequentialInstructionPlan(_ plan: InstructionPlan) throws
public func isNonDivisibleSequentialInstructionPlan(_ plan: InstructionPlan) -> Bool
public func assertIsNonDivisibleSequentialInstructionPlan(_ plan: InstructionPlan) throws
public func isParallelInstructionPlan(_ plan: InstructionPlan) -> Bool
public func assertIsParallelInstructionPlan(_ plan: InstructionPlan) throws
public func findInstructionPlan(_ instructionPlan: InstructionPlan, where predicate: (InstructionPlan) throws -> Bool) rethrows -> InstructionPlan?
public func everyInstructionPlan(_ instructionPlan: InstructionPlan, satisfies predicate: (InstructionPlan) throws -> Bool) rethrows -> Bool
public func transformInstructionPlan(_ instructionPlan: InstructionPlan, _ transform: (InstructionPlan) throws -> InstructionPlan) rethrows -> InstructionPlan
public func flattenInstructionPlan(_ instructionPlan: InstructionPlan) -> [InstructionPlan]
public func getLinearMessagePackerInstructionPlan(totalLength: Int, getInstruction: @escaping @Sendable (_ offset: Int, _ length: Int) -> Instruction) -> InstructionPlan
public func getMessagePackerInstructionPlanFromInstructions(_ instructions: [Instruction]) -> InstructionPlan
public func getReallocMessagePackerInstructionPlan(totalSize: Int, getInstruction: @escaping @Sendable (_ size: Int) -> Instruction) -> InstructionPlan
public func appendTransactionMessageInstructionPlan(_ instructionPlan: InstructionPlan, _ transactionMessage: TransactionMessage) throws -> TransactionMessage

public func parseInstructionPlanInput(_ input: InstructionPlanInput) -> InstructionPlan
public func parseInstructionPlanInput(_ instruction: Instruction) -> InstructionPlan
public func parseInstructionPlanInput(_ plan: InstructionPlan) -> InstructionPlan
public func parseInstructionPlanInput(_ inputs: [InstructionPlanInput]) -> InstructionPlan
public func parseTransactionPlanInput(_ input: TransactionPlanInput) -> TransactionPlan
public func parseTransactionPlanInput(_ message: TransactionMessage) -> TransactionPlan
public func parseTransactionPlanInput(_ plan: TransactionPlan) -> TransactionPlan
public func parseTransactionPlanInput(_ inputs: [TransactionPlanInput]) -> TransactionPlan
public func parseInstructionOrTransactionPlanInput(_ input: InstructionOrTransactionPlanInput) -> InstructionOrTransactionPlan

public func singleTransactionPlan(_ transactionMessage: TransactionMessage) -> TransactionPlan
public func parallelTransactionPlan(_ plans: [TransactionPlan]) -> TransactionPlan
public func parallelTransactionPlan(_ messages: [TransactionMessage]) -> TransactionPlan
public func parallelTransactionPlan(_ inputs: [TransactionPlanInput]) -> TransactionPlan
public func sequentialTransactionPlan(_ plans: [TransactionPlan]) -> TransactionPlan
public func sequentialTransactionPlan(_ messages: [TransactionMessage]) -> TransactionPlan
public func sequentialTransactionPlan(_ inputs: [TransactionPlanInput]) -> TransactionPlan
public func nonDivisibleSequentialTransactionPlan(_ plans: [TransactionPlan]) -> TransactionPlan
public func nonDivisibleSequentialTransactionPlan(_ messages: [TransactionMessage]) -> TransactionPlan
public func nonDivisibleSequentialTransactionPlan(_ inputs: [TransactionPlanInput]) -> TransactionPlan
public func isTransactionPlan(_ value: Any) -> Bool
public func isSingleTransactionPlan(_ plan: TransactionPlan) -> Bool
public func assertIsSingleTransactionPlan(_ plan: TransactionPlan) throws
public func isSequentialTransactionPlan(_ plan: TransactionPlan) -> Bool
public func assertIsSequentialTransactionPlan(_ plan: TransactionPlan) throws
public func isNonDivisibleSequentialTransactionPlan(_ plan: TransactionPlan) -> Bool
public func assertIsNonDivisibleSequentialTransactionPlan(_ plan: TransactionPlan) throws
public func isParallelTransactionPlan(_ plan: TransactionPlan) -> Bool
public func assertIsParallelTransactionPlan(_ plan: TransactionPlan) throws
public func flattenTransactionPlan(_ transactionPlan: TransactionPlan) -> [SingleTransactionPlan]
public func findTransactionPlan(_ transactionPlan: TransactionPlan, where predicate: (TransactionPlan) throws -> Bool) rethrows -> TransactionPlan?
public func everyTransactionPlan(_ transactionPlan: TransactionPlan, satisfies predicate: (TransactionPlan) throws -> Bool) rethrows -> Bool
public func transformTransactionPlan(_ transactionPlan: TransactionPlan, _ transform: (TransactionPlan) throws -> TransactionPlan) rethrows -> TransactionPlan

public func successfulSingleTransactionPlanResult(_ plannedMessage: TransactionMessage, context: TransactionPlanExecutionContext) -> TransactionPlanResult
public func successfulSingleTransactionPlanResult(_ plannedMessage: TransactionMessage, signature: Signature) -> TransactionPlanResult
public func successfulSingleTransactionPlanResultFromTransaction(_ plannedMessage: TransactionMessage, _ transaction: Transaction, context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()) throws -> TransactionPlanResult
public func failedSingleTransactionPlanResult(_ plannedMessage: TransactionMessage, _ error: any Error, context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()) -> TransactionPlanResult
public func canceledSingleTransactionPlanResult(_ plannedMessage: TransactionMessage, context: TransactionPlanExecutionContext = TransactionPlanExecutionContext()) -> TransactionPlanResult
public func parallelTransactionPlanResult(_ plans: [TransactionPlanResult]) -> TransactionPlanResult
public func sequentialTransactionPlanResult(_ plans: [TransactionPlanResult]) -> TransactionPlanResult
public func nonDivisibleSequentialTransactionPlanResult(_ plans: [TransactionPlanResult]) -> TransactionPlanResult
public func isTransactionPlanResult(_ value: Any) -> Bool
public func isSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsSingleTransactionPlanResult(_ result: TransactionPlanResult) throws
public func isSuccessfulSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsSuccessfulSingleTransactionPlanResult(_ result: TransactionPlanResult) throws
public func isFailedSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsFailedSingleTransactionPlanResult(_ result: TransactionPlanResult) throws
public func isCanceledSingleTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsCanceledSingleTransactionPlanResult(_ result: TransactionPlanResult) throws
public func isSequentialTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsSequentialTransactionPlanResult(_ result: TransactionPlanResult) throws
public func isNonDivisibleSequentialTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsNonDivisibleSequentialTransactionPlanResult(_ result: TransactionPlanResult) throws
public func isParallelTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsParallelTransactionPlanResult(_ result: TransactionPlanResult) throws
public func isSuccessfulTransactionPlanResult(_ result: TransactionPlanResult) -> Bool
public func assertIsSuccessfulTransactionPlanResult(_ result: TransactionPlanResult) throws
public func flattenTransactionPlanResult(_ result: TransactionPlanResult) -> [SingleTransactionPlanResult]
public func findTransactionPlanResult(_ result: TransactionPlanResult, where predicate: (TransactionPlanResult) throws -> Bool) rethrows -> TransactionPlanResult?
public func everyTransactionPlanResult(_ result: TransactionPlanResult, satisfies predicate: (TransactionPlanResult) throws -> Bool) rethrows -> Bool
public func transformTransactionPlanResult(_ result: TransactionPlanResult, _ transform: (TransactionPlanResult) throws -> TransactionPlanResult) rethrows -> TransactionPlanResult
public func getFirstFailedSingleTransactionPlanResult(_ result: TransactionPlanResult) throws -> FailedSingleTransactionPlanResult
public func summarizeTransactionPlanResult(_ result: TransactionPlanResult) -> TransactionPlanResultSummary

public func createFailedToExecuteTransactionPlanError(_ result: TransactionPlanResult, abortReason: String? = nil) -> FailedToExecuteTransactionPlanError
public func createFailedToSendTransactionError(_ result: SingleTransactionPlanResult, abortReason: String? = nil) -> SolanaError
public func createFailedToSendTransactionsError(_ result: TransactionPlanResult, abortReason: String? = nil) -> SolanaError
public func createTransactionPlanner(_ config: TransactionPlannerConfig) -> TransactionPlanner
public func createTransactionPlanExecutor(_ config: TransactionPlanExecutorConfig) -> TransactionPlanExecutor
public func passthroughFailedTransactionPlanExecution(_ operation: @Sendable () async throws -> TransactionPlanResult) async throws -> TransactionPlanResult
