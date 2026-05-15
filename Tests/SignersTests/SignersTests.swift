import Addresses
import CryptoBackend
import CryptoKitBackend
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

final class SignersTests: XCTestCase {
    func testKeyPairSignerSignsMessagesAndTransactions() async throws {
        let backend = CryptoKitBackend()
        let signer = try generateKeyPairSigner(using: backend, identity: SignerIdentity("keypair"))
        let message = createSignableMessage("Hello world")

        let messageSignatures = try await signer.signMessages([message])
        XCTAssertEqual(messageSignatures.count, 1)
        XCTAssertNotNil(messageSignatures[0][signer.address])

        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signer.address, nil)])
        )
        let transactionSignatures = try await signer.signTransactions([transaction])
        XCTAssertEqual(transactionSignatures.count, 1)
        XCTAssertNotNil(transactionSignatures[0][signer.address])
    }

    func testKeyPairSignerDoesNotPreemptDirectCallsWithAbortConfig() async throws {
        let backend = CryptoKitBackend()
        let signer = try generateKeyPairSigner(using: backend, identity: SignerIdentity("keypair-abort"))
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signer.address, nil)])
        )

        let messageSignatures = try await signer.signMessages(
            [createSignableMessage("Hello world")],
            config: SignerConfig(abortSignal: signal)
        )
        let transactionSignatures = try await signer.signTransactions(
            [transaction],
            config: SignerConfig(abortSignal: signal)
        )

        XCTAssertNotNil(messageSignatures[0][signer.address])
        XCTAssertNotNil(transactionSignatures[0][signer.address])
    }

    func testDeduplicateRejectsDistinctSignersForOneAddress() throws {
        let address = try address("22222222222222222222222222222222222222222222")
        let signerA = TransactionSigner(partialSigner: transactionPartial(address, identity: "a", fill: 1))
        let signerB = TransactionSigner(partialSigner: transactionPartial(address, identity: "b", fill: 2))

        assertThrowsSolanaCode(.signerAddressCannotHaveMultipleSigners) {
            _ = try deduplicateTransactionSigners([signerA, signerB])
        }
    }

    func testDeduplicateKeepsEquivalentNoopSignersForOneAddress() throws {
        let address = try address("22222222222222222222222222222222222222222222")
        let first = createNoopSigner(address: address).transactionSigner
        let second = createNoopSigner(address: address).transactionSigner

        let deduplicated = try deduplicateTransactionSigners([first, second])

        XCTAssertEqual(deduplicated.count, 1)
        XCTAssertEqual(deduplicated.first?.identity, first.identity)
        XCTAssertEqual(second.identity, first.identity)
    }

    func testCompositeSignersRejectMixedIdentitiesForOneAddress() throws {
        let signerAddress = try address("22222222222222222222222222222222222222222222")

        assertThrowsSolanaCode(.signerAddressCannotHaveMultipleSigners) {
            _ = try MessageSigner(
                partialSigner: messagePartial(signerAddress, identity: "partial", fill: 1),
                modifyingSigner: messageModifying(signerAddress, identity: "modifying", fill: 2)
            )
        }

        assertThrowsSolanaCode(.signerAddressCannotHaveMultipleSigners) {
            _ = try TransactionSigner(
                partialSigner: transactionPartial(signerAddress, identity: "partial", fill: 1),
                modifyingSigner: transactionModifying(signerAddress, identity: "modifying", fill: 2),
                sendingSigner: transactionSending(signerAddress, identity: "sending", fill: 3)
            )
        }
    }

    func testAccountSignerMetaRejectsAddressMismatch() throws {
        let accountAddress = try address("22222222222222222222222222222222222222222222")
        let signerAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let signer = TransactionSigner(partialSigner: transactionPartial(signerAddress, identity: "mismatch", fill: 1))

        assertThrowsSolanaCode(.signerAddressCannotHaveMultipleSigners) {
            _ = try AccountSignerMeta(address: accountAddress, role: .readonlySigner, signer: signer)
        }
    }

    func testAddSignersToInstructionAndTransactionMessageExtractsSigners() throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let signerAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let program = try address("11111111111111111111111111111111")
        let feePayerSigner = TransactionSigner(partialSigner: transactionPartial(feePayer, identity: "fee", fill: 1))
        let accountSigner = TransactionSigner(partialSigner: transactionPartial(signerAddress, identity: "account", fill: 2))
        let instruction = Instruction(
            programAddress: program,
            accounts: [.account(readonlySignerAccount(signerAddress))],
            data: Data([1, 2, 3])
        )
        let message = appendTransactionMessageInstruction(
            instruction,
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
        )

        let instructionWithSigners = try addSignersToInstruction([accountSigner], instruction)
        XCTAssertEqual(try getSignersFromInstruction(instructionWithSigners).map(\.address), [signerAddress])

        let messageWithSigners = try addSignersToTransactionMessage([feePayerSigner, accountSigner], message)
        XCTAssertEqual(try getSignersFromTransactionMessage(messageWithSigners).map(\.address), [feePayer, signerAddress])
        XCTAssertEqual(messageWithSigners.transactionMessage.feePayer?.address, feePayer)
        XCTAssertEqual(messageWithSigners.instructions.map(\.instruction), message.instructions)
    }

    func testAddSignersPreservesExistingAttachedSigners() throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let signerAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let program = try address("11111111111111111111111111111111")
        let existingFeePayer = TransactionSigner(partialSigner: transactionPartial(feePayer, identity: "fee-existing", fill: 1))
        let replacementFeePayer = TransactionSigner(partialSigner: transactionPartial(feePayer, identity: "fee-replacement", fill: 2))
        let existingAccountSigner = TransactionSigner(partialSigner: transactionPartial(signerAddress, identity: "account-existing", fill: 3))
        let replacementAccountSigner = TransactionSigner(partialSigner: transactionPartial(signerAddress, identity: "account-replacement", fill: 4))
        let signedInstruction = try InstructionWithSigners(
            programAddress: program,
            accounts: [.signer(AccountSignerMeta(address: signerAddress, role: .readonlySigner, signer: existingAccountSigner))],
            data: Data([1, 2, 3])
        )
        let message = appendTransactionMessageInstruction(
            signedInstruction.instruction,
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
        )
        let signedMessage = TransactionMessageWithSigners(
            transactionMessage: message,
            feePayerSigner: existingFeePayer,
            instructions: [signedInstruction]
        )

        let updatedInstruction = try addSignersToInstruction([replacementAccountSigner], signedInstruction)
        let updatedMessage = try addSignersToTransactionMessage([replacementFeePayer, replacementAccountSigner], signedMessage)

        XCTAssertEqual(try getSignersFromInstruction(updatedInstruction).first?.identity, existingAccountSigner.identity)
        XCTAssertEqual(updatedMessage.feePayerSigner?.identity, existingFeePayer.identity)
        XCTAssertEqual(try getSignersFromTransactionMessage(updatedMessage).map(\.identity), [existingFeePayer.identity, existingAccountSigner.identity])
    }

    func testTransactionCompositeSignerRoutesByCapability() async throws {
        let signerAAddress = try address("22222222222222222222222222222222222222222222")
        let signerBAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let composite = try TransactionSigner(
            partialSigner: transactionPartial(signerAAddress, identity: "a", fill: 1),
            modifyingSigner: transactionModifying(signerAAddress, identity: "a", fill: 9)
        )
        let partial = TransactionSigner(partialSigner: transactionPartial(signerBAddress, identity: "b", fill: 2))
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAAddress, nil), (signerBAddress, nil)])
        )

        let signedWithCompositeModifying = try await partiallySignTransactionWithSigners([composite, partial], transaction)
        XCTAssertEqual(signedWithCompositeModifying.signatures.signature(for: signerAAddress), try signature(filledWith: 9))
        XCTAssertEqual(signedWithCompositeModifying.signatures.signature(for: signerBAddress), try signature(filledWith: 2))

        let externalModifier = TransactionSigner(modifyingSigner: transactionModifying(signerBAddress, identity: "b-mod", fill: 8))
        let signedWithCompositePartial = try await partiallySignTransactionWithSigners([composite, externalModifier], transaction)
        XCTAssertEqual(signedWithCompositePartial.signatures.signature(for: signerAAddress), try signature(filledWith: 1))
        XCTAssertEqual(signedWithCompositePartial.signatures.signature(for: signerBAddress), try signature(filledWith: 8))
    }

    func testPartialTransactionSignerMergesPreserveInputOrder() async throws {
        let targetAddress = try address("22222222222222222222222222222222222222222222")
        let otherAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let slowFirst = TransactionSigner(partialSigner: transactionPartial(targetAddress, identity: "slow-first", fill: 1, delayNanoseconds: 20_000_000, signingAddress: targetAddress))
        let fastSecond = TransactionSigner(partialSigner: transactionPartial(otherAddress, identity: "fast-second", fill: 2, signingAddress: targetAddress))
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(targetAddress, nil)])
        )

        let signed = try await partiallySignTransactionWithSigners([slowFirst, fastSecond], transaction)

        XCTAssertEqual(signed.signatures.signature(for: targetAddress), try signature(filledWith: 2))
    }

    func testPartialTransactionSignerAppendsNewSignatureAddresses() async throws {
        let targetAddress = try address("22222222222222222222222222222222222222222222")
        let extraAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let signer = TransactionSigner(partialSigner: transactionPartial(extraAddress, identity: "extra", fill: 7))
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(targetAddress, nil)])
        )

        let signed = try await partiallySignTransactionWithSigners([signer], transaction)

        XCTAssertEqual(signed.signatures.entries.map(\.address), [targetAddress, extraAddress])
        XCTAssertNil(signed.signatures.signature(for: targetAddress))
        XCTAssertEqual(signed.signatures.signature(for: extraAddress), try signature(filledWith: 7))
    }

    func testTransactionSendingSignerResolutionAndSendFlow() async throws {
        let signerAAddress = try address("22222222222222222222222222222222222222222222")
        let signerBAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let composite = try TransactionSigner(
            partialSigner: transactionPartial(signerAAddress, identity: "a", fill: 1),
            modifyingSigner: transactionModifying(signerAAddress, identity: "a", fill: 8),
            sendingSigner: transactionSending(signerAAddress, identity: "a", fill: 3)
        )
        let sender = TransactionSigner(sendingSigner: transactionSending(signerBAddress, identity: "b", fill: 4))
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAAddress, nil), (signerBAddress, nil)])
        )

        let signature = try await signAndSendTransactionWithSigners([composite, sender], transaction)
        XCTAssertEqual(signature, try self.signature(filledWith: 4))

        assertThrowsSolanaCode(.signerTransactionSendingSignerMissing) {
            try assertContainsResolvableTransactionSendingSigner([TransactionSigner(partialSigner: transactionPartial(signerAAddress, identity: "partial", fill: 1))])
        }
        assertThrowsSolanaCode(.signerTransactionCannotHaveMultipleSendingSigners) {
            try assertContainsResolvableTransactionSendingSigner([
                TransactionSigner(sendingSigner: transactionSending(signerAAddress, identity: "one", fill: 1)),
                TransactionSigner(sendingSigner: transactionSending(signerBAddress, identity: "two", fill: 2)),
            ])
        }
    }

    func testSignerConfigForwardsAbortSignalAndMinContextSlot() async throws {
        let signal = AbortSignal()
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let signer = TransactionPartialSigner(address: signerAddress, identity: SignerIdentity("config")) { _, config in
            XCTAssertTrue(config?.abortSignal === signal)
            XCTAssertEqual(config?.minContextSlot, 123)
            return [[:]]
        }
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAddress, nil)])
        )

        _ = try await signer.signTransactions(
            [transaction],
            config: SignerConfig(abortSignal: signal, minContextSlot: 123)
        )
    }

    func testDirectPartialSignerCallForwardsAlreadyAbortedConfig() async throws {
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let calls = SignerCallRecorder()
        let signer = TransactionPartialSigner(address: signerAddress, identity: SignerIdentity("direct-abort")) { _, config in
            XCTAssertTrue(config?.abortSignal === signal)
            await calls.record()
            return [[:]]
        }
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAddress, nil)])
        )

        _ = try await signer.signTransactions(
            [transaction],
            config: SignerConfig(abortSignal: signal)
        )

        let wasCalled = await calls.wasCalled
        XCTAssertTrue(wasCalled)
    }

    func testPartialSigningHonorsAlreadyAbortedSignalBeforeCallingSigner() async throws {
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let calls = SignerCallRecorder()
        let signer = TransactionSigner(partialSigner: TransactionPartialSigner(address: signerAddress, identity: SignerIdentity("abort")) { _, _ in
            await calls.record()
            return [[:]]
        })
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAddress, nil)])
        )

        do {
            _ = try await partiallySignTransactionWithSigners(
                [signer],
                transaction,
                config: SignerConfig(abortSignal: signal)
            )
            XCTFail("Expected abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
        let wasCalled = await calls.wasCalled
        XCTAssertFalse(wasCalled)
    }

    func testPartialSigningMergesReturnedSignaturesIfSignalAbortsAfterSignerReturns() async throws {
        let signal = AbortSignal()
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let transactionSigner = TransactionSigner(partialSigner: TransactionPartialSigner(address: signerAddress, identity: SignerIdentity("late-abort")) { _, _ in
            signal.abort()
            return [[signerAddress: try testSignature(filledWith: 7)]]
        })
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAddress, nil)])
        )

        let signedTransaction = try await partiallySignTransactionWithSigners(
            [transactionSigner],
            transaction,
            config: SignerConfig(abortSignal: signal)
        )

        XCTAssertEqual(signedTransaction.signatures.signature(for: signerAddress), try signature(filledWith: 7))

        let messageSignal = AbortSignal()
        let messageSigner = MessageSigner(partialSigner: MessagePartialSigner(address: signerAddress, identity: SignerIdentity("late-message-abort")) { _, _ in
            messageSignal.abort()
            return [[signerAddress: try testSignature(filledWith: 8)]]
        })
        let message = try OffchainMessage.v0(
            OffchainMessageV0(
                applicationDomain: "testdomain111111111111111111111111111111111",
                content: offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello world"),
                requiredSignatories: [OffchainMessageSignatory(address: signerAddress)]
            )
        )
        let messageWithSigners = try OffchainMessageWithSigners(
            message: message,
            requiredSignatories: [.signer(OffchainMessageSignatorySigner(address: signerAddress, signer: messageSigner))]
        )

        let signedEnvelope = try await partiallySignOffchainMessageWithSigners(
            messageWithSigners,
            config: SignerConfig(abortSignal: messageSignal)
        )

        XCTAssertEqual(signedEnvelope.signature(for: signerAddress), try signature(filledWith: 8))
    }

    func testSendingHonorsAlreadyAbortedSignalBeforeCallingSender() async throws {
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let signerAddress = try address("22222222222222222222222222222222222222222222")
        let calls = SignerCallRecorder()
        let signer = TransactionSigner(sendingSigner: TransactionSendingSigner(address: signerAddress, identity: SignerIdentity("abort-send")) { _, _ in
            await calls.record()
            return [try testSignature(filledWith: 9)]
        })
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAddress, nil)])
        )

        do {
            _ = try await signAndSendTransactionWithSigners(
                [signer],
                transaction,
                config: SignerConfig(abortSignal: signal)
            )
            XCTFail("Expected abort")
        } catch {
            XCTAssertTrue(isAbortError(error))
        }
        let wasCalled = await calls.wasCalled
        XCTAssertFalse(wasCalled)
    }

    func testOffchainMessageSigningWithEmbeddedSigners() async throws {
        let backend = CryptoKitBackend()
        let signer = try generateKeyPairSigner(using: backend, identity: SignerIdentity("offchain"))
        let message = try OffchainMessage.v0(
            OffchainMessageV0(
                applicationDomain: "testdomain111111111111111111111111111111111",
                content: offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello world"),
                requiredSignatories: [OffchainMessageSignatory(address: signer.address)]
            )
        )
        let signatorySigner = try OffchainMessageSignatorySigner(address: signer.address, signer: signer.messageSigner)
        let messageWithSigners = OffchainMessageWithSigners(message: message, requiredSignatories: [.signer(signatorySigner)])

        let envelope = try await signOffchainMessageWithSigners(messageWithSigners)

        XCTAssertTrue(isFullySignedOffchainMessageEnvelope(envelope))
        XCTAssertNotNil(envelope.signature(for: signer.address))
    }

    func testPartialOffchainMessageSignerMergesPreserveInputOrder() async throws {
        let targetAddress = try address("22222222222222222222222222222222222222222222")
        let otherAddress = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let slowFirst = MessageSigner(partialSigner: messagePartial(targetAddress, identity: "slow-message", fill: 1, delayNanoseconds: 20_000_000, signingAddress: targetAddress))
        let fastSecond = MessageSigner(partialSigner: messagePartial(otherAddress, identity: "fast-message", fill: 2, signingAddress: targetAddress))
        let message = try OffchainMessage.v0(
            OffchainMessageV0(
                applicationDomain: "testdomain111111111111111111111111111111111",
                content: offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello world"),
                requiredSignatories: [OffchainMessageSignatory(address: targetAddress)]
            )
        )
        let messageWithSigners = try OffchainMessageWithSigners(
            message: message,
            requiredSignatories: [
                .signer(OffchainMessageSignatorySigner(address: targetAddress, signer: slowFirst)),
                .signer(OffchainMessageSignatorySigner(address: otherAddress, signer: fastSecond)),
            ]
        )

        let envelope = try await partiallySignOffchainMessageWithSigners(messageWithSigners)

        XCTAssertEqual(envelope.signature(for: targetAddress), try signature(filledWith: 2))
    }

    private func transactionPartial(
        _ address: Address,
        identity: String,
        fill: UInt8,
        delayNanoseconds: UInt64 = 0,
        signingAddress: Address? = nil
    ) -> TransactionPartialSigner {
        TransactionPartialSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            return try transactions.map { _ in [(signingAddress ?? address): try testSignature(filledWith: fill)] }
        }
    }

    private func messagePartial(
        _ address: Address,
        identity: String,
        fill: UInt8,
        delayNanoseconds: UInt64 = 0,
        signingAddress: Address? = nil
    ) -> MessagePartialSigner {
        MessagePartialSigner(address: address, identity: SignerIdentity(identity)) { messages, _ in
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            return try messages.map { _ in [(signingAddress ?? address): try testSignature(filledWith: fill)] }
        }
    }

    private func messageModifying(_ address: Address, identity: String, fill: UInt8) -> MessageModifyingSigner {
        MessageModifyingSigner(address: address, identity: SignerIdentity(identity)) { messages, _ in
            try messages.map { message in
                var signatures = message.signatures
                signatures[address] = try testSignature(filledWith: fill)
                return SignableMessage(content: message.content, signatures: signatures)
            }
        }
    }

    private func transactionModifying(_ address: Address, identity: String, fill: UInt8) -> TransactionModifyingSigner {
        TransactionModifyingSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
            try transactions.map { transaction in
                Transaction(
                    messageBytes: transaction.messageBytes,
                    signatures: SignaturesMap(entries: try transaction.signatures.entries.map { entry in
                        TransactionSignature(
                            address: entry.address,
                            signature: entry.address == address ? try testSignature(filledWith: fill) : entry.signature
                        )
                    }),
                    lifetimeConstraint: transaction.lifetimeConstraint
                )
            }
        }
    }

    private func transactionSending(_ address: Address, identity: String, fill: UInt8) -> TransactionSendingSigner {
        TransactionSendingSigner(address: address, identity: SignerIdentity(identity)) { transactions, _ in
            try Array(repeating: testSignature(filledWith: fill), count: transactions.count)
        }
    }

    private func signature(filledWith byte: UInt8) throws -> SignatureBytes {
        try testSignature(filledWith: byte)
    }

    private func assertThrowsSolanaCode(
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
}

private func testSignature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private actor SignerCallRecorder {
    private var called = false

    var wasCalled: Bool {
        called
    }

    func record() {
        called = true
    }
}
