import Addresses
import CryptoBackend
import Foundation
import Instructions
import Keys
import OffchainMessages
import Promises
import Signers
import SolanaErrors
import TransactionMessages
import Transactions
import XCTest

final class SignersDetailedBehaviorTests: XCTestCase {
    func testSignableMessagesPreserveBytesUtf8ContentAndSignatures() throws {
        let firstAddress = try address("22222222222222222222222222222222222222222222")
        let secondAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let firstSignature = try signersDetailedSignature(filledWith: 1)
        let secondSignature = try signersDetailedSignature(filledWith: 2)
        let signatures: SignatureDictionary = [
            firstAddress: firstSignature,
            secondAddress: secondSignature,
        ]

        let bytesMessage = createSignableMessage(Data([1, 2, 3]), signatures: signatures)
        let textMessage = createSignableMessage("Hello world!")

        XCTAssertEqual(bytesMessage.content, Data([1, 2, 3]))
        XCTAssertEqual(bytesMessage.signatures[firstAddress], firstSignature)
        XCTAssertEqual(bytesMessage.signatures[secondAddress], secondSignature)
        XCTAssertEqual(textMessage.content, Data("Hello world!".utf8))
        XCTAssertEqual(textMessage.signatures, [:])
    }

    func testNoopSignerReturnsOneEmptySignatureDictionaryPerInput() async throws {
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let noop = createNoopSigner(address: signerAddress)
        let messages = [
            createSignableMessage("hello"),
            createSignableMessage("world"),
        ]
        let transactions = [
            signersDetailedTransaction(requiredSigners: [signerAddress]),
            signersDetailedTransaction(requiredSigners: [signerAddress]),
        ]

        let messageSignatures = try await noop.messagePartialSigner.signMessages(messages)
        let transactionSignatures = try await noop.transactionPartialSigner.signTransactions(transactions)

        XCTAssertEqual(noop.address, signerAddress)
        XCTAssertEqual(messageSignatures, [[:], [:]])
        XCTAssertEqual(transactionSignatures, [[:], [:]])
        XCTAssertEqual(noop.messageSigner.identity, noop.transactionSigner.identity)
    }

    func testCapabilityPredicatesAndAssertionsUseSpecificInterfaces() throws {
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let messagePartial = MessageSigner(partialSigner: signersDetailedMessagePartial(signerAddress, identity: "message-partial", fill: 1))
        let messageModifying = MessageSigner(modifyingSigner: signersDetailedMessageModifying(signerAddress, identity: "message-modifying", fill: 2))
        let transactionPartial = TransactionSigner(partialSigner: signersDetailedTransactionPartial(signerAddress, identity: "transaction-partial", fill: 3))
        let transactionModifying = TransactionSigner(modifyingSigner: signersDetailedTransactionModifying(signerAddress, identity: "transaction-modifying", fill: 4))
        let transactionSending = TransactionSigner(sendingSigner: signersDetailedTransactionSending(signerAddress, identity: "transaction-sending", fill: 5))

        XCTAssertTrue(isMessagePartialSigner(messagePartial))
        XCTAssertFalse(isMessageModifyingSigner(messagePartial))
        XCTAssertTrue(isMessageModifyingSigner(messageModifying))
        XCTAssertTrue(isTransactionPartialSigner(transactionPartial))
        XCTAssertTrue(isTransactionModifyingSigner(transactionModifying))
        XCTAssertTrue(isTransactionSendingSigner(transactionSending))
        XCTAssertTrue(isTransactionSigner(transactionSending))

        try assertIsMessagePartialSigner(messagePartial)
        try assertIsMessageModifyingSigner(messageModifying)
        try assertIsTransactionPartialSigner(transactionPartial)
        try assertIsTransactionModifyingSigner(transactionModifying)
        try assertIsTransactionSendingSigner(transactionSending)

        signersDetailedAssertThrowsSolanaCode(.signerExpectedMessageModifyingSigner) {
            try assertIsMessageModifyingSigner(messagePartial)
        }
        signersDetailedAssertThrowsSolanaCode(.signerExpectedMessagePartialSigner) {
            try assertIsMessagePartialSigner(messageModifying)
        }
        signersDetailedAssertThrowsSolanaCode(.signerExpectedTransactionModifyingSigner) {
            try assertIsTransactionModifyingSigner(transactionPartial)
        }
        signersDetailedAssertThrowsSolanaCode(.signerExpectedTransactionPartialSigner) {
            try assertIsTransactionPartialSigner(transactionSending)
        }
        signersDetailedAssertThrowsSolanaCode(.signerExpectedTransactionSendingSigner) {
            try assertIsTransactionSendingSigner(transactionModifying)
        }
    }

    func testDeduplicateMessageSignersKeepsFirstEquivalentSignerAndRejectsConflicts() throws {
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let otherAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let first = MessageSigner(partialSigner: signersDetailedMessagePartial(signerAddress, identity: "same", fill: 1))
        let duplicate = MessageSigner(partialSigner: signersDetailedMessagePartial(signerAddress, identity: "same", fill: 2))
        let other = MessageSigner(partialSigner: signersDetailedMessagePartial(otherAddress, identity: "other", fill: 3))

        let deduplicated = try deduplicateMessageSigners([first, other, duplicate])

        XCTAssertEqual(deduplicated.count, 2)
        XCTAssertEqual(deduplicated.map(\.address), [signerAddress, otherAddress])
        XCTAssertEqual(deduplicated.first?.identity, first.identity)

        signersDetailedAssertThrowsSolanaCode(.signerAddressCannotHaveMultipleSigners) {
            _ = try deduplicateMessageSigners([
                createNoopSigner(address: signerAddress).messageSigner,
                MessageSigner(partialSigner: signersDetailedMessagePartial(signerAddress, identity: "real", fill: 4)),
            ])
        }
    }

    func testAccountSignerMetaRejectsNonSignerRoles() throws {
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let signer = TransactionSigner(partialSigner: signersDetailedTransactionPartial(signerAddress, identity: "account", fill: 1))

        signersDetailedAssertThrowsSolanaCode(.signerExpectedTransactionSigner) {
            _ = try AccountSignerMeta(address: signerAddress, role: .readonly, signer: signer)
        }
        signersDetailedAssertThrowsSolanaCode(.signerExpectedTransactionSigner) {
            _ = try AccountSignerMeta(address: signerAddress, role: .writable, signer: signer)
        }
    }

    func testAddSignersIgnoresNonSignerAndLookupAccountsAndAddsOneSignerToMultipleMetas() throws {
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let otherAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let lookupTable = try address("Sysvar1111111111111111111111111111111111111")
        let program = try address("11111111111111111111111111111111")
        let signer = TransactionSigner(partialSigner: signersDetailedTransactionPartial(signerAddress, identity: "shared", fill: 1))
        let instruction = Instruction(
            programAddress: program,
            accounts: [
                .account(readonlySignerAccount(signerAddress)),
                .account(writableSignerAccount(signerAddress)),
                .account(readonlyAccount(otherAddress)),
                .lookup(writableLookupAccount(address: otherAddress, addressIndex: 2, lookupTableAddress: lookupTable)),
            ],
            data: Data([1, 2, 3])
        )

        let updated = try addSignersToInstruction([signer], instruction)

        XCTAssertEqual(updated.accounts?.compactMap(\.signer).map(\.identity), [signer.identity, signer.identity])
        XCTAssertEqual(updated.instruction.accounts, instruction.accounts)
        XCTAssertEqual(try getSignersFromInstruction(updated).map(\.identity), [signer.identity])
    }

    func testSetFeePayerSignerUpdatesMessageAndReturnedSigner() throws {
        let firstAddress = try address("22222222222222222222222222222222222222222222")
        let secondAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let firstSigner = TransactionSigner(partialSigner: signersDetailedTransactionPartial(firstAddress, identity: "first", fill: 1))
        let secondSigner = TransactionSigner(partialSigner: signersDetailedTransactionPartial(secondAddress, identity: "second", fill: 2))
        let baseMessage = createTransactionMessage(version: .legacy)
        let firstMessage = setTransactionMessageFeePayerSigner(firstSigner, baseMessage)
        let plainFeePayerMessage = setTransactionMessageFeePayer(firstAddress, baseMessage)

        let replaced = setTransactionMessageFeePayerSigner(secondSigner, firstMessage.transactionMessage)
        let replacedPlain = setTransactionMessageFeePayerSigner(secondSigner, plainFeePayerMessage)

        XCTAssertEqual(firstMessage.feePayerSigner?.identity, firstSigner.identity)
        XCTAssertEqual(firstMessage.transactionMessage.feePayer?.address, firstAddress)
        XCTAssertEqual(replaced.feePayerSigner?.identity, secondSigner.identity)
        XCTAssertEqual(replaced.transactionMessage.feePayer?.address, secondAddress)
        XCTAssertEqual(replacedPlain.feePayerSigner?.identity, secondSigner.identity)
        XCTAssertEqual(replacedPlain.transactionMessage.feePayer?.address, secondAddress)
    }

    func testSignTransactionWithSignersRequiresEveryRequiredSignature() async throws {
        let firstAddress = try address("22222222222222222222222222222222222222222222")
        let secondAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let signer = TransactionSigner(partialSigner: signersDetailedTransactionPartial(firstAddress, identity: "first", fill: 1))
        let transaction = signersDetailedTransaction(requiredSigners: [firstAddress, secondAddress])

        do {
            _ = try await signTransactionWithSigners([signer], transaction)
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionSignaturesMissing.rawValue)
            XCTAssertEqual(error.context["addresses"], .stringArray([secondAddress.rawValue]))
        }
    }
}

private func signersDetailedMessagePartial(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> MessagePartialSigner {
    MessagePartialSigner(address: address, identity: SignerIdentity(identity)) { messages, _ in
        try messages.map { _ in [address: try signersDetailedSignature(filledWith: fill)] }
    }
}

private func signersDetailedMessageModifying(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> MessageModifyingSigner {
    MessageModifyingSigner(address: address, identity: SignerIdentity(identity)) { messages, _ in
        try messages.map { message in
            var signatures = message.signatures
            signatures[address] = try signersDetailedSignature(filledWith: fill)
            return SignableMessage(content: message.content, signatures: signatures)
        }
    }
}

private func signersDetailedTransactionPartial(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> TransactionPartialSigner {
    TransactionPartialSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
        try transactions.map { _ in [address: try signersDetailedSignature(filledWith: fill)] }
    }
}

private func signersDetailedTransactionModifying(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> TransactionModifyingSigner {
    TransactionModifyingSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
        try transactions.map { transaction in
            Transaction(
                messageBytes: transaction.messageBytes,
                signatures: SignaturesMap(entries: try transaction.signatures.entries.map { entry in
                    TransactionSignature(
                        address: entry.address,
                        signature: entry.address == address ? try signersDetailedSignature(filledWith: fill) : entry.signature
                    )
                }),
                lifetimeConstraint: transaction.lifetimeConstraint
            )
        }
    }
}

private func signersDetailedTransactionSending(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> TransactionSendingSigner {
    TransactionSendingSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
        try Array(repeating: signersDetailedSignature(filledWith: fill), count: transactions.count)
    }
}

private func signersDetailedTransaction(requiredSigners: [Address]) -> Transaction {
    Transaction(
        messageBytes: Data([1, 2, 3]),
        signatures: SignaturesMap(requiredSigners.map { ($0, nil) })
    )
}

private func signersDetailedSignature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private func signersDetailedAssertThrowsSolanaCode(
    _ code: SolanaErrorCode,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () throws -> Void
) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
        guard let coded = error as? any SolanaErrorCoded else {
            return XCTFail("Expected SolanaErrorCoded, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(coded.code, code.rawValue, file: file, line: line)
    }
}
