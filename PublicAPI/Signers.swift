import Addresses
import CryptoBackend
import Foundation
import Instructions
import Keys
import OffchainMessages
import Promises
import SolanaErrors
import TransactionMessages
import Transactions

public typealias SignatureDictionary = [Address: SignatureBytes]

public struct SignerIdentity: Sendable, Equatable, Hashable {
    public let rawValue: String
    public init(_ rawValue: String)
    public static func unique() -> SignerIdentity
}

public struct SignerConfig: Sendable, Equatable {
    public let abortSignal: AbortSignal?
    public let minContextSlot: UInt64?
    public init(abortSignal: AbortSignal? = nil, minContextSlot: UInt64? = nil)
    public static func == (lhs: SignerConfig, rhs: SignerConfig) -> Bool
}

public typealias MessagePartialSignerConfig = SignerConfig
public typealias MessageModifyingSignerConfig = SignerConfig
public typealias TransactionPartialSignerConfig = SignerConfig
public typealias TransactionModifyingSignerConfig = SignerConfig
public typealias TransactionSendingSignerConfig = SignerConfig

public struct SignableMessage: Sendable, Equatable {
    public let content: Data
    public let signatures: SignatureDictionary
    public init(content: Data, signatures: SignatureDictionary = [:])
}

public struct MessagePartialSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        signMessages: @escaping @Sendable ([SignableMessage], MessagePartialSignerConfig?) async throws -> [SignatureDictionary]
    )
    public func signMessages(
        _ messages: [SignableMessage],
        config: MessagePartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary]
}

public struct MessageModifyingSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        modifyAndSignMessages: @escaping @Sendable ([SignableMessage], MessageModifyingSignerConfig?) async throws -> [SignableMessage]
    )
    public func modifyAndSignMessages(
        _ messages: [SignableMessage],
        config: MessageModifyingSignerConfig? = nil
    ) async throws -> [SignableMessage]
}

public struct MessageSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public let partialSigner: MessagePartialSigner?
    public let modifyingSigner: MessageModifyingSigner?
    public init(partialSigner: MessagePartialSigner)
    public init(modifyingSigner: MessageModifyingSigner)
    public init(partialSigner: MessagePartialSigner, modifyingSigner: MessageModifyingSigner) throws(SolanaError)
}

public struct TransactionPartialSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        signTransactions: @escaping @Sendable ([Transaction], TransactionPartialSignerConfig?) async throws -> [SignatureDictionary]
    )
    public func signTransactions(
        _ transactions: [Transaction],
        config: TransactionPartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary]
}

public struct TransactionModifyingSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        modifyAndSignTransactions: @escaping @Sendable ([Transaction], TransactionModifyingSignerConfig?) async throws -> [Transaction]
    )
    public func modifyAndSignTransactions(
        _ transactions: [Transaction],
        config: TransactionModifyingSignerConfig? = nil
    ) async throws -> [Transaction]
}

public struct TransactionSendingSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public init(
        address: Address,
        identity: SignerIdentity = .unique(),
        signAndSendTransactions: @escaping @Sendable ([Transaction], TransactionSendingSignerConfig?) async throws -> [SignatureBytes]
    )
    public func signAndSendTransactions(
        _ transactions: [Transaction],
        config: TransactionSendingSignerConfig? = nil
    ) async throws -> [SignatureBytes]
}

public struct TransactionSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public let partialSigner: TransactionPartialSigner?
    public let modifyingSigner: TransactionModifyingSigner?
    public let sendingSigner: TransactionSendingSigner?
    public init(partialSigner: TransactionPartialSigner)
    public init(modifyingSigner: TransactionModifyingSigner)
    public init(sendingSigner: TransactionSendingSigner)
    public init(
        partialSigner: TransactionPartialSigner? = nil,
        modifyingSigner: TransactionModifyingSigner? = nil,
        sendingSigner: TransactionSendingSigner? = nil
    ) throws(SolanaError)
}

public struct KeyPairSigner: Sendable {
    public let address: Address
    public let keyPair: KeyPair
    public let identity: SignerIdentity
    public init(address: Address, keyPair: KeyPair, identity: SignerIdentity, backend: any CryptoBackend)
    public func signMessages(
        _ messages: [SignableMessage],
        config: MessagePartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary]
    public func signTransactions(
        _ transactions: [Transaction],
        config: TransactionPartialSignerConfig? = nil
    ) async throws -> [SignatureDictionary]
    public var messagePartialSigner: MessagePartialSigner { get }
    public var transactionPartialSigner: TransactionPartialSigner { get }
    public var messageSigner: MessageSigner { get }
    public var transactionSigner: TransactionSigner { get }
}

public struct NoopSigner: Sendable {
    public let address: Address
    public let identity: SignerIdentity
    public init(address: Address)
    public init(address: Address, identity: SignerIdentity)
    public var messagePartialSigner: MessagePartialSigner { get }
    public var transactionPartialSigner: TransactionPartialSigner { get }
    public var messageSigner: MessageSigner { get }
    public var transactionSigner: TransactionSigner { get }
}

public struct AccountSignerMeta: Sendable {
    public let address: Address
    public let role: AccountRole
    public let signer: TransactionSigner
    public init(address: Address, role: AccountRole, signer: TransactionSigner) throws(SolanaError)
}

public enum InstructionAccountWithSigner: Sendable {
    case account(AccountMeta)
    case lookup(AccountLookupMeta)
    case signer(AccountSignerMeta)
    public var address: Address { get }
    public var role: AccountRole { get }
    public var signer: TransactionSigner? { get }
    public var instructionAccount: InstructionAccount { get }
}

public struct InstructionWithSigners: Sendable {
    public let programAddress: Address
    public let accounts: [InstructionAccountWithSigner]?
    public let data: Data?
    public init(programAddress: Address, accounts: [InstructionAccountWithSigner]? = nil, data: Data? = nil)
    public init(_ instruction: Instruction)
    public var instruction: Instruction { get }
}

public struct TransactionMessageWithSigners: Sendable {
    public let transactionMessage: TransactionMessage
    public let feePayerSigner: TransactionSigner?
    public let instructions: [InstructionWithSigners]
    public init(
        transactionMessage: TransactionMessage,
        feePayerSigner: TransactionSigner? = nil,
        instructions: [InstructionWithSigners]? = nil
    )
}

public struct OffchainMessageSignatorySigner: Sendable {
    public let address: Address
    public let signer: MessageSigner
    public init(address: Address, signer: MessageSigner) throws(SolanaError)
}

public enum OffchainMessageRequiredSignatory: Sendable {
    case signatory(OffchainMessageSignatory)
    case signer(OffchainMessageSignatorySigner)
    public var address: Address { get }
    public var signer: MessageSigner? { get }
    public var signatory: OffchainMessageSignatory { get }
}

public struct OffchainMessageWithSigners: Sendable {
    public let message: OffchainMessage
    public let requiredSignatories: [OffchainMessageRequiredSignatory]
    public init(message: OffchainMessage, requiredSignatories: [OffchainMessageRequiredSignatory])
}

public func createSignableMessage(_ content: Data, signatures: SignatureDictionary = [:]) -> SignableMessage
public func createSignableMessage(_ text: String, signatures: SignatureDictionary = [:]) -> SignableMessage

public func isMessagePartialSigner(_ signer: MessageSigner) -> Bool
public func assertIsMessagePartialSigner(_ signer: MessageSigner) throws(SolanaError)
public func isMessageModifyingSigner(_ signer: MessageSigner) -> Bool
public func assertIsMessageModifyingSigner(_ signer: MessageSigner) throws(SolanaError)
public func isMessageSigner(_ signer: MessageSigner) -> Bool
public func assertIsMessageSigner(_ signer: MessageSigner) throws(SolanaError)

public func isTransactionPartialSigner(_ signer: TransactionSigner) -> Bool
public func assertIsTransactionPartialSigner(_ signer: TransactionSigner) throws(SolanaError)
public func isTransactionModifyingSigner(_ signer: TransactionSigner) -> Bool
public func assertIsTransactionModifyingSigner(_ signer: TransactionSigner) throws(SolanaError)
public func isTransactionSendingSigner(_ signer: TransactionSigner) -> Bool
public func assertIsTransactionSendingSigner(_ signer: TransactionSigner) throws(SolanaError)
public func isTransactionSigner(_ signer: TransactionSigner) -> Bool
public func assertIsTransactionSigner(_ signer: TransactionSigner) throws(SolanaError)
public func isKeyPairSigner(_ signer: KeyPairSigner) -> Bool
public func assertIsKeyPairSigner(_ signer: KeyPairSigner) throws(SolanaError)

public func createSignerFromKeyPair(
    _ keyPair: KeyPair,
    using backend: any CryptoBackend,
    identity: SignerIdentity = .unique()
) throws -> KeyPairSigner
public func generateKeyPairSigner(using backend: any CryptoBackend, identity: SignerIdentity = .unique()) throws -> KeyPairSigner
public func createKeyPairSignerFromBytes(
    _ bytes: Data,
    using backend: any CryptoBackend,
    identity: SignerIdentity = .unique()
) throws -> KeyPairSigner
public func createKeyPairSignerFromPrivateKeyBytes(
    _ bytes: Data,
    using backend: any CryptoBackend,
    identity: SignerIdentity = .unique()
) throws -> KeyPairSigner
public func createNoopSigner(address: Address) -> NoopSigner
public func createNoopSigner(address: Address, identity: SignerIdentity) -> NoopSigner

public func deduplicateMessageSigners(_ signers: [MessageSigner]) throws(SolanaError) -> [MessageSigner]
public func deduplicateTransactionSigners(_ signers: [TransactionSigner]) throws(SolanaError) -> [TransactionSigner]

public func getSignersFromInstruction(_ instruction: InstructionWithSigners) throws(SolanaError) -> [TransactionSigner]
public func getSignersFromTransactionMessage(_ transactionMessage: TransactionMessageWithSigners) throws(SolanaError) -> [TransactionSigner]
public func addSignersToInstruction(_ signers: [TransactionSigner], _ instruction: Instruction) throws(SolanaError) -> InstructionWithSigners
public func addSignersToInstruction(
    _ signers: [TransactionSigner],
    _ instruction: InstructionWithSigners
) throws(SolanaError) -> InstructionWithSigners
public func addSignersToTransactionMessage(
    _ signers: [TransactionSigner],
    _ transactionMessage: TransactionMessage
) throws(SolanaError) -> TransactionMessageWithSigners
public func addSignersToTransactionMessage(
    _ signers: [TransactionSigner],
    _ transactionMessage: TransactionMessageWithSigners
) throws(SolanaError) -> TransactionMessageWithSigners
public func setTransactionMessageFeePayerSigner(
    _ feePayer: TransactionSigner,
    _ transactionMessage: TransactionMessage
) -> TransactionMessageWithSigners

public func getSignersFromOffchainMessage(_ offchainMessage: OffchainMessageWithSigners) throws(SolanaError) -> [MessageSigner]
public func partiallySignOffchainMessageWithSigners(
    _ offchainMessage: OffchainMessageWithSigners,
    config: MessagePartialSignerConfig? = nil
) async throws -> OffchainMessageEnvelope
public func signOffchainMessageWithSigners(
    _ offchainMessage: OffchainMessageWithSigners,
    config: MessagePartialSignerConfig? = nil
) async throws -> OffchainMessageEnvelope

public func isTransactionMessageWithSingleSendingSigner(_ transactionMessage: TransactionMessageWithSigners) -> Bool
public func assertIsTransactionMessageWithSingleSendingSigner(
    _ transactionMessage: TransactionMessageWithSigners
) throws(SolanaError)
public func assertContainsResolvableTransactionSendingSigner(_ signers: [TransactionSigner]) throws(SolanaError)

public func partiallySignTransactionMessageWithSigners(
    _ transactionMessage: TransactionMessageWithSigners,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction
public func signTransactionMessageWithSigners(
    _ transactionMessage: TransactionMessageWithSigners,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction
public func signAndSendTransactionMessageWithSigners(
    _ transactionMessage: TransactionMessageWithSigners,
    config: TransactionSendingSignerConfig? = nil
) async throws -> SignatureBytes
public func partiallySignTransactionWithSigners(
    _ signers: [TransactionSigner],
    _ transaction: Transaction,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction
public func signTransactionWithSigners(
    _ signers: [TransactionSigner],
    _ transaction: Transaction,
    config: TransactionPartialSignerConfig? = nil
) async throws -> Transaction
public func signAndSendTransactionWithSigners(
    _ signers: [TransactionSigner],
    _ transaction: Transaction,
    config: TransactionSendingSignerConfig? = nil
) async throws -> SignatureBytes
