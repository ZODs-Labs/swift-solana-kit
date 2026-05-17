import CodecsCore
import CodecsNumbers
import CodecsStrings
import Foundation
import Options
import SolanaErrors
import XCTest

final class OptionsTests: XCTestCase {
    func testCreatesAndChecksOptions() {
        let optionA: Option<Int> = some(42)
        let optionB: Option<String> = none()

        XCTAssertEqual(optionA, .some(42))
        XCTAssertEqual(optionB, .none)
        XCTAssertTrue(isOption(optionA))
        XCTAssertTrue(isSome(optionA))
        XCTAssertFalse(isNone(optionA))
        XCTAssertFalse(isSome(optionB))
        XCTAssertTrue(isNone(optionB))
    }

    func testWrapsAndUnwrapsOptions() {
        XCTAssertEqual(wrapNullable(42), .some(42))
        XCTAssertEqual(wrapNullable(Optional<Int>.none), .none)
        XCTAssertEqual(unwrapOption(some("hello")), "hello")
        XCTAssertNil(unwrapOption(none() as Option<String>))
        XCTAssertEqual(unwrapOption(none() as Option<Int>) { 42 }, 42)
        XCTAssertEqual(unwrapOption(some(1)) { 42 }, 1)
    }

    func testRecursivelyUnwrapsTrees() {
        let input = OptionTreeValue.object([
            "age": .int(42),
            "gender": .option(.none),
            "interests": .array([
                .object(["category": .option(.some(.string("IT"))), "name": .string("Programming")]),
                .object(["category": .option(.none), "name": .string("Popping bubble wrap")])
            ]),
            "name": .string("Roo")
        ])

        let expected = OptionTreeValue.object([
            "age": .int(42),
            "gender": .null,
            "interests": .array([
                .object(["category": .string("IT"), "name": .string("Programming")]),
                .object(["category": .null, "name": .string("Popping bubble wrap")])
            ]),
            "name": .string("Roo")
        ])

        XCTAssertEqual(unwrapOptionRecursively(input), expected)
        XCTAssertEqual(
            unwrapOptionRecursively(input) { .int(7) },
            .object([
                "age": .int(42),
                "gender": .int(7),
                "interests": .array([
                    .object(["category": .string("IT"), "name": .string("Programming")]),
                    .object(["category": .int(7), "name": .string("Popping bubble wrap")])
                ]),
                "name": .string("Roo")
            ])
        )
    }

    func testDefaultPrefixOptionNumberCodec() throws {
        let codec = try getOptionCodec(getU16Codec())

        XCTAssertEqual(try codec.encode(0), Data(hex: "010000"))
        XCTAssertEqual(try codec.encode(.some(0)), Data(hex: "010000"))
        XCTAssertEqual(try codec.encode(42), Data(hex: "012a00"))
        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "012a00"))
        XCTAssertEqual(try codec.encode(Optional<Int>.none), Data(hex: "00"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "00"))
        XCTAssertEqual(try codec.decode(Data(hex: "010000")), .some(0))
        XCTAssertEqual(try codec.decode(Data(hex: "012a00")), .some(42))
        XCTAssertEqual(try codec.decode(Data(hex: "00")), .none)
        XCTAssertEqual(try codec.getSizeFromValue(Optional<Int>.none), 1)
        XCTAssertEqual(try codec.getSizeFromValue(42), 3)
        XCTAssertEqual(codec.maxSize, 3)
    }

    func testCustomPrefixOptionNumberCodec() throws {
        let codec = try getOptionCodec(getU16Codec(), prefix: .fixed(getU32Codec()))

        XCTAssertEqual(try codec.encode(.some(0)), Data(hex: "010000000000"))
        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "010000002a00"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "00000000"))
        XCTAssertEqual(try codec.decode(Data(hex: "010000000000")), .some(0))
        XCTAssertEqual(try codec.decode(Data(hex: "010000002a00")), .some(42))
        XCTAssertEqual(try codec.decode(Data(hex: "00000000")), .none)
    }

    func testVariableStringOptionCodec() throws {
        let codec = try getOptionCodec(getUtf8Codec())

        XCTAssertEqual(try codec.encode("Hello"), Data(hex: "0148656c6c6f"))
        XCTAssertEqual(try codec.encode(.some("Hello")), Data(hex: "0148656c6c6f"))
        XCTAssertEqual(try codec.encode(Optional<String>.none), Data(hex: "00"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "00"))
        XCTAssertEqual(try codec.decode(Data(hex: "0148656c6c6f")), .some("Hello"))
        XCTAssertEqual(try codec.decode(Data(hex: "00")), .none)
    }

    func testNestedOptionNumberCodec() throws {
        let inner = try getOptionCodec(getU16Codec())
        let codec = try getOptionCodec(inner)

        XCTAssertEqual(try codec.encode(42), Data(hex: "01012a00"))
        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "01012a00"))
        XCTAssertEqual(try codec.encode(.some(.some(42))), Data(hex: "01012a00"))
        XCTAssertEqual(try codec.encode(.some(.none)), Data(hex: "0100"))
        XCTAssertEqual(try codec.encode(Optional<Option<Int>>.none), Data(hex: "00"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "00"))
        XCTAssertEqual(try codec.decode(Data(hex: "01012a00")), .some(.some(42)))
        XCTAssertEqual(try codec.decode(Data(hex: "0100")), .some(.none))
        XCTAssertEqual(try codec.decode(Data(hex: "00")), .none)
    }

    func testZeroableFixedOptionCodecWithoutPrefix() throws {
        let codec = try getFixedOptionCodec(getU16Codec(), prefix: .none, noneValue: .zeroes)

        XCTAssertEqual(codec.fixedSize, 2)
        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "2a00"))
        XCTAssertEqual(try codec.encode(.some(0)), Data(hex: "0000"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "0000"))
        XCTAssertEqual(try codec.decode(Data(hex: "2a00")), .some(42))
        XCTAssertEqual(try codec.decode(Data(hex: "0000")), .none)
    }

    func testCustomNoneValueWithoutPrefix() throws {
        let codec = try getOptionCodec(getU16Codec(), prefix: .none, noneValue: .bytes(Data(hex: "ffff")))

        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "2a00"))
        XCTAssertEqual(try codec.encode(.some(65_535)), Data(hex: "ffff"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "ffff"))
        XCTAssertEqual(try codec.decode(Data(hex: "2a00")), .some(42))
        XCTAssertEqual(try codec.decode(Data(hex: "ffff")), .none)
        XCTAssertEqual(codec.maxSize, 2)
    }

    func testNoPrefixOrNoneValueUsesAbsenceOfBytes() throws {
        let codec = try getOptionCodec(getU16Codec(), prefix: .none)

        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "2a00"))
        XCTAssertEqual(try codec.encode(42), Data(hex: "2a00"))
        XCTAssertEqual(try codec.encode(Optional<Int>.none), Data())
        XCTAssertEqual(try codec.encode(.none), Data())
        XCTAssertEqual(try codec.decode(Data(hex: "2a00")), .some(42))
        XCTAssertEqual(try codec.decode(Data()), .none)
        XCTAssertEqual(try codec.read(Data(hex: "ffff010100"), at: 2).0, .some(257))
        XCTAssertEqual(try codec.read(Data(hex: "ffff010100"), at: 2).1, 4)
        XCTAssertEqual(try codec.read(Data(hex: "ffff"), at: 2).0, .none)
        XCTAssertEqual(try codec.read(Data(hex: "ffff"), at: 2).1, 2)
        XCTAssertEqual(try codec.getSizeFromValue(Optional<Int>.none), 0)
        XCTAssertEqual(try codec.getSizeFromValue(42), 2)
        XCTAssertEqual(codec.maxSize, 2)
    }

    func testNestedNoPrefixOptionsCollapseSomeNoneLikeMissingBytes() throws {
        let inner = try getOptionCodec(getU16Codec(), prefix: .none)
        let codec = try getOptionCodec(inner, prefix: .none)

        XCTAssertEqual(try codec.encode(.some(.some(42))), Data(hex: "2a00"))
        XCTAssertEqual(try codec.encode(.some(.none)), Data())
        XCTAssertEqual(try codec.encode(Optional<Option<Int>>.none), Data())
        XCTAssertEqual(try codec.decode(Data(hex: "2a00")), .some(.some(42)))
        XCTAssertEqual(try codec.decode(Data()), .none)
    }

    func testPrefixedCustomNoneValueMustMatchConstantBytes() throws {
        let codec = try getOptionCodec(getU16Codec(), prefix: .u8, noneValue: .bytes(Data(hex: "ffff")))

        XCTAssertEqual(try codec.decode(Data(hex: "00ffff")), .none)
        XCTAssertThrowsError(try codec.decode(Data(hex: "000000"))) { error in
            guard case CodecsError.invalidConstant(let constant, _, let offset) = error else {
                return XCTFail("Expected invalidConstant, got \(error)")
            }
            XCTAssertEqual(constant, Data(hex: "ffff"))
            XCTAssertEqual(offset, 1)
        }
    }

    func testPrefixAndZeroableNoneValue() throws {
        let codec = try getFixedOptionCodec(getU16Codec(), prefix: .u8, noneValue: .zeroes)

        XCTAssertEqual(codec.fixedSize, 3)
        XCTAssertEqual(try codec.encode(.some(0)), Data(hex: "010000"))
        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "012a00"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "000000"))
        XCTAssertEqual(try codec.decode(Data(hex: "010000")), .some(0))
        XCTAssertEqual(try codec.decode(Data(hex: "012a00")), .some(42))
        XCTAssertEqual(try codec.decode(Data(hex: "000000")), .none)
    }

    func testVariablePrefixAndZeroableNoneValue() throws {
        let codec = try getOptionCodec(getU16Codec(), prefix: .variable(getShortU16Codec()), noneValue: .zeroes)

        XCTAssertEqual(try codec.encode(.some(42)), Data(hex: "012a00"))
        XCTAssertEqual(try codec.encode(.none), Data(hex: "000000"))
        XCTAssertEqual(try codec.getSizeFromValue(.some(42)), 3)
        XCTAssertEqual(try codec.getSizeFromValue(.none), 3)
        XCTAssertEqual(codec.maxSize, 5)
    }

    func testReadAndWriteOffsets() throws {
        let codec = try getOptionCodec(getU16Codec())
        var someBytes = Data(repeating: 0, count: 10)
        var noneBytes = Data(repeating: 0, count: 10)

        XCTAssertEqual(try codec.write(.some(257), into: &someBytes, at: 3), 6)
        XCTAssertEqual(try codec.write(.none, into: &noneBytes, at: 3), 4)
        XCTAssertEqual(someBytes, Data(hex: "00000001010100000000"))
        XCTAssertEqual(noneBytes, Data(hex: "00000000000000000000"))
        XCTAssertEqual(try codec.read(Data(hex: "ffff01010100"), at: 2).0, .some(257))
        XCTAssertEqual(try codec.read(Data(hex: "ffff01010100"), at: 2).1, 5)
        XCTAssertEqual(try codec.read(Data(hex: "ffff00"), at: 2).0, .none)
        XCTAssertEqual(try codec.read(Data(hex: "ffff00"), at: 2).1, 3)
    }

    func testZeroesRequireFixedSizeItemAtConstruction() {
        XCTAssertThrowsError(try getOptionCodec(getUtf8Codec(), noneValue: .zeroes)) { error in
            XCTAssertEqual(error as? CodecsError, .expectedFixedLength)
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
