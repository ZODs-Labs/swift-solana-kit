public import Addresses
public import CodecsCore
import CodecsNumbers
public import FixedPoints
import SolanaErrors

public enum Commitment: String, Sendable, Equatable, Hashable, Codable, Comparable {
    case processed
    case confirmed
    case finalized

    public static func < (lhs: Commitment, rhs: Commitment) -> Bool {
        commitmentScore(lhs) < commitmentScore(rhs)
    }
}

public func commitmentComparator(_ lhs: Commitment, _ rhs: Commitment) -> Int {
    if lhs == rhs { return 0 }
    return lhs < rhs ? -1 : 1
}

private func commitmentScore(_ commitment: Commitment) -> Int {
    switch commitment {
    case .finalized:
        return 2
    case .confirmed:
        return 1
    case .processed:
        return 0
    }
}

public typealias Blockhash = String

public func isBlockhash(_ putativeBlockhash: String) -> Bool {
    do {
        try assertIsBlockhash(putativeBlockhash)
        return true
    } catch {
        return false
    }
}

public func assertIsBlockhash(_ putativeBlockhash: String) throws {
    do {
        try assertIsAddress(putativeBlockhash)
    } catch AddressValidationError.addresses(let addressError) {
        switch addressError {
        case .stringLengthOutOfRange(let actualLength):
            throw SolanaError(.blockhashStringLengthOutOfRange, context: ["actualLength": .int(actualLength)])
        case .invalidByteLength(let actualLength):
            throw SolanaError(.invalidBlockhashByteLength, context: ["actualLength": .int(actualLength)])
        default:
            throw addressError
        }
    } catch {
        throw error
    }
}

public func blockhash(_ putativeBlockhash: String) throws -> Blockhash {
    try assertIsBlockhash(putativeBlockhash)
    return putativeBlockhash
}

public func getBlockhashEncoder() -> AnyFixedSizeEncoder<Blockhash> {
    let encoder = getAddressEncoder()
    return AnyFixedSizeEncoder<Blockhash>(fixedSize: 32) { value, bytes, offset in
        try assertIsBlockhash(value)
        return try encoder.write(Address(unchecked: value), into: &bytes, at: offset)
    }
}

public func getBlockhashDecoder() -> AnyFixedSizeDecoder<Blockhash> {
    let decoder = getAddressDecoder()
    return AnyFixedSizeDecoder<Blockhash>(fixedSize: 32) { bytes, offset in
        let result = try decoder.read(bytes, at: offset)
        return (result.0.rawValue, result.1)
    }
}

public func getBlockhashCodec() -> AnyFixedSizeCodec<Blockhash, Blockhash> {
    createCodec(fixedSize: 32) { value, bytes, offset in
        try getBlockhashEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getBlockhashDecoder().read(bytes, at: offset)
    }
}

public func getBlockhashComparator() -> @Sendable (String, String) -> Int {
    { lhs, rhs in compareBlockhashStrings(lhs, rhs) }
}

private func compareBlockhashStrings(_ lhs: String, _ rhs: String) -> Int {
    let lhsScalars = Array(lhs.unicodeScalars)
    let rhsScalars = Array(rhs.unicodeScalars)
    let count = Swift.min(lhsScalars.count, rhsScalars.count)

    for index in 0 ..< count {
        let lhsScalar = lhsScalars[index]
        let rhsScalar = rhsScalars[index]
        if lhsScalar == rhsScalar {
            continue
        }

        let lhsFolded = asciiFold(lhsScalar)
        let rhsFolded = asciiFold(rhsScalar)
        if lhsFolded != rhsFolded {
            return lhsFolded < rhsFolded ? -1 : 1
        }

        let lhsIsLowercase = isAsciiLowercase(lhsScalar)
        let rhsIsLowercase = isAsciiLowercase(rhsScalar)
        if lhsIsLowercase != rhsIsLowercase {
            return lhsIsLowercase ? -1 : 1
        }

        return lhsScalar.value < rhsScalar.value ? -1 : 1
    }

    if lhsScalars.count == rhsScalars.count {
        return 0
    }
    return lhsScalars.count < rhsScalars.count ? -1 : 1
}

private func asciiFold(_ scalar: UnicodeScalar) -> UInt32 {
    if scalar.value >= 65 && scalar.value <= 90 {
        return scalar.value + 32
    }
    return scalar.value
}

private func isAsciiLowercase(_ scalar: UnicodeScalar) -> Bool {
    scalar.value >= 97 && scalar.value <= 122
}

public typealias Lamports = UInt64

public func isLamports(_ putativeLamports: UInt64) -> Bool {
    true
}

public func assertIsLamports(_ putativeLamports: UInt64) throws {}

public func lamports(_ putativeLamports: UInt64) -> Lamports {
    putativeLamports
}

public func getDefaultLamportsEncoder() -> AnyFixedSizeEncoder<Lamports> {
    getLamportsEncoder(getU64Encoder())
}

public func getDefaultLamportsDecoder() -> AnyFixedSizeDecoder<Lamports> {
    getLamportsDecoder(getU64Decoder())
}

public func getDefaultLamportsCodec() -> AnyFixedSizeCodec<Lamports, Lamports> {
    getLamportsCodec(getU64Codec())
}

public func getLamportsEncoder<C: FixedSizeEncoder>(_ innerEncoder: C) -> AnyFixedSizeEncoder<Lamports> where C.Encoded == UInt64 {
    transformEncoder(innerEncoder) { (value: Lamports) in value }
}

public func getLamportsDecoder<D: FixedSizeDecoder>(_ innerDecoder: D) -> AnyFixedSizeDecoder<Lamports> where D.Decoded == UInt64 {
    transformDecoder(innerDecoder) { (value: UInt64) in value }
}

public func getLamportsCodec<C: FixedSizeCodec>(_ innerCodec: C) -> AnyFixedSizeCodec<Lamports, Lamports> where C.Encoded == UInt64, C.Decoded == UInt64 {
    transformCodec(innerCodec, encode: { (value: Lamports) in value }, decode: { (value: UInt64) in value })
}

public func getLamportsEncoder<C: FixedSizeEncoder>(_ innerEncoder: C) -> AnyFixedSizeEncoder<Lamports> where C.Encoded == Int {
    transformEncoder(innerEncoder) { (value: Lamports) throws(CodecsError) in
        guard value <= UInt64(Int.max) else {
            throw CodecsError.numberOutOfRange(codecDescription: "lamports", min: "0", max: String(Int.max), value: String(value))
        }
        return Int(value)
    }
}

public func getLamportsDecoder<D: FixedSizeDecoder>(_ innerDecoder: D) -> AnyFixedSizeDecoder<Lamports> where D.Decoded == Int {
    transformDecoder(innerDecoder) { (value: Int) throws(CodecsError) in
        guard value >= 0 else {
            throw CodecsError.numberOutOfRange(codecDescription: "lamports", min: "0", max: String(UInt64.max), value: String(value))
        }
        return UInt64(value)
    }
}

public func getLamportsCodec<C: FixedSizeCodec>(_ innerCodec: C) -> AnyFixedSizeCodec<Lamports, Lamports> where C.Encoded == Int, C.Decoded == Int {
    createCodec(fixedSize: innerCodec.fixedSize) { value, bytes, offset in
        try getLamportsEncoder(innerCodec).write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getLamportsDecoder(innerCodec).read(bytes, at: offset)
    }
}

public typealias Sol = DecimalFixedPoint

public func sol(_ value: String, rounding: RoundingMode = .strict) throws -> Sol {
    try decimalFixedPoint(.unsigned, 64, 9)(value, rounding: rounding)
}

public func solToLamports(_ value: Sol) throws -> Lamports {
    guard let lamports = UInt64(value.raw.description) else {
        throw SolanaError(.lamportsOutOfRange)
    }
    return lamports
}

public func lamportsToSol(_ value: Lamports) throws -> Sol {
    try rawDecimalFixedPoint(.unsigned, 64, 9)(FixedPointRaw(value))
}

public func getSolEncoder() -> AnyFixedSizeEncoder<Sol> {
    AnyFixedSizeEncoder<Sol>(fixedSize: 8) { value, bytes, offset in
        try getU64Encoder().write(try solToLamports(value), into: &bytes, at: offset)
    }
}

public func getSolDecoder() -> AnyFixedSizeDecoder<Sol> {
    AnyFixedSizeDecoder<Sol>(fixedSize: 8) { bytes, offset in
        let result = try getU64Decoder().read(bytes, at: offset)
        return (try lamportsToSol(result.0), result.1)
    }
}

public func getSolCodec() -> AnyFixedSizeCodec<Sol, Sol> {
    createCodec(fixedSize: 8) { value, bytes, offset in
        try getSolEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSolDecoder().read(bytes, at: offset)
    }
}

public typealias StringifiedBigInt = String

public func isStringifiedBigInt(_ putativeBigInt: String) -> Bool {
    do {
        try assertIsStringifiedBigInt(putativeBigInt)
        return true
    } catch {
        return false
    }
}

public func assertIsStringifiedBigInt(_ putativeBigInt: String) throws {
    guard jsBigIntParses(putativeBigInt) else {
        throw SolanaError(.malformedBigintString, context: ["value": .string(putativeBigInt)])
    }
}

public func stringifiedBigInt(_ putativeBigInt: String) throws -> StringifiedBigInt {
    try assertIsStringifiedBigInt(putativeBigInt)
    return putativeBigInt
}

public typealias StringifiedNumber = String

public func isStringifiedNumber(_ putativeNumber: String) -> Bool {
    jsNumberParses(putativeNumber)
}

public func assertIsStringifiedNumber(_ putativeNumber: String) throws {
    guard isStringifiedNumber(putativeNumber) else {
        throw SolanaError(.malformedNumberString, context: ["value": .string(putativeNumber)])
    }
}

public func stringifiedNumber(_ putativeNumber: String) throws -> StringifiedNumber {
    try assertIsStringifiedNumber(putativeNumber)
    return putativeNumber
}

private func jsBigIntParses(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return true
    }

    if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
        return allAsciiDigits(trimmed.dropFirst(2), radix: 16)
    }
    if trimmed.hasPrefix("0b") || trimmed.hasPrefix("0B") {
        return allAsciiDigits(trimmed.dropFirst(2), radix: 2)
    }
    if trimmed.hasPrefix("0o") || trimmed.hasPrefix("0O") {
        return allAsciiDigits(trimmed.dropFirst(2), radix: 8)
    }

    let unsigned: Substring
    if trimmed.first == "+" || trimmed.first == "-" {
        unsigned = trimmed.dropFirst()
    } else {
        unsigned = Substring(trimmed)
    }
    return allAsciiDigits(unsigned, radix: 10)
}

private func jsNumberParses(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return true
    }
    if trimmed == "Infinity" || trimmed == "+Infinity" || trimmed == "-Infinity" {
        return true
    }
    if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
        return allAsciiDigits(trimmed.dropFirst(2), radix: 16)
    }
    if trimmed.hasPrefix("0b") || trimmed.hasPrefix("0B") {
        return allAsciiDigits(trimmed.dropFirst(2), radix: 2)
    }
    if trimmed.hasPrefix("0o") || trimmed.hasPrefix("0O") {
        return allAsciiDigits(trimmed.dropFirst(2), radix: 8)
    }
    return decimalNumberParses(trimmed)
}

private func decimalNumberParses(_ value: String) -> Bool {
    var index = value.startIndex
    if index < value.endIndex, value[index] == "+" || value[index] == "-" {
        index = value.index(after: index)
    }

    var hasIntegerDigits = false
    while index < value.endIndex, isAsciiDigit(value[index], radix: 10) {
        hasIntegerDigits = true
        index = value.index(after: index)
    }

    var hasFractionDigits = false
    if index < value.endIndex, value[index] == "." {
        index = value.index(after: index)
        while index < value.endIndex, isAsciiDigit(value[index], radix: 10) {
            hasFractionDigits = true
            index = value.index(after: index)
        }
    }

    guard hasIntegerDigits || hasFractionDigits else {
        return false
    }

    if index < value.endIndex, value[index] == "e" || value[index] == "E" {
        index = value.index(after: index)
        if index < value.endIndex, value[index] == "+" || value[index] == "-" {
            index = value.index(after: index)
        }
        var hasExponentDigits = false
        while index < value.endIndex, isAsciiDigit(value[index], radix: 10) {
            hasExponentDigits = true
            index = value.index(after: index)
        }
        guard hasExponentDigits else {
            return false
        }
    }

    return index == value.endIndex
}

private func allAsciiDigits(_ value: Substring, radix: Int) -> Bool {
    guard !value.isEmpty else {
        return false
    }
    return value.allSatisfy { isAsciiDigit($0, radix: radix) }
}

private func isAsciiDigit(_ character: Character, radix: Int) -> Bool {
    guard let scalar = character.unicodeScalars.first,
          character.unicodeScalars.count == 1
    else {
        return false
    }
    switch scalar.value {
    case 48 ... 57:
        return Int(scalar.value - 48) < radix
    case 65 ... 70:
        return radix == 16
    case 97 ... 102:
        return radix == 16
    default:
        return false
    }
}

public typealias Slot = UInt64
public typealias Epoch = UInt64
public typealias MicroLamports = UInt64
public typealias SignedLamports = Int64
public typealias F64UnsafeSeeDocumentation = Double

public typealias UnixTimestamp = Int64

public func isUnixTimestamp(_ putativeTimestamp: Int64) -> Bool {
    true
}

public func assertIsUnixTimestamp(_ putativeTimestamp: Int64) throws {}

public func unixTimestamp(_ putativeTimestamp: Int64) -> UnixTimestamp {
    putativeTimestamp
}

public typealias Base58EncodedBytes = String
public typealias Base64EncodedBytes = String
public typealias Base64EncodedZStdCompressedBytes = String

public struct Base58EncodedDataResponse: Sendable, Equatable, Hashable, Codable {
    public let bytes: Base58EncodedBytes
    public let encoding: String

    public init(_ bytes: Base58EncodedBytes, encoding: String = "base58") {
        self.bytes = bytes
        self.encoding = encoding
    }

    public init(from decoder: any Swift.Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.bytes = try container.decode(Base58EncodedBytes.self)
        self.encoding = try container.decode(String.self)
    }

    public func encode(to encoder: any Swift.Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(bytes)
        try container.encode(encoding)
    }
}

public struct Base64EncodedDataResponse: Sendable, Equatable, Hashable, Codable {
    public let bytes: Base64EncodedBytes
    public let encoding: String

    public init(_ bytes: Base64EncodedBytes, encoding: String = "base64") {
        self.bytes = bytes
        self.encoding = encoding
    }

    public init(from decoder: any Swift.Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.bytes = try container.decode(Base64EncodedBytes.self)
        self.encoding = try container.decode(String.self)
    }

    public func encode(to encoder: any Swift.Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(bytes)
        try container.encode(encoding)
    }
}

public struct Base64EncodedZStdCompressedDataResponse: Sendable, Equatable, Hashable, Codable {
    public let bytes: Base64EncodedZStdCompressedBytes
    public let encoding: String

    public init(_ bytes: Base64EncodedZStdCompressedBytes, encoding: String = "base64+zstd") {
        self.bytes = bytes
        self.encoding = encoding
    }

    public init(from decoder: any Swift.Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.bytes = try container.decode(Base64EncodedZStdCompressedBytes.self)
        self.encoding = try container.decode(String.self)
    }

    public func encode(to encoder: any Swift.Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(bytes)
        try container.encode(encoding)
    }
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

    public init(length: Int, offset: Int) {
        self.length = length
        self.offset = offset
    }
}

public enum ProgramNotificationsMemcmpFilterEncoding: String, Sendable, Equatable, Hashable, Codable {
    case base58
    case base64
}

public struct ProgramNotificationsMemcmpFilter: Sendable, Equatable, Hashable, Codable {
    public let bytes: String
    public let encoding: ProgramNotificationsMemcmpFilterEncoding
    public let offset: UInt64

    public init(bytes: String, encoding: ProgramNotificationsMemcmpFilterEncoding, offset: UInt64) {
        self.bytes = bytes
        self.encoding = encoding
        self.offset = offset
    }
}

public struct GetProgramAccountsMemcmpFilter: Sendable, Equatable, Hashable, Codable {
    public let memcmp: ProgramNotificationsMemcmpFilter

    public init(memcmp: ProgramNotificationsMemcmpFilter) {
        self.memcmp = memcmp
    }
}

public struct GetProgramAccountsDatasizeFilter: Sendable, Equatable, Hashable, Codable {
    public let dataSize: UInt64

    public init(dataSize: UInt64) {
        self.dataSize = dataSize
    }
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

    public init(executable: Bool, lamports: Lamports, owner: Address, space: UInt64) {
        self.executable = executable
        self.lamports = lamports
        self.owner = owner
        self.space = space
    }
}

public struct AccountInfoWithBase58Bytes: Sendable, Equatable, Hashable {
    public let data: Base58EncodedBytes

    public init(data: Base58EncodedBytes) {
        self.data = data
    }
}

public struct AccountInfoWithBase58EncodedData: Sendable, Equatable, Hashable {
    public let data: Base58EncodedDataResponse

    public init(data: Base58EncodedDataResponse) {
        self.data = data
    }
}

public struct AccountInfoWithBase64EncodedData: Sendable, Equatable, Hashable {
    public let data: Base64EncodedDataResponse

    public init(data: Base64EncodedDataResponse) {
        self.data = data
    }
}

public struct AccountInfoWithBase64EncodedZStdCompressedData: Sendable, Equatable, Hashable {
    public let data: Base64EncodedZStdCompressedDataResponse

    public init(data: Base64EncodedZStdCompressedDataResponse) {
        self.data = data
    }
}

public struct AccountInfoParsedData: Sendable, Equatable, Hashable {
    public let info: RpcTypeJsonValue?
    public let type: String

    public init(info: RpcTypeJsonValue? = nil, type: String) {
        self.info = info
        self.type = type
    }
}

public struct AccountInfoJsonParsedData: Sendable, Equatable, Hashable {
    public let parsed: AccountInfoParsedData
    public let program: String
    public let space: UInt64

    public init(parsed: AccountInfoParsedData, program: String, space: UInt64) {
        self.parsed = parsed
        self.program = program
        self.space = space
    }
}

public enum AccountInfoJsonData: Sendable, Equatable, Hashable {
    case base64(Base64EncodedDataResponse)
    case parsed(AccountInfoJsonParsedData)
}

public struct AccountInfoWithJsonData: Sendable, Equatable, Hashable {
    public let data: AccountInfoJsonData

    public init(data: AccountInfoJsonData) {
        self.data = data
    }
}

public struct AccountInfoWithPubkey<Account: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let account: Account
    public let pubkey: Address

    public init(account: Account, pubkey: Address) {
        self.account = account
        self.pubkey = pubkey
    }
}

public struct TokenAmount: Sendable, Equatable, Hashable {
    public let amount: StringifiedBigInt
    public let decimals: Int
    public let uiAmount: F64UnsafeSeeDocumentation?
    public let uiAmountString: StringifiedNumber

    public init(amount: StringifiedBigInt, decimals: Int, uiAmount: F64UnsafeSeeDocumentation?, uiAmountString: StringifiedNumber) {
        self.amount = amount
        self.decimals = decimals
        self.uiAmount = uiAmount
        self.uiAmountString = uiAmountString
    }
}

public struct TokenBalance: Sendable, Equatable, Hashable {
    public let accountIndex: Int
    public let mint: Address
    public let owner: Address?
    public let programId: Address?
    public let uiTokenAmount: TokenAmount

    public init(
        accountIndex: Int,
        mint: Address,
        owner: Address? = nil,
        programId: Address? = nil,
        uiTokenAmount: TokenAmount
    ) {
        self.accountIndex = accountIndex
        self.mint = mint
        self.owner = owner
        self.programId = programId
        self.uiTokenAmount = uiTokenAmount
    }
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

    public init(accountKey: Address, readonlyIndexes: [Int], writableIndexes: [Int]) {
        self.accountKey = accountKey
        self.readonlyIndexes = readonlyIndexes
        self.writableIndexes = writableIndexes
    }
}

public struct ParsedTransactionInstruction: Sendable, Equatable, Hashable {
    public let parsed: AccountInfoParsedData
    public let program: String
    public let programId: Address
    public let stackHeight: Int?

    public init(parsed: AccountInfoParsedData, program: String, programId: Address, stackHeight: Int? = nil) {
        self.parsed = parsed
        self.program = program
        self.programId = programId
        self.stackHeight = stackHeight
    }
}

public struct PartiallyDecodedTransactionInstruction: Sendable, Equatable, Hashable {
    public let accounts: [Address]
    public let data: Base58EncodedBytes
    public let programId: Address
    public let stackHeight: Int?

    public init(accounts: [Address], data: Base58EncodedBytes, programId: Address, stackHeight: Int? = nil) {
        self.accounts = accounts
        self.data = data
        self.programId = programId
        self.stackHeight = stackHeight
    }
}

public struct TransactionInstruction: Sendable, Equatable, Hashable {
    public let accounts: [Int]
    public let data: Base58EncodedBytes
    public let programIdIndex: Int
    public let stackHeight: Int?

    public init(accounts: [Int], data: Base58EncodedBytes, programIdIndex: Int, stackHeight: Int? = nil) {
        self.accounts = accounts
        self.data = data
        self.programIdIndex = programIdIndex
        self.stackHeight = stackHeight
    }
}

public struct ReturnData: Sendable, Equatable, Hashable {
    public let data: Base64EncodedDataResponse
    public let programId: Address

    public init(data: Base64EncodedDataResponse, programId: Address) {
        self.data = data
        self.programId = programId
    }
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

    public init(pubkey: Address, signer: Bool, source: TransactionParsedAccountSource, writable: Bool) {
        self.pubkey = pubkey
        self.signer = signer
        self.source = source
        self.writable = writable
    }
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

    public init(lamports: SignedLamports, postBalance: Lamports, pubkey: Address) {
        self.lamports = lamports
        self.postBalance = postBalance
        self.pubkey = pubkey
    }
}

public struct RewardWithCommission: Sendable, Equatable, Hashable {
    public let base: RewardBase
    public let commission: Int

    public init(base: RewardBase, commission: Int) {
        self.base = base
        self.commission = commission
    }
}

public enum Reward: Sendable, Equatable, Hashable {
    case fee(RewardBase)
    case rent(RewardBase)
    case staking(RewardWithCommission)
    case voting(RewardWithCommission)

    public var commission: Int? {
        switch self {
        case .fee, .rent:
            return nil
        case let .staking(reward), let .voting(reward):
            return reward.commission
        }
    }

    public var lamports: SignedLamports {
        base.lamports
    }

    public var postBalance: Lamports {
        base.postBalance
    }

    public var pubkey: Address {
        base.pubkey
    }

    public var rewardType: RewardType {
        switch self {
        case .fee:
            return .fee
        case .rent:
            return .rent
        case .staking:
            return .staking
        case .voting:
            return .voting
        }
    }

    private var base: RewardBase {
        switch self {
        case let .fee(base), let .rent(base):
            return base
        case let .staking(reward), let .voting(reward):
            return reward.base
        }
    }

    public init(commission: Int? = nil, lamports: SignedLamports, postBalance: Lamports, pubkey: Address, rewardType: RewardType) {
        let base = RewardBase(lamports: lamports, postBalance: postBalance, pubkey: pubkey)
        switch rewardType {
        case .fee:
            self = .fee(base)
        case .rent:
            self = .rent(base)
        case .staking:
            self = .staking(RewardWithCommission(base: base, commission: commission ?? 0))
        case .voting:
            self = .voting(RewardWithCommission(base: base, commission: commission ?? 0))
        }
    }
}

public struct TransactionMessageHeader: Sendable, Equatable, Hashable {
    public let numReadonlySignedAccounts: Int
    public let numReadonlyUnsignedAccounts: Int
    public let numRequiredSignatures: Int

    public init(numReadonlySignedAccounts: Int, numReadonlyUnsignedAccounts: Int, numRequiredSignatures: Int) {
        self.numReadonlySignedAccounts = numReadonlySignedAccounts
        self.numReadonlyUnsignedAccounts = numReadonlyUnsignedAccounts
        self.numRequiredSignatures = numRequiredSignatures
    }
}

public struct TransactionMessageBase: Sendable, Equatable, Hashable {
    public let header: TransactionMessageHeader
    public let recentBlockhash: Blockhash

    public init(header: TransactionMessageHeader, recentBlockhash: Blockhash) {
        self.header = header
        self.recentBlockhash = recentBlockhash
    }
}

public struct TransactionWithSignatures: Sendable, Equatable, Hashable {
    public let signatures: [Base58EncodedBytes]

    public init(signatures: [Base58EncodedBytes]) {
        self.signatures = signatures
    }
}

public typealias TransactionParsedAccountLegacy = TransactionParsedAccount
public typealias TransactionParsedAccountVersioned = TransactionParsedAccount

public struct TransactionForAccountsLegacyTransaction: Sendable, Equatable, Hashable {
    public let accountKeys: [TransactionParsedAccountLegacy]
    public let signatures: [Base58EncodedBytes]

    public init(accountKeys: [TransactionParsedAccountLegacy], signatures: [Base58EncodedBytes]) {
        self.accountKeys = accountKeys
        self.signatures = signatures
    }
}

public struct TransactionForAccountsVersionedTransaction: Sendable, Equatable, Hashable {
    public let accountKeys: [TransactionParsedAccountVersioned]
    public let signatures: [Base58EncodedBytes]

    public init(accountKeys: [TransactionParsedAccountVersioned], signatures: [Base58EncodedBytes]) {
        self.accountKeys = accountKeys
        self.signatures = signatures
    }
}

public struct TransactionForAccountsLegacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForAccountsMetaBase?
    public let transaction: TransactionForAccountsLegacyTransaction

    public init(meta: TransactionForAccountsMetaBase?, transaction: TransactionForAccountsLegacyTransaction) {
        self.meta = meta
        self.transaction = transaction
    }
}

public struct TransactionForAccountsVersioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForAccountsMetaBase?
    public let transaction: TransactionForAccountsVersionedTransaction
    public let version: RpcTransactionVersion

    public init(meta: TransactionForAccountsMetaBase?, transaction: TransactionForAccountsVersionedTransaction, version: RpcTransactionVersion) {
        self.meta = meta
        self.transaction = transaction
        self.version = version
    }
}

public enum TransactionInstructionResponse: Sendable, Equatable, Hashable {
    case parsed(ParsedTransactionInstruction)
    case partiallyDecoded(PartiallyDecodedTransactionInstruction)
}

public struct TransactionForFullMetaInnerInstruction<Instruction: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let index: Int
    public let instructions: [Instruction]

    public init(index: Int, instructions: [Instruction]) {
        self.index = index
        self.instructions = instructions
    }
}

public struct TransactionForFullMetaInnerInstructionsUnparsed: Sendable, Equatable, Hashable {
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>]

    public init(innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>]) {
        self.innerInstructions = innerInstructions
    }
}

public struct TransactionForFullMetaInnerInstructionsParsed: Sendable, Equatable, Hashable {
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>]

    public init(innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>]) {
        self.innerInstructions = innerInstructions
    }
}

public struct TransactionLoadedAddresses: Sendable, Equatable, Hashable {
    public let readonly: [Address]
    public let writable: [Address]

    public init(readonly: [Address], writable: [Address]) {
        self.readonly = readonly
        self.writable = writable
    }
}

public struct TransactionForFullTransactionAddressTableLookups: Sendable, Equatable, Hashable {
    public let addressTableLookups: [RpcAddressTableLookup]?

    public init(addressTableLookups: [RpcAddressTableLookup]? = nil) {
        self.addressTableLookups = addressTableLookups
    }
}

public struct TransactionForFullJsonMessage: Sendable, Equatable, Hashable {
    public let accountKeys: [Address]
    public let addressTableLookups: [RpcAddressTableLookup]?
    public let header: TransactionMessageHeader
    public let instructions: [TransactionInstruction]
    public let recentBlockhash: Blockhash

    public var base: TransactionMessageBase {
        TransactionMessageBase(header: header, recentBlockhash: recentBlockhash)
    }

    public init(accountKeys: [Address], base: TransactionMessageBase, instructions: [TransactionInstruction]) {
        self.accountKeys = accountKeys
        self.addressTableLookups = nil
        self.header = base.header
        self.instructions = instructions
        self.recentBlockhash = base.recentBlockhash
    }

    public init(
        accountKeys: [Address],
        addressTableLookups: [RpcAddressTableLookup]? = nil,
        header: TransactionMessageHeader,
        instructions: [TransactionInstruction],
        recentBlockhash: Blockhash
    ) {
        self.accountKeys = accountKeys
        self.addressTableLookups = addressTableLookups
        self.header = header
        self.instructions = instructions
        self.recentBlockhash = recentBlockhash
    }
}

public struct TransactionForFullJsonParsedMessage: Sendable, Equatable, Hashable {
    public let accountKeys: [TransactionParsedAccount]
    public let header: TransactionMessageHeader
    public let instructions: [TransactionInstructionResponse]
    public let recentBlockhash: Blockhash

    public var base: TransactionMessageBase {
        TransactionMessageBase(header: header, recentBlockhash: recentBlockhash)
    }

    public init(accountKeys: [TransactionParsedAccount], base: TransactionMessageBase, instructions: [TransactionInstructionResponse]) {
        self.accountKeys = accountKeys
        self.header = base.header
        self.instructions = instructions
        self.recentBlockhash = base.recentBlockhash
    }

    public init(accountKeys: [TransactionParsedAccount], header: TransactionMessageHeader, instructions: [TransactionInstructionResponse], recentBlockhash: Blockhash) {
        self.accountKeys = accountKeys
        self.header = header
        self.instructions = instructions
        self.recentBlockhash = recentBlockhash
    }
}

public struct TransactionForFullJsonTransaction: Sendable, Equatable, Hashable {
    public let message: TransactionForFullJsonMessage
    public let signatures: [Base58EncodedBytes]

    public var addressTableLookups: [RpcAddressTableLookup]? {
        message.addressTableLookups
    }

    public init(addressTableLookups: [RpcAddressTableLookup]? = nil, message: TransactionForFullJsonMessage, signatures: [Base58EncodedBytes]) {
        if let addressTableLookups {
            self.message = TransactionForFullJsonMessage(
                accountKeys: message.accountKeys,
                addressTableLookups: addressTableLookups,
                header: message.header,
                instructions: message.instructions,
                recentBlockhash: message.recentBlockhash
            )
        } else {
            self.message = message
        }
        self.signatures = signatures
    }
}

public struct TransactionForFullJsonParsedTransaction: Sendable, Equatable, Hashable {
    public let message: TransactionForFullJsonParsedMessage
    public let signatures: [Base58EncodedBytes]

    public init(message: TransactionForFullJsonParsedMessage, signatures: [Base58EncodedBytes]) {
        self.message = message
        self.signatures = signatures
    }
}

public struct TransactionForFullBase58Legacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base58EncodedDataResponse

    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base58EncodedDataResponse) {
        self.meta = meta
        self.transaction = transaction
    }
}

public struct TransactionForFullBase58Versioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base58EncodedDataResponse
    public let version: RpcTransactionVersion

    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base58EncodedDataResponse, version: RpcTransactionVersion) {
        self.meta = meta
        self.transaction = transaction
        self.version = version
    }
}

public struct TransactionForFullBase64Legacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base64EncodedDataResponse

    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base64EncodedDataResponse) {
        self.meta = meta
        self.transaction = transaction
    }
}

public struct TransactionForFullBase64Versioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: Base64EncodedDataResponse
    public let version: RpcTransactionVersion

    public init(meta: TransactionForFullUnparsedMeta?, transaction: Base64EncodedDataResponse, version: RpcTransactionVersion) {
        self.meta = meta
        self.transaction = transaction
        self.version = version
    }
}

public struct TransactionForFullJsonLegacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: TransactionForFullJsonTransaction

    public init(meta: TransactionForFullUnparsedMeta?, transaction: TransactionForFullJsonTransaction) {
        self.meta = meta
        self.transaction = transaction
    }
}

public struct TransactionForFullJsonVersioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullUnparsedMeta?
    public let transaction: TransactionForFullJsonTransaction
    public let version: RpcTransactionVersion

    public init(meta: TransactionForFullUnparsedMeta?, transaction: TransactionForFullJsonTransaction, version: RpcTransactionVersion) {
        self.meta = meta
        self.transaction = transaction
        self.version = version
    }
}

public struct TransactionForFullJsonParsedLegacy: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullParsedMeta?
    public let transaction: TransactionForFullJsonParsedTransaction

    public init(meta: TransactionForFullParsedMeta?, transaction: TransactionForFullJsonParsedTransaction) {
        self.meta = meta
        self.transaction = transaction
    }
}

public struct TransactionForFullJsonParsedVersioned: Sendable, Equatable, Hashable {
    public let meta: TransactionForFullParsedMeta?
    public let transaction: TransactionForFullJsonParsedTransaction
    public let version: RpcTransactionVersion

    public init(meta: TransactionForFullParsedMeta?, transaction: TransactionForFullJsonParsedTransaction, version: RpcTransactionVersion) {
        self.meta = meta
        self.transaction = transaction
        self.version = version
    }
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
    ) {
        self.err = err
        self.fee = fee
        self.postBalances = postBalances
        self.postTokenBalances = postTokenBalances
        self.preBalances = preBalances
        self.preTokenBalances = preTokenBalances
        self.status = status
    }
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

    public var accountsMeta: TransactionForAccountsMetaBase {
        TransactionForAccountsMetaBase(
            err: err,
            fee: fee,
            postBalances: postBalances,
            postTokenBalances: postTokenBalances,
            preBalances: preBalances,
            preTokenBalances: preTokenBalances,
            status: status
        )
    }

    public init(
        accountsMeta: TransactionForAccountsMetaBase,
        computeUnitsConsumed: UInt64? = nil,
        logMessages: [String]?,
        returnData: ReturnData? = nil,
        rewards: [Reward]?
    ) {
        self.err = accountsMeta.err
        self.fee = accountsMeta.fee
        self.postBalances = accountsMeta.postBalances
        self.postTokenBalances = accountsMeta.postTokenBalances
        self.preBalances = accountsMeta.preBalances
        self.preTokenBalances = accountsMeta.preTokenBalances
        self.status = accountsMeta.status
        self.computeUnitsConsumed = computeUnitsConsumed
        self.logMessages = logMessages
        self.returnData = returnData
        self.rewards = rewards
    }

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
    ) {
        self.err = err
        self.fee = fee
        self.postBalances = postBalances
        self.postTokenBalances = postTokenBalances
        self.preBalances = preBalances
        self.preTokenBalances = preTokenBalances
        self.status = status
        self.computeUnitsConsumed = computeUnitsConsumed
        self.logMessages = logMessages
        self.returnData = returnData
        self.rewards = rewards
    }
}

public struct TransactionForFullUnparsedMeta: Sendable, Equatable, Hashable {
    public let base: TransactionForFullMetaBase
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>]
    public let loadedAddresses: TransactionLoadedAddresses?

    public var accountsMeta: TransactionForAccountsMetaBase { base.accountsMeta }
    public var computeUnitsConsumed: UInt64? { base.computeUnitsConsumed }
    public var err: RpcTransactionError? { base.err }
    public var fee: Lamports { base.fee }
    public var logMessages: [String]? { base.logMessages }
    public var postBalances: [Lamports] { base.postBalances }
    public var postTokenBalances: [TokenBalance]? { base.postTokenBalances }
    public var preBalances: [Lamports] { base.preBalances }
    public var preTokenBalances: [TokenBalance]? { base.preTokenBalances }
    public var returnData: ReturnData? { base.returnData }
    public var rewards: [Reward]? { base.rewards }
    public var status: TransactionStatus { base.status }

    public init(
        base: TransactionForFullMetaBase,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    ) {
        self.base = base
        self.innerInstructions = innerInstructions
        self.loadedAddresses = loadedAddresses
    }

    public init(
        accountsMeta: TransactionForAccountsMetaBase,
        computeUnitsConsumed: UInt64? = nil,
        logMessages: [String]?,
        returnData: ReturnData? = nil,
        rewards: [Reward]?,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstruction>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    ) {
        self.base = TransactionForFullMetaBase(
            accountsMeta: accountsMeta,
            computeUnitsConsumed: computeUnitsConsumed,
            logMessages: logMessages,
            returnData: returnData,
            rewards: rewards
        )
        self.innerInstructions = innerInstructions
        self.loadedAddresses = loadedAddresses
    }
}

public struct TransactionForFullParsedMeta: Sendable, Equatable, Hashable {
    public let base: TransactionForFullMetaBase
    public let innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>]
    public let loadedAddresses: TransactionLoadedAddresses?

    public var accountsMeta: TransactionForAccountsMetaBase { base.accountsMeta }
    public var computeUnitsConsumed: UInt64? { base.computeUnitsConsumed }
    public var err: RpcTransactionError? { base.err }
    public var fee: Lamports { base.fee }
    public var logMessages: [String]? { base.logMessages }
    public var postBalances: [Lamports] { base.postBalances }
    public var postTokenBalances: [TokenBalance]? { base.postTokenBalances }
    public var preBalances: [Lamports] { base.preBalances }
    public var preTokenBalances: [TokenBalance]? { base.preTokenBalances }
    public var returnData: ReturnData? { base.returnData }
    public var rewards: [Reward]? { base.rewards }
    public var status: TransactionStatus { base.status }

    public init(
        base: TransactionForFullMetaBase,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    ) {
        self.base = base
        self.innerInstructions = innerInstructions
        self.loadedAddresses = loadedAddresses
    }

    public init(
        accountsMeta: TransactionForAccountsMetaBase,
        computeUnitsConsumed: UInt64? = nil,
        logMessages: [String]?,
        returnData: ReturnData? = nil,
        rewards: [Reward]?,
        innerInstructions: [TransactionForFullMetaInnerInstruction<TransactionInstructionResponse>],
        loadedAddresses: TransactionLoadedAddresses? = nil
    ) {
        self.base = TransactionForFullMetaBase(
            accountsMeta: accountsMeta,
            computeUnitsConsumed: computeUnitsConsumed,
            logMessages: logMessages,
            returnData: returnData,
            rewards: rewards
        )
        self.innerInstructions = innerInstructions
        self.loadedAddresses = loadedAddresses
    }
}

public struct TransactionForFullMetaLoadedAddresses: Sendable, Equatable, Hashable {
    public let loadedAddresses: TransactionLoadedAddresses

    public var readonly: [Address] {
        loadedAddresses.readonly
    }

    public var writable: [Address] {
        loadedAddresses.writable
    }

    public init(readonly: [Address], writable: [Address]) {
        self.loadedAddresses = TransactionLoadedAddresses(readonly: readonly, writable: writable)
    }

    public init(loadedAddresses: TransactionLoadedAddresses) {
        self.loadedAddresses = loadedAddresses
    }
}

public struct SolanaRpcContext: Sendable, Equatable, Hashable {
    public let slot: Slot

    public init(slot: Slot) {
        self.slot = slot
    }
}

public struct SolanaRpcResponse<Value: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let context: SolanaRpcContext
    public let value: Value

    public init(context: SolanaRpcContext, value: Value) {
        self.context = context
        self.value = value
    }
}

public typealias MainnetUrl = String
public typealias DevnetUrl = String
public typealias TestnetUrl = String
public typealias ClusterUrl = String

public func mainnet(_ putativeString: String) -> MainnetUrl {
    putativeString
}

public func devnet(_ putativeString: String) -> DevnetUrl {
    putativeString
}

public func testnet(_ putativeString: String) -> TestnetUrl {
    putativeString
}
