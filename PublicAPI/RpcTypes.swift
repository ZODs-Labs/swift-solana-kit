public import Addresses
public import CodecsCore
public import FixedPoints
public import Foundation

public enum Commitment: String, Sendable, Equatable, Hashable, Codable, Comparable {
    case processed
    case confirmed
    case finalized

    public static func < (lhs: Commitment, rhs: Commitment) -> Bool
}

public func commitmentComparator(_ lhs: Commitment, _ rhs: Commitment) -> Int

public typealias Blockhash = String
public func isBlockhash(_ putativeBlockhash: String) -> Bool
public func assertIsBlockhash(_ putativeBlockhash: String) throws
public func blockhash(_ putativeBlockhash: String) throws -> Blockhash
public func getBlockhashEncoder() -> AnyFixedSizeEncoder<Blockhash>
public func getBlockhashDecoder() -> AnyFixedSizeDecoder<Blockhash>
public func getBlockhashCodec() -> AnyFixedSizeCodec<Blockhash, Blockhash>
public func getBlockhashComparator() -> @Sendable (String, String) -> Int

public typealias Lamports = UInt64
public func isLamports(_ putativeLamports: UInt64) -> Bool
public func assertIsLamports(_ putativeLamports: UInt64) throws
public func lamports(_ putativeLamports: UInt64) -> Lamports
public func getDefaultLamportsEncoder() -> AnyFixedSizeEncoder<Lamports>
public func getDefaultLamportsDecoder() -> AnyFixedSizeDecoder<Lamports>
public func getDefaultLamportsCodec() -> AnyFixedSizeCodec<Lamports, Lamports>
public func getLamportsEncoder<C: FixedSizeEncoder>(_ innerEncoder: C) -> AnyFixedSizeEncoder<Lamports> where C.Encoded == UInt64
public func getLamportsDecoder<D: FixedSizeDecoder>(_ innerDecoder: D) -> AnyFixedSizeDecoder<Lamports> where D.Decoded == UInt64
public func getLamportsCodec<C: FixedSizeCodec>(_ innerCodec: C) -> AnyFixedSizeCodec<Lamports, Lamports> where C.Encoded == UInt64, C.Decoded == UInt64
public func getLamportsEncoder<C: FixedSizeEncoder>(_ innerEncoder: C) -> AnyFixedSizeEncoder<Lamports> where C.Encoded == Int
public func getLamportsDecoder<D: FixedSizeDecoder>(_ innerDecoder: D) -> AnyFixedSizeDecoder<Lamports> where D.Decoded == Int
public func getLamportsCodec<C: FixedSizeCodec>(_ innerCodec: C) -> AnyFixedSizeCodec<Lamports, Lamports> where C.Encoded == Int, C.Decoded == Int

public typealias Sol = DecimalFixedPoint
public func sol(_ value: String, rounding: RoundingMode = .strict) throws -> Sol
public func solToLamports(_ value: Sol) throws -> Lamports
public func lamportsToSol(_ value: Lamports) throws -> Sol
public func getSolEncoder() -> AnyFixedSizeEncoder<Sol>
public func getSolDecoder() -> AnyFixedSizeDecoder<Sol>
public func getSolCodec() -> AnyFixedSizeCodec<Sol, Sol>

public typealias StringifiedBigInt = String
public func isStringifiedBigInt(_ putativeBigInt: String) -> Bool
public func assertIsStringifiedBigInt(_ putativeBigInt: String) throws
public func stringifiedBigInt(_ putativeBigInt: String) throws -> StringifiedBigInt

public typealias StringifiedNumber = String
public func isStringifiedNumber(_ putativeNumber: String) -> Bool
public func assertIsStringifiedNumber(_ putativeNumber: String) throws
public func stringifiedNumber(_ putativeNumber: String) throws -> StringifiedNumber

public typealias Slot = UInt64
public typealias Epoch = UInt64
public typealias MicroLamports = UInt64
public typealias SignedLamports = Int64
public typealias F64UnsafeSeeDocumentation = Double

public typealias UnixTimestamp = Int64
public func isUnixTimestamp(_ putativeTimestamp: Int64) -> Bool
public func assertIsUnixTimestamp(_ putativeTimestamp: Int64) throws
public func unixTimestamp(_ putativeTimestamp: Int64) -> UnixTimestamp

public typealias Base58EncodedBytes = String
public typealias Base64EncodedBytes = String
public typealias Base64EncodedZStdCompressedBytes = String

public struct Base58EncodedDataResponse: Sendable, Equatable, Hashable, Codable {
    public let bytes: Base58EncodedBytes
    public let encoding: String
    public init(_ bytes: Base58EncodedBytes, encoding: String = "base58")
    public init(from decoder: any Swift.Decoder) throws
    public func encode(to encoder: any Swift.Encoder) throws
}

public struct Base64EncodedDataResponse: Sendable, Equatable, Hashable, Codable {
    public let bytes: Base64EncodedBytes
    public let encoding: String
    public init(_ bytes: Base64EncodedBytes, encoding: String = "base64")
    public init(from decoder: any Swift.Decoder) throws
    public func encode(to encoder: any Swift.Encoder) throws
}

public struct Base64EncodedZStdCompressedDataResponse: Sendable, Equatable, Hashable, Codable {
    public let bytes: Base64EncodedZStdCompressedBytes
    public let encoding: String
    public init(_ bytes: Base64EncodedZStdCompressedBytes, encoding: String = "base64+zstd")
    public init(from decoder: any Swift.Decoder) throws
    public func encode(to encoder: any Swift.Encoder) throws
}

public indirect enum RpcTypeJsonValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case string(String)
    case number(String)
    case array([RpcTypeJsonValue])
    case object([String: RpcTypeJsonValue])
}

public struct DataSlice: Sendable, Equatable, Hashable, Codable {
    public let length: Int
    public let offset: Int
    public init(length: Int, offset: Int)
}

public enum ProgramNotificationsMemcmpFilterEncoding: String, Sendable, Equatable, Hashable, Codable {
    case base58
    case base64
}

public struct ProgramNotificationsMemcmpFilter: Sendable, Equatable, Hashable, Codable {
    public let bytes: String
    public let encoding: ProgramNotificationsMemcmpFilterEncoding
    public let offset: UInt64
    public init(bytes: String, encoding: ProgramNotificationsMemcmpFilterEncoding, offset: UInt64)
}

public struct GetProgramAccountsMemcmpFilter: Sendable, Equatable, Hashable, Codable {
    public let memcmp: ProgramNotificationsMemcmpFilter
    public init(memcmp: ProgramNotificationsMemcmpFilter)
}

public struct GetProgramAccountsDatasizeFilter: Sendable, Equatable, Hashable, Codable {
    public let dataSize: UInt64
    public init(dataSize: UInt64)
}

public enum GetProgramAccountsFilter: Sendable, Equatable, Hashable, Codable {
    case memcmp(GetProgramAccountsMemcmpFilter)
    case dataSize(GetProgramAccountsDatasizeFilter)
}

public struct AccountInfoBase: Sendable, Equatable, Hashable {
    public let executable: Bool
    public let lamports: Lamports
    public let owner: Address
    public let space: UInt64
    public init(executable: Bool, lamports: Lamports, owner: Address, space: UInt64)
}

public struct AccountInfoWithBase58Bytes: Sendable, Equatable, Hashable {
    public let data: Base58EncodedBytes
    public init(data: Base58EncodedBytes)
}

public struct AccountInfoWithBase58EncodedData: Sendable, Equatable, Hashable {
    public let data: Base58EncodedDataResponse
    public init(data: Base58EncodedDataResponse)
}

public struct AccountInfoWithBase64EncodedData: Sendable, Equatable, Hashable {
    public let data: Base64EncodedDataResponse
    public init(data: Base64EncodedDataResponse)
}

public struct AccountInfoWithBase64EncodedZStdCompressedData: Sendable, Equatable, Hashable {
    public let data: Base64EncodedZStdCompressedDataResponse
    public init(data: Base64EncodedZStdCompressedDataResponse)
}

public struct AccountInfoParsedData: Sendable, Equatable, Hashable {
    public let info: RpcTypeJsonValue?
    public let type: String
    public init(info: RpcTypeJsonValue? = nil, type: String)
}

public struct AccountInfoJsonParsedData: Sendable, Equatable, Hashable {
    public let parsed: AccountInfoParsedData
    public let program: String
    public let space: UInt64
    public init(parsed: AccountInfoParsedData, program: String, space: UInt64)
}

public enum AccountInfoJsonData: Sendable, Equatable, Hashable {
    case base64(Base64EncodedDataResponse)
    case parsed(AccountInfoJsonParsedData)
}

public struct AccountInfoWithJsonData: Sendable, Equatable, Hashable {
    public let data: AccountInfoJsonData
    public init(data: AccountInfoJsonData)
}

public struct AccountInfoWithPubkey<Account: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let account: Account
    public let pubkey: Address
    public init(account: Account, pubkey: Address)
}

public struct TokenAmount: Sendable, Equatable, Hashable {
    public let amount: StringifiedBigInt
    public let decimals: Int
    public let uiAmount: F64UnsafeSeeDocumentation?
    public let uiAmountString: StringifiedNumber
    public init(amount: StringifiedBigInt, decimals: Int, uiAmount: F64UnsafeSeeDocumentation?, uiAmountString: StringifiedNumber)
}

public struct TokenBalance: Sendable, Equatable, Hashable {
    public let accountIndex: Int
    public let mint: Address
    public let owner: Address?
    public let programId: Address?
    public let uiTokenAmount: TokenAmount
    public init(accountIndex: Int, mint: Address, owner: Address? = nil, programId: Address? = nil, uiTokenAmount: TokenAmount)
}

public enum RpcInstructionError: Sendable, Equatable, Hashable {
    case accountAlreadyInitialized
    case accountBorrowFailed
    case accountBorrowOutstanding
    case accountDataSizeChanged
    case accountDataTooSmall
    case accountNotExecutable
    case accountNotRentExempt
    case arithmeticOverflow
    case borshIoError
    case builtinProgramsMustConsumeComputeUnits
    case callDepth
    case computationalBudgetExceeded
    case duplicateAccountIndex
    case duplicateAccountOutOfSync
    case executableAccountNotRentExempt
    case executableDataModified
    case executableLamportChange
    case executableModified
    case externalAccountDataModified
    case externalAccountLamportSpend
    case genericError
    case illegalOwner
    case immutable
    case incorrectAuthority
    case incorrectProgramId
    case insufficientFunds
    case invalidAccountData
    case invalidAccountOwner
    case invalidArgument
    case invalidError
    case invalidInstructionData
    case invalidRealloc
    case invalidSeeds
    case maxAccountsDataAllocationsExceeded
    case maxAccountsExceeded
    case maxInstructionTraceLengthExceeded
    case maxSeedLengthExceeded
    case missingAccount
    case missingRequiredSignature
    case modifiedProgramId
    case notEnoughAccountKeys
    case privilegeEscalation
    case programEnvironmentSetupFailure
    case programFailedToCompile
    case programFailedToComplete
    case readonlyDataModified
    case readonlyLamportChange
    case reentrancyNotAllowed
    case rentEpochModified
    case unbalancedInstruction
    case uninitializedAccount
    case unsupportedProgramId
    case unsupportedSysvar
    case custom(Int)
}

public enum RpcTransactionError: Sendable, Equatable, Hashable {
    case accountBorrowOutstanding
    case accountInUse
    case accountLoadedTwice
    case accountNotFound
    case addressLookupTableNotFound
    case alreadyProcessed
    case blockhashNotFound
    case callChainTooDeep
    case clusterMaintenance
    case insufficientFundsForFee
    case invalidAccountForFee
    case invalidAccountIndex
    case invalidAddressLookupTableData
    case invalidAddressLookupTableIndex
    case invalidAddressLookupTableOwner
    case invalidLoadedAccountsDataSizeLimit
    case invalidProgramForExecution
    case invalidRentPayingAccount
    case invalidWritableAccount
    case maxLoadedAccountsDataSizeExceeded
    case missingSignatureForFee
    case programAccountNotFound
    case resanitizationNeeded
    case sanitizeFailure
    case signatureFailure
    case tooManyAccountLocks
    case unbalancedTransaction
    case unsupportedVersion
    case wouldExceedAccountDataBlockLimit
    case wouldExceedAccountDataTotalLimit
    case wouldExceedMaxAccountCostLimit
    case wouldExceedMaxBlockCostLimit
    case wouldExceedMaxVoteCostLimit
    case duplicateInstruction(Int)
    case instructionError(index: Int, error: RpcInstructionError)
    case insufficientFundsForRent(accountIndex: Int)
    case programExecutionTemporarilyRestricted(accountIndex: Int)
    case unknown(String)
}

public enum TransactionStatus: Sendable, Equatable, Hashable {
    case ok
    case err(RpcTransactionError)
}

public enum RpcTransactionVersion: Sendable, Equatable, Hashable {
    case legacy
    case number(Int)
}

public struct RpcAddressTableLookup: Sendable, Equatable, Hashable {
    public let accountKey: Address
    public let readonlyIndexes: [Int]
    public let writableIndexes: [Int]
    public init(accountKey: Address, readonlyIndexes: [Int], writableIndexes: [Int])
}

public struct ParsedTransactionInstruction: Sendable, Equatable, Hashable {
    public let parsed: AccountInfoParsedData
    public let program: String
    public let programId: Address
    public let stackHeight: Int?
    public init(parsed: AccountInfoParsedData, program: String, programId: Address, stackHeight: Int? = nil)
}

public struct PartiallyDecodedTransactionInstruction: Sendable, Equatable, Hashable {
    public let accounts: [Address]
    public let data: Base58EncodedBytes
    public let programId: Address
    public let stackHeight: Int?
    public init(accounts: [Address], data: Base58EncodedBytes, programId: Address, stackHeight: Int? = nil)
}

public struct TransactionInstruction: Sendable, Equatable, Hashable {
    public let accounts: [Int]
    public let data: Base58EncodedBytes
    public let programIdIndex: Int
    public let stackHeight: Int?
    public init(accounts: [Int], data: Base58EncodedBytes, programIdIndex: Int, stackHeight: Int? = nil)
}

public struct ReturnData: Sendable, Equatable, Hashable {
    public let data: Base64EncodedDataResponse
    public let programId: Address
    public init(data: Base64EncodedDataResponse, programId: Address)
}

public enum TransactionParsedAccountSource: String, Sendable, Equatable, Hashable, Codable {
    case lookupTable
    case transaction
}

public struct TransactionParsedAccount: Sendable, Equatable, Hashable {
    public let pubkey: Address
    public let signer: Bool
    public let source: TransactionParsedAccountSource
    public let writable: Bool
    public init(pubkey: Address, signer: Bool, source: TransactionParsedAccountSource, writable: Bool)
}

public enum RewardType: String, Sendable, Equatable, Hashable, Codable {
    case fee = "Fee"
    case rent = "Rent"
    case staking = "Staking"
    case voting = "Voting"
}

public struct RewardBase: Sendable, Equatable, Hashable {
    public let lamports: SignedLamports
    public let postBalance: Lamports
    public let pubkey: Address
    public init(lamports: SignedLamports, postBalance: Lamports, pubkey: Address)
}

public struct RewardWithCommission: Sendable, Equatable, Hashable {
    public let base: RewardBase
    public let commission: Int
    public init(base: RewardBase, commission: Int)
}

public enum Reward: Sendable, Equatable, Hashable {
    case fee(RewardBase)
    case rent(RewardBase)
    case staking(RewardWithCommission)
    case voting(RewardWithCommission)
    public var commission: Int? { get }
    public var lamports: SignedLamports { get }
    public var postBalance: Lamports { get }
    public var pubkey: Address { get }
    public var rewardType: RewardType { get }
    public init(commission: Int? = nil, lamports: SignedLamports, postBalance: Lamports, pubkey: Address, rewardType: RewardType)
}

public struct TransactionMessageHeader: Sendable, Equatable, Hashable {
    public let numReadonlySignedAccounts: Int
    public let numReadonlyUnsignedAccounts: Int
    public let numRequiredSignatures: Int
    public init(numReadonlySignedAccounts: Int, numReadonlyUnsignedAccounts: Int, numRequiredSignatures: Int)
}

public struct TransactionMessageBase: Sendable, Equatable, Hashable {
    public let header: TransactionMessageHeader
    public let recentBlockhash: Blockhash
    public init(header: TransactionMessageHeader, recentBlockhash: Blockhash)
}

public struct TransactionWithSignatures: Sendable, Equatable, Hashable {
    public let signatures: [Base58EncodedBytes]
    public init(signatures: [Base58EncodedBytes])
}

public typealias TransactionParsedAccountLegacy = TransactionParsedAccount
public typealias TransactionParsedAccountVersioned = TransactionParsedAccount

public struct TransactionForAccountsLegacyTransaction: Sendable, Equatable, Hashable {
    public let accountKeys: [TransactionParsedAccountLegacy]
    public let signatures: [Base58EncodedBytes]
    public init(accountKeys: [TransactionParsedAccountLegacy], signatures: [Base58EncodedBytes])
}

public struct TransactionForAccountsVersionedTransaction: Sendable, Equatable, Hashable {
    public let accountKeys: [TransactionParsedAccountVersioned]
    public let signatures: [Base58EncodedBytes]
    public init(accountKeys: [TransactionParsedAccountVersioned], signatures: [Base58EncodedBytes])
}

public struct TransactionForAccountsLegacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForAccountsMetaBase?
    public let transaction: TransactionForAccountsLegacyTransaction
    public init(meta: TransactionForAccountsMetaBase?, transaction: TransactionForAccountsLegacyTransaction)
}

public struct TransactionForAccountsVersioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForAccountsMetaBase?
    public let transaction: TransactionForAccountsVersionedTransaction
    public let version: RpcTransactionVersion
    public init(meta: TransactionForAccountsMetaBase?, transaction: TransactionForAccountsVersionedTransaction, version: RpcTransactionVersion)
}

public enum TransactionInstructionResponse: Sendable, Equatable, Hashable {
    case parsed(ParsedTransactionInstruction)
    case partiallyDecoded(PartiallyDecodedTransactionInstruction)
}

public struct TransactionForFullMetaInnerInstruction<Instruction: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let index: Int
    public let instructions: [Instruction]
    public init(index: Int, instructions: [Instruction])
}

public struct TransactionForFullMetaInnerInstructionsUnparsed: Sendable, Equatable, Hashable {
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>]
    public init(innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>])
}

public struct TransactionForFullMetaInnerInstructionsParsed: Sendable, Equatable, Hashable {
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>]
    public init(innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>])
}

public struct TransactionLoadedAddresses: Sendable, Equatable, Hashable {
    public let readonly: [Address]
    public let writable: [Address]
    public init(readonly: [Address], writable: [Address])
}

public struct TransactionForFullTransactionAddressTableLookups: Sendable, Equatable, Hashable {
    public let addressTableLookups: [RpcAddressTableLookup]?
    public init(addressTableLookups: [RpcAddressTableLookup]? = nil)
}

public struct TransactionForFullJsonMessage: Sendable, Equatable, Hashable {
    public let accountKeys: [Address]
    public let addressTableLookups: [RpcAddressTableLookup]?
    public let header: TransactionMessageHeader
    public let instructions: [TransactionInstruction]
    public let recentBlockhash: Blockhash
    public var base: TransactionMessageBase { get }
    public init(accountKeys: [Address], base: TransactionMessageBase, instructions: [TransactionInstruction])
    public init(
        accountKeys: [Address],
        addressTableLookups: [RpcAddressTableLookup]? = nil,
        header: TransactionMessageHeader,
        instructions: [TransactionInstruction],
        recentBlockhash: Blockhash
    )
}

public struct TransactionForFullJsonParsedMessage: Sendable, Equatable, Hashable {
    public let accountKeys: [TransactionParsedAccount]
    public let header: TransactionMessageHeader
    public let instructions: [TransactionInstructionResponse]
    public let recentBlockhash: Blockhash
    public var base: TransactionMessageBase { get }
    public init(accountKeys: [TransactionParsedAccount], base: TransactionMessageBase, instructions: [TransactionInstructionResponse])
    public init(accountKeys: [TransactionParsedAccount], header: TransactionMessageHeader, instructions: [TransactionInstructionResponse], recentBlockhash: Blockhash)
}

public struct TransactionForFullJsonTransaction: Sendable, Equatable, Hashable {
    public let message: TransactionForFullJsonMessage
    public let signatures: [Base58EncodedBytes]
    public var addressTableLookups: [RpcAddressTableLookup]? { get }
    public init(addressTableLookups: [RpcAddressTableLookup]? = nil, message: TransactionForFullJsonMessage, signatures: [Base58EncodedBytes])
}

public struct TransactionForFullJsonParsedTransaction: Sendable, Equatable, Hashable {
    public let message: TransactionForFullJsonParsedMessage
    public let signatures: [Base58EncodedBytes]
    public init(message: TransactionForFullJsonParsedMessage, signatures: [Base58EncodedBytes])
}

public struct TransactionForFullBase58Legacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base58EncodedDataResponse
    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base58EncodedDataResponse)
}

public struct TransactionForFullBase58Versioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base58EncodedDataResponse
    public let version: RpcTransactionVersion
    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base58EncodedDataResponse, version: RpcTransactionVersion)
}

public struct TransactionForFullBase64Legacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base64EncodedDataResponse
    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base64EncodedDataResponse)
}

public struct TransactionForFullBase64Versioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base64EncodedDataResponse
    public let version: RpcTransactionVersion
    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base64EncodedDataResponse, version: RpcTransactionVersion)
}

public struct TransactionForFullJsonLegacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: TransactionForFullJsonTransaction
    public init(meta: TransactionForFullUnparsedMeta?, transaction: TransactionForFullJsonTransaction)
}

public struct TransactionForFullJsonVersioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: TransactionForFullJsonTransaction
    public let version: RpcTransactionVersion
    public init(meta: TransactionForFullUnparsedMeta?, transaction: TransactionForFullJsonTransaction, version: RpcTransactionVersion)
}

public struct TransactionForFullJsonParsedLegacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullParsedMeta?
    public let transaction: TransactionForFullJsonParsedTransaction
    public init(meta: TransactionForFullParsedMeta?, transaction: TransactionForFullJsonParsedTransaction)
}

public struct TransactionForFullJsonParsedVersioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullParsedMeta?
    public let transaction: TransactionForFullJsonParsedTransaction
    public let version: RpcTransactionVersion
    public init(meta: TransactionForFullParsedMeta?, transaction: TransactionForFullJsonParsedTransaction, version: RpcTransactionVersion)
}

public struct TransactionForAccountsMetaBase: Sendable, Equatable, Hashable {
    public let err: RpcTransactionError?
    public let fee: Lamports
    public let postBalances: [Lamports]
    public let postTokenBalances: [TokenBalance]?
    public let preBalances: [Lamports]
    public let preTokenBalances: [TokenBalance]?
    public let status: TransactionStatus
    public init(
        err: RpcTransactionError?,
        fee: Lamports,
        postBalances: [Lamports],
        postTokenBalances: [TokenBalance]? = nil,
        preBalances: [Lamports],
        preTokenBalances: [TokenBalance]? = nil,
        status: TransactionStatus
    )
}

public struct TransactionForFullMetaBase: Sendable, Equatable, Hashable {
    public let computeUnitsConsumed: UInt64?
    public let err: RpcTransactionError?
    public let fee: Lamports
    public let logMessages: [String]?
    public let postBalances: [Lamports]
    public let postTokenBalances: [TokenBalance]?
    public let preBalances: [Lamports]
    public let preTokenBalances: [TokenBalance]?
    public let returnData: ReturnData?
    public let rewards: [Reward]?
    public let status: TransactionStatus
    public var accountsMeta: TransactionForAccountsMetaBase { get }
    public init(
        accountsMeta: TransactionForAccountsMetaBase,
        computeUnitsConsumed: UInt64? = nil,
        logMessages: [String]?,
        returnData: ReturnData? = nil,
        rewards: [Reward]?
    )
    public init(
        err: RpcTransactionError?,
        fee: Lamports,
        postBalances: [Lamports],
        postTokenBalances: [TokenBalance]? = nil,
        preBalances: [Lamports],
        preTokenBalances: [TokenBalance]? = nil,
        status: TransactionStatus,
        computeUnitsConsumed: UInt64? = nil,
        logMessages: [String]?,
        returnData: ReturnData? = nil,
        rewards: [Reward]?
    )
}

public struct TransactionForFullUnparsedMeta: Sendable, Equatable, Hashable {
    public let base: TransactionForFullMetaBase
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>]
    public let loadedAddresses: TransactionLoadedAddresses?
    public var accountsMeta: TransactionForAccountsMetaBase { get }
    public var computeUnitsConsumed: UInt64? { get }
    public var err: RpcTransactionError? { get }
    public var fee: Lamports { get }
    public var logMessages: [String]? { get }
    public var postBalances: [Lamports] { get }
    public var postTokenBalances: [TokenBalance]? { get }
    public var preBalances: [Lamports] { get }
    public var preTokenBalances: [TokenBalance]? { get }
    public var returnData: ReturnData? { get }
    public var rewards: [Reward]? { get }
    public var status: TransactionStatus { get }
    public init(
        base: TransactionForFullMetaBase,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    )
    public init(
        accountsMeta: TransactionForAccountsMetaBase,
        computeUnitsConsumed: UInt64? = nil,
        logMessages: [String]?,
        returnData: ReturnData? = nil,
        rewards: [Reward]?,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    )
}

public struct TransactionForFullParsedMeta: Sendable, Equatable, Hashable {
    public let base: TransactionForFullMetaBase
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>]
    public let loadedAddresses: TransactionLoadedAddresses?
    public var accountsMeta: TransactionForAccountsMetaBase { get }
    public var computeUnitsConsumed: UInt64? { get }
    public var err: RpcTransactionError? { get }
    public var fee: Lamports { get }
    public var logMessages: [String]? { get }
    public var postBalances: [Lamports] { get }
    public var postTokenBalances: [TokenBalance]? { get }
    public var preBalances: [Lamports] { get }
    public var preTokenBalances: [TokenBalance]? { get }
    public var returnData: ReturnData? { get }
    public var rewards: [Reward]? { get }
    public var status: TransactionStatus { get }
    public init(
        base: TransactionForFullMetaBase,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    )
    public init(
        accountsMeta: TransactionForAccountsMetaBase,
        computeUnitsConsumed: UInt64? = nil,
        logMessages: [String]?,
        returnData: ReturnData? = nil,
        rewards: [Reward]?,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    )
}

public struct TransactionForFullMetaLoadedAddresses: Sendable, Equatable, Hashable {
    public let loadedAddresses: TransactionLoadedAddresses
    public var readonly: [Address] { get }
    public var writable: [Address] { get }
    public init(readonly: [Address], writable: [Address])
    public init(loadedAddresses: TransactionLoadedAddresses)
}

public struct SolanaRpcContext: Sendable, Equatable, Hashable {
    public let slot: Slot
    public init(slot: Slot)
}

public struct SolanaRpcResponse<Value: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let context: SolanaRpcContext
    public let value: Value
    public init(context: SolanaRpcContext, value: Value)
}

public typealias MainnetUrl = String
public typealias DevnetUrl = String
public typealias TestnetUrl = String
public typealias ClusterUrl = String
public func mainnet(_ putativeString: String) -> MainnetUrl
public func devnet(_ putativeString: String) -> DevnetUrl
public func testnet(_ putativeString: String) -> TestnetUrl
