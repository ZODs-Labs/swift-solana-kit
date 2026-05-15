public import Addresses
public import CryptoBackend
public import Foundation
public import Keys
import SolanaErrors

private let maximumBodyBytes = 0xffff
private let maximumHardwareWalletSignableBodyBytes = 1232
private let signingDomainBytes = Data([
    0xff, 0x73, 0x6f, 0x6c, 0x61, 0x6e, 0x61, 0x20,
    0x6f, 0x66, 0x66, 0x63, 0x68, 0x61, 0x69, 0x6e,
])
private let zeroSignatureBytes = Data(repeating: 0, count: 64)

public typealias OffchainMessageApplicationDomain = String
public typealias OffchainMessageBytes = Data
public typealias OffchainMessageVersion = Int

public enum OffchainMessageContentFormat: UInt8, Sendable, Equatable, Codable {
    case restrictedAscii1232BytesMax = 0
    case utf8_1232BytesMax = 1
    case utf8_65535BytesMax = 2
}

public struct OffchainMessageContent: Sendable, Equatable, Codable {
    public let format: OffchainMessageContentFormat
    public let text: String

    public init(format: OffchainMessageContentFormat, text: String) {
        self.format = format
        self.text = text
    }
}

public struct OffchainMessageSignatory: Sendable, Equatable, Hashable, Codable {
    public let address: Address

    public init(address: Address) {
        self.address = address
    }
}

public struct OffchainMessagePreambleV0: Sendable, Equatable, Codable {
    public let applicationDomain: OffchainMessageApplicationDomain
    public let messageFormat: OffchainMessageContentFormat
    public let messageLength: Int
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion

    public init(
        applicationDomain: OffchainMessageApplicationDomain,
        messageFormat: OffchainMessageContentFormat,
        messageLength: Int,
        requiredSignatories: [OffchainMessageSignatory],
        version: OffchainMessageVersion = 0
    ) {
        self.applicationDomain = applicationDomain
        self.messageFormat = messageFormat
        self.messageLength = messageLength
        self.requiredSignatories = requiredSignatories
        self.version = version
    }
}

public struct OffchainMessagePreambleV1: Sendable, Equatable, Codable {
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion

    public init(requiredSignatories: [OffchainMessageSignatory], version: OffchainMessageVersion = 1) {
        self.requiredSignatories = requiredSignatories
        self.version = version
    }
}

public struct OffchainMessageV0: Sendable, Equatable, Codable {
    public let applicationDomain: OffchainMessageApplicationDomain
    public let content: OffchainMessageContent
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion

    public init(
        applicationDomain: OffchainMessageApplicationDomain,
        content: OffchainMessageContent,
        requiredSignatories: [OffchainMessageSignatory],
        version: OffchainMessageVersion = 0
    ) {
        self.applicationDomain = applicationDomain
        self.content = content
        self.requiredSignatories = requiredSignatories
        self.version = version
    }
}

public struct OffchainMessageV1: Sendable, Equatable, Codable {
    public let content: String
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion

    public init(
        content: String,
        requiredSignatories: [OffchainMessageSignatory],
        version: OffchainMessageVersion = 1
    ) {
        self.content = content
        self.requiredSignatories = requiredSignatories
        self.version = version
    }
}

public enum OffchainMessage: Sendable, Equatable, Codable {
    case v0(OffchainMessageV0)
    case v1(OffchainMessageV1)

    public var version: OffchainMessageVersion {
        switch self {
        case let .v0(message):
            return message.version
        case let .v1(message):
            return message.version
        }
    }
}

public struct OffchainMessageSignature: Sendable, Equatable {
    public let address: Address
    public let signature: SignatureBytes?

    public init(address: Address, signature: SignatureBytes?) {
        self.address = address
        self.signature = signature
    }
}

public struct OffchainMessageEnvelope: Sendable, Equatable {
    public let content: OffchainMessageBytes
    public let signatures: [OffchainMessageSignature]

    public init(content: OffchainMessageBytes, signatures: [OffchainMessageSignature]) {
        self.content = content
        self.signatures = signatures
    }

    public init(content: OffchainMessageBytes, signaturesByAddress: [Address: SignatureBytes?]) {
        self.content = content
        self.signatures = signaturesByAddress.map { address, signature in
            OffchainMessageSignature(address: address, signature: signature)
        }
    }

    public func signature(for address: Address) -> SignatureBytes? {
        signatures.reversed().first { $0.address == address }?.signature
    }

    public var signaturesByAddress: [Address: SignatureBytes?] {
        makeSignaturesByAddress(signatures)
    }

    func containsSignatureEntry(for address: Address) -> Bool {
        signatures.contains { $0.address == address }
    }
}

public struct OffchainMessageEncoder<Value>: Sendable {
    private let sizeBody: @Sendable (Value) throws -> Int
    private let writeBody: @Sendable (Value, inout Data, Int) throws -> Int

    public init(
        getSizeFromValue: @escaping @Sendable (Value) throws -> Int,
        write: @escaping @Sendable (Value, inout Data, Int) throws -> Int
    ) {
        self.sizeBody = getSizeFromValue
        self.writeBody = write
    }

    public func getSizeFromValue(_ value: Value) throws -> Int {
        try sizeBody(value)
    }

    public func encode(_ value: Value) throws -> Data {
        let size = try getSizeFromValue(value)
        var bytes = Data(count: size)
        _ = try write(value, into: &bytes, at: 0)
        return bytes
    }

    public func write(_ value: Value, into bytes: inout Data, at offset: Int) throws -> Int {
        try writeBody(value, &bytes, offset)
    }
}

public struct OffchainMessageDecoder<Value>: Sendable {
    private let readBody: @Sendable (Data, Int) throws -> (Value, Int)

    public init(read: @escaping @Sendable (Data, Int) throws -> (Value, Int)) {
        self.readBody = read
    }

    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Value {
        try read(bytes, at: offset).0
    }

    public func read(_ bytes: Data, at offset: Int) throws -> (Value, Int) {
        try readBody(bytes, offset)
    }
}

public struct OffchainMessageCodec<Value>: Sendable {
    public let encoder: OffchainMessageEncoder<Value>
    public let decoder: OffchainMessageDecoder<Value>

    public init(encoder: OffchainMessageEncoder<Value>, decoder: OffchainMessageDecoder<Value>) {
        self.encoder = encoder
        self.decoder = decoder
    }

    public func getSizeFromValue(_ value: Value) throws -> Int {
        try encoder.getSizeFromValue(value)
    }

    public func encode(_ value: Value) throws -> Data {
        try encoder.encode(value)
    }

    public func write(_ value: Value, into bytes: inout Data, at offset: Int) throws -> Int {
        try encoder.write(value, into: &bytes, at: offset)
    }

    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Value {
        try decoder.decode(bytes, at: offset)
    }

    public func read(_ bytes: Data, at offset: Int) throws -> (Value, Int) {
        try decoder.read(bytes, at: offset)
    }
}

public func isOffchainMessageApplicationDomain(_ putativeApplicationDomain: String) -> Bool {
    isAddress(putativeApplicationDomain)
}

public func assertIsOffchainMessageApplicationDomain(_ putativeApplicationDomain: String) throws {
    do {
        try assertIsAddress(putativeApplicationDomain)
    } catch let error {
        switch error {
        case let .addresses(.stringLengthOutOfRange(actualLength)):
            throw SolanaError(
                .offchainMessageApplicationDomainStringLengthOutOfRange,
                context: ["actualLength": .int(actualLength)]
            )
        case let .addresses(.invalidByteLength(actualLength)):
            throw SolanaError(
                .offchainMessageInvalidApplicationDomainByteLength,
                context: ["actualLength": .int(actualLength)]
            )
        default:
            throw error
        }
    }
}

public func offchainMessageApplicationDomain(
    _ putativeApplicationDomain: String
) throws -> OffchainMessageApplicationDomain {
    try assertIsOffchainMessageApplicationDomain(putativeApplicationDomain)
    return putativeApplicationDomain
}

public func assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(
    _ content: OffchainMessageContent
) throws {
    guard content.format == .restrictedAscii1232BytesMax else {
        throw messageFormatMismatch(actual: content.format, expected: .restrictedAscii1232BytesMax)
    }
    guard !content.text.isEmpty else {
        throw SolanaError(.offchainMessageMessageMustBeNonEmpty)
    }
    guard isRestrictedAscii(content.text) else {
        throw SolanaError(.offchainMessageRestrictedAsciiBodyCharacterOutOfRange)
    }
    let length = byteLength(content.text)
    guard length <= maximumHardwareWalletSignableBodyBytes else {
        throw maximumLengthExceeded(actualBytes: length, maxBytes: maximumHardwareWalletSignableBodyBytes)
    }
}

public func isOffchainMessageContentRestrictedAsciiOf1232BytesMax(
    _ content: OffchainMessageContent
) -> Bool {
    do {
        try assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(content)
        return true
    } catch {
        return false
    }
}

public func offchainMessageContentRestrictedAsciiOf1232BytesMax(
    _ text: String
) throws -> OffchainMessageContent {
    let content = OffchainMessageContent(format: .restrictedAscii1232BytesMax, text: text)
    try assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(content)
    return content
}

public func assertIsOffchainMessageContentUtf8Of1232BytesMax(_ content: OffchainMessageContent) throws {
    guard !content.text.isEmpty else {
        throw SolanaError(.offchainMessageMessageMustBeNonEmpty)
    }
    guard content.format == .utf8_1232BytesMax else {
        throw messageFormatMismatch(actual: content.format, expected: .utf8_1232BytesMax)
    }
    let length = byteLength(content.text)
    guard length <= maximumHardwareWalletSignableBodyBytes else {
        throw maximumLengthExceeded(actualBytes: length, maxBytes: maximumHardwareWalletSignableBodyBytes)
    }
}

public func isOffchainMessageContentUtf8Of1232BytesMax(_ content: OffchainMessageContent) -> Bool {
    do {
        try assertIsOffchainMessageContentUtf8Of1232BytesMax(content)
        return true
    } catch {
        return false
    }
}

public func offchainMessageContentUtf8Of1232BytesMax(_ text: String) throws -> OffchainMessageContent {
    let content = OffchainMessageContent(format: .utf8_1232BytesMax, text: text)
    try assertIsOffchainMessageContentUtf8Of1232BytesMax(content)
    return content
}

public func assertIsOffchainMessageContentUtf8Of65535BytesMax(_ content: OffchainMessageContent) throws {
    guard content.format == .utf8_65535BytesMax else {
        throw messageFormatMismatch(actual: content.format, expected: .utf8_65535BytesMax)
    }
    guard !content.text.isEmpty else {
        throw SolanaError(.offchainMessageMessageMustBeNonEmpty)
    }
    let length = byteLength(content.text)
    guard length <= maximumBodyBytes else {
        throw maximumLengthExceeded(actualBytes: length, maxBytes: maximumBodyBytes)
    }
}

public func isOffchainMessageContentUtf8Of65535BytesMax(_ content: OffchainMessageContent) -> Bool {
    do {
        try assertIsOffchainMessageContentUtf8Of65535BytesMax(content)
        return true
    } catch {
        return false
    }
}

public func offchainMessageContentUtf8Of65535BytesMax(_ text: String) throws -> OffchainMessageContent {
    let content = OffchainMessageContent(format: .utf8_65535BytesMax, text: text)
    try assertIsOffchainMessageContentUtf8Of65535BytesMax(content)
    return content
}

public func assertIsOffchainMessageRestrictedAsciiOf1232BytesMax(_ message: OffchainMessageV0) throws {
    try assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(message.content)
}

public func assertIsOffchainMessageUtf8Of1232BytesMax(_ message: OffchainMessageV0) throws {
    try assertIsOffchainMessageContentUtf8Of1232BytesMax(message.content)
}

public func assertIsOffchainMessageUtf8Of65535BytesMax(_ message: OffchainMessageV0) throws {
    try assertIsOffchainMessageContentUtf8Of65535BytesMax(message.content)
}

public func getOffchainMessageSigningDomainEncoder() -> OffchainMessageEncoder<Void> {
    OffchainMessageEncoder<Void>(
        getSizeFromValue: { _ in signingDomainBytes.count },
        write: { _, bytes, offset in
            try writeData(signingDomainBytes, into: &bytes, at: offset)
        }
    )
}

public func getOffchainMessageSigningDomainDecoder() -> OffchainMessageDecoder<Void> {
    OffchainMessageDecoder<Void> { bytes, offset in
        try readSigningDomain(bytes, offset: offset)
        return ((), offset + signingDomainBytes.count)
    }
}

public func getOffchainMessageContentFormatEncoder() -> OffchainMessageEncoder<OffchainMessageContentFormat> {
    OffchainMessageEncoder<OffchainMessageContentFormat>(
        getSizeFromValue: { _ in 1 },
        write: { value, bytes, offset in
            try writeByte(value.rawValue, into: &bytes, at: offset)
        }
    )
}

public func getOffchainMessageContentFormatDecoder() -> OffchainMessageDecoder<OffchainMessageContentFormat> {
    OffchainMessageDecoder<OffchainMessageContentFormat> { bytes, offset in
        let (byte, nextOffset) = try readByte(bytes, offset: offset)
        guard let format = OffchainMessageContentFormat(rawValue: byte) else {
            throw CodecsError.enumDiscriminatorOutOfRange(
                discriminator: Int(byte),
                formattedValidDiscriminators: "0, 1, 2",
                validDiscriminators: [0, 1, 2]
            )
        }
        return (format, nextOffset)
    }
}

public func getOffchainMessageApplicationDomainEncoder()
    -> OffchainMessageEncoder<OffchainMessageApplicationDomain> {
    OffchainMessageEncoder<OffchainMessageApplicationDomain>(
        getSizeFromValue: { _ in 32 },
        write: { value, bytes, offset in
            try assertIsOffchainMessageApplicationDomain(value)
            let encoded = try getAddressEncoder().encode(try address(value))
            return try writeData(encoded, into: &bytes, at: offset)
        }
    )
}

public func getOffchainMessageApplicationDomainDecoder()
    -> OffchainMessageDecoder<OffchainMessageApplicationDomain> {
    OffchainMessageDecoder<OffchainMessageApplicationDomain> { bytes, offset in
        let (address, nextOffset) = try getAddressDecoder().read(bytes, at: offset)
        return (address.rawValue, nextOffset)
    }
}

public func getOffchainMessageV0PreambleEncoder() -> OffchainMessageEncoder<OffchainMessagePreambleV0> {
    OffchainMessageEncoder<OffchainMessagePreambleV0>(
        getSizeFromValue: { value in
            try validateVersion(value.version, fixedVersion: 0)
            try validateRequiredSignatories(value.requiredSignatories)
            return signingDomainBytes.count + 1 + 32 + 1 + 1 + value.requiredSignatories.count * 32 + 2
        },
        write: { value, bytes, offset in
            try validateVersion(value.version, fixedVersion: 0)
            try validateRequiredSignatories(value.requiredSignatories)
            var cursor = try writeData(signingDomainBytes, into: &bytes, at: offset)
            cursor = try writeByte(UInt8(value.version), into: &bytes, at: cursor)
            cursor = try getOffchainMessageApplicationDomainEncoder().write(
                value.applicationDomain,
                into: &bytes,
                at: cursor
            )
            cursor = try writeByte(value.messageFormat.rawValue, into: &bytes, at: cursor)
            cursor = try writeByte(UInt8(value.requiredSignatories.count), into: &bytes, at: cursor)
            for signatory in value.requiredSignatories {
                cursor = try writeData(try getAddressEncoder().encode(signatory.address), into: &bytes, at: cursor)
            }
            cursor = try writeU16LE(value.messageLength, into: &bytes, at: cursor)
            return cursor
        }
    )
}

public func getOffchainMessageV0PreambleDecoder() -> OffchainMessageDecoder<OffchainMessagePreambleV0> {
    OffchainMessageDecoder<OffchainMessagePreambleV0> { bytes, offset in
        var cursor = offset
        try readSigningDomain(bytes, offset: cursor)
        cursor += signingDomainBytes.count
        let (versionByte, versionOffset) = try readByte(bytes, offset: cursor)
        cursor = versionOffset
        let version = Int(versionByte)
        try validateVersion(version, fixedVersion: 0)
        let (applicationDomain, domainOffset) = try getOffchainMessageApplicationDomainDecoder().read(bytes, at: cursor)
        cursor = domainOffset
        let (format, formatOffset) = try getOffchainMessageContentFormatDecoder().read(bytes, at: cursor)
        cursor = formatOffset
        let (requiredSignatories, signatoriesOffset) = try readV0Signatories(bytes, offset: cursor)
        cursor = signatoriesOffset
        let (messageLength, messageLengthOffset) = try readU16LE(bytes, offset: cursor)
        cursor = messageLengthOffset
        return (
            OffchainMessagePreambleV0(
                applicationDomain: applicationDomain,
                messageFormat: format,
                messageLength: messageLength,
                requiredSignatories: requiredSignatories,
                version: version
            ),
            cursor
        )
    }
}

public func getOffchainMessageV1PreambleEncoder() -> OffchainMessageEncoder<OffchainMessagePreambleV1> {
    OffchainMessageEncoder<OffchainMessagePreambleV1>(
        getSizeFromValue: { value in
            try validateVersion(value.version, fixedVersion: 1)
            try validateRequiredSignatories(value.requiredSignatories)
            try validateUniqueSignatories(value.requiredSignatories)
            return signingDomainBytes.count + 1 + 1 + value.requiredSignatories.count * 32
        },
        write: { value, bytes, offset in
            try validateVersion(value.version, fixedVersion: 1)
            try validateRequiredSignatories(value.requiredSignatories)
            try validateUniqueSignatories(value.requiredSignatories)
            var cursor = try writeData(signingDomainBytes, into: &bytes, at: offset)
            cursor = try writeByte(UInt8(value.version), into: &bytes, at: cursor)
            let sortedAddressBytes = try value.requiredSignatories
                .map { try getAddressEncoder().encode($0.address) }
                .sorted(by: byteArrayLexicographicLess)
            cursor = try writeByte(UInt8(sortedAddressBytes.count), into: &bytes, at: cursor)
            for addressBytes in sortedAddressBytes {
                cursor = try writeData(addressBytes, into: &bytes, at: cursor)
            }
            return cursor
        }
    )
}

public func getOffchainMessageV1PreambleDecoder() -> OffchainMessageDecoder<OffchainMessagePreambleV1> {
    OffchainMessageDecoder<OffchainMessagePreambleV1> { bytes, offset in
        var cursor = offset
        try readSigningDomain(bytes, offset: cursor)
        cursor += signingDomainBytes.count
        let (versionByte, versionOffset) = try readByte(bytes, offset: cursor)
        cursor = versionOffset
        let version = Int(versionByte)
        try validateVersion(version, fixedVersion: 1)
        let (requiredSignatories, signatoriesOffset) = try readV1Signatories(bytes, offset: cursor, validateOrdering: true)
        cursor = signatoriesOffset
        return (
            OffchainMessagePreambleV1(requiredSignatories: requiredSignatories, version: version),
            cursor
        )
    }
}

public func getOffchainMessageV0Encoder() -> OffchainMessageEncoder<OffchainMessageV0> {
    OffchainMessageEncoder<OffchainMessageV0>(
        getSizeFromValue: { value in
            let contentBytes = try encodedUtf8(value.content.text)
            let preamble = try v0Preamble(for: value, messageLength: contentBytes.count)
            return try getOffchainMessageV0PreambleEncoder().getSizeFromValue(preamble) + contentBytes.count
        },
        write: { value, bytes, offset in
            let contentBytes = try encodedUtf8(value.content.text)
            let preamble = try v0Preamble(for: value, messageLength: contentBytes.count)
            var cursor = try getOffchainMessageV0PreambleEncoder().write(preamble, into: &bytes, at: offset)
            cursor = try writeData(contentBytes, into: &bytes, at: cursor)
            return cursor
        }
    )
}

public func getOffchainMessageV0Decoder() -> OffchainMessageDecoder<OffchainMessageV0> {
    OffchainMessageDecoder<OffchainMessageV0> { bytes, offset in
        let (preamble, contentOffset) = try getOffchainMessageV0PreambleDecoder().read(bytes, at: offset)
        let contentBytes = Data(bytes.suffix(from: contentOffset))
        let text = try decodeUtf8(contentBytes)
        let actualLength = byteLength(text)
        guard preamble.messageLength == actualLength else {
            throw SolanaError(
                .offchainMessageMessageLengthMismatch,
                context: [
                    "actualLength": .int(actualLength),
                    "specifiedLength": .int(preamble.messageLength),
                ]
            )
        }
        let message = OffchainMessageV0(
            applicationDomain: preamble.applicationDomain,
            content: OffchainMessageContent(format: preamble.messageFormat, text: text),
            requiredSignatories: preamble.requiredSignatories,
            version: preamble.version
        )
        try validateV0Content(message)
        return (message, bytes.count)
    }
}

public func getOffchainMessageV0Codec() -> OffchainMessageCodec<OffchainMessageV0> {
    OffchainMessageCodec(encoder: getOffchainMessageV0Encoder(), decoder: getOffchainMessageV0Decoder())
}

public func getOffchainMessageV1Encoder() -> OffchainMessageEncoder<OffchainMessageV1> {
    OffchainMessageEncoder<OffchainMessageV1>(
        getSizeFromValue: { value in
            try validateV1Content(value.content)
            let contentBytes = try encodedUtf8(value.content)
            let preamble = OffchainMessagePreambleV1(
                requiredSignatories: value.requiredSignatories,
                version: value.version
            )
            return try getOffchainMessageV1PreambleEncoder().getSizeFromValue(preamble) + contentBytes.count
        },
        write: { value, bytes, offset in
            try validateV1Content(value.content)
            let contentBytes = try encodedUtf8(value.content)
            let preamble = OffchainMessagePreambleV1(
                requiredSignatories: value.requiredSignatories,
                version: value.version
            )
            var cursor = try getOffchainMessageV1PreambleEncoder().write(preamble, into: &bytes, at: offset)
            cursor = try writeData(contentBytes, into: &bytes, at: cursor)
            return cursor
        }
    )
}

public func getOffchainMessageV1Decoder() -> OffchainMessageDecoder<OffchainMessageV1> {
    OffchainMessageDecoder<OffchainMessageV1> { bytes, offset in
        let (preamble, contentOffset) = try getOffchainMessageV1PreambleDecoder().read(bytes, at: offset)
        let content = try decodeUtf8(Data(bytes.suffix(from: contentOffset)))
        try validateV1Content(content)
        return (
            OffchainMessageV1(
                content: content,
                requiredSignatories: preamble.requiredSignatories,
                version: preamble.version
            ),
            bytes.count
        )
    }
}

public func getOffchainMessageV1Codec() -> OffchainMessageCodec<OffchainMessageV1> {
    OffchainMessageCodec(encoder: getOffchainMessageV1Encoder(), decoder: getOffchainMessageV1Decoder())
}

public func getOffchainMessageEncoder() -> OffchainMessageEncoder<OffchainMessage> {
    OffchainMessageEncoder<OffchainMessage>(
        getSizeFromValue: { message in
            switch message {
            case let .v0(value):
                return try getOffchainMessageV0Encoder().getSizeFromValue(value)
            case let .v1(value):
                return try getOffchainMessageV1Encoder().getSizeFromValue(value)
            }
        },
        write: { message, bytes, offset in
            switch message {
            case let .v0(value):
                return try getOffchainMessageV0Encoder().write(value, into: &bytes, at: offset)
            case let .v1(value):
                return try getOffchainMessageV1Encoder().write(value, into: &bytes, at: offset)
            }
        }
    )
}

public func getOffchainMessageDecoder() -> OffchainMessageDecoder<OffchainMessage> {
    OffchainMessageDecoder<OffchainMessage> { bytes, offset in
        let version = try readVersionAfterSigningDomain(bytes, offset: offset)
        switch version {
        case 0:
            let (message, nextOffset) = try getOffchainMessageV0Decoder().read(bytes, at: offset)
            return (.v0(message), nextOffset)
        case 1:
            let (message, nextOffset) = try getOffchainMessageV1Decoder().read(bytes, at: offset)
            return (.v1(message), nextOffset)
        default:
            throw SolanaError(
                .offchainMessageVersionNumberNotSupported,
                context: ["unsupportedVersion": .int(version)]
            )
        }
    }
}

public func getOffchainMessageCodec() -> OffchainMessageCodec<OffchainMessage> {
    OffchainMessageCodec(encoder: getOffchainMessageEncoder(), decoder: getOffchainMessageDecoder())
}

public func getOffchainMessageEnvelopeEncoder() -> OffchainMessageEncoder<OffchainMessageEnvelope> {
    OffchainMessageEncoder<OffchainMessageEnvelope>(
        getSizeFromValue: { envelope in
            let ordered = try orderedEnvelopeSignatures(envelope)
            return 1 + ordered.count * 64 + envelope.content.count
        },
        write: { envelope, bytes, offset in
            let ordered = try orderedEnvelopeSignatures(envelope)
            var cursor = try writeByte(UInt8(ordered.count), into: &bytes, at: offset)
            for signature in ordered {
                cursor = try writeData(signature?.rawValue ?? zeroSignatureBytes, into: &bytes, at: cursor)
            }
            cursor = try writeData(envelope.content, into: &bytes, at: cursor)
            return cursor
        }
    )
}

public func getOffchainMessageEnvelopeDecoder() -> OffchainMessageDecoder<OffchainMessageEnvelope> {
    OffchainMessageDecoder<OffchainMessageEnvelope> { bytes, offset in
        let (signatureCountByte, signaturesStartOffset) = try readByte(bytes, offset: offset)
        let signatureCount = Int(signatureCountByte)
        guard signatureCount > 0 else {
            throw SolanaError(.offchainMessageNumEnvelopeSignaturesCannotBeZero)
        }
        var cursor = signaturesStartOffset
        var signatures: [SignatureBytes?] = []
        signatures.reserveCapacity(signatureCount)
        for _ in 0..<signatureCount {
            let signatureBytes = try readData(bytes, offset: cursor, count: 64)
            cursor += 64
            if signatureBytes == zeroSignatureBytes {
                signatures.append(nil)
            } else {
                signatures.append(try SignatureBytes(signatureBytes))
            }
        }
        let content = Data(bytes.suffix(from: cursor))
        let signatoryAddresses = try decodeAndValidateRequiredSignatoryAddresses(content)
        guard signatoryAddresses.count == signatures.count else {
            throw SolanaError(
                .offchainMessageNumSignaturesMismatch,
                context: [
                    "numRequiredSignatures": .int(signatoryAddresses.count),
                    "signatoryAddresses": .stringArray(signatoryAddresses.map(\.rawValue)),
                    "signaturesLength": .int(signatures.count),
                ]
            )
        }
        let signatureEntries = zip(signatoryAddresses, signatures).map { address, signature in
            OffchainMessageSignature(address: address, signature: signature)
        }
        return (OffchainMessageEnvelope(content: content, signatures: signatureEntries), bytes.count)
    }
}

public func getOffchainMessageEnvelopeCodec() -> OffchainMessageCodec<OffchainMessageEnvelope> {
    OffchainMessageCodec(
        encoder: getOffchainMessageEnvelopeEncoder(),
        decoder: getOffchainMessageEnvelopeDecoder()
    )
}

public func getSignatoriesComparator() -> @Sendable (Data, Data) -> Int {
    { lhs, rhs in compareBytes(lhs, rhs) }
}

public func decodeRequiredSignatoryAddresses(_ bytes: Data) throws -> [Address] {
    try readSigningDomain(bytes, offset: 0)
    let (versionByte, afterVersionOffset) = try readByte(bytes, offset: signingDomainBytes.count)
    let version = Int(versionByte)
    if version > 1 {
        throw SolanaError(
            .offchainMessageVersionNumberNotSupported,
            context: ["unsupportedVersion": .int(version)]
        )
    }
    let signatoryOffset = version == 0 ? afterVersionOffset + 32 + 1 : afterVersionOffset
    let (countByte, addressesOffset) = try readByte(bytes, offset: signatoryOffset)
    let count = Int(countByte)
    guard count > 0 else {
        throw SolanaError(.offchainMessageNumRequiredSignersCannotBeZero)
    }
    var cursor = addressesOffset
    var addresses: [Address] = []
    addresses.reserveCapacity(count)
    for _ in 0..<count {
        let (address, nextOffset) = try getAddressDecoder().read(bytes, at: cursor)
        addresses.append(address)
        cursor = nextOffset
    }
    return addresses
}

public func compileOffchainMessageV0Envelope(_ offchainMessage: OffchainMessageV0) throws -> OffchainMessageEnvelope {
    try compileOffchainMessageEnvelopeUsingEncoder(offchainMessage, encoder: getOffchainMessageV0Encoder())
}

public func compileOffchainMessageV1Envelope(_ offchainMessage: OffchainMessageV1) throws -> OffchainMessageEnvelope {
    try compileOffchainMessageEnvelopeUsingEncoder(offchainMessage, encoder: getOffchainMessageV1Encoder())
}

public func compileOffchainMessageEnvelope(_ offchainMessage: OffchainMessage) throws -> OffchainMessageEnvelope {
    switch offchainMessage {
    case let .v0(message):
        return try compileOffchainMessageV0Envelope(message)
    case let .v1(message):
        return try compileOffchainMessageV1Envelope(message)
    }
}

public func isFullySignedOffchainMessageEnvelope(_ offchainMessage: OffchainMessageEnvelope) -> Bool {
    uniqueSignatureEntries(offchainMessage.signatures).allSatisfy { $0.signature != nil }
}

public func assertIsFullySignedOffchainMessageEnvelope(_ offchainMessage: OffchainMessageEnvelope) throws {
    let missing = uniqueSignatureEntries(offchainMessage.signatures).compactMap { entry in
        entry.signature == nil ? entry.address.rawValue : nil
    }
    guard missing.isEmpty else {
        throw SolanaError(
            .offchainMessageSignaturesMissing,
            context: ["addresses": .stringArray(missing)]
        )
    }
}

public func partiallySignOffchainMessageEnvelope(
    _ keyPairs: [KeyPair],
    _ offchainMessageEnvelope: OffchainMessageEnvelope,
    using backend: any CryptoBackend
) throws -> OffchainMessageEnvelope {
    let requiredAddresses = try decodeRequiredSignatoryAddresses(offchainMessageEnvelope.content)
    var keyPairAddresses: [(KeyPair, Address)] = []
    var unexpectedAddresses: [Address] = []
    for keyPair in keyPairs {
        let address = try getAddressFromPublicKey(keyPair.publicKey.rawValue)
        keyPairAddresses.append((keyPair, address))
        if !requiredAddresses.contains(address) {
            unexpectedAddresses.append(address)
        }
    }
    guard unexpectedAddresses.isEmpty else {
        throw SolanaError(
            .offchainMessageAddressesCannotSignOffchainMessage,
            context: [
                "expectedAddresses": .stringArray(requiredAddresses.map(\.rawValue)),
                "unexpectedAddresses": .stringArray(unexpectedAddresses.map(\.rawValue)),
            ]
        )
    }

    var newSignaturesByAddress: [Address: SignatureBytes] = [:]
    var newSignatureAddressOrder: [Address] = []
    var signaturesByAddress = makeSignaturesByAddress(offchainMessageEnvelope.signatures)
    for (keyPair, address) in keyPairAddresses {
        let newSignature = try signBytes(offchainMessageEnvelope.content, with: keyPair.privateKey, using: backend)
        if signaturesByAddress[address] == newSignature {
            continue
        }
        signaturesByAddress[address] = newSignature
        if newSignaturesByAddress[address] == nil {
            newSignatureAddressOrder.append(address)
        }
        newSignaturesByAddress[address] = newSignature
    }
    guard !newSignaturesByAddress.isEmpty else {
        return offchainMessageEnvelope
    }

    var existingAddresses: Set<Address> = []
    var orderedSignatures = uniqueSignatureEntries(offchainMessageEnvelope.signatures).map { entry in
        existingAddresses.insert(entry.address)
        return OffchainMessageSignature(
            address: entry.address,
            signature: newSignaturesByAddress[entry.address] ?? entry.signature
        )
    }
    for address in newSignatureAddressOrder where !existingAddresses.contains(address) {
        orderedSignatures.append(OffchainMessageSignature(address: address, signature: newSignaturesByAddress[address]))
    }
    return OffchainMessageEnvelope(content: offchainMessageEnvelope.content, signatures: orderedSignatures)
}

public func signOffchainMessageEnvelope(
    _ keyPairs: [KeyPair],
    _ offchainMessageEnvelope: OffchainMessageEnvelope,
    using backend: any CryptoBackend
) throws -> OffchainMessageEnvelope {
    let envelope = try partiallySignOffchainMessageEnvelope(keyPairs, offchainMessageEnvelope, using: backend)
    try assertIsFullySignedOffchainMessageEnvelope(envelope)
    return envelope
}

public func verifyOffchainMessageEnvelope(
    _ offchainMessageEnvelope: OffchainMessageEnvelope,
    using backend: any CryptoBackend
) throws {
    let requiredSignatories = try decodeRequiredSignatoryAddresses(offchainMessageEnvelope.content)
    var invalid: [String] = []
    var missing: [String] = []
    for address in requiredSignatories {
        guard let signature = offchainMessageEnvelope.signature(for: address) else {
            missing.append(address.rawValue)
            continue
        }
        let publicKey = try PublicKey(try getAddressEncoder().encode(address))
        let isValid = try verifySignature(signature, of: offchainMessageEnvelope.content, using: publicKey, backend: backend)
        if !isValid {
            invalid.append(address.rawValue)
        }
    }
    if !invalid.isEmpty || !missing.isEmpty {
        var context: [String: SolanaErrorContextValue] = [:]
        if !invalid.isEmpty {
            context["signatoriesWithInvalidSignatures"] = .stringArray(invalid)
        }
        if !missing.isEmpty {
            context["signatoriesWithMissingSignatures"] = .stringArray(missing)
        }
        throw SolanaError(
            .offchainMessageSignatureVerificationFailure,
            context: SolanaErrorContext(context)
        )
    }
}

private func compileOffchainMessageEnvelopeUsingEncoder<T>(
    _ offchainMessage: T,
    encoder: OffchainMessageEncoder<T>
) throws -> OffchainMessageEnvelope where T: OffchainMessageSignatoryProviding {
    let content = try encoder.encode(offchainMessage)
    let signatures = uniqueSignatories(offchainMessage.requiredSignatories).map { signatory in
        OffchainMessageSignature(address: signatory.address, signature: nil)
    }
    return OffchainMessageEnvelope(content: content, signatures: signatures)
}

private protocol OffchainMessageSignatoryProviding {
    var requiredSignatories: [OffchainMessageSignatory] { get }
}

private func makeSignaturesByAddress(_ signatures: [OffchainMessageSignature]) -> [Address: SignatureBytes?] {
    var out: [Address: SignatureBytes?] = [:]
    for entry in signatures {
        out.updateValue(entry.signature, forKey: entry.address)
    }
    return out
}

private func uniqueSignatureEntries(_ signatures: [OffchainMessageSignature]) -> [OffchainMessageSignature] {
    var order: [Address] = []
    var values: [Address: SignatureBytes?] = [:]
    for entry in signatures {
        if values[entry.address] == nil, !order.contains(entry.address) {
            order.append(entry.address)
        }
        values.updateValue(entry.signature, forKey: entry.address)
    }
    return order.map { address in
        OffchainMessageSignature(address: address, signature: values[address] ?? nil)
    }
}

private func uniqueSignatories(_ signatories: [OffchainMessageSignatory]) -> [OffchainMessageSignatory] {
    var seen = Set<Address>()
    var unique: [OffchainMessageSignatory] = []
    for signatory in signatories where seen.insert(signatory.address).inserted {
        unique.append(signatory)
    }
    return unique
}

extension OffchainMessageV0: OffchainMessageSignatoryProviding {}
extension OffchainMessageV1: OffchainMessageSignatoryProviding {}

private func v0Preamble(for value: OffchainMessageV0, messageLength: Int) throws -> OffchainMessagePreambleV0 {
    try validateV0Content(value)
    return OffchainMessagePreambleV0(
        applicationDomain: value.applicationDomain,
        messageFormat: value.content.format,
        messageLength: messageLength,
        requiredSignatories: value.requiredSignatories,
        version: value.version
    )
}

private func validateV0Content(_ message: OffchainMessageV0) throws {
    switch message.content.format {
    case .restrictedAscii1232BytesMax:
        try assertIsOffchainMessageRestrictedAsciiOf1232BytesMax(message)
    case .utf8_1232BytesMax:
        try assertIsOffchainMessageUtf8Of1232BytesMax(message)
    case .utf8_65535BytesMax:
        try assertIsOffchainMessageUtf8Of65535BytesMax(message)
    }
}

private func validateV1Content(_ content: String) throws {
    guard !content.isEmpty else {
        throw SolanaError(.offchainMessageMessageMustBeNonEmpty)
    }
}

private func validateRequiredSignatories(_ signatories: [OffchainMessageSignatory]) throws {
    guard !signatories.isEmpty else {
        throw SolanaError(.offchainMessageNumRequiredSignersCannotBeZero)
    }
    guard signatories.count <= Int(UInt8.max) else {
        throw CodecsError.numberOutOfRange(codecDescription: "u8", min: "0", max: "255", value: String(signatories.count))
    }
}

private func validateUniqueSignatories(_ signatories: [OffchainMessageSignatory]) throws {
    var seen: Set<Address> = []
    for signatory in signatories {
        guard seen.insert(signatory.address).inserted else {
            throw SolanaError(.offchainMessageSignatoriesMustBeUnique)
        }
    }
}

private func validateVersion(_ version: Int, fixedVersion: Int?) throws {
    if version > 1 {
        throw SolanaError(
            .offchainMessageVersionNumberNotSupported,
            context: ["unsupportedVersion": .int(version)]
        )
    }
    if let fixedVersion, version != fixedVersion {
        throw SolanaError(
            .offchainMessageUnexpectedVersion,
            context: ["actualVersion": .int(version), "expectedVersion": .int(fixedVersion)]
        )
    }
}

private func readVersionAfterSigningDomain(_ bytes: Data, offset: Int) throws -> Int {
    try readSigningDomain(bytes, offset: offset)
    let (version, _) = try readByte(bytes, offset: offset + signingDomainBytes.count)
    return Int(version)
}

private func readSigningDomain(_ bytes: Data, offset: Int) throws {
    guard offset >= 0, bytes.count >= offset + signingDomainBytes.count else {
        throw CodecsError.invalidConstant(constant: signingDomainBytes, data: bytes, offset: offset)
    }
    guard bytes.subdata(in: offset..<(offset + signingDomainBytes.count)) == signingDomainBytes else {
        throw CodecsError.invalidConstant(constant: signingDomainBytes, data: bytes, offset: offset)
    }
}

private func readV0Signatories(_ bytes: Data, offset: Int) throws -> ([OffchainMessageSignatory], Int) {
    let (countByte, addressesOffset) = try readByte(bytes, offset: offset)
    let count = Int(countByte)
    guard count > 0 else {
        throw SolanaError(.offchainMessageNumRequiredSignersCannotBeZero)
    }
    var cursor = addressesOffset
    var signatories: [OffchainMessageSignatory] = []
    signatories.reserveCapacity(count)
    for _ in 0..<count {
        let (address, nextOffset) = try getAddressDecoder().read(bytes, at: cursor)
        signatories.append(OffchainMessageSignatory(address: address))
        cursor = nextOffset
    }
    return (signatories, cursor)
}

private func readV1Signatories(
    _ bytes: Data,
    offset: Int,
    validateOrdering: Bool
) throws -> ([OffchainMessageSignatory], Int) {
    let (countByte, addressesOffset) = try readByte(bytes, offset: offset)
    let count = Int(countByte)
    guard count > 0 else {
        throw SolanaError(.offchainMessageNumRequiredSignersCannotBeZero)
    }
    var cursor = addressesOffset
    var addressBytes: [Data] = []
    addressBytes.reserveCapacity(count)
    for _ in 0..<count {
        addressBytes.append(try readData(bytes, offset: cursor, count: 32))
        cursor += 32
    }
    if validateOrdering {
        for index in 0..<(addressBytes.count - 1) {
            let comparison = compareBytes(addressBytes[index], addressBytes[index + 1])
            if comparison == 0 {
                throw SolanaError(.offchainMessageSignatoriesMustBeUnique)
            }
            if comparison > 0 {
                throw SolanaError(.offchainMessageSignatoriesMustBeSorted)
            }
        }
    }
    let signatories = try addressBytes.map { bytes in
        OffchainMessageSignatory(address: try getAddressDecoder().decode(bytes, at: 0))
    }
    return (signatories, cursor)
}

private func decodeAndValidateRequiredSignatoryAddresses(_ bytes: Data) throws -> [Address] {
    let addresses = try decodeRequiredSignatoryAddresses(bytes)
    guard !addresses.isEmpty else {
        throw SolanaError(.offchainMessageNumRequiredSignersCannotBeZero)
    }
    return addresses
}

private func orderedEnvelopeSignatures(_ envelope: OffchainMessageEnvelope) throws -> [SignatureBytes?] {
    guard !envelope.signatures.isEmpty else {
        throw SolanaError(.offchainMessageNumEnvelopeSignaturesCannotBeZero)
    }
    let signatoryAddresses = try decodeAndValidateRequiredSignatoryAddresses(envelope.content)
    var missingRequiredSigners: [String] = []
    var unexpectedSigners: [String] = []
    for address in signatoryAddresses where !envelope.containsSignatureEntry(for: address) {
        missingRequiredSigners.append(address.rawValue)
    }
    for signature in envelope.signatures where !signatoryAddresses.contains(signature.address) {
        unexpectedSigners.append(signature.address.rawValue)
    }
    guard missingRequiredSigners.isEmpty, unexpectedSigners.isEmpty else {
        throw SolanaError(
            .offchainMessageEnvelopeSignersMismatch,
            context: [
                "missingRequiredSigners": .stringArray(missingRequiredSigners),
                "unexpectedSigners": .stringArray(unexpectedSigners),
            ]
        )
    }
    let signaturesByAddress = makeSignaturesByAddress(envelope.signatures)
    var seenSignatoryAddresses = Set<Address>()
    var ordered: [SignatureBytes?] = []
    for address in signatoryAddresses {
        guard seenSignatoryAddresses.insert(address).inserted else {
            continue
        }
        ordered.append(signaturesByAddress[address] ?? nil)
    }
    return ordered
}

private func messageFormatMismatch(
    actual: OffchainMessageContentFormat,
    expected: OffchainMessageContentFormat
) -> SolanaError {
    SolanaError(
        .offchainMessageMessageFormatMismatch,
        context: ["actualMessageFormat": .int(Int(actual.rawValue)), "expectedMessageFormat": .int(Int(expected.rawValue))]
    )
}

private func maximumLengthExceeded(actualBytes: Int, maxBytes: Int) -> SolanaError {
    SolanaError(
        .offchainMessageMaximumLengthExceeded,
        context: ["actualBytes": .int(actualBytes), "maxBytes": .int(maxBytes)]
    )
}

private func isRestrictedAscii(_ text: String) -> Bool {
    text.utf8.allSatisfy { byte in byte >= 0x20 && byte <= 0x7e }
}

private func byteLength(_ text: String) -> Int {
    text.utf8.count
}

private func encodedUtf8(_ text: String) throws -> Data {
    Data(text.utf8)
}

private func decodeUtf8(_ bytes: Data) throws -> String {
    let decoded = String(decoding: bytes, as: UTF8.self)
    return String(decoded.unicodeScalars.filter { $0.value != 0 })
}

private func compareBytes(_ lhs: Data, _ rhs: Data) -> Int {
    if lhs.count != rhs.count {
        return lhs.count < rhs.count ? -1 : 1
    }
    for (left, right) in zip(lhs, rhs) where left != right {
        return left < right ? -1 : 1
    }
    return 0
}

private func byteArrayLexicographicLess(_ lhs: Data, _ rhs: Data) -> Bool {
    compareBytes(lhs, rhs) < 0
}

private func readByte(_ bytes: Data, offset: Int) throws -> (UInt8, Int) {
    guard offset >= 0, offset < bytes.count else {
        throw CodecsError.invalidByteLength(codecDescription: "u8", expected: 1, bytesLength: max(0, bytes.count - offset))
    }
    return (bytes[offset], offset + 1)
}

private func writeByte(_ byte: UInt8, into bytes: inout Data, at offset: Int) throws -> Int {
    guard offset >= 0, offset < bytes.count else {
        throw CodecsError.offsetOutOfRange(codecDescription: "u8", offset: offset, bytesLength: bytes.count)
    }
    bytes[offset] = byte
    return offset + 1
}

private func readData(_ bytes: Data, offset: Int, count: Int) throws -> Data {
    guard offset >= 0, count >= 0, offset + count <= bytes.count else {
        throw CodecsError.invalidByteLength(
            codecDescription: "bytes",
            expected: count,
            bytesLength: max(0, bytes.count - offset)
        )
    }
    return bytes.subdata(in: offset..<(offset + count))
}

private func writeData(_ data: Data, into bytes: inout Data, at offset: Int) throws -> Int {
    guard offset >= 0, offset + data.count <= bytes.count else {
        throw CodecsError.invalidByteLength(
            codecDescription: "bytes",
            expected: data.count,
            bytesLength: max(0, bytes.count - offset)
        )
    }
    bytes.replaceSubrange(offset..<(offset + data.count), with: data)
    return offset + data.count
}

private func readU16LE(_ bytes: Data, offset: Int) throws -> (Int, Int) {
    let data = try readData(bytes, offset: offset, count: 2)
    return (Int(data[data.startIndex]) | (Int(data[data.startIndex + 1]) << 8), offset + 2)
}

private func writeU16LE(_ value: Int, into bytes: inout Data, at offset: Int) throws -> Int {
    guard value >= 0, value <= Int(UInt16.max) else {
        throw CodecsError.numberOutOfRange(codecDescription: "u16", min: "0", max: "65535", value: String(value))
    }
    var cursor = try writeByte(UInt8(value & 0xff), into: &bytes, at: offset)
    cursor = try writeByte(UInt8((value >> 8) & 0xff), into: &bytes, at: cursor)
    return cursor
}
