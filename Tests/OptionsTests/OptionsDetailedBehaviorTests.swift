import CodecsCore
import CodecsNumbers
import CodecsStrings
import Options
import SolanaErrors
import XCTest

final class OptionsDetailedBehaviorTests: XCTestCase {
    func testFallbackCallbacksAreLazyAndOnlyRunForMissingValues() {
        var fallbackCalls = 0
        let present = unwrapOption(some("A")) {
            fallbackCalls += 1
            return "fallback"
        }
        XCTAssertEqual(present, "A")
        XCTAssertEqual(fallbackCalls, 0)

        let missing = unwrapOption(none() as Option<String>) {
            fallbackCalls += 1
            return "fallback"
        }
        XCTAssertEqual(missing, "fallback")
        XCTAssertEqual(fallbackCalls, 1)

        let presentNumber = unwrapOption(some(1)) {
            fallbackCalls += 1
            return 99
        }
        XCTAssertEqual(presentNumber, 1)
        XCTAssertEqual(fallbackCalls, 1)
    }

    func testRecursiveUnwrapPreservesScalarsAndBytesWhileReplacingMissingValues() {
        XCTAssertEqual(unwrapOptionRecursively(.option(.some(.option(.some(.bool(false)))))), .bool(false))
        XCTAssertEqual(unwrapOptionRecursively(.option(.some(.option(.none)))), .null)
        XCTAssertEqual(unwrapOptionRecursively(.bytes(Data([1, 2, 3]))), .bytes(Data([1, 2, 3])))
        XCTAssertEqual(unwrapOptionRecursively(.string("hello")), .string("hello"))
        XCTAssertEqual(unwrapOptionRecursively(.option(.none)) { .int(42) }, .int(42))

        let input = OptionTreeValue.array([
            .option(.some(.string("a"))),
            .option(.none),
            .option(.some(.option(.some(.int(3))))),
            .string("b"),
        ])
        XCTAssertEqual(
            unwrapOptionRecursively(input),
            .array([.string("a"), .null, .int(3), .string("b")])
        )
        XCTAssertEqual(
            unwrapOptionRecursively(input) { .int(42) },
            .array([.string("a"), .int(42), .int(3), .string("b")])
        )
    }

    func testCustomNoneBytesWorkWithVariableStringsWithoutPrefixes() throws {
        let codec = try getOptionCodec(getUtf8Codec(), prefix: .none, noneValue: .bytes(Data(hex: "ffff")))

        XCTAssertEqual(try codec.encode("Hello"), Data(hex: "48656c6c6f"))
        XCTAssertEqual(try codec.encode(.some("Hello")), Data(hex: "48656c6c6f"))
        XCTAssertEqual(try codec.encode(Optional<String>.none), Data(hex: "ffff"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "ffff"))
        XCTAssertEqual(try codec.decode(Data(hex: "48656c6c6f")), .some("Hello"))
        XCTAssertEqual(try codec.decode(Data(hex: "ffff")), .none)
        let noneRead = try codec.read(Data(hex: "aaaaffffbb"), at: 2)
        XCTAssertEqual(noneRead.0, .none)
        XCTAssertEqual(noneRead.1, 4)
        XCTAssertEqual(try codec.getSizeFromValue("Hello"), 5)
        XCTAssertEqual(try codec.getSizeFromValue(Optional<String>.none), 2)
        XCTAssertNil(codec.maxSize)
    }

    func testNestedZeroableOptionsWithoutPrefixesCollapseMissingInnerValues() throws {
        let inner = try getFixedOptionCodec(getU16Codec(), prefix: .none, noneValue: .zeroes)
        let codec = try getFixedOptionCodec(inner, prefix: .none, noneValue: .zeroes)

        XCTAssertEqual(codec.fixedSize, 2)
        XCTAssertEqual(try codec.encode(.some(.some(42))), Data(hex: "2a00"))
        XCTAssertEqual(try codec.encode(.some(.none)), Data(hex: "0000"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "0000"))
        XCTAssertEqual(try codec.decode(Data(hex: "2a00")), .some(.some(42)))
        XCTAssertEqual(try codec.decode(Data(hex: "0000")), .none)

        var bytes = Data(repeating: 0xaa, count: 8)
        XCTAssertEqual(try codec.write(.some(.some(257)), into: &bytes, at: 3), 5)
        XCTAssertEqual(bytes, Data(hex: "aaaaaa0101aaaaaa"))
        let someRead = try codec.read(Data(hex: "ffff010100"), at: 2)
        XCTAssertEqual(someRead.0, .some(.some(257)))
        XCTAssertEqual(someRead.1, 4)

        let noneRead = try codec.read(Data(hex: "ffff000000"), at: 2)
        XCTAssertEqual(noneRead.0, .none)
        XCTAssertEqual(noneRead.1, 4)
    }

    func testPrefixedCustomNoneBytesCoverNestedAndVariableStringValues() throws {
        let numberCodec = try getOptionCodec(getU16Codec(), noneValue: .bytes(Data(hex: "ffff")))
        let nestedCodec = try getOptionCodec(numberCodec, noneValue: .bytes(Data(hex: "ffff")))

        XCTAssertEqual(try nestedCodec.encode(.some(.some(42))), Data(hex: "01012a00"))
        XCTAssertEqual(try nestedCodec.encode(.some(.none)), Data(hex: "0100ffff"))
        XCTAssertEqual(try nestedCodec.encode(.none), Data(hex: "00ffff"))
        XCTAssertEqual(try nestedCodec.decode(Data(hex: "01012a00")), .some(.some(42)))
        XCTAssertEqual(try nestedCodec.decode(Data(hex: "0100ffff")), .some(.none))
        XCTAssertEqual(try nestedCodec.decode(Data(hex: "00ffff")), .none)

        let stringCodec = try getOptionCodec(getUtf8Codec(), noneValue: .bytes(Data(hex: "ffff")))
        XCTAssertEqual(try stringCodec.encode("Hello"), Data(hex: "0148656c6c6f"))
        XCTAssertEqual(try stringCodec.encode(Optional<String>.none), Data(hex: "00ffff"))
        XCTAssertEqual(try stringCodec.decode(Data(hex: "0148656c6c6f")), .some("Hello"))
        XCTAssertEqual(try stringCodec.decode(Data(hex: "00ffff")), .none)
        XCTAssertEqual(try stringCodec.getSizeFromValue("Hello"), 6)
        XCTAssertEqual(try stringCodec.getSizeFromValue(Optional<String>.none), 3)
        XCTAssertNil(stringCodec.maxSize)
    }

    func testFixedOptionCodecRejectsVariablePrefixesAndInvalidWriteSpace() throws {
        XCTAssertThrowsError(
            try getFixedOptionCodec(
                getU16Codec(),
                prefix: .variable(getShortU16Codec()),
                noneValue: .zeroes
            )
        ) { error in
            XCTAssertEqual(error as? CodecsError, .expectedFixedLength)
        }

        let codec = try getFixedOptionCodec(getU16Codec(), prefix: .u8, noneValue: .bytes(Data(hex: "ffff")))
        var tooSmall = Data(repeating: 0, count: 2)
        XCTAssertThrowsError(try codec.write(.none, into: &tooSmall, at: 0)) { error in
            guard case let CodecsError.invalidByteLength(codecDescription, expected, bytesLength) = error else {
                return XCTFail("Expected invalid byte length, got \(error)")
            }
            XCTAssertEqual(codecDescription, "option")
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(bytesLength, 2)
        }
    }
}

private extension Data {
    init(hex: String) {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        self.init(bytes)
    }
}
