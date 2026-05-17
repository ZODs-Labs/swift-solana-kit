import Addresses
import CryptoKitBackend
import Foundation
import Instructions
import Keys
import OffchainMessages
import Signers
import SolanaErrors
import TransactionMessages
import Transactions
import XCTest

final class SignersRuntimeBehaviorTests: XCTestCase {
    func testKeyPairSignerSignsEveryMessageAndTransactionWithVerifiableBytes() async throws {
        let backend = CryptoKitBackend()
        let signer = try generateKeyPairSigner(using: backend, identity: SignerIdentity("runtime-keypair"))
        let firstMessage = createSignableMessage(Data([1, 2, 3]))
        let secondMessage = createSignableMessage(Data([4, 5, 6]))
        let transaction = Transaction(
            messageBytes: Data([7, 8, 9]),
            signatures: SignaturesMap([(signer.address, nil)])
        )

        let messageSignatures = try await signer.signMessages([firstMessage, secondMessage])
        let transactionSignatures = try await signer.signTransactions([transaction])

        XCTAssertEqual(messageSignatures.count, 2)
        XCTAssertEqual(transactionSignatures.count, 1)
        let firstSignature = try XCTUnwrap(messageSignatures[0][signer.address])
        let secondSignature = try XCTUnwrap(messageSignatures[1][signer.address])
        let transactionSignature = try XCTUnwrap(transactionSignatures[0][signer.address])
        XCTAssertTrue(try verifySignature(firstSignature, of: firstMessage.content, using: signer.keyPair.publicKey, backend: backend))
        XCTAssertTrue(try verifySignature(secondSignature, of: secondMessage.content, using: signer.keyPair.publicKey, backend: backend))
        XCTAssertTrue(try verifySignature(transactionSignature, of: transaction.messageBytes, using: signer.keyPair.publicKey, backend: backend))
        XCTAssertNotEqual(firstSignature, secondSignature)
    }

    func testOffchainMessageSignersExtractDeduplicateAndRejectConflicts() throws {
        let address = try address("22222222222222222222222222222222222222222222")
        let duplicate = MessageSigner(partialSigner: signersRuntimeMessagePartial(address, identity: "same", fill: 1))
        let conflicting = MessageSigner(partialSigner: signersRuntimeMessagePartial(address, identity: "other", fill: 2))
        let message = try signersRuntimeOffchainMessage(required: [address])
        let withDuplicateSigners = OffchainMessageWithSigners(
            message: message,
            requiredSignatories: [
                .signer(try OffchainMessageSignatorySigner(address: address, signer: duplicate)),
                .signer(try OffchainMessageSignatorySigner(address: address, signer: duplicate)),
                .signatory(OffchainMessageSignatory(address: address)),
            ]
        )
        let withConflictingSigners = OffchainMessageWithSigners(
            message: message,
            requiredSignatories: [
                .signer(try OffchainMessageSignatorySigner(address: address, signer: duplicate)),
                .signer(try OffchainMessageSignatorySigner(address: address, signer: conflicting)),
            ]
        )

        let signers = try getSignersFromOffchainMessage(withDuplicateSigners)

        XCTAssertEqual(signers.count, 1)
        XCTAssertEqual(signers.first?.identity, duplicate.identity)
        signersRuntimeAssertThrowsSolanaCode(.signerAddressCannotHaveMultipleSigners) {
            _ = try getSignersFromOffchainMessage(withConflictingSigners)
        }
    }

    func testTransactionMessageSingleSendingSignerRulesAcceptCompositesAndRejectAmbiguity() throws {
        let firstAddress = try address("22222222222222222222222222222222222222222222")
        let secondAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let program = try address("11111111111111111111111111111111")
        let firstComposite = try TransactionSigner(
            partialSigner: signersRuntimeTransactionPartial(firstAddress, identity: "first", fill: 1),
            sendingSigner: signersRuntimeTransactionSending(firstAddress, identity: "first", fill: 2)
        )
        let secondComposite = try TransactionSigner(
            modifyingSigner: signersRuntimeTransactionModifying(secondAddress, identity: "second", fill: 3),
            sendingSigner: signersRuntimeTransactionSending(secondAddress, identity: "second", fill: 4)
        )
        let firstSendingOnly = TransactionSigner(sendingSigner: signersRuntimeTransactionSending(firstAddress, identity: "first-send", fill: 5))
        let secondSendingOnly = TransactionSigner(sendingSigner: signersRuntimeTransactionSending(secondAddress, identity: "second-send", fill: 6))
        let instruction = try InstructionWithSigners(
            programAddress: program,
            accounts: [.signer(AccountSignerMeta(address: secondAddress, role: .readonlySigner, signer: secondComposite))]
        )
        let message = TransactionMessageWithSigners(
            transactionMessage: setTransactionMessageFeePayer(firstAddress, createTransactionMessage(version: .legacy)),
            feePayerSigner: firstComposite,
            instructions: [instruction]
        )
        let missing = TransactionMessageWithSigners(
            transactionMessage: setTransactionMessageFeePayer(firstAddress, createTransactionMessage(version: .legacy)),
            feePayerSigner: TransactionSigner(partialSigner: signersRuntimeTransactionPartial(firstAddress, identity: "partial", fill: 7))
        )

        XCTAssertTrue(isTransactionMessageWithSingleSendingSigner(message))
        try assertIsTransactionMessageWithSingleSendingSigner(message)
        try assertContainsResolvableTransactionSendingSigner([firstComposite, secondComposite])
        signersRuntimeAssertThrowsSolanaCode(.signerTransactionSendingSignerMissing) {
            try assertIsTransactionMessageWithSingleSendingSigner(missing)
        }
        signersRuntimeAssertThrowsSolanaCode(.signerTransactionCannotHaveMultipleSendingSigners) {
            try assertContainsResolvableTransactionSendingSigner([firstSendingOnly, secondSendingOnly])
        }
    }

    func testTransactionMessageWrappersCompileBeforeSigningAndSending() async throws {
        let address = try address("22222222222222222222222222222222222222222222")
        let partial = TransactionSigner(partialSigner: signersRuntimeTransactionPartial(address, identity: "partial", fill: 9))
        let sending = TransactionSigner(sendingSigner: signersRuntimeTransactionSending(address, identity: "sending", fill: 8))
        let message = TransactionMessageWithSigners(
            transactionMessage: setTransactionMessageFeePayer(address, createTransactionMessage(version: .legacy)),
            feePayerSigner: partial
        )
        let sendingMessage = TransactionMessageWithSigners(
            transactionMessage: setTransactionMessageFeePayer(address, createTransactionMessage(version: .legacy)),
            feePayerSigner: sending
        )

        let partiallySigned = try await partiallySignTransactionMessageWithSigners(message)
        let fullySigned = try await signTransactionMessageWithSigners(message)
        let sentSignature = try await signAndSendTransactionMessageWithSigners(sendingMessage)

        XCTAssertEqual(partiallySigned.signatures.signature(for: address), try signersRuntimeSignature(filledWith: 9))
        XCTAssertEqual(fullySigned.signatures.signature(for: address), try signersRuntimeSignature(filledWith: 9))
        XCTAssertEqual(sentSignature, try signersRuntimeSignature(filledWith: 8))
    }

    func testOffchainMessageWrappersSignPartiallyAndRequireEverySignatureWhenFinalizing() async throws {
        let firstAddress = try address("22222222222222222222222222222222222222222222")
        let secondAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let signer = MessageSigner(partialSigner: signersRuntimeMessagePartial(firstAddress, identity: "first", fill: 6))
        let message = try signersRuntimeOffchainMessage(required: [firstAddress, secondAddress])
        let messageWithSigners = OffchainMessageWithSigners(
            message: message,
            requiredSignatories: [
                .signer(try OffchainMessageSignatorySigner(address: firstAddress, signer: signer)),
                .signatory(OffchainMessageSignatory(address: secondAddress)),
            ]
        )

        let partialEnvelope = try await partiallySignOffchainMessageWithSigners(messageWithSigners)

        XCTAssertEqual(partialEnvelope.signature(for: firstAddress), try signersRuntimeSignature(filledWith: 6))
        XCTAssertNil(partialEnvelope.signature(for: secondAddress))
        do {
            _ = try await signOffchainMessageWithSigners(messageWithSigners)
            XCTFail("Expected missing signature")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.offchainMessageSignaturesMissing.rawValue)
            XCTAssertEqual(error.context["addresses"], .stringArray([secondAddress.rawValue]))
        }
    }
}

private func signersRuntimeMessagePartial(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> MessagePartialSigner {
    MessagePartialSigner(address: address, identity: SignerIdentity(identity)) { messages, _ in
        try messages.map { _ in [address: try signersRuntimeSignature(filledWith: fill)] }
    }
}

private func signersRuntimeTransactionPartial(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> TransactionPartialSigner {
    TransactionPartialSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
        try transactions.map { _ in [address: try signersRuntimeSignature(filledWith: fill)] }
    }
}

private func signersRuntimeTransactionModifying(
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
                        signature: entry.address == address ? try signersRuntimeSignature(filledWith: fill) : entry.signature
                    )
                }),
                lifetimeConstraint: transaction.lifetimeConstraint
            )
        }
    }
}

private func signersRuntimeTransactionSending(
    _ address: Address,
    identity: String,
    fill: UInt8
) -> TransactionSendingSigner {
    TransactionSendingSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
        try Array(repeating: signersRuntimeSignature(filledWith: fill), count: transactions.count)
    }
}

private func signersRuntimeOffchainMessage(required addresses: [Address]) throws -> OffchainMessage {
    try OffchainMessage.v0(
        OffchainMessageV0(
            applicationDomain: "testdomain111111111111111111111111111111111",
            content: offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello world"),
            requiredSignatories: addresses.map(OffchainMessageSignatory.init(address:))
        )
    )
}

private func signersRuntimeSignature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private func signersRuntimeAssertThrowsSolanaCode(
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
