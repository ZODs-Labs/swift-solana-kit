// Closed public API contract for FixedPoints.
import Foundation

public enum FixedPointKind: String, Sendable, Equatable, Hashable, Codable
public enum Signedness: String, Sendable, Equatable, Hashable, Codable
public enum RoundingMode: String, Sendable, Equatable, Hashable, Codable
public enum FixedPointEndian: Sendable, Equatable, Hashable, Codable
public struct FixedPointRaw: Sendable, Equatable, Hashable, Comparable, Codable, CustomStringConvertible, ExpressibleByIntegerLiteral
public struct FixedPointCodecConfig: Sendable, Equatable, Hashable
public struct FixedPointToStringOptions: Sendable, Equatable
public struct DecimalFixedPoint: Sendable, Equatable, Hashable
public struct BinaryFixedPoint: Sendable, Equatable, Hashable
public struct DecimalFixedPointFactory: Sendable
public struct RawDecimalFixedPointFactory: Sendable
public struct RatioDecimalFixedPointFactory: Sendable
public struct BinaryFixedPointFactory: Sendable
public struct RawBinaryFixedPointFactory: Sendable
public struct RatioBinaryFixedPointFactory: Sendable
public struct FixedPointFixedSizeEncoder<Encoded: Sendable>: Sendable
public struct FixedPointFixedSizeDecoder<Decoded: Sendable>: Sendable
public struct FixedPointFixedSizeCodec<Encoded: Sendable, Decoded: Sendable>: Sendable

FixedPointKind cases: decimalFixedPoint, binaryFixedPoint
Signedness cases: signed, unsigned
RoundingMode cases: ceil, floor, round, strict, trunc
FixedPointEndian cases: little, big

FixedPointRaw.init(integerLiteral value: Int64)
FixedPointRaw.init(_ value: Int64)
FixedPointRaw.init(_ value: UInt64)
FixedPointRaw.init(decimalString value: String) throws(SolanaError)
FixedPointRaw.description: String
FixedPointRaw.zero: FixedPointRaw
FixedPointRaw.one: FixedPointRaw
FixedPointRaw.IntegerLiteralType typealias Int64
FixedPointRaw.<(lhs: FixedPointRaw, rhs: FixedPointRaw) -> Bool

FixedPointCodecConfig.endian: FixedPointEndian
FixedPointCodecConfig.init(endian: FixedPointEndian = .little)

FixedPointToStringOptions.decimals: Int?
FixedPointToStringOptions.padTrailingZeros: Bool
FixedPointToStringOptions.rounding: RoundingMode
FixedPointToStringOptions.init(decimals: Int? = nil, padTrailingZeros: Bool = false, rounding: RoundingMode = .strict)

DecimalFixedPoint.kind: FixedPointKind
DecimalFixedPoint.raw: FixedPointRaw
DecimalFixedPoint.signedness: Signedness
DecimalFixedPoint.totalBits: Int
DecimalFixedPoint.decimals: Int

BinaryFixedPoint.kind: FixedPointKind
BinaryFixedPoint.raw: FixedPointRaw
BinaryFixedPoint.signedness: Signedness
BinaryFixedPoint.totalBits: Int
BinaryFixedPoint.fractionalBits: Int

DecimalFixedPointFactory.callAsFunction(_ input: String, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint
RawDecimalFixedPointFactory.callAsFunction(_ raw: FixedPointRaw) throws(SolanaError) -> DecimalFixedPoint
RatioDecimalFixedPointFactory.callAsFunction(_ numerator: FixedPointRaw, _ denominator: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint

BinaryFixedPointFactory.callAsFunction(_ input: String, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint
RawBinaryFixedPointFactory.callAsFunction(_ raw: FixedPointRaw) throws(SolanaError) -> BinaryFixedPoint
RatioBinaryFixedPointFactory.callAsFunction(_ numerator: FixedPointRaw, _ denominator: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint

FixedPointFixedSizeEncoder.fixedSize: Int
FixedPointFixedSizeEncoder.init(fixedSize: Int, write: @escaping @Sendable (Encoded, inout Data, Int) throws -> Int)
FixedPointFixedSizeEncoder.encode(_ value: Encoded) throws -> Data
FixedPointFixedSizeEncoder.write(_ value: Encoded, into bytes: inout Data, at offset: Int) throws -> Int

FixedPointFixedSizeDecoder.fixedSize: Int
FixedPointFixedSizeDecoder.init(fixedSize: Int, read: @escaping @Sendable (Data, Int) throws -> (Decoded, Int))
FixedPointFixedSizeDecoder.decode(_ bytes: Data, at offset: Int = 0) throws -> Decoded
FixedPointFixedSizeDecoder.read(_ bytes: Data, at offset: Int) throws -> (Decoded, Int)

FixedPointFixedSizeCodec.fixedSize: Int
FixedPointFixedSizeCodec.init(encoder: FixedPointFixedSizeEncoder<Encoded>, decoder: FixedPointFixedSizeDecoder<Decoded>)
FixedPointFixedSizeCodec.encode(_ value: Encoded) throws -> Data
FixedPointFixedSizeCodec.write(_ value: Encoded, into bytes: inout Data, at offset: Int) throws -> Int
FixedPointFixedSizeCodec.decode(_ bytes: Data, at offset: Int = 0) throws -> Decoded
FixedPointFixedSizeCodec.read(_ bytes: Data, at offset: Int) throws -> (Decoded, Int)

public func decimalFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int) throws(SolanaError) -> DecimalFixedPointFactory
public func rawDecimalFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int) throws(SolanaError) -> RawDecimalFixedPointFactory
public func ratioDecimalFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int) throws(SolanaError) -> RatioDecimalFixedPointFactory

public func binaryFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int) throws(SolanaError) -> BinaryFixedPointFactory
public func rawBinaryFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int) throws(SolanaError) -> RawBinaryFixedPointFactory
public func ratioBinaryFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int) throws(SolanaError) -> RatioBinaryFixedPointFactory

public func addDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint
public func subtractDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint
public func multiplyDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint
public func multiplyDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint
public func divideDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint
public func divideDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint
public func negateDecimalFixedPoint(_ a: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint
public func absoluteDecimalFixedPoint(_ a: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint
public func cmpDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Int
public func eqDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool
public func ltDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool
public func lteDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool
public func gtDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool
public func gteDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool
public func toUnsignedDecimalFixedPoint(_ value: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint
public func toSignedDecimalFixedPoint(_ value: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint
public func rescaleDecimalFixedPoint(_ value: DecimalFixedPoint, _ newTotalBits: Int, _ newDecimals: Int, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint
public func decimalFixedPointToString(_ value: DecimalFixedPoint, options: FixedPointToStringOptions = FixedPointToStringOptions()) throws(SolanaError) -> String
public func formatDecimalFixedPoint(_ formatter: NumberFormatter, _ value: DecimalFixedPoint) -> String
public func decimalFixedPointToNumber(_ value: DecimalFixedPoint) -> Double

public func addBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint
public func subtractBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint
public func multiplyBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint
public func multiplyBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint
public func divideBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint
public func divideBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint
public func negateBinaryFixedPoint(_ a: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint
public func absoluteBinaryFixedPoint(_ a: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint
public func cmpBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Int
public func eqBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool
public func ltBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool
public func lteBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool
public func gtBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool
public func gteBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool
public func binaryFixedPointToBase10(_ value: BinaryFixedPoint) -> (raw: FixedPointRaw, decimals: Int)
public func toUnsignedBinaryFixedPoint(_ value: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint
public func toSignedBinaryFixedPoint(_ value: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint
public func rescaleBinaryFixedPoint(_ value: BinaryFixedPoint, _ newTotalBits: Int, _ newFractionalBits: Int, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint
public func binaryFixedPointToString(_ value: BinaryFixedPoint, options: FixedPointToStringOptions = FixedPointToStringOptions()) throws(SolanaError) -> String
public func formatBinaryFixedPoint(_ formatter: NumberFormatter, _ value: BinaryFixedPoint) -> String
public func binaryFixedPointToNumber(_ value: BinaryFixedPoint) -> Double

public func assertIsDecimalFixedPoint(_ value: DecimalFixedPoint, signedness: Signedness? = nil, totalBits: Int? = nil, decimals: Int? = nil) throws(SolanaError)
public func isDecimalFixedPoint(_ value: DecimalFixedPoint, signedness: Signedness? = nil, totalBits: Int? = nil, decimals: Int? = nil) -> Bool
public func assertIsBinaryFixedPoint(_ value: BinaryFixedPoint, signedness: Signedness? = nil, totalBits: Int? = nil, fractionalBits: Int? = nil) throws(SolanaError)
public func isBinaryFixedPoint(_ value: BinaryFixedPoint, signedness: Signedness? = nil, totalBits: Int? = nil, fractionalBits: Int? = nil) -> Bool

public func getDecimalFixedPointEncoder(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int, config: FixedPointCodecConfig = FixedPointCodecConfig()) throws(SolanaError) -> FixedPointFixedSizeEncoder<DecimalFixedPoint>
public func getDecimalFixedPointDecoder(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int, config: FixedPointCodecConfig = FixedPointCodecConfig()) throws(SolanaError) -> FixedPointFixedSizeDecoder<DecimalFixedPoint>
public func getDecimalFixedPointCodec(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int, config: FixedPointCodecConfig = FixedPointCodecConfig()) throws(SolanaError) -> FixedPointFixedSizeCodec<DecimalFixedPoint, DecimalFixedPoint>
public func getBinaryFixedPointEncoder(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int, config: FixedPointCodecConfig = FixedPointCodecConfig()) throws(SolanaError) -> FixedPointFixedSizeEncoder<BinaryFixedPoint>
public func getBinaryFixedPointDecoder(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int, config: FixedPointCodecConfig = FixedPointCodecConfig()) throws(SolanaError) -> FixedPointFixedSizeDecoder<BinaryFixedPoint>
public func getBinaryFixedPointCodec(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int, config: FixedPointCodecConfig = FixedPointCodecConfig()) throws(SolanaError) -> FixedPointFixedSizeCodec<BinaryFixedPoint, BinaryFixedPoint>
