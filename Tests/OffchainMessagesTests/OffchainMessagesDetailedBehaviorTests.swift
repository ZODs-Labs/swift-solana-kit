import Addresses
import CryptoBackend
import Foundation
import Keys
import OffchainMessages
import SolanaErrors
import XCTest

final class OffchainMessagesDetailedBehaviorTests: XCTestCase {
    func testContentPredicatesCoverUtf8ByteBoundariesAndAsciiRange() throws {
        let asciiRange = (0x20...0x7e).map { String(UnicodeScalar($0)!) }.joined()
        XCTAssertTrue(isOffchainMessageContentRestrictedAsciiOf1232BytesMax(
            OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: asciiRange)
        ))
        XCTAssertFalse(isOffchainMessageContentRestrictedAsciiOf1232BytesMax(
            OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: "\u{19}")
        ))
        XCTAssertFalse(isOffchainMessageContentRestrictedAsciiOf1232BytesMax(
            OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: "\u{7f}")
        ))

        XCTAssertTrue(isOffchainMessageContentUtf8Of1232BytesMax(
            OffchainMessageContent(format: .utf8_1232BytesMax, text: String(repeating: "😘", count: 308))
        ))
        XCTAssertTrue(isOffchainMessageContentUtf8Of1232BytesMax(
            OffchainMessageContent(format: .utf8_1232BytesMax, text: String(repeating: "€", count: 410))
        ))
        XCTAssertTrue(isOffchainMessageContentUtf8Of1232BytesMax(
            OffchainMessageContent(format: .utf8_1232BytesMax, text: String(repeating: "✌🏿", count: 176))
        ))
        XCTAssertFalse(isOffchainMessageContentUtf8Of1232BytesMax(
            OffchainMessageContent(format: .utf8_1232BytesMax, text: String(repeating: "😘", count: 309))
        ))

        XCTAssertTrue(isOffchainMessageContentUtf8Of65535BytesMax(
            OffchainMessageContent(format: .utf8_65535BytesMax, text: String(repeating: "✌🏿", count: 9_362))
        ))
        do {
            try assertIsOffchainMessageContentUtf8Of65535BytesMax(
                OffchainMessageContent(format: .utf8_65535BytesMax, text: String(repeating: "✌🏿", count: 9_363))
            )
            XCTFail("Expected length failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.offchainMessageMaximumLengthExceeded.rawValue)
            XCTAssertEqual(error.context["actualBytes"], .int(65_541))
            XCTAssertEqual(error.context["maxBytes"], .int(65_535))
        }
    }

    func testApplicationDomainCodecPreservesOffsetsAndMapsAddressErrors() throws {
        let encoder = getOffchainMessageApplicationDomainEncoder()
        let decoder = getOffchainMessageApplicationDomainDecoder()
        var buffer = Data([9, 9]) + Data(repeating: 0, count: try encoder.getSizeFromValue(offchainDetailedApplicationDomain)) + Data([8])

        let nextOffset = try encoder.write(offchainDetailedApplicationDomain, into: &buffer, at: 2)
        let (decoded, decodedOffset) = try decoder.read(buffer, at: 2)

        XCTAssertEqual(nextOffset, 34)
        XCTAssertEqual(decodedOffset, 34)
        XCTAssertEqual(Data(buffer.prefix(2)), Data([9, 9]))
        XCTAssertEqual(buffer.last, 8)
        XCTAssertEqual(decoded, offchainDetailedApplicationDomain)

        offchainDetailedAssertThrowsCode(.offchainMessageApplicationDomainStringLengthOutOfRange) {
            try assertIsOffchainMessageApplicationDomain("short")
        }
    }

    func testV0PreambleCodecPreservesOffsetsAndRejectsInvalidVersionsAndSigners() throws {
        let sample = try OffchainDetailedSample()
        let preamble = OffchainMessagePreambleV0(
            applicationDomain: offchainDetailedApplicationDomain,
            messageFormat: .utf8_1232BytesMax,
            messageLength: 11,
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerA),
                OffchainMessageSignatory(address: sample.signerB),
            ]
        )
        let encoder = getOffchainMessageV0PreambleEncoder()
        let decoder = getOffchainMessageV0PreambleDecoder()
        var buffer = Data([7, 7]) + Data(repeating: 0, count: try encoder.getSizeFromValue(preamble)) + Data([6])

        let nextOffset = try encoder.write(preamble, into: &buffer, at: 2)
        let (decoded, decodedOffset) = try decoder.read(buffer, at: 2)

        XCTAssertEqual(nextOffset, 119)
        XCTAssertEqual(decodedOffset, 119)
        XCTAssertEqual(buffer.first, 7)
        XCTAssertEqual(buffer.last, 6)
        XCTAssertEqual(decoded, preamble)

        offchainDetailedAssertThrowsCode(.offchainMessageUnexpectedVersion) {
            _ = try encoder.encode(OffchainMessagePreambleV0(
                applicationDomain: offchainDetailedApplicationDomain,
                messageFormat: .restrictedAscii1232BytesMax,
                messageLength: 1,
                requiredSignatories: [OffchainMessageSignatory(address: sample.signerA)],
                version: 1
            ))
        }
        offchainDetailedAssertThrowsCode(.offchainMessageVersionNumberNotSupported) {
            _ = try encoder.encode(OffchainMessagePreambleV0(
                applicationDomain: offchainDetailedApplicationDomain,
                messageFormat: .restrictedAscii1232BytesMax,
                messageLength: 1,
                requiredSignatories: [OffchainMessageSignatory(address: sample.signerA)],
                version: 255
            ))
        }
        offchainDetailedAssertThrowsCode(.offchainMessageNumRequiredSignersCannotBeZero) {
            _ = try encoder.encode(OffchainMessagePreambleV0(
                applicationDomain: offchainDetailedApplicationDomain,
                messageFormat: .restrictedAscii1232BytesMax,
                messageLength: 1,
                requiredSignatories: []
            ))
        }
    }

    func testV1PreambleSortsForEncodingAndRejectsMalformedSignatoryLists() throws {
        let sample = try OffchainDetailedSample()
        let preamble = OffchainMessagePreambleV1(
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerB),
                OffchainMessageSignatory(address: sample.signerA),
            ]
        )
        let encoded = try getOffchainMessageV1PreambleEncoder().encode(preamble)

        XCTAssertEqual(encoded, Data(offchainDetailedSigningDomainBytes + [0x01, 0x02]) + offchainDetailedSignerABytes + offchainDetailedSignerBBytes)

        let duplicate = Data(offchainDetailedSigningDomainBytes + [0x01, 0x02])
            + offchainDetailedSignerABytes
            + offchainDetailedSignerABytes
            + Data("Hello".utf8)
        let unsorted = Data(offchainDetailedSigningDomainBytes + [0x01, 0x02])
            + offchainDetailedSignerBBytes
            + offchainDetailedSignerABytes
            + Data("Hello".utf8)
        let zeroSigners = Data(offchainDetailedSigningDomainBytes + [0x01, 0x00]) + Data("Hello".utf8)

        offchainDetailedAssertThrowsCode(.offchainMessageSignatoriesMustBeUnique) {
            _ = try getOffchainMessageV1Decoder().decode(duplicate, at: 0)
        }
        offchainDetailedAssertThrowsCode(.offchainMessageSignatoriesMustBeSorted) {
            _ = try getOffchainMessageV1Decoder().decode(unsorted, at: 0)
        }
        offchainDetailedAssertThrowsCode(.offchainMessageNumRequiredSignersCannotBeZero) {
            _ = try getOffchainMessageV1Decoder().decode(zeroSigners, at: 0)
        }
    }

    func testGenericMessageCodecDispatchesByVersionAndReportsUnsupportedVersions() throws {
        let sample = try OffchainDetailedSample()
        let v0Bytes = offchainDetailedV0MessageBytes(format: .restrictedAscii1232BytesMax, signers: [offchainDetailedSignerABytes])
        let v1Bytes = Data(offchainDetailedSigningDomainBytes + [0x01, 0x01])
            + offchainDetailedSignerABytes
            + Data("Hello".utf8)
        let decoder = getOffchainMessageDecoder()

        let (decodedV0, v0Offset) = try decoder.read(Data([0xff, 0xee]) + v0Bytes, at: 2)
        let (decodedV1, v1Offset) = try decoder.read(Data([0xff]) + v1Bytes, at: 1)

        XCTAssertEqual(v0Offset, v0Bytes.count + 2)
        XCTAssertEqual(v1Offset, v1Bytes.count + 1)
        XCTAssertEqual(decodedV0.version, 0)
        XCTAssertEqual(decodedV1.version, 1)

        offchainDetailedAssertThrowsCode(.offchainMessageVersionNumberNotSupported) {
            _ = try decoder.decode(Data(offchainDetailedSigningDomainBytes + [0xff]), at: 0)
        }
        offchainDetailedAssertThrowsCode(.offchainMessageUnexpectedVersion) {
            _ = try getOffchainMessageEncoder().encode(.v0(OffchainMessageV0(
                applicationDomain: offchainDetailedApplicationDomain,
                content: try offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello"),
                requiredSignatories: [OffchainMessageSignatory(address: sample.signerA)],
                version: 1
            )))
        }
        offchainDetailedAssertThrowsCode(.offchainMessageVersionNumberNotSupported) {
            _ = try getOffchainMessageEncoder().encode(.v1(OffchainMessageV1(
                content: "Hello",
                requiredSignatories: [OffchainMessageSignatory(address: sample.signerA)],
                version: 255
            )))
        }
    }

    func testV0AndV1MessagesEncodeUtf8BytesAndRejectEmptyContent() throws {
        let sample = try OffchainDetailedSample()
        let v0 = OffchainMessageV0(
            applicationDomain: offchainDetailedApplicationDomain,
            content: try offchainMessageContentUtf8Of1232BytesMax("✌🏿cool"),
            requiredSignatories: [OffchainMessageSignatory(address: sample.signerA)]
        )
        let v1 = OffchainMessageV1(
            content: "✌🏿cool",
            requiredSignatories: [OffchainMessageSignatory(address: sample.signerA)]
        )

        XCTAssertEqual(
            try getOffchainMessageV0Encoder().encode(v0).suffix(11),
            Data([0xe2, 0x9c, 0x8c, 0xf0, 0x9f, 0x8f, 0xbf, 0x63, 0x6f, 0x6f, 0x6c])
        )
        XCTAssertEqual(
            try getOffchainMessageV1Encoder().encode(v1).suffix(11),
            Data([0xe2, 0x9c, 0x8c, 0xf0, 0x9f, 0x8f, 0xbf, 0x63, 0x6f, 0x6f, 0x6c])
        )
        offchainDetailedAssertThrowsCode(.offchainMessageMessageMustBeNonEmpty) {
            _ = try getOffchainMessageV1Encoder().encode(OffchainMessageV1(
                content: "",
                requiredSignatories: [OffchainMessageSignatory(address: sample.signerA)]
            ))
        }
    }

    func testEnvelopeCodecPreservesOffsetsAndReportsMismatchContext() throws {
        let sample = try OffchainDetailedSample()
        let content = offchainDetailedV0MessageBytes(
            format: .restrictedAscii1232BytesMax,
            signers: [offchainDetailedSignerABytes, offchainDetailedSignerBBytes]
        )
        let envelope = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerB, signature: try offchainDetailedSignature(filledWith: 2)),
            OffchainMessageSignature(address: sample.signerA, signature: nil),
        ])
        let encoder = getOffchainMessageEnvelopeEncoder()
        let decoder = getOffchainMessageEnvelopeDecoder()
        var buffer = Data([0xaa]) + Data(repeating: 0, count: try encoder.getSizeFromValue(envelope)) + Data([0xbb])

        let nextOffset = try encoder.write(envelope, into: &buffer, at: 1)
        let encodedEnvelope = Data(buffer.dropFirst(1).dropLast())
        let decodeBuffer = Data([0xaa]) + encodedEnvelope
        let (decoded, decodedOffset) = try decoder.read(decodeBuffer, at: 1)

        XCTAssertEqual(nextOffset, buffer.count - 1)
        XCTAssertEqual(decodedOffset, decodeBuffer.count)
        XCTAssertEqual(buffer.first, 0xaa)
        XCTAssertEqual(buffer.last, 0xbb)
        XCTAssertEqual(decoded.signatures.map(\.address), [sample.signerA, sample.signerB])
        XCTAssertNil(decoded.signature(for: sample.signerA))
        XCTAssertEqual(decoded.signature(for: sample.signerB), try offchainDetailedSignature(filledWith: 2))

        do {
            _ = try decoder.decode(Data([0x01]) + Data(repeating: 0, count: 64) + content, at: 0)
            XCTFail("Expected signature count mismatch")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.offchainMessageNumSignaturesMismatch.rawValue)
            XCTAssertEqual(error.context["numRequiredSignatures"], .int(2))
            XCTAssertEqual(error.context["signatoryAddresses"], .stringArray([sample.signerA.rawValue, sample.signerB.rawValue]))
            XCTAssertEqual(error.context["signaturesLength"], .int(1))
        }

        do {
            _ = try encoder.encode(OffchainMessageEnvelope(content: content, signatures: [
                OffchainMessageSignature(address: sample.signerA, signature: nil),
                OffchainMessageSignature(address: sample.signerC, signature: nil),
            ]))
            XCTFail("Expected signer mismatch")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.offchainMessageEnvelopeSignersMismatch.rawValue)
            XCTAssertEqual(error.context["missingRequiredSigners"], .stringArray([sample.signerB.rawValue]))
            XCTAssertEqual(error.context["unexpectedSigners"], .stringArray([sample.signerC.rawValue]))
        }
    }

    func testSigningPredicatesAndUnexpectedSignerContextsAreComplete() throws {
        let sample = try OffchainDetailedSample()
        let backend = OffchainDetailedCryptoBackend()
        let content = offchainDetailedV0MessageBytes(
            format: .restrictedAscii1232BytesMax,
            signers: [offchainDetailedSignerABytes, offchainDetailedSignerBBytes]
        )

        XCTAssertTrue(isFullySignedOffchainMessageEnvelope(OffchainMessageEnvelope(content: content, signatures: [])))
        XCTAssertNoThrow(try assertIsFullySignedOffchainMessageEnvelope(OffchainMessageEnvelope(content: content, signatures: [])))

        let missing = OffchainMessageEnvelope(content: content, signatures: [
            OffchainMessageSignature(address: sample.signerA, signature: nil),
            OffchainMessageSignature(address: sample.signerB, signature: nil),
        ])
        do {
            try assertIsFullySignedOffchainMessageEnvelope(missing)
            XCTFail("Expected missing signatures")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.offchainMessageSignaturesMissing.rawValue)
            XCTAssertEqual(error.context["addresses"], .stringArray([sample.signerA.rawValue, sample.signerB.rawValue]))
        }

        do {
            _ = try partiallySignOffchainMessageEnvelope(
                [
                    try offchainDetailedKeyPair(privateFill: 3, publicKeyBytes: offchainDetailedSignerCBytes),
                    try offchainDetailedKeyPair(privateFill: 4, publicKeyBytes: offchainDetailedSignerDBytes),
                ],
                missing,
                using: backend
            )
            XCTFail("Expected unexpected signer failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.offchainMessageAddressesCannotSignOffchainMessage.rawValue)
            XCTAssertEqual(error.context["expectedAddresses"], .stringArray([sample.signerA.rawValue, sample.signerB.rawValue]))
            XCTAssertEqual(error.context["unexpectedAddresses"], .stringArray([sample.signerC.rawValue, sample.signerD.rawValue]))
        }
    }

    func testSignatoryComparatorOrdersLengthBeforeLexicalBytes() {
        let values = [
            Data([0, 0]),
            Data([1]),
            Data([1, 1, 0]),
            Data([0, 1, 0]),
            Data([0, 0, 0]),
            Data([1, 1, 1]),
            Data([0]),
            Data([0, 1, 1]),
            Data([0, 0, 1]),
        ]
        let sorted = values.sorted { getSignatoriesComparator()($0, $1) < 0 }

        XCTAssertEqual(sorted, [
            Data([0]),
            Data([1]),
            Data([0, 0]),
            Data([0, 0, 0]),
            Data([0, 0, 1]),
            Data([0, 1, 0]),
            Data([0, 1, 1]),
            Data([1, 1, 0]),
            Data([1, 1, 1]),
        ])
    }
}

private let offchainDetailedSigningDomainBytes: [UInt8] = [
    0xff, 0x73, 0x6f, 0x6c, 0x61, 0x6e, 0x61, 0x20,
    0x6f, 0x66, 0x66, 0x63, 0x68, 0x61, 0x69, 0x6e,
]

private let offchainDetailedApplicationDomain = "testdomain111111111111111111111111111111111"
private let offchainDetailedApplicationDomainBytes = Data([
    0x0d, 0x3b, 0x73, 0x0b, 0x9e, 0x88, 0x9b, 0x4b,
    0x66, 0x1e, 0xd2, 0xa3, 0xce, 0x19, 0x1f, 0x68,
    0xd3, 0x7d, 0xa7, 0x44, 0x32, 0x06, 0xa1, 0x82,
    0xb9, 0x46, 0x89, 0x1e, 0x00, 0x00, 0x00, 0x00,
])

private let offchainDetailedSignerABytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x55, 0x0e, 0x94,
    0xc7, 0x25, 0x63, 0x9a, 0x4b, 0xd1, 0x1d, 0x4e,
    0xa5, 0xa6, 0x38, 0x36, 0x51, 0xc3, 0x08, 0xb7,
    0x18, 0xc3, 0xae, 0xf2, 0x86, 0xbc, 0xa1, 0xaf,
])
private let offchainDetailedSignerBBytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x5c, 0x95, 0xef,
    0xb9, 0x72, 0xc0, 0xc5, 0xb7, 0xae, 0x0f, 0xd5,
    0x20, 0xd9, 0x7e, 0x94, 0x8f, 0xd8, 0xbb, 0x2c,
    0x10, 0xa1, 0x01, 0x02, 0xce, 0x98, 0xb3, 0xa6,
])
private let offchainDetailedSignerCBytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x64, 0x1d, 0x4a,
    0xab, 0xc0, 0x1d, 0xf1, 0x23, 0x8b, 0x02, 0x5b,
    0x9c, 0x0c, 0xc4, 0xf2, 0xcd, 0xee, 0x6d, 0xa1,
    0x08, 0x7e, 0x53, 0x13, 0x16, 0x74, 0xc5, 0x9d,
])
private let offchainDetailedSignerDBytes = Data(repeating: 4, count: 32)

private struct OffchainDetailedSample {
    let signerA: Address
    let signerB: Address
    let signerC: Address
    let signerD: Address

    init() throws {
        signerA = try getAddressDecoder().decode(offchainDetailedSignerABytes, at: 0)
        signerB = try getAddressDecoder().decode(offchainDetailedSignerBBytes, at: 0)
        signerC = try getAddressDecoder().decode(offchainDetailedSignerCBytes, at: 0)
        signerD = try getAddressDecoder().decode(offchainDetailedSignerDBytes, at: 0)
    }
}

private func offchainDetailedV0MessageBytes(format: OffchainMessageContentFormat, signers: [Data]) -> Data {
    Data(offchainDetailedSigningDomainBytes)
        + Data([0x00])
        + offchainDetailedApplicationDomainBytes
        + Data([format.rawValue, UInt8(signers.count)])
        + signers.reduce(Data(), +)
        + Data([0x0b, 0x00])
        + Data("Hello world".utf8)
}

private func offchainDetailedSignature(filledWith byte: UInt8) throws -> SignatureBytes {
    try SignatureBytes(Data(repeating: byte, count: 64))
}

private func offchainDetailedKeyPair(privateFill: UInt8, publicKeyBytes: Data) throws -> KeyPair {
    try KeyPair(privateKey: PrivateKey(Data(repeating: privateFill, count: 32)), publicKey: PublicKey(publicKeyBytes))
}

private func offchainDetailedAssertThrowsCode(
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

private struct OffchainDetailedCryptoBackend: CryptoBackend {
    func generateKeyPair() throws(KeysError) -> CryptoKeyPairBytes {
        CryptoKeyPairBytes(privateKey: Data(repeating: 1, count: 32), publicKey: offchainDetailedSignerABytes)
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
            return offchainDetailedSignerABytes
        case 2:
            return offchainDetailedSignerBBytes
        case 3:
            return offchainDetailedSignerCBytes
        case 4:
            return offchainDetailedSignerDBytes
        default:
            return Data(repeating: 9, count: 32)
        }
    }

    func sign(_ message: Data, privateKeyBytes: Data) throws(KeysError) -> Data {
        Data(repeating: privateKeyBytes.first ?? 0xff, count: 64)
    }

    func verify(signature: Data, message: Data, publicKeyBytes: Data) throws(KeysError) -> Bool {
        switch publicKeyBytes {
        case offchainDetailedSignerABytes:
            return signature == Data(repeating: 1, count: 64)
        case offchainDetailedSignerBBytes:
            return signature == Data(repeating: 2, count: 64)
        case offchainDetailedSignerCBytes:
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
