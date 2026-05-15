import Addresses
import CodecsCore
import CodecsNumbers
import CryptoBackend
import Foundation
import Instructions
import Keys
import SolanaErrors
import TransactionMessages

public typealias TransactionMessageBytes = Data
public typealias TransactionMessageBytesBase64 = String
public typealias Base64EncodedWireTransaction = String

public struct TransactionSignature: Sendable, Equatable, Hashable {
    public let address: Address
    public let signature: SignatureBytes?
    public init(address: Address, signature: SignatureBytes?)
}

public struct SignaturesMap: Sendable, Equatable, Hashable {
    public let entries: [TransactionSignature]
    public init(entries: [TransactionSignature] = [])
    public init(_ pairs: [(Address, SignatureBytes?)])
    public var count: Int { get }
    public var isEmpty: Bool { get }
    public var addresses: [Address] { get }
    public var signatures: [SignatureBytes?] { get }
    public func contains(_ address: Address) -> Bool
    public func signature(for address: Address) -> SignatureBytes?
}

public struct TransactionBlockhashLifetime: Sendable, Equatable, Hashable {
    public let blockhash: Blockhash
    public let lastValidBlockHeight: UInt64
    public init(blockhash: Blockhash, lastValidBlockHeight: UInt64)
}

public struct TransactionDurableNonceLifetime: Sendable, Equatable, Hashable {
    public let nonce: Nonce
    public let nonceAccountAddress: Address
    public init(nonce: Nonce, nonceAccountAddress: Address)
}

public enum TransactionLifetimeConstraint: Sendable, Equatable, Hashable {
    case blockhash(TransactionBlockhashLifetime)
    case nonce(TransactionDurableNonceLifetime)
}

public struct Transaction: Sendable, Equatable, Hashable {
    public let messageBytes: TransactionMessageBytes
    public let signatures: SignaturesMap
    public let lifetimeConstraint: TransactionLifetimeConstraint?
    public init(
        messageBytes: TransactionMessageBytes,
        signatures: SignaturesMap,
        lifetimeConstraint: TransactionLifetimeConstraint? = nil
    )
}

public let transactionPacketSize: Int
public let transactionPacketHeaderSize: Int
public let transactionSizeLimit: Int
public let legacyTransactionSizeLimit: Int
public let v1TransactionSizeLimit: Int

public struct TransactionEncoder: Sendable {
    public init()
    public func getSizeFromValue(_ transaction: Transaction) throws -> Int
    public func encode(_ transaction: Transaction) throws -> Data
    public func write(_ transaction: Transaction, into bytes: inout Data, at offset: Int) throws -> Int
}

public struct TransactionDecoder: Sendable {
    public init()
    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Transaction
    public func read(_ bytes: Data, at offset: Int) throws -> (Transaction, Int)
}

public struct TransactionCodec: Sendable {
    public init()
    public func getSizeFromValue(_ transaction: Transaction) throws -> Int
    public func encode(_ transaction: Transaction) throws -> Data
    public func write(_ transaction: Transaction, into bytes: inout Data, at offset: Int) throws -> Int
    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Transaction
    public func read(_ bytes: Data, at offset: Int) throws -> (Transaction, Int)
}

public func compileTransaction(_ transactionMessage: TransactionMessage) throws -> Transaction
public func getTransactionLifetimeConstraintFromCompiledTransactionMessage(
    _ compiledTransactionMessage: CompiledTransactionMessage
) throws -> TransactionLifetimeConstraint
public func isTransactionWithBlockhashLifetime(_ transaction: Transaction) -> Bool
public func assertIsTransactionWithBlockhashLifetime(_ transaction: Transaction) throws
public func isTransactionWithDurableNonceLifetime(_ transaction: Transaction) -> Bool
public func assertIsTransactionWithDurableNonceLifetime(_ transaction: Transaction) throws

public func getSignatureFromTransaction(_ transaction: Transaction) throws -> Signature
public func partiallySignTransaction(
    _ keyPairs: [KeyPair],
    _ transaction: Transaction,
    using backend: any CryptoBackend
) throws -> Transaction
public func signTransaction(
    _ keyPairs: [KeyPair],
    _ transaction: Transaction,
    using backend: any CryptoBackend
) throws -> Transaction
public func isFullySignedTransaction(_ transaction: Transaction) -> Bool
public func assertIsFullySignedTransaction(_ transaction: Transaction) throws

public func isSendableTransaction(_ transaction: Transaction) throws -> Bool
public func assertIsSendableTransaction(_ transaction: Transaction) throws

public func getTransactionEncoder() -> TransactionEncoder
public func getTransactionDecoder() -> TransactionDecoder
public func getTransactionCodec() -> TransactionCodec
public func getBase64EncodedWireTransaction(_ transaction: Transaction) throws -> Base64EncodedWireTransaction

public func getTransactionSize(_ transaction: Transaction) throws -> Int
public func getTransactionSizeLimit(_ transaction: Transaction) -> Int
public func isTransactionWithinSizeLimit(_ transaction: Transaction) throws -> Bool
public func assertIsTransactionWithinSizeLimit(_ transaction: Transaction) throws

public func getTransactionMessageSize(_ transactionMessage: TransactionMessage) throws -> Int
public func getTransactionMessageSizeLimit(_ transactionMessage: TransactionMessage) -> Int
public func isTransactionMessageWithinSizeLimit(_ transactionMessage: TransactionMessage) throws -> Bool
public func assertIsTransactionMessageWithinSizeLimit(_ transactionMessage: TransactionMessage) throws
