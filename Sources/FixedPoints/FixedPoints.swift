import CodecsCore
public import Foundation
public import SolanaErrors

public enum FixedPointKind: String, Sendable, Equatable, Hashable, Codable {
    case decimalFixedPoint
    case binaryFixedPoint
}

public enum Signedness: String, Sendable, Equatable, Hashable, Codable {
    case signed
    case unsigned
}

public enum RoundingMode: String, Sendable, Equatable, Hashable, Codable {
    case ceil
    case floor
    case round
    case strict
    case trunc
}

public enum FixedPointEndian: Sendable, Equatable, Hashable, Codable {
    case little
    case big
}

public struct FixedPointRaw: Sendable, Equatable, Hashable, Comparable, Codable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int64

    public static let zero = FixedPointRaw(0)
    public static let one = FixedPointRaw(1)

    private var sign: Int8
    private var words: [UInt32]

    public var description: String {
        if sign == 0 {
            return "0"
        }
        var magnitude = words
        var chunks: [UInt32] = []
        while !magnitude.isEmpty {
            let remainder = Self.divideMagnitude(&magnitude, by: 1_000_000_000)
            chunks.append(remainder)
        }
        let mostSignificant = chunks.reversed()
        let digits = mostSignificant.enumerated()
            .map { index, chunk in index == 0 ? String(chunk) : String(format: "%09u", chunk) }
            .joined()
        return sign < 0 ? "-\(digits)" : digits
    }

    public init(integerLiteral value: Int64) {
        self.init(value)
    }

    public init(_ value: Int64) {
        if value == 0 {
            self.init(sign: 0, words: [])
            return
        }
        if value > 0 {
            self.init(UInt64(value))
            return
        }
        let bitPattern = UInt64(bitPattern: value)
        let magnitude = (~bitPattern).addingReportingOverflow(1)
        self.init(sign: -1, words: Self.words(from: magnitude.partialValue))
    }

    public init(_ value: UInt64) {
        self.init(sign: value == 0 ? 0 : 1, words: Self.words(from: value))
    }

    public init(decimalString value: String) throws(SolanaError) {
        self = try Self.parseDecimalInteger(value)
    }

    private init(sign: Int8, words: [UInt32]) {
        var normalized = words
        while normalized.last == 0 {
            normalized.removeLast()
        }
        self.words = normalized
        if normalized.isEmpty {
            self.sign = 0
        } else {
            self.sign = sign < 0 ? -1 : 1
        }
    }

    public static func < (lhs: FixedPointRaw, rhs: FixedPointRaw) -> Bool {
        if lhs.sign != rhs.sign {
            return lhs.sign < rhs.sign
        }
        if lhs.sign == 0 {
            return false
        }
        let comparison = compareMagnitude(lhs.words, rhs.words)
        return lhs.sign > 0 ? comparison < 0 : comparison > 0
    }

    static prefix func - (value: FixedPointRaw) -> FixedPointRaw {
        FixedPointRaw(sign: -value.sign, words: value.words)
    }

    static func + (lhs: FixedPointRaw, rhs: FixedPointRaw) -> FixedPointRaw {
        if lhs.sign == 0 {
            return rhs
        }
        if rhs.sign == 0 {
            return lhs
        }
        if lhs.sign == rhs.sign {
            return FixedPointRaw(sign: lhs.sign, words: addMagnitude(lhs.words, rhs.words))
        }
        let comparison = compareMagnitude(lhs.words, rhs.words)
        if comparison == 0 {
            return .zero
        }
        if comparison > 0 {
            return FixedPointRaw(sign: lhs.sign, words: subtractMagnitude(lhs.words, rhs.words))
        }
        return FixedPointRaw(sign: rhs.sign, words: subtractMagnitude(rhs.words, lhs.words))
    }

    static func - (lhs: FixedPointRaw, rhs: FixedPointRaw) -> FixedPointRaw {
        lhs + (-rhs)
    }

    static func * (lhs: FixedPointRaw, rhs: FixedPointRaw) -> FixedPointRaw {
        if lhs.sign == 0 || rhs.sign == 0 {
            return .zero
        }
        let sign: Int8 = lhs.sign == rhs.sign ? 1 : -1
        return FixedPointRaw(sign: sign, words: multiplyMagnitude(lhs.words, rhs.words))
    }

    func quotientAndRemainder(dividingBy divisor: FixedPointRaw) -> (quotient: FixedPointRaw, remainder: FixedPointRaw) {
        precondition(divisor.sign != 0)
        if sign == 0 {
            return (.zero, .zero)
        }
        var remainder = magnitude
        let divisorMagnitude = divisor.magnitude
        if remainder < divisorMagnitude {
            return (.zero, self)
        }

        var quotient = FixedPointRaw.zero
        let maxShift = remainder.bitWidth - divisorMagnitude.bitWidth
        if maxShift >= 0 {
            for shift in stride(from: maxShift, through: 0, by: -1) {
                let candidate = divisorMagnitude.shiftedLeft(shift)
                if candidate <= remainder {
                    remainder = remainder - candidate
                    quotient.setBit(shift)
                }
            }
        }

        let signedQuotient = FixedPointRaw(sign: sign == divisor.sign ? 1 : -1, words: quotient.words)
        let signedRemainder = self - (signedQuotient * divisor)
        return (signedQuotient, signedRemainder)
    }

    var isZero: Bool {
        sign == 0
    }

    var isNegative: Bool {
        sign < 0
    }

    var magnitude: FixedPointRaw {
        FixedPointRaw(sign: words.isEmpty ? 0 : 1, words: words)
    }

    var bitWidth: Int {
        guard let last = words.last else {
            return 0
        }
        return (words.count - 1) * 32 + (32 - last.leadingZeroBitCount)
    }

    func shiftedLeft(_ bits: Int) -> FixedPointRaw {
        if sign == 0 || bits == 0 {
            return self
        }
        let wordShift = bits / 32
        let bitShift = bits % 32
        var result = Array(repeating: UInt32(0), count: wordShift)
        var carry: UInt64 = 0
        for word in words {
            let shifted = (UInt64(word) << UInt64(bitShift)) | carry
            result.append(UInt32(shifted & 0xffff_ffff))
            carry = shifted >> 32
        }
        if carry != 0 {
            result.append(UInt32(carry))
        }
        return FixedPointRaw(sign: sign, words: result)
    }

    func multiplied(bySmall small: UInt32) -> FixedPointRaw {
        if sign == 0 || small == 0 {
            return .zero
        }
        var result: [UInt32] = []
        var carry: UInt64 = 0
        for word in words {
            let product = UInt64(word) * UInt64(small) + carry
            result.append(UInt32(product & 0xffff_ffff))
            carry = product >> 32
        }
        if carry != 0 {
            result.append(UInt32(carry))
        }
        return FixedPointRaw(sign: sign, words: result)
    }

    func byte(at index: Int) -> UInt8 {
        let wordIndex = index / 4
        guard wordIndex < words.count else {
            return 0
        }
        let shift = UInt32((index % 4) * 8)
        return UInt8((words[wordIndex] >> shift) & 0xff)
    }

    static func powerOf2(_ exponent: Int) -> FixedPointRaw {
        FixedPointRaw.one.shiftedLeft(exponent)
    }

    static func powerOf10(_ exponent: Int) -> FixedPointRaw {
        var result = FixedPointRaw.one
        if exponent > 0 {
            for _ in 0 ..< exponent {
                result = result.multiplied(bySmall: 10)
            }
        }
        return result
    }

    static func powerOf5(_ exponent: Int) -> FixedPointRaw {
        var result = FixedPointRaw.one
        if exponent > 0 {
            for _ in 0 ..< exponent {
                result = result.multiplied(bySmall: 5)
            }
        }
        return result
    }

    static func fromUnsignedBytes(_ bytes: Data, littleEndian: Bool) -> FixedPointRaw {
        var result = FixedPointRaw.zero
        for index in 0 ..< bytes.count {
            let byteIndex = littleEndian ? index : bytes.count - index - 1
            let value = FixedPointRaw(UInt64(bytes[byteIndex])).shiftedLeft(index * 8)
            result = result + value
        }
        return result
    }

    private mutating func setBit(_ bit: Int) {
        let wordIndex = bit / 32
        let bitIndex = UInt32(bit % 32)
        if words.count <= wordIndex {
            words.append(contentsOf: repeatElement(0, count: wordIndex - words.count + 1))
        }
        words[wordIndex] |= UInt32(1) << bitIndex
        if sign == 0 {
            sign = 1
        }
    }

    private static func words(from value: UInt64) -> [UInt32] {
        if value == 0 {
            return []
        }
        let low = UInt32(value & 0xffff_ffff)
        let high = UInt32(value >> 32)
        return high == 0 ? [low] : [low, high]
    }

    private static func parseDecimalInteger(_ value: String) throws(SolanaError) -> FixedPointRaw {
        guard !value.isEmpty else {
            throw fixedPointError(.fixedPointsInvalidString, ["kind": .string(FixedPointKind.decimalFixedPoint.rawValue), "input": .string(value)])
        }
        let isNegative = value.first == "-"
        let digits = isNegative ? String(value.dropFirst()) : value
        guard !digits.isEmpty, digits.unicodeScalars.allSatisfy(isAsciiDigit) else {
            throw fixedPointError(.fixedPointsInvalidString, ["kind": .string(FixedPointKind.decimalFixedPoint.rawValue), "input": .string(value)])
        }
        var result = FixedPointRaw.zero
        for scalar in digits.unicodeScalars {
            let digit = UInt32(scalar.value - asciiZero)
            result = result.multiplied(bySmall: 10) + FixedPointRaw(UInt64(digit))
        }
        return isNegative ? -result : result
    }

    private static func compareMagnitude(_ lhs: [UInt32], _ rhs: [UInt32]) -> Int {
        if lhs.count != rhs.count {
            return lhs.count < rhs.count ? -1 : 1
        }
        for index in stride(from: lhs.count - 1, through: 0, by: -1) {
            if lhs[index] != rhs[index] {
                return lhs[index] < rhs[index] ? -1 : 1
            }
            if index == 0 {
                break
            }
        }
        return 0
    }

    private static func addMagnitude(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        let count = max(lhs.count, rhs.count)
        var result: [UInt32] = []
        result.reserveCapacity(count + 1)
        var carry: UInt64 = 0
        for index in 0 ..< count {
            let sum = UInt64(index < lhs.count ? lhs[index] : 0) + UInt64(index < rhs.count ? rhs[index] : 0) + carry
            result.append(UInt32(sum & 0xffff_ffff))
            carry = sum >> 32
        }
        if carry != 0 {
            result.append(UInt32(carry))
        }
        return result
    }

    private static func subtractMagnitude(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        var result: [UInt32] = []
        result.reserveCapacity(lhs.count)
        var borrow: Int64 = 0
        for index in 0 ..< lhs.count {
            var difference = Int64(lhs[index]) - Int64(index < rhs.count ? rhs[index] : 0) - borrow
            if difference < 0 {
                difference += 1 << 32
                borrow = 1
            } else {
                borrow = 0
            }
            result.append(UInt32(difference))
        }
        return result
    }

    private static func multiplyMagnitude(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        if lhs.isEmpty || rhs.isEmpty {
            return []
        }
        var result = Array(repeating: UInt32(0), count: lhs.count + rhs.count + 1)
        for lhsIndex in lhs.indices {
            var carry: UInt64 = 0
            for rhsIndex in rhs.indices {
                let index = lhsIndex + rhsIndex
                let product = UInt64(lhs[lhsIndex]) * UInt64(rhs[rhsIndex]) + UInt64(result[index]) + carry
                result[index] = UInt32(product & 0xffff_ffff)
                carry = product >> 32
            }
            var index = lhsIndex + rhs.count
            while carry != 0 {
                let sum = UInt64(result[index]) + carry
                result[index] = UInt32(sum & 0xffff_ffff)
                carry = sum >> 32
                index += 1
            }
        }
        return result
    }

    private static func divideMagnitude(_ words: inout [UInt32], by divisor: UInt32) -> UInt32 {
        var remainder: UInt64 = 0
        for index in stride(from: words.count - 1, through: 0, by: -1) {
            let value = (remainder << 32) | UInt64(words[index])
            words[index] = UInt32(value / UInt64(divisor))
            remainder = value % UInt64(divisor)
            if index == 0 {
                break
            }
        }
        while words.last == 0 {
            words.removeLast()
        }
        return UInt32(remainder)
    }
}

public struct FixedPointCodecConfig: Sendable, Equatable, Hashable {
    public let endian: FixedPointEndian

    public init(endian: FixedPointEndian = .little) {
        self.endian = endian
    }
}

public struct FixedPointToStringOptions: Sendable, Equatable {
    public let decimals: Int?
    public let padTrailingZeros: Bool
    public let rounding: RoundingMode

    public init(decimals: Int? = nil, padTrailingZeros: Bool = false, rounding: RoundingMode = .strict) {
        self.decimals = decimals
        self.padTrailingZeros = padTrailingZeros
        self.rounding = rounding
    }
}

public struct DecimalFixedPoint: Sendable, Equatable, Hashable {
    public let kind: FixedPointKind
    public let raw: FixedPointRaw
    public let signedness: Signedness
    public let totalBits: Int
    public let decimals: Int

    fileprivate init(signedness: Signedness, totalBits: Int, decimals: Int, raw: FixedPointRaw) {
        kind = .decimalFixedPoint
        self.raw = raw
        self.signedness = signedness
        self.totalBits = totalBits
        self.decimals = decimals
    }
}

public struct BinaryFixedPoint: Sendable, Equatable, Hashable {
    public let kind: FixedPointKind
    public let raw: FixedPointRaw
    public let signedness: Signedness
    public let totalBits: Int
    public let fractionalBits: Int

    fileprivate init(signedness: Signedness, totalBits: Int, fractionalBits: Int, raw: FixedPointRaw) {
        kind = .binaryFixedPoint
        self.raw = raw
        self.signedness = signedness
        self.totalBits = totalBits
        self.fractionalBits = fractionalBits
    }
}

public struct DecimalFixedPointFactory: Sendable {
    let signedness: Signedness
    let totalBits: Int
    let decimals: Int

    public func callAsFunction(_ input: String, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint {
        let parsed = try parseDecimalString(.decimalFixedPoint, input)
        let raw: FixedPointRaw
        if parsed.decimals <= decimals {
            raw = parsed.raw * .powerOf10(decimals - parsed.decimals)
        } else {
            raw = try roundDivision(
                kind: .decimalFixedPoint,
                operation: "fromString",
                numerator: parsed.raw,
                denominator: .powerOf10(parsed.decimals - decimals),
                mode: rounding
            )
        }
        return try createDecimalFixedPoint(signedness: signedness, totalBits: totalBits, decimals: decimals, raw: raw)
    }
}

public struct RawDecimalFixedPointFactory: Sendable {
    let signedness: Signedness
    let totalBits: Int
    let decimals: Int

    public func callAsFunction(_ raw: FixedPointRaw) throws(SolanaError) -> DecimalFixedPoint {
        try createDecimalFixedPoint(signedness: signedness, totalBits: totalBits, decimals: decimals, raw: raw)
    }
}

public struct RatioDecimalFixedPointFactory: Sendable {
    let signedness: Signedness
    let totalBits: Int
    let decimals: Int

    public func callAsFunction(
        _ numerator: FixedPointRaw,
        _ denominator: FixedPointRaw,
        rounding: RoundingMode = .strict
    ) throws(SolanaError) -> DecimalFixedPoint {
        if denominator.isZero {
            throw fixedPointError(.fixedPointsInvalidZeroDenominatorRatio, [
                "denominator": .string(denominator.description),
                "kind": .string(FixedPointKind.decimalFixedPoint.rawValue),
                "numerator": .string(numerator.description),
            ])
        }
        let raw = try roundDivision(
            kind: .decimalFixedPoint,
            operation: "fromRatio",
            numerator: numerator * .powerOf10(decimals),
            denominator: denominator,
            mode: rounding
        )
        return try createDecimalFixedPoint(signedness: signedness, totalBits: totalBits, decimals: decimals, raw: raw)
    }
}

public struct BinaryFixedPointFactory: Sendable {
    let signedness: Signedness
    let totalBits: Int
    let fractionalBits: Int

    public func callAsFunction(_ input: String, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint {
        let parsed = try parseDecimalString(.binaryFixedPoint, input)
        let scaledRaw = parsed.raw * .powerOf2(fractionalBits)
        let raw = parsed.decimals == 0
            ? scaledRaw
            : try roundDivision(
                kind: .binaryFixedPoint,
                operation: "fromString",
                numerator: scaledRaw,
                denominator: .powerOf10(parsed.decimals),
                mode: rounding
            )
        return try createBinaryFixedPoint(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits, raw: raw)
    }
}

public struct RawBinaryFixedPointFactory: Sendable {
    let signedness: Signedness
    let totalBits: Int
    let fractionalBits: Int

    public func callAsFunction(_ raw: FixedPointRaw) throws(SolanaError) -> BinaryFixedPoint {
        try createBinaryFixedPoint(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits, raw: raw)
    }
}

public struct RatioBinaryFixedPointFactory: Sendable {
    let signedness: Signedness
    let totalBits: Int
    let fractionalBits: Int

    public func callAsFunction(
        _ numerator: FixedPointRaw,
        _ denominator: FixedPointRaw,
        rounding: RoundingMode = .strict
    ) throws(SolanaError) -> BinaryFixedPoint {
        if denominator.isZero {
            throw fixedPointError(.fixedPointsInvalidZeroDenominatorRatio, [
                "denominator": .string(denominator.description),
                "kind": .string(FixedPointKind.binaryFixedPoint.rawValue),
                "numerator": .string(numerator.description),
            ])
        }
        let raw = try roundDivision(
            kind: .binaryFixedPoint,
            operation: "fromRatio",
            numerator: numerator * .powerOf2(fractionalBits),
            denominator: denominator,
            mode: rounding
        )
        return try createBinaryFixedPoint(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits, raw: raw)
    }
}

public struct FixedPointFixedSizeEncoder<Encoded: Sendable>: Sendable {
    public let fixedSize: Int
    private let writeBody: @Sendable (Encoded, inout Data, Int) throws -> Int

    public init(fixedSize: Int, write: @escaping @Sendable (Encoded, inout Data, Int) throws -> Int) {
        self.fixedSize = fixedSize
        writeBody = write
    }

    public func encode(_ value: Encoded) throws -> Data {
        var bytes = Data(count: fixedSize)
        _ = try write(value, into: &bytes, at: 0)
        return bytes
    }

    public func write(_ value: Encoded, into bytes: inout Data, at offset: Int) throws -> Int {
        try writeBody(value, &bytes, offset)
    }
}

public struct FixedPointFixedSizeDecoder<Decoded: Sendable>: Sendable {
    public let fixedSize: Int
    private let readBody: @Sendable (Data, Int) throws -> (Decoded, Int)

    public init(fixedSize: Int, read: @escaping @Sendable (Data, Int) throws -> (Decoded, Int)) {
        self.fixedSize = fixedSize
        readBody = read
    }

    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Decoded {
        try read(bytes, at: offset).0
    }

    public func read(_ bytes: Data, at offset: Int) throws -> (Decoded, Int) {
        try readBody(bytes, offset)
    }
}

public struct FixedPointFixedSizeCodec<Encoded: Sendable, Decoded: Sendable>: Sendable {
    public let fixedSize: Int
    private let encoder: FixedPointFixedSizeEncoder<Encoded>
    private let decoder: FixedPointFixedSizeDecoder<Decoded>

    public init(encoder: FixedPointFixedSizeEncoder<Encoded>, decoder: FixedPointFixedSizeDecoder<Decoded>) {
        fixedSize = encoder.fixedSize
        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode(_ value: Encoded) throws -> Data {
        try encoder.encode(value)
    }

    public func write(_ value: Encoded, into bytes: inout Data, at offset: Int) throws -> Int {
        try encoder.write(value, into: &bytes, at: offset)
    }

    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Decoded {
        try decoder.decode(bytes, at: offset)
    }

    public func read(_ bytes: Data, at offset: Int) throws -> (Decoded, Int) {
        try decoder.read(bytes, at: offset)
    }
}

public func decimalFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int) throws(SolanaError) -> DecimalFixedPointFactory {
    try assertValidTotalBits(.decimalFixedPoint, totalBits)
    try assertValidDecimals(decimals)
    return DecimalFixedPointFactory(signedness: signedness, totalBits: totalBits, decimals: decimals)
}

public func rawDecimalFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int) throws(SolanaError) -> RawDecimalFixedPointFactory {
    try assertValidTotalBits(.decimalFixedPoint, totalBits)
    try assertValidDecimals(decimals)
    return RawDecimalFixedPointFactory(signedness: signedness, totalBits: totalBits, decimals: decimals)
}

public func ratioDecimalFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ decimals: Int) throws(SolanaError) -> RatioDecimalFixedPointFactory {
    try assertValidTotalBits(.decimalFixedPoint, totalBits)
    try assertValidDecimals(decimals)
    return RatioDecimalFixedPointFactory(signedness: signedness, totalBits: totalBits, decimals: decimals)
}

public func binaryFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int) throws(SolanaError) -> BinaryFixedPointFactory {
    try assertValidTotalBits(.binaryFixedPoint, totalBits)
    try assertValidFractionalBits(fractionalBits)
    try assertFractionalBitsFitInTotalBits(fractionalBits, totalBits)
    return BinaryFixedPointFactory(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits)
}

public func rawBinaryFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int) throws(SolanaError) -> RawBinaryFixedPointFactory {
    try assertValidTotalBits(.binaryFixedPoint, totalBits)
    try assertValidFractionalBits(fractionalBits)
    try assertFractionalBitsFitInTotalBits(fractionalBits, totalBits)
    return RawBinaryFixedPointFactory(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits)
}

public func ratioBinaryFixedPoint(_ signedness: Signedness, _ totalBits: Int, _ fractionalBits: Int) throws(SolanaError) -> RatioBinaryFixedPointFactory {
    try assertValidTotalBits(.binaryFixedPoint, totalBits)
    try assertValidFractionalBits(fractionalBits)
    try assertFractionalBitsFitInTotalBits(fractionalBits, totalBits)
    return RatioBinaryFixedPointFactory(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits)
}

public func addDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint {
    try assertDecimalShapeMatches("addDecimalFixedPoint", actual: b, signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals)
    let result = a.raw + b.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "add", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func subtractDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint {
    try assertDecimalShapeMatches("subtractDecimalFixedPoint", actual: b, signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals)
    let result = a.raw - b.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "subtract", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func multiplyDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: FixedPointRaw, rounding _: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint {
    let result = a.raw * b
    try assertNoArithmeticOverflow(kind: a.kind, operation: "multiply", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func multiplyDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint {
    try assertDecimalShapeMatches("multiplyDecimalFixedPoint", actual: b, signedness: a.signedness)
    let result = try roundDivision(kind: a.kind, operation: "multiply", numerator: a.raw * b.raw, denominator: .powerOf10(b.decimals), mode: rounding)
    try assertNoArithmeticOverflow(kind: a.kind, operation: "multiply", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func divideDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint {
    try assertNoDivisionByZero(kind: a.kind, signedness: a.signedness, totalBits: a.totalBits, denominator: b)
    let result = try roundDivision(kind: a.kind, operation: "divide", numerator: a.raw, denominator: b, mode: rounding)
    try assertNoArithmeticOverflow(kind: a.kind, operation: "divide", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func divideDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> DecimalFixedPoint {
    try assertDecimalShapeMatches("divideDecimalFixedPoint", actual: b, signedness: a.signedness)
    try assertNoDivisionByZero(kind: a.kind, signedness: a.signedness, totalBits: a.totalBits, denominator: b.raw)
    let result = try roundDivision(kind: a.kind, operation: "divide", numerator: a.raw * .powerOf10(b.decimals), denominator: b.raw, mode: rounding)
    try assertNoArithmeticOverflow(kind: a.kind, operation: "divide", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func negateDecimalFixedPoint(_ a: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint {
    try assertDecimalShapeMatches("negateDecimalFixedPoint", actual: a, signedness: .signed)
    let result = -a.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "negate", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func absoluteDecimalFixedPoint(_ a: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint {
    let result = a.raw.isNegative ? -a.raw : a.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "absolute", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return DecimalFixedPoint(signedness: a.signedness, totalBits: a.totalBits, decimals: a.decimals, raw: result)
}

public func cmpDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Int {
    try assertDecimalShapeMatches("cmpDecimalFixedPoint", actual: b, decimals: a.decimals)
    if a.raw < b.raw {
        return -1
    }
    if a.raw > b.raw {
        return 1
    }
    return 0
}

public func eqDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool {
    try cmpDecimalFixedPoint(a, b) == 0
}

public func ltDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool {
    try cmpDecimalFixedPoint(a, b) < 0
}

public func lteDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool {
    try cmpDecimalFixedPoint(a, b) <= 0
}

public func gtDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool {
    try cmpDecimalFixedPoint(a, b) > 0
}

public func gteDecimalFixedPoint(_ a: DecimalFixedPoint, _ b: DecimalFixedPoint) throws(SolanaError) -> Bool {
    try cmpDecimalFixedPoint(a, b) >= 0
}

public func toUnsignedDecimalFixedPoint(_ value: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint {
    if value.signedness == .unsigned {
        return value
    }
    try assertRawFitsInRange(kind: .decimalFixedPoint, signedness: .unsigned, totalBits: value.totalBits, raw: value.raw)
    return DecimalFixedPoint(signedness: .unsigned, totalBits: value.totalBits, decimals: value.decimals, raw: value.raw)
}

public func toSignedDecimalFixedPoint(_ value: DecimalFixedPoint) throws(SolanaError) -> DecimalFixedPoint {
    if value.signedness == .signed {
        return value
    }
    try assertRawFitsInRange(kind: .decimalFixedPoint, signedness: .signed, totalBits: value.totalBits, raw: value.raw)
    return DecimalFixedPoint(signedness: .signed, totalBits: value.totalBits, decimals: value.decimals, raw: value.raw)
}

public func rescaleDecimalFixedPoint(
    _ value: DecimalFixedPoint,
    _ newTotalBits: Int,
    _ newDecimals: Int,
    rounding: RoundingMode = .strict
) throws(SolanaError) -> DecimalFixedPoint {
    try assertValidTotalBits(.decimalFixedPoint, newTotalBits)
    try assertValidDecimals(newDecimals)
    if value.totalBits == newTotalBits, value.decimals == newDecimals {
        return value
    }
    let result: FixedPointRaw
    if newDecimals == value.decimals {
        result = value.raw
    } else if newDecimals > value.decimals {
        result = value.raw * .powerOf10(newDecimals - value.decimals)
    } else {
        result = try roundDivision(kind: .decimalFixedPoint, operation: "rescale", numerator: value.raw, denominator: .powerOf10(value.decimals - newDecimals), mode: rounding)
    }
    try assertNoArithmeticOverflow(kind: .decimalFixedPoint, operation: "rescale", signedness: value.signedness, totalBits: newTotalBits, result: result)
    return DecimalFixedPoint(signedness: value.signedness, totalBits: newTotalBits, decimals: newDecimals, raw: result)
}

public func decimalFixedPointToString(_ value: DecimalFixedPoint, options: FixedPointToStringOptions = FixedPointToStringOptions()) throws(SolanaError) -> String {
    let scaled = try applyDecimalsOption(kind: .decimalFixedPoint, raw: value.raw, currentDecimals: value.decimals, options: options)
    return formatScaledBigint(scaled.raw, decimals: scaled.decimals, padTrailingZeros: options.padTrailingZeros)
}

public func formatDecimalFixedPoint(_ formatter: NumberFormatter, _ value: DecimalFixedPoint) -> String {
    formatFixedPoint(formatter, raw: value.raw, decimals: value.decimals) ?? ((try? decimalFixedPointToString(value)) ?? value.raw.description)
}

public func decimalFixedPointToNumber(_ value: DecimalFixedPoint) -> Double {
    (Double(value.raw.description) ?? 0) / pow(10, Double(value.decimals))
}

public func addBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint {
    try assertBinaryShapeMatches("addBinaryFixedPoint", actual: b, signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits)
    let result = a.raw + b.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "add", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func subtractBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint {
    try assertBinaryShapeMatches("subtractBinaryFixedPoint", actual: b, signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits)
    let result = a.raw - b.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "subtract", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func multiplyBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: FixedPointRaw, rounding _: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint {
    let result = a.raw * b
    try assertNoArithmeticOverflow(kind: a.kind, operation: "multiply", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func multiplyBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint {
    try assertBinaryShapeMatches("multiplyBinaryFixedPoint", actual: b, signedness: a.signedness)
    let result = try roundDivision(kind: a.kind, operation: "multiply", numerator: a.raw * b.raw, denominator: .powerOf2(b.fractionalBits), mode: rounding)
    try assertNoArithmeticOverflow(kind: a.kind, operation: "multiply", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func divideBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: FixedPointRaw, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint {
    try assertNoDivisionByZero(kind: a.kind, signedness: a.signedness, totalBits: a.totalBits, denominator: b)
    let result = try roundDivision(kind: a.kind, operation: "divide", numerator: a.raw, denominator: b, mode: rounding)
    try assertNoArithmeticOverflow(kind: a.kind, operation: "divide", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func divideBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint, rounding: RoundingMode = .strict) throws(SolanaError) -> BinaryFixedPoint {
    try assertBinaryShapeMatches("divideBinaryFixedPoint", actual: b, signedness: a.signedness)
    try assertNoDivisionByZero(kind: a.kind, signedness: a.signedness, totalBits: a.totalBits, denominator: b.raw)
    let result = try roundDivision(kind: a.kind, operation: "divide", numerator: a.raw * .powerOf2(b.fractionalBits), denominator: b.raw, mode: rounding)
    try assertNoArithmeticOverflow(kind: a.kind, operation: "divide", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func negateBinaryFixedPoint(_ a: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint {
    try assertBinaryShapeMatches("negateBinaryFixedPoint", actual: a, signedness: .signed)
    let result = -a.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "negate", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func absoluteBinaryFixedPoint(_ a: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint {
    let result = a.raw.isNegative ? -a.raw : a.raw
    try assertNoArithmeticOverflow(kind: a.kind, operation: "absolute", signedness: a.signedness, totalBits: a.totalBits, result: result)
    return BinaryFixedPoint(signedness: a.signedness, totalBits: a.totalBits, fractionalBits: a.fractionalBits, raw: result)
}

public func cmpBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Int {
    try assertBinaryShapeMatches("cmpBinaryFixedPoint", actual: b, fractionalBits: a.fractionalBits)
    if a.raw < b.raw {
        return -1
    }
    if a.raw > b.raw {
        return 1
    }
    return 0
}

public func eqBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool {
    try cmpBinaryFixedPoint(a, b) == 0
}

public func ltBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool {
    try cmpBinaryFixedPoint(a, b) < 0
}

public func lteBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool {
    try cmpBinaryFixedPoint(a, b) <= 0
}

public func gtBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool {
    try cmpBinaryFixedPoint(a, b) > 0
}

public func gteBinaryFixedPoint(_ a: BinaryFixedPoint, _ b: BinaryFixedPoint) throws(SolanaError) -> Bool {
    try cmpBinaryFixedPoint(a, b) >= 0
}

public func binaryFixedPointToBase10(_ value: BinaryFixedPoint) -> (raw: FixedPointRaw, decimals: Int) {
    let decimals = value.fractionalBits
    let raw = decimals == 0 ? value.raw : value.raw * .powerOf5(decimals)
    return (raw, decimals)
}

public func toUnsignedBinaryFixedPoint(_ value: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint {
    if value.signedness == .unsigned {
        return value
    }
    try assertRawFitsInRange(kind: .binaryFixedPoint, signedness: .unsigned, totalBits: value.totalBits, raw: value.raw)
    return BinaryFixedPoint(signedness: .unsigned, totalBits: value.totalBits, fractionalBits: value.fractionalBits, raw: value.raw)
}

public func toSignedBinaryFixedPoint(_ value: BinaryFixedPoint) throws(SolanaError) -> BinaryFixedPoint {
    if value.signedness == .signed {
        return value
    }
    try assertRawFitsInRange(kind: .binaryFixedPoint, signedness: .signed, totalBits: value.totalBits, raw: value.raw)
    return BinaryFixedPoint(signedness: .signed, totalBits: value.totalBits, fractionalBits: value.fractionalBits, raw: value.raw)
}

public func rescaleBinaryFixedPoint(
    _ value: BinaryFixedPoint,
    _ newTotalBits: Int,
    _ newFractionalBits: Int,
    rounding: RoundingMode = .strict
) throws(SolanaError) -> BinaryFixedPoint {
    try assertValidTotalBits(.binaryFixedPoint, newTotalBits)
    try assertValidFractionalBits(newFractionalBits)
    try assertFractionalBitsFitInTotalBits(newFractionalBits, newTotalBits)
    if value.totalBits == newTotalBits, value.fractionalBits == newFractionalBits {
        return value
    }
    let result: FixedPointRaw
    if newFractionalBits == value.fractionalBits {
        result = value.raw
    } else if newFractionalBits > value.fractionalBits {
        result = value.raw.shiftedLeft(newFractionalBits - value.fractionalBits)
    } else {
        result = try roundDivision(kind: .binaryFixedPoint, operation: "rescale", numerator: value.raw, denominator: .powerOf2(value.fractionalBits - newFractionalBits), mode: rounding)
    }
    try assertNoArithmeticOverflow(kind: .binaryFixedPoint, operation: "rescale", signedness: value.signedness, totalBits: newTotalBits, result: result)
    return BinaryFixedPoint(signedness: value.signedness, totalBits: newTotalBits, fractionalBits: newFractionalBits, raw: result)
}

public func binaryFixedPointToString(_ value: BinaryFixedPoint, options: FixedPointToStringOptions = FixedPointToStringOptions()) throws(SolanaError) -> String {
    let base10 = binaryFixedPointToBase10(value)
    let scaled = try applyDecimalsOption(kind: .binaryFixedPoint, raw: base10.raw, currentDecimals: base10.decimals, options: options)
    return formatScaledBigint(scaled.raw, decimals: scaled.decimals, padTrailingZeros: options.padTrailingZeros)
}

public func formatBinaryFixedPoint(_ formatter: NumberFormatter, _ value: BinaryFixedPoint) -> String {
    let base10 = binaryFixedPointToBase10(value)
    return formatFixedPoint(formatter, raw: base10.raw, decimals: base10.decimals) ?? ((try? binaryFixedPointToString(value)) ?? value.raw.description)
}

public func binaryFixedPointToNumber(_ value: BinaryFixedPoint) -> Double {
    if value.fractionalBits == 0 {
        return Double(value.raw.description) ?? 0
    }
    let scale = FixedPointRaw.powerOf2(value.fractionalBits)
    let division = value.raw.quotientAndRemainder(dividingBy: scale)
    let integer = Double(division.quotient.description) ?? 0
    let fraction = (Double(division.remainder.description) ?? 0) / pow(2, Double(value.fractionalBits))
    return integer + fraction
}

public func assertIsDecimalFixedPoint(
    _ value: DecimalFixedPoint,
    signedness: Signedness? = nil,
    totalBits: Int? = nil,
    decimals: Int? = nil
) throws(SolanaError) {
    try assertDecimalShapeMatches("assertIsDecimalFixedPoint", actual: value, signedness: signedness, totalBits: totalBits, decimals: decimals)
    try assertRawFitsInRange(kind: .decimalFixedPoint, signedness: value.signedness, totalBits: value.totalBits, raw: value.raw)
}

public func isDecimalFixedPoint(_ value: DecimalFixedPoint, signedness: Signedness? = nil, totalBits: Int? = nil, decimals: Int? = nil) -> Bool {
    do {
        try assertIsDecimalFixedPoint(value, signedness: signedness, totalBits: totalBits, decimals: decimals)
        return true
    } catch {
        return false
    }
}

public func assertIsBinaryFixedPoint(
    _ value: BinaryFixedPoint,
    signedness: Signedness? = nil,
    totalBits: Int? = nil,
    fractionalBits: Int? = nil
) throws(SolanaError) {
    try assertBinaryShapeMatches("assertIsBinaryFixedPoint", actual: value, signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits)
    try assertFractionalBitsFitInTotalBits(value.fractionalBits, value.totalBits)
    try assertRawFitsInRange(kind: .binaryFixedPoint, signedness: value.signedness, totalBits: value.totalBits, raw: value.raw)
}

public func isBinaryFixedPoint(_ value: BinaryFixedPoint, signedness: Signedness? = nil, totalBits: Int? = nil, fractionalBits: Int? = nil) -> Bool {
    do {
        try assertIsBinaryFixedPoint(value, signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits)
        return true
    } catch {
        return false
    }
}

public func getDecimalFixedPointEncoder(
    _ signedness: Signedness,
    _ totalBits: Int,
    _ decimals: Int,
    config: FixedPointCodecConfig = FixedPointCodecConfig()
) throws(SolanaError) -> FixedPointFixedSizeEncoder<DecimalFixedPoint> {
    try assertValidTotalBits(.decimalFixedPoint, totalBits)
    try assertValidDecimals(decimals)
    try assertTotalBitsIsByteAligned(.decimalFixedPoint, totalBits)
    let byteSize = totalBits / 8
    let littleEndian = config.endian != .big
    return FixedPointFixedSizeEncoder(fixedSize: byteSize) { value, bytes, offset in
        try assertDecimalShapeMatches("getDecimalFixedPointEncoder", actual: value, signedness: signedness, totalBits: totalBits, decimals: decimals)
        try writeRawBigInt(value.raw, into: &bytes, at: offset, byteSize: byteSize, signedness: signedness, littleEndian: littleEndian, codecDescription: "getDecimalFixedPointEncoder")
        return offset + byteSize
    }
}

public func getDecimalFixedPointDecoder(
    _ signedness: Signedness,
    _ totalBits: Int,
    _ decimals: Int,
    config: FixedPointCodecConfig = FixedPointCodecConfig()
) throws(SolanaError) -> FixedPointFixedSizeDecoder<DecimalFixedPoint> {
    try assertValidTotalBits(.decimalFixedPoint, totalBits)
    try assertValidDecimals(decimals)
    try assertTotalBitsIsByteAligned(.decimalFixedPoint, totalBits)
    let byteSize = totalBits / 8
    let littleEndian = config.endian != .big
    return FixedPointFixedSizeDecoder(fixedSize: byteSize) { bytes, offset in
        try assertReadable(bytes, offset: offset, size: byteSize, codecDescription: "getDecimalFixedPointDecoder")
        let raw = readRawBigInt(from: bytes, at: offset, byteSize: byteSize, signedness: signedness, littleEndian: littleEndian)
        return (DecimalFixedPoint(signedness: signedness, totalBits: totalBits, decimals: decimals, raw: raw), offset + byteSize)
    }
}

public func getDecimalFixedPointCodec(
    _ signedness: Signedness,
    _ totalBits: Int,
    _ decimals: Int,
    config: FixedPointCodecConfig = FixedPointCodecConfig()
) throws(SolanaError) -> FixedPointFixedSizeCodec<DecimalFixedPoint, DecimalFixedPoint> {
    FixedPointFixedSizeCodec(
        encoder: try getDecimalFixedPointEncoder(signedness, totalBits, decimals, config: config),
        decoder: try getDecimalFixedPointDecoder(signedness, totalBits, decimals, config: config)
    )
}

public func getBinaryFixedPointEncoder(
    _ signedness: Signedness,
    _ totalBits: Int,
    _ fractionalBits: Int,
    config: FixedPointCodecConfig = FixedPointCodecConfig()
) throws(SolanaError) -> FixedPointFixedSizeEncoder<BinaryFixedPoint> {
    try assertValidTotalBits(.binaryFixedPoint, totalBits)
    try assertValidFractionalBits(fractionalBits)
    try assertFractionalBitsFitInTotalBits(fractionalBits, totalBits)
    try assertTotalBitsIsByteAligned(.binaryFixedPoint, totalBits)
    let byteSize = totalBits / 8
    let littleEndian = config.endian != .big
    return FixedPointFixedSizeEncoder(fixedSize: byteSize) { value, bytes, offset in
        try assertBinaryShapeMatches("getBinaryFixedPointEncoder", actual: value, signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits)
        try writeRawBigInt(value.raw, into: &bytes, at: offset, byteSize: byteSize, signedness: signedness, littleEndian: littleEndian, codecDescription: "getBinaryFixedPointEncoder")
        return offset + byteSize
    }
}

public func getBinaryFixedPointDecoder(
    _ signedness: Signedness,
    _ totalBits: Int,
    _ fractionalBits: Int,
    config: FixedPointCodecConfig = FixedPointCodecConfig()
) throws(SolanaError) -> FixedPointFixedSizeDecoder<BinaryFixedPoint> {
    try assertValidTotalBits(.binaryFixedPoint, totalBits)
    try assertValidFractionalBits(fractionalBits)
    try assertFractionalBitsFitInTotalBits(fractionalBits, totalBits)
    try assertTotalBitsIsByteAligned(.binaryFixedPoint, totalBits)
    let byteSize = totalBits / 8
    let littleEndian = config.endian != .big
    return FixedPointFixedSizeDecoder(fixedSize: byteSize) { bytes, offset in
        try assertReadable(bytes, offset: offset, size: byteSize, codecDescription: "getBinaryFixedPointDecoder")
        let raw = readRawBigInt(from: bytes, at: offset, byteSize: byteSize, signedness: signedness, littleEndian: littleEndian)
        return (BinaryFixedPoint(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits, raw: raw), offset + byteSize)
    }
}

public func getBinaryFixedPointCodec(
    _ signedness: Signedness,
    _ totalBits: Int,
    _ fractionalBits: Int,
    config: FixedPointCodecConfig = FixedPointCodecConfig()
) throws(SolanaError) -> FixedPointFixedSizeCodec<BinaryFixedPoint, BinaryFixedPoint> {
    FixedPointFixedSizeCodec(
        encoder: try getBinaryFixedPointEncoder(signedness, totalBits, fractionalBits, config: config),
        decoder: try getBinaryFixedPointDecoder(signedness, totalBits, fractionalBits, config: config)
    )
}

private struct ParsedDecimalString {
    let raw: FixedPointRaw
    let decimals: Int
}

private struct Shape {
    let kind: FixedPointKind
    let scale: Int
    let scaleLabel: String
    let signedness: Signedness
    let totalBits: Int
}

private func parseDecimalString(_ kind: FixedPointKind, _ input: String) throws(SolanaError) -> ParsedDecimalString {
    guard !input.isEmpty else {
        throw invalidString(kind: kind, input: input)
    }
    let isNegative = input.first == "-"
    let unsigned = isNegative ? String(input.dropFirst()) : input
    guard !unsigned.isEmpty else {
        throw invalidString(kind: kind, input: input)
    }
    let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2 else {
        throw invalidString(kind: kind, input: input)
    }
    if parts.count == 1 {
        guard !parts[0].isEmpty, allAsciiDigits(parts[0]) else {
            throw invalidString(kind: kind, input: input)
        }
        let raw = try FixedPointRaw(decimalString: (isNegative ? "-" : "") + String(parts[0]))
        return ParsedDecimalString(raw: raw, decimals: 0)
    }

    let integerPart = String(parts[0])
    let fractionalPart = String(parts[1])
    guard !(integerPart.isEmpty && fractionalPart.isEmpty),
          allAsciiDigits(integerPart),
          allAsciiDigits(fractionalPart) else {
        throw invalidString(kind: kind, input: input)
    }
    let digits = (integerPart.isEmpty ? "0" : integerPart) + fractionalPart
    let raw = try FixedPointRaw(decimalString: (isNegative ? "-" : "") + digits)
    return ParsedDecimalString(raw: raw, decimals: fractionalPart.count)
}

private func invalidString(kind: FixedPointKind, input: String) -> SolanaError {
    fixedPointError(.fixedPointsInvalidString, [
        "input": .string(input),
        "kind": .string(kind.rawValue),
    ])
}

private let asciiZero = UnicodeScalar("0").value
private let asciiNine = UnicodeScalar("9").value

private func isAsciiDigit(_ scalar: UnicodeScalar) -> Bool {
    scalar.value >= asciiZero && scalar.value <= asciiNine
}

private func allAsciiDigits<S: StringProtocol>(_ value: S) -> Bool {
    value.unicodeScalars.allSatisfy(isAsciiDigit)
}

private func createDecimalFixedPoint(signedness: Signedness, totalBits: Int, decimals: Int, raw: FixedPointRaw) throws(SolanaError) -> DecimalFixedPoint {
    try assertRawFitsInRange(kind: .decimalFixedPoint, signedness: signedness, totalBits: totalBits, raw: raw)
    return DecimalFixedPoint(signedness: signedness, totalBits: totalBits, decimals: decimals, raw: raw)
}

private func createBinaryFixedPoint(signedness: Signedness, totalBits: Int, fractionalBits: Int, raw: FixedPointRaw) throws(SolanaError) -> BinaryFixedPoint {
    try assertRawFitsInRange(kind: .binaryFixedPoint, signedness: signedness, totalBits: totalBits, raw: raw)
    return BinaryFixedPoint(signedness: signedness, totalBits: totalBits, fractionalBits: fractionalBits, raw: raw)
}

private func getRawRange(signedness: Signedness, totalBits: Int) -> (min: FixedPointRaw, max: FixedPointRaw) {
    if signedness == .signed {
        let half = FixedPointRaw.powerOf2(totalBits - 1)
        return (-half, half - 1)
    }
    return (.zero, FixedPointRaw.powerOf2(totalBits) - 1)
}

private func assertValidTotalBits(_ kind: FixedPointKind, _ totalBits: Int) throws(SolanaError) {
    if totalBits <= 0 {
        throw fixedPointError(.fixedPointsInvalidTotalBits, [
            "kind": .string(kind.rawValue),
            "totalBits": .int(totalBits),
        ])
    }
}

private func assertValidFractionalBits(_ fractionalBits: Int) throws(SolanaError) {
    if fractionalBits < 0 {
        throw fixedPointError(.fixedPointsInvalidFractionalBits, [
            "fractionalBits": .int(fractionalBits),
        ])
    }
}

private func assertValidDecimals(_ decimals: Int) throws(SolanaError) {
    if decimals < 0 {
        throw fixedPointError(.fixedPointsInvalidDecimals, [
            "decimals": .int(decimals),
        ])
    }
}

private func assertFractionalBitsFitInTotalBits(_ fractionalBits: Int, _ totalBits: Int) throws(SolanaError) {
    if fractionalBits > totalBits {
        throw fixedPointError(.fixedPointsFractionalBitsExceedTotalBits, [
            "fractionalBits": .int(fractionalBits),
            "totalBits": .int(totalBits),
        ])
    }
}

private func assertTotalBitsIsByteAligned(_ kind: FixedPointKind, _ totalBits: Int) throws(SolanaError) {
    if totalBits % 8 != 0 {
        throw fixedPointError(.fixedPointsTotalBitsNotByteAligned, [
            "kind": .string(kind.rawValue),
            "totalBits": .int(totalBits),
        ])
    }
}

private func assertRawFitsInRange(kind: FixedPointKind, signedness: Signedness, totalBits: Int, raw: FixedPointRaw) throws(SolanaError) {
    let range = getRawRange(signedness: signedness, totalBits: totalBits)
    if raw < range.min || raw > range.max {
        throw fixedPointError(.fixedPointsValueOutOfRange, [
            "kind": .string(kind.rawValue),
            "max": .string(range.max.description),
            "min": .string(range.min.description),
            "raw": .string(raw.description),
            "signedness": .string(signedness.rawValue),
            "totalBits": .int(totalBits),
        ])
    }
}

private func assertNoArithmeticOverflow(
    kind: FixedPointKind,
    operation: String,
    signedness: Signedness,
    totalBits: Int,
    result: FixedPointRaw
) throws(SolanaError) {
    let range = getRawRange(signedness: signedness, totalBits: totalBits)
    if result < range.min || result > range.max {
        throw fixedPointError(.fixedPointsArithmeticOverflow, [
            "kind": .string(kind.rawValue),
            "max": .string(range.max.description),
            "min": .string(range.min.description),
            "operation": .string(operation),
            "result": .string(result.description),
            "signedness": .string(signedness.rawValue),
            "totalBits": .int(totalBits),
        ])
    }
}

private func assertNoDivisionByZero(kind: FixedPointKind, signedness: Signedness, totalBits: Int, denominator: FixedPointRaw) throws(SolanaError) {
    if denominator.isZero {
        throw fixedPointError(.fixedPointsDivisionByZero, [
            "kind": .string(kind.rawValue),
            "signedness": .string(signedness.rawValue),
            "totalBits": .int(totalBits),
        ])
    }
}

private func assertDecimalShapeMatches(
    _ operation: String,
    actual value: DecimalFixedPoint,
    signedness expectedSignedness: Signedness? = nil,
    totalBits expectedTotalBits: Int? = nil,
    decimals expectedDecimals: Int? = nil
) throws(SolanaError) {
    try assertShapeMatches(
        operation,
        actual: Shape(kind: value.kind, scale: value.decimals, scaleLabel: "decimals", signedness: value.signedness, totalBits: value.totalBits),
        expectedKind: .decimalFixedPoint,
        expectedScale: expectedDecimals,
        expectedScaleLabel: "decimals",
        expectedSignedness: expectedSignedness,
        expectedTotalBits: expectedTotalBits
    )
}

private func assertBinaryShapeMatches(
    _ operation: String,
    actual value: BinaryFixedPoint,
    signedness expectedSignedness: Signedness? = nil,
    totalBits expectedTotalBits: Int? = nil,
    fractionalBits expectedFractionalBits: Int? = nil
) throws(SolanaError) {
    try assertShapeMatches(
        operation,
        actual: Shape(kind: value.kind, scale: value.fractionalBits, scaleLabel: "fractional bits", signedness: value.signedness, totalBits: value.totalBits),
        expectedKind: .binaryFixedPoint,
        expectedScale: expectedFractionalBits,
        expectedScaleLabel: "fractional bits",
        expectedSignedness: expectedSignedness,
        expectedTotalBits: expectedTotalBits
    )
}

private func assertShapeMatches(
    _ operation: String,
    actual: Shape,
    expectedKind: FixedPointKind,
    expectedScale: Int?,
    expectedScaleLabel: String,
    expectedSignedness: Signedness?,
    expectedTotalBits: Int?
) throws(SolanaError) {
    if actual.kind != expectedKind ||
        expectedScale.map({ actual.scale != $0 }) == true ||
        expectedSignedness.map({ actual.signedness != $0 }) == true ||
        expectedTotalBits.map({ actual.totalBits != $0 }) == true {
        throw fixedPointError(.fixedPointsShapeMismatch, [
            "actualKind": .string(actual.kind.rawValue),
            "actualScale": .int(actual.scale),
            "actualScaleLabel": .string(actual.scaleLabel),
            "actualSignedness": .string(actual.signedness.rawValue),
            "actualTotalBits": .int(actual.totalBits),
            "expectedKind": .string(expectedKind.rawValue),
            "expectedScale": .int(expectedScale ?? actual.scale),
            "expectedScaleLabel": .string(expectedScaleLabel),
            "expectedSignedness": .string((expectedSignedness ?? actual.signedness).rawValue),
            "expectedTotalBits": .int(expectedTotalBits ?? actual.totalBits),
            "operation": .string(operation),
        ])
    }
}

private func roundDivision(
    kind: FixedPointKind,
    operation: String,
    numerator: FixedPointRaw,
    denominator: FixedPointRaw,
    mode: RoundingMode
) throws(SolanaError) -> FixedPointRaw {
    let division = numerator.quotientAndRemainder(dividingBy: denominator)
    if division.remainder.isZero {
        return division.quotient
    }
    if mode == .strict {
        throw fixedPointError(.fixedPointsStrictModePrecisionLoss, [
            "kind": .string(kind.rawValue),
            "operation": .string(operation),
        ])
    }
    let sameSign = numerator.isNegative == denominator.isNegative
    switch mode {
    case .trunc:
        return division.quotient
    case .floor:
        return sameSign ? division.quotient : division.quotient - 1
    case .ceil:
        return sameSign ? division.quotient + 1 : division.quotient
    case .round:
        let doubledRemainder = division.remainder.magnitude.multiplied(bySmall: 2)
        let absoluteDenominator = denominator.magnitude
        if doubledRemainder < absoluteDenominator {
            return division.quotient
        }
        return sameSign ? division.quotient + 1 : division.quotient - 1
    case .strict:
        return division.quotient
    }
}

private func applyDecimalsOption(
    kind: FixedPointKind,
    raw: FixedPointRaw,
    currentDecimals: Int,
    options: FixedPointToStringOptions
) throws(SolanaError) -> (raw: FixedPointRaw, decimals: Int) {
    guard let targetDecimals = options.decimals, targetDecimals != currentDecimals else {
        return (raw, currentDecimals)
    }
    try assertValidDecimals(targetDecimals)
    if targetDecimals > currentDecimals {
        return (raw * .powerOf10(targetDecimals - currentDecimals), targetDecimals)
    }
    let rescaled = try roundDivision(
        kind: kind,
        operation: "toString",
        numerator: raw,
        denominator: .powerOf10(currentDecimals - targetDecimals),
        mode: options.rounding
    )
    return (rescaled, targetDecimals)
}

private func formatScaledBigint(_ raw: FixedPointRaw, decimals: Int, padTrailingZeros: Bool) -> String {
    if decimals == 0 {
        return raw.description
    }
    let isNegative = raw.isNegative
    var digits = raw.magnitude.description
    let minimumLength = decimals + 1
    if digits.count < minimumLength {
        digits = String(repeating: "0", count: minimumLength - digits.count) + digits
    }
    let split = digits.index(digits.endIndex, offsetBy: -decimals)
    let integerPart = String(digits[..<split])
    var fractionalPart = String(digits[split...])
    if !padTrailingZeros {
        while fractionalPart.last == "0" {
            fractionalPart.removeLast()
        }
    }
    let sign = isNegative ? "-" : ""
    if fractionalPart.isEmpty {
        return sign + integerPart
    }
    return "\(sign)\(integerPart).\(fractionalPart)"
}

private func formatFixedPoint(_ formatter: NumberFormatter, raw: FixedPointRaw, decimals: Int) -> String? {
    let number = NSDecimalNumber(
        string: "\(raw.description)E-\(decimals)",
        locale: Locale(identifier: "en_US_POSIX")
    )
    guard number != .notANumber else {
        return nil
    }
    return formatter.string(from: number)
}

private func writeRawBigInt(
    _ raw: FixedPointRaw,
    into bytes: inout Data,
    at offset: Int,
    byteSize: Int,
    signedness: Signedness,
    littleEndian: Bool,
    codecDescription: String
) throws {
    try assertWritable(bytes, offset: offset, size: byteSize, codecDescription: codecDescription)
    let unsigned = signedness == .signed && raw.isNegative ? raw + .powerOf2(byteSize * 8) : raw
    for index in 0 ..< byteSize {
        let position = littleEndian ? index : byteSize - index - 1
        bytes[offset + position] = unsigned.byte(at: index)
    }
}

private func readRawBigInt(
    from bytes: Data,
    at offset: Int,
    byteSize: Int,
    signedness: Signedness,
    littleEndian: Bool
) -> FixedPointRaw {
    let slice = Data(bytes[offset ..< offset + byteSize])
    let unsigned = FixedPointRaw.fromUnsignedBytes(slice, littleEndian: littleEndian)
    if signedness == .signed {
        let signBit = FixedPointRaw.powerOf2(byteSize * 8 - 1)
        if unsigned >= signBit {
            return unsigned - .powerOf2(byteSize * 8)
        }
    }
    return unsigned
}

private func assertReadable(_ bytes: Data, offset: Int, size: Int, codecDescription: String) throws {
    if bytes.isEmpty || offset >= bytes.count {
        throw CodecsError.cannotDecodeEmptyByteArray(codecDescription: codecDescription)
    }
    if offset < 0 || bytes.count - offset < size {
        throw CodecsError.invalidByteLength(codecDescription: codecDescription, expected: size, bytesLength: max(0, bytes.count - max(offset, 0)))
    }
}

private func assertWritable(_ bytes: Data, offset: Int, size: Int, codecDescription: String) throws {
    if offset < 0 || bytes.count - offset < size {
        throw CodecsError.invalidByteLength(codecDescription: codecDescription, expected: size, bytesLength: max(0, bytes.count - max(offset, 0)))
    }
}

private func fixedPointError(_ code: SolanaErrorCode, _ context: [String: SolanaErrorContextValue]) -> SolanaError {
    SolanaError(code, context: SolanaErrorContext(context))
}
