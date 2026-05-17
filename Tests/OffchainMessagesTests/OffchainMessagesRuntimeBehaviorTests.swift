import Addresses
import Foundation
import Keys
import OffchainMessages
import SolanaErrors
import XCTest

final class OffchainMessagesRuntimeBehaviorTests: XCTestCase {
    func testContentValidatorsReportExactFormatsAndUtf8ByteLengths() throws {
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageMessageFormatMismatch) { error in
            XCTAssertEqual(error.context["actualMessageFormat"], .int(1))
            XCTAssertEqual(error.context["expectedMessageFormat"], .int(0))
        } body: {
            try assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(
                OffchainMessageContent(format: .utf8_1232BytesMax, text: "Hello world")
            )
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageMessageFormatMismatch) { error in
            XCTAssertEqual(error.context["actualMessageFormat"], .int(0))
            XCTAssertEqual(error.context["expectedMessageFormat"], .int(1))
        } body: {
            try assertIsOffchainMessageContentUtf8Of1232BytesMax(
                OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: "Hello world")
            )
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageMessageFormatMismatch) { error in
            XCTAssertEqual(error.context["actualMessageFormat"], .int(1))
            XCTAssertEqual(error.context["expectedMessageFormat"], .int(2))
        } body: {
            try assertIsOffchainMessageContentUtf8Of65535BytesMax(
                OffchainMessageContent(format: .utf8_1232BytesMax, text: "Hello world")
            )
        }

        let over1232 = [
            (String(repeating: "!", count: 1_233), 1_233),
            (String(repeating: "😘", count: 309), 1_236),
            (String(repeating: "€", count: 411), 1_233),
            (String(repeating: "✌🏿", count: 177), 1_239),
        ]
        for (text, byteCount) in over1232 {
            offchainRuntimeAssertThrowsSolanaError(.offchainMessageMaximumLengthExceeded) { error in
                XCTAssertEqual(error.context["actualBytes"], .int(byteCount))
                XCTAssertEqual(error.context["maxBytes"], .int(1_232))
            } body: {
                try assertIsOffchainMessageContentUtf8Of1232BytesMax(
                    OffchainMessageContent(format: .utf8_1232BytesMax, text: text)
                )
            }
        }

        let over65535 = [
            (String(repeating: "!", count: 65_536), 65_536),
            (String(repeating: "😘", count: 16_384), 65_536),
            (String(repeating: "€", count: 21_846), 65_538),
            (String(repeating: "✌🏿", count: 9_363), 65_541),
        ]
        for (text, byteCount) in over65535 {
            offchainRuntimeAssertThrowsSolanaError(.offchainMessageMaximumLengthExceeded) { error in
                XCTAssertEqual(error.context["actualBytes"], .int(byteCount))
                XCTAssertEqual(error.context["maxBytes"], .int(65_535))
            } body: {
                try assertIsOffchainMessageContentUtf8Of65535BytesMax(
                    OffchainMessageContent(format: .utf8_65535BytesMax, text: text)
                )
            }
        }
    }

    func testApplicationDomainValidationMapsAddressFailures() throws {
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageApplicationDomainStringLengthOutOfRange) { error in
            XCTAssertEqual(error.context["actualLength"], .int(31))
        } body: {
            try assertIsOffchainMessageApplicationDomain(String(repeating: "1", count: 31))
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageApplicationDomainStringLengthOutOfRange) { error in
            XCTAssertEqual(error.context["actualLength"], .int(45))
        } body: {
            try assertIsOffchainMessageApplicationDomain(String(repeating: "1", count: 45))
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageInvalidApplicationDomainByteLength) { error in
            XCTAssertEqual(error.context["actualLength"], .int(31))
        } body: {
            try assertIsOffchainMessageApplicationDomain("tVojvhToWjQ8Xvo4UPx2Xz9eRy7auyYMmZBjc2XfN")
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageInvalidApplicationDomainByteLength) { error in
            XCTAssertEqual(error.context["actualLength"], .int(33))
        } body: {
            try assertIsOffchainMessageApplicationDomain("JJEfe6DcPM2ziB2vfUWDV6aHVerXRGkv3TcyvJUNGHZz")
        }
        offchainRuntimeAssertThrowsCode(.codecsInvalidStringForBase) {
            try assertIsOffchainMessageApplicationDomain(String(repeating: "0", count: 32))
        }
    }

    func testSigningDomainDecodersRejectMalformedBytesAtOffsets() throws {
        let reversedDomain = Data(offchainRuntimeSigningDomainBytes.reversed())
        offchainRuntimeAssertThrowsCode(.codecsInvalidConstant) {
            _ = try getOffchainMessageSigningDomainDecoder().decode(reversedDomain, at: 0)
        }
        offchainRuntimeAssertThrowsCode(.codecsInvalidConstant) {
            _ = try getOffchainMessageSigningDomainDecoder().decode(Data(offchainRuntimeSigningDomainBytes.dropLast()), at: 0)
        }

        let padded = Data([0xaa, 0xbb]) + Data(offchainRuntimeSigningDomainBytes) + Data([0xcc])
        let (_, nextOffset) = try getOffchainMessageSigningDomainDecoder().read(padded, at: 2)
        XCTAssertEqual(nextOffset, 18)
    }

    func testEnvelopeCodecRejectsZeroSignaturesAndUnsupportedVersionsWithContext() throws {
        let sample = try OffchainRuntimeSample()
        let messageBytes = offchainRuntimeV0MessageBytes(signers: [offchainRuntimeSignerABytes, offchainRuntimeSignerBBytes])
        let unsupportedContent = Data(offchainRuntimeSigningDomainBytes + [0xff])

        offchainRuntimeAssertThrowsSolanaError(.offchainMessageNumEnvelopeSignaturesCannotBeZero) { _ in } body: {
            _ = try getOffchainMessageEnvelopeEncoder().encode(
                OffchainMessageEnvelope(content: messageBytes, signatures: [])
            )
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageNumEnvelopeSignaturesCannotBeZero) { _ in } body: {
            _ = try getOffchainMessageEnvelopeDecoder().decode(Data([0x00]) + messageBytes, at: 0)
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageVersionNumberNotSupported) { error in
            XCTAssertEqual(error.context["unsupportedVersion"], .int(255))
        } body: {
            _ = try getOffchainMessageEnvelopeEncoder().encode(
                OffchainMessageEnvelope(
                    content: unsupportedContent,
                    signatures: [OffchainMessageSignature(address: sample.signerA, signature: nil)]
                )
            )
        }
        offchainRuntimeAssertThrowsSolanaError(.offchainMessageVersionNumberNotSupported) { error in
            XCTAssertEqual(error.context["unsupportedVersion"], .int(255))
        } body: {
            _ = try getOffchainMessageEnvelopeDecoder().decode(
                Data([0x01]) + Data(repeating: 0, count: 64) + unsupportedContent,
                at: 0
            )
        }
    }

    func testCompileEnvelopeDeduplicatesSignaturesAndKeepsMessageSignatories() throws {
        let sample = try OffchainRuntimeSample()
        let message = OffchainMessageV0(
            applicationDomain: offchainRuntimeApplicationDomain,
            content: try offchainMessageContentRestrictedAsciiOf1232BytesMax("Hello world"),
            requiredSignatories: [
                OffchainMessageSignatory(address: sample.signerA),
                OffchainMessageSignatory(address: sample.signerA),
                OffchainMessageSignatory(address: sample.signerB),
            ]
        )

        let envelope = try compileOffchainMessageV0Envelope(message)
        let decoded = try getOffchainMessageV0Decoder().decode(envelope.content, at: 0)

        XCTAssertEqual(envelope.signatures.map(\.address), [sample.signerA, sample.signerB])
        XCTAssertEqual(decoded.requiredSignatories.map(\.address), [sample.signerA, sample.signerA, sample.signerB])
    }
}

private let offchainRuntimeSigningDomainBytes: [UInt8] = [
    0xff, 0x73, 0x6f, 0x6c, 0x61, 0x6e, 0x61, 0x20,
    0x6f, 0x66, 0x66, 0x63, 0x68, 0x61, 0x69, 0x6e,
]

private let offchainRuntimeApplicationDomain = "testdomain111111111111111111111111111111111"
private let offchainRuntimeApplicationDomainBytes = Data([
    0x0d, 0x3b, 0x73, 0x0b, 0x9e, 0x88, 0x9b, 0x4b,
    0x66, 0x1e, 0xd2, 0xa3, 0xce, 0x19, 0x1f, 0x68,
    0xd3, 0x7d, 0xa7, 0x44, 0x32, 0x06, 0xa1, 0x82,
    0xb9, 0x46, 0x89, 0x1e, 0x00, 0x00, 0x00, 0x00,
])

private let offchainRuntimeSignerABytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x55, 0x0e, 0x94,
    0xc7, 0x25, 0x63, 0x9a, 0x4b, 0xd1, 0x1d, 0x4e,
    0xa5, 0xa6, 0x38, 0x36, 0x51, 0xc3, 0x08, 0xb7,
    0x18, 0xc3, 0xae, 0xf2, 0x86, 0xbc, 0xa1, 0xaf,
])

private let offchainRuntimeSignerBBytes = Data([
    0x0c, 0xfe, 0x2c, 0xc9, 0x52, 0x5c, 0x95, 0xef,
    0xb9, 0x72, 0xc0, 0xc5, 0xb7, 0xae, 0x0f, 0xd5,
    0x20, 0xd9, 0x7e, 0x94, 0x8f, 0xd8, 0xbb, 0x2c,
    0x10, 0xa1, 0x01, 0x02, 0xce, 0x98, 0xb3, 0xa6,
])

private struct OffchainRuntimeSample {
    let signerA: Address
    let signerB: Address

    init() throws {
        signerA = try getAddressDecoder().decode(offchainRuntimeSignerABytes, at: 0)
        signerB = try getAddressDecoder().decode(offchainRuntimeSignerBBytes, at: 0)
    }
}

private func offchainRuntimeV0MessageBytes(signers: [Data]) -> Data {
    Data(offchainRuntimeSigningDomainBytes)
        + Data([0x00])
        + offchainRuntimeApplicationDomainBytes
        + Data([OffchainMessageContentFormat.restrictedAscii1232BytesMax.rawValue, UInt8(signers.count)])
        + signers.reduce(Data(), +)
        + Data([0x0b, 0x00])
        + Data("Hello world".utf8)
}

private func offchainRuntimeAssertThrowsCode(
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

private func offchainRuntimeAssertThrowsSolanaError(
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
