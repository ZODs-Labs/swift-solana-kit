public import CodecsCore
import Foundation
public import SolanaErrors

// Swift has no runtime numeric union, so each codec uses the narrowest exact value type for its wire domain.
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

    public init(endian: Endian = .little) {
        self.endian = endian
    }
}

public func assertNumberIsBetweenForCodec<T: BinaryInteger & Sendable>(
    _ codecDescription: String,
    min: T,
    max: T,
    value: T
) throws(CodecsError) {
    if value < min || value > max {
        throw CodecsError.numberOutOfRange(
            codecDescription: codecDescription,
            min: String(describing: min),
            max: String(describing: max),
            value: String(describing: value)
        )
    }
}

public struct UInt128Value: Sendable, Equatable, Hashable, Comparable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public let high: UInt64
    public let low: UInt64

    public static let min = UInt128Value(high: 0, low: 0)
    public static let max = UInt128Value(high: UInt64.max, low: UInt64.max)

    public var description: String {
        decimalString(high: high, low: low)
    }

    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }

    public init(_ value: UInt64) {
        high = 0
        low = value
    }

    public init(integerLiteral value: UInt64) {
        self.init(value)
    }

    public static func < (lhs: UInt128Value, rhs: UInt128Value) -> Bool {
        if lhs.high != rhs.high {
            return lhs.high < rhs.high
        }
        return lhs.low < rhs.low
    }
}

public struct Int128Value: Sendable, Equatable, Hashable, Comparable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public let bitPattern: UInt128Value

    public static let min = Int128Value(bitPattern: UInt128Value(high: 0x8000_0000_0000_0000, low: 0))
    public static let max = Int128Value(bitPattern: UInt128Value(high: 0x7FFF_FFFF_FFFF_FFFF, low: UInt64.max))

    public var description: String {
        if isNegative {
            return "-\(twosComplementMagnitude.description)"
        }
        return bitPattern.description
    }

    public init(bitPattern: UInt128Value) {
        self.bitPattern = bitPattern
    }

    public init(_ value: Int64) {
        if value < 0 {
            bitPattern = UInt128Value(high: UInt64.max, low: UInt64(bitPattern: value))
        } else {
            bitPattern = UInt128Value(UInt64(value))
        }
    }

    public init(integerLiteral value: Int64) {
        self.init(value)
    }

    public static func < (lhs: Int128Value, rhs: Int128Value) -> Bool {
        let lhsNegative = lhs.isNegative
        let rhsNegative = rhs.isNegative
        if lhsNegative != rhsNegative {
            return lhsNegative
        }
        return lhs.bitPattern < rhs.bitPattern
    }

    var isNegative: Bool {
        (bitPattern.high & 0x8000_0000_0000_0000) != 0
    }

    var twosComplementMagnitude: UInt128Value {
        let low = (~bitPattern.low).addingReportingOverflow(1)
        let high = ~bitPattern.high &+ (low.overflow ? 1 : 0)
        return UInt128Value(high: high, low: low.partialValue)
    }
}

public func getF32Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Double> {
    createEncoder(fixedSize: 4) { value, bytes, offset in
        let bitPattern = Float(value).bitPattern
        try writeInteger(bitPattern, endian: config.endian, into: &bytes, at: offset, codecDescription: "f32")
        return offset + 4
    }
}

public func getF32Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Double> {
    createDecoder(fixedSize: 4) { bytes, offset in
        let bitPattern = try readInteger(UInt32.self, endian: config.endian, from: bytes, at: offset, codecDescription: "f32")
        return (Double(Float(bitPattern: bitPattern)), offset + 4)
    }
}

public func getF32Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Double, Double> {
    createCodec(fixedSize: 4) { value, bytes, offset in
        try getF32Encoder(config).write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getF32Decoder(config).read(bytes, at: offset)
    }
}

public func getF64Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Double> {
    createEncoder(fixedSize: 8) { value, bytes, offset in
        try writeInteger(value.bitPattern, endian: config.endian, into: &bytes, at: offset, codecDescription: "f64")
        return offset + 8
    }
}

public func getF64Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Double> {
    createDecoder(fixedSize: 8) { bytes, offset in
        let bitPattern = try readInteger(UInt64.self, endian: config.endian, from: bytes, at: offset, codecDescription: "f64")
        return (Double(bitPattern: bitPattern), offset + 8)
    }
}

public func getF64Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Double, Double> {
    createCodec(fixedSize: 8) { value, bytes, offset in
        try getF64Encoder(config).write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getF64Decoder(config).read(bytes, at: offset)
    }
}

public func getI8Encoder() -> AnyFixedSizeEncoder<Int> {
    createIntegerEncoder(name: "i8", size: 1, min: -128, max: 127) { value in
        UInt8(bitPattern: Int8(value))
    }
}

public func getI8Decoder() -> AnyFixedSizeDecoder<Int> {
    createIntegerDecoder(name: "i8", size: 1, config: NumberCodecConfig()) { raw in
        Int(Int8(bitPattern: raw))
    }
}

public func getI8Codec() -> AnyFixedSizeCodec<Int, Int> {
    createIntegerCodec(name: "i8", size: 1, min: -128, max: 127, config: NumberCodecConfig()) { value in
        UInt8(bitPattern: Int8(value))
    } decode: { raw in
        Int(Int8(bitPattern: raw))
    }
}

public func getI16Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int> {
    createIntegerEncoder(name: "i16", size: 2, min: Int(Int16.min), max: Int(Int16.max), config: config) { value in
        UInt16(bitPattern: Int16(value))
    }
}

public func getI16Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int> {
    createIntegerDecoder(name: "i16", size: 2, config: config) { raw in
        Int(Int16(bitPattern: raw))
    }
}

public func getI16Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int> {
    createIntegerCodec(name: "i16", size: 2, min: Int(Int16.min), max: Int(Int16.max), config: config) { value in
        UInt16(bitPattern: Int16(value))
    } decode: { raw in
        Int(Int16(bitPattern: raw))
    }
}

public func getI32Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int> {
    createIntegerEncoder(name: "i32", size: 4, min: Int(Int32.min), max: Int(Int32.max), config: config) { value in
        UInt32(bitPattern: Int32(value))
    }
}

public func getI32Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int> {
    createIntegerDecoder(name: "i32", size: 4, config: config) { raw in
        Int(Int32(bitPattern: raw))
    }
}

public func getI32Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int> {
    createIntegerCodec(name: "i32", size: 4, min: Int(Int32.min), max: Int(Int32.max), config: config) { value in
        UInt32(bitPattern: Int32(value))
    } decode: { raw in
        Int(Int32(bitPattern: raw))
    }
}

public func getI64Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int64> {
    createIntegerEncoder(name: "i64", size: 8, min: Int64.min, max: Int64.max, config: config) { value in
        UInt64(bitPattern: value)
    }
}

public func getI64Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int64> {
    createIntegerDecoder(name: "i64", size: 8, config: config) { raw in
        Int64(bitPattern: raw)
    }
}

public func getI64Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int64, Int64> {
    createIntegerCodec(name: "i64", size: 8, min: Int64.min, max: Int64.max, config: config) { value in
        UInt64(bitPattern: value)
    } decode: { raw in
        Int64(bitPattern: raw)
    }
}

public func getI128Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int128Value> {
    createEncoder(fixedSize: 16) { value, bytes, offset in
        try writeUInt128(value.bitPattern, endian: config.endian, into: &bytes, at: offset, codecDescription: "i128")
        return offset + 16
    }
}

public func getI128Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int128Value> {
    createDecoder(fixedSize: 16) { bytes, offset in
        let raw = try readUInt128(endian: config.endian, from: bytes, at: offset, codecDescription: "i128")
        return (Int128Value(bitPattern: raw), offset + 16)
    }
}

public func getI128Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int128Value, Int128Value> {
    createCodec(fixedSize: 16) { value, bytes, offset in
        try writeUInt128(value.bitPattern, endian: config.endian, into: &bytes, at: offset, codecDescription: "i128")
        return offset + 16
    } read: { bytes, offset in
        let raw = try readUInt128(endian: config.endian, from: bytes, at: offset, codecDescription: "i128")
        return (Int128Value(bitPattern: raw), offset + 16)
    }
}

public func getShortU16Encoder() -> AnyVariableSizeEncoder<Int> {
    createEncoder(maxSize: 3) { value in
        if value <= 0b0111_1111 {
            return 1
        }
        if value <= 0b0011_1111_1111_1111 {
            return 2
        }
        return 3
    } write: { value, bytes, offset in
        try assertNumberIsBetweenForCodec("shortU16", min: 0, max: 65_535, value: value)
        var encoded = Data([0])
        var index = 0
        while true {
            let alignedValue = value >> (index * 7)
            if alignedValue == 0 {
                break
            }
            let nextSevenBits = UInt8(alignedValue & 0b0111_1111)
            if index == encoded.count {
                encoded.append(nextSevenBits)
            } else {
                encoded[index] = nextSevenBits
            }
            if index > 0 {
                encoded[index - 1] |= 0b1000_0000
            }
            index += 1
        }
        try writeData(encoded, into: &bytes, at: offset, codecDescription: "shortU16")
        return offset + encoded.count
    }
}

public func getShortU16Decoder() -> AnyVariableSizeDecoder<Int> {
    createDecoder(maxSize: 3) { bytes, offset in
        var value = 0
        var byteCount = 0
        while true {
            byteCount += 1
            let byteIndex = byteCount - 1
            let currentByte = shortU16Byte(bytes, at: offset + byteIndex)
            let nextSevenBits = Int(currentByte & 0b0111_1111)
            value |= nextSevenBits << (byteIndex * 7)
            if (currentByte & 0b1000_0000) == 0 {
                break
            }
        }
        return (value, offset + byteCount)
    }
}

public func getShortU16Codec() -> AnyVariableSizeCodec<Int, Int> {
    createCodec(maxSize: 3) { value in
        try getShortU16Encoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getShortU16Encoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getShortU16Decoder().read(bytes, at: offset)
    }
}

public func getU8Encoder() -> AnyFixedSizeEncoder<Int> {
    createIntegerEncoder(name: "u8", size: 1, min: 0, max: 0xFF) { value in
        UInt8(value)
    }
}

public func getU8Decoder() -> AnyFixedSizeDecoder<Int> {
    createIntegerDecoder(name: "u8", size: 1, config: NumberCodecConfig()) { (raw: UInt8) in
        Int(raw)
    }
}

public func getU8Codec() -> AnyFixedSizeCodec<Int, Int> {
    createIntegerCodec(name: "u8", size: 1, min: 0, max: 0xFF, config: NumberCodecConfig()) { value in
        UInt8(value)
    } decode: { raw in
        Int(raw)
    }
}

public func getU16Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int> {
    createIntegerEncoder(name: "u16", size: 2, min: 0, max: 0xFFFF, config: config) { value in
        UInt16(value)
    }
}

public func getU16Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int> {
    createIntegerDecoder(name: "u16", size: 2, config: config) { (raw: UInt16) in
        Int(raw)
    }
}

public func getU16Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int> {
    createIntegerCodec(name: "u16", size: 2, min: 0, max: 0xFFFF, config: config) { value in
        UInt16(value)
    } decode: { raw in
        Int(raw)
    }
}

public func getU32Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<Int> {
    createIntegerEncoder(name: "u32", size: 4, min: 0, max: 0xFFFF_FFFF, config: config) { value in
        UInt32(value)
    }
}

public func getU32Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<Int> {
    createIntegerDecoder(name: "u32", size: 4, config: config) { (raw: UInt32) in
        Int(raw)
    }
}

public func getU32Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<Int, Int> {
    createIntegerCodec(name: "u32", size: 4, min: 0, max: 0xFFFF_FFFF, config: config) { value in
        UInt32(value)
    } decode: { raw in
        Int(raw)
    }
}

public func getU64Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<UInt64> {
    createIntegerEncoder(name: "u64", size: 8, min: UInt64.min, max: UInt64.max, config: config) { value in
        value
    }
}

public func getU64Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<UInt64> {
    createIntegerDecoder(name: "u64", size: 8, config: config) { raw in
        raw
    }
}

public func getU64Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<UInt64, UInt64> {
    createIntegerCodec(name: "u64", size: 8, min: UInt64.min, max: UInt64.max, config: config) { value in
        value
    } decode: { raw in
        raw
    }
}

public func getU128Encoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeEncoder<UInt128Value> {
    createEncoder(fixedSize: 16) { value, bytes, offset in
        try writeUInt128(value, endian: config.endian, into: &bytes, at: offset, codecDescription: "u128")
        return offset + 16
    }
}

public func getU128Decoder(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeDecoder<UInt128Value> {
    createDecoder(fixedSize: 16) { bytes, offset in
        let value = try readUInt128(endian: config.endian, from: bytes, at: offset, codecDescription: "u128")
        return (value, offset + 16)
    }
}

public func getU128Codec(_ config: NumberCodecConfig = NumberCodecConfig()) -> AnyFixedSizeCodec<UInt128Value, UInt128Value> {
    createCodec(fixedSize: 16) { value, bytes, offset in
        try writeUInt128(value, endian: config.endian, into: &bytes, at: offset, codecDescription: "u128")
        return offset + 16
    } read: { bytes, offset in
        let value = try readUInt128(endian: config.endian, from: bytes, at: offset, codecDescription: "u128")
        return (value, offset + 16)
    }
}

func createIntegerEncoder<Input: BinaryInteger & Sendable, Raw: FixedWidthInteger & Sendable>(
    name: String,
    size: Int,
    min: Input,
    max: Input,
    config: NumberCodecConfig = NumberCodecConfig(),
    encode: @escaping @Sendable (Input) -> Raw
) -> AnyFixedSizeEncoder<Input> {
    createEncoder(fixedSize: size) { value, bytes, offset in
        try assertNumberIsBetweenForCodec(name, min: min, max: max, value: value)
        try writeInteger(encode(value), endian: config.endian, into: &bytes, at: offset, codecDescription: name)
        return offset + size
    }
}

func createIntegerDecoder<Output, Raw: FixedWidthInteger & Sendable>(
    name: String,
    size: Int,
    config: NumberCodecConfig,
    decode: @escaping @Sendable (Raw) -> Output
) -> AnyFixedSizeDecoder<Output> {
    createDecoder(fixedSize: size) { bytes, offset in
        let raw = try readInteger(Raw.self, endian: config.endian, from: bytes, at: offset, codecDescription: name)
        return (decode(raw), offset + size)
    }
}

func createIntegerCodec<Input: BinaryInteger & Sendable, Output, Raw: FixedWidthInteger & Sendable>(
    name: String,
    size: Int,
    min: Input,
    max: Input,
    config: NumberCodecConfig,
    encode: @escaping @Sendable (Input) -> Raw,
    decode: @escaping @Sendable (Raw) -> Output
) -> AnyFixedSizeCodec<Input, Output> {
    createCodec(fixedSize: size) { value, bytes, offset in
        try assertNumberIsBetweenForCodec(name, min: min, max: max, value: value)
        try writeInteger(encode(value), endian: config.endian, into: &bytes, at: offset, codecDescription: name)
        return offset + size
    } read: { bytes, offset in
        let raw = try readInteger(Raw.self, endian: config.endian, from: bytes, at: offset, codecDescription: name)
        return (decode(raw), offset + size)
    }
}

func writeInteger<T: FixedWidthInteger>(
    _ value: T,
    endian: Endian,
    into bytes: inout Data,
    at offset: Offset,
    codecDescription: String
) throws(CodecsError) {
    var stored = endian == .little ? value.littleEndian : value.bigEndian
    let encoded = withUnsafeBytes(of: &stored) { Data($0) }
    try writeData(encoded, into: &bytes, at: offset, codecDescription: codecDescription)
}

func readInteger<T: FixedWidthInteger>(
    _ type: T.Type,
    endian: Endian,
    from bytes: Data,
    at offset: Offset,
    codecDescription: String
) throws(CodecsError) -> T {
    _ = type
    try assertByteArrayIsNotEmptyForCodec(codecDescription, bytes: bytes, offset: offset)
    try assertByteArrayHasEnoughBytesForCodec(codecDescription, expected: MemoryLayout<T>.size, bytes: bytes, offset: offset)
    let fixedBytes = toArrayBuffer(bytes, offset: offset, length: MemoryLayout<T>.size)
    if fixedBytes.count < MemoryLayout<T>.size {
        throw CodecsError.invalidByteLength(
            codecDescription: codecDescription,
            expected: MemoryLayout<T>.size,
            bytesLength: fixedBytes.count
        )
    }
    let raw = fixedBytes.withUnsafeBytes { rawBuffer in
        rawBuffer.loadUnaligned(as: T.self)
    }
    return endian == .little ? T(littleEndian: raw) : T(bigEndian: raw)
}

func writeUInt128(
    _ value: UInt128Value,
    endian: Endian,
    into bytes: inout Data,
    at offset: Offset,
    codecDescription: String
) throws(CodecsError) {
    var encoded = Data(count: 16)
    switch endian {
    case .little:
        try writeInteger(value.low, endian: .little, into: &encoded, at: 0, codecDescription: codecDescription)
        try writeInteger(value.high, endian: .little, into: &encoded, at: 8, codecDescription: codecDescription)
    case .big:
        try writeInteger(value.high, endian: .big, into: &encoded, at: 0, codecDescription: codecDescription)
        try writeInteger(value.low, endian: .big, into: &encoded, at: 8, codecDescription: codecDescription)
    }
    try writeData(encoded, into: &bytes, at: offset, codecDescription: codecDescription)
}

func readUInt128(
    endian: Endian,
    from bytes: Data,
    at offset: Offset,
    codecDescription: String
) throws(CodecsError) -> UInt128Value {
    try assertByteArrayIsNotEmptyForCodec(codecDescription, bytes: bytes, offset: offset)
    try assertByteArrayHasEnoughBytesForCodec(codecDescription, expected: 16, bytes: bytes, offset: offset)
    let fixedBytes = toArrayBuffer(bytes, offset: offset, length: 16)
    if fixedBytes.count < 16 {
        throw CodecsError.invalidByteLength(codecDescription: codecDescription, expected: 16, bytesLength: fixedBytes.count)
    }
    switch endian {
    case .little:
        let low = try readInteger(UInt64.self, endian: .little, from: fixedBytes, at: 0, codecDescription: codecDescription)
        let high = try readInteger(UInt64.self, endian: .little, from: fixedBytes, at: 8, codecDescription: codecDescription)
        return UInt128Value(high: high, low: low)
    case .big:
        let high = try readInteger(UInt64.self, endian: .big, from: fixedBytes, at: 0, codecDescription: codecDescription)
        let low = try readInteger(UInt64.self, endian: .big, from: fixedBytes, at: 8, codecDescription: codecDescription)
        return UInt128Value(high: high, low: low)
    }
}

func writeData(_ source: Data, into destination: inout Data, at offset: Offset, codecDescription: String) throws(CodecsError) {
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: offset, bytesLength: destination.count)
    let end = offset + source.count
    if end > destination.count {
        throw CodecsError.invalidByteLength(
            codecDescription: codecDescription,
            expected: end,
            bytesLength: destination.count
        )
    }
    destination.replaceSubrange(offset ..< end, with: source)
}

func shortU16Byte(_ bytes: Data, at index: Int) -> UInt8 {
    if index < 0 || index >= bytes.count {
        return 0
    }
    return bytes[index]
}

func decimalString(high: UInt64, low: UInt64) -> String {
    if high == 0 && low == 0 {
        return "0"
    }

    var workingHigh = high
    var workingLow = low
    var digits: [UInt8] = []
    while workingHigh != 0 || workingLow != 0 {
        let result = divideByTen(high: workingHigh, low: workingLow)
        digits.append(UInt8(result.remainder) + 48)
        workingHigh = result.high
        workingLow = result.low
    }
    return String(decoding: digits.reversed(), as: UTF8.self)
}

func divideByTen(high: UInt64, low: UInt64) -> (high: UInt64, low: UInt64, remainder: UInt64) {
    var quotientHigh: UInt64 = 0
    var quotientLow: UInt64 = 0
    var remainder: UInt64 = 0

    for bitIndex in stride(from: 127, through: 0, by: -1) {
        remainder <<= 1
        if bitIsSet(high: high, low: low, bitIndex: bitIndex) {
            remainder |= 1
        }
        if remainder >= 10 {
            remainder -= 10
            if bitIndex >= 64 {
                quotientHigh |= 1 << UInt64(bitIndex - 64)
            } else {
                quotientLow |= 1 << UInt64(bitIndex)
            }
        }
    }

    return (quotientHigh, quotientLow, remainder)
}

func bitIsSet(high: UInt64, low: UInt64, bitIndex: Int) -> Bool {
    if bitIndex >= 64 {
        return ((high >> UInt64(bitIndex - 64)) & 1) == 1
    }
    return ((low >> UInt64(bitIndex)) & 1) == 1
}
