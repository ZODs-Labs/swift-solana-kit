import Addresses
import CryptoBackend
import Foundation
import Keys
import OffchainMessages
import SolanaErrors
import XCTest

final class OffchainMessagesTests: XCTestCase {
    func testContentAssertionsEnforceBounds() throws {
        XCTAssertNoThrow(try assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(
            OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: String(repeating: "!", count: 1232))
        ))
        XCTAssertFalse(isOffchainMessageContentRestrictedAsciiOf1232BytesMax(
            OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: "\u{7f}")
        ))
        try assertThrowsCode(SolanaErrorCode.offchainMessageRestrictedAsciiBodyCharacterOutOfRange.rawValue) {
            try assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(
                OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: "\t")
            )
        }
        try assertThrowsCode(SolanaErrorCode.offchainMessageMaximumLengthExceeded.rawValue) {
            try assertIsOffchainMessageContentUtf8Of1232BytesMax(
                OffchainMessageContent(format: .utf8_1232BytesMax, text: String(repeating: "!", count: 1233))
            )
        }
        try assertThrowsCode(SolanaErrorCode.offchainMessageMessageMustBeNonEmpty.rawValue) {
            try assertIsOffchainMessageContentUtf8Of65535BytesMax(
                OffchainMessageContent(format: .utf8_65535BytesMax, text: "")
            )
        }
        try assertThrowsCode(SolanaErrorCode.offchainMessageMessageFormatMismatch.rawValue) {
            try assertIsOffchainMessageContentUtf8Of1232BytesMax(
                OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: "Hello")
            )
        }
    }

    func testV0CodecEncodesAndDecodesRestrictedAsciiMessageBytes() throws {
        let sample = try OffchainSample()
        let message = try OffchainMessageV0(
            applicationDomain: applicationDomain,
            content: offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello world"),
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerA),
                OffchainMessageSignatory(address: sample.signerB),
            ]
        )

        let encoded = try getOffchainMessageV0Encoder().encode(message)
        XCTAssertEqual(encoded, v0HelloWorldMessageBytes(format: .restrictedAscii1232BytesMax, signers: [signerABytes, signerBBytes]))

        let decoded = try getOffchainMessageV0Decoder().decode(encoded, at: 0)
        XCTAssertEqual(decoded.applicationDomain, applicationDomain)
        XCTAssertEqual(decoded.content, message.content)
        XCTAssertEqual(decoded.requiredSignatories, message.requiredSignatories)
        XCTAssertEqual(decoded.version, 0)
    }

    func testV0DecoderThrowsForLengthAndRestrictedAsciiFailures() throws {
        var malformed = v0HelloWorldMessageBytes(format: .restrictedAscii1232BytesMax, signers: [signerABytes, signerBBytes])
        malformed[malformed.count - 1] = 0x21
        malformed.append(0x21)
        try assertThrowsCode(SolanaErrorCode.offchainMessageMessageLengthMismatch.rawValue) {
            _ = try getOffchainMessageV0Decoder().decode(malformed, at: 0)
        }

        let tabMessage = Data(signingDomainBytes + [0x00] + applicationDomainBytes + [0x00, 0x02])
            + signerABytes
            + signerBBytes
            + Data([0x01, 0x00, 0x09])
        try assertThrowsCode(SolanaErrorCode.offchainMessageRestrictedAsciiBodyCharacterOutOfRange.rawValue) {
            _ = try getOffchainMessageV0Decoder().decode(tabMessage, at: 0)
        }
    }

    func testV1CodecSortsSignatoriesAndRejectsDuplicates() throws {
        let sample = try OffchainSample()
        let message = OffchainMessageV1(
            content: "Hello\nworld",
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerB),
                OffchainMessageSignatory(address: sample.signerA),
            ]
        )

        let encoded = try getOffchainMessageV1Encoder().encode(message)
        XCTAssertEqual(encoded, Data(signingDomainBytes + [0x01, 0x02]) + signerABytes + signerBBytes + Data("Hello\nworld".utf8))

        let decoded = try getOffchainMessageV1Decoder().decode(encoded, at: 0)
        XCTAssertEqual(decoded.requiredSignatories.map(\.address), [sample.signerA, sample.signerB])

        let duplicate = OffchainMessageV1(
            content: "Hello\nworld",
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerA),
                OffchainMessageSignatory(address: sample.signerA),
            ]
        )
        try assertThrowsCode(SolanaErrorCode.offchainMessageSignatoriesMustBeUnique.rawValue) {
            _ = try getOffchainMessageV1Encoder().encode(duplicate)
        }
    }

    func testV1DecoderRemovesNullCharactersAndReplacesInvalidUtf8() throws {
        let encoded = Data(signingDomainBytes + [0x01, 0x01])
            + signerABytes
            + Data([0x48, 0x00, 0xc3, 0x28, 0x69])

        let decoded = try getOffchainMessageV1Decoder().decode(encoded, at: 0)

        XCTAssertEqual(decoded.content, "H\u{fffd}(i")
    }

    func testEnvelopeCodecOrdersSignaturesByMessagePreamble() throws {
        let sample = try OffchainSample()
        let content = v0HelloWorldMessageBytes(format: .restrictedAscii1232BytesMax, signers: [signerABytes, signerBBytes])
        let envelope = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerB, signature: try signature(filledWith: 2)),
            OffchainMessageSignature(address: sample.signerA, signature: nil),
        ])

        let encoded = try getOffchainMessageEnvelopeEncoder().encode(envelope)
        XCTAssertEqual(encoded, Data([0x02]) + Data(repeating: 0, count: 64) + Data(repeating: 2, count: 64) + content)

        let decoded = try getOffchainMessageEnvelopeDecoder().decode(encoded, at: 0)
        XCTAssertEqual(decoded.signatures.map(\.address), [sample.signerA, sample.signerB])
        XCTAssertNil(decoded.signature(for: sample.signerA))
        XCTAssertEqual(decoded.signature(for: sample.signerB), try signature(filledWith: 2))
    }

    func testEnvelopeSignaturesByAddressUsesLastDuplicateEntry() throws {
        let sample = try OffchainSample()
        let envelope = OffchainMessageEnvelope(content: Data([1, 2, 3]), signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: nil),
            OffchainMessageSignature(address: sample.signerB, signature: nil),
            OffchainMessageSignature(address: sample.signerA, signature: try signature(filledWith: 1)),
            OffchainMessageSignature(address: sample.signerA, signature: try signature(filledWith: 2)),
        ])

        let signaturesByAddress = envelope.signaturesByAddress

        XCTAssertEqual(signaturesByAddress.count, 2)
        XCTAssertEqual(signaturesByAddress[sample.signerA]!, try signature(filledWith: 2))
        XCTAssertEqual(envelope.signature(for: sample.signerA), try signature(filledWith: 2))
        XCTAssertNil(signaturesByAddress[sample.signerB]!)
    }

    func testEnvelopeEncoderCollapsesDuplicateSignatoryAddressesUsingMapSemantics() throws {
        let sample = try OffchainSample()
        let content = v0HelloWorldMessageBytes(
            format: .restrictedAscii1232BytesMax,
            signers: [signerABytes, signerABytes, signerBBytes]
        )
        let envelope = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: nil),
            OffchainMessageSignature(address: sample.signerB, signature: try signature(filledWith: 2)),
            OffchainMessageSignature(address: sample.signerA, signature: try signature(filledWith: 1)),
        ])

        let encoded = try getOffchainMessageEnvelopeEncoder().encode(envelope)

        XCTAssertEqual(
            encoded,
            Data([0x02]) + Data(repeating: 1, count: 64) + Data(repeating: 2, count: 64) + content
        )
    }

    func testEnvelopeCodecRejectsSignerMismatchAndSignatureCountMismatch() throws {
        let sample = try OffchainSample()
        let content = v0HelloWorldMessageBytes(format: .restrictedAscii1232BytesMax, signers: [signerABytes, signerBBytes])
        let mismatch = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: nil),
            OffchainMessageSignature(address: sample.signerC, signature: nil),
        ])
        try assertThrowsCode(SolanaErrorCode.offchainMessageEnvelopeSignersMismatch.rawValue) {
            _ = try getOffchainMessageEnvelopeEncoder().encode(mismatch)
        }

        let encodedWithOneSignature = Data([0x01]) + Data(repeating: 0, count: 64) + content
        try assertThrowsCode(SolanaErrorCode.offchainMessageNumSignaturesMismatch.rawValue) {
            _ = try getOffchainMessageEnvelopeDecoder().decode(encodedWithOneSignature, at: 0)
        }
    }

    func testCompileAndSignOffchainEnvelope() throws {
        let sample = try OffchainSample()
        let backend = TestCryptoBackend()
        let message = try OffchainMessageV0(
            applicationDomain: applicationDomain,
            content: offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello world"),
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerA),
                OffchainMessageSignatory(address: sample.signerB),
            ]
        )
        let envelope = try compileOffchainMessageV0Envelope(message)
        XCTAssertEqual(envelope.signatures.map(\.address), [sample.signerA, sample.signerB])
        XCTAssertFalse(isFullySignedOffchainMessageEnvelope(envelope))

        let partiallySigned = try partiallySignOffchainMessageEnvelope(
            [try keyPair(privateFill: 1, publicKeyBytes: signerABytes)],
            envelope,
            using: backend
        )
        XCTAssertEqual(partiallySigned.signature(for: sample.signerA), try signature(filledWith: 1))
        XCTAssertNil(partiallySigned.signature(for: sample.signerB))

        try assertThrowsCode(SolanaErrorCode.offchainMessageSignaturesMissing.rawValue) {
            _ = try signOffchainMessageEnvelope(
                [try keyPair(privateFill: 1, publicKeyBytes: signerABytes)],
                envelope,
                using: backend
            )
        }

        let signed = try signOffchainMessageEnvelope(
            [
                try keyPair(privateFill: 2, publicKeyBytes: signerBBytes),
                try keyPair(privateFill: 1, publicKeyBytes: signerABytes),
            ],
            envelope,
            using: backend
        )
        XCTAssertEqual(signed.signatures.map(\.address), [sample.signerA, sample.signerB])
        XCTAssertTrue(isFullySignedOffchainMessageEnvelope(signed))
        XCTAssertNoThrow(try verifyOffchainMessageEnvelope(signed, using: backend))
    }

    func testPartialSigningPreservesExistingEnvelopeSignatureOrder() throws {
        let sample = try OffchainSample()
        let backend = TestCryptoBackend()
        let message = OffchainMessageV1(
            content: "Hello world",
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerB),
                OffchainMessageSignatory(address: sample.signerA),
            ]
        )
        let envelope = try compileOffchainMessageV1Envelope(message)
        XCTAssertEqual(envelope.signatures.map(\.address), [sample.signerB, sample.signerA])

        let signed = try partiallySignOffchainMessageEnvelope(
            [
                try keyPair(privateFill: 1, publicKeyBytes: signerABytes),
                try keyPair(privateFill: 2, publicKeyBytes: signerBBytes),
            ],
            envelope,
            using: backend
        )

        XCTAssertEqual(signed.signatures.map(\.address), [sample.signerB, sample.signerA])
        XCTAssertEqual(signed.signature(for: sample.signerA), try signature(filledWith: 1))
        XCTAssertEqual(signed.signature(for: sample.signerB), try signature(filledWith: 2))
    }

    func testPartialSigningAddsOnlyNewlySignedMissingEntries() throws {
        let sample = try OffchainSample()
        let backend = TestCryptoBackend()
        let content = v0HelloWorldMessageBytes(
            format: .restrictedAscii1232BytesMax,
            signers: [signerABytes, signerBBytes, signerCBytes]
        )
        let envelope = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: nil),
        ])

        let signed = try partiallySignOffchainMessageEnvelope(
            [try keyPair(privateFill: 2, publicKeyBytes: signerBBytes)],
            envelope,
            using: backend
        )

        XCTAssertEqual(signed.signatures.map(\.address), [sample.signerA, sample.signerB])
        XCTAssertNil(signed.signature(for: sample.signerA))
        XCTAssertEqual(signed.signature(for: sample.signerB), try signature(filledWith: 2))
    }

    func testSigningRejectsUnexpectedAddressesAndVerificationReportsMissingAndInvalid() throws {
        let sample = try OffchainSample()
        let backend = TestCryptoBackend()
        let content = v0HelloWorldMessageBytes(
            format: .restrictedAscii1232BytesMax,
            signers: [signerABytes, signerBBytes, signerCBytes]
        )
        let envelope = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: nil),
        ])
        try assertThrowsCode(SolanaErrorCode.offchainMessageAddressesCannotSignOffchainMessage.rawValue) {
            _ = try partiallySignOffchainMessageEnvelope(
                [try keyPair(privateFill: 4, publicKeyBytes: signerDBytes)],
                envelope,
                using: backend
            )
        }

        let invalidEnvelope = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: try signature(filledWith: 9)),
            OffchainMessageSignature(address: sample.signerC, signature: nil),
        ])
        try assertThrowsCode(SolanaErrorCode.offchainMessageSignatureVerificationFailure.rawValue) {
            try verifyOffchainMessageEnvelope(invalidEnvelope, using: backend)
        }
    }

    func testVerificationFailureContextOnlyIncludesObservedFailureKinds() throws {
        let sample = try OffchainSample()
        let backend = TestCryptoBackend()
        let content = v0HelloWorldMessageBytes(format: .restrictedAscii1232BytesMax, signers: [signerABytes, signerBBytes])
        let missingOnlyEnvelope = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: try signature(filledWith: 1)),
            OffchainMessageSignature(address: sample.signerB, signature: nil),
        ])

        do {
            try verifyOffchainMessageEnvelope(missingOnlyEnvelope, using: backend)
            XCTFail("Expected verification failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.solanaCode, .offchainMessageSignatureVerificationFailure)
            XCTAssertEqual(error.context.values["signatoriesWithMissingSignatures"], .stringArray([sample.signerB.rawValue]))
            XCTAssertNil(error.context.values["signatoriesWithInvalidSignatures"])
        }
    }
}

private let signingDomainBytes: [UInt8] = [
    0xff, 0x73, 0x6f, 0x6c, 0x61, 0x6e, 0x61, 0x20,
    0x6f, 0x66, 0x66, 0x63, 0x68, 0x61, 0x69, 0x6e,
]

private let applicationDomain = "testdomain111111111111111111111111111111111"
private let applicationDomainBytes = Data([
    0x0d, 0x3b, 0x73, 0x0b, 0x9e, 0x88, 0x9b, 0x4b,
    0x66, 0x1e, 0xd2, 0xa3, 0xce, 0x19, 0x1f, 0x68,
    0xd3, 0x7d, 0xa7, 0x44, 0x32, 0x06, 0xa1, 0x82,
    0xb9, 0x46, 0x89, 0x1e, 0x00, 0x00, 0x00, 0x00,
])

private let signerABytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x55, 0x0e, 0x94,
    0xc7, 0x25, 0x63, 0x9a, 0x4b, 0xd1, 0x1d, 0x4e,
    0xa5, 0xa6, 0x38, 0x36, 0x51, 0xc3, 0x08, 0xb7,
    0x18, 0xc3, 0xae, 0xf2, 0x86, 0xbc, 0xa1, 0xaf,
])
private let signerBBytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x5c, 0x95, 0xef,
    0xb9, 0x72, 0xc0, 0xc5, 0xb7, 0xae, 0x0f, 0xd5,
    0x20, 0xd9, 0x7e, 0x94, 0x8f, 0xd8, 0xbb, 0x2c,
    0x10, 0xa1, 0x01, 0x02, 0xce, 0x98, 0xb3, 0xa6,
])
private let signerCBytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x64, 0x1d, 0x4a,
    0xab, 0xc0, 0x1d, 0xf1, 0x23, 0x8b, 0x02, 0x5b,
    0x9c, 0x0c, 0xc4, 0xf2, 0xcd, 0xee, 0x6d, 0xa1,
    0x08, 0x7e, 0x53, 0x13, 0x16, 0x74, 0xc5, 0x9d,
])
private let signerDBytes = Data(repeating: 4, count: 32)

private struct OffchainSample {
    let signerA: Address
    let signerB: Address
    let signerC: Address

    init() throws {
        signerA = try getAddressDecoder().decode(signerABytes, at: 0)
        signerB = try getAddressDecoder().decode(signerBBytes, at: 0)
        signerC = try getAddressDecoder().decode(signerCBytes, at: 0)
    }
}

private func v0HelloWorldMessageBytes(format: OffchainMessageContentFormat, signers: [Data]) -> Data {
    Data(signingDomainBytes)
        + Data([0x00])
        + applicationDomainBytes
        + Data([format.rawValue, UInt8(signers.count)])
        + signers.reduce(Data(), +)
        + Data([0x0b, 0x00])
        + Data("Hello world".utf8)
}

private func signature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private func keyPair(privateFill: UInt8, publicKeyBytes: Data) throws -> KeyPair {
    try KeyPair(privateKey: PrivateKey(Data(repeating: privateFill, count: 32)), publicKey: PublicKey(publicKeyBytes))
}

private func assertThrowsCode(_ code: Int, _ body: () throws -> Void) throws {
    do {
        try body()
        XCTFail("Expected error code \(code)")
    } catch let error as any SolanaErrorCoded {
        XCTAssertEqual(error.code, code)
    } catch {
        XCTFail("Expected SolanaErrorCoded, got \(error)")
    }
}

private struct TestCryptoBackend: CryptoBackend {
    func generateKeyPair() throws(KeysError) -> CryptoKeyPairBytes {
        CryptoKeyPairBytes(privateKey: Data(repeating: 1, count: 32), publicKey: signerABytes)
    }

    func createKeyPair(privateKeyBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        CryptoKeyPairBytes(privateKey: privateKeyBytes, publicKey: try publicKey(privateKeyBytes: privateKeyBytes))
    }

    func createKeyPair(solanaKeyPairBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        CryptoKeyPairBytes(privateKey: solanaKeyPairBytes.prefix(32), publicKey: solanaKeyPairBytes.suffix(32))
    }

    func publicKey(privateKeyBytes: Data) throws(KeysError) -> Data {
        switch privateKeyBytes.first {
        case 1:
            return signerABytes
        case 2:
            return signerBBytes
        case 3:
            return signerCBytes
        case 4:
            return signerDBytes
        default:
            return Data(repeating: 9, count: 32)
        }
    }

    func sign(_ message: Data, privateKeyBytes: Data) throws(KeysError) -> Data {
        Data(repeating: privateKeyBytes.first ?? 0xff, count: 64)
    }

    func verify(signature: Data, message: Data, publicKeyBytes: Data) throws(KeysError) -> Bool {
        switch publicKeyBytes {
        case signerABytes:
            return signature == Data(repeating: 1, count: 64)
        case signerBBytes:
            return signature == Data(repeating: 2, count: 64)
        case signerCBytes:
            return signature == Data(repeating: 3, count: 64)
        default:
            return false
        }
    }

    func sha256(_ data: Data) -> Data {
        data
    }

    func isOnCurve(_ compressedEdwardsY: Data) -> Bool {
        true
    }
}
