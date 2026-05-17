import Addresses
import CryptoKitBackend
import Foundation
import Instructions
import Keys
import SolanaErrors
import TransactionMessages
import Transactions
import XCTest

final class TransactionsDetailedBehaviorTests: XCTestCase {
    func testTransactionSizeLimitsUseMessageVersionAndIncludeSignatureBytes() throws {
        let signer = try address("22222222222222222222222222222222222222222222")
        let signature = try transactionsDetailedSignature(filledWith: 1)
        let legacy = Transaction(
            messageBytes: Data([0, 0, 0, 0]),
            signatures: SignaturesMap([(signer, signature)])
        )
        let legacyOversized = Transaction(
            messageBytes: Data([0]) + Data(repeating: 2, count: legacyTransactionSizeLimit),
            signatures: SignaturesMap([(signer, signature)])
        )
        let v1OverLegacyLimit = Transaction(
            messageBytes: Data([129, 1]) + Data(repeating: 3, count: legacyTransactionSizeLimit),
            signatures: SignaturesMap([(signer, signature)])
        )
        let v1Oversized = Transaction(
            messageBytes: Data([129, 1]) + Data(repeating: 4, count: v1TransactionSizeLimit),
            signatures: SignaturesMap([(signer, signature)])
        )

        XCTAssertEqual(try getTransactionSize(legacy), 69)
        XCTAssertEqual(getTransactionSizeLimit(legacy), legacyTransactionSizeLimit)
        XCTAssertEqual(getTransactionSizeLimit(v1OverLegacyLimit), v1TransactionSizeLimit)
        XCTAssertTrue(try isTransactionWithinSizeLimit(legacy))
        XCTAssertFalse(try isTransactionWithinSizeLimit(legacyOversized))
        XCTAssertTrue(try isTransactionWithinSizeLimit(v1OverLegacyLimit))
        XCTAssertFalse(try isTransactionWithinSizeLimit(v1Oversized))

        transactionsDetailedAssertThrowsSolanaCode(.transactionExceedsSizeLimit) {
            try assertIsTransactionWithinSizeLimit(legacyOversized)
        }
        transactionsDetailedAssertThrowsSolanaCode(.transactionExceedsSizeLimit) {
            try assertIsTransactionWithinSizeLimit(v1Oversized)
        }
    }

    func testSendableTransactionChecksSignaturesBeforeSize() throws {
        let signer = try address("22222222222222222222222222222222222222222222")
        let oversizedMessage = Data([0]) + Data(repeating: 7, count: legacyTransactionSizeLimit)
        let unsigned = Transaction(
            messageBytes: oversizedMessage,
            signatures: SignaturesMap([(signer, nil)])
        )
        let signed = Transaction(
            messageBytes: oversizedMessage,
            signatures: SignaturesMap([(signer, try transactionsDetailedSignature(filledWith: 1))])
        )

        XCTAssertFalse(try isSendableTransaction(unsigned))
        XCTAssertFalse(try isSendableTransaction(signed))
        transactionsDetailedAssertThrowsSolanaCode(.transactionSignaturesMissing) {
            try assertIsSendableTransaction(unsigned)
        }
        transactionsDetailedAssertThrowsSolanaCode(.transactionExceedsSizeLimit) {
            try assertIsSendableTransaction(signed)
        }
    }

    func testEncoderWriteAndDecoderReadHonorOffsets() throws {
        let signer = try address("22222222222222222222222222222222222222222222")
        let signature = try transactionsDetailedSignature(filledWith: 5)
        let messageBytes = try transactionsDetailedLegacyMessageBytes(signerAddresses: [signer])
        let transaction = Transaction(
            messageBytes: messageBytes,
            signatures: SignaturesMap([(signer, signature)])
        )
        let encoded = try getTransactionEncoder().encode(transaction)
        var buffer = Data([9, 9]) + Data(repeating: 0, count: encoded.count)

        let nextOffset = try getTransactionEncoder().write(transaction, into: &buffer, at: 2)
        let (decoded, decodedOffset) = try getTransactionDecoder().read(buffer, at: 2)

        XCTAssertEqual(nextOffset, buffer.count)
        XCTAssertEqual(decodedOffset, buffer.count)
        XCTAssertEqual(Data(buffer.prefix(2)), Data([9, 9]))
        XCTAssertEqual(Data(buffer.dropFirst(2)), encoded)
        XCTAssertEqual(decoded, transaction)
    }

    func testDecoderReportsSignatureCountMismatchesWithSignerAddresses() throws {
        let signer = try address("22222222222222222222222222222222222222222222")
        let messageBytes = try transactionsDetailedLegacyMessageBytes(signerAddresses: [signer])
        let bytes = Data([2])
            + (try transactionsDetailedSignature(filledWith: 1)).rawValue
            + (try transactionsDetailedSignature(filledWith: 2)).rawValue
            + messageBytes

        do {
            _ = try getTransactionDecoder().decode(bytes)
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionMessageSignaturesMismatch.rawValue)
            XCTAssertEqual(error.context["numRequiredSignatures"], .int(1))
            XCTAssertEqual(error.context["signaturesLength"], .int(2))
            XCTAssertEqual(error.context["signerAddresses"], .stringArray([signer.rawValue]))
        }
    }

    func testSigningKeepsMessageBytesPreservesOrderAndReturnsEqualTransactionWhenUnchanged() throws {
        let backend = CryptoKitBackend()
        let firstKeyPair = try generateKeyPair(using: backend)
        let secondKeyPair = try generateKeyPair(using: backend)
        let firstAddress = try getAddressFromPublicKey(firstKeyPair.publicKey.rawValue)
        let secondAddress = try getAddressFromPublicKey(secondKeyPair.publicKey.rawValue)
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(firstAddress, nil), (secondAddress, nil)])
        )

        let signed = try partiallySignTransaction([secondKeyPair, firstKeyPair], transaction, using: backend)
        let resigned = try partiallySignTransaction([firstKeyPair, secondKeyPair], signed, using: backend)

        XCTAssertEqual(signed.messageBytes, transaction.messageBytes)
        XCTAssertEqual(signed.signatures.addresses, [firstAddress, secondAddress])
        XCTAssertNotNil(signed.signatures.signature(for: firstAddress))
        XCTAssertNotNil(signed.signatures.signature(for: secondAddress))
        XCTAssertEqual(resigned, signed)
    }

    func testUnexpectedSignerErrorIncludesAllUnexpectedAddresses() throws {
        let backend = CryptoKitBackend()
        let expectedKeyPair = try generateKeyPair(using: backend)
        let firstUnexpected = try generateKeyPair(using: backend)
        let secondUnexpected = try generateKeyPair(using: backend)
        let expectedAddress = try getAddressFromPublicKey(expectedKeyPair.publicKey.rawValue)
        let firstUnexpectedAddress = try getAddressFromPublicKey(firstUnexpected.publicKey.rawValue)
        let secondUnexpectedAddress = try getAddressFromPublicKey(secondUnexpected.publicKey.rawValue)
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([(expectedAddress, nil)])
        )

        do {
            _ = try partiallySignTransaction([firstUnexpected, secondUnexpected], transaction, using: backend)
            XCTFail("Expected an error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionAddressesCannotSignTransaction.rawValue)
            XCTAssertEqual(error.context["expectedAddresses"], .stringArray([expectedAddress.rawValue]))
            XCTAssertEqual(
                error.context["unexpectedAddresses"],
                .stringArray([firstUnexpectedAddress.rawValue, secondUnexpectedAddress.rawValue])
            )
        }
    }

    func testSignatureAndLifetimeAssertionsCoverEmptyWrongAndValidShapes() throws {
        let signer = try address("22222222222222222222222222222222222222222222")
        let emptySignatures = Transaction(messageBytes: Data([1, 0, 0, 0]), signatures: SignaturesMap())
        let missingFeePayer = Transaction(messageBytes: Data(), signatures: SignaturesMap([(signer, nil)]))
        let blockhashLifetime = TransactionLifetimeConstraint.blockhash(
            TransactionBlockhashLifetime(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 42)
        )
        let nonceLifetime = TransactionLifetimeConstraint.nonce(
            TransactionDurableNonceLifetime(nonce: "11111111111111111111111111111111", nonceAccountAddress: signer)
        )
        let blockhashTransaction = Transaction(messageBytes: Data([1, 0, 0, 0]), signatures: SignaturesMap(), lifetimeConstraint: blockhashLifetime)
        let nonceTransaction = Transaction(messageBytes: Data([1, 0, 0, 0]), signatures: SignaturesMap(), lifetimeConstraint: nonceLifetime)

        XCTAssertTrue(isFullySignedTransaction(emptySignatures))
        XCTAssertTrue(isTransactionWithBlockhashLifetime(blockhashTransaction))
        XCTAssertTrue(isTransactionWithDurableNonceLifetime(nonceTransaction))
        try assertIsFullySignedTransaction(emptySignatures)
        try assertIsTransactionWithBlockhashLifetime(blockhashTransaction)
        try assertIsTransactionWithDurableNonceLifetime(nonceTransaction)

        transactionsDetailedAssertThrowsSolanaCode(.transactionFeePayerSignatureMissing) {
            _ = try getSignatureFromTransaction(missingFeePayer)
        }
        transactionsDetailedAssertThrowsSolanaCode(.transactionExpectedBlockhashLifetime) {
            try assertIsTransactionWithBlockhashLifetime(nonceTransaction)
        }
        transactionsDetailedAssertThrowsSolanaCode(.transactionExpectedNonceLifetime) {
            try assertIsTransactionWithDurableNonceLifetime(blockhashTransaction)
        }
        transactionsDetailedAssertThrowsSolanaCode(.transactionExpectedBlockhashLifetime) {
            try assertIsTransactionWithBlockhashLifetime(emptySignatures)
        }
        transactionsDetailedAssertThrowsSolanaCode(.transactionExpectedNonceLifetime) {
            try assertIsTransactionWithDurableNonceLifetime(emptySignatures)
        }
    }
}

private func transactionsDetailedLegacyMessageBytes(signerAddresses: [Address]) throws -> Data {
    var bytes = Data([
        UInt8(signerAddresses.count),
        0,
        0,
        UInt8(signerAddresses.count),
    ])
    for signerAddress in signerAddresses {
        bytes.append(try getAddressEncoder().encode(signerAddress))
    }
    bytes.append(Data([1, 2, 3]))
    return bytes
}

private func transactionsDetailedSignature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private func transactionsDetailedAssertThrowsSolanaCode(
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
