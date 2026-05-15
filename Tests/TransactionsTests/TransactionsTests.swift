import Addresses
import CryptoKitBackend
import Foundation
import Instructions
import Keys
import SolanaErrors
import TransactionMessages
import Transactions
import XCTest

final class TransactionsTests: XCTestCase {
    func testCompileTransactionBuildsMessageBytesSignaturesAndLifetimes() throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let readonlySigner = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let program = try address("p2Yicb86aZig616Eav2VWG9vuXR5mEqhtzshZYBxzsV")
        let blockhash = BlockhashLifetimeConstraint(
            blockhash: "11111111111111111111111111111111",
            lastValidBlockHeight: 42
        )
        let message = appendTransactionMessageInstruction(
            Instruction(
                programAddress: program,
                accounts: [.account(readonlySignerAccount(readonlySigner))],
                data: Data([1, 2, 3])
            ),
            setTransactionMessageLifetimeUsingBlockhash(
                blockhash,
                setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
            )
        )

        let transaction = try compileTransaction(message)

        XCTAssertFalse(transaction.messageBytes.isEmpty)
        XCTAssertEqual(transaction.signatures.addresses, [feePayer, readonlySigner])
        XCTAssertEqual(transaction.signatures.signatures, [nil, nil])
        XCTAssertEqual(
            transaction.lifetimeConstraint,
            .blockhash(TransactionBlockhashLifetime(blockhash: blockhash.blockhash, lastValidBlockHeight: 42))
        )
    }

    func testCompileTransactionForDurableNonceCopiesNonceAccountFromPrependedInstruction() throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let nonceAccount = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let nonceAuthority = try address("p2Yicb86aZig616Eav2VWG9vuXR5mEqhtzshZYBxzsV")
        let message = setTransactionMessageFeePayer(
            feePayer,
            setTransactionMessageLifetimeUsingDurableNonce(
                DurableNonceConfig(
                    nonce: "11111111111111111111111111111111",
                    nonceAccountAddress: nonceAccount,
                    nonceAuthorityAddress: nonceAuthority
                ),
                createTransactionMessage(version: .legacy)
            )
        )

        let transaction = try compileTransaction(message)

        XCTAssertEqual(
            transaction.lifetimeConstraint,
            .nonce(TransactionDurableNonceLifetime(nonce: "11111111111111111111111111111111", nonceAccountAddress: nonceAccount))
        )
    }

    func testCompileTransactionDoesNotInferNonceLifetimeWhenAdvanceNonceInstructionIsMissing() throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let message = TransactionMessage(
            version: .legacy,
            instructions: [],
            feePayer: TransactionMessageFeePayer(address: feePayer),
            lifetimeConstraint: .nonce(NonceLifetimeConstraint(nonce: "11111111111111111111111111111111"))
        )

        let transaction = try compileTransaction(message)

        XCTAssertNil(transaction.lifetimeConstraint)
    }

    func testSignatureGuardsAndSigning() throws {
        let backend = CryptoKitBackend()
        let keyPair = try generateKeyPair(using: backend)
        let signerAddress = try getAddressFromPublicKey(keyPair.publicKey.rawValue)
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(signerAddress, nil)])
        )

        XCTAssertFalse(isFullySignedTransaction(transaction))
        assertThrowsSolanaCode(.transactionSignaturesMissing) {
            try assertIsFullySignedTransaction(transaction)
        }

        let signed = try signTransaction([keyPair], transaction, using: backend)

        XCTAssertTrue(isFullySignedTransaction(signed))
        XCTAssertNotNil(signed.signatures.signature(for: signerAddress))
        XCTAssertEqual(signed.messageBytes, transaction.messageBytes)
    }

    func testUnexpectedSignersThrowWithTransactionCode() throws {
        let backend = CryptoKitBackend()
        let expectedKeyPair = try generateKeyPair(using: backend)
        let unexpectedKeyPair = try generateKeyPair(using: backend)
        let expectedAddress = try getAddressFromPublicKey(expectedKeyPair.publicKey.rawValue)
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(expectedAddress, nil)])
        )

        assertThrowsSolanaCode(.transactionAddressesCannotSignTransaction) {
            _ = try partiallySignTransaction([unexpectedKeyPair], transaction, using: backend)
        }
    }

    func testGetSignatureFromTransactionUsesFeePayerSignature() throws {
        let feePayer = try address("22222222222222222222222222222222222222222222")
        let signature = try SignatureBytes(Data(repeating: 9, count: 64))
        let transaction = Transaction(
            messageBytes: Data(),
            signatures: SignaturesMap([(feePayer, signature)])
        )

        XCTAssertEqual(
            try getSignatureFromTransaction(transaction).rawValue,
            "BUguQsv2ZuHus54HAFzjdJHzZBkygAjKhEeYwSG19tUfUyvvz3worsdQCdAXDNjakJHioSiyxhFiDJrm8XpSXRA"
        )
    }

    func testBlockhashLifetimePredicateRejectsMalformedBlockhashStrings() throws {
        let transaction = Transaction(
            messageBytes: Data([1, 0, 0, 0]),
            signatures: SignaturesMap([(try address("22222222222222222222222222222222222222222222"), nil)]),
            lifetimeConstraint: .blockhash(TransactionBlockhashLifetime(blockhash: "not-a-blockhash", lastValidBlockHeight: 42))
        )

        XCTAssertFalse(isTransactionWithBlockhashLifetime(transaction))
        assertThrowsSolanaCode(.transactionExpectedBlockhashLifetime) {
            try assertIsTransactionWithBlockhashLifetime(transaction)
        }
    }

    func testSignaturesMapCollapsesDuplicateAddressesUsingObjectSemantics() throws {
        let signer = try address("22222222222222222222222222222222222222222222")
        let firstSignature = try SignatureBytes(Data(repeating: 1, count: 64))
        let secondSignature = try SignatureBytes(Data(repeating: 2, count: 64))
        let signatures = SignaturesMap([
            (signer, firstSignature),
            (signer, secondSignature),
        ])

        XCTAssertEqual(signatures.count, 1)
        XCTAssertEqual(signatures.addresses, [signer])
        XCTAssertEqual(signatures.signature(for: signer), secondSignature)
        XCTAssertEqual(
            try getTransactionEncoder().encode(Transaction(messageBytes: Data([1, 0, 0, 0]), signatures: signatures)),
            Data([1]) + secondSignature.rawValue + Data([1, 0, 0, 0])
        )
    }

    func testTransactionCodecEncodesLegacyAndV1Envelopes() throws {
        let legacy = Transaction(
            messageBytes: Data([1, 0, 0, 0]),
            signatures: SignaturesMap([(try address("22222222222222222222222222222222222222222222"), nil)])
        )
        XCTAssertEqual(
            try getTransactionEncoder().encode(legacy),
            Data([1] + Array(repeating: 0, count: 64) + [1, 0, 0, 0])
        )

        let v1 = Transaction(
            messageBytes: Data([129, 1, 0, 0]),
            signatures: SignaturesMap([(try address("22222222222222222222222222222222222222222222"), try SignatureBytes(Data(repeating: 7, count: 64)))])
        )
        XCTAssertEqual(
            try getTransactionEncoder().encode(v1),
            Data([129, 1, 0, 0] + Array(repeating: 7, count: 64))
        )
    }

    func testTransactionCodecDecodesLegacyV0AndV1Signatures() throws {
        let address1Bytes = Data(repeating: 11, count: 32)
        let address2Bytes = Data(repeating: 12, count: 32)
        let address1 = try address("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let address2 = try address("p2Yicb86aZig616Eav2VWG9vuXR5mEqhtzshZYBxzsV")
        let signature1 = try SignatureBytes(Data(repeating: 1, count: 64))
        let signature2 = try SignatureBytes(Data(repeating: 2, count: 64))

        let legacyMessageBytes = Data([2, 0, 1, 2]) + address1Bytes + address2Bytes + Data([1, 2, 3])
        let legacyBytes = Data([2]) + signature1.rawValue + Data(repeating: 0, count: 64) + legacyMessageBytes
        let legacy = try getTransactionDecoder().decode(legacyBytes)
        XCTAssertEqual(legacy.messageBytes, legacyMessageBytes)
        XCTAssertEqual(legacy.signatures.entries, [
            TransactionSignature(address: address1, signature: signature1),
            TransactionSignature(address: address2, signature: nil),
        ])

        let v0MessageBytes = Data([128, 2, 0, 1, 2]) + address1Bytes + address2Bytes + Data([1, 2, 3])
        let v0Bytes = Data([2]) + signature1.rawValue + signature2.rawValue + v0MessageBytes
        let v0 = try getTransactionDecoder().decode(v0Bytes)
        XCTAssertEqual(v0.signatures.entries, [
            TransactionSignature(address: address1, signature: signature1),
            TransactionSignature(address: address2, signature: signature2),
        ])

        let v1MessageBytes = Data([129, 2, 0, 1])
            + Data(repeating: 0, count: 4)
            + Data(repeating: 0, count: 32)
            + Data([1, 2])
            + address1Bytes
            + address2Bytes
            + Data([1, 2, 3])
        let v1Bytes = v1MessageBytes + signature1.rawValue + Data(repeating: 0, count: 64)
        let v1 = try getTransactionDecoder().decode(v1Bytes)
        XCTAssertEqual(v1.signatures.entries, [
            TransactionSignature(address: address1, signature: signature1),
            TransactionSignature(address: address2, signature: nil),
        ])
    }

    func testTransactionCodecErrorCodes() throws {
        assertThrowsSolanaCode(.transactionCannotEncodeWithEmptySignatures) {
            _ = try getTransactionEncoder().encode(Transaction(messageBytes: Data([1, 0, 0]), signatures: SignaturesMap()))
        }
        assertThrowsSolanaCode(.transactionCannotEncodeWithEmptyMessageBytes) {
            _ = try getTransactionEncoder().encode(Transaction(messageBytes: Data(), signatures: SignaturesMap()))
        }
        assertThrowsSolanaCode(.transactionCannotDecodeEmptyTransactionBytes) {
            _ = try getTransactionDecoder().decode(Data())
        }
        assertThrowsSolanaCode(.transactionVersionZeroMustBeEncodedWithSignaturesFirst) {
            _ = try getTransactionDecoder().decode(Data([128, 1, 0]))
        }
        assertThrowsSolanaCode(.transactionVersionNumberNotSupported) {
            _ = try getTransactionDecoder().decode(Data([130, 1, 0]))
        }
        assertThrowsSolanaCode(.transactionSignatureCountTooHighForTransactionBytes) {
            _ = try getTransactionDecoder().decode(Data([129, 2, 0]))
        }
    }

    func testLifetimeExtractionFromCompiledMessages() throws {
        let nonceAccount = try address("22222222222222222222222222222222222222222222")
        let sysvar = try address("SysvarRecentB1ockHashes11111111111111111111")
        let authority = try address("33333333333333333333333333333333333333333333")
        let legacy = CompiledTransactionMessage.legacy(
            LegacyCompiledTransactionMessage(
                header: MessageHeader(numReadonlyNonSignerAccounts: 1, numReadonlySignerAccounts: 0, numSignerAccounts: 1),
                instructions: [
                    CompiledInstruction(accountIndices: [1, 2, 3], data: Data([4, 0, 0, 0]), programAddressIndex: 0),
                ],
                lifetimeToken: "11111111111111111111111111111111",
                staticAccounts: [systemProgramAddressForTests, nonceAccount, sysvar, authority]
            )
        )
        XCTAssertEqual(
            try getTransactionLifetimeConstraintFromCompiledTransactionMessage(legacy),
            .nonce(TransactionDurableNonceLifetime(nonce: "11111111111111111111111111111111", nonceAccountAddress: nonceAccount))
        )

        let v1 = CompiledTransactionMessage.v1(
            V1CompiledTransactionMessage(
                configMask: 0,
                configValues: [],
                header: MessageHeader(numReadonlyNonSignerAccounts: 1, numReadonlySignerAccounts: 0, numSignerAccounts: 1),
                instructionHeaders: [
                    InstructionHeader(numInstructionAccounts: 3, numInstructionDataBytes: 4, programAccountIndex: 0),
                ],
                instructionPayloads: [
                    InstructionPayload(instructionAccountIndices: [1, 2, 3], instructionData: Data([4, 0, 0, 0])),
                ],
                lifetimeToken: "11111111111111111111111111111111",
                numInstructions: 1,
                numStaticAccounts: 4,
                staticAccounts: [systemProgramAddressForTests, nonceAccount, sysvar, authority]
            )
        )
        XCTAssertEqual(
            try getTransactionLifetimeConstraintFromCompiledTransactionMessage(v1),
            .nonce(TransactionDurableNonceLifetime(nonce: "11111111111111111111111111111111", nonceAccountAddress: nonceAccount))
        )

        let v1HeaderNonceWithShortPayload = CompiledTransactionMessage.v1(
            V1CompiledTransactionMessage(
                configMask: 0,
                configValues: [],
                header: MessageHeader(numReadonlyNonSignerAccounts: 1, numReadonlySignerAccounts: 0, numSignerAccounts: 1),
                instructionHeaders: [
                    InstructionHeader(numInstructionAccounts: 3, numInstructionDataBytes: 4, programAccountIndex: 0),
                ],
                instructionPayloads: [
                    InstructionPayload(instructionAccountIndices: [1], instructionData: Data([4, 0, 0, 0])),
                ],
                lifetimeToken: "11111111111111111111111111111111",
                numInstructions: 1,
                numStaticAccounts: 4,
                staticAccounts: [systemProgramAddressForTests, nonceAccount, sysvar, authority]
            )
        )
        XCTAssertEqual(
            try getTransactionLifetimeConstraintFromCompiledTransactionMessage(v1HeaderNonceWithShortPayload),
            .nonce(TransactionDurableNonceLifetime(nonce: "11111111111111111111111111111111", nonceAccountAddress: nonceAccount))
        )

        let v1HeaderNonceWithMissingIndex = CompiledTransactionMessage.v1(
            V1CompiledTransactionMessage(
                configMask: 0,
                configValues: [],
                header: MessageHeader(numReadonlyNonSignerAccounts: 1, numReadonlySignerAccounts: 0, numSignerAccounts: 1),
                instructionHeaders: [
                    InstructionHeader(numInstructionAccounts: 3, numInstructionDataBytes: 4, programAccountIndex: 0),
                ],
                instructionPayloads: [
                    InstructionPayload(instructionAccountIndices: [], instructionData: Data([4, 0, 0, 0])),
                ],
                lifetimeToken: "11111111111111111111111111111111",
                numInstructions: 1,
                numStaticAccounts: 4,
                staticAccounts: [systemProgramAddressForTests, nonceAccount, sysvar, authority]
            )
        )
        assertThrowsSolanaCode(.transactionInvalidNonceAccountIndex) {
            _ = try getTransactionLifetimeConstraintFromCompiledTransactionMessage(v1HeaderNonceWithMissingIndex)
        }
    }

    func testLifetimeExtractionHandlesNegativeCompiledIndicesWithoutTrapping() throws {
        let nonceAccount = try address("22222222222222222222222222222222222222222222")
        let sysvar = try address("SysvarRecentB1ockHashes11111111111111111111")
        let authority = try address("33333333333333333333333333333333333333333333")
        let malformedProgramIndex = CompiledTransactionMessage.legacy(
            LegacyCompiledTransactionMessage(
                header: MessageHeader(numReadonlyNonSignerAccounts: 1, numReadonlySignerAccounts: 0, numSignerAccounts: 1),
                instructions: [
                    CompiledInstruction(accountIndices: [1, 2, 3], data: Data([4, 0, 0, 0]), programAddressIndex: -1),
                ],
                lifetimeToken: "11111111111111111111111111111111",
                staticAccounts: [systemProgramAddressForTests, nonceAccount, sysvar, authority]
            )
        )
        XCTAssertEqual(
            try getTransactionLifetimeConstraintFromCompiledTransactionMessage(malformedProgramIndex),
            .blockhash(TransactionBlockhashLifetime(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: UInt64.max))
        )

        let malformedLegacyNonceIndex = CompiledTransactionMessage.legacy(
            LegacyCompiledTransactionMessage(
                header: MessageHeader(numReadonlyNonSignerAccounts: 1, numReadonlySignerAccounts: 0, numSignerAccounts: 1),
                instructions: [
                    CompiledInstruction(accountIndices: [-1, 2, 3], data: Data([4, 0, 0, 0]), programAddressIndex: 0),
                ],
                lifetimeToken: "11111111111111111111111111111111",
                staticAccounts: [systemProgramAddressForTests, nonceAccount, sysvar, authority]
            )
        )
        assertThrowsSolanaCode(.transactionNonceAccountCannotBeInLookupTable) {
            _ = try getTransactionLifetimeConstraintFromCompiledTransactionMessage(malformedLegacyNonceIndex)
        }

        let malformedV1NonceIndex = CompiledTransactionMessage.v1(
            V1CompiledTransactionMessage(
                configMask: 0,
                configValues: [],
                header: MessageHeader(numReadonlyNonSignerAccounts: 1, numReadonlySignerAccounts: 0, numSignerAccounts: 1),
                instructionHeaders: [
                    InstructionHeader(numInstructionAccounts: 3, numInstructionDataBytes: 4, programAccountIndex: 0),
                ],
                instructionPayloads: [
                    InstructionPayload(instructionAccountIndices: [-1, 2, 3], instructionData: Data([4, 0, 0, 0])),
                ],
                lifetimeToken: "11111111111111111111111111111111",
                numInstructions: 1,
                numStaticAccounts: 4,
                staticAccounts: [systemProgramAddressForTests, nonceAccount, sysvar, authority]
            )
        )
        assertThrowsSolanaCode(.transactionInvalidNonceAccountIndex) {
            _ = try getTransactionLifetimeConstraintFromCompiledTransactionMessage(malformedV1NonceIndex)
        }
    }

    func testSizeLimitAndWireBase64Parity() throws {
        let transaction = try wireSampleTransaction()
        XCTAssertEqual(try getBase64EncodedWireTransaction(transaction), wireSampleBase64)
        XCTAssertEqual(getTransactionSizeLimit(transaction), legacyTransactionSizeLimit)
        XCTAssertTrue(try isTransactionWithinSizeLimit(transaction))
    }

    func testSizeLimitPredicatePropagatesMalformedEnvelopeErrors() throws {
        let signer = try address("22222222222222222222222222222222222222222222")
        let malformedV1 = Transaction(
            messageBytes: Data([129]),
            signatures: SignaturesMap([(signer, nil)])
        )

        assertThrowsSolanaCode(.transactionMalformedMessageBytes) {
            _ = try isTransactionWithinSizeLimit(malformedV1)
        }

        assertThrowsSolanaCode(.transactionMalformedMessageBytes) {
            _ = try isSendableTransaction(
                Transaction(
                    messageBytes: malformedV1.messageBytes,
                    signatures: SignaturesMap([(signer, try SignatureBytes(Data(repeating: 1, count: 64)))])
                )
            )
        }
    }

    func testTransactionDecoderRejectsNegativeOffsetWithoutTrapping() throws {
        assertThrowsSolanaCode(.codecsOffsetOutOfRange) {
            _ = try getTransactionDecoder().read(Data([1, 0, 0, 0]), at: -1)
        }
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

private let systemProgramAddressForTests = Address(unchecked: "11111111111111111111111111111111")

private let wireSampleBase64 =
    "AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABlyfqJ5qvbi2J5r1hDgkimf7xAsjcGduDtpu9zfTn8MGyAgMBmLTJ6VrW508Eg1xWkND+TiiPuCPuCPuCPuCPugAIBAQMPHmsUIcBKBwQxJlwZxbvuGZK66K/RzQeO+K9wR9wR9y1bQTxlQN4VDJNzFE1RM8pMuDC6D3VnFqzqDlDXlDXlPHmsUIcBKBwQxJlwZxbvuGZK66K/RzQeO+K9wR9wR9wePNYoQ4CUDghiTLgzi3fcMyV10V+jmg8d8V7gj7gj7gECAQEAAA=="

private func wireSampleTransaction() throws -> Transaction {
    let feePayer = Address(unchecked: "22222222222222222222222222222222222222222222")
    let signer = Address(unchecked: "44444444444444444444444444444444444444444")
    let signature = try SignatureBytes(Data([
        0x65, 0xc9, 0xfa, 0x89, 0xe6, 0xab, 0xdb, 0x8b, 0x62, 0x79, 0xaf, 0x58, 0x43, 0x82, 0x48, 0xa6,
        0x7f, 0xbc, 0x40, 0xb2, 0x37, 0x06, 0x76, 0xe0, 0xed, 0xa6, 0xef, 0x73, 0x7d, 0x39, 0xfc, 0x30,
        0x6c, 0x80, 0x80, 0xc0, 0x66, 0x2d, 0x32, 0x7a, 0x56, 0xb5, 0xb9, 0xd3, 0xc1, 0x20, 0xd7, 0x15,
        0xa4, 0x34, 0x3f, 0x93, 0x8a, 0x23, 0xee, 0x08, 0xfb, 0x82, 0x3e, 0xe0, 0x8f, 0xb8, 0x23, 0xee,
    ]))
    return Transaction(
        messageBytes: Data([
            128, 2, 1, 1, 3, 15, 30, 107, 20, 33, 192, 74, 7, 4, 49, 38, 92, 25, 197, 187, 238, 25, 146, 186, 232,
            175, 209, 205, 7, 142, 248, 175, 112, 71, 220, 17, 247, 45, 91, 65, 60, 101, 64, 222, 21, 12, 147, 115,
            20, 77, 81, 51, 202, 76, 184, 48, 186, 15, 117, 103, 22, 172, 234, 14, 80, 215, 148, 53, 229, 60, 121,
            172, 80, 135, 1, 40, 28, 16, 196, 153, 112, 103, 22, 239, 184, 102, 74, 235, 162, 191, 71, 52, 30, 59,
            226, 189, 193, 31, 112, 71, 220, 30, 60, 214, 40, 67, 128, 148, 14, 8, 98, 76, 184, 51, 139, 119, 220,
            51, 37, 117, 209, 95, 163, 154, 15, 29, 241, 94, 224, 143, 184, 35, 238, 1, 2, 1, 1, 0, 0,
        ]),
        signatures: SignaturesMap([(feePayer, nil), (signer, signature)])
    )
}
