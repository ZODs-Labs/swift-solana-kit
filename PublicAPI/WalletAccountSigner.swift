import Addresses
import Foundation
import Keys
import Signers
import SolanaErrors
import Transactions

public typealias SolanaChain = String

public enum WalletAccountSignerFeature: String, Sendable, Equatable, Hashable, CaseIterable {
    case signMessage = "solana:signMessage"
    case signTransaction = "solana:signTransaction"
    case signAndSendTransaction = "solana:signAndSendTransaction"
}

public enum WalletAccountSignerError: Error, Sendable, Equatable {
    case chainUnsupported(address: Address, chain: SolanaChain, supportedChains: [SolanaChain], supportedFeatures: [WalletAccountSignerFeature])
    case featureUnsupported(address: Address, feature: WalletAccountSignerFeature, supportedFeatures: [WalletAccountSignerFeature])
    case outputCountExceeded(inputCount: Int, outputCount: Int)
}

public struct WalletSignMessageInput: Sendable, Equatable {
    public let address: Address
    public let message: Data
    public init(address: Address, message: Data)
}

public struct WalletSignMessageOutput: Sendable, Equatable {
    public let signedMessage: Data
    public let signature: SignatureBytes
    public init(signedMessage: Data, signature: SignatureBytes)
}

public struct WalletTransactionInput: Sendable, Equatable {
    public let address: Address
    public let chain: SolanaChain
    public let transaction: Data
    public let minContextSlot: UInt64?
    public init(address: Address, chain: SolanaChain, transaction: Data, minContextSlot: UInt64? = nil)
}

public struct WalletSignedTransactionOutput: Sendable, Equatable {
    public let signedTransaction: Data
    public init(signedTransaction: Data)
}

public struct WalletSentTransactionOutput: Sendable, Equatable {
    public let signature: SignatureBytes
    public init(signature: SignatureBytes)
}

public struct WalletAccount: Sendable {
    public let address: Address
    public let chains: [SolanaChain]
    public let features: [WalletAccountSignerFeature]
    public init(
        address: Address,
        chains: [SolanaChain],
        features: [WalletAccountSignerFeature],
        signMessage: (@Sendable ([WalletSignMessageInput]) async throws -> [WalletSignMessageOutput])? = nil,
        signTransaction: (@Sendable ([WalletTransactionInput]) async throws -> [WalletSignedTransactionOutput])? = nil,
        signAndSendTransaction: (@Sendable ([WalletTransactionInput]) async throws -> [WalletSentTransactionOutput])? = nil
    )
    public func signMessage(_ inputs: [WalletSignMessageInput]) async throws -> [WalletSignMessageOutput]
    public func signTransaction(_ inputs: [WalletTransactionInput]) async throws -> [WalletSignedTransactionOutput]
    public func signAndSendTransaction(_ inputs: [WalletTransactionInput]) async throws -> [WalletSentTransactionOutput]
}

public struct WalletAccountSigner: Sendable {
    public let address: Address
    public let messageSigner: MessageSigner?
    public let transactionSigner: TransactionSigner
    public init(address: Address, messageSigner: MessageSigner?, transactionSigner: TransactionSigner)
}

public func createMessageSignerFromWalletAccount(_ walletAccount: WalletAccount) throws -> MessageModifyingSigner
public func createTransactionSignerFromWalletAccount(
    _ walletAccount: WalletAccount,
    chain: SolanaChain
) throws -> TransactionModifyingSigner
public func createTransactionSendingSignerFromWalletAccount(
    _ walletAccount: WalletAccount,
    chain: SolanaChain
) throws -> TransactionSendingSigner
public func createSignerFromWalletAccount(
    _ walletAccount: WalletAccount,
    chain: SolanaChain
) throws -> WalletAccountSigner
