public import Addresses
import CodecsCore
public import Foundation
public import Keys
import Promises
public import Signers
import SolanaErrors
import TransactionMessages
import Transactions

public typealias SolanaChain = String

public enum WalletAccountSignerFeature: String, Sendable, Equatable, Hashable, CaseIterable {
    case signMessage = "solana:signMessage"
    case signTransaction = "solana:signTransaction"
    case signAndSendTransaction = "solana:signAndSendTransaction"
}

public enum WalletAccountSignerError: Error, Sendable, Equatable {
    case chainUnsupported(
        address: Address,
        chain: SolanaChain,
        supportedChains: [SolanaChain],
        supportedFeatures: [WalletAccountSignerFeature]
    )
    case featureUnsupported(
        address: Address,
        feature: WalletAccountSignerFeature,
        supportedFeatures: [WalletAccountSignerFeature]
    )
    case outputCountExceeded(inputCount: Int, outputCount: Int)
}

public struct WalletSignMessageInput: Sendable, Equatable {
    public let address: Address
    public let message: Data

    public init(address: Address, message: Data) {
        self.address = address
        self.message = message
    }
}

public struct WalletSignMessageOutput: Sendable, Equatable {
    public let signedMessage: Data
    public let signature: SignatureBytes

    public init(signedMessage: Data, signature: SignatureBytes) {
        self.signedMessage = signedMessage
        self.signature = signature
    }
}

public struct WalletTransactionInput: Sendable, Equatable {
    public let address: Address
    public let chain: SolanaChain
    public let transaction: Data
    public let minContextSlot: UInt64?

    public init(address: Address, chain: SolanaChain, transaction: Data, minContextSlot: UInt64? = nil) {
        self.address = address
        self.chain = chain
        self.transaction = transaction
        self.minContextSlot = minContextSlot
    }
}

public struct WalletSignedTransactionOutput: Sendable, Equatable {
    public let signedTransaction: Data

    public init(signedTransaction: Data) {
        self.signedTransaction = signedTransaction
    }
}

public struct WalletSentTransactionOutput: Sendable, Equatable {
    public let signature: SignatureBytes

    public init(signature: SignatureBytes) {
        self.signature = signature
    }
}

public struct WalletAccount: Sendable {
    public let address: Address
    public let chains: [SolanaChain]
    public let features: [WalletAccountSignerFeature]
    private let signMessageImpl: (@Sendable ([WalletSignMessageInput]) async throws -> [WalletSignMessageOutput])?
    private let signTransactionImpl: (@Sendable ([WalletTransactionInput]) async throws -> [WalletSignedTransactionOutput])?
    private let signAndSendTransactionImpl: (@Sendable ([WalletTransactionInput]) async throws -> [WalletSentTransactionOutput])?

    public init(
        address: Address,
        chains: [SolanaChain],
        features: [WalletAccountSignerFeature],
        signMessage: (@Sendable ([WalletSignMessageInput]) async throws -> [WalletSignMessageOutput])? = nil,
        signTransaction: (@Sendable ([WalletTransactionInput]) async throws -> [WalletSignedTransactionOutput])? = nil,
        signAndSendTransaction: (@Sendable ([WalletTransactionInput]) async throws -> [WalletSentTransactionOutput])? = nil
    ) {
        self.address = address
        self.chains = chains
        self.features = features
        self.signMessageImpl = signMessage
        self.signTransactionImpl = signTransaction
        self.signAndSendTransactionImpl = signAndSendTransaction
    }

    public func signMessage(_ inputs: [WalletSignMessageInput]) async throws -> [WalletSignMessageOutput] {
        guard let signMessageImpl else {
            throw WalletAccountSignerError.featureUnsupported(
                address: address,
                feature: .signMessage,
                supportedFeatures: features
            )
        }
        return try await signMessageImpl(inputs)
    }

    public func signTransaction(_ inputs: [WalletTransactionInput]) async throws -> [WalletSignedTransactionOutput] {
        guard let signTransactionImpl else {
            throw WalletAccountSignerError.featureUnsupported(
                address: address,
                feature: .signTransaction,
                supportedFeatures: features
            )
        }
        return try await signTransactionImpl(inputs)
    }

    public func signAndSendTransaction(_ inputs: [WalletTransactionInput]) async throws -> [WalletSentTransactionOutput] {
        guard let signAndSendTransactionImpl else {
            throw WalletAccountSignerError.featureUnsupported(
                address: address,
                feature: .signAndSendTransaction,
                supportedFeatures: features
            )
        }
        return try await signAndSendTransactionImpl(inputs)
    }
}

public struct WalletAccountSigner: Sendable {
    public let address: Address
    public let messageSigner: MessageSigner?
    public let transactionSigner: TransactionSigner

    public init(address: Address, messageSigner: MessageSigner?, transactionSigner: TransactionSigner) {
        self.address = address
        self.messageSigner = messageSigner
        self.transactionSigner = transactionSigner
    }
}

public func createMessageSignerFromWalletAccount(_ walletAccount: WalletAccount) throws -> MessageModifyingSigner {
    try assertFeature(.signMessage, on: walletAccount)
    return MessageModifyingSigner(address: walletAccount.address, identity: SignerIdentity(walletAccount.address.rawValue)) { messages, config in
        try await throwIfAborted(config)
        try Task.checkCancellation()
        if messages.isEmpty {
            return []
        }

        let inputs = messages.map {
            WalletSignMessageInput(address: walletAccount.address, message: $0.content)
        }
        let outputs = try await getAbortablePromise(
            {
                try await walletAccount.signMessage(inputs)
            },
            abortSignal: config?.abortSignal
        )
        try Task.checkCancellation()

        var results: [SignableMessage] = []
        results.reserveCapacity(outputs.count)
        for (index, output) in outputs.enumerated() {
            guard messages.indices.contains(index) else {
                throw WalletAccountSignerError.outputCountExceeded(
                    inputCount: messages.count,
                    outputCount: outputs.count
                )
            }
            let originalMessage = messages[index]
            let messageWasModified = originalMessage.content != output.signedMessage
            let originalSignature = originalMessage.signatures[walletAccount.address]
            let signatureIsNew = originalSignature == nil || originalSignature != output.signature

            if !signatureIsNew && !messageWasModified {
                results.append(originalMessage)
                continue
            }

            let signatures: SignatureDictionary
            if messageWasModified {
                signatures = [walletAccount.address: output.signature]
            } else {
                var next = originalMessage.signatures
                next[walletAccount.address] = output.signature
                signatures = next
            }
            results.append(SignableMessage(content: output.signedMessage, signatures: signatures))
        }
        return results
    }
}

public func createTransactionSignerFromWalletAccount(
    _ walletAccount: WalletAccount,
    chain: SolanaChain
) throws -> TransactionModifyingSigner {
    try assertChain(chain, on: walletAccount, feature: .signTransaction)
    try assertFeature(.signTransaction, on: walletAccount)
    return TransactionModifyingSigner(address: walletAccount.address, identity: SignerIdentity(walletAccount.address.rawValue)) { transactions, config in
        try await throwIfAborted(config)
        try Task.checkCancellation()
        if transactions.isEmpty {
            return []
        }

        let codec = getTransactionCodec()
        let inputs = try transactions.map { transaction in
            WalletTransactionInput(
                address: walletAccount.address,
                chain: chain,
                transaction: try codec.encode(transaction),
                minContextSlot: config?.minContextSlot
            )
        }
        let outputs = try await getAbortablePromise(
            {
                try await walletAccount.signTransaction(inputs)
            },
            abortSignal: config?.abortSignal
        )
        try Task.checkCancellation()
        try await throwIfAborted(config)

        var results: [Transaction] = []
        results.reserveCapacity(outputs.count)
        for (index, output) in outputs.enumerated() {
            try await throwIfAborted(config)
            let decoded = try codec.decode(output.signedTransaction)
            try assertIsTransactionWithinSizeLimit(decoded)
            let input = transactions.indices.contains(index) ? transactions[index] : nil
            if let input,
               let existingLifetime = input.lifetimeConstraint,
               decoded.messageBytes == input.messageBytes {
                results.append(
                    Transaction(
                        messageBytes: decoded.messageBytes,
                        signatures: decoded.signatures,
                        lifetimeConstraint: existingLifetime
                    )
                )
                continue
            }

            let compiledMessage = try getCompiledTransactionMessageDecoder().decode(decoded.messageBytes)
            if let existingLifetime = input?.lifetimeConstraint,
               compiledMessage.lifetimeToken == existingLifetime.lifetimeToken {
                results.append(
                    Transaction(
                        messageBytes: decoded.messageBytes,
                        signatures: decoded.signatures,
                        lifetimeConstraint: existingLifetime
                    )
                )
                continue
            }

            let lifetimeConstraint = try getTransactionLifetimeConstraintFromCompiledTransactionMessage(compiledMessage)
            results.append(
                Transaction(
                    messageBytes: decoded.messageBytes,
                    signatures: decoded.signatures,
                    lifetimeConstraint: lifetimeConstraint
                )
            )
        }
        return results
    }
}

public func createTransactionSendingSignerFromWalletAccount(
    _ walletAccount: WalletAccount,
    chain: SolanaChain
) throws -> TransactionSendingSigner {
    try assertChain(chain, on: walletAccount, feature: .signAndSendTransaction)
    try assertFeature(.signAndSendTransaction, on: walletAccount)
    return TransactionSendingSigner(address: walletAccount.address, identity: SignerIdentity(walletAccount.address.rawValue)) { transactions, config in
        try await throwIfAborted(config)
        try Task.checkCancellation()
        if transactions.isEmpty {
            return []
        }
        let encoder = getTransactionEncoder()
        let inputs = try transactions.map {
            WalletTransactionInput(
                address: walletAccount.address,
                chain: chain,
                transaction: try encoder.encode($0),
                minContextSlot: config?.minContextSlot
            )
        }
        let outputs = try await getAbortablePromise(
            {
                try await walletAccount.signAndSendTransaction(inputs)
            },
            abortSignal: config?.abortSignal
        )
        try Task.checkCancellation()
        return outputs.map(\.signature)
    }
}

public func createSignerFromWalletAccount(
    _ walletAccount: WalletAccount,
    chain: SolanaChain
) throws -> WalletAccountSigner {
    try assertChain(chain, on: walletAccount, feature: .signTransaction)
    let hasSignTransaction = walletAccount.features.contains(.signTransaction)
    let hasSignAndSendTransaction = walletAccount.features.contains(.signAndSendTransaction)
    let hasSignMessage = walletAccount.features.contains(.signMessage)

    if !hasSignTransaction && !hasSignAndSendTransaction {
        throw SolanaError(
            .signerWalletAccountCannotSignTransaction,
            context: [
                "address": .string(walletAccount.address.rawValue),
                "supportedFeatures": .stringArray(walletAccount.features.map(\.rawValue)),
            ]
        )
    }

    let modifyingSigner = hasSignTransaction
        ? try createTransactionSignerFromWalletAccount(walletAccount, chain: chain)
        : nil
    let sendingSigner = hasSignAndSendTransaction
        ? try createTransactionSendingSignerFromWalletAccount(walletAccount, chain: chain)
        : nil
    let transactionSigner = try TransactionSigner(
        partialSigner: nil,
        modifyingSigner: modifyingSigner,
        sendingSigner: sendingSigner
    )
    let messageSigner = hasSignMessage
        ? MessageSigner(modifyingSigner: try createMessageSignerFromWalletAccount(walletAccount))
        : nil
    return WalletAccountSigner(
        address: walletAccount.address,
        messageSigner: messageSigner,
        transactionSigner: transactionSigner
    )
}

private func assertFeature(_ feature: WalletAccountSignerFeature, on walletAccount: WalletAccount) throws {
    guard walletAccount.features.contains(feature) else {
        throw WalletAccountSignerError.featureUnsupported(
            address: walletAccount.address,
            feature: feature,
            supportedFeatures: walletAccount.features
        )
    }
}

private func assertChain(
    _ chain: SolanaChain,
    on walletAccount: WalletAccount,
    feature: WalletAccountSignerFeature
) throws {
    guard walletAccount.chains.contains(chain) else {
        throw WalletAccountSignerError.chainUnsupported(
            address: walletAccount.address,
            chain: chain,
            supportedChains: walletAccount.chains,
            supportedFeatures: walletAccount.features
        )
    }
}

private extension TransactionLifetimeConstraint {
    var lifetimeToken: String {
        switch self {
        case let .blockhash(blockhash):
            return blockhash.blockhash
        case let .nonce(nonce):
            return nonce.nonce
        }
    }
}

private func throwIfAborted(_ config: SignerConfig?) async throws {
    if let reason = config?.abortSignal?.abortReason() {
        throw reason
    }
}
