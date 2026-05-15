public enum CodecValue: Sendable, Equatable, CustomStringConvertible
public struct MapEntry<Key: Sendable, Value: Sendable>: Sendable
public enum AnyValueCodec: Sendable
public struct StructField: Sendable
public struct DiscriminatedUnionVariant: Sendable
public struct EnumCase: Sendable, Equatable
public struct EnumStats: Sendable, Equatable
public enum NullableNoneValue: Sendable, Equatable
public enum NullablePrefix: Sendable

public enum CodecValue.case void
public enum CodecValue.case null
public enum CodecValue.case bool(Bool)
public enum CodecValue.case int(Int)
public enum CodecValue.case int64(Int64)
public enum CodecValue.case uint64(UInt64)
public enum CodecValue.case uint128(UInt128Value)
public enum CodecValue.case string(String)
public enum CodecValue.case bytes(Data)
public enum CodecValue.case array([CodecValue])
public enum CodecValue.case object([String: CodecValue])
public var CodecValue.description: String
public let MapEntry.key: Key
public let MapEntry.value: Value
public init MapEntry(_ key: Key, _ value: Value)
public enum AnyValueCodec.case fixed(AnyFixedSizeCodec<CodecValue, CodecValue>)
public enum AnyValueCodec.case variable(AnyVariableSizeCodec<CodecValue, CodecValue>)
public var AnyValueCodec.fixedSize: Int?
public var AnyValueCodec.maxSize: Int?
public func AnyValueCodec.getSizeFromValue(_ value: CodecValue) throws(CodecsError) -> Int
public func AnyValueCodec.encode(_ value: CodecValue) throws(CodecsError) -> Data
public func AnyValueCodec.write(_ value: CodecValue, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset
public func AnyValueCodec.decode(_ bytes: Data, at offset: Offset) throws(CodecsError) -> CodecValue
public func AnyValueCodec.read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (CodecValue, Offset)
public let StructField.name: String
public let StructField.codec: AnyValueCodec
public init StructField(_ name: String, _ codec: AnyValueCodec)
public let DiscriminatedUnionVariant.discriminator: CodecValue
public let DiscriminatedUnionVariant.codec: AnyValueCodec
public init DiscriminatedUnionVariant(_ discriminator: CodecValue, _ codec: AnyValueCodec)
public let EnumCase.key: String
public let EnumCase.value: CodecValue
public init EnumCase(_ key: String, _ value: CodecValue)
public let EnumStats.enumKeys: [String]
public let EnumStats.enumValues: [CodecValue]
public let EnumStats.numericalValues: [Int]
public let EnumStats.stringValues: [String]
public init EnumStats(enumKeys: [String], enumValues: [CodecValue], numericalValues: [Int], stringValues: [String])
public enum NullableNoneValue.case absent
public enum NullableNoneValue.case zeroes
public enum NullableNoneValue.case bytes(Data)
public enum NullablePrefix.case none
public enum NullablePrefix.case fixed(AnyFixedSizeCodec<Int, Int>)
public enum NullablePrefix.case variable(AnyVariableSizeCodec<Int, Int>)
public static var NullablePrefix.u8: NullablePrefix

public func valueCodec<C: FixedSizeCodec>(_ codec: C, encode: @escaping @Sendable (CodecValue) throws -> C.Encoded, decode: @escaping @Sendable (C.Decoded) throws -> CodecValue) -> AnyValueCodec
public func valueCodec<C: VariableSizeCodec>(_ codec: C, encode: @escaping @Sendable (CodecValue) throws -> C.Encoded, decode: @escaping @Sendable (C.Decoded) throws -> CodecValue) -> AnyValueCodec
public func intValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Int, C.Decoded == Int
public func intValueCodec<C: VariableSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Int, C.Decoded == Int
public func int64ValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Int64, C.Decoded == Int64
public func uint64ValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == UInt64, C.Decoded == UInt64
public func stringValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == String, C.Decoded == String
public func stringValueCodec<C: VariableSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == String, C.Decoded == String
public func bytesValueCodec<C: VariableSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Data, C.Decoded == Data
public func booleanValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Bool, C.Decoded == Bool
public func unitValueCodec() -> AnyValueCodec

public func assertValidNumberOfItemsForCodec(_ codecDescription: String, expected: Int, actual: Int) throws(CodecsError)
public func getBytesEncoder() -> AnyVariableSizeEncoder<Data>
public func getBytesDecoder() -> AnyVariableSizeDecoder<Data>
public func getBytesCodec() -> AnyVariableSizeCodec<Data, Data>
public func getBooleanEncoder() -> AnyFixedSizeEncoder<Bool>
public func getBooleanDecoder() -> AnyFixedSizeDecoder<Bool>
public func getBooleanCodec() -> AnyFixedSizeCodec<Bool, Bool>
public func getBooleanEncoder<C: FixedSizeEncoder>(size: C) -> AnyFixedSizeEncoder<Bool> where C.Encoded == Int
public func getBooleanDecoder<D: FixedSizeDecoder>(size: D) -> AnyFixedSizeDecoder<Bool> where D.Decoded == Int
public func getBooleanCodec<C: FixedSizeCodec>(size: C) -> AnyFixedSizeCodec<Bool, Bool> where C.Encoded == Int, C.Decoded == Int
public func getBooleanEncoder<C: VariableSizeEncoder>(size: C) -> AnyVariableSizeEncoder<Bool> where C.Encoded == Int
public func getBooleanDecoder<D: VariableSizeDecoder>(size: D) -> AnyVariableSizeDecoder<Bool> where D.Decoded == Int
public func getBooleanCodec<C: VariableSizeCodec>(size: C) -> AnyVariableSizeCodec<Bool, Bool> where C.Encoded == Int, C.Decoded == Int
public func getBitArrayEncoder(_ size: Int, backward: Bool) -> AnyFixedSizeEncoder<[Bool]>
public func getBitArrayDecoder(_ size: Int, backward: Bool) -> AnyFixedSizeDecoder<[Bool]>
public func getBitArrayCodec(_ size: Int, backward: Bool) -> AnyFixedSizeCodec<[Bool], [Bool]>
public func getUnitEncoder() -> AnyFixedSizeEncoder<Void>
public func getUnitDecoder() -> AnyFixedSizeDecoder<Void>
public func getUnitCodec() -> AnyFixedSizeCodec<Void, Void>
public func getConstantEncoder(_ constant: Data) -> AnyFixedSizeEncoder<Void>
public func getConstantDecoder(_ constant: Data) -> AnyFixedSizeDecoder<Void>
public func getConstantCodec(_ constant: Data) -> AnyFixedSizeCodec<Void, Void>

public func getArrayCodec<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]>
public func getArrayCodec<C: Codec, P: Codec>(_ item: C, size prefix: P) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> where P.Encoded == Int, P.Decoded == Int
public func getArrayCodec<C: FixedSizeCodec>(_ item: C, size: Int, description: String) -> AnyFixedSizeCodec<[C.Encoded], [C.Decoded]>
public func getArrayCodec<C: VariableSizeCodec>(_ item: C, size: Int, description: String) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]>
public func getArrayCodecRemainder<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]>
public func getSetCodec<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]>
public func getSetCodec<C: Codec, P: Codec>(_ item: C, size prefix: P) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> where P.Encoded == Int, P.Decoded == Int
public func getSetCodec<C: FixedSizeCodec>(_ item: C, size: Int) -> AnyFixedSizeCodec<[C.Encoded], [C.Decoded]>
public func getSetCodec<C: VariableSizeCodec>(_ item: C, size: Int) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]>
public func getSetCodecRemainder<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]>
public func getMapCodec<K: Codec, V: Codec>(_ key: K, _ value: V) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]>
public func getMapCodec<K: Codec, V: Codec, P: Codec>(_ key: K, _ value: V, size prefix: P) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]> where P.Encoded == Int, P.Decoded == Int
public func getMapCodec<K: FixedSizeCodec, V: FixedSizeCodec>(_ key: K, _ value: V, size: Int) -> AnyFixedSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]>
public func getMapCodec<K: Codec, V: Codec>(_ key: K, _ value: V, size: Int) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]>
public func getMapCodecRemainder<K: Codec, V: Codec>(_ key: K, _ value: V) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]>

public func getTupleCodec(_ items: [AnyValueCodec], description: String) -> AnyValueCodec
public func getStructCodec(_ fields: [StructField]) -> AnyValueCodec
public func getUnionCodec(_ variants: [AnyValueCodec], getIndexFromValue: @escaping @Sendable (CodecValue) throws -> Int, getIndexFromBytes: @escaping @Sendable (Data, Offset) throws -> Int) -> AnyValueCodec
public func getDiscriminatedUnionCodec(_ variants: [DiscriminatedUnionVariant], discriminator: String, size: AnyValueCodec) -> AnyValueCodec
public func getLiteralUnionCodec(_ variants: [CodecValue]) -> AnyValueCodec
public func getLiteralUnionCodec(_ variants: [CodecValue], size: AnyValueCodec) -> AnyValueCodec
public func getEnumStats(_ cases: [EnumCase]) -> EnumStats
public func getEnumIndexFromVariant(stats: EnumStats, variant: CodecValue) -> Int
public func getEnumIndexFromDiscriminator(stats: EnumStats, discriminator: Int, useValuesAsDiscriminators: Bool) -> Int
public func formatNumericalValues(_ values: [Int]) -> String
public func getEnumCodec(_ cases: [EnumCase], useValuesAsDiscriminators: Bool) -> AnyValueCodec
public func getEnumCodec(_ cases: [EnumCase], size: AnyValueCodec, useValuesAsDiscriminators: Bool) -> AnyValueCodec
public func getNullableCodec<C: Codec>(_ item: C, prefix: NullablePrefix, noneValue: NullableNoneValue) -> AnyVariableSizeCodec<C.Encoded?, C.Decoded?>
public func getNullableCodec<C: Codec>(_ item: C) -> AnyVariableSizeCodec<C.Encoded?, C.Decoded?>
public func getFixedNullableCodec<C: FixedSizeCodec>(_ item: C, prefix: NullablePrefix, noneValue: NullableNoneValue) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded?, C.Decoded?>
public func getHiddenPrefixCodec<C: FixedSizeCodec>(_ codec: C, prefixes: [AnyFixedSizeCodec<Void, Void>]) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func getHiddenPrefixCodec<C: VariableSizeCodec>(_ codec: C, prefixes: [AnyFixedSizeCodec<Void, Void>]) -> AnyVariableSizeCodec<C.Encoded, C.Decoded>
public func getHiddenSuffixCodec<C: FixedSizeCodec>(_ codec: C, suffixes: [AnyFixedSizeCodec<Void, Void>]) -> AnyFixedSizeCodec<C.Encoded, C.Decoded>
public func getHiddenSuffixCodec<C: VariableSizeCodec>(_ codec: C, suffixes: [AnyFixedSizeCodec<Void, Void>]) -> AnyVariableSizeCodec<C.Encoded, C.Decoded>
public func getPredicateCodec<C: FixedSizeCodec>(encodePredicate: @escaping @Sendable (C.Encoded) -> Bool, decodePredicate: @escaping @Sendable (Data) -> Bool, ifTrue: C, ifFalse: C) -> AnyValueCodec where C.Encoded == C.Decoded
public func getPredicateCodec(encodePredicate: @escaping @Sendable (CodecValue) -> Bool, decodePredicate: @escaping @Sendable (Data) -> Bool, ifTrue: AnyValueCodec, ifFalse: AnyValueCodec) -> AnyValueCodec
public func getPatternMatchCodec(_ patterns: [(value: @Sendable (CodecValue) -> Bool, bytes: @Sendable (Data) -> Bool, codec: AnyValueCodec)]) -> AnyValueCodec
