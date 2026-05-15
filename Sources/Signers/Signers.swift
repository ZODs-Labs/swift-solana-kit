public import Addresses
public import CryptoBackend
public import Foundation
public import Instructions
public import Keys
public import OffchainMessages
public import Promises
public import SolanaErrors
public import TransactionMessages
public import Transactions

public typealias SignatureDictionary = [Address: SignatureBytes]

public struct SignerIdentity: Sendable, Equatable, Hashable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static func unique() -> SignerIdentity {
        SignerIdentity(UUID().uuidString)
    }
}

public struct SignerConfig: Sendable, Equatable {
    public let abortSignal: AbortSignal?
    public let minContextSlot: UInt64?

    public init(abortSignal: AbortSignal? = nil, minContextSlot: UInt64? = nil) {
        self.abortSignal = abortSignal
        self.minContextSlot = minContextSlot
    }

    public static func == (lhs: SignerConfig, rhs: SignerConfig) -> Bool {
        lhs.abortSignal === rhs.abortSignal && lhs.minContextSlot == rhs.minContextSlot
    }
}

public typealias MessagePartialSignerConfig = SignerConfig
public typealias MessageModifyingSignerConfig = SignerConfig
public typealias TransactionPartialSignerConfig = SignerConfig
public typealias TransactionModifyingSignerConfig = SignerConfig
public typealias TransactionSendingSignerConfig = SignerConfig

public struct SignableMessage: Sendable, Equatable {
    public let content: Data
    public let signatures: SignatureDictionary

    public init(content: Data, signatures: SignatureDictionary = [:]) {
        self.content = content
        self.signatures = signatures
    }
}

public struct MessagePartialSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    private let signMessagesImpl: @Sendable ([SignableMessage], MessagePartialSignerConfig?) async throws -> [SignatureDictionary]

    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        signMessages: @escaping @Sendable ([SignableMessage], MessagePartialSignerConfig?) async throws -> [SignatureDictionary]
    ) {
        self.address = address
        self.identity = identity
        self.signMessagesImpl = signMessages
    }

    public func signMessages(
        _ messages: [SignableMessage],
        config: MessagePartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary] {
        try await signMessagesImpl(messages, config)
    }
}

public struct MessageModifyingSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    private let modifyAndSignMessagesImpl: @Sendable ([SignableMessage], MessageModifyingSignerConfig?) async throws -> [SignableMessage]

    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        modifyAndSignMessages: @escaping @Sendable ([SignableMessage], MessageModifyingSignerConfig?) async throws -> [SignableMessage]
    ) {
        self.address = address
        self.identity = identity
        self.modifyAndSignMessagesImpl = modifyAndSignMessages
    }

    public func modifyAndSignMessages(
        _ messages: [SignableMessage],
        config: MessageModifyingSignerConfig? = nil
    ) async throws -> [SignableMessage] {
        try await modifyAndSignMessagesImpl(messages, config)
    }
}

public struct MessageSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public let partialSigner: MessagePartialSigner?
    public let modifyingSigner: MessageModifyingSigner?

    public init(partialSigner: MessagePartialSigner) {
        self.address = partialSigner.address
        self.identity = partialSigner.identity
        self.partialSigner = partialSigner
        self.modifyingSigner = nil
    }

    public init(modifyingSigner: MessageModifyingSigner) {
        self.address = modifyingSigner.address
        self.identity = modifyingSigner.identity
        self.partialSigner = nil
        self.modifyingSigner = modifyingSigner
    }

    public init(partialSigner: MessagePartialSigner, modifyingSigner: MessageModifyingSigner) throws(SolanaError) {
        guard partialSigner.address == modifyingSigner.address else {
            throw SolanaError(.signerAddressCannotHaveMultipleSigners, context: ["address": .string(modifyingSigner.address.rawValue)])
        }
        guard partialSigner.identity == modifyingSigner.identity else {
            throw SolanaError(.signerAddressCannotHaveMultipleSigners, context: ["address": .string(partialSigner.address.rawValue)])
        }
        self.address = partialSigner.address
        self.identity = partialSigner.identity
        self.partialSigner = partialSigner
        self.modifyingSigner = modifyingSigner
    }
}

public struct TransactionPartialSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    private let signTransactionsImpl: @Sendable ([Transaction], TransactionPartialSignerConfig?) async throws -> [SignatureDictionary]

    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        signTransactions: @escaping @Sendable ([Transaction], TransactionPartialSignerConfig?) async throws -> [SignatureDictionary]
    ) {
        self.address = address
        self.identity = identity
        self.signTransactionsImpl = signTransactions
    }

    public func signTransactions(
        _ transactions: [Transaction],
        config: TransactionPartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary] {
        try await signTransactionsImpl(transactions, config)
    }
}

public struct TransactionModifyingSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    private let modifyAndSignTransactionsImpl: @Sendable ([Transaction], TransactionModifyingSignerConfig?) async throws -> [Transaction]

    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        modifyAndSignTransactions: @escaping @Sendable ([Transaction], TransactionModifyingSignerConfig?) async throws -> [Transaction]
    ) {
        self.address = address
        self.identity = identity
        self.modifyAndSignTransactionsImpl = modifyAndSignTransactions
    }

    public func modifyAndSignTransactions(
        _ transactions: [Transaction],
        config: TransactionModifyingSignerConfig? = nil
    ) async throws -> [Transaction] {
        try await modifyAndSignTransactionsImpl(transactions, config)
    }
}

public struct TransactionSendingSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    private let signAndSendTransactionsImpl: @Sendable ([Transaction], TransactionSendingSignerConfig?) async throws -> [SignatureBytes]

    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        signAndSendTransactions: @escaping @Sendable ([Transaction], TransactionSendingSignerConfig?) async throws -> [SignatureBytes]
    ) {
        self.address = address
        self.identity = identity
        self.signAndSendTransactionsImpl = signAndSendTransactions
    }

    public func signAndSendTransactions(
        _ transactions: [Transaction],
        config: TransactionSendingSignerConfig? = nil
    ) async throws -> [SignatureBytes] {
        try await signAndSendTransactionsImpl(transactions, config)
    }
}

public struct TransactionSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public let partialSigner: TransactionPartialSigner?
    public let modifyingSigner: TransactionModifyingSigner?
    public let sendingSigner: TransactionSendingSigner?

    public init(partialSigner: TransactionPartialSigner) {
        self.address = partialSigner.address
        self.identity = partialSigner.identity
        self.partialSigner = partialSigner
        self.modifyingSigner = nil
        self.sendingSigner = nil
    }

    public init(modifyingSigner: TransactionModifyingSigner) {
        self.address = modifyingSigner.address
        self.identity = modifyingSigner.identity
        self.partialSigner = nil
        self.modifyingSigner = modifyingSigner
        self.sendingSigner = nil
    }

    public init(sendingSigner: TransactionSendingSigner) {
        self.address = sendingSigner.address
        self.identity = sendingSigner.identity
        self.partialSigner = nil
        self.modifyingSigner = nil
        self.sendingSigner = sendingSigner
    }

    public init(
        partialSigner: TransactionPartialSigner? = nil,
        modifyingSigner: TransactionModifyingSigner? = nil,
        sendingSigner: TransactionSendingSigner? = nil
    ) throws(SolanaError) {
        guard partialSigner != nil || modifyingSigner != nil || sendingSigner != nil else {
            throw SolanaError(.signerExpectedTransactionSigner)
        }
        let addresses = [partialSigner?.address, modifyingSigner?.address, sendingSigner?.address].compactMap { $0 }
        guard let address = addresses.first, addresses.allSatisfy({ $0 == address }) else {
            throw SolanaError(.signerAddressCannotHaveMultipleSigners, context: ["address": .string(addresses.first?.rawValue ?? "")])
        }
        let identities = [partialSigner?.identity, modifyingSigner?.identity, sendingSigner?.identity].compactMap { $0 }
        guard let identity = identities.first, identities.allSatisfy({ $0 == identity }) else {
            throw SolanaError(.signerAddressCannotHaveMultipleSigners, context: ["address": .string(address.rawValue)])
        }
        self.address = address
        self.identity = identity
        self.partialSigner = partialSigner
        self.modifyingSigner = modifyingSigner
        self.sendingSigner = sendingSigner
    }
}

public struct KeyPairSigner: Sendable {
    public let address: Address
    public let keyPair: KeyPair
    public let identity: SignerIdentity
    private let backend: any CryptoBackend

    public init(address: Address, keyPair: KeyPair, identity: SignerIdentity, backend: any CryptoBackend) {
        self.address = address
        self.keyPair = keyPair
        self.identity = identity
        self.backend = backend
    }

    public func signMessages(
        _ messages: [SignableMessage],
        config: MessagePartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary] {
        try messages.map { message in
            let signature = try signBytes(message.content, with: keyPair.privateKey, using: backend)
            return [address: signature]
        }
    }

    public func signTransactions(
        _ transactions: [Transaction],
        config: TransactionPartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary] {
        try transactions.map { transaction in
            let signedTransaction = try partiallySignTransaction([keyPair], transaction, using: backend)
            guard let signature = signedTransaction.signatures.signature(for: address) else {
                return SignatureDictionary()
            }
            return [address: signature]
        }
    }

    public var messagePartialSigner: MessagePartialSigner {
        MessagePartialSigner(address: address, identity: identity) { messages, config in
            try await signMessages(messages, config: config)
        }
    }

    public var transactionPartialSigner: TransactionPartialSigner {
        TransactionPartialSigner(address: address, identity: identity) { transactions, config in
            try await signTransactions(transactions, config: config)
        }
    }

    public var messageSigner: MessageSigner {
        MessageSigner(partialSigner: messagePartialSigner)
    }

    public var transactionSigner: TransactionSigner {
        TransactionSigner(partialSigner: transactionPartialSigner)
    }
}

public struct NoopSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity

    public init(address: Address) {
        self.init(address: address, identity: noopSignerIdentity(address))
    }

    public init(address: Address, identity: SignerIdentity) {
        self.address = address
        self.identity = identity
    }

    public var messagePartialSigner: MessagePartialSigner {
        MessagePartialSigner(address: address, identity: identity) { messages, _ in
            Array(repeating: SignatureDictionary(), count: messages.count)
        }
    }

    public var transactionPartialSigner: TransactionPartialSigner {
        TransactionPartialSigner(address: address, identity: identity) { transactions, _ in
            Array(repeating: SignatureDictionary(), count: transactions.count)
        }
    }

    public var messageSigner: MessageSigner {
        MessageSigner(partialSigner: messagePartialSigner)
    }

    public var transactionSigner: TransactionSigner {
        TransactionSigner(partialSigner: transactionPartialSigner)
    }
}

public struct AccountSignerMeta: Sendable {
    public let address: Address
    public let role: AccountRole
    public let signer: TransactionSigner

    public init(address: Address, role: AccountRole, signer: TransactionSigner) throws(SolanaError) {
        guard isSignerRole(role) else {
            throw SolanaError(.signerExpectedTransactionSigner, context: ["address": .string(address.rawValue)])
        }
        guard signer.address == address else {
            throw SolanaError(.signerAddressCannotHaveMultipleSigners, context: ["address": .string(address.rawValue)])
        }
        self.address = address
        self.role = role
        self.signer = signer
    }
}

public enum InstructionAccountWithSigner: Sendable {
    case account(AccountMeta)
    case lookup(AccountLookupMeta)
    case signer(AccountSignerMeta)

    public var address: Address {
        switch self {
        case let .account(meta):
            return meta.address
        case let .lookup(meta):
            return meta.address
        case let .signer(meta):
            return meta.address
        }
    }

    public var role: AccountRole {
        switch self {
        case let .account(meta):
            return meta.role
        case let .lookup(meta):
            return meta.role
        case let .signer(meta):
            return meta.role
        }
    }

    public var signer: TransactionSigner? {
        if case let .signer(meta) = self {
            return meta.signer
        }
        return nil
    }

    public var instructionAccount: InstructionAccount {
        switch self {
        case let .account(meta):
            return .account(meta)
        case let .lookup(meta):
            return .lookup(meta)
        case let .signer(meta):
            return .account(AccountMeta(address: meta.address, role: meta.role))
        }
    }
}

public struct InstructionWithSigners: Sendable {
    public let programAddress: Address
    public let accounts: [InstructionAccountWithSigner]?
    public let data: Data?

    public init(programAddress: Address, accounts: [InstructionAccountWithSigner]? = nil, data: Data? = nil) {
        self.programAddress = programAddress
        self.accounts = accounts
        self.data = data
    }

    public init(_ instruction: Instruction) {
        self.programAddress = instruction.programAddress
        self.accounts = instruction.accounts?.map {
            switch $0 {
            case let .account(meta):
                return .account(meta)
            case let .lookup(meta):
                return .lookup(meta)
            }
        }
        self.data = instruction.data
    }

    public var instruction: Instruction {
        Instruction(
            programAddress: programAddress,
            accounts: accounts?.map(\.instructionAccount),
            data: data
        )
    }
}

public struct TransactionMessageWithSigners: Sendable {
    public let transactionMessage: TransactionMessage
    public let feePayerSigner: TransactionSigner?
    public let instructions: [InstructionWithSigners]

    public init(
        transactionMessage: TransactionMessage,
        feePayerSigner: TransactionSigner? = nil,
        instructions: [InstructionWithSigners]? = nil
    ) {
        self.transactionMessage = transactionMessage
        self.feePayerSigner = feePayerSigner
        self.instructions = instructions ?? transactionMessage.instructions.map(InstructionWithSigners.init)
    }
}

public struct OffchainMessageSignatorySigner: Sendable {
    public let address: Address
    public let signer: MessageSigner

    public init(address: Address, signer: MessageSigner) throws(SolanaError) {
        guard address == signer.address else {
            throw SolanaError(.signerAddressCannotHaveMultipleSigners, context: ["address": .string(address.rawValue)])
        }
        self.address = address
        self.signer = signer
    }
}

public enum OffchainMessageRequiredSignatory: Sendable {
    case signatory(OffchainMessageSignatory)
    case signer(OffchainMessageSignatorySigner)

    public var address: Address {
        switch self {
        case let .signatory(signatory):
            return signatory.address
        case let .signer(signatorySigner):
            return signatorySigner.address
        }
    }

    public var signer: MessageSigner? {
        if case let .signer(signatorySigner) = self {
            return signatorySigner.signer
        }
        return nil
    }

    public var signatory: OffchainMessageSignatory {
        OffchainMessageSignatory(address: address)
    }
}

public struct OffchainMessageWithSigners: Sendable {
    public let message: OffchainMessage
    public let requiredSignatories: [OffchainMessageRequiredSignatory]

    public init(message: OffchainMessage, requiredSignatories: [OffchainMessageRequiredSignatory]) {
        self.message = message
        self.requiredSignatories = requiredSignatories
    }
}

public func createSignableMessage(_ content: Data, signatures: SignatureDictionary = [:]) -> SignableMessage {
    SignableMessage(content: content, signatures: signatures)
}

public func createSignableMessage(_ text: String, signatures: SignatureDictionary = [:]) -> SignableMessage {
    SignableMessage(content: Data(text.utf8), signatures: signatures)
}

public func isMessagePartialSigner(_ signer: MessageSigner) -> Bool {
    signer.partialSigner != nil
}

public func assertIsMessagePartialSigner(_ signer: MessageSigner) throws(SolanaError) {
    guard isMessagePartialSigner(signer) else {
        throw SolanaError(.signerExpectedMessagePartialSigner, context: ["address": .string(signer.address.rawValue)])
    }
}

public func isMessageModifyingSigner(_ signer: MessageSigner) -> Bool {
    signer.modifyingSigner != nil
}

public func assertIsMessageModifyingSigner(_ signer: MessageSigner) throws(SolanaError) {
    guard isMessageModifyingSigner(signer) else {
        throw SolanaError(.signerExpectedMessageModifyingSigner, context: ["address": .string(signer.address.rawValue)])
    }
}

public func isMessageSigner(_ signer: MessageSigner) -> Bool {
    isMessagePartialSigner(signer) || isMessageModifyingSigner(signer)
}

public func assertIsMessageSigner(_ signer: MessageSigner) throws(SolanaError) {
    guard isMessageSigner(signer) else {
        throw SolanaError(.signerExpectedMessageSigner, context: ["address": .string(signer.address.rawValue)])
    }
}

public func isTransactionPartialSigner(_ signer: TransactionSigner) -> Bool {
    signer.partialSigner != nil
}

public func assertIsTransactionPartialSigner(_ signer: TransactionSigner) throws(SolanaError) {
    guard isTransactionPartialSigner(signer) else {
        throw SolanaError(.signerExpectedTransactionPartialSigner, context: ["address": .string(signer.address.rawValue)])
    }
}

public func isTransactionModifyingSigner(_ signer: TransactionSigner) -> Bool {
    signer.modifyingSigner != nil
}

public func assertIsTransactionModifyingSigner(_ signer: TransactionSigner) throws(SolanaError) {
    guard isTransactionModifyingSigner(signer) else {
        throw SolanaError(.signerExpectedTransactionModifyingSigner, context: ["address": .string(signer.address.rawValue)])
    }
}

public func isTransactionSendingSigner(_ signer: TransactionSigner) -> Bool {
    signer.sendingSigner != nil
}

public func assertIsTransactionSendingSigner(_ signer: TransactionSigner) throws(SolanaError) {
    guard isTransactionSendingSigner(signer) else {
        throw SolanaError(.signerExpectedTransactionSendingSigner, context: ["address": .string(signer.address.rawValue)])
    }
}

public func isTransactionSigner(_ signer: TransactionSigner) -> Bool {
    isTransactionPartialSigner(signer) || isTransactionModifyingSigner(signer) || isTransactionSendingSigner(signer)
}

public func assertIsTransactionSigner(_ signer: TransactionSigner) throws(SolanaError) {
    guard isTransactionSigner(signer) else {
        throw SolanaError(.signerExpectedTransactionSigner, context: ["address": .string(signer.address.rawValue)])
    }
}

public func isKeyPairSigner(_: KeyPairSigner) -> Bool {
    true
}

public func assertIsKeyPairSigner(_: KeyPairSigner) throws(SolanaError) {}

public func createSignerFromKeyPair(
    _ keyPair: KeyPair,
    using backend: any CryptoBackend,
    identity: SignerIdentity = .unique()
) throws -> KeyPairSigner {
    let address = try getAddressFromPublicKey(keyPair.publicKey.rawValue)
    return KeyPairSigner(address: address, keyPair: keyPair, identity: identity, backend: backend)
}

public func generateKeyPairSigner(using backend: any CryptoBackend, identity: SignerIdentity = .unique()) throws -> KeyPairSigner {
    try createSignerFromKeyPair(generateKeyPair(using: backend), using: backend, identity: identity)
}

public func createKeyPairSignerFromBytes(
    _ bytes: Data,
    using backend: any CryptoBackend,
    identity: SignerIdentity = .unique()
) throws -> KeyPairSigner {
    try createSignerFromKeyPair(createKeyPairFromBytes(bytes, using: backend), using: backend, identity: identity)
}

public func createKeyPairSignerFromPrivateKeyBytes(
    _ bytes: Data,
    using backend: any CryptoBackend,
    identity: SignerIdentity = .unique()
) throws -> KeyPairSigner {
    try createSignerFromKeyPair(createKeyPairFromPrivateKeyBytes(bytes, using: backend), using: backend, identity: identity)
}

public func createNoopSigner(address: Address) -> NoopSigner {
    NoopSigner(address: address)
}

public func createNoopSigner(address: Address, identity: SignerIdentity) -> NoopSigner {
    NoopSigner(address: address, identity: identity)
}

public func deduplicateMessageSigners(_ signers: [MessageSigner]) throws(SolanaError) -> [MessageSigner] {
    try deduplicateSigners(signers)
}

public func deduplicateTransactionSigners(_ signers: [TransactionSigner]) throws(SolanaError) -> [TransactionSigner] {
    try deduplicateSigners(signers)
}

public func getSignersFromInstruction(_ instruction: InstructionWithSigners) throws(SolanaError) -> [TransactionSigner] {
    try deduplicateTransactionSigners((instruction.accounts ?? []).compactMap(\.signer))
}

public func getSignersFromTransactionMessage(_ transactionMessage: TransactionMessageWithSigners) throws(SolanaError) -> [TransactionSigner] {
    try deduplicateTransactionSigners(
        [transactionMessage.feePayerSigner].compactMap { $0 } +
            transactionMessage.instructions.flatMap { instruction in
                (instruction.accounts ?? []).compactMap(\.signer)
            }
    )
}

public func addSignersToInstruction(_ signers: [TransactionSigner], _ instruction: Instruction) throws(SolanaError) -> InstructionWithSigners {
    try addSignersToInstruction(signers, InstructionWithSigners(instruction))
}

public func addSignersToInstruction(
    _ signers: [TransactionSigner],
    _ instruction: InstructionWithSigners
) throws(SolanaError) -> InstructionWithSigners {
    guard let accounts = instruction.accounts, !accounts.isEmpty else {
        return instruction
    }
    let signers = try deduplicateTransactionSigners(signers)
    let signerByAddress = Dictionary(uniqueKeysWithValues: signers.map { ($0.address, $0) })
    var accountsWithSigners: [InstructionAccountWithSigner] = []
    accountsWithSigners.reserveCapacity(accounts.count)
    for account in accounts {
        switch account {
        case .signer:
            accountsWithSigners.append(account)
        case let .lookup(meta):
            accountsWithSigners.append(.lookup(meta))
        case let .account(meta):
            guard isSignerRole(meta.role), let signer = signerByAddress[meta.address] else {
                accountsWithSigners.append(.account(meta))
                continue
            }
            accountsWithSigners.append(try .signer(AccountSignerMeta(address: meta.address, role: meta.role, signer: signer)))
        }
    }
    return InstructionWithSigners(programAddress: instruction.programAddress, accounts: accountsWithSigners, data: instruction.data)
}

public func addSignersToTransactionMessage(
    _ signers: [TransactionSigner],
    _ transactionMessage: TransactionMessage
) throws(SolanaError) -> TransactionMessageWithSigners {
    try addSignersToTransactionMessage(signers, TransactionMessageWithSigners(transactionMessage: transactionMessage))
}

public func addSignersToTransactionMessage(
    _ signers: [TransactionSigner],
    _ transactionMessage: TransactionMessageWithSigners
) throws(SolanaError) -> TransactionMessageWithSigners {
    let signers = try deduplicateTransactionSigners(signers)
    let feePayerSigner = transactionMessage.feePayerSigner ?? transactionMessage.transactionMessage.feePayer.flatMap { feePayer in
        signers.first { $0.address == feePayer.address }
    }
    var instructions: [InstructionWithSigners] = []
    instructions.reserveCapacity(transactionMessage.instructions.count)
    for instruction in transactionMessage.instructions {
        instructions.append(try addSignersToInstruction(signers, instruction))
    }
    return TransactionMessageWithSigners(
        transactionMessage: transactionMessage.transactionMessage,
        feePayerSigner: feePayerSigner,
        instructions: instructions
    )
}

public func setTransactionMessageFeePayerSigner(
    _ feePayer: TransactionSigner,
    _ transactionMessage: TransactionMessage
) -> TransactionMessageWithSigners {
    let message = setTransactionMessageFeePayer(feePayer.address, transactionMessage)
    return TransactionMessageWithSigners(transactionMessage: message, feePayerSigner: feePayer)
}

public func getSignersFromOffchainMessage(_ offchainMessage: OffchainMessageWithSigners) throws(SolanaError) -> [MessageSigner] {
    try deduplicateMessageSigners(offchainMessage.requiredSignatories.compactMap(\.signer))
}

public func partiallySignOffchainMessageWithSigners(
    _ offchainMessage: OffchainMessageWithSigners,
    config: MessagePartialSignerConfig? = nil
) async throws -> OffchainMessageEnvelope {
    let signers = try getSignersFromOffchainMessage(offchainMessage)
    let categorized = categorizeMessageSigners(signers)
    let envelope = try compileOffchainMessageEnvelope(offchainMessage.message)
    return try await signModifyingAndPartialMessageSigners(
        envelope,
        modifyingSigners: categorized.modifyingSigners,
        partialSigners: categorized.partialSigners,
        config: config
    )
}

public func signOffchainMessageWithSigners(
    _ offchainMessage: OffchainMessageWithSigners,
    config: MessagePartialSignerConfig? = nil
) async throws -> OffchainMessageEnvelope {
    let signedEnvelope = try await partiallySignOffchainMessageWithSigners(offchainMessage, config: config)
    try assertIsFullySignedOffchainMessageEnvelope(signedEnvelope)
    return signedEnvelope
}

public func isTransactionMessageWithSingleSendingSigner(_ transactionMessage: TransactionMessageWithSigners) -> Bool {
    do {
        try assertIsTransactionMessageWithSingleSendingSigner(transactionMessage)
        return true
    } catch {
        return false
    }
}

public func assertIsTransactionMessageWithSingleSendingSigner(
    _ transactionMessage: TransactionMessageWithSigners
) throws(SolanaError) {
    try assertContainsResolvableTransactionSendingSigner(getSignersFromTransactionMessage(transactionMessage))
}

public func assertContainsResolvableTransactionSendingSigner(_ signers: [TransactionSigner]) throws(SolanaError) {
    let sendingSigners = signers.filter(isTransactionSendingSigner)
    if sendingSigners.isEmpty {
        throw SolanaError(.signerTransactionSendingSignerMissing)
    }
    let sendingOnlySigners = sendingSigners.filter { signer in
        !isTransactionPartialSigner(signer) && !isTransactionModifyingSigner(signer)
    }
    if sendingOnlySigners.count > 1 {
        throw SolanaError(.signerTransactionCannotHaveMultipleSendingSigners)
    }
}

public func partiallySignTransactionMessageWithSigners(
    _ transactionMessage: TransactionMessageWithSigners,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction {
    let signers = try getSignersFromTransactionMessage(transactionMessage).filter {
        isTransactionModifyingSigner($0) || isTransactionPartialSigner($0)
    }
    return try await partiallySignTransactionWithSigners(signers, compileTransaction(transactionMessage.transactionMessage), config: config)
}

public func signTransactionMessageWithSigners(
    _ transactionMessage: TransactionMessageWithSigners,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction {
    let signedTransaction = try await partiallySignTransactionMessageWithSigners(transactionMessage, config: config)
    try assertIsFullySignedTransaction(signedTransaction)
    return signedTransaction
}

public func signAndSendTransactionMessageWithSigners(
    _ transactionMessage: TransactionMessageWithSigners,
    config: TransactionSendingSignerConfig? = nil
) async throws -> SignatureBytes {
    try await signAndSendTransactionWithSigners(
        getSignersFromTransactionMessage(transactionMessage).filter(isTransactionSigner),
        compileTransaction(transactionMessage.transactionMessage),
        config: config
    )
}

public func partiallySignTransactionWithSigners(
    _ signers: [TransactionSigner],
    _ transaction: Transaction,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction {
    let categorized = try categorizeTransactionSigners(
        deduplicateTransactionSigners(signers),
        identifySendingSigner: false
    )
    return try await signModifyingAndPartialTransactionSigners(
        transaction,
        modifyingSigners: categorized.modifyingSigners,
        partialSigners: categorized.partialSigners,
        config: config
    )
}

public func signTransactionWithSigners(
    _ signers: [TransactionSigner],
    _ transaction: Transaction,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction {
    let signedTransaction = try await partiallySignTransactionWithSigners(signers, transaction, config: config)
    try assertIsFullySignedTransaction(signedTransaction)
    return signedTransaction
}

public func signAndSendTransactionWithSigners(
    _ signers: [TransactionSigner],
    _ transaction: Transaction,
    config: TransactionSendingSignerConfig? = nil
) async throws -> SignatureBytes {
    try assertContainsResolvableTransactionSendingSigner(signers)
    let categorized = try categorizeTransactionSigners(deduplicateTransactionSigners(signers))
    try await throwIfAborted(config)
    let signedTransaction = try await signModifyingAndPartialTransactionSigners(
        transaction,
        modifyingSigners: categorized.modifyingSigners,
        partialSigners: categorized.partialSigners,
        config: config
    )
    guard let sendingSigner = categorized.sendingSigner else {
        throw SolanaError(.signerTransactionSendingSignerMissing)
    }
    try Task.checkCancellation()
    try await throwIfAborted(config)
    let signatures = try await sendingSigner.signAndSendTransactions([signedTransaction], config: config)
    try Task.checkCancellation()
    try await throwIfAborted(config)
    guard let signature = signatures.first else {
        throw SolanaError(.signerTransactionSendingSignerMissing)
    }
    return signature
}

private func deduplicateSigners<T>(
    _ signers: [T],
    address: (T) -> Address,
    identity: (T) -> SignerIdentity
) throws(SolanaError) -> [T] {
    var deduplicated: [(Address, SignerIdentity, T)] = []
    for signer in signers {
        let signerAddress = address(signer)
        let signerIdentity = identity(signer)
        if let existing = deduplicated.first(where: { $0.0 == signerAddress }) {
            if existing.1 != signerIdentity {
                throw SolanaError(.signerAddressCannotHaveMultipleSigners, context: ["address": .string(signerAddress.rawValue)])
            }
            continue
        }
        deduplicated.append((signerAddress, signerIdentity, signer))
    }
    return deduplicated.map(\.2)
}

private func deduplicateSigners(_ signers: [MessageSigner]) throws(SolanaError) -> [MessageSigner] {
    try deduplicateSigners(signers, address: \.address, identity: \.identity)
}

private func deduplicateSigners(_ signers: [TransactionSigner]) throws(SolanaError) -> [TransactionSigner] {
    try deduplicateSigners(signers, address: \.address, identity: \.identity)
}

private func noopSignerIdentity(_ address: Address) -> SignerIdentity {
    SignerIdentity("noop:\(address.rawValue)")
}

private func categorizeMessageSigners(_ signers: [MessageSigner]) -> (
    modifyingSigners: [MessageModifyingSigner],
    partialSigners: [MessagePartialSigner]
) {
    let modifyingSigners = identifyMessageModifyingSigners(signers)
    let partialSigners = signers.compactMap(\.partialSigner).filter { partialSigner in
        !modifyingSigners.contains { $0.identity == partialSigner.identity && $0.address == partialSigner.address }
    }
    return (modifyingSigners, partialSigners)
}

private func identifyMessageModifyingSigners(_ signers: [MessageSigner]) -> [MessageModifyingSigner] {
    let modifyingSigners = signers.compactMap(\.modifyingSigner)
    if modifyingSigners.isEmpty {
        return []
    }
    let nonPartialSigners = signers.filter {
        $0.modifyingSigner != nil && $0.partialSigner == nil
    }.compactMap(\.modifyingSigner)
    if !nonPartialSigners.isEmpty {
        return nonPartialSigners
    }
    return [modifyingSigners[0]]
}

private func signModifyingAndPartialMessageSigners(
    _ message: SignableMessage,
    modifyingSigners: [MessageModifyingSigner],
    partialSigners: [MessagePartialSigner],
    config: MessageModifyingSignerConfig?
) async throws -> SignableMessage {
    var modifiedMessage = message
    for modifyingSigner in modifyingSigners {
        try Task.checkCancellation()
        try await throwIfAborted(config)
        guard let signed = try await modifyingSigner.modifyAndSignMessages([modifiedMessage], config: config).first else {
            throw SolanaError(.signerExpectedMessageModifyingSigner, context: ["address": .string(modifyingSigner.address.rawValue)])
        }
        modifiedMessage = signed
    }
    try Task.checkCancellation()
    try await throwIfAborted(config)
    let signatureDictionaries = try await collectPartialMessageSignatures(
        partialSigners,
        message: modifiedMessage,
        config: config
    )
    return SignableMessage(
        content: modifiedMessage.content,
        signatures: mergeSignatures(modifiedMessage.signatures, signatureDictionaries)
    )
}

private func signModifyingAndPartialMessageSigners(
    _ envelope: OffchainMessageEnvelope,
    modifyingSigners: [MessageModifyingSigner],
    partialSigners: [MessagePartialSigner],
    config: MessageModifyingSignerConfig?
) async throws -> OffchainMessageEnvelope {
    let signedMessage = try await signModifyingAndPartialMessageSigners(
        SignableMessage(content: envelope.content, signatures: envelope.signaturesByAddress.compactMapValues { $0 }),
        modifyingSigners: modifyingSigners,
        partialSigners: partialSigners,
        config: config
    )
    var updates = envelope.signaturesByAddress
    for (address, signature) in signedMessage.signatures {
        updates[address] = signature
    }
    return OffchainMessageEnvelope(content: signedMessage.content, signaturesByAddress: updates)
}

private func collectPartialMessageSignatures(
    _ partialSigners: [MessagePartialSigner],
    message: SignableMessage,
    config: MessagePartialSignerConfig?
) async throws -> [SignatureDictionary] {
    try await withThrowingTaskGroup(of: (Int, SignatureDictionary).self) { group in
        for (index, partialSigner) in partialSigners.enumerated() {
            group.addTask {
                try await throwIfAborted(config)
                guard let signatures = try await partialSigner.signMessages([message], config: config).first else {
                    throw SolanaError(.signerExpectedMessagePartialSigner, context: ["address": .string(partialSigner.address.rawValue)])
                }
                return (index, signatures)
            }
        }
        var dictionaries = Array<SignatureDictionary?>(repeating: nil, count: partialSigners.count)
        for try await (index, dictionary) in group {
            dictionaries[index] = dictionary
        }
        return dictionaries.map { $0 ?? SignatureDictionary() }
    }
}

private func categorizeTransactionSigners(
    _ signers: [TransactionSigner],
    identifySendingSigner: Bool = true
) throws(SolanaError) -> (
    modifyingSigners: [TransactionModifyingSigner],
    partialSigners: [TransactionPartialSigner],
    sendingSigner: TransactionSendingSigner?
) {
    let sendingSigner = identifySendingSigner ? identifyTransactionSendingSigner(signers) : nil
    let otherSigners = signers.filter { signer in
        guard signer.identity != sendingSigner?.identity || signer.address != sendingSigner?.address else {
            return false
        }
        return isTransactionModifyingSigner(signer) || isTransactionPartialSigner(signer)
    }
    let modifyingSigners = identifyTransactionModifyingSigners(otherSigners)
    let partialSigners = otherSigners.compactMap(\.partialSigner).filter { partialSigner in
        !modifyingSigners.contains { $0.identity == partialSigner.identity && $0.address == partialSigner.address }
    }
    return (modifyingSigners, partialSigners, sendingSigner)
}

private func identifyTransactionSendingSigner(_ signers: [TransactionSigner]) -> TransactionSendingSigner? {
    let sendingSigners = signers.filter(isTransactionSendingSigner)
    if sendingSigners.isEmpty {
        return nil
    }
    let sendingOnlySigners = sendingSigners.filter {
        !isTransactionModifyingSigner($0) && !isTransactionPartialSigner($0)
    }
    if let sendingOnly = sendingOnlySigners.first?.sendingSigner {
        return sendingOnly
    }
    return sendingSigners.first?.sendingSigner
}

private func identifyTransactionModifyingSigners(_ signers: [TransactionSigner]) -> [TransactionModifyingSigner] {
    let modifyingSigners = signers.compactMap(\.modifyingSigner)
    if modifyingSigners.isEmpty {
        return []
    }
    let nonPartialSigners = signers.filter {
        $0.modifyingSigner != nil && $0.partialSigner == nil
    }.compactMap(\.modifyingSigner)
    if !nonPartialSigners.isEmpty {
        return nonPartialSigners
    }
    return [modifyingSigners[0]]
}

private func signModifyingAndPartialTransactionSigners(
    _ transaction: Transaction,
    modifyingSigners: [TransactionModifyingSigner],
    partialSigners: [TransactionPartialSigner],
    config: TransactionModifyingSignerConfig?
) async throws -> Transaction {
    var modifiedTransaction = transaction
    for modifyingSigner in modifyingSigners {
        try Task.checkCancellation()
        try await throwIfAborted(config)
        guard let signed = try await modifyingSigner.modifyAndSignTransactions([modifiedTransaction], config: config).first else {
            throw SolanaError(.signerExpectedTransactionModifyingSigner, context: ["address": .string(modifyingSigner.address.rawValue)])
        }
        modifiedTransaction = signed
    }
    try Task.checkCancellation()
    try await throwIfAborted(config)
    let signatureDictionaries = try await collectPartialTransactionSignatures(
        partialSigners,
        transaction: modifiedTransaction,
        config: config
    )
    return applySignatures(signatureDictionaries, to: modifiedTransaction)
}

private func collectPartialTransactionSignatures(
    _ partialSigners: [TransactionPartialSigner],
    transaction: Transaction,
    config: TransactionPartialSignerConfig?
) async throws -> [SignatureDictionary] {
    try await withThrowingTaskGroup(of: (Int, SignatureDictionary).self) { group in
        for (index, partialSigner) in partialSigners.enumerated() {
            group.addTask {
                try await throwIfAborted(config)
                guard let signatures = try await partialSigner.signTransactions([transaction], config: config).first else {
                    throw SolanaError(.signerExpectedTransactionPartialSigner, context: ["address": .string(partialSigner.address.rawValue)])
                }
                return (index, signatures)
            }
        }
        var dictionaries = Array<SignatureDictionary?>(repeating: nil, count: partialSigners.count)
        for try await (index, dictionary) in group {
            dictionaries[index] = dictionary
        }
        return dictionaries.map { $0 ?? SignatureDictionary() }
    }
}

private func throwIfAborted(_ config: SignerConfig?) async throws {
    if let reason = config?.abortSignal?.abortReason() {
        throw reason
    }
}

private func applySignatures(_ signatureDictionaries: [SignatureDictionary], to transaction: Transaction) -> Transaction {
    var entries = transaction.signatures.entries
    for dictionary in signatureDictionaries {
        for (address, signature) in dictionary {
            if let index = entries.firstIndex(where: { $0.address == address }) {
                entries[index] = TransactionSignature(address: address, signature: signature)
            } else {
                entries.append(TransactionSignature(address: address, signature: signature))
            }
        }
    }
    return Transaction(
        messageBytes: transaction.messageBytes,
        signatures: SignaturesMap(entries: entries),
        lifetimeConstraint: transaction.lifetimeConstraint
    )
}

private func mergeSignatures(_ base: SignatureDictionary, _ signatureDictionaries: [SignatureDictionary]) -> SignatureDictionary {
    signatureDictionaries.reduce(base) { partialResult, dictionary in
        var next = partialResult
        for (address, signature) in dictionary {
            next[address] = signature
        }
        return next
    }
}
