import Foundation
import SolanaErrors

public typealias Offset = Int

public protocol Encoder<Encoded>: Sendable {
    associatedtype Encoded
    func encode(_ value: Encoded) throws(CodecsError) -> Data
    func write(_ value: Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset
}

public protocol Decoder<Decoded>: Sendable {
    associatedtype Decoded
    func decode(_ bytes: Data, at offset: Offset) throws(CodecsError) -> Decoded
    func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Decoded, Offset)
}

public protocol Codec<Encoded, Decoded>: Encoder, Decoder {}
public protocol FixedSizeEncoder<Encoded>: Encoder { var fixedSize: Int { get } }
public protocol FixedSizeDecoder<Decoded>: Decoder { var fixedSize: Int { get } }
public protocol FixedSizeCodec<Encoded, Decoded>: Codec, FixedSizeEncoder, FixedSizeDecoder {}
public protocol VariableSizeEncoder<Encoded>: Encoder {
    var maxSize: Int? { get }
    func getSizeFromValue(_ value: Encoded) throws(CodecsError) -> Int
}
public protocol VariableSizeDecoder<Decoded>: Decoder { var maxSize: Int? { get } }
public protocol VariableSizeCodec<Encoded, Decoded>: Codec, VariableSizeEncoder, VariableSizeDecoder {}

public struct AnyFixedSizeEncoder<Encoded>: FixedSizeEncoder {
    public let fixedSize: Int
    public init(fixedSize: Int, write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset)
    public init<E: FixedSizeEncoder>(_ encoder: E) where E.Encoded == Encoded
}

public struct AnyVariableSizeEncoder<Encoded>: VariableSizeEncoder {
    public let maxSize: Int?
    public init(maxSize: Int? = nil, getSizeFromValue: @escaping @Sendable (Encoded) throws -> Int, write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset)
    public init<E: VariableSizeEncoder>(_ encoder: E) where E.Encoded == Encoded
}

public struct AnyFixedSizeDecoder<Decoded>: FixedSizeDecoder {
    public let fixedSize: Int
    public init(fixedSize: Int, read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset))
    public init<D: FixedSizeDecoder>(_ decoder: D) where D.Decoded == Decoded
}

public struct AnyVariableSizeDecoder<Decoded>: VariableSizeDecoder {
    public let maxSize: Int?
    public init(maxSize: Int? = nil, read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset))
    public init<D: VariableSizeDecoder>(_ decoder: D) where D.Decoded == Decoded
}

public struct AnyFixedSizeCodec<Encoded, Decoded>: FixedSizeCodec {
    public let fixedSize: Int
    public init(encoder: AnyFixedSizeEncoder<Encoded>, decoder: AnyFixedSizeDecoder<Decoded>) throws(CodecsError)
}

public struct AnyVariableSizeCodec<Encoded, Decoded>: VariableSizeCodec {
    public let maxSize: Int?
    public init(encoder: AnyVariableSizeEncoder<Encoded>, decoder: AnyVariableSizeDecoder<Decoded>) throws(CodecsError)
}

public struct OffsetContext: Sendable {
    public let bytes: Data
    public let preOffset: Offset
    public func wrapBytes(_ offset: Offset) -> Offset
}

public struct PostOffsetContext: Sendable {
    public let bytes: Data
    public let preOffset: Offset
    public let newPreOffset: Offset
    public let postOffset: Offset
    public func wrapBytes(_ offset: Offset) -> Offset
}

public struct OffsetConfig: Sendable {
    public let preOffset: (@Sendable (OffsetContext) -> Offset)?
    public let postOffset: (@Sendable (PostOffsetContext) -> Offset)?
    public init(preOffset: (@Sendable (OffsetContext) -> Offset)? = nil, postOffset: (@Sendable (PostOffsetContext) -> Offset)? = nil)
}

public func createEncoder<Encoded>(fixedSize: Int, write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset) -> AnyFixedSizeEncoder<Encoded>
public func createEncoder<Encoded>(maxSize: Int? = nil, getSizeFromValue: @escaping @Sendable (Encoded) throws -> Int, write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset) -> AnyVariableSizeEncoder<Encoded>
public func createDecoder<Decoded>(fixedSize: Int, read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)) -> AnyFixedSizeDecoder<Decoded>
public func createDecoder<Decoded>(maxSize: Int? = nil, read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)) -> AnyVariableSizeDecoder<Decoded>
public func createCodec<Encoded, Decoded>(fixedSize: Int, write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset, read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)) -> AnyFixedSizeCodec<Encoded, Decoded>
public func createCodec<Encoded, Decoded>(maxSize: Int? = nil, getSizeFromValue: @escaping @Sendable (Encoded) throws -> Int, write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset, read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)) -> AnyVariableSizeCodec<Encoded, Decoded>
public func getEncodedSize<E: FixedSizeEncoder>(_ value: E.Encoded, using encoder: E) -> Int
public func getEncodedSize<E: VariableSizeEncoder>(_ value: E.Encoded, using encoder: E) throws(CodecsError) -> Int
public func assertByteArrayIsNotEmptyForCodec(_ codecDescription: String, bytes: Data, offset: Offset = 0) throws(CodecsError)
public func assertByteArrayHasEnoughBytesForCodec(_ codecDescription: String, expected: Int, bytes: Data, offset: Offset = 0) throws(CodecsError)
public func assertByteArrayOffsetIsNotOutOfRange(_ codecDescription: String, offset: Offset, bytesLength: Int) throws(CodecsError)
public func combineCodec<E: FixedSizeEncoder, D: FixedSizeDecoder>(_ encoder: E, _ decoder: D) throws(CodecsError) -> AnyFixedSizeCodec<E.Encoded, D.Decoded>
public func combineCodec<E: VariableSizeEncoder, D: VariableSizeDecoder>(_ encoder: E, _ decoder: D) throws(CodecsError) -> AnyVariableSizeCodec<E.Encoded, D.Decoded>
public func isFixedSize<E: Encoder>(_ encoder: E) -> Bool
public func isFixedSize<D: Decoder>(_ decoder: D) -> Bool
public func isFixedSize<C: Codec>(_ codec: C) -> Bool
public func isVariableSize<E: Encoder>(_ encoder: E) -> Bool
public func isVariableSize<D: Decoder>(_ decoder: D) -> Bool
public func isVariableSize<C: Codec>(_ codec: C) -> Bool
public func assertIsFixedSize<E: Encoder>(_ encoder: E) throws(CodecsError)
public func assertIsFixedSize<D: Decoder>(_ decoder: D) throws(CodecsError)
public func assertIsFixedSize<C: Codec>(_ codec: C) throws(CodecsError)
public func assertIsVariableSize<E: Encoder>(_ encoder: E) throws(CodecsError)
public func assertIsVariableSize<D: Decoder>(_ decoder: D) throws(CodecsError)
public func assertIsVariableSize<C: Codec>(_ codec: C) throws(CodecsError)
public func addEncoderSizePrefix<E: FixedSizeEncoder, P: FixedSizeEncoder>(_ encoder: E, prefix: P) -> AnyFixedSizeEncoder<E.Encoded> where P.Encoded == Int
public func addEncoderSizePrefix<E: FixedSizeEncoder, P: VariableSizeEncoder>(_ encoder: E, prefix: P) -> AnyVariableSizeEncoder<E.Encoded> where P.Encoded == Int
public func addEncoderSizePrefix<E: VariableSizeEncoder, P: FixedSizeEncoder>(_ encoder: E, prefix: P) -> AnyVariableSizeEncoder<E.Encoded> where P.Encoded == Int
public func addEncoderSizePrefix<E: VariableSizeEncoder, P: VariableSizeEncoder>(_ encoder: E, prefix: P) -> AnyVariableSizeEncoder<E.Encoded> where P.Encoded == Int
public func addDecoderSizePrefix<D: FixedSizeDecoder, P: FixedSizeDecoder>(_ decoder: D, prefix: P) -> AnyFixedSizeDecoder<D.Decoded> where P.Decoded == Int
public func addDecoderSizePrefix<D: FixedSizeDecoder, P: VariableSizeDecoder>(_ decoder: D, prefix: P) -> AnyVariableSizeDecoder<D.Decoded> where P.Decoded == Int
public func addDecoderSizePrefix<D: VariableSizeDecoder, P: FixedSizeDecoder>(_ decoder: D, prefix: P) -> AnyVariableSizeDecoder<D.Decoded> where P.Decoded == Int
public func addDecoderSizePrefix<D: VariableSizeDecoder, P: VariableSizeDecoder>(_ decoder: D, prefix: P) -> AnyVariableSizeDecoder<D.Decoded> where P.Decoded == Int
public func addCodecSizePrefix<C: FixedSizeCodec, P: FixedSizeCodec>(_ codec: C, prefix: P) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int
public func addCodecSizePrefix<C: FixedSizeCodec, P: VariableSizeCodec>(_ codec: C, prefix: P) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int
public func addCodecSizePrefix<C: VariableSizeCodec, P: FixedSizeCodec>(_ codec: C, prefix: P) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int
public func addCodecSizePrefix<C: VariableSizeCodec, P: VariableSizeCodec>(_ codec: C, prefix: P) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int
public func fixEncoderSize<E: Encoder>(_ encoder: E, fixedBytes: Int) -> AnyFixedSizeEncoder<E.Encoded>
public func fixDecoderSize<D: Decoder>(_ decoder: D, fixedBytes: Int) -> AnyFixedSizeDecoder<D.Decoded>
public func fixCodecSize<C: Codec>(_ codec: C, fixedBytes: Int) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func resizeEncoder<E: FixedSizeEncoder>(_ encoder: E, resize: @Sendable (Int) -> Int) throws(CodecsError) -> AnyFixedSizeEncoder<E.Encoded>
public func resizeEncoder<E: VariableSizeEncoder>(_ encoder: E, resize: @escaping @Sendable (Int) -> Int) -> AnyVariableSizeEncoder<E.Encoded>
public func resizeDecoder<D: FixedSizeDecoder>(_ decoder: D, resize: @Sendable (Int) -> Int) throws(CodecsError) -> AnyFixedSizeDecoder<D.Decoded>
public func resizeDecoder<D: VariableSizeDecoder>(_ decoder: D, resize: @escaping @Sendable (Int) -> Int) -> AnyVariableSizeDecoder<D.Decoded>
public func resizeCodec<C: FixedSizeCodec>(_ codec: C, resize: @Sendable (Int) -> Int) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func resizeCodec<C: VariableSizeCodec>(_ codec: C, resize: @escaping @Sendable (Int) -> Int) -> AnyVariableSizeCodec<C.Encoded, C.Decoded>
public func createDecoderThatConsumesEntireByteArray<D: Decoder>(_ decoder: D) -> AnyVariableSizeDecoder<D.Decoded>
public func transformEncoder<E: FixedSizeEncoder, NewEncoded>(_ encoder: E, transform: @escaping @Sendable (NewEncoded) throws -> E.Encoded) -> AnyFixedSizeEncoder<NewEncoded>
public func transformEncoder<E: VariableSizeEncoder, NewEncoded>(_ encoder: E, transform: @escaping @Sendable (NewEncoded) throws -> E.Encoded) -> AnyVariableSizeEncoder<NewEncoded>
public func transformDecoder<D: FixedSizeDecoder, NewDecoded>(_ decoder: D, transform: @escaping @Sendable (D.Decoded) throws -> NewDecoded) -> AnyFixedSizeDecoder<NewDecoded>
public func transformDecoder<D: VariableSizeDecoder, NewDecoded>(_ decoder: D, transform: @escaping @Sendable (D.Decoded) throws -> NewDecoded) -> AnyVariableSizeDecoder<NewDecoded>
public func transformCodec<C: FixedSizeCodec, NewEncoded, NewDecoded>(_ codec: C, encode: @escaping @Sendable (NewEncoded) throws -> C.Encoded, decode: @escaping @Sendable (C.Decoded) throws -> NewDecoded) -> AnyFixedSizeCodec<NewEncoded, NewDecoded>
public func transformCodec<C: VariableSizeCodec, NewEncoded, NewDecoded>(_ codec: C, encode: @escaping @Sendable (NewEncoded) throws -> C.Encoded, decode: @escaping @Sendable (C.Decoded) throws -> NewDecoded) -> AnyVariableSizeCodec<NewEncoded, NewDecoded>
public func reverseEncoder<E: FixedSizeEncoder>(_ encoder: E) -> AnyFixedSizeEncoder<E.Encoded>
public func reverseDecoder<D: FixedSizeDecoder>(_ decoder: D) -> AnyFixedSizeDecoder<D.Decoded>
public func reverseCodec<C: FixedSizeCodec>(_ codec: C) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func offsetEncoder<E: FixedSizeEncoder>(_ encoder: E, config: OffsetConfig) -> AnyFixedSizeEncoder<E.Encoded>
public func offsetEncoder<E: VariableSizeEncoder>(_ encoder: E, config: OffsetConfig) -> AnyVariableSizeEncoder<E.Encoded>
public func offsetDecoder<D: FixedSizeDecoder>(_ decoder: D, config: OffsetConfig) -> AnyFixedSizeDecoder<D.Decoded>
public func offsetDecoder<D: VariableSizeDecoder>(_ decoder: D, config: OffsetConfig) -> AnyVariableSizeDecoder<D.Decoded>
public func offsetCodec<C: FixedSizeCodec>(_ codec: C, config: OffsetConfig) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func offsetCodec<C: VariableSizeCodec>(_ codec: C, config: OffsetConfig) -> AnyVariableSizeCodec<C.Encoded, C.Decoded>
public func padLeftEncoder<E: FixedSizeEncoder>(_ encoder: E, offset: Offset) throws(CodecsError) -> AnyFixedSizeEncoder<E.Encoded>
public func padRightEncoder<E: FixedSizeEncoder>(_ encoder: E, offset: Offset) throws(CodecsError) -> AnyFixedSizeEncoder<E.Encoded>
public func padLeftDecoder<D: FixedSizeDecoder>(_ decoder: D, offset: Offset) throws(CodecsError) -> AnyFixedSizeDecoder<D.Decoded>
public func padRightDecoder<D: FixedSizeDecoder>(_ decoder: D, offset: Offset) throws(CodecsError) -> AnyFixedSizeDecoder<D.Decoded>
public func padLeftCodec<C: FixedSizeCodec>(_ codec: C, offset: Offset) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func padRightCodec<C: FixedSizeCodec>(_ codec: C, offset: Offset) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func addEncoderSentinel<E: FixedSizeEncoder>(_ encoder: E, sentinel: Data) -> AnyFixedSizeEncoder<E.Encoded>
public func addEncoderSentinel<E: VariableSizeEncoder>(_ encoder: E, sentinel: Data) -> AnyVariableSizeEncoder<E.Encoded>
public func addDecoderSentinel<D: FixedSizeDecoder>(_ decoder: D, sentinel: Data) -> AnyFixedSizeDecoder<D.Decoded>
public func addDecoderSentinel<D: VariableSizeDecoder>(_ decoder: D, sentinel: Data) -> AnyVariableSizeDecoder<D.Decoded>
public func addCodecSentinel<C: FixedSizeCodec>(_ codec: C, sentinel: Data) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func addCodecSentinel<C: VariableSizeCodec>(_ codec: C, sentinel: Data) -> AnyVariableSizeCodec<C.Encoded, C.Decoded>
public func mergeBytes(_ byteArrays: [Data]) -> Data
public func padBytes(_ bytes: Data, length: Int) -> Data
public func fixBytes(_ bytes: Data, length: Int) -> Data
public func containsBytes(_ data: Data, _ bytes: Data, at offset: Int) -> Bool
public func bytesEqual(_ lhs: Data, _ rhs: Data) -> Bool
public func toArrayBuffer(_ bytes: Data, offset: Int = 0, length: Int? = nil) -> Data
