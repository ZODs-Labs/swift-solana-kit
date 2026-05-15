import CodecsCore
import CodecsNumbers
import CodecsStrings
import Foundation
import SolanaErrors
import XCTest

final class CodecsStringsTests: XCTestCase {
    func testBase10Codec() throws {
        let base10 = getBase10Codec()

        try assertValid(base10, "", "")
        try assertRead(base10, "", expected: "", expectedOffset: 0)
        try assertValid(base10, "0", "00", expectedOffset: 1)
        try assertValid(base10, "000", "000000", expectedOffset: 3)
        try assertValid(base10, "1", "01", expectedOffset: 1)
        try assertValid(base10, "42", "2a", expectedOffset: 1)
        try assertValid(base10, "1024", "0400", expectedOffset: 2)
        try assertValid(base10, "65535", "ffff", expectedOffset: 2)
        assertInvalidBase(getBase10Codec(), value: "INVALID_INPUT", alphabet: "0123456789", base: 10)
    }

    func testBase16Codec() throws {
        let base16 = getBase16Codec()

        try assertValid(base16, "", "")
        try assertRead(base16, "", expected: "", expectedOffset: 0)
        XCTAssertEqual(try base16.encode("0").hex, "00")
        XCTAssertEqual(try base16.encode("00").hex, "00")
        try assertRead(base16, "00", expected: "00", expectedOffset: 1)
        XCTAssertEqual(try base16.encode("1").hex, "01")
        XCTAssertEqual(try base16.encode("01").hex, "01")
        try assertRead(base16, "01", expected: "01", expectedOffset: 1)
        try assertValid(base16, "2a", "2a", expectedOffset: 1)
        try assertValid(base16, "0400", "0400", expectedOffset: 2)
        try assertValid(base16, "ffff", "ffff", expectedOffset: 2)
        XCTAssertEqual(try base16.encode("abc").hex, "ab00")
        assertInvalidBase(base16, value: "INVALID_INPUT", alphabet: "0123456789abcdef", base: 16)
        assertInvalidBase(base16, value: "😀", alphabet: "0123456789abcdef", base: 16)
    }

    func testBase58Codec() throws {
        let base58 = getBase58Codec()
        let pubkey = "LorisCg1FTs89a32VSrFskYDgiRbNQzct1WxyZb7nuA"
        let pubkeyHex = "0513045e052f4919b608963de73c666e0672e06e28140ab841bff1cc83a178b5"

        try assertValid(base58, "", "")
        try assertRead(base58, "", expected: "", expectedOffset: 0)
        try assertValid(base58, "1", "00", expectedOffset: 1)
        try assertValid(base58, "2", "01", expectedOffset: 1)
        try assertValid(base58, "11", "0000", expectedOffset: 2)
        try assertValid(base58, String(repeating: "1", count: 32), String(repeating: "00", count: 32), expectedOffset: 32)
        try assertValid(base58, "j", "2a", expectedOffset: 1)
        try assertValid(base58, "Jf", "0400", expectedOffset: 2)
        try assertValid(base58, "LUv", "ffff", expectedOffset: 2)
        try assertValid(base58, pubkey, pubkeyHex, expectedOffset: 32)

        XCTAssertEqual(try base58.getSizeFromValue(""), 0)
        XCTAssertEqual(try base58.getSizeFromValue("2"), 1)
        XCTAssertEqual(try base58.getSizeFromValue("Jf"), 2)
        XCTAssertEqual(try base58.getSizeFromValue("11111LUv"), 7)
        XCTAssertEqual(try base58.getSizeFromValue(pubkey), 32)
        XCTAssertEqual(try base58.getSizeFromValue("0"), 1)

        let pubkeyBytes = try Data(hex: pubkeyHex)
        XCTAssertEqual(try base58.read(pubkeyBytes, at: -pubkeyBytes.count).0, pubkey)
        XCTAssertEqual(try base58.read(pubkeyBytes, at: -(pubkeyBytes.count + 1)).0, pubkey)
        assertInvalidBase(base58, value: "INVALID_INPUT", alphabet: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz", base: 58)
    }

    func testBase64Codec() throws {
        let base64 = getBase64Codec()
        let base16 = getBase16Codec()
        let sentence = "TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu"
        let sentenceHex = "4d616e792068616e6473206d616b65206c6967687420776f726b2e"
        let base64TokenData =
            "AShNrkm2joOHhfQnRCzfSbrtDUkUcJSS7PJryR4PPjsnyyIWxL0ESVFoE7QWBowtz2B/iTtUGdb2EEyKbLuN5gEAAAAAAAAAAQAAAGCtpnOhgF7t+dM8By+nG51mKI9Dgb0RtO/6xvPX1w52AgAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        let base16TokenData =
            "01284dae49b68e838785f427442cdf49baed0d4914709492ecf26bc91e0f3e3b27cb2216c4bd0449516813b416068c2dcf607f893b5419d6f6104c8a6cbb8de601000000000000000100000060ada673a1805eedf9d33c072fa71b9d66288f4381bd11b4effac6f3d7d70e76020000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

        try assertValid(base64, "", "")
        try assertRead(base64, "", expected: "", expectedOffset: 0)
        XCTAssertEqual(try base64.encode("AA").hex, "00")
        XCTAssertEqual(try base64.encode("AA==").hex, "00")
        try assertRead(base64, "00", expected: "AA==", expectedOffset: 1)
        try assertValid(base64, "AQ==", "01", expectedOffset: 1)
        XCTAssertEqual(try base64.encode("Kg").hex, "2a")
        try assertRead(base64, "2a", expected: "Kg==", expectedOffset: 1)
        try assertValid(base64, sentence, sentenceHex, expectedOffset: 27)
        XCTAssertEqual(try base16.decode(try base64.encode(base64TokenData)), base16TokenData)
        XCTAssertEqual(try base64.decode(try base16.encode(base16TokenData)), base64TokenData)
        XCTAssertEqual(try base64.encode("A").hex, "")
        XCTAssertEqual(try base64.encode("AA=").hex, "00")
        XCTAssertEqual(try base64.encode("A==A").hex, "")
        XCTAssertEqual(try base64.encode("AA=A").hex, "00")
        XCTAssertEqual(try base64.encode("AAAAA").hex, "000000")
        XCTAssertEqual(try base64.getSizeFromValue("A==A"), 0)
        XCTAssertEqual(try base64.getSizeFromValue("AA=A"), 1)
        XCTAssertEqual(try base64.getSizeFromValue("INVALID_INPUT"), 9)
        assertInvalidBase(base64, value: "INVALID_INPUT", alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", base: 64)
    }

    func testBaseXResliceCodec() throws {
        let base8 = getBaseXResliceCodec("01234567", bits: 3)
        try assertValid(base8, "77777777", "ffffff", expectedOffset: 3)
        XCTAssertEqual(try base8.read(Data(hex: "00ffffff"), at: 1).0, "77777777")
        try assertValid(base8, "", "")
        let emptyAtEnd = try base8.read(Data(hex: "ff"), at: 1)
        XCTAssertEqual(emptyAtEnd.0, "")
        XCTAssertEqual(emptyAtEnd.1, 1)
        try assertValid(base8, "000", "00", expectedOffset: 1)
        try assertValid(base8, "100", "20", expectedOffset: 1)
        try assertValid(base8, "700", "e0", expectedOffset: 1)
        try assertValid(base8, "002", "01", expectedOffset: 1)

        let bytes = try Data(hex: "ffffff")
        XCTAssertEqual(try base8.read(bytes, at: -bytes.count).0, try base8.read(bytes, at: 0).0)
        XCTAssertEqual(try base8.read(bytes, at: -(bytes.count + 1)).0, try base8.read(bytes, at: 0).0)
    }

    func testUtf8AndNullCharacters() throws {
        let utf8 = getUtf8Codec()

        try assertValid(utf8, "", "")
        try assertValid(utf8, "0", "30")
        try assertValid(utf8, "ABC", "414243")
        try assertValid(utf8, "Hello World!", "48656c6c6f20576f726c6421")
        try assertValid(utf8, "語", "e8aa9e")

        XCTAssertEqual(try utf8.decode(Data([0x68, 0x00, 0x69])), "hi")
        XCTAssertEqual(removeNullCharacters("hello\u{0000}\u{0000}"), "hello")
        XCTAssertEqual(padNullCharacters("hello", chars: 8), "hello\u{0000}\u{0000}\u{0000}")
    }

    func testSizedStringComposition() throws {
        let u32PrefixedString = addCodecSizePrefix(getUtf8Codec(), prefix: getU32Codec())
        XCTAssertEqual(try u32PrefixedString.encode("").hex, "00000000")
        XCTAssertEqual(try u32PrefixedString.encode("Hello World!").hex, "0c00000048656c6c6f20576f726c6421")
        XCTAssertEqual(try u32PrefixedString.encode("語").hex, "03000000e8aa9e")
        XCTAssertEqual(try u32PrefixedString.read(Data(hex: "03000000e8aa9e"), at: 0).0, "語")
        XCTAssertEqual(try u32PrefixedString.read(Data(hex: "ff03000000e8aa9e"), at: 1).1, 8)

        let fixedString = fixCodecSize(getUtf8Codec(), fixedBytes: 5)
        XCTAssertEqual(try fixedString.encode("").hex, "0000000000")
        XCTAssertEqual(try fixedString.encode("語").hex, "e8aa9e0000")
        XCTAssertEqual(try fixedString.encode("Hello World!").hex, "48656c6c6f")
        XCTAssertEqual(try fixedString.read(Data(hex: "48656c6c6f"), at: 0).0, "Hello")

        let fixedBase58 = fixCodecSize(getBase58Codec(), fixedBytes: 5)
        XCTAssertEqual(try fixedBase58.encode("ABC").hex, "7893000000")
        XCTAssertEqual(try fixedBase58.decode(Data(hex: "7893000000")), "EbzinYo")
        XCTAssertEqual(try fixedBase58.decode(Data(hex: "0000007893")), "111ABC")
    }
}

private func assertValid<C: Codec>(
    _ codec: C,
    _ value: C.Encoded,
    _ expectedHex: String,
    expectedOffset: Int? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) throws where C.Decoded == String, C.Encoded == String {
    let encoded = try codec.encode(value)
    XCTAssertEqual(encoded.hex, expectedHex, file: file, line: line)
    let read = try codec.read(encoded, at: 0)
    XCTAssertEqual(read.0, value, file: file, line: line)
    XCTAssertEqual(read.1, expectedOffset ?? encoded.count, file: file, line: line)
}

private func assertRead<C: Decoder>(
    _ decoder: C,
    _ inputHex: String,
    expected: String,
    expectedOffset: Int,
    file: StaticString = #filePath,
    line: UInt = #line
) throws where C.Decoded == String {
    let read = try decoder.read(Data(hex: inputHex), at: 0)
    XCTAssertEqual(read.0, expected, file: file, line: line)
    XCTAssertEqual(read.1, expectedOffset, file: file, line: line)
}

private func assertInvalidBase<E: Encoder>(
    _ encoder: E,
    value: String,
    alphabet: String,
    base: Int,
    file: StaticString = #filePath,
    line: UInt = #line
) where E.Encoded == String {
    XCTAssertThrowsError(try encoder.encode(value), file: file, line: line) { error in
        guard case let CodecsError.invalidStringForBase(actualValue, actualBase, actualAlphabet) = error else {
            XCTFail("Expected invalidStringForBase, got \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(actualValue, value, file: file, line: line)
        XCTAssertEqual(actualBase, base, file: file, line: line)
        XCTAssertEqual(actualAlphabet, alphabet, file: file, line: line)
        XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsInvalidStringForBase.rawValue, file: file, line: line)
    }
}

private extension Data {
    init(hex: String) throws {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let byte = try XCTUnwrap(UInt8(hex[index ..< next], radix: 16))
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
