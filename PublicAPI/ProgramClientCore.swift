public import Accounts
public import Addresses
public import CodecsCore
public import Foundation
public import InstructionPlans
public import Instructions
public import PluginInterfaces
public import RpcSpec
public import Signers
public import SolanaErrors
public import TransactionMessages

public enum ResolvedInstructionAccountValue: Sendable
public enum ResolvedInstructionAccountValue.case address(Address)
public enum ResolvedInstructionAccountValue.case programDerivedAddress(ProgramDerivedAddress)
public enum ResolvedInstructionAccountValue.case transactionSigner(TransactionSigner)
public var ResolvedInstructionAccountValue.address: Address { get }

public struct ResolvedInstructionAccount: Sendable
public let ResolvedInstructionAccount.isWritable: Bool
public let ResolvedInstructionAccount.value: ResolvedInstructionAccountValue?
public init ResolvedInstructionAccount(isWritable: Bool, value: ResolvedInstructionAccountValue?)

public enum OptionalAccountStrategy: Sendable, Equatable, Hashable
public enum OptionalAccountStrategy.case omitted
public enum OptionalAccountStrategy.case programID

public typealias AccountMetaFactory = @Sendable (_ inputName: String, _ account: ResolvedInstructionAccount) throws(SolanaError) -> InstructionAccountWithSigner?

public struct InstructionWithByteDelta: Sendable, Equatable, Hashable
public let InstructionWithByteDelta.byteDelta: Int
public init InstructionWithByteDelta(byteDelta: Int)

public struct SelfFetchingCodec<Base: Codec>: Codec where Base.Decoded: Sendable
public typealias SelfFetchingCodec.Encoded = Base.Encoded
public typealias SelfFetchingCodec.Decoded = Base.Decoded
public let SelfFetchingCodec.base: Base
public init SelfFetchingCodec(base: Base, rpc: Rpc)
public func SelfFetchingCodec.encode(_ value: Base.Encoded) throws(CodecsError) -> Data
public func SelfFetchingCodec.write(_ value: Base.Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset
public func SelfFetchingCodec.decode(_ bytes: Data, at offset: Offset = 0) throws(CodecsError) -> Base.Decoded
public func SelfFetchingCodec.read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Base.Decoded, Offset)
public func SelfFetchingCodec.fetch(_ address: Address, config: FetchAccountConfig = FetchAccountConfig()) async throws -> Account<Base.Decoded>
public func SelfFetchingCodec.fetchMaybe(_ address: Address, config: FetchAccountConfig = FetchAccountConfig()) async throws -> MaybeAccount<Base.Decoded>
public func SelfFetchingCodec.fetchAll(_ addresses: [Address], config: FetchAccountsConfig = FetchAccountsConfig()) async throws -> [Account<Base.Decoded>]
public func SelfFetchingCodec.fetchAllMaybe(_ addresses: [Address], config: FetchAccountsConfig = FetchAccountsConfig()) async throws -> [MaybeAccount<Base.Decoded>]
extension SelfFetchingCodec: FixedSizeEncoder where Base: FixedSizeCodec
extension SelfFetchingCodec: FixedSizeDecoder where Base: FixedSizeCodec
extension SelfFetchingCodec: FixedSizeCodec where Base: FixedSizeCodec
public var SelfFetchingCodec.fixedSize: Int { get }
extension SelfFetchingCodec: VariableSizeEncoder where Base: VariableSizeCodec
extension SelfFetchingCodec: VariableSizeDecoder where Base: VariableSizeCodec
extension SelfFetchingCodec: VariableSizeCodec where Base: VariableSizeCodec
public var SelfFetchingCodec.maxSize: Int? { get }
public func SelfFetchingCodec.getSizeFromValue(_ value: Base.Encoded) throws(CodecsError) -> Int

public struct SelfPlanAndSendItem<Input: Sendable>: Sendable
public let SelfPlanAndSendItem.input: Input
public init SelfPlanAndSendItem(input: Input, instructionPlanInput: @escaping @Sendable () async throws -> InstructionPlans.InstructionPlanInput, singleTransactionInput: @escaping @Sendable () async throws -> PluginInterfaces.SingleTransactionPlanInput, transactionInput: @escaping @Sendable () async throws -> PluginInterfaces.TransactionPlanInput, client: any ClientWithTransactionPlanning & ClientWithTransactionSending)
public func SelfPlanAndSendItem.planTransaction(config: PluginTransactionConfig? = nil) async throws -> TransactionMessage
public func SelfPlanAndSendItem.planTransactions(config: PluginTransactionConfig? = nil) async throws -> InstructionPlans.TransactionPlan
public func SelfPlanAndSendItem.sendTransaction(config: PluginTransactionConfig? = nil) async throws -> InstructionPlans.SuccessfulSingleTransactionPlanResult
public func SelfPlanAndSendItem.sendTransactions(config: PluginTransactionConfig? = nil) async throws -> InstructionPlans.TransactionPlanResult

public func getNonNullResolvedInstructionInput<T>(_ inputName: String, _ value: T?) throws(SolanaError) -> T
public func getAddressFromResolvedInstructionAccount(_ inputName: String, _ value: ResolvedInstructionAccountValue?) throws(SolanaError) -> Address
public func getResolvedInstructionAccountAsProgramDerivedAddress(_ inputName: String, _ value: ResolvedInstructionAccountValue?) throws(SolanaError) -> ProgramDerivedAddress
public func getResolvedInstructionAccountAsTransactionSigner(_ inputName: String, _ value: ResolvedInstructionAccountValue?) throws(SolanaError) -> TransactionSigner
public func getAccountMetaFactory(programAddress: Address, optionalAccountStrategy: OptionalAccountStrategy) -> AccountMetaFactory
public func addSelfFetchFunctions<C: Codec, Client: ClientWithRpc>(client: Client, codec: C) -> SelfFetchingCodec<C> where C.Decoded: Sendable
public func addSelfPlanAndSendFunctions(client: any ClientWithTransactionPlanning & ClientWithTransactionSending, input: Instruction) -> SelfPlanAndSendItem<Instruction>
public func addSelfPlanAndSendFunctions(client: any ClientWithTransactionPlanning & ClientWithTransactionSending, input: InstructionPlans.InstructionPlan) -> SelfPlanAndSendItem<InstructionPlans.InstructionPlan>
public func addSelfPlanAndSendFunctions(client: any ClientWithTransactionPlanning & ClientWithTransactionSending, input: @escaping @Sendable () async throws -> Instruction) -> SelfPlanAndSendItem<@Sendable () async throws -> Instruction>
public func addSelfPlanAndSendFunctions(client: any ClientWithTransactionPlanning & ClientWithTransactionSending, input: @escaping @Sendable () async throws -> InstructionPlans.InstructionPlan) -> SelfPlanAndSendItem<@Sendable () async throws -> InstructionPlans.InstructionPlan>
public func addSelfPlanAndSendFunctions<Input: Sendable>(client: any ClientWithTransactionPlanning & ClientWithTransactionSending, input: @escaping @Sendable () async throws -> Input, resolveInstructionPlanInput: @escaping @Sendable (Input) throws -> InstructionPlans.InstructionPlanInput) -> SelfPlanAndSendItem<@Sendable () async throws -> Input>
