public import CodecsCore
public import CodecsNumbers
public import Foundation
public import SolanaErrors

public indirect enum CodecValue: Sendable, Equatable, CustomStringConvertible {
    case void
    case null
    case bool(Bool)
    case int(Int)
    case int64(Int64)
    case uint64(UInt64)
    case uint128(UInt128Value)
    case string(String)
    case bytes(Data)
    case array([CodecValue])
    case object([String: CodecValue])

    public var description: String {
        switch self {
        case .void:
            return "undefined"
        case .null:
            return "null"
        case let .bool(value):
            return String(value)
        case let .int(value):
            return String(value)
        case let .int64(value):
            return String(value)
        case let .uint64(value):
            return String(value)
        case let .uint128(value):
            return value.description
        case let .string(value):
            return value
        case let .bytes(value):
            return value.hexString
        case let .array(values):
            return "[" + values.map(\.description).joined(separator: ", ") + "]"
        case let .object(values):
            return "{" + values.keys.sorted().map { "\($0): \(values[$0]?.description ?? "undefined")" }.joined(separator: ", ") + "}"
        }
    }
}

public struct MapEntry<Key: Sendable, Value: Sendable>: Sendable {
    public let key: Key
    public let value: Value

    public init(_ key: Key, _ value: Value) {
        self.key = key
        self.value = value
    }
}

extension MapEntry: Equatable where Key: Equatable, Value: Equatable {}

public enum AnyValueCodec: Sendable {
    case fixed(AnyFixedSizeCodec<CodecValue, CodecValue>)
    case variable(AnyVariableSizeCodec<CodecValue, CodecValue>)

    public var fixedSize: Int? {
        switch self {
        case let .fixed(codec):
            return codec.fixedSize
        case .variable:
            return nil
        }
    }

    public var maxSize: Int? {
        switch self {
        case let .fixed(codec):
            return codec.fixedSize
        case let .variable(codec):
            return codec.maxSize
        }
    }

    public func getSizeFromValue(_ value: CodecValue) throws(CodecsError) -> Int {
        switch self {
        case let .fixed(codec):
            return codec.fixedSize
        case let .variable(codec):
            return try codec.getSizeFromValue(value)
        }
    }

    public func encode(_ value: CodecValue) throws(CodecsError) -> Data {
        switch self {
        case let .fixed(codec):
            return try codec.encode(value)
        case let .variable(codec):
            return try codec.encode(value)
        }
    }

    public func write(_ value: CodecValue, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
        switch self {
        case let .fixed(codec):
            return try codec.write(value, into: &bytes, at: offset)
        case let .variable(codec):
            return try codec.write(value, into: &bytes, at: offset)
        }
    }

    public func decode(_ bytes: Data, at offset: Offset = 0) throws(CodecsError) -> CodecValue {
        try read(bytes, at: offset).0
    }

    public func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (CodecValue, Offset) {
        switch self {
        case let .fixed(codec):
            return try codec.read(bytes, at: offset)
        case let .variable(codec):
            return try codec.read(bytes, at: offset)
        }
    }
}

public struct StructField: Sendable {
    public let name: String
    public let codec: AnyValueCodec

    public init(_ name: String, _ codec: AnyValueCodec) {
        self.name = name
        self.codec = codec
    }
}

public struct DiscriminatedUnionVariant: Sendable {
    public let discriminator: CodecValue
    public let codec: AnyValueCodec

    public init(_ discriminator: CodecValue, _ codec: AnyValueCodec) {
        self.discriminator = discriminator
        self.codec = codec
    }
}

public struct EnumCase: Sendable, Equatable {
    public let key: String
    public let value: CodecValue

    public init(_ key: String, _ value: CodecValue) {
        self.key = key
        self.value = value
    }
}

public struct EnumStats: Sendable, Equatable {
    public let enumKeys: [String]
    public let enumValues: [CodecValue]
    public let numericalValues: [Int]
    public let stringValues: [String]

    public init(enumKeys: [String], enumValues: [CodecValue], numericalValues: [Int], stringValues: [String]) {
        self.enumKeys = enumKeys
        self.enumValues = enumValues
        self.numericalValues = numericalValues
        self.stringValues = stringValues
    }
}

public enum NullableNoneValue: Sendable, Equatable {
    case absent
    case zeroes
    case bytes(Data)
}

public enum NullablePrefix: Sendable {
    case none
    case fixed(AnyFixedSizeCodec<Int, Int>)
    case variable(AnyVariableSizeCodec<Int, Int>)

    public static var u8: NullablePrefix {
        .fixed(getU8Codec())
    }
}

public func valueCodec<C: FixedSizeCodec>(
    _ codec: C,
    encode: @escaping @Sendable (CodecValue) throws -> C.Encoded,
    decode: @escaping @Sendable (C.Decoded) throws -> CodecValue
) -> AnyValueCodec {
    .fixed(
        createCodec(fixedSize: codec.fixedSize) { value, bytes, offset in
            let encoded = try castToCodecsError { try encode(value) }
            return try codec.write(encoded, into: &bytes, at: offset)
        } read: { bytes, offset in
            let (decoded, newOffset) = try codec.read(bytes, at: offset)
            return (try castToCodecsError { try decode(decoded) }, newOffset)
        }
    )
}

public func valueCodec<C: VariableSizeCodec>(
    _ codec: C,
    encode: @escaping @Sendable (CodecValue) throws -> C.Encoded,
    decode: @escaping @Sendable (C.Decoded) throws -> CodecValue
) -> AnyValueCodec {
    .variable(
        createCodec(maxSize: codec.maxSize) { value in
            let encoded = try castToCodecsError { try encode(value) }
            return try codec.getSizeFromValue(encoded)
        } write: { value, bytes, offset in
            let encoded = try castToCodecsError { try encode(value) }
            return try codec.write(encoded, into: &bytes, at: offset)
        } read: { bytes, offset in
            let (decoded, newOffset) = try codec.read(bytes, at: offset)
            return (try castToCodecsError { try decode(decoded) }, newOffset)
        }
    )
}

public func intValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Int, C.Decoded == Int {
    valueCodec(codec, encode: intFromValue, decode: { .int($0) })
}

public func intValueCodec<C: VariableSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Int, C.Decoded == Int {
    valueCodec(codec, encode: intFromValue, decode: { .int($0) })
}

public func int64ValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Int64, C.Decoded == Int64 {
    valueCodec(codec, encode: int64FromValue, decode: { .int64($0) })
}

public func uint64ValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == UInt64, C.Decoded == UInt64 {
    valueCodec(codec, encode: uint64FromValue, decode: { .uint64($0) })
}

public func stringValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == String, C.Decoded == String {
    valueCodec(codec, encode: stringFromValue, decode: { .string($0) })
}

public func stringValueCodec<C: VariableSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == String, C.Decoded == String {
    valueCodec(codec, encode: stringFromValue, decode: { .string($0) })
}

public func bytesValueCodec<C: VariableSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Data, C.Decoded == Data {
    valueCodec(codec, encode: bytesFromValue, decode: { .bytes($0) })
}

public func booleanValueCodec<C: FixedSizeCodec>(_ codec: C) -> AnyValueCodec where C.Encoded == Bool, C.Decoded == Bool {
    valueCodec(codec, encode: boolFromValue, decode: { .bool($0) })
}

public func unitValueCodec() -> AnyValueCodec {
    .fixed(
        createCodec(fixedSize: 0) { _, _, offset in
            offset
        } read: { _, offset in
            (.void, offset)
        }
    )
}

public func assertValidNumberOfItemsForCodec(
    _ codecDescription: String,
    expected: Int,
    actual: Int
) throws(CodecsError) {
    if expected != actual {
        throw CodecsError.invalidNumberOfItems(codecDescription: codecDescription, expected: expected, actual: actual)
    }
}

public func getBytesEncoder() -> AnyVariableSizeEncoder<Data> {
    createEncoder { value in
        value.count
    } write: { value, bytes, offset in
        try writeData(value, into: &bytes, at: offset, codecDescription: "bytes")
        return offset + value.count
    }
}

public func getBytesDecoder() -> AnyVariableSizeDecoder<Data> {
    createDecoder { bytes, offset in
        let slice = suffixBytes(bytes, from: offset)
        return (slice, offset + slice.count)
    }
}

public func getBytesCodec() -> AnyVariableSizeCodec<Data, Data> {
    createCodec { value in
        try getBytesEncoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getBytesEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getBytesDecoder().read(bytes, at: offset)
    }
}

public func getBooleanEncoder() -> AnyFixedSizeEncoder<Bool> {
    getBooleanEncoder(size: getU8Codec())
}

public func getBooleanDecoder() -> AnyFixedSizeDecoder<Bool> {
    getBooleanDecoder(size: getU8Codec())
}

public func getBooleanCodec() -> AnyFixedSizeCodec<Bool, Bool> {
    getBooleanCodec(size: getU8Codec())
}

public func getBooleanEncoder<C: FixedSizeEncoder>(size: C) -> AnyFixedSizeEncoder<Bool> where C.Encoded == Int {
    transformEncoder(size) { value in value ? 1 : 0 }
}

public func getBooleanDecoder<D: FixedSizeDecoder>(size: D) -> AnyFixedSizeDecoder<Bool> where D.Decoded == Int {
    transformDecoder(size) { value in value == 1 }
}

public func getBooleanCodec<C: FixedSizeCodec>(size: C) -> AnyFixedSizeCodec<Bool, Bool> where C.Encoded == Int, C.Decoded == Int {
    transformCodec(size, encode: { $0 ? 1 : 0 }, decode: { $0 == 1 })
}

public func getBooleanEncoder<C: VariableSizeEncoder>(size: C) -> AnyVariableSizeEncoder<Bool> where C.Encoded == Int {
    transformEncoder(size) { value in value ? 1 : 0 }
}

public func getBooleanDecoder<D: VariableSizeDecoder>(size: D) -> AnyVariableSizeDecoder<Bool> where D.Decoded == Int {
    transformDecoder(size) { value in value == 1 }
}

public func getBooleanCodec<C: VariableSizeCodec>(size: C) -> AnyVariableSizeCodec<Bool, Bool> where C.Encoded == Int, C.Decoded == Int {
    transformCodec(size, encode: { $0 ? 1 : 0 }, decode: { $0 == 1 })
}

public func getBitArrayEncoder(_ size: Int, backward: Bool = false) -> AnyFixedSizeEncoder<[Bool]> {
    createEncoder(fixedSize: size) { value, bytes, offset in
        var bytesToAdd: [UInt8] = []
        bytesToAdd.reserveCapacity(size)
        for byteIndex in 0..<size {
            var byte: UInt8 = 0
            for bitIndex in 0..<8 {
                let valueIndex = byteIndex * 8 + bitIndex
                let feature: UInt8 = valueIndex < value.count && value[valueIndex] ? 1 : 0
                byte |= feature << UInt8(backward ? bitIndex : 7 - bitIndex)
            }
            if backward {
                bytesToAdd.insert(byte, at: 0)
            } else {
                bytesToAdd.append(byte)
            }
        }
        try writeData(Data(bytesToAdd), into: &bytes, at: offset, codecDescription: "bitArray")
        return size
    }
}

public func getBitArrayDecoder(_ size: Int, backward: Bool = false) -> AnyFixedSizeDecoder<[Bool]> {
    createDecoder(fixedSize: size) { bytes, offset in
        try assertByteArrayHasEnoughBytesForCodec("bitArray", expected: size, bytes: bytes, offset: offset)
        var slice = Array(bytes[offset..<offset + size])
        if backward {
            slice.reverse()
        }

        var values: [Bool] = []
        values.reserveCapacity(size * 8)
        for var byte in slice {
            for _ in 0..<8 {
                if backward {
                    values.append((byte & 1) != 0)
                    byte >>= 1
                } else {
                    values.append((byte & 0b1000_0000) != 0)
                    byte <<= 1
                }
            }
        }
        return (values, offset + size)
    }
}

public func getBitArrayCodec(_ size: Int, backward: Bool = false) -> AnyFixedSizeCodec<[Bool], [Bool]> {
    createCodec(fixedSize: size) { value, bytes, offset in
        try getBitArrayEncoder(size, backward: backward).write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getBitArrayDecoder(size, backward: backward).read(bytes, at: offset)
    }
}

public func getUnitEncoder() -> AnyFixedSizeEncoder<Void> {
    createEncoder(fixedSize: 0) { _, _, offset in offset }
}

public func getUnitDecoder() -> AnyFixedSizeDecoder<Void> {
    createDecoder(fixedSize: 0) { _, offset in ((), offset) }
}

public func getUnitCodec() -> AnyFixedSizeCodec<Void, Void> {
    createCodec(fixedSize: 0) { _, _, offset in offset } read: { _, offset in ((), offset) }
}

public func getConstantEncoder(_ constant: Data) -> AnyFixedSizeEncoder<Void> {
    createEncoder(fixedSize: constant.count) { _, bytes, offset in
        try writeData(constant, into: &bytes, at: offset, codecDescription: "constant")
        return offset + constant.count
    }
}

public func getConstantDecoder(_ constant: Data) -> AnyFixedSizeDecoder<Void> {
    createDecoder(fixedSize: constant.count) { bytes, offset in
        if !containsBytes(bytes, constant, at: offset) {
            throw CodecsError.invalidConstant(constant: constant, data: bytes, offset: offset)
        }
        return ((), offset + constant.count)
    }
}

public func getConstantCodec(_ constant: Data) -> AnyFixedSizeCodec<Void, Void> {
    createCodec(fixedSize: constant.count) { _, bytes, offset in
        try getConstantEncoder(constant).write((), into: &bytes, at: offset)
    } read: { bytes, offset in
        try getConstantDecoder(constant).read(bytes, at: offset)
    }
}

public func getArrayCodec<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> {
    getArrayCodec(item, size: getU32Codec())
}

public func getArrayCodec<C: Codec, P: Codec>(
    _ item: C,
    size prefix: P
) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> where P.Encoded == Int, P.Decoded == Int {
    createCodec { values in
        try encodedSize(values.count, using: prefix) + values.reduce(0) { total, value in
            try total + encodedSize(value, using: item)
        }
    } write: { values, bytes, offset in
        var cursor = try prefix.write(values.count, into: &bytes, at: offset)
        for value in values {
            cursor = try item.write(value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        if suffixBytes(bytes, from: offset).isEmpty {
            return ([], offset)
        }
        let (count, afterPrefix) = try prefix.read(bytes, at: offset)
        var cursor = afterPrefix
        var values: [C.Decoded] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            let (value, nextOffset) = try item.read(bytes, at: cursor)
            values.append(value)
            cursor = nextOffset
        }
        return (values, cursor)
    }
}

public func getArrayCodec<C: FixedSizeCodec>(
    _ item: C,
    size: Int,
    description: String = "array"
) -> AnyFixedSizeCodec<[C.Encoded], [C.Decoded]> {
    createCodec(fixedSize: item.fixedSize * size) { values, bytes, offset in
        try assertValidNumberOfItemsForCodec(description, expected: size, actual: values.count)
        var cursor = offset
        for value in values {
            cursor = try item.write(value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        var cursor = offset
        var values: [C.Decoded] = []
        values.reserveCapacity(size)
        for _ in 0..<size {
            let (value, nextOffset) = try item.read(bytes, at: cursor)
            values.append(value)
            cursor = nextOffset
        }
        return (values, cursor)
    }
}

public func getArrayCodec<C: VariableSizeCodec>(
    _ item: C,
    size: Int,
    description: String = "array"
) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> {
    createCodec(maxSize: item.maxSize.map { $0 * size }) { values in
        try assertValidNumberOfItemsForCodec(description, expected: size, actual: values.count)
        return try values.reduce(0) { try $0 + item.getSizeFromValue($1) }
    } write: { values, bytes, offset in
        try assertValidNumberOfItemsForCodec(description, expected: size, actual: values.count)
        var cursor = offset
        for value in values {
            cursor = try item.write(value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        var cursor = offset
        var values: [C.Decoded] = []
        values.reserveCapacity(size)
        for _ in 0..<size {
            let (value, nextOffset) = try item.read(bytes, at: cursor)
            values.append(value)
            cursor = nextOffset
        }
        return (values, cursor)
    }
}

public func getArrayCodecRemainder<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> {
    createCodec { values in
        try values.reduce(0) { total, value in try total + encodedSize(value, using: item) }
    } write: { values, bytes, offset in
        var cursor = offset
        for value in values {
            cursor = try item.write(value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        var cursor = offset
        var values: [C.Decoded] = []
        while cursor < bytes.count {
            let (value, nextOffset) = try item.read(bytes, at: cursor)
            values.append(value)
            cursor = nextOffset
        }
        return (values, cursor)
    }
}

public func getSetCodec<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> {
    getArrayCodec(item)
}

public func getSetCodec<C: Codec, P: Codec>(
    _ item: C,
    size prefix: P
) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> where P.Encoded == Int, P.Decoded == Int {
    getArrayCodec(item, size: prefix)
}

public func getSetCodec<C: FixedSizeCodec>(_ item: C, size: Int) -> AnyFixedSizeCodec<[C.Encoded], [C.Decoded]> {
    getArrayCodec(item, size: size)
}

public func getSetCodec<C: VariableSizeCodec>(_ item: C, size: Int) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> {
    getArrayCodec(item, size: size)
}

public func getSetCodecRemainder<C: Codec>(_ item: C) -> AnyVariableSizeCodec<[C.Encoded], [C.Decoded]> {
    getArrayCodecRemainder(item)
}

public func getMapCodec<K: Codec, V: Codec>(
    _ key: K,
    _ value: V
) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]> {
    getMapCodec(key, value, size: getU32Codec())
}

public func getMapCodec<K: Codec, V: Codec, P: Codec>(
    _ key: K,
    _ value: V,
    size prefix: P
) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]> where P.Encoded == Int, P.Decoded == Int {
    createCodec { entries in
        try encodedSize(entries.count, using: prefix) + entries.reduce(0) { total, entry in
            try total + encodedSize(entry.key, using: key) + encodedSize(entry.value, using: value)
        }
    } write: { entries, bytes, offset in
        var cursor = try prefix.write(entries.count, into: &bytes, at: offset)
        for entry in entries {
            cursor = try key.write(entry.key, into: &bytes, at: cursor)
            cursor = try value.write(entry.value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        if suffixBytes(bytes, from: offset).isEmpty {
            return ([], offset)
        }
        let (count, afterPrefix) = try prefix.read(bytes, at: offset)
        return try readMapEntries(count: count, key: key, value: value, bytes: bytes, offset: afterPrefix)
    }
}

public func getMapCodec<K: FixedSizeCodec, V: FixedSizeCodec>(
    _ key: K,
    _ value: V,
    size: Int
) -> AnyFixedSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]> {
    createCodec(fixedSize: (key.fixedSize + value.fixedSize) * size) { entries, bytes, offset in
        try assertValidNumberOfItemsForCodec("array", expected: size, actual: entries.count)
        var cursor = offset
        for entry in entries {
            cursor = try key.write(entry.key, into: &bytes, at: cursor)
            cursor = try value.write(entry.value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        try readMapEntries(count: size, key: key, value: value, bytes: bytes, offset: offset)
    }
}

public func getMapCodec<K: Codec, V: Codec>(
    _ key: K,
    _ value: V,
    size: Int
) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]> {
    createCodec(maxSize: combinedMapMaxSize(key: key, value: value, count: size)) { entries in
        try assertValidNumberOfItemsForCodec("array", expected: size, actual: entries.count)
        return try entries.reduce(0) { total, entry in
            try total + encodedSize(entry.key, using: key) + encodedSize(entry.value, using: value)
        }
    } write: { entries, bytes, offset in
        try assertValidNumberOfItemsForCodec("array", expected: size, actual: entries.count)
        var cursor = offset
        for entry in entries {
            cursor = try key.write(entry.key, into: &bytes, at: cursor)
            cursor = try value.write(entry.value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        try readMapEntries(count: size, key: key, value: value, bytes: bytes, offset: offset)
    }
}

public func getMapCodecRemainder<K: Codec, V: Codec>(
    _ key: K,
    _ value: V
) -> AnyVariableSizeCodec<[MapEntry<K.Encoded, V.Encoded>], [MapEntry<K.Decoded, V.Decoded>]> {
    createCodec { entries in
        try entries.reduce(0) { total, entry in
            try total + encodedSize(entry.key, using: key) + encodedSize(entry.value, using: value)
        }
    } write: { entries, bytes, offset in
        var cursor = offset
        for entry in entries {
            cursor = try key.write(entry.key, into: &bytes, at: cursor)
            cursor = try value.write(entry.value, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        var cursor = offset
        var entries: [MapEntry<K.Decoded, V.Decoded>] = []
        while cursor < bytes.count {
            let (decodedKey, afterKey) = try key.read(bytes, at: cursor)
            let (decodedValue, afterValue) = try value.read(bytes, at: afterKey)
            entries.append(MapEntry(decodedKey, decodedValue))
            cursor = afterValue
        }
        return (entries, cursor)
    }
}

public func getTupleCodec(_ items: [AnyValueCodec], description: String = "tuple") -> AnyValueCodec {
    if let fixedSize = sumKnownSizes(items.map(\.fixedSize)) {
        return .fixed(createCodec(fixedSize: fixedSize) { value, bytes, offset in
            let values = try arrayFromValue(value)
            try assertValidNumberOfItemsForCodec(description, expected: items.count, actual: values.count)
            var cursor = offset
            for (index, item) in items.enumerated() {
                cursor = try item.write(values[index], into: &bytes, at: cursor)
            }
            return cursor
        } read: { bytes, offset in
            var cursor = offset
            var values: [CodecValue] = []
            values.reserveCapacity(items.count)
            for item in items {
                let (value, nextOffset) = try item.read(bytes, at: cursor)
                values.append(value)
                cursor = nextOffset
            }
            return (.array(values), cursor)
        })
    }

    return .variable(createCodec(maxSize: sumKnownSizes(items.map(\.maxSize))) { value in
        let values = try arrayFromValue(value)
        try assertValidNumberOfItemsForCodec(description, expected: items.count, actual: values.count)
        var size = 0
        for (index, item) in items.enumerated() {
            size += try item.getSizeFromValue(values[index])
        }
        return size
    } write: { value, bytes, offset in
        let values = try arrayFromValue(value)
        try assertValidNumberOfItemsForCodec(description, expected: items.count, actual: values.count)
        var cursor = offset
        for (index, item) in items.enumerated() {
            cursor = try item.write(values[index], into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        var cursor = offset
        var values: [CodecValue] = []
        values.reserveCapacity(items.count)
        for item in items {
            let (value, nextOffset) = try item.read(bytes, at: cursor)
            values.append(value)
            cursor = nextOffset
        }
        return (.array(values), cursor)
    })
}

public func getStructCodec(_ fields: [StructField]) -> AnyValueCodec {
    if let fixedSize = sumKnownSizes(fields.map { $0.codec.fixedSize }) {
        return .fixed(createCodec(fixedSize: fixedSize) { value, bytes, offset in
            let object = try objectFromValue(value)
            var cursor = offset
            for field in fields {
                cursor = try field.codec.write(object[field.name] ?? .void, into: &bytes, at: cursor)
            }
            return cursor
        } read: { bytes, offset in
            var cursor = offset
            var object: [String: CodecValue] = [:]
            for field in fields {
                let (value, nextOffset) = try field.codec.read(bytes, at: cursor)
                object[field.name] = value
                cursor = nextOffset
            }
            return (.object(object), cursor)
        })
    }

    return .variable(createCodec(maxSize: sumKnownSizes(fields.map { $0.codec.maxSize })) { value in
        let object = try objectFromValue(value)
        return try fields.reduce(0) { total, field in
            try total + field.codec.getSizeFromValue(object[field.name] ?? .void)
        }
    } write: { value, bytes, offset in
        let object = try objectFromValue(value)
        var cursor = offset
        for field in fields {
            cursor = try field.codec.write(object[field.name] ?? .void, into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        var cursor = offset
        var object: [String: CodecValue] = [:]
        for field in fields {
            let (value, nextOffset) = try field.codec.read(bytes, at: cursor)
            object[field.name] = value
            cursor = nextOffset
        }
        return (.object(object), cursor)
    })
}

public func getUnionCodec(
    _ variants: [AnyValueCodec],
    getIndexFromValue: @escaping @Sendable (CodecValue) throws -> Int,
    getIndexFromBytes: @escaping @Sendable (Data, Offset) throws -> Int
) -> AnyValueCodec {
    if let fixedSize = unionFixedSize(variants) {
        return .fixed(createCodec(fixedSize: fixedSize) { value, bytes, offset in
            let index = try validUnionIndex(try castToCodecsError { try getIndexFromValue(value) }, variantCount: variants.count)
            return try variants[index].write(value, into: &bytes, at: offset)
        } read: { bytes, offset in
            let index = try validUnionIndex(try castToCodecsError { try getIndexFromBytes(bytes, offset) }, variantCount: variants.count)
            return try variants[index].read(bytes, at: offset)
        })
    }

    return .variable(createCodec(maxSize: maxKnownSize(variants.map(\.maxSize))) { value in
        let index = try validUnionIndex(try castToCodecsError { try getIndexFromValue(value) }, variantCount: variants.count)
        return try variants[index].getSizeFromValue(value)
    } write: { value, bytes, offset in
        let index = try validUnionIndex(try castToCodecsError { try getIndexFromValue(value) }, variantCount: variants.count)
        return try variants[index].write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        let index = try validUnionIndex(try castToCodecsError { try getIndexFromBytes(bytes, offset) }, variantCount: variants.count)
        return try variants[index].read(bytes, at: offset)
    })
}

public func getDiscriminatedUnionCodec(
    _ variants: [DiscriminatedUnionVariant],
    discriminator: String = "__kind",
    size: AnyValueCodec = intValueCodec(getU8Codec())
) -> AnyValueCodec {
    let unionVariants = variants.enumerated().map { index, variant in
        getTupleCodec([size, variant.codec]).mapEncodedDecoded(
            encode: { value in .array([.int(index), value]) },
            decode: { value in
                let values = try arrayFromValue(value)
                let content = values.count > 1 ? values[1] : .void
                var object = (try? objectFromValue(content)) ?? [:]
                object[discriminator] = variant.discriminator
                return .object(object)
            }
        )
    }
    return getUnionCodec(unionVariants) { value in
        let object = try objectFromValue(value)
        let discriminatorValue = object[discriminator] ?? .void
        guard let index = variants.firstIndex(where: { $0.discriminator == discriminatorValue }) else {
            throw CodecsError.invalidDiscriminatedUnionVariant(
                value: discriminatorValue.description,
                variants: variants.map { $0.discriminator.description }
            )
        }
        return index
    } getIndexFromBytes: { bytes, offset in
        let (value, _) = try size.read(bytes, at: offset)
        return try intFromValue(value)
    }
}

public func getLiteralUnionCodec(_ variants: [CodecValue]) -> AnyValueCodec {
    getLiteralUnionCodec(variants, size: intValueCodec(getU8Codec()))
}

public func getLiteralUnionCodec(_ variants: [CodecValue], size: AnyValueCodec) -> AnyValueCodec {
    size.mapEncodedDecoded { value in
        guard let index = variants.firstIndex(of: value) else {
            throw CodecsError.invalidLiteralUnionVariant(value: value.description, variants: variants.map(\.description))
        }
        return .int(index)
    } decode: { value in
        let index = try intFromValue(value)
        guard index >= 0, index < variants.count else {
            throw CodecsError.literalUnionDiscriminatorOutOfRange(discriminator: index, minRange: 0, maxRange: variants.count - 1)
        }
        return variants[index]
    }
}

public func getEnumStats(_ cases: [EnumCase]) -> EnumStats {
    let enumKeys = cases.map(\.key)
    let enumValues = cases.map(\.value)
    let numericalValues = Array(Set(enumValues.compactMap { value -> Int? in
        if case let .int(number) = value { return number }
        return nil
    })).sorted()
    var stringValues: [String] = []
    for key in enumKeys where !stringValues.contains(key) {
        stringValues.append(key)
    }
    for value in enumValues {
        if case let .string(string) = value, !stringValues.contains(string) {
            stringValues.append(string)
        }
    }
    return EnumStats(enumKeys: enumKeys, enumValues: enumValues, numericalValues: numericalValues, stringValues: stringValues)
}

public func getEnumIndexFromVariant(stats: EnumStats, variant: CodecValue) -> Int {
    if let valueIndex = stats.enumValues.lastIndex(of: variant) {
        return valueIndex
    }
    if case let .string(key) = variant {
        return stats.enumKeys.firstIndex(of: key) ?? -1
    }
    return -1
}

public func getEnumIndexFromDiscriminator(
    stats: EnumStats,
    discriminator: Int,
    useValuesAsDiscriminators: Bool
) -> Int {
    if !useValuesAsDiscriminators {
        return discriminator >= 0 && discriminator < stats.enumKeys.count ? discriminator : -1
    }
    return stats.enumValues.lastIndex(of: .int(discriminator)) ?? -1
}

public func formatNumericalValues(_ values: [Int]) -> String {
    guard let first = values.first else {
        return ""
    }
    var range = (first, first)
    var ranges: [String] = []
    for value in values.dropFirst() {
        if range.1 + 1 == value {
            range.1 = value
        } else {
            ranges.append(range.0 == range.1 ? "\(range.0)" : "\(range.0)-\(range.1)")
            range = (value, value)
        }
    }
    ranges.append(range.0 == range.1 ? "\(range.0)" : "\(range.0)-\(range.1)")
    return ranges.joined(separator: ", ")
}

public func getEnumCodec(_ cases: [EnumCase], useValuesAsDiscriminators: Bool = false) -> AnyValueCodec {
    getEnumCodec(cases, size: intValueCodec(getU8Codec()), useValuesAsDiscriminators: useValuesAsDiscriminators)
}

public func getEnumCodec(
    _ cases: [EnumCase],
    size: AnyValueCodec,
    useValuesAsDiscriminators: Bool = false
) -> AnyValueCodec {
    let stats = getEnumStats(cases)
    let lexicalDiscriminatorError: CodecsError? = {
        guard useValuesAsDiscriminators else {
            return nil
        }
        let lexicalValues = stats.enumValues.compactMap { value -> String? in
            if case let .string(string) = value { return string }
            return nil
        }
        return lexicalValues.isEmpty ? nil : .cannotUseLexicalValuesAsEnumDiscriminators(stringValues: lexicalValues)
    }()
    return size.mapEncodedDecoded { value in
        if let lexicalDiscriminatorError {
            throw lexicalDiscriminatorError
        }
        let index = getEnumIndexFromVariant(stats: stats, variant: value)
        guard index >= 0 else {
            throw CodecsError.invalidEnumVariant(
                variant: value.description,
                stringValues: stats.stringValues,
                numericalValues: stats.numericalValues,
                formattedNumericalValues: formatNumericalValues(stats.numericalValues)
            )
        }
        return useValuesAsDiscriminators ? stats.enumValues[index] : .int(index)
    } decode: { value in
        if let lexicalDiscriminatorError {
            throw lexicalDiscriminatorError
        }
        let discriminator = try intFromValue(value)
        let index = getEnumIndexFromDiscriminator(
            stats: stats,
            discriminator: discriminator,
            useValuesAsDiscriminators: useValuesAsDiscriminators
        )
        guard index >= 0 else {
            let valid = useValuesAsDiscriminators ? stats.numericalValues : Array(0..<stats.enumKeys.count)
            throw CodecsError.enumDiscriminatorOutOfRange(
                discriminator: discriminator,
                formattedValidDiscriminators: formatNumericalValues(valid),
                validDiscriminators: valid
            )
        }
        return stats.enumValues[index]
    }
}

public func getNullableCodec<C: Codec>(
    _ item: C,
    prefix: NullablePrefix,
    noneValue: NullableNoneValue = .absent
) -> AnyVariableSizeCodec<C.Encoded?, C.Decoded?> {
    createCodec(maxSize: nullableMaxSize(item: item, prefix: prefix, noneValue: noneValue)) { value in
        if let value {
            return try prefixSize(prefix, flag: true) + encodedSize(value, using: item)
        }
        return try prefixSize(prefix, flag: false) + noneValueSize(noneValue, item: item)
    } write: { value, bytes, offset in
        var cursor = offset
        if let value {
            cursor = try writePrefix(prefix, flag: true, into: &bytes, at: cursor)
            return try item.write(value, into: &bytes, at: cursor)
        }
        cursor = try writePrefix(prefix, flag: false, into: &bytes, at: cursor)
        return try writeNoneValue(noneValue, item: item, into: &bytes, at: cursor)
    } read: { bytes, offset in
        let decision = try nullableDecision(prefix: prefix, noneValue: noneValue, item: item, bytes: bytes, offset: offset)
        if decision.isSome {
            return try item.read(bytes, at: decision.valueOffset)
        }
        return (nil, decision.noneOffset)
    }
}

public func getNullableCodec<C: Codec>(_ item: C) -> AnyVariableSizeCodec<C.Encoded?, C.Decoded?> {
    getNullableCodec(item, prefix: .u8, noneValue: .absent)
}

public func getFixedNullableCodec<C: FixedSizeCodec>(
    _ item: C,
    prefix: NullablePrefix = .none,
    noneValue: NullableNoneValue = .zeroes
) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded?, C.Decoded?> {
    let prefixFixedSize = try fixedPrefixSize(prefix)
    let fixedSize = prefixFixedSize + item.fixedSize
    return createCodec(fixedSize: fixedSize) { value, bytes, offset in
        var cursor = offset
        if let value {
            cursor = try writePrefix(prefix, flag: true, into: &bytes, at: cursor)
            return try item.write(value, into: &bytes, at: cursor)
        }
        cursor = try writePrefix(prefix, flag: false, into: &bytes, at: cursor)
        return try writeNoneValue(noneValue, item: item, into: &bytes, at: cursor)
    } read: { bytes, offset in
        let decision = try nullableDecision(prefix: prefix, noneValue: noneValue, item: item, bytes: bytes, offset: offset)
        if decision.isSome {
            return try item.read(bytes, at: decision.valueOffset)
        }
        return (nil, decision.noneOffset)
    }
}

public func getHiddenPrefixCodec<C: FixedSizeCodec>(
    _ codec: C,
    prefixes: [AnyFixedSizeCodec<Void, Void>]
) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    let prefixSize = prefixes.reduce(0) { $0 + $1.fixedSize }
    return createCodec(fixedSize: prefixSize + codec.fixedSize) { value, bytes, offset in
        var cursor = offset
        for prefix in prefixes {
            cursor = try prefix.write((), into: &bytes, at: cursor)
        }
        return try codec.write(value, into: &bytes, at: cursor)
    } read: { bytes, offset in
        var cursor = offset
        for prefix in prefixes {
            cursor = try prefix.read(bytes, at: cursor).1
        }
        return try codec.read(bytes, at: cursor)
    }
}

public func getHiddenPrefixCodec<C: VariableSizeCodec>(
    _ codec: C,
    prefixes: [AnyFixedSizeCodec<Void, Void>]
) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> {
    let prefixSize = prefixes.reduce(0) { $0 + $1.fixedSize }
    return createCodec(maxSize: codec.maxSize.map { $0 + prefixSize }) { value in
        try prefixSize + codec.getSizeFromValue(value)
    } write: { value, bytes, offset in
        var cursor = offset
        for prefix in prefixes {
            cursor = try prefix.write((), into: &bytes, at: cursor)
        }
        return try codec.write(value, into: &bytes, at: cursor)
    } read: { bytes, offset in
        var cursor = offset
        for prefix in prefixes {
            cursor = try prefix.read(bytes, at: cursor).1
        }
        return try codec.read(bytes, at: cursor)
    }
}

public func getHiddenSuffixCodec<C: FixedSizeCodec>(
    _ codec: C,
    suffixes: [AnyFixedSizeCodec<Void, Void>]
) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    let suffixSize = suffixes.reduce(0) { $0 + $1.fixedSize }
    return createCodec(fixedSize: codec.fixedSize + suffixSize) { value, bytes, offset in
        var cursor = try codec.write(value, into: &bytes, at: offset)
        for suffix in suffixes {
            cursor = try suffix.write((), into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        let (value, afterValue) = try codec.read(bytes, at: offset)
        var cursor = afterValue
        for suffix in suffixes {
            cursor = try suffix.read(bytes, at: cursor).1
        }
        return (value, cursor)
    }
}

public func getHiddenSuffixCodec<C: VariableSizeCodec>(
    _ codec: C,
    suffixes: [AnyFixedSizeCodec<Void, Void>]
) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> {
    let suffixSize = suffixes.reduce(0) { $0 + $1.fixedSize }
    return createCodec(maxSize: codec.maxSize.map { $0 + suffixSize }) { value in
        try codec.getSizeFromValue(value) + suffixSize
    } write: { value, bytes, offset in
        var cursor = try codec.write(value, into: &bytes, at: offset)
        for suffix in suffixes {
            cursor = try suffix.write((), into: &bytes, at: cursor)
        }
        return cursor
    } read: { bytes, offset in
        let (value, afterValue) = try codec.read(bytes, at: offset)
        var cursor = afterValue
        for suffix in suffixes {
            cursor = try suffix.read(bytes, at: cursor).1
        }
        return (value, cursor)
    }
}

public func getPredicateCodec<C: FixedSizeCodec>(
    encodePredicate: @escaping @Sendable (C.Encoded) -> Bool,
    decodePredicate: @escaping @Sendable (Data) -> Bool,
    ifTrue: C,
    ifFalse: C
) -> AnyValueCodec where C.Encoded == C.Decoded {
    valueCodec(
        createCodec(fixedSize: ifTrue.fixedSize) { value, bytes, offset in
            try (encodePredicate(value) ? ifTrue : ifFalse).write(value, into: &bytes, at: offset)
        } read: { bytes, offset in
            try (decodePredicate(bytes) ? ifTrue : ifFalse).read(bytes, at: offset)
        },
        encode: { value in
            guard case let .int(int) = value, let typed = int as? C.Encoded else {
                throw CodecsError.invalidPatternMatchValue
            }
            return typed
        },
        decode: { value in
            if let int = value as? Int {
                return .int(int)
            }
            throw CodecsError.invalidPatternMatchValue
        }
    )
}

public func getPredicateCodec(
    encodePredicate: @escaping @Sendable (CodecValue) -> Bool,
    decodePredicate: @escaping @Sendable (Data) -> Bool,
    ifTrue: AnyValueCodec,
    ifFalse: AnyValueCodec
) -> AnyValueCodec {
    getUnionCodec(
        [ifTrue, ifFalse],
        getIndexFromValue: { value in encodePredicate(value) ? 0 : 1 },
        getIndexFromBytes: { bytes, _ in decodePredicate(bytes) ? 0 : 1 }
    )
}

public func getPatternMatchCodec(
    _ patterns: [(value: @Sendable (CodecValue) -> Bool, bytes: @Sendable (Data) -> Bool, codec: AnyValueCodec)]
) -> AnyValueCodec {
    getUnionCodec(
        patterns.map(\.codec),
        getIndexFromValue: { value in
            guard let index = patterns.firstIndex(where: { $0.value(value) }) else {
                throw CodecsError.invalidPatternMatchValue
            }
            return index
        },
        getIndexFromBytes: { bytes, _ in
            guard let index = patterns.firstIndex(where: { $0.bytes(bytes) }) else {
                throw CodecsError.invalidPatternMatchBytes
            }
            return index
        }
    )
}

private func readMapEntries<K: Decoder, V: Decoder>(
    count: Int,
    key: K,
    value: V,
    bytes: Data,
    offset: Offset
) throws(CodecsError) -> ([MapEntry<K.Decoded, V.Decoded>], Offset) {
    var cursor = offset
    var entries: [MapEntry<K.Decoded, V.Decoded>] = []
    entries.reserveCapacity(count)
    for _ in 0..<count {
        let (decodedKey, afterKey) = try key.read(bytes, at: cursor)
        let (decodedValue, afterValue) = try value.read(bytes, at: afterKey)
        entries.append(MapEntry(decodedKey, decodedValue))
        cursor = afterValue
    }
    return (entries, cursor)
}

private func encodedSize<E: Encoder>(_ value: E.Encoded, using encoder: E) throws(CodecsError) -> Int {
    if let fixed = encoder as? any FixedSizeEncoder<E.Encoded> {
        return fixed.fixedSize
    }
    if let variable = encoder as? any VariableSizeEncoder<E.Encoded> {
        return try variable.getSizeFromValue(value)
    }
    return try encoder.encode(value).count
}

private func maxSize<E: Encoder>(_ encoder: E) -> Int? {
    if let fixed = encoder as? any FixedSizeEncoder<E.Encoded> {
        return fixed.fixedSize
    }
    if let variable = encoder as? any VariableSizeEncoder<E.Encoded> {
        return variable.maxSize
    }
    return nil
}

private func combinedMapMaxSize<K: Encoder, V: Encoder>(key: K, value: V, count: Int) -> Int? {
    guard let keyMax = maxSize(key), let valueMax = maxSize(value) else {
        return nil
    }
    return (keyMax + valueMax) * count
}

private func sumKnownSizes(_ sizes: [Int?]) -> Int? {
    sizes.reduce(0 as Int?) { total, size in
        guard let total, let size else { return nil }
        return total + size
    }
}

private func maxKnownSize(_ sizes: [Int?]) -> Int? {
    sizes.reduce(0 as Int?) { total, size in
        guard let total, let size else { return nil }
        return max(total, size)
    }
}

private func unionFixedSize(_ variants: [AnyValueCodec]) -> Int? {
    guard let first = variants.first else {
        return 0
    }
    guard let size = first.fixedSize else {
        return nil
    }
    return variants.allSatisfy { $0.fixedSize == size } ? size : nil
}

private func validUnionIndex(_ index: Int, variantCount: Int) throws(CodecsError) -> Int {
    guard index >= 0, index < variantCount else {
        throw CodecsError.unionVariantOutOfRange(variant: index, minRange: 0, maxRange: variantCount - 1)
    }
    return index
}

private func intFromValue(_ value: CodecValue) throws(CodecsError) -> Int {
    switch value {
    case let .int(value):
        return value
    case let .int64(value):
        guard value >= Int64(Int.min), value <= Int64(Int.max) else {
            throw CodecsError.invalidPatternMatchValue
        }
        return Int(value)
    case let .uint64(value):
        guard value <= UInt64(Int.max) else {
            throw CodecsError.invalidPatternMatchValue
        }
        return Int(value)
    default:
        throw CodecsError.invalidPatternMatchValue
    }
}

private func int64FromValue(_ value: CodecValue) throws(CodecsError) -> Int64 {
    switch value {
    case let .int(value):
        return Int64(value)
    case let .int64(value):
        return value
    default:
        throw CodecsError.invalidPatternMatchValue
    }
}

private func uint64FromValue(_ value: CodecValue) throws(CodecsError) -> UInt64 {
    switch value {
    case let .int(value) where value >= 0:
        return UInt64(value)
    case let .int64(value) where value >= 0:
        return UInt64(value)
    case let .uint64(value):
        return value
    default:
        throw CodecsError.invalidPatternMatchValue
    }
}

private func boolFromValue(_ value: CodecValue) throws(CodecsError) -> Bool {
    guard case let .bool(value) = value else {
        throw CodecsError.invalidPatternMatchValue
    }
    return value
}

private func stringFromValue(_ value: CodecValue) throws(CodecsError) -> String {
    guard case let .string(value) = value else {
        throw CodecsError.invalidPatternMatchValue
    }
    return value
}

private func bytesFromValue(_ value: CodecValue) throws(CodecsError) -> Data {
    guard case let .bytes(value) = value else {
        throw CodecsError.invalidPatternMatchValue
    }
    return value
}

private func arrayFromValue(_ value: CodecValue) throws(CodecsError) -> [CodecValue] {
    guard case let .array(values) = value else {
        throw CodecsError.invalidPatternMatchValue
    }
    return values
}

private func objectFromValue(_ value: CodecValue) throws(CodecsError) -> [String: CodecValue] {
    guard case let .object(values) = value else {
        throw CodecsError.invalidPatternMatchValue
    }
    return values
}

private func writeData(_ source: Data, into destination: inout Data, at offset: Offset, codecDescription: String) throws(CodecsError) {
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: offset, bytesLength: destination.count)
    let end = offset + source.count
    if end > destination.count {
        throw CodecsError.invalidByteLength(codecDescription: codecDescription, expected: end, bytesLength: destination.count)
    }
    destination.replaceSubrange(offset..<end, with: source)
}

private func suffixBytes(_ bytes: Data, from offset: Offset) -> Data {
    let lower = normalizedSliceIndex(offset, count: bytes.count)
    guard lower < bytes.count else {
        return Data()
    }
    return bytes.subdata(in: lower..<bytes.count)
}

private func sliceBytes(_ bytes: Data, offset: Offset, length: Int) -> Data {
    let lower = normalizedSliceIndex(offset, count: bytes.count)
    let upper = normalizedSliceIndex(offset + length, count: bytes.count)
    guard upper > lower else {
        return Data()
    }
    return bytes.subdata(in: lower..<upper)
}

private func normalizedSliceIndex(_ index: Int, count: Int) -> Int {
    if index < 0 {
        return max(count + index, 0)
    }
    return min(index, count)
}

private func castToCodecsError<T>(_ body: () throws -> T) throws(CodecsError) -> T {
    do {
        return try body()
    } catch let error as CodecsError {
        throw error
    } catch {
        throw CodecsError.invalidPatternMatchValue
    }
}

private extension AnyValueCodec {
    func mapEncodedDecoded(
        encode: @escaping @Sendable (CodecValue) throws -> CodecValue,
        decode: @escaping @Sendable (CodecValue) throws -> CodecValue
    ) -> AnyValueCodec {
        switch self {
        case let .fixed(codec):
            return valueCodec(codec, encode: encode, decode: decode)
        case let .variable(codec):
            return valueCodec(codec, encode: encode, decode: decode)
        }
    }
}

private struct NullableDecision {
    let isSome: Bool
    let valueOffset: Offset
    let noneOffset: Offset
}

private func nullableDecision<C: Decoder>(
    prefix: NullablePrefix,
    noneValue: NullableNoneValue,
    item: C,
    bytes: Data,
    offset: Offset
) throws(CodecsError) -> NullableDecision {
    switch prefix {
    case .none:
        if noneValue == .absent {
            return NullableDecision(isSome: offset < bytes.count, valueOffset: offset, noneOffset: offset)
        }
        let noneBytes = try noneBytesFor(noneValue, item: item)
        if containsBytes(bytes, noneBytes, at: offset) {
            return NullableDecision(isSome: false, valueOffset: offset, noneOffset: offset + noneBytes.count)
        }
        return NullableDecision(isSome: true, valueOffset: offset, noneOffset: offset)
    case let .fixed(prefixCodec):
        let (flag, valueOffset) = try prefixCodec.read(bytes, at: offset)
        if flag == 1 {
            return NullableDecision(isSome: true, valueOffset: valueOffset, noneOffset: valueOffset)
        }
        try validatePrefixedNullableNoneValue(noneValue, bytes: bytes, offset: valueOffset)
        let noneBytes = try noneBytesFor(noneValue, item: item)
        return NullableDecision(isSome: false, valueOffset: valueOffset, noneOffset: valueOffset + noneBytes.count)
    case let .variable(prefixCodec):
        let (flag, valueOffset) = try prefixCodec.read(bytes, at: offset)
        if flag == 1 {
            return NullableDecision(isSome: true, valueOffset: valueOffset, noneOffset: valueOffset)
        }
        try validatePrefixedNullableNoneValue(noneValue, bytes: bytes, offset: valueOffset)
        let noneBytes = try noneBytesFor(noneValue, item: item)
        return NullableDecision(isSome: false, valueOffset: valueOffset, noneOffset: valueOffset + noneBytes.count)
    }
}

private func validatePrefixedNullableNoneValue(
    _ noneValue: NullableNoneValue,
    bytes: Data,
    offset: Offset
) throws(CodecsError) {
    guard case let .bytes(expectedBytes) = noneValue else {
        return
    }
    guard containsBytes(bytes, expectedBytes, at: offset) else {
        throw CodecsError.invalidConstant(constant: expectedBytes, data: bytes, offset: offset)
    }
}

private func writePrefix(_ prefix: NullablePrefix, flag: Bool, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
    switch prefix {
    case .none:
        return offset
    case let .fixed(codec):
        return try codec.write(flag ? 1 : 0, into: &bytes, at: offset)
    case let .variable(codec):
        return try codec.write(flag ? 1 : 0, into: &bytes, at: offset)
    }
}

private func prefixSize(_ prefix: NullablePrefix, flag: Bool) throws(CodecsError) -> Int {
    switch prefix {
    case .none:
        return 0
    case let .fixed(codec):
        return codec.fixedSize
    case let .variable(codec):
        return try codec.getSizeFromValue(flag ? 1 : 0)
    }
}

private func fixedPrefixSize(_ prefix: NullablePrefix) throws(CodecsError) -> Int {
    switch prefix {
    case .none:
        return 0
    case let .fixed(codec):
        return codec.fixedSize
    case .variable:
        throw CodecsError.expectedFixedLength
    }
}

private func noneValueSize<C: Encoder>(_ noneValue: NullableNoneValue, item: C) throws(CodecsError) -> Int {
    switch noneValue {
    case .absent:
        return 0
    case .zeroes:
        guard let fixed = item as? any FixedSizeEncoder<C.Encoded> else {
            throw CodecsError.expectedFixedLength
        }
        return fixed.fixedSize
    case let .bytes(bytes):
        return bytes.count
    }
}

private func writeNoneValue<C: Encoder>(
    _ noneValue: NullableNoneValue,
    item: C,
    into bytes: inout Data,
    at offset: Offset
) throws(CodecsError) -> Offset {
    switch noneValue {
    case .absent:
        return offset
    case .zeroes:
        guard let fixed = item as? any FixedSizeEncoder<C.Encoded> else {
            throw CodecsError.expectedFixedLength
        }
        let zeroes = Data(repeating: 0, count: fixed.fixedSize)
        try writeData(zeroes, into: &bytes, at: offset, codecDescription: "nullable")
        return offset + zeroes.count
    case let .bytes(value):
        try writeData(value, into: &bytes, at: offset, codecDescription: "nullable")
        return offset + value.count
    }
}

private func noneBytesFor<C: Decoder>(_ noneValue: NullableNoneValue, item: C) throws(CodecsError) -> Data {
    switch noneValue {
    case .absent:
        return Data()
    case .zeroes:
        guard let fixed = item as? any FixedSizeDecoder<C.Decoded> else {
            throw CodecsError.expectedFixedLength
        }
        return Data(repeating: 0, count: fixed.fixedSize)
    case let .bytes(bytes):
        return bytes
    }
}

private func nullableMaxSize<C: Encoder>(item: C, prefix: NullablePrefix, noneValue: NullableNoneValue) -> Int? {
    let prefixMax: Int?
    switch prefix {
    case .none:
        prefixMax = 0
    case let .fixed(codec):
        prefixMax = codec.fixedSize
    case let .variable(codec):
        prefixMax = codec.maxSize
    }
    guard let prefixMax else {
        return nil
    }
    let someMax = maxSize(item)
    let noneMax: Int?
    switch noneValue {
    case .absent:
        noneMax = 0
    case .zeroes:
        noneMax = maxSize(item)
    case let .bytes(bytes):
        noneMax = bytes.count
    }
    guard let someMax, let noneMax else {
        return nil
    }
    return prefixMax + max(someMax, noneMax)
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
