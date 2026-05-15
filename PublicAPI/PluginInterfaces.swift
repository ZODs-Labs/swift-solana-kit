public import Addresses
public import InstructionPlans
public import Instructions
public import Keys
public import Promises
public import RpcSpec
public import RpcSubscriptionsSpec
public import RpcTypes
public import Signers
public import TransactionMessages

public protocol ClientWithAirdrop: Sendable
public func ClientWithAirdrop.airdrop(address: Address, amount: Lamports, abortSignal: AbortSignal?) async throws -> Signature?
public func ClientWithAirdrop.airdrop(address: Address, amount: Lamports) async throws -> Signature?

public struct GetMinimumBalanceConfig: Sendable, Equatable, Hashable
public let GetMinimumBalanceConfig.withoutHeader: Bool
public init GetMinimumBalanceConfig(withoutHeader: Bool = false)

public protocol ClientWithGetMinimumBalance: Sendable
public func ClientWithGetMinimumBalance.getMinimumBalance(space: Int, config: GetMinimumBalanceConfig?) async throws -> Lamports
public func ClientWithGetMinimumBalance.getMinimumBalance(space: Int) async throws -> Lamports

public protocol ClientWithIdentity: Sendable
public var ClientWithIdentity.identity: TransactionSigner { get }

public protocol ClientWithPayer: Sendable
public var ClientWithPayer.payer: TransactionSigner { get }

public protocol ClientWithRpc: Sendable
public var ClientWithRpc.rpc: Rpc { get }

public protocol ClientWithRpcSubscriptions: Sendable
public var ClientWithRpcSubscriptions.rpcSubscriptions: RpcSubscriptions { get }

public typealias SubscribeToFn = @Sendable (@escaping @Sendable () -> Void) -> @Sendable () -> Void

public protocol ClientWithSubscribeToPayer: Sendable
public var ClientWithSubscribeToPayer.subscribeToPayer: SubscribeToFn { get }

public protocol ClientWithSubscribeToIdentity: Sendable
public var ClientWithSubscribeToIdentity.subscribeToIdentity: SubscribeToFn { get }

public struct PluginTransactionConfig: Sendable, Equatable
public let PluginTransactionConfig.abortSignal: AbortSignal?
public init PluginTransactionConfig(abortSignal: AbortSignal? = nil)
public static func PluginTransactionConfig.== (lhs: PluginTransactionConfig, rhs: PluginTransactionConfig) -> Bool

public enum SingleTransactionPlanInput: Sendable
public enum SingleTransactionPlanInput.case instruction(Instruction)
public enum SingleTransactionPlanInput.case instructionPlan(InstructionPlans.InstructionPlan)
public enum SingleTransactionPlanInput.case instructionPlanInput(InstructionPlans.InstructionPlanInput)
public enum SingleTransactionPlanInput.case singleTransactionPlan(InstructionPlans.SingleTransactionPlan)
public enum SingleTransactionPlanInput.case transactionMessage(TransactionMessage)

public enum TransactionPlanInput: Sendable
public enum TransactionPlanInput.case instruction(Instruction)
public enum TransactionPlanInput.case instructionPlan(InstructionPlans.InstructionPlan)
public enum TransactionPlanInput.case instructionPlanInput(InstructionPlans.InstructionPlanInput)
public enum TransactionPlanInput.case transactionPlan(InstructionPlans.TransactionPlan)

public protocol ClientWithTransactionPlanning: Sendable
public func ClientWithTransactionPlanning.planTransaction(_ input: InstructionPlans.InstructionPlanInput, config: PluginTransactionConfig?) async throws -> TransactionMessage
public func ClientWithTransactionPlanning.planTransactions(_ input: InstructionPlans.InstructionPlanInput, config: PluginTransactionConfig?) async throws -> InstructionPlans.TransactionPlan

public protocol ClientWithTransactionSending: Sendable
public func ClientWithTransactionSending.sendTransaction(_ input: SingleTransactionPlanInput, config: PluginTransactionConfig?) async throws -> InstructionPlans.SuccessfulSingleTransactionPlanResult
public func ClientWithTransactionSending.sendTransactions(_ input: TransactionPlanInput, config: PluginTransactionConfig?) async throws -> InstructionPlans.TransactionPlanResult
