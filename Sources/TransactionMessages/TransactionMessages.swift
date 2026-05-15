public import Addresses
public import CodecsCore
import CodecsNumbers
public import Foundation
public import Instructions
public import SolanaErrors

public typealias Blockhash = String
public typealias Nonce = String

public struct AddressesByLookupTableAddress: Sendable, Equatable, ExpressibleByDictionaryLiteral {
    private var entries: [Entry]

    public init() {
        self.entries = []
    }

    public init(dictionaryLiteral elements: (Address, [Address])...) {
        self.entries = Self.collapse(elements)
    }

    public init(_ entries: [(Address, [Address])]) {
        self.entries = Self.collapse(entries)
    }

    public init(_ values: [Address: [Address]]) {
        self.entries = Self.collapse(values.map { ($0.key, $0.value) })
    }

    public subscript(lookupTableAddress: Address) -> [Address]? {
        entries.first { $0.lookupTableAddress == lookupTableAddress }?.addresses
    }

    public var isEmpty: Bool {
        entries.isEmpty
    }

    public var lookupTableAddresses: [Address] {
        entries.map(\.lookupTableAddress)
    }

    internal var values: [[Address]] {
        entries.map(\.addresses)
    }

    internal var orderedPairs: [(lookupTableAddress: Address, addresses: [Address])] {
        entries.map { ($0.lookupTableAddress, $0.addresses) }
    }

    private static func collapse(_ elements: [(Address, [Address])]) -> [Entry] {
        var entries: [Entry] = []
        for (lookupTableAddress, addresses) in elements {
            if let index = entries.firstIndex(where: { $0.lookupTableAddress == lookupTableAddress }) {
                entries[index] = Entry(lookupTableAddress: lookupTableAddress, addresses: addresses)
            } else {
                entries.append(Entry(lookupTableAddress: lookupTableAddress, addresses: addresses))
            }
        }
        return entries
    }

    private struct Entry: Sendable, Equatable {
        let lookupTableAddress: Address
        let addresses: [Address]
    }
}

private let versionFlagMask = 0x80
private let maximumAccounts = 64
private let maximumSigners = 12
private let maximumInstructions = 64
private let maximumAccountsPerInstruction = 255
private let lifetimeTokenByteLength = 32
private let systemProgramAddress = knownAddress("11111111111111111111111111111111")
private let recentBlockhashesSysvarAddress = knownAddress("SysvarRecentB1ockHashes11111111111111111111")

public enum TransactionVersion: Sendable, Equatable, Hashable {
    case legacy
    case v0
    case v1
    case unsupported(Int)

    public static let maxSupported = 1

    public var number: Int? {
        switch self {
        case .legacy:
            return nil
        case .v0:
            return 0
        case .v1:
            return 1
        case let .unsupported(value):
            return value
        }
    }

    public init(number: Int) {
        switch number {
        case 0:
            self = .v0
        case 1:
            self = .v1
        default:
            self = .unsupported(number)
        }
    }
}

public struct TransactionMessageFeePayer: Sendable, Equatable, Hashable {
    public let address: Address

    public init(address: Address) {
        self.address = address
    }
}

public struct BlockhashLifetimeConstraint: Sendable, Equatable, Hashable {
    public let blockhash: Blockhash
    public let lastValidBlockHeight: UInt64

    public init(blockhash: Blockhash, lastValidBlockHeight: UInt64) {
        self.blockhash = blockhash
        self.lastValidBlockHeight = lastValidBlockHeight
    }
}

public struct NonceLifetimeConstraint: Sendable, Equatable, Hashable {
    public let nonce: Nonce

    public init(nonce: Nonce) {
        self.nonce = nonce
    }
}

public struct DurableNonceConfig: Sendable, Equatable, Hashable {
    public let nonce: Nonce
    public let nonceAccountAddress: Address
    public let nonceAuthorityAddress: Address

    public init(nonce: Nonce, nonceAccountAddress: Address, nonceAuthorityAddress: Address) {
        self.nonce = nonce
        self.nonceAccountAddress = nonceAccountAddress
        self.nonceAuthorityAddress = nonceAuthorityAddress
    }
}

public enum TransactionMessageLifetimeConstraint: Sendable, Equatable, Hashable {
    case blockhash(BlockhashLifetimeConstraint)
    case nonce(NonceLifetimeConstraint)

    public var lifetimeToken: String {
        switch self {
        case let .blockhash(constraint):
            return constraint.blockhash
        case let .nonce(constraint):
            return constraint.nonce
        }
    }
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
    ) {
        self.computeUnitLimit = computeUnitLimit
        self.heapSize = heapSize
        self.loadedAccountsDataSizeLimit = loadedAccountsDataSizeLimit
        self.priorityFeeLamports = priorityFeeLamports
    }

    public var isEmpty: Bool {
        computeUnitLimit == nil &&
            heapSize == nil &&
            loadedAccountsDataSizeLimit == nil &&
            priorityFeeLamports == nil
    }
}

public enum V1TransactionConfigField<Value: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    case unchanged
    case set(Value)
    case remove

    fileprivate func apply(to currentValue: Value?) -> Value? {
        switch self {
        case .unchanged:
            return currentValue
        case let .set(value):
            return value
        case .remove:
            return nil
        }
    }
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
    ) {
        self.computeUnitLimit = computeUnitLimit
        self.heapSize = heapSize
        self.loadedAccountsDataSizeLimit = loadedAccountsDataSizeLimit
        self.priorityFeeLamports = priorityFeeLamports
    }
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
    ) {
        self.version = version
        self.instructions = instructions
        self.feePayer = feePayer
        self.lifetimeConstraint = lifetimeConstraint
        self.config = config
    }
}

public struct MessageHeader: Sendable, Equatable, Hashable {
    public let numReadonlyNonSignerAccounts: Int
    public let numReadonlySignerAccounts: Int
    public let numSignerAccounts: Int

    public init(numReadonlyNonSignerAccounts: Int, numReadonlySignerAccounts: Int, numSignerAccounts: Int) {
        self.numReadonlyNonSignerAccounts = numReadonlyNonSignerAccounts
        self.numReadonlySignerAccounts = numReadonlySignerAccounts
        self.numSignerAccounts = numSignerAccounts
    }
}

public struct CompiledInstruction: Sendable, Equatable, Hashable {
    public let accountIndices: [Int]?
    public let data: Data?
    public let programAddressIndex: Int

    public init(accountIndices: [Int]? = nil, data: Data? = nil, programAddressIndex: Int) {
        self.accountIndices = accountIndices
        self.data = data
        self.programAddressIndex = programAddressIndex
    }
}

public struct AddressTableLookup: Sendable, Equatable, Hashable {
    public let lookupTableAddress: Address
    public let readonlyIndexes: [Int]
    public let writableIndexes: [Int]

    public init(lookupTableAddress: Address, readonlyIndexes: [Int], writableIndexes: [Int]) {
        self.lookupTableAddress = lookupTableAddress
        self.readonlyIndexes = readonlyIndexes
        self.writableIndexes = writableIndexes
    }
}

public enum CompiledTransactionConfigValue: Sendable, Equatable, Hashable {
    case u32(Int)
    case u64(UInt64)
}

public struct InstructionHeader: Sendable, Equatable, Hashable {
    public let numInstructionAccounts: Int
    public let numInstructionDataBytes: Int
    public let programAccountIndex: Int

    public init(numInstructionAccounts: Int, numInstructionDataBytes: Int, programAccountIndex: Int) {
        self.numInstructionAccounts = numInstructionAccounts
        self.numInstructionDataBytes = numInstructionDataBytes
        self.programAccountIndex = programAccountIndex
    }
}

public struct InstructionPayload: Sendable, Equatable, Hashable {
    public let instructionAccountIndices: [Int]
    public let instructionData: Data

    public init(instructionAccountIndices: [Int], instructionData: Data) {
        self.instructionAccountIndices = instructionAccountIndices
        self.instructionData = instructionData
    }
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
    ) {
        self.header = header
        self.instructions = instructions
        self.lifetimeToken = lifetimeToken
        self.staticAccounts = staticAccounts
        self.version = version
    }
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
    ) {
        self.addressTableLookups = addressTableLookups
        self.header = header
        self.instructions = instructions
        self.lifetimeToken = lifetimeToken
        self.staticAccounts = staticAccounts
        self.version = version
    }
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
    ) {
        self.configMask = configMask
        self.configValues = configValues
        self.header = header
        self.instructionHeaders = instructionHeaders
        self.instructionPayloads = instructionPayloads
        self.lifetimeToken = lifetimeToken
        self.numInstructions = numInstructions
        self.numStaticAccounts = numStaticAccounts
        self.staticAccounts = staticAccounts
        self.version = version
    }
}

public enum CompiledTransactionMessage: Sendable, Equatable, Hashable {
    case legacy(LegacyCompiledTransactionMessage)
    case v0(V0CompiledTransactionMessage)
    case v1(V1CompiledTransactionMessage)

    public var version: TransactionVersion {
        switch self {
        case let .legacy(message):
            return message.version
        case let .v0(message):
            return message.version
        case let .v1(message):
            return message.version
        }
    }

    public var lifetimeToken: String? {
        switch self {
        case let .legacy(message):
            return message.lifetimeToken
        case let .v0(message):
            return message.lifetimeToken
        case let .v1(message):
            return message.lifetimeToken
        }
    }
}

public struct DecompileTransactionMessageConfig: Sendable, Equatable {
    public let addressesByLookupTableAddress: AddressesByLookupTableAddress
    public let lastValidBlockHeight: UInt64?

    public init(
        addressesByLookupTableAddress: AddressesByLookupTableAddress = [:],
        lastValidBlockHeight: UInt64? = nil
    ) {
        self.addressesByLookupTableAddress = addressesByLookupTableAddress
        self.lastValidBlockHeight = lastValidBlockHeight
    }
}

public let computeBudgetProgramAddress = knownAddress("ComputeBudget111111111111111111111111111111")
public let maximumComputeUnitLimit = 1_400_000
public let transactionConfigPriorityFeeLamportsBitMask = 0b11
public let transactionConfigComputeUnitLimitBitMask = 0b100
public let transactionConfigLoadedAccountsDataSizeLimitBitMask = 0b1000
public let transactionConfigHeapSizeBitMask = 0b10000

private enum AddressMapEntryType: Int, Sendable {
    case feePayer
    case `static`
    case lookupTable
}

private struct AddressMapEntry: Sendable, Equatable {
    var type: AddressMapEntryType
    var role: AccountRole
    var addressIndex: Int?
    var lookupTableAddress: Address?
}

private struct OrderedAccount: Sendable, Equatable {
    let address: Address
    let entry: AddressMapEntry

    var instructionAccount: InstructionAccount {
        if entry.type == .lookupTable, let addressIndex = entry.addressIndex, let lookupTableAddress = entry.lookupTableAddress {
            return .lookup(
                AccountLookupMeta(
                    address: address,
                    addressIndex: addressIndex,
                    lookupTableAddress: lookupTableAddress,
                    role: entry.role
                )
            )
        }
        return .account(AccountMeta(address: address, role: entry.role))
    }
}

public func createTransactionMessage(version: TransactionVersion) -> TransactionMessage {
    TransactionMessage(version: version)
}

public func setTransactionMessageFeePayer(_ feePayer: Address, _ transactionMessage: TransactionMessage) -> TransactionMessage {
    if transactionMessage.feePayer?.address == feePayer {
        return transactionMessage
    }
    return TransactionMessage(
        version: transactionMessage.version,
        instructions: transactionMessage.instructions,
        feePayer: TransactionMessageFeePayer(address: feePayer),
        lifetimeConstraint: transactionMessage.lifetimeConstraint,
        config: transactionMessage.config
    )
}

public func setTransactionMessageLifetimeUsingBlockhash(
    _ constraint: BlockhashLifetimeConstraint,
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    if transactionMessage.lifetimeConstraint == .blockhash(constraint) {
        return transactionMessage
    }
    return TransactionMessage(
        version: transactionMessage.version,
        instructions: transactionMessage.instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: .blockhash(constraint),
        config: transactionMessage.config
    )
}

public func isTransactionMessageWithBlockhashLifetime(_ transactionMessage: TransactionMessage) -> Bool {
    guard case let .blockhash(constraint) = transactionMessage.lifetimeConstraint else {
        return false
    }
    return isValidLifetimeToken(constraint.blockhash)
}

public func assertIsTransactionMessageWithBlockhashLifetime(_ transactionMessage: TransactionMessage) throws(SolanaError) {
    guard isTransactionMessageWithBlockhashLifetime(transactionMessage) else {
        throw SolanaError(.transactionExpectedBlockhashLifetime)
    }
}

public func setTransactionMessageLifetimeUsingDurableNonce(
    _ config: DurableNonceConfig,
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    let advanceInstruction = createAdvanceNonceAccountInstruction(
        nonceAccountAddress: config.nonceAccountAddress,
        nonceAuthorityAddress: config.nonceAuthorityAddress
    )
    var instructions = transactionMessage.instructions
    if let first = instructions.first, isAdvanceNonceAccountInstruction(first) {
        if isAdvanceNonceAccountInstruction(first, nonceAccountAddress: config.nonceAccountAddress, nonceAuthorityAddress: config.nonceAuthorityAddress) {
            if transactionMessage.lifetimeConstraint == .nonce(NonceLifetimeConstraint(nonce: config.nonce)) {
                return transactionMessage
            }
        } else {
            instructions[0] = advanceInstruction
        }
    } else {
        instructions.insert(advanceInstruction, at: 0)
    }

    return TransactionMessage(
        version: transactionMessage.version,
        instructions: instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: .nonce(NonceLifetimeConstraint(nonce: config.nonce)),
        config: transactionMessage.config
    )
}

public func isTransactionMessageWithDurableNonceLifetime(_ transactionMessage: TransactionMessage) -> Bool {
    guard case .nonce = transactionMessage.lifetimeConstraint, let first = transactionMessage.instructions.first else {
        return false
    }
    return isAdvanceNonceAccountInstruction(first)
}

public func assertIsTransactionMessageWithDurableNonceLifetime(_ transactionMessage: TransactionMessage) throws(SolanaError) {
    guard isTransactionMessageWithDurableNonceLifetime(transactionMessage) else {
        throw SolanaError(.transactionExpectedNonceLifetime)
    }
}

public func createAdvanceNonceAccountInstruction(
    nonceAccountAddress: Address,
    nonceAuthorityAddress: Address
) -> Instruction {
    Instruction(
        programAddress: systemProgramAddress,
        accounts: [
            .account(writableAccount(nonceAccountAddress)),
            .account(readonlyAccount(recentBlockhashesSysvarAddress)),
            .account(readonlySignerAccount(nonceAuthorityAddress)),
        ],
        data: Data([4, 0, 0, 0])
    )
}

public func isAdvanceNonceAccountInstruction(_ instruction: Instruction) -> Bool {
    guard instruction.programAddress == systemProgramAddress,
          instruction.data == Data([4, 0, 0, 0]),
          let accounts = instruction.accounts,
          accounts.count == 3
    else {
        return false
    }
    return accounts[0].address != systemProgramAddress &&
        accounts[0].role == .writable &&
        accounts[1].address == recentBlockhashesSysvarAddress &&
        accounts[1].role == .readonly &&
        isSignerRole(accounts[2].role)
}

public func appendTransactionMessageInstruction(
    _ instruction: Instruction,
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    appendTransactionMessageInstructions([instruction], transactionMessage)
}

public func appendTransactionMessageInstructions(
    _ instructions: [Instruction],
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    TransactionMessage(
        version: transactionMessage.version,
        instructions: transactionMessage.instructions + instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: transactionMessage.lifetimeConstraint,
        config: transactionMessage.config
    )
}

public func prependTransactionMessageInstruction(
    _ instruction: Instruction,
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    prependTransactionMessageInstructions([instruction], transactionMessage)
}

public func prependTransactionMessageInstructions(
    _ instructions: [Instruction],
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    return TransactionMessage(
        version: transactionMessage.version,
        instructions: instructions + transactionMessage.instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: transactionMessage.lifetimeConstraint,
        config: transactionMessage.config
    )
}

public func compressTransactionMessageUsingAddressLookupTables(
    _ transactionMessage: TransactionMessage,
    addressesByLookupTableAddress: AddressesByLookupTableAddress
) -> TransactionMessage {
    if transactionMessage.version == .legacy {
        return transactionMessage
    }
    let programAddresses = Set(transactionMessage.instructions.map(\.programAddress))
    var eligible = Set<Address>()
    for addresses in addressesByLookupTableAddress.values {
        for address in addresses where !programAddresses.contains(address) {
            eligible.insert(address)
        }
    }

    var updatedAnyInstructions = false
    let instructions = transactionMessage.instructions.map { instruction in
        guard let accounts = instruction.accounts else {
            return instruction
        }
        var updatedAnyAccounts = false
        let nextAccounts = accounts.map { account -> InstructionAccount in
            guard case .account = account,
                  eligible.contains(account.address),
                  !isSignerRole(account.role),
                  let lookup = lookupMeta(address: account.address, role: account.role, in: addressesByLookupTableAddress)
            else {
                return account
            }
            updatedAnyAccounts = true
            updatedAnyInstructions = true
            return .lookup(lookup)
        }
        guard updatedAnyAccounts else {
            return instruction
        }
        return Instruction(programAddress: instruction.programAddress, accounts: nextAccounts, data: instruction.data)
    }

    guard updatedAnyInstructions else {
        return transactionMessage
    }
    return TransactionMessage(
        version: transactionMessage.version,
        instructions: instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: transactionMessage.lifetimeConstraint,
        config: transactionMessage.config
    )
}

public func getSetComputeUnitLimitInstruction(_ units: Int) throws -> Instruction {
    computeBudgetInstruction(discriminator: 2, value: try encodeU32Checked(units))
}

public func isSetComputeUnitLimitInstruction(_ instruction: Instruction) -> Bool {
    isComputeBudgetInstruction(instruction, discriminator: 2, expectedDataLength: 5)
}

public func getComputeUnitLimitFromInstructionData(_ data: Data) throws -> Int {
    try readU32(data, at: 1)
}

public func getTransactionMessageComputeUnitLimit(_ transactionMessage: TransactionMessage) throws -> Int? {
    if transactionMessage.version == .v1 {
        return transactionMessage.config?.computeUnitLimit
    }
    guard let instruction = transactionMessage.instructions.first(where: isSetComputeUnitLimitInstruction) else {
        return nil
    }
    return try getComputeUnitLimitFromInstructionData(instruction.data ?? Data())
}

public func setTransactionMessageComputeUnitLimit(
    _ computeUnitLimit: Int?,
    _ transactionMessage: TransactionMessage
) throws -> TransactionMessage {
    if transactionMessage.version == .v1 {
        return setConfigValue(transactionMessage) { config in
            V1TransactionConfig(
                computeUnitLimit: computeUnitLimit,
                heapSize: config.heapSize,
                loadedAccountsDataSizeLimit: config.loadedAccountsDataSizeLimit,
                priorityFeeLamports: config.priorityFeeLamports
            )
        }
    }
    return try setComputeBudgetInstruction(
        value: computeUnitLimit,
        transactionMessage: transactionMessage,
        predicate: isSetComputeUnitLimitInstruction,
        currentValue: getComputeUnitLimitFromInstructionData,
        makeInstruction: getSetComputeUnitLimitInstruction
    )
}

public func getSetComputeUnitPriceInstruction(_ microLamports: UInt64) -> Instruction {
    computeBudgetInstruction(discriminator: 3, value: encodeU64Unchecked(microLamports))
}

public func isSetComputeUnitPriceInstruction(_ instruction: Instruction) -> Bool {
    isComputeBudgetInstruction(instruction, discriminator: 3, expectedDataLength: 9)
}

public func getPriorityFeeFromInstructionData(_ data: Data) throws -> UInt64 {
    try readU64(data, at: 1)
}

public func getTransactionMessageComputeUnitPrice(_ transactionMessage: TransactionMessage) throws -> UInt64? {
    guard let instruction = transactionMessage.instructions.first(where: isSetComputeUnitPriceInstruction) else {
        return nil
    }
    return try getPriorityFeeFromInstructionData(instruction.data ?? Data())
}

public func setTransactionMessageComputeUnitPrice(
    _ computeUnitPrice: UInt64?,
    _ transactionMessage: TransactionMessage
) throws -> TransactionMessage {
    try setComputeBudgetInstruction(
        value: computeUnitPrice,
        transactionMessage: transactionMessage,
        predicate: isSetComputeUnitPriceInstruction,
        currentValue: getPriorityFeeFromInstructionData,
        makeInstruction: getSetComputeUnitPriceInstruction
    )
}

public func getRequestHeapFrameInstruction(_ bytes: Int) throws -> Instruction {
    computeBudgetInstruction(discriminator: 1, value: try encodeU32Checked(bytes))
}

public func isRequestHeapFrameInstruction(_ instruction: Instruction) -> Bool {
    isComputeBudgetInstruction(instruction, discriminator: 1, expectedDataLength: 5)
}

public func getHeapSizeFromInstructionData(_ data: Data) throws -> Int {
    try readU32(data, at: 1)
}

public func getTransactionMessageHeapSize(_ transactionMessage: TransactionMessage) throws -> Int? {
    if transactionMessage.version == .v1 {
        return transactionMessage.config?.heapSize
    }
    guard let instruction = transactionMessage.instructions.first(where: isRequestHeapFrameInstruction) else {
        return nil
    }
    return try getHeapSizeFromInstructionData(instruction.data ?? Data())
}

public func setTransactionMessageHeapSize(
    _ heapSize: Int?,
    _ transactionMessage: TransactionMessage
) throws -> TransactionMessage {
    if transactionMessage.version == .v1 {
        return setConfigValue(transactionMessage) { config in
            V1TransactionConfig(
                computeUnitLimit: config.computeUnitLimit,
                heapSize: heapSize,
                loadedAccountsDataSizeLimit: config.loadedAccountsDataSizeLimit,
                priorityFeeLamports: config.priorityFeeLamports
            )
        }
    }
    return try setComputeBudgetInstruction(
        value: heapSize,
        transactionMessage: transactionMessage,
        predicate: isRequestHeapFrameInstruction,
        currentValue: getHeapSizeFromInstructionData,
        makeInstruction: getRequestHeapFrameInstruction
    )
}

public func getSetLoadedAccountsDataSizeLimitInstruction(_ limit: Int) throws -> Instruction {
    computeBudgetInstruction(discriminator: 4, value: try encodeU32Checked(limit))
}

public func isSetLoadedAccountsDataSizeLimitInstruction(_ instruction: Instruction) -> Bool {
    isComputeBudgetInstruction(instruction, discriminator: 4, expectedDataLength: 5)
}

public func getLoadedAccountsDataSizeLimitFromInstructionData(_ data: Data) throws -> Int {
    try readU32(data, at: 1)
}

public func getTransactionMessageLoadedAccountsDataSizeLimit(_ transactionMessage: TransactionMessage) throws -> Int? {
    if transactionMessage.version == .v1 {
        return transactionMessage.config?.loadedAccountsDataSizeLimit
    }
    guard let instruction = transactionMessage.instructions.first(where: isSetLoadedAccountsDataSizeLimitInstruction) else {
        return nil
    }
    return try getLoadedAccountsDataSizeLimitFromInstructionData(instruction.data ?? Data())
}

public func setTransactionMessageLoadedAccountsDataSizeLimit(
    _ loadedAccountsDataSizeLimit: Int?,
    _ transactionMessage: TransactionMessage
) throws -> TransactionMessage {
    if transactionMessage.version == .v1 {
        return setConfigValue(transactionMessage) { config in
            V1TransactionConfig(
                computeUnitLimit: config.computeUnitLimit,
                heapSize: config.heapSize,
                loadedAccountsDataSizeLimit: loadedAccountsDataSizeLimit,
                priorityFeeLamports: config.priorityFeeLamports
            )
        }
    }
    return try setComputeBudgetInstruction(
        value: loadedAccountsDataSizeLimit,
        transactionMessage: transactionMessage,
        predicate: isSetLoadedAccountsDataSizeLimitInstruction,
        currentValue: getLoadedAccountsDataSizeLimitFromInstructionData,
        makeInstruction: getSetLoadedAccountsDataSizeLimitInstruction
    )
}

public func getTransactionMessagePriorityFeeLamports(_ transactionMessage: TransactionMessage) -> UInt64? {
    transactionMessage.config?.priorityFeeLamports
}

public func setTransactionMessagePriorityFeeLamports(
    _ priorityFeeLamports: UInt64?,
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    setConfigValue(transactionMessage) { config in
        V1TransactionConfig(
            computeUnitLimit: config.computeUnitLimit,
            heapSize: config.heapSize,
            loadedAccountsDataSizeLimit: config.loadedAccountsDataSizeLimit,
            priorityFeeLamports: priorityFeeLamports
        )
    }
}

public func setTransactionMessageConfig(
    _ config: V1TransactionConfig,
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    let current = transactionMessage.config ?? V1TransactionConfig()
    let merged = V1TransactionConfig(
        computeUnitLimit: config.computeUnitLimit ?? current.computeUnitLimit,
        heapSize: config.heapSize ?? current.heapSize,
        loadedAccountsDataSizeLimit: config.loadedAccountsDataSizeLimit ?? current.loadedAccountsDataSizeLimit,
        priorityFeeLamports: config.priorityFeeLamports ?? current.priorityFeeLamports
    )
    return replaceConfig(merged, in: transactionMessage)
}

public func setTransactionMessageConfig(
    _ patch: V1TransactionConfigPatch,
    _ transactionMessage: TransactionMessage
) -> TransactionMessage {
    let current = transactionMessage.config ?? V1TransactionConfig()
    let merged = V1TransactionConfig(
        computeUnitLimit: patch.computeUnitLimit.apply(to: current.computeUnitLimit),
        heapSize: patch.heapSize.apply(to: current.heapSize),
        loadedAccountsDataSizeLimit: patch.loadedAccountsDataSizeLimit.apply(to: current.loadedAccountsDataSizeLimit),
        priorityFeeLamports: patch.priorityFeeLamports.apply(to: current.priorityFeeLamports)
    )
    return replaceConfig(merged, in: transactionMessage)
}

public func transactionConfigMaskHasPriorityFee(_ mask: Int) throws(SolanaError) -> Bool {
    let priorityFeeBits = mask & transactionConfigPriorityFeeLamportsBitMask
    if priorityFeeBits == 0b01 || priorityFeeBits == 0b10 {
        throw SolanaError(.transactionInvalidConfigMaskPriorityFeeBits, context: ["mask": .int(mask)])
    }
    return priorityFeeBits == transactionConfigPriorityFeeLamportsBitMask
}

public func transactionConfigMaskHasComputeUnitLimit(_ mask: Int) -> Bool {
    (mask & transactionConfigComputeUnitLimitBitMask) != 0
}

public func transactionConfigMaskHasLoadedAccountsDataSizeLimit(_ mask: Int) -> Bool {
    (mask & transactionConfigLoadedAccountsDataSizeLimitBitMask) != 0
}

public func transactionConfigMaskHasHeapSize(_ mask: Int) -> Bool {
    (mask & transactionConfigHeapSizeBitMask) != 0
}

public func getTransactionConfigMask(_ config: V1TransactionConfig) -> Int {
    var mask = 0
    if config.priorityFeeLamports != nil {
        mask |= transactionConfigPriorityFeeLamportsBitMask
    }
    if config.computeUnitLimit != nil {
        mask |= transactionConfigComputeUnitLimitBitMask
    }
    if config.loadedAccountsDataSizeLimit != nil {
        mask |= transactionConfigLoadedAccountsDataSizeLimitBitMask
    }
    if config.heapSize != nil {
        mask |= transactionConfigHeapSizeBitMask
    }
    return mask
}

public func getTransactionConfigValues(_ config: V1TransactionConfig) -> [CompiledTransactionConfigValue] {
    var values: [CompiledTransactionConfigValue] = []
    if let priorityFeeLamports = config.priorityFeeLamports {
        values.append(.u64(priorityFeeLamports))
    }
    if let computeUnitLimit = config.computeUnitLimit {
        values.append(.u32(computeUnitLimit))
    }
    if let loadedAccountsDataSizeLimit = config.loadedAccountsDataSizeLimit {
        values.append(.u32(loadedAccountsDataSizeLimit))
    }
    if let heapSize = config.heapSize {
        values.append(.u32(heapSize))
    }
    return values
}

public func getCompiledMessageHeader(_ orderedAccounts: [InstructionAccount]) -> MessageHeader {
    var numReadonlyNonSignerAccounts = 0
    var numReadonlySignerAccounts = 0
    var numSignerAccounts = 0
    for account in orderedAccounts {
        if case .lookup = account {
            break
        }
        let accountIsWritable = isWritableRole(account.role)
        if isSignerRole(account.role) {
            numSignerAccounts += 1
            if !accountIsWritable {
                numReadonlySignerAccounts += 1
            }
        } else if !accountIsWritable {
            numReadonlyNonSignerAccounts += 1
        }
    }
    return MessageHeader(
        numReadonlyNonSignerAccounts: numReadonlyNonSignerAccounts,
        numReadonlySignerAccounts: numReadonlySignerAccounts,
        numSignerAccounts: numSignerAccounts
    )
}

public func getCompiledInstructions(
    _ instructions: [Instruction],
    orderedAccounts: [InstructionAccount]
) throws -> [CompiledInstruction] {
    let accountIndex = getAccountIndex(orderedAccounts)
    return try instructions.map { instruction in
        let accountIndices = try instruction.accounts?.map { account in
            guard let index = accountIndex[account.address] else {
                throw SolanaError(.transactionAddressMissing, context: ["address": .string(account.address.rawValue)])
            }
            return index
        }
        guard let programAddressIndex = accountIndex[instruction.programAddress] else {
            throw SolanaError(.transactionAddressMissing, context: ["address": .string(instruction.programAddress.rawValue)])
        }
        return CompiledInstruction(
            accountIndices: accountIndices,
            data: instruction.data,
            programAddressIndex: programAddressIndex
        )
    }
}

public func getCompiledStaticAccounts(_ orderedAccounts: [InstructionAccount]) -> [Address] {
    var accounts: [Address] = []
    for account in orderedAccounts {
        if case .lookup = account {
            break
        }
        accounts.append(account.address)
    }
    return accounts
}

public func getCompiledAddressTableLookups(_ orderedAccounts: [InstructionAccount]) -> [AddressTableLookup] {
    var index: [Address: (readonly: [Int], writable: [Int])] = [:]
    for account in orderedAccounts {
        guard case let .lookup(meta) = account else {
            continue
        }
        var entry = index[meta.lookupTableAddress] ?? (readonly: [], writable: [])
        if meta.role == .writable {
            entry.writable.append(meta.addressIndex)
        } else {
            entry.readonly.append(meta.addressIndex)
        }
        index[meta.lookupTableAddress] = entry
    }
    let comparator = getAddressComparator()
    return index.keys.sorted { comparator($0, $1) < 0 }.map { lookupTableAddress in
        let entry = index[lookupTableAddress] ?? (readonly: [], writable: [])
        return AddressTableLookup(
            lookupTableAddress: lookupTableAddress,
            readonlyIndexes: entry.readonly,
            writableIndexes: entry.writable
        )
    }
}

public func getInstructionHeader(_ instruction: Instruction, accountIndex: [Address: Int]) throws -> InstructionHeader {
    guard let programAccountIndex = accountIndex[instruction.programAddress] else {
        throw SolanaError(.transactionAddressMissing, context: ["address": .string(instruction.programAddress.rawValue)])
    }
    return InstructionHeader(
        numInstructionAccounts: instruction.accounts?.count ?? 0,
        numInstructionDataBytes: instruction.data?.count ?? 0,
        programAccountIndex: programAccountIndex
    )
}

public func getInstructionPayload(_ instruction: Instruction, accountIndex: [Address: Int]) throws -> InstructionPayload {
    InstructionPayload(
        instructionAccountIndices: try instruction.accounts?.map { account in
            guard let index = accountIndex[account.address] else {
                throw SolanaError(.transactionAddressMissing, context: ["address": .string(account.address.rawValue)])
            }
            return index
        } ?? [],
        instructionData: instruction.data ?? Data()
    )
}

public func compileTransactionMessage(_ transactionMessage: TransactionMessage) throws -> CompiledTransactionMessage {
    guard let feePayer = transactionMessage.feePayer?.address else {
        throw SolanaError(.transactionFeePayerMissing)
    }
    switch transactionMessage.version {
    case .legacy:
        let orderedAccounts = try orderedAccountsForLegacy(feePayer: feePayer, instructions: transactionMessage.instructions)
        try validateCompileLimits(orderedAccounts: orderedAccounts, instructions: transactionMessage.instructions)
        let accounts = orderedAccounts.map(\.instructionAccount)
        return .legacy(
            LegacyCompiledTransactionMessage(
                header: getCompiledMessageHeader(accounts),
                instructions: try getCompiledInstructions(transactionMessage.instructions, orderedAccounts: accounts),
                lifetimeToken: transactionMessage.lifetimeConstraint?.lifetimeToken,
                staticAccounts: orderedAccounts.map(\.address)
            )
        )
    case .v0:
        let orderedAccounts = try orderedAccountsForV0(feePayer: feePayer, instructions: transactionMessage.instructions)
        try validateCompileLimits(orderedAccounts: orderedAccounts, instructions: transactionMessage.instructions)
        let accounts = orderedAccounts.map(\.instructionAccount)
        let lookups = getCompiledAddressTableLookups(accounts)
        return .v0(
            V0CompiledTransactionMessage(
                addressTableLookups: lookups,
                header: getCompiledMessageHeader(accounts),
                instructions: try getCompiledInstructions(transactionMessage.instructions, orderedAccounts: accounts),
                lifetimeToken: transactionMessage.lifetimeConstraint?.lifetimeToken,
                staticAccounts: getCompiledStaticAccounts(accounts)
            )
        )
    case .v1:
        let orderedAccounts = try orderedAccountsForLegacy(feePayer: feePayer, instructions: transactionMessage.instructions)
        try validateCompileLimits(orderedAccounts: orderedAccounts, instructions: transactionMessage.instructions)
        let accounts = orderedAccounts.map(\.instructionAccount)
        let accountIndex = getAccountIndex(accounts)
        let config = transactionMessage.config ?? V1TransactionConfig()
        return .v1(
            V1CompiledTransactionMessage(
                configMask: getTransactionConfigMask(config),
                configValues: getTransactionConfigValues(config),
                header: getCompiledMessageHeader(accounts),
                instructionHeaders: try transactionMessage.instructions.map { try getInstructionHeader($0, accountIndex: accountIndex) },
                instructionPayloads: try transactionMessage.instructions.map { try getInstructionPayload($0, accountIndex: accountIndex) },
                lifetimeToken: transactionMessage.lifetimeConstraint?.lifetimeToken,
                numInstructions: transactionMessage.instructions.count,
                numStaticAccounts: orderedAccounts.count,
                staticAccounts: orderedAccounts.map(\.address)
            )
        )
    case let .unsupported(version):
        throw SolanaError(.transactionVersionNumberNotSupported, context: ["version": .int(version)])
    }
}

public func decompileTransactionMessage(
    _ compiledTransactionMessage: CompiledTransactionMessage,
    config: DecompileTransactionMessageConfig = DecompileTransactionMessageConfig()
) throws -> TransactionMessage {
    switch compiledTransactionMessage {
    case let .legacy(message):
        let feePayer = try getFeePayer(message.staticAccounts)
        let metas = try getAccountMetas(header: message.header, staticAccounts: message.staticAccounts)
        let instructions = try convertInstructions(message.instructions, accountMetas: metas.map { .account($0) })
        let lifetime = try getLifetimeConstraint(
            messageLifetimeToken: message.lifetimeToken ?? zeroLifetimeToken(),
            instructions: instructions,
            lastValidBlockHeight: config.lastValidBlockHeight
        )
        return applyLifetime(
            lifetime,
            to: appendTransactionMessageInstructions(
                instructions,
                setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
            )
        )
    case let .v0(message):
        let feePayer = try getFeePayer(message.staticAccounts)
        let staticMetas = try getAccountMetas(header: message.header, staticAccounts: message.staticAccounts).map { InstructionAccount.account($0) }
        let lookupMetas = try getAddressLookupMetas(
            compiledAddressTableLookups: message.addressTableLookups ?? [],
            addressesByLookupTableAddress: config.addressesByLookupTableAddress
        ).map { InstructionAccount.lookup($0) }
        let instructions = try convertInstructions(message.instructions, accountMetas: staticMetas + lookupMetas)
        let lifetime = try getLifetimeConstraint(
            messageLifetimeToken: message.lifetimeToken ?? zeroLifetimeToken(),
            instructions: instructions,
            lastValidBlockHeight: config.lastValidBlockHeight
        )
        return applyLifetime(
            lifetime,
            to: appendTransactionMessageInstructions(
                instructions,
                setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
            )
        )
    case let .v1(message):
        let feePayer = try getFeePayer(message.staticAccounts)
        let metas = try getAccountMetas(header: message.header, staticAccounts: message.staticAccounts)
        let transactionConfig = try decompileTransactionConfig(
            configMask: message.configMask,
            configValues: message.configValues
        )
        let instructions = try decompileInstructions(
            instructionHeaders: message.instructionHeaders,
            instructionPayloads: message.instructionPayloads,
            accountMetas: metas
        )
        let lifetime = try getLifetimeConstraint(
            messageLifetimeToken: message.lifetimeToken ?? zeroLifetimeToken(),
            instructions: instructions,
            lastValidBlockHeight: config.lastValidBlockHeight
        )
        return applyLifetime(
            lifetime,
            to: appendTransactionMessageInstructions(
                instructions,
                setTransactionMessageFeePayer(
                    feePayer,
                    setTransactionMessageConfig(transactionConfig, createTransactionMessage(version: .v1))
                )
            )
        )
    }
}

public func decompileTransactionConfig(
    configMask: Int,
    configValues: [CompiledTransactionConfigValue]
) throws -> V1TransactionConfig {
    var index = 0
    var priorityFeeLamports: UInt64?
    var computeUnitLimit: Int?
    var loadedAccountsDataSizeLimit: Int?
    var heapSize: Int?

    if try transactionConfigMaskHasPriorityFee(configMask) {
        priorityFeeLamports = try consumeConfigValue(
            configValues,
            index: &index,
            name: "priorityFeeLamports",
            expectedKind: "u64"
        )
    }
    if transactionConfigMaskHasComputeUnitLimit(configMask) {
        computeUnitLimit = try consumeConfigValue(
            configValues,
            index: &index,
            name: "computeUnitLimit",
            expectedKind: "u32"
        )
    }
    if transactionConfigMaskHasLoadedAccountsDataSizeLimit(configMask) {
        loadedAccountsDataSizeLimit = try consumeConfigValue(
            configValues,
            index: &index,
            name: "loadedAccountsDataSizeLimit",
            expectedKind: "u32"
        )
    }
    if transactionConfigMaskHasHeapSize(configMask) {
        heapSize = try consumeConfigValue(configValues, index: &index, name: "heapSize", expectedKind: "u32")
    }

    return V1TransactionConfig(
        computeUnitLimit: computeUnitLimit,
        heapSize: heapSize,
        loadedAccountsDataSizeLimit: loadedAccountsDataSizeLimit,
        priorityFeeLamports: priorityFeeLamports
    )
}

public func decompileInstructions(
    instructionHeaders: [InstructionHeader],
    instructionPayloads: [InstructionPayload],
    accountMetas: [AccountMeta]
) throws -> [Instruction] {
    guard instructionHeaders.count == instructionPayloads.count else {
        throw SolanaError(
            .transactionInstructionHeadersPayloadsMismatch,
            context: [
                "numInstructionHeaders": .int(instructionHeaders.count),
                "numInstructionPayloads": .int(instructionPayloads.count),
            ]
        )
    }
    return try zip(instructionHeaders, instructionPayloads).map { header, payload in
        let programAddress = try programAddressFromMetas(accountMetas.map { .account($0) }, index: header.programAccountIndex)
        let accounts = try payload.instructionAccountIndices.map { index in
            guard accountMetas.indices.contains(index) else {
                throw SolanaError(
                    .transactionFailedToDecompileInstructionProgramAddressNotFound,
                    context: ["index": .int(index)]
                )
            }
            return InstructionAccount.account(accountMetas[index])
        }
        return Instruction(
            programAddress: programAddress,
            accounts: accounts.isEmpty ? nil : accounts,
            data: payload.instructionData.isEmpty ? nil : payload.instructionData
        )
    }
}

public func getTransactionVersionEncoder() -> AnyVariableSizeEncoder<TransactionVersion> {
    createEncoder(maxSize: 1) { value in
        value == .legacy ? 0 : 1
    } write: { value, bytes, offset in
        let encoded = try encodeTransactionVersion(value)
        try writeData(encoded, into: &bytes, at: offset, codecDescription: "transactionVersion")
        return offset + encoded.count
    }
}

public func getTransactionVersionDecoder() -> AnyVariableSizeDecoder<TransactionVersion> {
    createDecoder(maxSize: 1) { bytes, offset in
        try decodeTransactionVersion(bytes, at: offset)
    }
}

public func getTransactionVersionCodec() -> AnyVariableSizeCodec<TransactionVersion, TransactionVersion> {
    createCodec(maxSize: 1) { value in
        value == .legacy ? 0 : 1
    } write: { value, bytes, offset in
        let encoded = try encodeTransactionVersion(value)
        try writeData(encoded, into: &bytes, at: offset, codecDescription: "transactionVersion")
        return offset + encoded.count
    } read: { bytes, offset in
        try decodeTransactionVersion(bytes, at: offset)
    }
}

public func getCompiledTransactionMessageEncoder() -> AnyVariableSizeEncoder<CompiledTransactionMessage> {
    createEncoder { message in
        try encodeCompiledTransactionMessage(message).count
    } write: { message, bytes, offset in
        let encoded = try encodeCompiledTransactionMessage(message)
        try writeData(encoded, into: &bytes, at: offset, codecDescription: "compiledTransactionMessage")
        return offset + encoded.count
    }
}

public func getCompiledTransactionMessageDecoder() -> AnyVariableSizeDecoder<CompiledTransactionMessage> {
    createDecoder { bytes, offset in
        try decodeCompiledTransactionMessage(bytes, at: offset)
    }
}

public func getCompiledTransactionMessageCodec() -> AnyVariableSizeCodec<CompiledTransactionMessage, CompiledTransactionMessage> {
    createCodec { message in
        try encodeCompiledTransactionMessage(message).count
    } write: { message, bytes, offset in
        let encoded = try encodeCompiledTransactionMessage(message)
        try writeData(encoded, into: &bytes, at: offset, codecDescription: "compiledTransactionMessage")
        return offset + encoded.count
    } read: { bytes, offset in
        try decodeCompiledTransactionMessage(bytes, at: offset)
    }
}

private func setComputeBudgetInstruction<Value: Equatable>(
    value: Value?,
    transactionMessage: TransactionMessage,
    predicate: (Instruction) -> Bool,
    currentValue: (Data) throws -> Value,
    makeInstruction: (Value) throws -> Instruction
) throws -> TransactionMessage {
    let existingIndex = transactionMessage.instructions.firstIndex(where: predicate)
    guard let value else {
        guard let existingIndex else {
            return transactionMessage
        }
        return removeInstruction(at: existingIndex, from: transactionMessage)
    }
    if let current = try getExistingComputeBudgetValue(transactionMessage, predicate: predicate, currentValue: currentValue),
       current == value {
        return transactionMessage
    }
    let newInstruction = try makeInstruction(value)
    guard let existingIndex else {
        return appendTransactionMessageInstruction(newInstruction, transactionMessage)
    }
    return replaceInstruction(at: existingIndex, with: newInstruction, in: transactionMessage)
}

private func getExistingComputeBudgetValue<Value>(
    _ transactionMessage: TransactionMessage,
    predicate: (Instruction) -> Bool,
    currentValue: (Data) throws -> Value
) throws -> Value? {
    guard let instruction = transactionMessage.instructions.first(where: predicate), let data = instruction.data else {
        return nil
    }
    return try currentValue(data)
}

private func replaceInstruction(at index: Int, with instruction: Instruction, in transactionMessage: TransactionMessage) -> TransactionMessage {
    var instructions = transactionMessage.instructions
    instructions[index] = instruction
    return TransactionMessage(
        version: transactionMessage.version,
        instructions: instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: transactionMessage.lifetimeConstraint,
        config: transactionMessage.config
    )
}

private func removeInstruction(at index: Int, from transactionMessage: TransactionMessage) -> TransactionMessage {
    var instructions = transactionMessage.instructions
    instructions.remove(at: index)
    return TransactionMessage(
        version: transactionMessage.version,
        instructions: instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: transactionMessage.lifetimeConstraint,
        config: transactionMessage.config
    )
}

private func setConfigValue(
    _ transactionMessage: TransactionMessage,
    mutate: (V1TransactionConfig) -> V1TransactionConfig
) -> TransactionMessage {
    replaceConfig(mutate(transactionMessage.config ?? V1TransactionConfig()), in: transactionMessage)
}

private func replaceConfig(_ config: V1TransactionConfig, in transactionMessage: TransactionMessage) -> TransactionMessage {
    let nextConfig = config.isEmpty ? nil : config
    if transactionMessage.config == nextConfig {
        return transactionMessage
    }
    return TransactionMessage(
        version: transactionMessage.version,
        instructions: transactionMessage.instructions,
        feePayer: transactionMessage.feePayer,
        lifetimeConstraint: transactionMessage.lifetimeConstraint,
        config: nextConfig
    )
}

private func computeBudgetInstruction(discriminator: UInt8, value: Data) -> Instruction {
    Instruction(programAddress: computeBudgetProgramAddress, data: Data([discriminator]) + value)
}

private func isComputeBudgetInstruction(_ instruction: Instruction, discriminator: UInt8, expectedDataLength: Int) -> Bool {
    instruction.programAddress == computeBudgetProgramAddress &&
        instruction.data?.count == expectedDataLength &&
        instruction.data?.first == discriminator
}

private func orderedAccountsForLegacy(feePayer: Address, instructions: [Instruction]) throws -> [OrderedAccount] {
    var addressMap: [Address: AddressMapEntry] = [
        feePayer: AddressMapEntry(type: .feePayer, role: .writableSigner)
    ]
    var invokedPrograms = Set<Address>()
    for instruction in instructions {
        try upsert(&addressMap, address: instruction.programAddress) { entry in
            invokedPrograms.insert(instruction.programAddress)
            if let entry {
                if isWritableRole(entry.role) {
                    if entry.type == .feePayer {
                        throw invokedProgramCannotPayFees(instruction.programAddress)
                    }
                    throw invokedProgramMustNotBeWritable(instruction.programAddress)
                }
                if entry.type == .static {
                    return entry
                }
            }
            return AddressMapEntry(type: .static, role: .readonly)
        }
        for account in instruction.accounts ?? [] {
            try upsert(&addressMap, address: account.address) { entry in
                let role = account.role
                guard let entry else {
                    return AddressMapEntry(type: .static, role: role)
                }
                switch entry.type {
                case .feePayer:
                    return entry
                case .lookupTable, .static:
                    let nextRole = mergeRoles(entry.role, role)
                    if invokedPrograms.contains(account.address), isWritableRole(role) {
                        throw invokedProgramMustNotBeWritable(account.address)
                    }
                    var next = entry
                    next.type = .static
                    next.role = nextRole
                    next.addressIndex = nil
                    next.lookupTableAddress = nil
                    return next
                }
            }
        }
    }
    return orderedAccounts(from: addressMap)
}

private func orderedAccountsForV0(feePayer: Address, instructions: [Instruction]) throws -> [OrderedAccount] {
    var addressMap: [Address: AddressMapEntry] = [
        feePayer: AddressMapEntry(type: .feePayer, role: .writableSigner)
    ]
    var invokedPrograms = Set<Address>()
    let comparator = getAddressComparator()

    for instruction in instructions {
        try upsert(&addressMap, address: instruction.programAddress) { entry in
            invokedPrograms.insert(instruction.programAddress)
            if let entry {
                if isWritableRole(entry.role) {
                    if entry.type == .feePayer {
                        throw invokedProgramCannotPayFees(instruction.programAddress)
                    }
                    throw invokedProgramMustNotBeWritable(instruction.programAddress)
                }
                if entry.type == .static {
                    return entry
                }
            }
            return AddressMapEntry(type: .static, role: .readonly)
        }

        for account in instruction.accounts ?? [] {
            let accountLookup = account.lookupMeta
            try upsert(&addressMap, address: account.address) { entry in
                let role = account.role
                guard let entry else {
                    if let accountLookup {
                        return AddressMapEntry(
                            type: .lookupTable,
                            role: role,
                            addressIndex: accountLookup.addressIndex,
                            lookupTableAddress: accountLookup.lookupTableAddress
                        )
                    }
                    return AddressMapEntry(type: .static, role: role)
                }

                switch entry.type {
                case .feePayer:
                    return entry
                case .lookupTable:
                    let nextRole = mergeRoles(entry.role, role)
                    if let accountLookup {
                        var next = entry
                        let shouldReplace = entry.lookupTableAddress != accountLookup.lookupTableAddress &&
                            entry.lookupTableAddress.map { comparator(accountLookup.lookupTableAddress, $0) < 0 } == true
                        if shouldReplace {
                            next.lookupTableAddress = accountLookup.lookupTableAddress
                            next.addressIndex = accountLookup.addressIndex
                        }
                        next.role = nextRole
                        return next
                    }
                    if isSignerRole(role) {
                        return AddressMapEntry(type: .static, role: nextRole)
                    }
                    var next = entry
                    next.role = nextRole
                    return next
                case .static:
                    let nextRole = mergeRoles(entry.role, role)
                    if invokedPrograms.contains(account.address) {
                        if isWritableRole(role) {
                            throw invokedProgramMustNotBeWritable(account.address)
                        }
                        var next = entry
                        next.role = nextRole
                        return next
                    }
                    if let accountLookup, !isSignerRole(entry.role) {
                        return AddressMapEntry(
                            type: .lookupTable,
                            role: nextRole,
                            addressIndex: accountLookup.addressIndex,
                            lookupTableAddress: accountLookup.lookupTableAddress
                        )
                    }
                    var next = entry
                    next.role = nextRole
                    return next
                }
            }
        }
    }
    return orderedAccounts(from: addressMap)
}

private func upsert(
    _ addressMap: inout [Address: AddressMapEntry],
    address: Address,
    update: (AddressMapEntry?) throws -> AddressMapEntry
) throws {
    addressMap[address] = try update(addressMap[address])
}

private func orderedAccounts(from addressMap: [Address: AddressMapEntry]) -> [OrderedAccount] {
    let comparator = getAddressComparator()
    return addressMap.map { OrderedAccount(address: $0.key, entry: $0.value) }
        .sorted { lhs, rhs in
            if lhs.entry.type != rhs.entry.type {
                return lhs.entry.type.rawValue < rhs.entry.type.rawValue
            }
            let lhsSigner = isSignerRole(lhs.entry.role)
            let rhsSigner = isSignerRole(rhs.entry.role)
            if lhsSigner != rhsSigner {
                return lhsSigner
            }
            let lhsWritable = isWritableRole(lhs.entry.role)
            let rhsWritable = isWritableRole(rhs.entry.role)
            if lhsWritable != rhsWritable {
                return lhsWritable
            }
            if lhs.entry.type == .lookupTable,
               rhs.entry.type == .lookupTable,
               let lhsLookup = lhs.entry.lookupTableAddress,
               let rhsLookup = rhs.entry.lookupTableAddress,
               lhsLookup != rhsLookup {
                return comparator(lhsLookup, rhsLookup) < 0
            }
            return comparator(lhs.address, rhs.address) < 0
        }
}

private func validateCompileLimits(orderedAccounts: [OrderedAccount], instructions: [Instruction]) throws {
    if orderedAccounts.count > maximumAccounts {
        throw SolanaError(
            .transactionTooManyAccountAddresses,
            context: ["actualCount": .int(orderedAccounts.count), "maxAllowed": .int(maximumAccounts)]
        )
    }
    let numSigners = orderedAccounts.filter { isSignerRole($0.entry.role) }.count
    if numSigners > maximumSigners {
        throw SolanaError(
            .transactionTooManySignerAddresses,
            context: ["actualCount": .int(numSigners), "maxAllowed": .int(maximumSigners)]
        )
    }
    if instructions.count > maximumInstructions {
        throw SolanaError(
            .transactionTooManyInstructions,
            context: ["actualCount": .int(instructions.count), "maxAllowed": .int(maximumInstructions)]
        )
    }
    for (index, instruction) in instructions.enumerated() {
        let count = instruction.accounts?.count ?? 0
        if count > maximumAccountsPerInstruction {
            throw SolanaError(
                .transactionTooManyAccountsInInstruction,
                context: [
                    "actualCount": .int(count),
                    "instructionIndex": .int(index),
                    "maxAllowed": .int(maximumAccountsPerInstruction),
                ]
            )
        }
    }
}

private func getAccountIndex(_ orderedAccounts: [InstructionAccount]) -> [Address: Int] {
    var out: [Address: Int] = [:]
    for (index, account) in orderedAccounts.enumerated() {
        out[account.address] = index
    }
    return out
}

private func getFeePayer(_ staticAccounts: [Address]) throws -> Address {
    guard let feePayer = staticAccounts.first else {
        throw SolanaError(.transactionFailedToDecompileFeePayerMissing)
    }
    return feePayer
}

private func getAccountMetas(header: MessageHeader, staticAccounts: [Address]) throws -> [AccountMeta] {
    let numWritableSignerAccounts = header.numSignerAccounts - header.numReadonlySignerAccounts
    let numWritableNonSignerAccounts = staticAccounts.count - header.numSignerAccounts - header.numReadonlyNonSignerAccounts
    var metas: [AccountMeta] = []
    var accountIndex = 0
    for _ in 0..<max(0, numWritableSignerAccounts) {
        guard staticAccounts.indices.contains(accountIndex) else {
            throw SolanaError(.transactionAddressMissing, context: ["index": .int(accountIndex)])
        }
        metas.append(AccountMeta(address: staticAccounts[accountIndex], role: .writableSigner))
        accountIndex += 1
    }
    for _ in 0..<max(0, header.numReadonlySignerAccounts) {
        guard staticAccounts.indices.contains(accountIndex) else {
            throw SolanaError(.transactionAddressMissing, context: ["index": .int(accountIndex)])
        }
        metas.append(AccountMeta(address: staticAccounts[accountIndex], role: .readonlySigner))
        accountIndex += 1
    }
    for _ in 0..<max(0, numWritableNonSignerAccounts) {
        guard staticAccounts.indices.contains(accountIndex) else {
            throw SolanaError(.transactionAddressMissing, context: ["index": .int(accountIndex)])
        }
        metas.append(AccountMeta(address: staticAccounts[accountIndex], role: .writable))
        accountIndex += 1
    }
    for _ in 0..<max(0, header.numReadonlyNonSignerAccounts) {
        guard staticAccounts.indices.contains(accountIndex) else {
            throw SolanaError(.transactionAddressMissing, context: ["index": .int(accountIndex)])
        }
        metas.append(AccountMeta(address: staticAccounts[accountIndex], role: .readonly))
        accountIndex += 1
    }
    return metas
}

private func convertInstructions(_ instructions: [CompiledInstruction], accountMetas: [InstructionAccount]) throws -> [Instruction] {
    try instructions.map { instruction in
        let programAddress = try programAddressFromMetas(accountMetas, index: instruction.programAddressIndex)
        let accounts = try instruction.accountIndices?.map { index in
            guard accountMetas.indices.contains(index) else {
                throw SolanaError(
                    .transactionFailedToDecompileInstructionProgramAddressNotFound,
                    context: ["index": .int(index)]
                )
            }
            return accountMetas[index]
        }
        return Instruction(
            programAddress: programAddress,
            accounts: accounts?.isEmpty == false ? accounts : nil,
            data: instruction.data?.isEmpty == false ? instruction.data : nil
        )
    }
}

private func programAddressFromMetas(_ accountMetas: [InstructionAccount], index: Int) throws -> Address {
    guard accountMetas.indices.contains(index) else {
        throw SolanaError(
            .transactionFailedToDecompileInstructionProgramAddressNotFound,
            context: ["index": .int(index)]
        )
    }
    return accountMetas[index].address
}

private func getAddressLookupMetas(
    compiledAddressTableLookups: [AddressTableLookup],
    addressesByLookupTableAddress: AddressesByLookupTableAddress
) throws -> [AccountLookupMeta] {
    let missing = compiledAddressTableLookups
        .map(\.lookupTableAddress)
        .filter { addressesByLookupTableAddress[$0] == nil }
    if !missing.isEmpty {
        throw SolanaError(
            .transactionFailedToDecompileAddressLookupTableContentsMissing,
            context: ["lookupTableAddresses": .stringArray(missing.map(\.rawValue))]
        )
    }

    var readonlyMetas: [AccountLookupMeta] = []
    var writableMetas: [AccountLookupMeta] = []
    for lookup in compiledAddressTableLookups {
        let addresses = addressesByLookupTableAddress[lookup.lookupTableAddress] ?? []
        let highest = (lookup.readonlyIndexes + lookup.writableIndexes).max() ?? -1
        if highest >= addresses.count {
            throw SolanaError(
                .transactionFailedToDecompileAddressLookupTableIndexOutOfRange,
                context: [
                    "highestKnownIndex": .int(addresses.count - 1),
                    "highestRequestedIndex": .int(highest),
                    "lookupTableAddress": .string(lookup.lookupTableAddress.rawValue),
                ]
            )
        }
        readonlyMetas.append(
            contentsOf: lookup.readonlyIndexes.map {
                AccountLookupMeta(
                    address: addresses[$0],
                    addressIndex: $0,
                    lookupTableAddress: lookup.lookupTableAddress,
                    role: .readonly
                )
            }
        )
        writableMetas.append(
            contentsOf: lookup.writableIndexes.map {
                AccountLookupMeta(
                    address: addresses[$0],
                    addressIndex: $0,
                    lookupTableAddress: lookup.lookupTableAddress,
                    role: .writable
                )
            }
        )
    }
    return writableMetas + readonlyMetas
}

private enum LifetimeConstraintResolution: Sendable, Equatable {
    case blockhash(BlockhashLifetimeConstraint)
    case nonce(DurableNonceConfig)
}

private func getLifetimeConstraint(
    messageLifetimeToken: String,
    instructions: [Instruction],
    lastValidBlockHeight: UInt64?
) throws -> LifetimeConstraintResolution {
    guard let first = instructions.first, isAdvanceNonceAccountInstruction(first), let accounts = first.accounts else {
        return .blockhash(
            BlockhashLifetimeConstraint(
                blockhash: messageLifetimeToken,
                lastValidBlockHeight: lastValidBlockHeight ?? UInt64.max
            )
        )
    }
    return .nonce(
        DurableNonceConfig(
            nonce: messageLifetimeToken,
            nonceAccountAddress: accounts[0].address,
            nonceAuthorityAddress: accounts[2].address
        )
    )
}

private func applyLifetime(
    _ lifetime: LifetimeConstraintResolution,
    to transactionMessage: TransactionMessage
) -> TransactionMessage {
    switch lifetime {
    case let .blockhash(constraint):
        return setTransactionMessageLifetimeUsingBlockhash(constraint, transactionMessage)
    case let .nonce(config):
        return setTransactionMessageLifetimeUsingDurableNonce(config, transactionMessage)
    }
}

private func consumeConfigValue<T>(
    _ values: [CompiledTransactionConfigValue],
    index: inout Int,
    name: String,
    expectedKind: String
) throws -> T {
    guard values.indices.contains(index) else {
        throw invalidConfigValueKind(name: name, expectedKind: expectedKind, actualKind: "missing")
    }
    defer { index += 1 }
    switch (expectedKind, values[index]) {
    case let ("u32", .u32(value)):
        guard let value = value as? T else { break }
        return value
    case let ("u64", .u64(value)):
        guard let value = value as? T else { break }
        return value
    case ("u32", .u64):
        throw invalidConfigValueKind(name: name, expectedKind: expectedKind, actualKind: "u64")
    case ("u64", .u32):
        throw invalidConfigValueKind(name: name, expectedKind: expectedKind, actualKind: "u32")
    default:
        break
    }
    throw invalidConfigValueKind(name: name, expectedKind: expectedKind, actualKind: "unknown")
}

private func invalidConfigValueKind(name: String, expectedKind: String, actualKind: String) -> SolanaError {
    SolanaError(
        .transactionInvalidConfigValueKind,
        context: ["actualKind": .string(actualKind), "configName": .string(name), "expectedKind": .string(expectedKind)]
    )
}

private func encodeCompiledTransactionMessage(_ message: CompiledTransactionMessage) throws -> Data {
    switch message {
    case let .legacy(message):
        return try encodeLegacyMessage(message)
    case let .v0(message):
        return try encodeV0Message(message)
    case let .v1(message):
        return try encodeV1Message(message)
    }
}

private func decodeCompiledTransactionMessage(_ bytes: Data, at offset: Offset) throws -> (CompiledTransactionMessage, Offset) {
    let (version, _) = try decodeTransactionVersion(bytes, at: offset)
    switch version {
    case .legacy:
        let (message, next) = try decodeLegacyMessage(bytes, at: offset)
        return (.legacy(message), next)
    case .v0:
        let (message, next) = try decodeV0Message(bytes, at: offset)
        return (.v0(message), next)
    case .v1:
        let (message, next) = try decodeV1Message(bytes, at: offset)
        return (.v1(message), next)
    case let .unsupported(version):
        throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(version)])
    }
}

private func encodeLegacyMessage(_ message: LegacyCompiledTransactionMessage) throws -> Data {
    var out = Data()
    try appendHeader(message.header, to: &out)
    try appendShortU16(message.staticAccounts.count, to: &out)
    for account in message.staticAccounts {
        out.append(try getAddressEncoder().encode(account))
    }
    out.append(try encodeLifetimeToken(message.lifetimeToken))
    try appendShortU16(message.instructions.count, to: &out)
    for instruction in message.instructions {
        try appendCompiledInstruction(instruction, to: &out)
    }
    return out
}

private func decodeLegacyMessage(_ bytes: Data, at offset: Offset) throws -> (LegacyCompiledTransactionMessage, Offset) {
    var cursor = offset
    let header = try readHeader(bytes, cursor: &cursor)
    let staticAccounts = try readAddressArray(bytes, cursor: &cursor, count: readShortU16(bytes, cursor: &cursor))
    let lifetimeToken = try readLifetimeToken(bytes, cursor: &cursor)
    let instructions = try readCompiledInstructionArray(bytes, cursor: &cursor)
    return (
        LegacyCompiledTransactionMessage(
            header: header,
            instructions: instructions,
            lifetimeToken: lifetimeToken,
            staticAccounts: staticAccounts
        ),
        cursor
    )
}

private func encodeV0Message(_ message: V0CompiledTransactionMessage) throws -> Data {
    var out = Data()
    out.append(try encodeTransactionVersion(.v0))
    try appendHeader(message.header, to: &out)
    try appendShortU16(message.staticAccounts.count, to: &out)
    for account in message.staticAccounts {
        out.append(try getAddressEncoder().encode(account))
    }
    out.append(try encodeLifetimeToken(message.lifetimeToken))
    try appendShortU16(message.instructions.count, to: &out)
    for instruction in message.instructions {
        try appendCompiledInstruction(instruction, to: &out)
    }
    let lookups = message.addressTableLookups ?? []
    try appendShortU16(lookups.count, to: &out)
    for lookup in lookups {
        out.append(try getAddressEncoder().encode(lookup.lookupTableAddress))
        try appendU8Array(lookup.writableIndexes, to: &out)
        try appendU8Array(lookup.readonlyIndexes, to: &out)
    }
    return out
}

private func decodeV0Message(_ bytes: Data, at offset: Offset) throws -> (V0CompiledTransactionMessage, Offset) {
    var cursor = offset
    let (version, afterVersion) = try decodeTransactionVersion(bytes, at: cursor)
    guard version == .v0 else {
        throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(version.number ?? -1)])
    }
    cursor = afterVersion
    let header = try readHeader(bytes, cursor: &cursor)
    let staticAccounts = try readAddressArray(bytes, cursor: &cursor, count: readShortU16(bytes, cursor: &cursor))
    let lifetimeToken = try readLifetimeToken(bytes, cursor: &cursor)
    let instructions = try readCompiledInstructionArray(bytes, cursor: &cursor)
    let lookupCount = try readShortU16(bytes, cursor: &cursor)
    var lookups: [AddressTableLookup] = []
    for _ in 0..<lookupCount {
        let lookupTableAddress = try getAddressDecoder().read(bytes, at: cursor)
        cursor = lookupTableAddress.1
        let writableIndexes = try readU8Array(bytes, cursor: &cursor)
        let readonlyIndexes = try readU8Array(bytes, cursor: &cursor)
        lookups.append(
            AddressTableLookup(
                lookupTableAddress: lookupTableAddress.0,
                readonlyIndexes: readonlyIndexes,
                writableIndexes: writableIndexes
            )
        )
    }
    return (
        V0CompiledTransactionMessage(
            addressTableLookups: lookups.isEmpty ? nil : lookups,
            header: header,
            instructions: instructions,
            lifetimeToken: lifetimeToken,
            staticAccounts: staticAccounts
        ),
        cursor
    )
}

private func encodeV1Message(_ message: V1CompiledTransactionMessage) throws -> Data {
    var out = Data()
    out.append(try encodeTransactionVersion(.v1))
    try appendHeader(message.header, to: &out)
    try appendU32(message.configMask, to: &out)
    out.append(try encodeLifetimeToken(message.lifetimeToken))
    try appendU8(message.numInstructions, to: &out)
    try appendU8(message.numStaticAccounts, to: &out)
    for account in message.staticAccounts {
        out.append(try getAddressEncoder().encode(account))
    }
    for value in message.configValues {
        switch value {
        case let .u32(value):
            try appendU32(value, to: &out)
        case let .u64(value):
            appendU64(value, to: &out)
        }
    }
    for header in message.instructionHeaders {
        try appendU8(header.programAccountIndex, to: &out)
        try appendU8(header.numInstructionAccounts, to: &out)
        try appendU16(header.numInstructionDataBytes, to: &out)
    }
    for payload in message.instructionPayloads {
        for index in payload.instructionAccountIndices {
            try appendU8(index, to: &out)
        }
        out.append(payload.instructionData)
    }
    return out
}

private func decodeV1Message(_ bytes: Data, at offset: Offset) throws -> (V1CompiledTransactionMessage, Offset) {
    var cursor = offset
    let (version, afterVersion) = try decodeTransactionVersion(bytes, at: cursor)
    guard version == .v1 else {
        throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(version.number ?? -1)])
    }
    cursor = afterVersion
    let header = try readHeader(bytes, cursor: &cursor)
    let configMask = try readU32(bytes, at: cursor)
    cursor += 4
    let lifetimeToken = try readLifetimeToken(bytes, cursor: &cursor)
    let numInstructions = try readU8(bytes, cursor: &cursor)
    let numStaticAccounts = try readU8(bytes, cursor: &cursor)
    let staticAccounts = try readAddressArray(bytes, cursor: &cursor, count: numStaticAccounts)
    let configValues = try readConfigValues(mask: configMask, bytes: bytes, cursor: &cursor)
    var instructionHeaders: [InstructionHeader] = []
    for _ in 0..<numInstructions {
        let programAccountIndex = try readU8(bytes, cursor: &cursor)
        let numInstructionAccounts = try readU8(bytes, cursor: &cursor)
        let numInstructionDataBytes = try readU16(bytes, cursor: &cursor)
        instructionHeaders.append(
            InstructionHeader(
                numInstructionAccounts: numInstructionAccounts,
                numInstructionDataBytes: numInstructionDataBytes,
                programAccountIndex: programAccountIndex
            )
        )
    }
    var instructionPayloads: [InstructionPayload] = []
    for header in instructionHeaders {
        var indices: [Int] = []
        for _ in 0..<header.numInstructionAccounts {
            indices.append(try readU8(bytes, cursor: &cursor))
        }
        let data = try readData(bytes, cursor: &cursor, count: header.numInstructionDataBytes)
        instructionPayloads.append(InstructionPayload(instructionAccountIndices: indices, instructionData: data))
    }
    return (
        V1CompiledTransactionMessage(
            configMask: configMask,
            configValues: configValues,
            header: header,
            instructionHeaders: instructionHeaders,
            instructionPayloads: instructionPayloads,
            lifetimeToken: lifetimeToken,
            numInstructions: numInstructions,
            numStaticAccounts: numStaticAccounts,
            staticAccounts: staticAccounts
        ),
        cursor
    )
}

private func encodeTransactionVersion(_ version: TransactionVersion) throws -> Data {
    switch version {
    case .legacy:
        return Data()
    case .v0:
        return Data([UInt8(versionFlagMask)])
    case .v1:
        return Data([UInt8(1 | versionFlagMask)])
    case let .unsupported(value):
        if value < 0 || value > 127 {
            throw SolanaError(.transactionVersionNumberOutOfRange, context: ["actualVersion": .int(value)])
        }
        throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(value)])
    }
}

private func decodeTransactionVersion(_ bytes: Data, at offset: Offset) throws -> (TransactionVersion, Offset) {
    guard bytes.indices.contains(offset) else {
        return (.legacy, offset)
    }
    let firstByte = Int(bytes[offset])
    if (firstByte & versionFlagMask) == 0 {
        return (.legacy, offset)
    }
    let version = firstByte ^ versionFlagMask
    if version > TransactionVersion.maxSupported {
        throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(version)])
    }
    return (TransactionVersion(number: version), offset + 1)
}

private func appendCompiledInstruction(_ instruction: CompiledInstruction, to data: inout Data) throws {
    try appendU8(instruction.programAddressIndex, to: &data)
    try appendU8Array(instruction.accountIndices ?? [], to: &data)
    let payload = instruction.data ?? Data()
    try appendShortU16(payload.count, to: &data)
    data.append(payload)
}

private func readCompiledInstructionArray(_ bytes: Data, cursor: inout Int) throws -> [CompiledInstruction] {
    let count = try readShortU16(bytes, cursor: &cursor)
    var instructions: [CompiledInstruction] = []
    for _ in 0..<count {
        let programAddressIndex = try readU8(bytes, cursor: &cursor)
        let accountIndices = try readU8Array(bytes, cursor: &cursor)
        let dataLength = try readShortU16(bytes, cursor: &cursor)
        let data = try readData(bytes, cursor: &cursor, count: dataLength)
        instructions.append(
            CompiledInstruction(
                accountIndices: accountIndices.isEmpty ? nil : accountIndices,
                data: data.isEmpty ? nil : data,
                programAddressIndex: programAddressIndex
            )
        )
    }
    return instructions
}

private func appendHeader(_ header: MessageHeader, to data: inout Data) throws {
    try appendU8(header.numSignerAccounts, to: &data)
    try appendU8(header.numReadonlySignerAccounts, to: &data)
    try appendU8(header.numReadonlyNonSignerAccounts, to: &data)
}

private func readHeader(_ bytes: Data, cursor: inout Int) throws -> MessageHeader {
    let numSignerAccounts = try readU8(bytes, cursor: &cursor)
    let numReadonlySignerAccounts = try readU8(bytes, cursor: &cursor)
    let numReadonlyNonSignerAccounts = try readU8(bytes, cursor: &cursor)
    return MessageHeader(
        numReadonlyNonSignerAccounts: numReadonlyNonSignerAccounts,
        numReadonlySignerAccounts: numReadonlySignerAccounts,
        numSignerAccounts: numSignerAccounts
    )
}

private func encodeLifetimeToken(_ token: String?) throws -> Data {
    guard let token else {
        return Data(repeating: 0, count: lifetimeTokenByteLength)
    }
    return try getAddressEncoder().encode(address(token))
}

private func readLifetimeToken(_ bytes: Data, cursor: inout Int) throws -> String {
    let (address, next) = try getAddressDecoder().read(bytes, at: cursor)
    cursor = next
    return address.rawValue
}

private func zeroLifetimeToken() -> String {
    (try? getAddressDecoder().decode(Data(repeating: 0, count: lifetimeTokenByteLength)).rawValue)
        ?? "11111111111111111111111111111111"
}

private func appendU8Array(_ values: [Int], to data: inout Data) throws {
    try appendShortU16(values.count, to: &data)
    for value in values {
        try appendU8(value, to: &data)
    }
}

private func readU8Array(_ bytes: Data, cursor: inout Int) throws -> [Int] {
    let count = try readShortU16(bytes, cursor: &cursor)
    var values: [Int] = []
    for _ in 0..<count {
        values.append(try readU8(bytes, cursor: &cursor))
    }
    return values
}

private func appendShortU16(_ value: Int, to data: inout Data) throws {
    data.append(try getShortU16Encoder().encode(value))
}

private func readShortU16(_ bytes: Data, cursor: inout Int) throws -> Int {
    let (value, next) = try getShortU16Decoder().read(bytes, at: cursor)
    cursor = next
    return value
}

private func readAddressArray(_ bytes: Data, cursor: inout Int, count: Int) throws -> [Address] {
    var addresses: [Address] = []
    for _ in 0..<count {
        let (address, next) = try getAddressDecoder().read(bytes, at: cursor)
        cursor = next
        addresses.append(address)
    }
    return addresses
}

private func readConfigValues(mask: Int, bytes: Data, cursor: inout Int) throws -> [CompiledTransactionConfigValue] {
    var values: [CompiledTransactionConfigValue] = []
    if try transactionConfigMaskHasPriorityFee(mask) {
        values.append(.u64(try readU64(bytes, cursor: &cursor)))
    }
    if transactionConfigMaskHasComputeUnitLimit(mask) {
        values.append(.u32(try readU32(bytes, cursor: &cursor)))
    }
    if transactionConfigMaskHasLoadedAccountsDataSizeLimit(mask) {
        values.append(.u32(try readU32(bytes, cursor: &cursor)))
    }
    if transactionConfigMaskHasHeapSize(mask) {
        values.append(.u32(try readU32(bytes, cursor: &cursor)))
    }
    return values
}

private func appendU8(_ value: Int, to data: inout Data) throws {
    try assertNumberIsBetweenForCodec("u8", min: 0, max: Int(UInt8.max), value: value)
    data.append(UInt8(value))
}

private func appendU16(_ value: Int, to data: inout Data) throws {
    try assertNumberIsBetweenForCodec("u16", min: 0, max: Int(UInt16.max), value: value)
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
}

private func appendU32(_ value: Int, to data: inout Data) throws {
    try assertNumberIsBetweenForCodec("u32", min: 0, max: Int(UInt32.max), value: value)
    let bytes = encodeU32Unchecked(value)
    data.append(bytes)
}

private func appendU64(_ value: UInt64, to data: inout Data) {
    data.append(encodeU64Unchecked(value))
}

private func readU8(_ bytes: Data, cursor: inout Int) throws -> Int {
    let value = try readU8(bytes, at: cursor)
    cursor += 1
    return value
}

private func readU8(_ bytes: Data, at offset: Int) throws -> Int {
    guard bytes.indices.contains(offset) else {
        throw CodecsError.offsetOutOfRange(codecDescription: "u8", offset: offset, bytesLength: bytes.count)
    }
    return Int(bytes[offset])
}

private func readU16(_ bytes: Data, cursor: inout Int) throws -> Int {
    try assertByteArrayHasEnoughBytesForCodec("u16", expected: 2, bytes: bytes, offset: cursor)
    let value = Int(bytes[cursor]) | (Int(bytes[cursor + 1]) << 8)
    cursor += 2
    return value
}

private func readU32(_ bytes: Data, cursor: inout Int) throws -> Int {
    let value = try readU32(bytes, at: cursor)
    cursor += 4
    return value
}

private func readU32(_ bytes: Data, at offset: Int) throws -> Int {
    try assertByteArrayHasEnoughBytesForCodec("u32", expected: 4, bytes: bytes, offset: offset)
    let value = UInt32(bytes[offset]) |
        (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) |
        (UInt32(bytes[offset + 3]) << 24)
    return Int(value)
}

private func readU64(_ bytes: Data, cursor: inout Int) throws -> UInt64 {
    let value = try readU64(bytes, at: cursor)
    cursor += 8
    return value
}

private func readU64(_ bytes: Data, at offset: Int) throws -> UInt64 {
    try assertByteArrayHasEnoughBytesForCodec("u64", expected: 8, bytes: bytes, offset: offset)
    var value: UInt64 = 0
    for index in 0..<8 {
        value |= UInt64(bytes[offset + index]) << UInt64(index * 8)
    }
    return value
}

private func readData(_ bytes: Data, cursor: inout Int, count: Int) throws -> Data {
    try assertByteArrayHasEnoughBytesForCodec("bytes", expected: count, bytes: bytes, offset: cursor)
    let end = cursor + count
    let data = Data(bytes[cursor..<end])
    cursor = end
    return data
}

private func writeData(_ source: Data, into destination: inout Data, at offset: Offset, codecDescription: String) throws(CodecsError) {
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: offset, bytesLength: destination.count)
    let end = offset + source.count
    guard end <= destination.count else {
        throw CodecsError.invalidByteLength(
            codecDescription: codecDescription,
            expected: end,
            bytesLength: destination.count
        )
    }
    destination.replaceSubrange(offset..<end, with: source)
}

private func encodeU32Unchecked(_ value: Int) -> Data {
    Data([
        UInt8(value & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 24) & 0xFF),
    ])
}

private func encodeU32Checked(_ value: Int) throws -> Data {
    try assertNumberIsBetweenForCodec("u32", min: 0, max: Int(UInt32.max), value: value)
    return encodeU32Unchecked(value)
}

private func encodeU64Unchecked(_ value: UInt64) -> Data {
    Data((0..<8).map { UInt8((value >> UInt64($0 * 8)) & 0xFF) })
}

private func lookupMeta(
    address: Address,
    role: AccountRole,
    in addressesByLookupTableAddress: AddressesByLookupTableAddress
) -> AccountLookupMeta? {
    for (lookupTableAddress, addresses) in addressesByLookupTableAddress.orderedPairs {
        if let index = addresses.firstIndex(of: address) {
            return AccountLookupMeta(
                address: address,
                addressIndex: index,
                lookupTableAddress: lookupTableAddress,
                role: role
            )
        }
    }
    return nil
}

private func isValidLifetimeToken(_ value: String) -> Bool {
    do {
        _ = try address(value)
        return true
    } catch {
        return false
    }
}

private func isAdvanceNonceAccountInstruction(
    _ instruction: Instruction,
    nonceAccountAddress: Address,
    nonceAuthorityAddress: Address
) -> Bool {
    guard isAdvanceNonceAccountInstruction(instruction), let accounts = instruction.accounts else {
        return false
    }
    return accounts[0].address == nonceAccountAddress && accounts[2].address == nonceAuthorityAddress
}

private func invokedProgramCannotPayFees(_ programAddress: Address) -> SolanaError {
    SolanaError(.transactionInvokedProgramsCannotPayFees, context: ["programAddress": .string(programAddress.rawValue)])
}

private func invokedProgramMustNotBeWritable(_ programAddress: Address) -> SolanaError {
    SolanaError(.transactionInvokedProgramsMustNotBeWritable, context: ["programAddress": .string(programAddress.rawValue)])
}

private func knownAddress(_ value: String) -> Address {
    Address(unchecked: value)
}

private extension InstructionAccount {
    var lookupMeta: AccountLookupMeta? {
        if case let .lookup(meta) = self {
            return meta
        }
        return nil
    }
}
