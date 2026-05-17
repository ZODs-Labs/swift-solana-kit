import Addresses
import CryptoKitBackend
import Foundation
import Instructions
import Keys
import SolanaErrors
import TransactionMessages
import Transactions
import XCTest

final class TransactionsRuntimeBehaviorTests: XCTestCase {
    func testCompiledMessageSizeHelpersUseVersionSpecificLimitsAndExactSizes() throws {
        let smallV0 = try transactionRuntimeSizedMessage(version: .v0, dataCount: nil)
        let oversizedV0 = try transactionRuntimeSizedMessage(version: .v0, dataCount: legacyTransactionSizeLimit + 1)
        let smallV1 = try transactionRuntimeSizedMessage(version: .v1, dataCount: nil)
        let v1OverLegacyLimit = try transactionRuntimeSizedMessage(version: .v1, dataCount: legacyTransactionSizeLimit + 1)
        let v1OverV1Limit = try transactionRuntimeSizedMessage(version: .v1, dataCount: v1TransactionSizeLimit + 1)

        XCTAssertEqual(getTransactionMessageSizeLimit(try transactionRuntimeSizedMessage(version: .legacy, dataCount: nil)), legacyTransactionSizeLimit)
        XCTAssertEqual(getTransactionMessageSizeLimit(smallV0), legacyTransactionSizeLimit)
        XCTAssertEqual(getTransactionMessageSizeLimit(smallV1), v1TransactionSizeLimit)
        XCTAssertEqual(try getTransactionMessageSize(smallV0), 136)
        XCTAssertEqual(try getTransactionMessageSize(oversizedV0), 1_405)
        XCTAssertEqual(try getTransactionMessageSize(v1OverV1Limit), 4_271)

        XCTAssertTrue(try isTransactionMessageWithinSizeLimit(smallV0))
        XCTAssertFalse(try isTransactionMessageWithinSizeLimit(oversizedV0))
        XCTAssertTrue(try isTransactionMessageWithinSizeLimit(v1OverLegacyLimit))
        XCTAssertFalse(try isTransactionMessageWithinSizeLimit(v1OverV1Limit))
        try assertIsTransactionMessageWithinSizeLimit(smallV0)
        try assertIsTransactionMessageWithinSizeLimit(v1OverLegacyLimit)

        transactionRuntimeAssertThrowsSolanaError(.transactionExceedsSizeLimit) { error in
            XCTAssertEqual(error.context["transactionSize"], .int(1_405))
            XCTAssertEqual(error.context["transactionSizeLimit"], .int(legacyTransactionSizeLimit))
        } body: {
            try assertIsTransactionMessageWithinSizeLimit(oversizedV0)
        }
        transactionRuntimeAssertThrowsSolanaError(.transactionExceedsSizeLimit) { error in
            XCTAssertEqual(error.context["transactionSize"], .int(4_271))
            XCTAssertEqual(error.context["transactionSizeLimit"], .int(v1TransactionSizeLimit))
        } body: {
            try assertIsTransactionMessageWithinSizeLimit(v1OverV1Limit)
        }
    }

    func testCompiledTransactionSizeHelpersUseVersionSpecificLimitsAndExactSizes() throws {
        let smallV0 = try compileTransaction(transactionRuntimeSizedMessage(version: .v0, dataCount: nil))
        let oversizedV0 = try compileTransaction(transactionRuntimeSizedMessage(version: .v0, dataCount: legacyTransactionSizeLimit + 1))
        let v1OverLegacyLimit = try compileTransaction(transactionRuntimeSizedMessage(version: .v1, dataCount: legacyTransactionSizeLimit + 1))
        let v1OverV1Limit = try compileTransaction(transactionRuntimeSizedMessage(version: .v1, dataCount: v1TransactionSizeLimit + 1))

        XCTAssertEqual(try getTransactionSize(smallV0), 136)
        XCTAssertEqual(try getTransactionSize(oversizedV0), 1_405)
        XCTAssertEqual(try getTransactionSize(v1OverV1Limit), 4_271)
        XCTAssertTrue(try isTransactionWithinSizeLimit(smallV0))
        XCTAssertFalse(try isTransactionWithinSizeLimit(oversizedV0))
        XCTAssertTrue(try isTransactionWithinSizeLimit(v1OverLegacyLimit))
        XCTAssertFalse(try isTransactionWithinSizeLimit(v1OverV1Limit))
        try assertIsTransactionWithinSizeLimit(smallV0)
        try assertIsTransactionWithinSizeLimit(v1OverLegacyLimit)

        transactionRuntimeAssertThrowsSolanaError(.transactionExceedsSizeLimit) { error in
            XCTAssertEqual(error.context["transactionSize"], .int(1_405))
            XCTAssertEqual(error.context["transactionSizeLimit"], .int(legacyTransactionSizeLimit))
        } body: {
            try assertIsTransactionWithinSizeLimit(oversizedV0)
        }
        transactionRuntimeAssertThrowsSolanaError(.transactionExceedsSizeLimit) { error in
            XCTAssertEqual(error.context["transactionSize"], .int(4_271))
            XCTAssertEqual(error.context["transactionSizeLimit"], .int(v1TransactionSizeLimit))
        } body: {
            try assertIsTransactionWithinSizeLimit(v1OverV1Limit)
        }
    }

    func testSignatureEncodingBytesCoverPrefixedAndFixedLengthShapes() throws {
        let first = try transactionRuntimeAddress("22222222222222222222222222222222222222222222")
        let second = try transactionRuntimeAddress("33333333333333333333333333333333333333333333")
        let third = try transactionRuntimeAddress("k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn")
        let signature1 = try transactionRuntimeSignature(1)
        let signature2 = try transactionRuntimeSignature(2)
        let signature3 = try transactionRuntimeSignature(3)
        let legacyMessage = Data([3, 0, 0, 0])
        let mixedLegacy = Transaction(
            messageBytes: legacyMessage,
            signatures: SignaturesMap([(first, signature1), (second, nil), (third, signature3)])
        )
        let allLegacy = Transaction(
            messageBytes: legacyMessage,
            signatures: SignaturesMap([(first, signature1), (second, signature2), (third, signature3)])
        )
        let emptyLegacy = Transaction(
            messageBytes: legacyMessage,
            signatures: SignaturesMap([(first, nil), (second, nil), (third, nil)])
        )

        XCTAssertEqual(
            try getTransactionEncoder().encode(mixedLegacy),
            Data([3]) + signature1.rawValue + Data(repeating: 0, count: 64) + signature3.rawValue + legacyMessage
        )
        XCTAssertEqual(
            try getTransactionEncoder().encode(allLegacy),
            Data([3]) + signature1.rawValue + signature2.rawValue + signature3.rawValue + legacyMessage
        )
        XCTAssertEqual(
            try getTransactionEncoder().encode(emptyLegacy),
            Data([3]) + Data(repeating: 0, count: 192) + legacyMessage
        )

        let v1Message = Data([129, 3, 0, 0])
        let mixedV1 = Transaction(
            messageBytes: v1Message,
            signatures: SignaturesMap([(first, signature1), (second, nil), (third, signature3)])
        )
        let emptyV1 = Transaction(
            messageBytes: v1Message,
            signatures: SignaturesMap([(first, nil), (second, nil), (third, nil)])
        )

        XCTAssertEqual(
            try getTransactionEncoder().encode(mixedV1),
            v1Message + signature1.rawValue + Data(repeating: 0, count: 64) + signature3.rawValue
        )
        XCTAssertEqual(
            try getTransactionEncoder().encode(emptyV1),
            v1Message + Data(repeating: 0, count: 192)
        )

        transactionRuntimeAssertThrowsCode(.codecsInvalidNumberOfItems) {
            _ = try getTransactionEncoder().encode(
                Transaction(
                    messageBytes: Data([129, 2, 0, 0]),
                    signatures: SignaturesMap([(first, signature1), (second, signature2), (third, signature3)])
                )
            )
        }
    }

    func testDecoderRejectsUnsupportedVersionInsideBothEnvelopeShapes() throws {
        let signature = try transactionRuntimeSignature(1)
        let signaturesFirst = Data([1]) + signature.rawValue + Data([130, 1, 0, 0, 1])
        let messageFirst = Data([130, 1, 0, 0]) + Data(repeating: 0, count: 64)

        transactionRuntimeAssertThrowsSolanaError(.transactionVersionNumberNotSupported) { error in
            XCTAssertEqual(error.context["unsupportedVersion"], .int(2))
        } body: {
            _ = try getTransactionDecoder().decode(signaturesFirst)
        }
        transactionRuntimeAssertThrowsSolanaError(.transactionVersionNumberNotSupported) { error in
            XCTAssertEqual(error.context["unsupportedVersion"], .int(2))
        } body: {
            _ = try getTransactionDecoder().decode(messageFirst)
        }
    }

    func testSigningReplacesDifferentExistingSignatureAndReportsMissingAddressesInOrder() throws {
        let backend = CryptoKitBackend()
        let firstKeyPair = try generateKeyPair(using: backend)
        let secondKeyPair = try generateKeyPair(using: backend)
        let firstAddress = try getAddressFromPublicKey(firstKeyPair.publicKey.rawValue)
        let secondAddress = try getAddressFromPublicKey(secondKeyPair.publicKey.rawValue)
        let transaction = Transaction(
            messageBytes: Data([1, 2, 3]),
            signatures: SignaturesMap([
                (firstAddress, try transactionRuntimeSignature(9)),
                (secondAddress, nil),
            ])
        )

        let partiallySigned = try partiallySignTransaction([firstKeyPair], transaction, using: backend)

        XCTAssertNotEqual(partiallySigned.signatures.signature(for: firstAddress), transaction.signatures.signature(for: firstAddress))
        XCTAssertNotNil(partiallySigned.signatures.signature(for: firstAddress))
        XCTAssertNil(partiallySigned.signatures.signature(for: secondAddress))
        transactionRuntimeAssertThrowsSolanaError(.transactionSignaturesMissing) { error in
            XCTAssertEqual(error.context["addresses"], .stringArray([secondAddress.rawValue]))
        } body: {
            _ = try signTransaction([firstKeyPair], transaction, using: backend)
        }
    }
}

private func transactionRuntimeSizedMessage(version: TransactionVersion, dataCount: Int?) throws -> TransactionMessage {
    let feePayer = try transactionRuntimeAddress("22222222222222222222222222222222222222222222")
    let program = try transactionRuntimeAddress("33333333333333333333333333333333333333333333")
    var message = setTransactionMessageFeePayer(
        feePayer,
        setTransactionMessageLifetimeUsingBlockhash(
            BlockhashLifetimeConstraint(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 0),
            createTransactionMessage(version: version)
        )
    )
    if let dataCount {
        message = appendTransactionMessageInstruction(
            Instruction(programAddress: program, data: Data(repeating: 0, count: dataCount)),
            message
        )
    }
    return message
}

private func transactionRuntimeSignature(_ byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private func transactionRuntimeAddress(_ value: String) throws -> Address {
    try address(value)
}

private func transactionRuntimeAssertThrowsCode(
    _ code: SolanaErrorCode,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () throws -> Void
) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
        guard let coded = error as? any SolanaErrorCoded else {
            return XCTFail("Expected SolanaErrorCoded: \(error)", file: file, line: line)
        }
        XCTAssertEqual(coded.code, code.rawValue, file: file, line: line)
    }
}

private func transactionRuntimeAssertThrowsSolanaError(
    _ code: SolanaErrorCode,
    file: StaticString = #filePath,
    line: UInt = #line,
    verify: (SolanaError) -> Void = { _ in },
    body: () throws -> Void
) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
        guard let solanaError = error as? SolanaError else {
            return XCTFail("Expected SolanaError: \(error)", file: file, line: line)
        }
        XCTAssertEqual(solanaError.code, code.rawValue, file: file, line: line)
        verify(solanaError)
    }
}
