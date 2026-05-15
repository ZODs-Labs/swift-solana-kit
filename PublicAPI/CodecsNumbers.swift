import CodecsCore
import Foundation
import SolanaErrors

public typealias NumberEncoder<Encoded> = any Encoder<Encoded>
public typealias FixedSizeNumberEncoder<Encoded> = any FixedSizeEncoder<Encoded>
public typealias NumberDecoder<Decoded> = any Decoder<Decoded>
public typealias FixedSizeNumberDecoder<Decoded> = any FixedSizeDecoder<Decoded>
public typealias NumberCodec<Encoded, Decoded> = any Codec<Encoded, Decoded>
public typealias FixedSizeNumberCodec<Encoded, Decoded> = any FixedSizeCodec<Encoded, Decoded>

public enum Endian: Sendable, Equatable {
    case little
    case big
}

public struct NumberCodecConfig: Sendable, Equatable {
    public let endian: Endian
    public init(endian: Endian = .little)
}

public func assertNumberIsBetweenForCodec<T: BinaryInteger & Sendable>(
    _ codecDescription: String,
    min: T,
    max: T,
    value: T
) throws(CodecsError)

public struct UInt128Value: Sendable, Equatable, Hashable, Comparable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public let high: UInt64
    public let low: UInt64
    public static let min: UInt128Value
    public static let max: UInt128Value
    public var description: String { get }
    public init(high: UInt64, low: UInt64)
    public init(_ value: UInt64)
    public init(integerLiteral value: UInt64)
    public static func < (lhs: UInt128Value, rhs: UInt128Value) -> Bool
}

public struct Int128Value: Sendable, Equatable, Hashable, Comparable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public let bitPattern: UInt128Value
    public static let min: Int128Value
    public static let max: Int128Value
    public var description: String { get }
    public init(bitPattern: UInt128Value)
    public init(_ value: Int64)
    public init(integerLiteral value: Int64)
    public static func < (lhs: Int128Value, rhs: Int128Value) -> Bool
}

public func getF32Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Double>
public func getF32Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Double>
public func getF32Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Double, Double>

public func getF64Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Double>
public func getF64Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Double>
public func getF64Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Double, Double>

public func getI8Encoder() -> AnyFixedSizeEncoder<Int>
public func getI8Decoder() -> AnyFixedSizeDecoder<Int>
public func getI8Codec() -> AnyFixedSizeCodec<Int, Int>

public func getI16Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int>
public func getI16Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int>
public func getI16Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int>

public func getI32Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int>
public func getI32Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int>
public func getI32Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int>

public func getI64Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int64>
public func getI64Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int64>
public func getI64Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int64, Int64>

public func getI128Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int128Value>
public func getI128Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int128Value>
public func getI128Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int128Value, Int128Value>

public func getShortU16Encoder() -> AnyVariableSizeEncoder<Int>
public func getShortU16Decoder() -> AnyVariableSizeDecoder<Int>
public func getShortU16Codec() -> AnyVariableSizeCodec<Int, Int>

public func getU8Encoder() -> AnyFixedSizeEncoder<Int>
public func getU8Decoder() -> AnyFixedSizeDecoder<Int>
public func getU8Codec() -> AnyFixedSizeCodec<Int, Int>

public func getU16Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int>
public func getU16Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int>
public func getU16Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int>

public func getU32Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int>
public func getU32Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int>
public func getU32Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int>

public func getU64Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<UInt64>
public func getU64Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<UInt64>
public func getU64Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<UInt64, UInt64>

public func getU128Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<UInt128Value>
public func getU128Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<UInt128Value>
public func getU128Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<UInt128Value, UInt128Value>
