public import CodecsCore
import Foundation
public import SolanaErrors

let base10Alphabet = "0123456789"
let base16Alphabet = "0123456789abcdef"
let base58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
let base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

public func assertValidBaseString(
    _ alphabet: String,
    _ testValue: String,
    givenValue: String? = nil
) throws(CodecsError) {
    let allowed = Set(alphabet)
    if testValue.contains(where: { !allowed.contains($0) }) {
        throw CodecsError.invalidStringForBase(
            value: givenValue ?? testValue,
            base: alphabet.count,
            alphabet: alphabet
        )
    }
}

public func getBase10Encoder() -> AnyVariableSizeEncoder<String> {
    getBaseXEncoder(base10Alphabet)
}

public func getBase10Decoder() -> AnyVariableSizeDecoder<String> {
    getBaseXDecoder(base10Alphabet)
}

public func getBase10Codec() -> AnyVariableSizeCodec<String, String> {
    getBaseXCodec(base10Alphabet)
}

public func getBase16Encoder() -> AnyVariableSizeEncoder<String> {
    createEncoder { value in
        (value.count + 1) / 2
    } write: { value, bytes, offset in
        if value.isEmpty {
            return offset
        }

        if value.count == 1 {
            guard let scalar = value.unicodeScalars.first,
                  let nibble = base16Nibble(scalar.value) else {
                throw invalidBase16String(value)
            }
            try writeStringBytes(Data([nibble]), into: &bytes, at: offset, codecDescription: "base16")
            return offset + 1
        }

        let scalars = Array(value.unicodeScalars)
        let writtenByteCount = value.count / 2
        var encoded = Data(count: writtenByteCount)
        var scalarIndex = 0
        var byteIndex = 0
        while scalarIndex < scalars.count, byteIndex < writtenByteCount {
            guard let high = base16Nibble(scalars[scalarIndex].value) else {
                throw invalidBase16String(value)
            }
            scalarIndex += 1

            var low: UInt8 = 0
            if scalarIndex < scalars.count {
                guard let decodedLow = base16Nibble(scalars[scalarIndex].value) else {
                    throw invalidBase16String(value)
                }
                low = decodedLow
                scalarIndex += 1
            }

            encoded[byteIndex] = (high << 4) | low
            byteIndex += 1
        }
        try writeStringBytes(encoded, into: &bytes, at: offset, codecDescription: "base16")
        return offset + encoded.count
    }
}

public func getBase16Decoder() -> AnyVariableSizeDecoder<String> {
    createDecoder { rawBytes, offset in
        let slice = jsSlice(rawBytes, offset: offset)
        let value = slice.map { String(format: "%02x", $0) }.joined()
        return (value, rawBytes.count)
    }
}

public func getBase16Codec() -> AnyVariableSizeCodec<String, String> {
    createCodec { value in
        try getBase16Encoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getBase16Encoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getBase16Decoder().read(bytes, at: offset)
    }
}

public func getBase58Encoder() -> AnyVariableSizeEncoder<String> {
    getBaseXEncoder(base58Alphabet)
}

public func getBase58Decoder() -> AnyVariableSizeDecoder<String> {
    getBaseXDecoder(base58Alphabet)
}

public func getBase58Codec() -> AnyVariableSizeCodec<String, String> {
    getBaseXCodec(base58Alphabet)
}

public func getBase64Encoder() -> AnyVariableSizeEncoder<String> {
    createEncoder { value in
        nodeBase64DecodedByteCount(value)
    } write: { value, bytes, offset in
        let decoded = try decodedBase64Bytes(value)
        try writeStringBytes(decoded, into: &bytes, at: offset, codecDescription: "base64")
        return offset + decoded.count
    }
}

public func getBase64Decoder() -> AnyVariableSizeDecoder<String> {
    createDecoder { rawBytes, offset in
        let slice = jsSlice(rawBytes, offset: offset)
        return (slice.base64EncodedString(), rawBytes.count)
    }
}

public func getBase64Codec() -> AnyVariableSizeCodec<String, String> {
    createCodec { value in
        try getBase64Encoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getBase64Encoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getBase64Decoder().read(bytes, at: offset)
    }
}

public func getBaseXEncoder(_ alphabet: String) -> AnyVariableSizeEncoder<String> {
    createEncoder { value in
        let (leadingZeroes, tailChars) = partitionLeadingZeroes(value, zeroCharacter: alphabet.first)
        guard let tailChars, !tailChars.isEmpty else {
            return value.count
        }
        let tailBytes = baseXDigitsToBytes(tailChars, alphabet: alphabet)
        return leadingZeroes.count + tailBytes.count
    } write: { value, bytes, offset in
        try assertValidBaseString(alphabet, value)
        if value.isEmpty {
            return offset
        }

        let (leadingZeroes, tailChars) = partitionLeadingZeroes(value, zeroCharacter: alphabet.first)
        guard let tailChars, !tailChars.isEmpty else {
            let encoded = Data(repeating: 0, count: leadingZeroes.count)
            try writeStringBytes(encoded, into: &bytes, at: offset, codecDescription: "baseX")
            return offset + encoded.count
        }

        let encoded = Data(repeating: 0, count: leadingZeroes.count) + baseXDigitsToBytes(tailChars, alphabet: alphabet)
        try writeStringBytes(encoded, into: &bytes, at: offset, codecDescription: "baseX")
        return offset + encoded.count
    }
}

public func getBaseXDecoder(_ alphabet: String) -> AnyVariableSizeDecoder<String> {
    createDecoder { rawBytes, offset in
        let bytes = jsBaseXReadSlice(rawBytes, offset: offset)
        if bytes.isEmpty {
            return ("", 0)
        }

        let firstNonZero = bytes.firstIndex { $0 != 0 } ?? bytes.count
        let leadingZeroes = String(repeating: String(alphabet.first ?? Character("")), count: firstNonZero)
        if firstNonZero == bytes.count {
            return (leadingZeroes, rawBytes.count)
        }

        let tailBytes = Data(bytes[firstNonZero ..< bytes.count])
        let tailChars = bytesToBaseXDigits(tailBytes, alphabet: alphabet)
        return (leadingZeroes + tailChars, rawBytes.count)
    }
}

public func getBaseXCodec(_ alphabet: String) -> AnyVariableSizeCodec<String, String> {
    createCodec { value in
        try getBaseXEncoder(alphabet).getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getBaseXEncoder(alphabet).write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getBaseXDecoder(alphabet).read(bytes, at: offset)
    }
}

public func getBaseXResliceEncoder(_ alphabet: String, bits: Int) -> AnyVariableSizeEncoder<String> {
    createEncoder { value in
        (value.count * bits) / 8
    } write: { value, bytes, offset in
        try assertValidBaseString(alphabet, value)
        if value.isEmpty {
            return offset
        }
        let indices = value.map { alphabetIndex($0, in: alphabet) }
        let reslicedBytes = Data(reslice(indices, inputBits: bits, outputBits: 8, useRemainder: false).map(UInt8.init))
        try writeStringBytes(reslicedBytes, into: &bytes, at: offset, codecDescription: "baseXReslice")
        return offset + reslicedBytes.count
    }
}

public func getBaseXResliceDecoder(_ alphabet: String, bits: Int) -> AnyVariableSizeDecoder<String> {
    createDecoder { rawBytes, offset in
        let bytes = jsBaseXReadSlice(rawBytes, offset: offset)
        if bytes.isEmpty {
            return ("", rawBytes.count)
        }
        let indices = reslice(bytes.map(Int.init), inputBits: 8, outputBits: bits, useRemainder: true)
        let value = String(indices.map { alphabetCharacter(at: $0, in: alphabet) })
        return (value, rawBytes.count)
    }
}

public func getBaseXResliceCodec(_ alphabet: String, bits: Int) -> AnyVariableSizeCodec<String, String> {
    createCodec { value in
        try getBaseXResliceEncoder(alphabet, bits: bits).getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getBaseXResliceEncoder(alphabet, bits: bits).write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getBaseXResliceDecoder(alphabet, bits: bits).read(bytes, at: offset)
    }
}

public func removeNullCharacters(_ value: String) -> String {
    value.replacingOccurrences(of: "\u{0000}", with: "")
}

public func padNullCharacters(_ value: String, chars: Int) -> String {
    guard value.count < chars else {
        return value
    }
    return value + String(repeating: "\u{0000}", count: chars - value.count)
}

public func getUtf8Encoder() -> AnyVariableSizeEncoder<String> {
    createEncoder { value in
        Data(value.utf8).count
    } write: { value, bytes, offset in
        let encoded = Data(value.utf8)
        try writeStringBytes(encoded, into: &bytes, at: offset, codecDescription: "utf8")
        return offset + encoded.count
    }
}

public func getUtf8Decoder() -> AnyVariableSizeDecoder<String> {
    createDecoder { rawBytes, offset in
        let slice = jsSlice(rawBytes, offset: offset)
        return (removeNullCharacters(String(decoding: slice, as: UTF8.self)), rawBytes.count)
    }
}

public func getUtf8Codec() -> AnyVariableSizeCodec<String, String> {
    createCodec { value in
        try getUtf8Encoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getUtf8Encoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getUtf8Decoder().read(bytes, at: offset)
    }
}

func invalidBase16String(_ value: String) -> CodecsError {
    CodecsError.invalidStringForBase(value: value, base: 16, alphabet: base16Alphabet)
}

func decodedBase64Bytes(_ value: String) throws(CodecsError) -> Data {
    try assertValidBaseString(base64Alphabet, value.replacingOccurrences(of: "=", with: ""), givenValue: value)
    var output = Data()
    var buffer = 0
    var bits = 0
    for character in value {
        if character == "=" {
            break
        }
        let sextet = alphabetIndex(character, in: base64Alphabet)
        guard sextet >= 0 else {
            continue
        }
        buffer = (buffer << 6) | sextet
        bits += 6
        while bits >= 8 {
            bits -= 8
            output.append(UInt8((buffer >> bits) & 0xFF))
        }
    }
    return output
}

func nodeBase64DecodedByteCount(_ value: String) -> Int {
    var validCharacters = 0
    for character in value {
        if character == "=" {
            break
        }
        if character != "=", alphabetIndex(character, in: base64Alphabet) >= 0 {
            validCharacters += 1
        }
    }
    return (validCharacters * 6) / 8
}

func base16Nibble(_ char: UInt32) -> UInt8? {
    switch char {
    case 48 ... 57:
        return UInt8(char - 48)
    case 65 ... 70:
        return UInt8(char - 55)
    case 97 ... 102:
        return UInt8(char - 87)
    default:
        return nil
    }
}

func partitionLeadingZeroes(_ value: String, zeroCharacter: Character?) -> (String, String?) {
    guard let zeroCharacter else {
        return ("", value.isEmpty ? nil : value)
    }
    var leading = ""
    var tailStart = value.startIndex
    while tailStart < value.endIndex, value[tailStart] == zeroCharacter {
        leading.append(zeroCharacter)
        tailStart = value.index(after: tailStart)
    }
    if tailStart == value.endIndex {
        return (leading, nil)
    }
    return (leading, String(value[tailStart...]))
}

func baseXDigitsToBytes(_ value: String, alphabet: String) -> Data {
    let base = alphabet.count
    var bytes: [Int] = []
    for character in value {
        let digit = alphabetIndex(character, in: alphabet)
        var carry = digit
        var index = bytes.count - 1
        while index >= 0 {
            let updated = bytes[index] * base + carry
            bytes[index] = updated & 0xFF
            carry = updated >> 8
            index -= 1
        }
        while carry > 0 {
            bytes.insert(carry & 0xFF, at: 0)
            carry >>= 8
        }
        if bytes.isEmpty {
            bytes.append(0)
        }
    }
    while bytes.first == 0, bytes.count > 1 {
        bytes.removeFirst()
    }
    return Data(bytes.map(UInt8.init))
}

func bytesToBaseXDigits(_ bytes: Data, alphabet: String) -> String {
    let base = alphabet.count
    var digits: [Int] = []
    for byte in bytes {
        var carry = Int(byte)
        var index = digits.count - 1
        while index >= 0 {
            let updated = digits[index] * 256 + carry
            digits[index] = updated % base
            carry = updated / base
            index -= 1
        }
        while carry > 0 {
            digits.insert(carry % base, at: 0)
            carry /= base
        }
        if digits.isEmpty {
            digits.append(0)
        }
    }
    while digits.first == 0, digits.count > 1 {
        digits.removeFirst()
    }
    return String(digits.map { alphabetCharacter(at: $0, in: alphabet) })
}

func alphabetIndex(_ character: Character, in alphabet: String) -> Int {
    alphabet.firstIndex(of: character).map { alphabet.distance(from: alphabet.startIndex, to: $0) } ?? -1
}

func alphabetCharacter(at index: Int, in alphabet: String) -> Character {
    let safeIndex = max(0, min(index, max(alphabet.count - 1, 0)))
    return alphabet[alphabet.index(alphabet.startIndex, offsetBy: safeIndex)]
}

func reslice(_ input: [Int], inputBits: Int, outputBits: Int, useRemainder: Bool) -> [Int] {
    var output: [Int] = []
    var accumulator = 0
    var bitsInAccumulator = 0
    let mask = (1 << outputBits) - 1

    for value in input {
        accumulator = (accumulator << inputBits) | value
        bitsInAccumulator += inputBits
        while bitsInAccumulator >= outputBits {
            bitsInAccumulator -= outputBits
            output.append((accumulator >> bitsInAccumulator) & mask)
        }
    }

    if useRemainder, bitsInAccumulator > 0 {
        output.append((accumulator << (outputBits - bitsInAccumulator)) & mask)
    }
    return output
}

func jsBaseXReadSlice(_ rawBytes: Data, offset: Int) -> Data {
    if offset == 0 || offset <= -rawBytes.count {
        return rawBytes
    }
    return jsSlice(rawBytes, offset: offset)
}

func jsSlice(_ rawBytes: Data, offset: Int) -> Data {
    if rawBytes.isEmpty {
        return Data()
    }
    let start: Int
    if offset < 0 {
        start = max(rawBytes.count + offset, 0)
    } else {
        start = min(offset, rawBytes.count)
    }
    return Data(rawBytes[start ..< rawBytes.count])
}

func writeStringBytes(
    _ source: Data,
    into destination: inout Data,
    at offset: Offset,
    codecDescription: String
) throws(CodecsError) {
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
