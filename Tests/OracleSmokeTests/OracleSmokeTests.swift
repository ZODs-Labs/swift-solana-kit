import CodecsCore
import CryptoBackend
import CryptoKitBackend
import Curve25519Math
import Foundation
import Keys
import SolanaErrors
import XCTest

final class OracleSmokeTests: XCTestCase {
    func testSolanaErrorFixtureParity() throws {
        let document: OracleDocument = try OracleFixtures.load("errors.generated.json")
        XCTAssertEqual(document.pinnedReference, OracleFixtures.pin)
        XCTAssertEqual(document.kind, "solanaErrors")
        XCTAssertEqual(document.cases.count, 308)

        for fixture in document.cases {
            let code = try XCTUnwrap(fixture.code)
            let message = try XCTUnwrap(fixture.message)
            XCTAssertEqual(
                solanaErrorMessage(code: SolanaErrorCode(rawValue: code)),
                message
            )
        }
    }

    func testCodecsCoreFixtureParity() throws {
        let document: OracleDocument = try OracleFixtures.load("codecs-core.generated.json")
        XCTAssertEqual(document.pinnedReference, OracleFixtures.pin)
        XCTAssertEqual(document.kind, "codecsCore")

        for fixture in document.cases {
            switch fixture.operation {
            case "mergeBytes":
                let input = try XCTUnwrap(fixture.inputHex).map(Data.init(hex:))
                XCTAssertEqual(mergeBytes(input).hex, try XCTUnwrap(fixture.expectedHex))
            case "padBytes":
                XCTAssertEqual(
                    try padBytes(Data(hex: fixture.requiredInputHex()), length: fixture.requiredLength()).hex,
                    try XCTUnwrap(fixture.expectedHex)
                )
            case "fixBytes":
                XCTAssertEqual(
                    try fixBytes(Data(hex: fixture.requiredInputHex()), length: fixture.requiredLength()).hex,
                    try XCTUnwrap(fixture.expectedHex)
                )
            case "reverseEncoderWrite":
                let encoder = createEncoder(fixedSize: 2) { (_: Int, bytes: inout Data, offset: Offset) in
                    bytes[offset] = UInt8(offset)
                    bytes[offset + 1] = UInt8(offset + 1)
                    return offset + 2
                }
                var bytes = try Data(hex: fixture.requiredBytesHex())
                let offset = try reverseEncoder(encoder).write(0, into: &bytes, at: fixture.requiredOffset())
                XCTAssertEqual(bytes.hex, try XCTUnwrap(fixture.expectedHex))
                XCTAssertEqual(offset, try fixture.requiredExpectedOffset())
            case "reverseDecoderRead":
                let decoder = createDecoder(fixedSize: 2) { bytes, offset in
                    (Data(bytes[offset ..< offset + 2]), offset + 10)
                }
                let (value, offset) = try reverseDecoder(decoder).read(
                    Data(hex: fixture.requiredInputHex()),
                    at: fixture.requiredOffset()
                )
                XCTAssertEqual(value.hex, try XCTUnwrap(fixture.expectedHex))
                XCTAssertEqual(offset, try fixture.requiredExpectedOffset())
            case "bytesEqual":
                XCTAssertEqual(
                    try bytesEqual(Data(hex: fixture.requiredLeftHex()), Data(hex: fixture.requiredRightHex())),
                    try XCTUnwrap(fixture.expectedBool)
                )
            case "containsBytes":
                XCTAssertEqual(
                    try containsBytes(
                        Data(hex: fixture.requiredDataHex()),
                        Data(hex: fixture.requiredNeedleHex()),
                        at: fixture.requiredOffset()
                    ),
                    try XCTUnwrap(fixture.expectedBool)
                )
            case "toArrayBuffer":
                XCTAssertEqual(
                    try toArrayBuffer(
                        Data(hex: fixture.requiredInputHex()),
                        offset: fixture.requiredOffset(),
                        length: fixture.length
                    ).hex,
                    try XCTUnwrap(fixture.expectedHex)
                )
            case "sentinelEncode":
                let codec = try payloadCodec(payload: Data(hex: fixture.requiredPayloadHex()))
                let encoded = try addCodecSentinel(codec, sentinel: Data(hex: fixture.requiredSentinelHex())).encode("value")
                XCTAssertEqual(encoded.hex, try XCTUnwrap(fixture.expectedHex))
            case "sentinelDecode":
                let codec = passthroughStringCodec()
                let decoded = try addCodecSentinel(codec, sentinel: Data(hex: fixture.requiredSentinelHex()))
                    .decode(Data(hex: fixture.requiredInputHex()))
                XCTAssertEqual(decoded, try XCTUnwrap(fixture.expectedValue))
            case "sentinelEncodeError":
                let codec = try payloadCodec(payload: Data(hex: fixture.requiredPayloadHex()))
                XCTAssertEqual(
                    throwingCode { _ = try addCodecSentinel(codec, sentinel: Data(hex: fixture.requiredSentinelHex())).encode("value") },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "sentinelDecodeError":
                let codec = passthroughStringCodec()
                XCTAssertEqual(
                    throwingCode { _ = try addCodecSentinel(codec, sentinel: Data(hex: fixture.requiredSentinelHex())).decode(Data(hex: fixture.requiredInputHex())) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "fixCodecSizeEncode":
                let codec = try payloadCodec(payload: Data(hex: fixture.requiredPayloadHex()))
                let encoded = try fixCodecSize(codec, fixedBytes: fixture.requiredFixedBytes()).encode("value")
                XCTAssertEqual(encoded.hex, try XCTUnwrap(fixture.expectedHex))
            case "fixCodecSizeDecodeError":
                let decoder = passthroughStringCodec()
                XCTAssertEqual(
                    throwingCode { _ = try fixCodecSize(decoder, fixedBytes: fixture.requiredFixedBytes()).decode(Data(hex: fixture.requiredInputHex())) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "sizePrefixDecodeError":
                let decoder = passthroughStringCodec()
                let prefix = createDecoder(fixedSize: 0) { (_: Data, _: Offset) in
                    try (fixture.requiredLength(), fixture.requiredOffset())
                }
                let prefixed = addDecoderSizePrefix(decoder, prefix: prefix)
                XCTAssertEqual(
                    throwingCode { _ = try prefixed.decode(Data(hex: fixture.requiredInputHex())) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "sizePrefixVariablePrefix":
                let codec = addCodecSizePrefix(oracleU16Codec(), prefix: oracleVariableSizePrefixCodec())
                XCTAssertTrue(isVariableSize(codec))
                XCTAssertEqual(try codec.getSizeFromValue(0x1234), try fixture.requiredLength())
                XCTAssertEqual(try codec.encode(0x1234).hex, try XCTUnwrap(fixture.expectedHex))
                let (value, offset) = try codec.read(Data(hex: fixture.requiredInputHex()), at: 0)
                XCTAssertEqual(value, 0x1234)
                XCTAssertEqual(offset, try fixture.requiredExpectedOffset())
            case "offsetPreError":
                let encoder = createEncoder(fixedSize: 1) { (_: Int, bytes: inout Data, offset: Offset) in
                    bytes[offset] = 1
                    return offset + 1
                }
                let offsetEncoder = offsetEncoder(encoder, config: OffsetConfig(preOffset: { _ in fixture.offset ?? 0 }))
                XCTAssertEqual(
                    throwingCode {
                        var bytes = try Data(count: Data(hex: fixture.requiredBytesHex()).count)
                        _ = try offsetEncoder.write(1, into: &bytes, at: 0)
                    },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "consumeEntireError":
                let decoder = createDecoder { (_: Data, offset: Offset) in
                    ("value", offset + (fixture.decoderConsumes ?? 0))
                }
                let consuming = createDecoderThatConsumesEntireByteArray(decoder)
                XCTAssertEqual(
                    throwingCode { _ = try consuming.decode(Data(hex: fixture.requiredBytesHex())) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            default:
                XCTFail("Unhandled fixture operation \(fixture.operation)")
            }
        }
    }

    func testKeysCryptoFixtureParity() throws {
        let document: OracleDocument = try OracleFixtures.load("keys-crypto.generated.json")
        XCTAssertEqual(document.pinnedReference, OracleFixtures.pin)
        XCTAssertEqual(document.kind, "keysCrypto")
        let backend = CryptoKitBackend()

        for fixture in document.cases {
            switch fixture.operation {
            case "createKeyPairFromPrivateKeyBytes":
                let keyPair = try createKeyPairFromPrivateKeyBytes(Data(hex: fixture.requiredPrivateKeyHex()), using: backend)
                XCTAssertEqual(keyPair.publicKey.rawValue.hex, try XCTUnwrap(fixture.expectedPublicKeyHex))
            case "createKeyPairFromBytes":
                let keyPair = try createKeyPairFromBytes(Data(hex: fixture.requiredKeyPairHex()), using: backend)
                XCTAssertEqual(keyPair.publicKey.rawValue.hex, try XCTUnwrap(fixture.expectedPublicKeyHex))
            case "createKeyPairFromBytesError":
                XCTAssertEqual(
                    throwingSolanaCode { _ = try createKeyPairFromBytes(Data(hex: fixture.requiredKeyPairHex()), using: backend) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "createPrivateKeyFromBytesError":
                XCTAssertEqual(
                    throwingSolanaCode { _ = try createPrivateKeyFromBytes(Data(hex: fixture.requiredPrivateKeyHex())) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "signBytes":
                let privateKey = try createPrivateKeyFromBytes(Data(hex: fixture.requiredPrivateKeyHex()))
                let keyPair = try createKeyPairFromPrivateKeyBytes(Data(hex: fixture.requiredPrivateKeyHex()), using: backend)
                let signature = try signBytes(Data(hex: fixture.requiredMessageHex()), with: privateKey, using: backend)
                XCTAssertEqual(keyPair.publicKey.rawValue.hex, try XCTUnwrap(fixture.expectedPublicKeyHex))
                XCTAssertEqual(signature.rawValue.hex, try XCTUnwrap(fixture.expectedSignatureHex))
            case "verifySignature":
                let result = try verifySignature(
                    SignatureBytes(Data(hex: fixture.requiredSignatureHex())),
                    of: Data(hex: fixture.requiredMessageHex()),
                    using: PublicKey(Data(hex: fixture.requiredPublicKeyHex())),
                    backend: backend
                )
                XCTAssertEqual(result, try XCTUnwrap(fixture.expectedBool))
            case "signatureBytesError":
                XCTAssertEqual(
                    throwingSolanaCode { _ = try signatureBytes(Data(hex: fixture.requiredSignatureHex())) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "signatureStringError":
                XCTAssertEqual(
                    throwingSolanaCode { try assertIsSignature(fixture.requiredSignature()) },
                    try XCTUnwrap(fixture.expectedErrorCode)
                )
            case "signatureStringValid":
                let value = try fixture.requiredSignature()
                XCTAssertEqual(isSignature(value), try XCTUnwrap(fixture.expectedBool))
                XCTAssertNoThrow(try assertIsSignature(value))
            default:
                XCTFail("Unhandled fixture operation \(fixture.operation)")
            }
        }
    }

    func testCurveFixtureParity() throws {
        let document: OracleDocument = try OracleFixtures.load("curve25519.generated.json")
        XCTAssertEqual(document.pinnedReference, OracleFixtures.pin)
        XCTAssertEqual(document.kind, "curve25519")

        for fixture in document.cases {
            switch fixture.operation {
            case "compressedPointBytesAreOnCurve":
                let bytes = try Data(hex: fixture.requiredBytesHex())
                let expected = try XCTUnwrap(fixture.expectedBool)
                XCTAssertEqual(compressedEdwardsYIsOnCurve(bytes), expected)
                XCTAssertEqual(isCompressedEdwardsYOnCurve(bytes), expected)
            default:
                XCTFail("Unhandled fixture operation \(fixture.operation)")
            }
        }
    }
}

private enum OracleFixtures {
    static let pin = "b4542070c3a092558ee5e716c15f652e826fbc71"

    static func load<T: Decodable>(_ filename: String, filePath: String = #filePath) throws -> T {
        var url = URL(fileURLWithPath: filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.appendPathComponent("Oracle/Fixtures/Phase1")
        url.appendPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct OracleDocument: Decodable {
    let schemaVersion: Int
    let pinnedReference: String
    let kind: String
    let upstreamPackage: String
    let upstreamSources: [String]
    let cases: [OracleCase]
}

private struct OracleCase: Decodable {
    let id: String
    let operation: String
    let symbol: String?
    let code: Int?
    let message: String?
    let inputHex: [String]?
    let expectedHex: String?
    let expectedBool: Bool?
    let expectedValue: String?
    let expectedErrorCode: Int?
    let leftHex: String?
    let rightHex: String?
    let dataHex: String?
    let needleHex: String?
    let bytesHex: String?
    let payloadHex: String?
    let sentinelHex: String?
    let keyPairHex: String?
    let privateKeyHex: String?
    let publicKeyHex: String?
    let messageHex: String?
    let signatureHex: String?
    let expectedPublicKeyHex: String?
    let expectedSignatureHex: String?
    let signature: String?
    let length: Int?
    let offset: Int?
    let expectedOffset: Int?
    let fixedBytes: Int?
    let decoderConsumes: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case operation
        case symbol
        case code
        case message
        case inputHex
        case expectedHex
        case expectedBool
        case expectedValue
        case expectedErrorCode
        case leftHex
        case rightHex
        case dataHex
        case needleHex
        case bytesHex
        case payloadHex
        case sentinelHex
        case keyPairHex
        case privateKeyHex
        case publicKeyHex
        case messageHex
        case signatureHex
        case expectedPublicKeyHex
        case expectedSignatureHex
        case signature
        case length
        case offset
        case expectedOffset
        case fixedBytes
        case decoderConsumes
    }

    init(from decoder: any Swift.Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        operation = try container.decodeIfPresent(String.self, forKey: .operation) ?? ""
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        code = try container.decodeIfPresent(Int.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        if let values = try? container.decodeIfPresent([String].self, forKey: .inputHex) {
            inputHex = values
        } else if let value = try container.decodeIfPresent(String.self, forKey: .inputHex) {
            inputHex = [value]
        } else {
            inputHex = nil
        }
        expectedHex = try container.decodeIfPresent(String.self, forKey: .expectedHex)
        expectedBool = try container.decodeIfPresent(Bool.self, forKey: .expectedBool)
        expectedValue = try container.decodeIfPresent(String.self, forKey: .expectedValue)
        expectedErrorCode = try container.decodeIfPresent(Int.self, forKey: .expectedErrorCode)
        leftHex = try container.decodeIfPresent(String.self, forKey: .leftHex)
        rightHex = try container.decodeIfPresent(String.self, forKey: .rightHex)
        dataHex = try container.decodeIfPresent(String.self, forKey: .dataHex)
        needleHex = try container.decodeIfPresent(String.self, forKey: .needleHex)
        bytesHex = try container.decodeIfPresent(String.self, forKey: .bytesHex)
        payloadHex = try container.decodeIfPresent(String.self, forKey: .payloadHex)
        sentinelHex = try container.decodeIfPresent(String.self, forKey: .sentinelHex)
        keyPairHex = try container.decodeIfPresent(String.self, forKey: .keyPairHex)
        privateKeyHex = try container.decodeIfPresent(String.self, forKey: .privateKeyHex)
        publicKeyHex = try container.decodeIfPresent(String.self, forKey: .publicKeyHex)
        messageHex = try container.decodeIfPresent(String.self, forKey: .messageHex)
        signatureHex = try container.decodeIfPresent(String.self, forKey: .signatureHex)
        expectedPublicKeyHex = try container.decodeIfPresent(String.self, forKey: .expectedPublicKeyHex)
        expectedSignatureHex = try container.decodeIfPresent(String.self, forKey: .expectedSignatureHex)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        length = try container.decodeIfPresent(Int.self, forKey: .length)
        offset = try container.decodeIfPresent(Int.self, forKey: .offset)
        expectedOffset = try container.decodeIfPresent(Int.self, forKey: .expectedOffset)
        fixedBytes = try container.decodeIfPresent(Int.self, forKey: .fixedBytes)
        decoderConsumes = try container.decodeIfPresent(Int.self, forKey: .decoderConsumes)
    }
}

private extension OracleCase {
    func requiredInputHex() throws -> String {
        try XCTUnwrap(inputHex?.first ?? dataHex)
    }

    func requiredLeftHex() throws -> String {
        try XCTUnwrap(leftHex)
    }

    func requiredRightHex() throws -> String {
        try XCTUnwrap(rightHex)
    }

    func requiredDataHex() throws -> String {
        try XCTUnwrap(dataHex)
    }

    func requiredNeedleHex() throws -> String {
        try XCTUnwrap(needleHex)
    }

    func requiredBytesHex() throws -> String {
        try XCTUnwrap(bytesHex)
    }

    func requiredPayloadHex() throws -> String {
        try XCTUnwrap(payloadHex)
    }

    func requiredSentinelHex() throws -> String {
        try XCTUnwrap(sentinelHex)
    }

    func requiredKeyPairHex() throws -> String {
        try XCTUnwrap(keyPairHex)
    }

    func requiredPrivateKeyHex() throws -> String {
        try XCTUnwrap(privateKeyHex)
    }

    func requiredPublicKeyHex() throws -> String {
        try XCTUnwrap(publicKeyHex)
    }

    func requiredMessageHex() throws -> String {
        try XCTUnwrap(messageHex)
    }

    func requiredSignatureHex() throws -> String {
        try XCTUnwrap(signatureHex)
    }

    func requiredSignature() throws -> String {
        try XCTUnwrap(signature)
    }

    func requiredLength() throws -> Int {
        try XCTUnwrap(length)
    }

    func requiredOffset() throws -> Int {
        try XCTUnwrap(offset)
    }

    func requiredExpectedOffset() throws -> Int {
        try XCTUnwrap(expectedOffset)
    }

    func requiredFixedBytes() throws -> Int {
        try XCTUnwrap(fixedBytes)
    }
}

private func payloadCodec(payload: Data) -> AnyVariableSizeCodec<String, String> {
    createCodec { _ in
        payload.count
    } write: { _, bytes, offset in
        bytes.replaceSubrange(offset ..< offset + payload.count, with: payload)
        return offset + payload.count
    } read: { bytes, offset in
        let value = String(data: Data(bytes[offset...]), encoding: .utf8) ?? ""
        return (value, bytes.count)
    }
}

private func passthroughStringCodec() -> AnyVariableSizeCodec<String, String> {
    createCodec { value in
        value.utf8.count
    } write: { value, bytes, offset in
        let data = Data(value.utf8)
        bytes.replaceSubrange(offset ..< offset + data.count, with: data)
        return offset + data.count
    } read: { bytes, offset in
        let data = Data(bytes[offset...])
        return (String(data: data, encoding: .utf8) ?? "", bytes.count)
    }
}

private func oracleU16Codec() -> AnyFixedSizeCodec<UInt16, UInt16> {
    createCodec(fixedSize: 2) { value, bytes, offset in
        bytes[offset] = UInt8(value & 0xFF)
        bytes[offset + 1] = UInt8(value >> 8)
        return offset + 2
    } read: { bytes, offset in
        try assertByteArrayHasEnoughBytesForCodec("u16", expected: 2, bytes: bytes, offset: offset)
        let value = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        return (value, offset + 2)
    }
}

private func oracleVariableSizePrefixCodec() -> AnyVariableSizeCodec<Int, Int> {
    createCodec { value in
        value < 256 ? 1 : 2
    } write: { value, bytes, offset in
        let size = value < 256 ? 1 : 2
        bytes[offset] = UInt8(value & 0xFF)
        if size == 2 {
            bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
        }
        return offset + size
    } read: { bytes, offset in
        try assertByteArrayHasEnoughBytesForCodec("varPrefix", expected: 1, bytes: bytes, offset: offset)
        return (Int(bytes[offset]), offset + 1)
    }
}

private func throwingCode(_ body: () throws -> Void) -> Int {
    do {
        try body()
        XCTFail("Expected CodecsError")
        return Int.min
    } catch let error as CodecsError {
        return error.code
    } catch {
        XCTFail("Expected CodecsError, got \(error)")
        return Int.min
    }
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

private extension Data {
    init(hex: String) throws {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                throw OracleFixtureError.invalidHex(hex)
            }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private enum OracleFixtureError: Error {
    case invalidHex(String)
}
