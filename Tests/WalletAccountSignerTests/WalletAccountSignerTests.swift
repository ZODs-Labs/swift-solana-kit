import Addresses
import Foundation
import Keys
import Promises
import Signers
import SolanaErrors
import Transactions
import WalletAccountSigner
import XCTest

final class WalletAccountSignerTests: XCTestCase {
    func testMessageSignerPreservesSignaturesWhenContentIsUnchanged() async throws {
        let wallet = try walletAddress()
        let otherAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let recorder = WalletRecorder()
        let account = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signMessage],
            signMessage: { inputs in
                await recorder.recordMessageInputs(inputs)
                return try inputs.map {
                    WalletSignMessageOutput(signedMessage: $0.message, signature: try testSignature(filledWith: 9))
                }
            }
        )
        let signer = try createMessageSignerFromWalletAccount(account)
        let message = SignableMessage(
            content: Data([1, 2, 3]),
            signatures: [otherAddress: try testSignature(filledWith: 2)]
        )

        let results = try await signer.modifyAndSignMessages([message])

        let messageInputs = await recorder.messageInputsSnapshot()
        XCTAssertEqual(messageInputs.count, 1)
        XCTAssertEqual(results[0].content, Data([1, 2, 3]))
        XCTAssertEqual(results[0].signatures[otherAddress], try testSignature(filledWith: 2))
        XCTAssertEqual(results[0].signatures[wallet], try testSignature(filledWith: 9))
    }

    func testMessageSignerClearsExistingSignaturesWhenContentChanges() async throws {
        let wallet = try walletAddress()
        let otherAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let account = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signMessage],
            signMessage: { _ in
                [try WalletSignMessageOutput(signedMessage: Data([9, 9, 9]), signature: testSignature(filledWith: 7))]
            }
        )
        let signer = try createMessageSignerFromWalletAccount(account)
        let message = SignableMessage(
            content: Data([1, 2, 3]),
            signatures: [otherAddress: try testSignature(filledWith: 2)]
        )

        let results = try await signer.modifyAndSignMessages([message])

        XCTAssertEqual(results[0].content, Data([9, 9, 9]))
        XCTAssertNil(results[0].signatures[otherAddress])
        XCTAssertEqual(results[0].signatures[wallet], try testSignature(filledWith: 7))
    }

    func testMessageSignerThrowsInsteadOfTrappingWhenWalletReturnsExtraOutput() async throws {
        let wallet = try walletAddress()
        let account = WalletAccount(
            address: wallet,
            chains: ["solana:devnet"],
            features: [.signMessage],
            signMessage: { inputs in
                try inputs.map {
                    WalletSignMessageOutput(signedMessage: $0.message, signature: try testSignature(filledWith: 1))
                } + [
                    WalletSignMessageOutput(signedMessage: Data([9]), signature: try testSignature(filledWith: 2)),
                ]
            }
        )
        let signer = try createMessageSignerFromWalletAccount(account)

        do {
            _ = try await signer.modifyAndSignMessages([SignableMessage(content: Data([1, 2, 3]))])
            XCTFail("Expected outputCountExceeded")
        } catch WalletAccountSignerError.outputCountExceeded(let inputCount, let outputCount) {
            XCTAssertEqual(inputCount, 1)
            XCTAssertEqual(outputCount, 2)
        }
    }

    func testTransactionSignerForwardsEncodedTransactionsAndPreservesLifetimeForIdenticalBytes() async throws {
        let address = try walletAddress()
        let transaction = try sampleTransaction()
        let signedTransaction = Transaction(
            messageBytes: transaction.messageBytes,
            signatures: SignaturesMap(entries: try transaction.signatures.entries.map {
                TransactionSignature(address: $0.address, signature: try testSignature(filledWith: 5))
            }),
            lifetimeConstraint: transaction.lifetimeConstraint
        )
        let encodedSignedTransaction = try getTransactionEncoder().encode(signedTransaction)
        let recorder = WalletRecorder()
        let account = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signTransaction],
            signTransaction: { inputs in
                await recorder.recordTransactionInputs(inputs)
                return [WalletSignedTransactionOutput(signedTransaction: encodedSignedTransaction)]
            }
        )
        let signer = try createTransactionSignerFromWalletAccount(account, chain: "solana:devnet")

        let results = try await signer.modifyAndSignTransactions([transaction], config: SignerConfig(minContextSlot: 123))

        let inputs = await recorder.transactionInputs
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(inputs[0].chain, "solana:devnet")
        XCTAssertEqual(inputs[0].minContextSlot, 123)
        XCTAssertEqual(inputs[0].transaction, try getTransactionEncoder().encode(transaction))
        XCTAssertEqual(results[0].lifetimeConstraint, transaction.lifetimeConstraint)
        XCTAssertEqual(results[0].signatures.signature(for: address), try testSignature(filledWith: 5))
    }

    func testTransactionSignerCanDecodeExtraWalletOutputWithoutInputLifetime() async throws {
        let address = try walletAddress()
        let transaction = try sampleTransaction()
        let signedTransaction = Transaction(
            messageBytes: transaction.messageBytes,
            signatures: SignaturesMap(entries: try transaction.signatures.entries.map {
                TransactionSignature(address: $0.address, signature: try testSignature(filledWith: 5))
            }),
            lifetimeConstraint: transaction.lifetimeConstraint
        )
        let encodedSignedTransaction = try getTransactionEncoder().encode(signedTransaction)
        let account = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signTransaction],
            signTransaction: { _ in
                [
                    WalletSignedTransactionOutput(signedTransaction: encodedSignedTransaction),
                    WalletSignedTransactionOutput(signedTransaction: encodedSignedTransaction),
                ]
            }
        )
        let signer = try createTransactionSignerFromWalletAccount(account, chain: "solana:devnet")

        let results = try await signer.modifyAndSignTransactions([transaction])

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].lifetimeConstraint, transaction.lifetimeConstraint)
        XCTAssertEqual(results[1].messageBytes, transaction.messageBytes)
        XCTAssertEqual(results[1].lifetimeConstraint?.lifetimeToken, transaction.lifetimeConstraint?.lifetimeToken)
    }

    func testTransactionSendingSignerReturnsWalletSignatures() async throws {
        let address = try walletAddress()
        let transaction = try sampleTransaction()
        let recorder = WalletRecorder()
        let account = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signAndSendTransaction],
            signAndSendTransaction: { inputs in
                await recorder.recordTransactionInputs(inputs)
                return [try WalletSentTransactionOutput(signature: testSignature(filledWith: 6))]
            }
        )
        let signer = try createTransactionSendingSignerFromWalletAccount(account, chain: "solana:devnet")

        let signatures = try await signer.signAndSendTransactions([transaction], config: SignerConfig(minContextSlot: 456))

        let transactionInputs = await recorder.transactionInputsSnapshot()
        XCTAssertEqual(transactionInputs.first?.minContextSlot, 456)
        XCTAssertEqual(signatures, [try testSignature(filledWith: 6)])
    }

    func testMessageSignerRacesWalletCallAgainstAbortSignal() async throws {
        let signal = AbortSignal()
        let account = try WalletAccount(
            address: walletAddress(),
            chains: ["solana:devnet"],
            features: [.signMessage],
            signMessage: { inputs in
                try await Task.sleep(nanoseconds: 200_000_000)
                return try inputs.map {
                    WalletSignMessageOutput(signedMessage: $0.message, signature: try testSignature(filledWith: 8))
                }
            }
        )
        let signer = try createMessageSignerFromWalletAccount(account)
        let task = Task {
            try await signer.modifyAndSignMessages(
                [SignableMessage(content: Data([1, 2, 3]))],
                config: SignerConfig(abortSignal: signal)
            )
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        signal.abort(reason: AbortError(reason: "stop"))

        do {
            _ = try await task.value
            XCTFail("Expected abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
    }

    func testTransactionSignerRacesWalletCallAgainstAbortSignal() async throws {
        let signal = AbortSignal()
        let account = try WalletAccount(
            address: walletAddress(),
            chains: ["solana:devnet"],
            features: [.signTransaction],
            signTransaction: { _ in
                try await Task.sleep(nanoseconds: 200_000_000)
                return []
            }
        )
        let signer = try createTransactionSignerFromWalletAccount(account, chain: "solana:devnet")
        let transaction = try sampleTransaction()
        let task = Task {
            try await signer.modifyAndSignTransactions(
                [transaction],
                config: SignerConfig(abortSignal: signal)
            )
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        signal.abort(reason: AbortError(reason: "stop"))

        do {
            _ = try await task.value
            XCTFail("Expected abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
    }

    func testTransactionSendingSignerRacesWalletCallAgainstAbortSignal() async throws {
        let signal = AbortSignal()
        let account = try WalletAccount(
            address: walletAddress(),
            chains: ["solana:devnet"],
            features: [.signAndSendTransaction],
            signAndSendTransaction: { _ in
                try await Task.sleep(nanoseconds: 200_000_000)
                return []
            }
        )
        let signer = try createTransactionSendingSignerFromWalletAccount(account, chain: "solana:devnet")
        let transaction = try sampleTransaction()
        let task = Task {
            try await signer.signAndSendTransactions(
                [transaction],
                config: SignerConfig(abortSignal: signal)
            )
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        signal.abort(reason: AbortError(reason: "stop"))

        do {
            _ = try await task.value
            XCTFail("Expected abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
    }

    func testWalletAccountSignersCheckAbortBeforeEmptyInputFastPath() async throws {
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let address = try walletAddress()
        let messageAccount = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signMessage],
            signMessage: { _ in [] }
        )
        let transactionAccount = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signTransaction],
            signTransaction: { _ in [] }
        )
        let sendingAccount = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signAndSendTransaction],
            signAndSendTransaction: { _ in [] }
        )

        let messageSigner = try createMessageSignerFromWalletAccount(messageAccount)
        let transactionSigner = try createTransactionSignerFromWalletAccount(transactionAccount, chain: "solana:devnet")
        let sendingSigner = try createTransactionSendingSignerFromWalletAccount(sendingAccount, chain: "solana:devnet")

        do {
            _ = try await messageSigner.modifyAndSignMessages([], config: SignerConfig(abortSignal: signal))
            XCTFail("Expected message abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
        do {
            _ = try await transactionSigner.modifyAndSignTransactions([], config: SignerConfig(abortSignal: signal))
            XCTFail("Expected transaction abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
        do {
            _ = try await sendingSigner.signAndSendTransactions([], config: SignerConfig(abortSignal: signal))
            XCTFail("Expected sending abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
    }

    func testCombinedSignerIncludesAvailableFeaturesAndRejectsMissingTransactionCapability() throws {
        let address = try walletAddress()
        let account = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signTransaction, .signAndSendTransaction, .signMessage],
            signMessage: { _ in [] },
            signTransaction: { _ in [] },
            signAndSendTransaction: { _ in [] }
        )

        let signer = try createSignerFromWalletAccount(account, chain: "solana:devnet")

        XCTAssertEqual(signer.address, address)
        XCTAssertNotNil(signer.messageSigner)
        XCTAssertTrue(isTransactionModifyingSigner(signer.transactionSigner))
        XCTAssertTrue(isTransactionSendingSigner(signer.transactionSigner))

        let messageOnly = WalletAccount(address: address, chains: ["solana:devnet"], features: [.signMessage], signMessage: { _ in [] })
        XCTAssertEqual(
            throwingSolanaCode { _ = try createSignerFromWalletAccount(messageOnly, chain: "solana:devnet") },
            SolanaErrorCode.signerWalletAccountCannotSignTransaction.rawValue
        )
    }

    func testUnsupportedChainAndFeatureErrors() throws {
        let address = try walletAddress()
        let account = WalletAccount(
            address: address,
            chains: ["solana:devnet"],
            features: [.signTransaction, .signMessage],
            signMessage: { _ in [] },
            signTransaction: { _ in [] }
        )

        XCTAssertThrowsError(try createTransactionSignerFromWalletAccount(account, chain: "solana:mainnet")) { error in
            guard case let WalletAccountSignerError.chainUnsupported(_, _, _, supportedFeatures) = error else {
                return XCTFail("Expected chainUnsupported, got \(error)")
            }
            XCTAssertEqual(supportedFeatures, [.signTransaction, .signMessage])
        }

        let transactionOnly = WalletAccount(address: address, chains: ["solana:devnet"], features: [.signTransaction], signTransaction: { _ in [] })
        XCTAssertThrowsError(try createMessageSignerFromWalletAccount(transactionOnly)) { error in
            guard case WalletAccountSignerError.featureUnsupported = error else {
                return XCTFail("Expected featureUnsupported, got \(error)")
            }
        }
    }

    private func sampleTransaction() throws -> Transaction {
        let address = try walletAddress()
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

    private func walletAddress() throws -> Address {
        try address("22222222222222222222222222222222222222222222")
    }
}

private actor WalletRecorder {
    private(set) var messageInputs: [WalletSignMessageInput] = []
    private(set) var transactionInputs: [WalletTransactionInput] = []

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

private func testSignature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private func throwingSolanaCode(_ body: () throws -> Void) -> Int {
    do {
        try body()
        XCTFail("Expected SolanaErrorCoded")
        return Int.min
    } catch let error as any SolanaErrorCoded {
        return error.code
    } catch {
        XCTFail("Expected SolanaErrorCoded, got \(error)")
        return Int.min
    }
}

private extension TransactionLifetimeConstraint {
    var lifetimeToken: String {
        switch self {
        case let .blockhash(blockhash):
            blockhash.blockhash
        case let .nonce(nonce):
            nonce.nonce
        }
    }
}
