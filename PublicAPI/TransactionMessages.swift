import Addresses
import CodecsCore
import Foundation
import Instructions
import SolanaErrors

public typealias Blockhash = String
public typealias Nonce = String

public struct AddressesByLookupTableAddress: Sendable, Equatable, ExpressibleByDictionaryLiteral {
    public init()
    public init(dictionaryLiteral elements: (Address, [Address])...)
    public init(_ entries: [(Address, [Address])])
    public init(_ values: [Address: [Address]])
    public subscript(lookupTableAddress: Address) -> [Address]? { get }
    public var isEmpty: Bool { get }
    public var lookupTableAddresses: [Address] { get }
}

public enum TransactionVersion: Sendable, Equatable, Hashable {
    case legacy
    case v0
    case v1
    case unsupported(Int)
    public static let maxSupported: Int
    public var number: Int? { get }
    public init(number: Int)
}

public struct TransactionMessageFeePayer: Sendable, Equatable, Hashable {
    public let address: Address
    public init(address: Address)
}

public struct BlockhashLifetimeConstraint: Sendable, Equatable, Hashable {
    public let blockhash: Blockhash
    public let lastValidBlockHeight: UInt64
    public init(blockhash: Blockhash, lastValidBlockHeight: UInt64)
}

public struct NonceLifetimeConstraint: Sendable, Equatable, Hashable {
    public let nonce: Nonce
    public init(nonce: Nonce)
}

public struct DurableNonceConfig: Sendable, Equatable, Hashable {
    public let nonce: Nonce
    public let nonceAccountAddress: Address
    public let nonceAuthorityAddress: Address
    public init(nonce: Nonce, nonceAccountAddress: Address, nonceAuthorityAddress: Address)
}

public enum TransactionMessageLifetimeConstraint: Sendable, Equatable, Hashable {
    case blockhash(BlockhashLifetimeConstraint)
    case nonce(NonceLifetimeConstraint)
    public var lifetimeToken: String { get }
}

public struct V1TransactionConfig: Sendable, Equatable, Hashable {
    public let computeUnitLimit: Int?
    public let heapSize: Int?
    public let loadedAccountsDataSizeLimit: Int?
    public let priorityFeeLamports: UInt64?
    public init(
        computeUnitLimit: Int? = nil,
        heapSize: Int? = nil,
        loadedAccountsDataSizeLimit: Int? = nil,
        priorityFeeLamports: UInt64? = nil
    )
    public var isEmpty: Bool { get }
}

public enum V1TransactionConfigField<Value: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    case unchanged
    case set(Value)
    case remove
}

public struct V1TransactionConfigPatch: Sendable, Equatable, Hashable {
    public let computeUnitLimit: V1TransactionConfigField<Int>
    public let heapSize: V1TransactionConfigField<Int>
    public let loadedAccountsDataSizeLimit: V1TransactionConfigField<Int>
    public let priorityFeeLamports: V1TransactionConfigField<UInt64>
    public init(
        computeUnitLimit: V1TransactionConfigField<Int> = .unchanged,
        heapSize: V1TransactionConfigField<Int> = .unchanged,
        loadedAccountsDataSizeLimit: V1TransactionConfigField<Int> = .unchanged,
        priorityFeeLamports: V1TransactionConfigField<UInt64> = .unchanged
    )
}

public struct TransactionMessage: Sendable, Equatable, Hashable {
    public let version: TransactionVersion
    public let instructions: [Instruction]
    public let feePayer: TransactionMessageFeePayer?
    public let lifetimeConstraint: TransactionMessageLifetimeConstraint?
    public let config: V1TransactionConfig?
    public init(
        version: TransactionVersion,
        instructions: [Instruction] = [],
        feePayer: TransactionMessageFeePayer? = nil,
        lifetimeConstraint: TransactionMessageLifetimeConstraint? = nil,
        config: V1TransactionConfig? = nil
    )
}

public struct MessageHeader: Sendable, Equatable, Hashable {
    public let numReadonlyNonSignerAccounts: Int
    public let numReadonlySignerAccounts: Int
    public let numSignerAccounts: Int
    public init(numReadonlyNonSignerAccounts: Int, numReadonlySignerAccounts: Int, numSignerAccounts: Int)
}

public struct CompiledInstruction: Sendable, Equatable, Hashable {
    public let accountIndices: [Int]?
    public let data: Data?
    public let programAddressIndex: Int
    public init(accountIndices: [Int]? = nil, data: Data? = nil, programAddressIndex: Int)
}

public struct AddressTableLookup: Sendable, Equatable, Hashable {
    public let lookupTableAddress: Address
    public let readonlyIndexes: [Int]
    public let writableIndexes: [Int]
    public init(lookupTableAddress: Address, readonlyIndexes: [Int], writableIndexes: [Int])
}

public enum CompiledTransactionConfigValue: Sendable, Equatable, Hashable {
    case u32(Int)
    case u64(UInt64)
}

public struct InstructionHeader: Sendable, Equatable, Hashable {
    public let numInstructionAccounts: Int
    public let numInstructionDataBytes: Int
    public let programAccountIndex: Int
    public init(numInstructionAccounts: Int, numInstructionDataBytes: Int, programAccountIndex: Int)
}

public struct InstructionPayload: Sendable, Equatable, Hashable {
    public let instructionAccountIndices: [Int]
    public let instructionData: Data
    public init(instructionAccountIndices: [Int], instructionData: Data)
}

public struct LegacyCompiledTransactionMessage: Sendable, Equatable, Hashable {
    public let header: MessageHeader
    public let instructions: [CompiledInstruction]
    public let lifetimeToken: String?
    public let staticAccounts: [Address]
    public let version: TransactionVersion
    public init(
        header: MessageHeader,
        instructions: [CompiledInstruction],
        lifetimeToken: String? = nil,
        staticAccounts: [Address],
        version: TransactionVersion = .legacy
    )
}

public struct V0CompiledTransactionMessage: Sendable, Equatable, Hashable {
    public let addressTableLookups: [AddressTableLookup]?
    public let header: MessageHeader
    public let instructions: [CompiledInstruction]
    public let lifetimeToken: String?
    public let staticAccounts: [Address]
    public let version: TransactionVersion
    public init(
        addressTableLookups: [AddressTableLookup]? = nil,
        header: MessageHeader,
        instructions: [CompiledInstruction],
        lifetimeToken: String? = nil,
        staticAccounts: [Address],
        version: TransactionVersion = .v0
    )
}

public struct V1CompiledTransactionMessage: Sendable, Equatable, Hashable {
    public let configMask: Int
    public let configValues: [CompiledTransactionConfigValue]
    public let header: MessageHeader
    public let instructionHeaders: [InstructionHeader]
    public let instructionPayloads: [InstructionPayload]
    public let lifetimeToken: String?
    public let numInstructions: Int
    public let numStaticAccounts: Int
    public let staticAccounts: [Address]
    public let version: TransactionVersion
    public init(
        configMask: Int,
        configValues: [CompiledTransactionConfigValue],
        header: MessageHeader,
        instructionHeaders: [InstructionHeader],
        instructionPayloads: [InstructionPayload],
        lifetimeToken: String? = nil,
        numInstructions: Int,
        numStaticAccounts: Int,
        staticAccounts: [Address],
        version: TransactionVersion = .v1
    )
}

public enum CompiledTransactionMessage: Sendable, Equatable, Hashable {
    case legacy(LegacyCompiledTransactionMessage)
    case v0(V0CompiledTransactionMessage)
    case v1(V1CompiledTransactionMessage)
    public var version: TransactionVersion { get }
    public var lifetimeToken: String? { get }
}

public struct DecompileTransactionMessageConfig: Sendable, Equatable {
    public let addressesByLookupTableAddress: AddressesByLookupTableAddress
    public let lastValidBlockHeight: UInt64?
    public init(addressesByLookupTableAddress: AddressesByLookupTableAddress = [:], lastValidBlockHeight: UInt64? = nil)
}

public let computeBudgetProgramAddress: Address
public let maximumComputeUnitLimit: Int
public let transactionConfigPriorityFeeLamportsBitMask: Int
public let transactionConfigComputeUnitLimitBitMask: Int
public let transactionConfigLoadedAccountsDataSizeLimitBitMask: Int
public let transactionConfigHeapSizeBitMask: Int

public func createTransactionMessage(version: TransactionVersion) -> TransactionMessage
public func setTransactionMessageFeePayer(_ feePayer: Address, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func setTransactionMessageLifetimeUsingBlockhash(_ constraint: BlockhashLifetimeConstraint, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func isTransactionMessageWithBlockhashLifetime(_ transactionMessage: TransactionMessage) -> Bool
public func assertIsTransactionMessageWithBlockhashLifetime(_ transactionMessage: TransactionMessage) throws(SolanaError)
public func setTransactionMessageLifetimeUsingDurableNonce(_ config: DurableNonceConfig, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func isTransactionMessageWithDurableNonceLifetime(_ transactionMessage: TransactionMessage) -> Bool
public func assertIsTransactionMessageWithDurableNonceLifetime(_ transactionMessage: TransactionMessage) throws(SolanaError)
public func createAdvanceNonceAccountInstruction(nonceAccountAddress: Address, nonceAuthorityAddress: Address) -> Instruction
public func isAdvanceNonceAccountInstruction(_ instruction: Instruction) -> Bool
public func appendTransactionMessageInstruction(_ instruction: Instruction, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func appendTransactionMessageInstructions(_ instructions: [Instruction], _ transactionMessage: TransactionMessage) -> TransactionMessage
public func prependTransactionMessageInstruction(_ instruction: Instruction, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func prependTransactionMessageInstructions(_ instructions: [Instruction], _ transactionMessage: TransactionMessage) -> TransactionMessage
public func compressTransactionMessageUsingAddressLookupTables(_ transactionMessage: TransactionMessage, addressesByLookupTableAddress: AddressesByLookupTableAddress) -> TransactionMessage

public func getSetComputeUnitLimitInstruction(_ units: Int) throws -> Instruction
public func isSetComputeUnitLimitInstruction(_ instruction: Instruction) -> Bool
public func getComputeUnitLimitFromInstructionData(_ data: Data) throws -> Int
public func getTransactionMessageComputeUnitLimit(_ transactionMessage: TransactionMessage) throws -> Int?
public func setTransactionMessageComputeUnitLimit(_ computeUnitLimit: Int?, _ transactionMessage: TransactionMessage) throws -> TransactionMessage
public func getSetComputeUnitPriceInstruction(_ microLamports: UInt64) -> Instruction
public func isSetComputeUnitPriceInstruction(_ instruction: Instruction) -> Bool
public func getPriorityFeeFromInstructionData(_ data: Data) throws -> UInt64
public func getTransactionMessageComputeUnitPrice(_ transactionMessage: TransactionMessage) throws -> UInt64?
public func setTransactionMessageComputeUnitPrice(_ computeUnitPrice: UInt64?, _ transactionMessage: TransactionMessage) throws -> TransactionMessage
public func getRequestHeapFrameInstruction(_ bytes: Int) throws -> Instruction
public func isRequestHeapFrameInstruction(_ instruction: Instruction) -> Bool
public func getHeapSizeFromInstructionData(_ data: Data) throws -> Int
public func getTransactionMessageHeapSize(_ transactionMessage: TransactionMessage) throws -> Int?
public func setTransactionMessageHeapSize(_ heapSize: Int?, _ transactionMessage: TransactionMessage) throws -> TransactionMessage
public func getSetLoadedAccountsDataSizeLimitInstruction(_ limit: Int) throws -> Instruction
public func isSetLoadedAccountsDataSizeLimitInstruction(_ instruction: Instruction) -> Bool
public func getLoadedAccountsDataSizeLimitFromInstructionData(_ data: Data) throws -> Int
public func getTransactionMessageLoadedAccountsDataSizeLimit(_ transactionMessage: TransactionMessage) throws -> Int?
public func setTransactionMessageLoadedAccountsDataSizeLimit(_ loadedAccountsDataSizeLimit: Int?, _ transactionMessage: TransactionMessage) throws -> TransactionMessage
public func getTransactionMessagePriorityFeeLamports(_ transactionMessage: TransactionMessage) -> UInt64?
public func setTransactionMessagePriorityFeeLamports(_ priorityFeeLamports: UInt64?, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func setTransactionMessageConfig(_ config: V1TransactionConfig, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func setTransactionMessageConfig(_ patch: V1TransactionConfigPatch, _ transactionMessage: TransactionMessage) -> TransactionMessage
public func transactionConfigMaskHasPriorityFee(_ mask: Int) throws(SolanaError) -> Bool
public func transactionConfigMaskHasComputeUnitLimit(_ mask: Int) -> Bool
public func transactionConfigMaskHasLoadedAccountsDataSizeLimit(_ mask: Int) -> Bool
public func transactionConfigMaskHasHeapSize(_ mask: Int) -> Bool
public func getTransactionConfigMask(_ config: V1TransactionConfig) -> Int
public func getTransactionConfigValues(_ config: V1TransactionConfig) -> [CompiledTransactionConfigValue]

public func getCompiledMessageHeader(_ orderedAccounts: [InstructionAccount]) -> MessageHeader
public func getCompiledInstructions(_ instructions: [Instruction], orderedAccounts: [InstructionAccount]) throws -> [CompiledInstruction]
public func getCompiledStaticAccounts(_ orderedAccounts: [InstructionAccount]) -> [Address]
public func getCompiledAddressTableLookups(_ orderedAccounts: [InstructionAccount]) -> [AddressTableLookup]
public func getInstructionHeader(_ instruction: Instruction, accountIndex: [Address: Int]) throws -> InstructionHeader
public func getInstructionPayload(_ instruction: Instruction, accountIndex: [Address: Int]) throws -> InstructionPayload
public func compileTransactionMessage(_ transactionMessage: TransactionMessage) throws -> CompiledTransactionMessage
public func decompileTransactionMessage(_ compiledTransactionMessage: CompiledTransactionMessage, config: DecompileTransactionMessageConfig = DecompileTransactionMessageConfig()) throws -> TransactionMessage
public func decompileTransactionConfig(configMask: Int, configValues: [CompiledTransactionConfigValue]) throws -> V1TransactionConfig
public func decompileInstructions(instructionHeaders: [InstructionHeader], instructionPayloads: [InstructionPayload], accountMetas: [AccountMeta]) throws -> [Instruction]

public func getTransactionVersionEncoder() -> AnyVariableSizeEncoder<TransactionVersion>
public func getTransactionVersionDecoder() -> AnyVariableSizeDecoder<TransactionVersion>
public func getTransactionVersionCodec() -> AnyVariableSizeCodec<TransactionVersion, TransactionVersion>
public func getCompiledTransactionMessageEncoder() -> AnyVariableSizeEncoder<CompiledTransactionMessage>
public func getCompiledTransactionMessageDecoder() -> AnyVariableSizeDecoder<CompiledTransactionMessage>
public func getCompiledTransactionMessageCodec() -> AnyVariableSizeCodec<CompiledTransactionMessage, CompiledTransactionMessage>
