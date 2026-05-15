public import Addresses
public import CryptoBackend
public import Foundation
public import Keys

public typealias OffchainMessageApplicationDomain = String
public typealias OffchainMessageBytes = Data
public typealias OffchainMessageVersion = Int

public enum OffchainMessageContentFormat: UInt8, Sendable, Equatable, Codable {
    case restrictedAscii1232BytesMax
    case utf8_1232BytesMax
    case utf8_65535BytesMax
}

public struct OffchainMessageContent: Sendable, Equatable, Codable {
    public let format: OffchainMessageContentFormat
    public let text: String
    public init(format: OffchainMessageContentFormat, text: String)
}

public struct OffchainMessageSignatory: Sendable, Equatable, Hashable, Codable {
    public let address: Address
    public init(address: Address)
}

public struct OffchainMessagePreambleV0: Sendable, Equatable, Codable {
    public let applicationDomain: OffchainMessageApplicationDomain
    public let messageFormat: OffchainMessageContentFormat
    public let messageLength: Int
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion
    public init(applicationDomain: OffchainMessageApplicationDomain, messageFormat: OffchainMessageContentFormat, messageLength: Int, requiredSignatories: [OffchainMessageSignatory], version: OffchainMessageVersion = 0)
}

public struct OffchainMessagePreambleV1: Sendable, Equatable, Codable {
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion
    public init(requiredSignatories: [OffchainMessageSignatory], version: OffchainMessageVersion = 1)
}

public struct OffchainMessageV0: Sendable, Equatable, Codable {
    public let applicationDomain: OffchainMessageApplicationDomain
    public let content: OffchainMessageContent
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion
    public init(applicationDomain: OffchainMessageApplicationDomain, content: OffchainMessageContent, requiredSignatories: [OffchainMessageSignatory], version: OffchainMessageVersion = 0)
}

public struct OffchainMessageV1: Sendable, Equatable, Codable {
    public let content: String
    public let requiredSignatories: [OffchainMessageSignatory]
    public let version: OffchainMessageVersion
    public init(content: String, requiredSignatories: [OffchainMessageSignatory], version: OffchainMessageVersion = 1)
}

public enum OffchainMessage: Sendable, Equatable, Codable {
    case v0(OffchainMessageV0)
    case v1(OffchainMessageV1)
    public var version: OffchainMessageVersion { get }
}

public struct OffchainMessageSignature: Sendable, Equatable {
    public let address: Address
    public let signature: SignatureBytes?
    public init(address: Address, signature: SignatureBytes?)
}

public struct OffchainMessageEnvelope: Sendable, Equatable {
    public let content: OffchainMessageBytes
    public let signatures: [OffchainMessageSignature]
    public init(content: OffchainMessageBytes, signatures: [OffchainMessageSignature])
    public init(content: OffchainMessageBytes, signaturesByAddress: [Address: SignatureBytes?])
    public func signature(for address: Address) -> SignatureBytes?
    public var signaturesByAddress: [Address: SignatureBytes?] { get }
}

public struct OffchainMessageEncoder<Value>: Sendable {
    public init(getSizeFromValue: @escaping @Sendable (Value) throws -> Int, write: @escaping @Sendable (Value, inout Data, Int) throws -> Int)
    public func getSizeFromValue(_ value: Value) throws -> Int
    public func encode(_ value: Value) throws -> Data
    public func write(_ value: Value, into bytes: inout Data, at offset: Int) throws -> Int
}

public struct OffchainMessageDecoder<Value>: Sendable {
    public init(read: @escaping @Sendable (Data, Int) throws -> (Value, Int))
    public func decode(_ bytes: Data, at offset: Int) throws -> Value
    public func read(_ bytes: Data, at offset: Int) throws -> (Value, Int)
}

public struct OffchainMessageCodec<Value>: Sendable {
    public let encoder: OffchainMessageEncoder<Value>
    public let decoder: OffchainMessageDecoder<Value>
    public init(encoder: OffchainMessageEncoder<Value>, decoder: OffchainMessageDecoder<Value>)
    public func getSizeFromValue(_ value: Value) throws -> Int
    public func encode(_ value: Value) throws -> Data
    public func write(_ value: Value, into bytes: inout Data, at offset: Int) throws -> Int
    public func decode(_ bytes: Data, at offset: Int) throws -> Value
    public func read(_ bytes: Data, at offset: Int) throws -> (Value, Int)
}

public func isOffchainMessageApplicationDomain(_ putativeApplicationDomain: String) -> Bool
public func assertIsOffchainMessageApplicationDomain(_ putativeApplicationDomain: String) throws
public func offchainMessageApplicationDomain(_ putativeApplicationDomain: String) throws -> OffchainMessageApplicationDomain

public func assertIsOffchainMessageContentRestrictedAsciiOf1232BytesMax(_ content: OffchainMessageContent) throws
public func isOffchainMessageContentRestrictedAsciiOf1232BytesMax(_ content: OffchainMessageContent) -> Bool
public func offchainMessageContentRestrictedAsciiOf1232BytesMax(_ text: String) throws -> OffchainMessageContent
public func assertIsOffchainMessageContentUtf8Of1232BytesMax(_ content: OffchainMessageContent) throws
public func isOffchainMessageContentUtf8Of1232BytesMax(_ content: OffchainMessageContent) -> Bool
public func offchainMessageContentUtf8Of1232BytesMax(_ text: String) throws -> OffchainMessageContent
public func assertIsOffchainMessageContentUtf8Of65535BytesMax(_ content: OffchainMessageContent) throws
public func isOffchainMessageContentUtf8Of65535BytesMax(_ content: OffchainMessageContent) -> Bool
public func offchainMessageContentUtf8Of65535BytesMax(_ text: String) throws -> OffchainMessageContent

public func assertIsOffchainMessageRestrictedAsciiOf1232BytesMax(_ message: OffchainMessageV0) throws
public func assertIsOffchainMessageUtf8Of1232BytesMax(_ message: OffchainMessageV0) throws
public func assertIsOffchainMessageUtf8Of65535BytesMax(_ message: OffchainMessageV0) throws

public func getOffchainMessageSigningDomainEncoder() -> OffchainMessageEncoder<Void>
public func getOffchainMessageSigningDomainDecoder() -> OffchainMessageDecoder<Void>
public func getOffchainMessageContentFormatEncoder() -> OffchainMessageEncoder<OffchainMessageContentFormat>
public func getOffchainMessageContentFormatDecoder() -> OffchainMessageDecoder<OffchainMessageContentFormat>
public func getOffchainMessageApplicationDomainEncoder() -> OffchainMessageEncoder<OffchainMessageApplicationDomain>
public func getOffchainMessageApplicationDomainDecoder() -> OffchainMessageDecoder<OffchainMessageApplicationDomain>
public func getOffchainMessageV0PreambleEncoder() -> OffchainMessageEncoder<OffchainMessagePreambleV0>
public func getOffchainMessageV0PreambleDecoder() -> OffchainMessageDecoder<OffchainMessagePreambleV0>
public func getOffchainMessageV1PreambleEncoder() -> OffchainMessageEncoder<OffchainMessagePreambleV1>
public func getOffchainMessageV1PreambleDecoder() -> OffchainMessageDecoder<OffchainMessagePreambleV1>
public func getOffchainMessageV0Encoder() -> OffchainMessageEncoder<OffchainMessageV0>
public func getOffchainMessageV0Decoder() -> OffchainMessageDecoder<OffchainMessageV0>
public func getOffchainMessageV0Codec() -> OffchainMessageCodec<OffchainMessageV0>
public func getOffchainMessageV1Encoder() -> OffchainMessageEncoder<OffchainMessageV1>
public func getOffchainMessageV1Decoder() -> OffchainMessageDecoder<OffchainMessageV1>
public func getOffchainMessageV1Codec() -> OffchainMessageCodec<OffchainMessageV1>
public func getOffchainMessageEncoder() -> OffchainMessageEncoder<OffchainMessage>
public func getOffchainMessageDecoder() -> OffchainMessageDecoder<OffchainMessage>
public func getOffchainMessageCodec() -> OffchainMessageCodec<OffchainMessage>
public func getOffchainMessageEnvelopeEncoder() -> OffchainMessageEncoder<OffchainMessageEnvelope>
public func getOffchainMessageEnvelopeDecoder() -> OffchainMessageDecoder<OffchainMessageEnvelope>
public func getOffchainMessageEnvelopeCodec() -> OffchainMessageCodec<OffchainMessageEnvelope>
public func getSignatoriesComparator() -> @Sendable (Data, Data) -> Int
public func decodeRequiredSignatoryAddresses(_ bytes: Data) throws -> [Address]

public func compileOffchainMessageV0Envelope(_ offchainMessage: OffchainMessageV0) throws -> OffchainMessageEnvelope
public func compileOffchainMessageV1Envelope(_ offchainMessage: OffchainMessageV1) throws -> OffchainMessageEnvelope
public func compileOffchainMessageEnvelope(_ offchainMessage: OffchainMessage) throws -> OffchainMessageEnvelope

public func isFullySignedOffchainMessageEnvelope(_ offchainMessage: OffchainMessageEnvelope) -> Bool
public func assertIsFullySignedOffchainMessageEnvelope(_ offchainMessage: OffchainMessageEnvelope) throws
public func partiallySignOffchainMessageEnvelope(_ keyPairs: [KeyPair], _ offchainMessageEnvelope: OffchainMessageEnvelope, using backend: any CryptoBackend) throws -> OffchainMessageEnvelope
public func signOffchainMessageEnvelope(_ keyPairs: [KeyPair], _ offchainMessageEnvelope: OffchainMessageEnvelope, using backend: any CryptoBackend) throws -> OffchainMessageEnvelope
public func verifyOffchainMessageEnvelope(_ offchainMessageEnvelope: OffchainMessageEnvelope, using backend: any CryptoBackend) throws
