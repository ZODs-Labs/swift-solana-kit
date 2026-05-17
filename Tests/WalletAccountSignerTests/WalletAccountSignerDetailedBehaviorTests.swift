import Addresses
import Foundation
import Keys
import Promises
import Signers
import Transactions
import WalletAccountSigner
import XCTest

final class WalletAccountSignerDetailedBehaviorTests: XCTestCase {
    func testEmptyInputsReturnEmptyResultsWithoutCallingWallet() async throws {
        let wallet = try walletAccountSignerDetailedAddress()
        let recorder = WalletAccountSignerDetailedRecorder()
        let messageAccount = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signMessage],
            signMessage: { inputs in
                await recorder.recordMessageInputs(inputs)
                return []
            }
        )
        let transactionAccount = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signTransaction],
            signTransaction: { inputs in
                await recorder.recordTransactionInputs(inputs)
                return []
            }
        )
        let sendingAccount = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signAndSendTransaction],
            signAndSendTransaction: { inputs in
                await recorder.recordTransactionInputs(inputs)
                return []
            }
        )

        let messageSigner = try createMessageSignerFromWalletAccount(messageAccount)
        let transactionSigner = try createTransactionSignerFromWalletAccount(transactionAccount, chain: "solana:devnet")
        let sendingSigner = try createTransactionSendingSignerFromWalletAccount(sendingAccount, chain: "solana:devnet")

        let messages = try await messageSigner.modifyAndSignMessages([])
        let transactions = try await transactionSigner.modifyAndSignTransactions([])
        let signatures = try await sendingSigner.signAndSendTransactions([])
        let messageInputs = await recorder.messageInputsSnapshot()
        let transactionInputs = await recorder.transactionInputsSnapshot()

        XCTAssertEqual(messages, [])
        XCTAssertEqual(transactions, [])
        XCTAssertEqual(signatures, [])
        XCTAssertEqual(messageInputs, [])
        XCTAssertEqual(transactionInputs, [])
    }

    func testWalletErrorsPropagateFromEverySignerKind() async throws {
        let wallet = try walletAccountSignerDetailedAddress()
        let transaction = try walletAccountSignerDetailedTransaction()
        let messageAccount = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signMessage],
            signMessage: { _ in throw WalletAccountSignerDetailedError(message: "message") }
        )
        let transactionAccount = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signTransaction],
            signTransaction: { _ in throw WalletAccountSignerDetailedError(message: "transaction") }
        )
        let sendingAccount = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signAndSendTransaction],
            signAndSendTransaction: { _ in throw WalletAccountSignerDetailedError(message: "send") }
        )

        do {
            _ = try await createMessageSignerFromWalletAccount(messageAccount)
                .modifyAndSignMessages([SignableMessage(content: Data([1]))])
            XCTFail("Expected message signer error")
        } catch let error as WalletAccountSignerDetailedError {
            XCTAssertEqual(error.message, "message")
        }
        do {
            _ = try await createTransactionSignerFromWalletAccount(transactionAccount, chain: "solana:devnet")
                .modifyAndSignTransactions([transaction])
            XCTFail("Expected transaction signer error")
        } catch let error as WalletAccountSignerDetailedError {
            XCTAssertEqual(error.message, "transaction")
        }
        do {
            _ = try await createTransactionSendingSignerFromWalletAccount(sendingAccount, chain: "solana:devnet")
                .signAndSendTransactions([transaction])
            XCTFail("Expected sending signer error")
        } catch let error as WalletAccountSignerDetailedError {
            XCTAssertEqual(error.message, "send")
        }
    }

    func testSendingSignerForwardsMultipleTransactionsWithConfigAndPreservesOrder() async throws {
        let wallet = try walletAccountSignerDetailedAddress()
        let transaction = try walletAccountSignerDetailedTransaction()
        let recorder = WalletAccountSignerDetailedRecorder()
        let account = WalletAccount(
            address: wallet,
            chains: ["solana:mainnet", "solana:devnet"],
            features: [.signAndSendTransaction],
            signAndSendTransaction: { inputs in
                await recorder.recordTransactionInputs(inputs)
                return [
                    try WalletSentTransactionOutput(signature: walletAccountSignerDetailedSignature(filledWith: 1)),
                    try WalletSentTransactionOutput(signature: walletAccountSignerDetailedSignature(filledWith: 2)),
                ]
            }
        )
        let signer = try createTransactionSendingSignerFromWalletAccount(account, chain: "solana:mainnet")

        let signatures = try await signer.signAndSendTransactions(
            [transaction, transaction],
            config: SignerConfig(minContextSlot: 77)
        )

        let inputs = await recorder.transactionInputsSnapshot()
        XCTAssertEqual(signatures, [
            try walletAccountSignerDetailedSignature(filledWith: 1),
            try walletAccountSignerDetailedSignature(filledWith: 2),
        ])
        XCTAssertEqual(inputs.map(\.chain), ["solana:mainnet", "solana:mainnet"])
        XCTAssertEqual(inputs.map(\.minContextSlot), [77, 77])
        XCTAssertEqual(inputs.map(\.transaction), [
            try getTransactionEncoder().encode(transaction),
            try getTransactionEncoder().encode(transaction),
        ])
    }

    func testCombinedSignerReflectsAvailableTransactionAndMessageFeatures() throws {
        let wallet = try walletAccountSignerDetailedAddress()
        let sendOnly = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signAndSendTransaction],
            signAndSendTransaction: { _ in [] }
        )
        let modifyOnly = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signTransaction],
            signTransaction: { _ in [] }
        )
        let withMessage = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signTransaction, .signMessage],
            signMessage: { _ in [] },
            signTransaction: { _ in [] }
        )

        let sendingSigner = try createSignerFromWalletAccount(sendOnly, chain: "solana:devnet")
        XCTAssertFalse(isTransactionModifyingSigner(sendingSigner.transactionSigner))
        XCTAssertTrue(isTransactionSendingSigner(sendingSigner.transactionSigner))
        XCTAssertNil(sendingSigner.messageSigner)

        let modifyingSigner = try createSignerFromWalletAccount(modifyOnly, chain: "solana:devnet")
        XCTAssertTrue(isTransactionModifyingSigner(modifyingSigner.transactionSigner))
        XCTAssertFalse(isTransactionSendingSigner(modifyingSigner.transactionSigner))
        XCTAssertNil(modifyingSigner.messageSigner)

        let messageSigner = try createSignerFromWalletAccount(withMessage, chain: "solana:devnet")
        XCTAssertNotNil(messageSigner.messageSigner)
    }

    func testUnsupportedChainErrorCarriesAddressChainAndSupportedValues() throws {
        let wallet = try walletAccountSignerDetailedAddress()
        let account = WalletAccount(
            address: wallet,
            chains: ["solana:devnet", "solana:testnet"],
            features: [.signTransaction, .signMessage],
            signMessage: { _ in [] },
            signTransaction: { _ in [] }
        )

        XCTAssertThrowsError(try createTransactionSignerFromWalletAccount(account, chain: "solana:mainnet")) { error in
            guard case let WalletAccountSignerError.chainUnsupported(address, chain, chains, features) = error else {
                return XCTFail("Expected chainUnsupported")
            }
            XCTAssertEqual(address, wallet)
            XCTAssertEqual(chain, "solana:mainnet")
            XCTAssertEqual(chains, ["solana:devnet", "solana:testnet"])
            XCTAssertEqual(features, [.signTransaction, .signMessage])
        }
    }
}

private actor WalletAccountSignerDetailedRecorder {
    private var messageInputs: [WalletSignMessageInput] = []
    private var transactionInputs: [WalletTransactionInput] = []

    func recordMessageInputs(_ inputs: [WalletSignMessageInput]) {
        messageInputs.append(contentsOf: inputs)
    }

    func recordTransactionInputs(_ inputs: [WalletTransactionInput]) {
        transactionInputs.append(contentsOf: inputs)
    }

    func messageInputsSnapshot() -> [WalletSignMessageInput] {
        messageInputs
    }

    func transactionInputsSnapshot() -> [WalletTransactionInput] {
        transactionInputs
    }
}

private struct WalletAccountSignerDetailedError: Error, Sendable, Equatable {
    let message: String
}

private func walletAccountSignerDetailedAddress() throws -> Address {
    try address("22222222222222222222222222222222222222222222")
}

private func walletAccountSignerDetailedTransaction() throws -> Transaction {
    let address = try walletAccountSignerDetailedAddress()
    let lifetime = TransactionBlockhashLifetime(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 42)
    let messageBytes = Data([1, 0, 0, 1])
        + (try getPublicKeyFromAddress(address))
        + Data(repeating: 0, count: 32)
        + Data([0])
    return Transaction(
        messageBytes: messageBytes,
        signatures: SignaturesMap([(address, nil)]),
        lifetimeConstraint: .blockhash(lifetime)
    )
}

private func walletAccountSignerDetailedSignature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}
