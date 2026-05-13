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

public protocol Codec<Encoded, Decoded>: Encoder, Decoder where Encoded == Decoded {}

public protocol FixedSizeEncoder: Encoder { var fixedSize: Int { get } }
public protocol FixedSizeDecoder: Decoder { var fixedSize: Int { get } }
public protocol FixedSizeCodec: Codec, FixedSizeEncoder, FixedSizeDecoder {}

public protocol VariableSizeEncoder: Encoder {
    func getSizeFromValue(_ value: Encoded) -> Int
    var maxSize: Int? { get }
}

public protocol VariableSizeDecoder: Decoder { var maxSize: Int? { get } }
public protocol VariableSizeCodec: Codec, VariableSizeEncoder, VariableSizeDecoder {}
