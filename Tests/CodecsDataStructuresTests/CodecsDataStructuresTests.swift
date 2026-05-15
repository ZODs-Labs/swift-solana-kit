import CodecsCore
import CodecsDataStructures
import CodecsNumbers
import CodecsStrings
import Foundation
import SolanaErrors
import XCTest

final class CodecsDataStructuresTests: XCTestCase {
    func testBytesBooleanBitArrayUnitAndConstantCodecs() throws {
        let bytes = getBytesCodec()
        XCTAssertEqual(try bytes.encode(Data(hex: "2aff")).hex, "2aff")
        XCTAssertEqual(try bytes.read(Data(hex: "ffff2aff00"), at: 2).0.hex, "2aff00")
        XCTAssertEqual(try bytes.read(Data(hex: "ffff2aff00"), at: 2).1, 5)
        XCTAssertEqual(try bytes.getSizeFromValue(Data(hex: "2aff")), 2)

        XCTAssertEqual(try getBooleanCodec().encode(true).hex, "01")
        XCTAssertEqual(try getBooleanCodec().encode(false).hex, "00")
        XCTAssertEqual(try getBooleanCodec(size: getU32Codec()).encode(true).hex, "01000000")
        XCTAssertEqual(try getBooleanCodec(size: getU32Codec()).read(Data(hex: "ffff00000000"), at: 2).0, false)

        let mappedShortU16 = transformCodec(
            getShortU16Codec(),
            encode: { (value: Bool) in value ? 0xffff : 0 },
            decode: { (value: Int) in value == 0xffff }
        )
        XCTAssertEqual(try mappedShortU16.encode(true).hex, "ffff03")
        XCTAssertEqual(try mappedShortU16.encode(false).hex, "00")

        let bits = getBitArrayCodec(1)
        XCTAssertEqual(try bits.encode([true, true]).hex, "c0")
        XCTAssertEqual(try bits.read(Data(hex: "ffc0"), at: 1).0.prefix(8), [true, true, false, false, false, false, false, false])
        XCTAssertEqual(try getBitArrayCodec(1, backward: true).encode([true, true]).hex, "03")
        assertCodecError(try getBitArrayCodec(3).read(Data(hex: "ff"), at: 0), .codecsInvalidByteLength)

        XCTAssertEqual(try getUnitCodec().encode(()).hex, "")
        XCTAssertEqual(try getUnitCodec().read(Data(hex: "00"), at: 1).1, 1)
        let constant = try getConstantCodec(Data(hex: "010203"))
        XCTAssertEqual(try constant.encode(()).hex, "010203")
        XCTAssertEqual(try constant.read(Data(hex: "ffff01020300"), at: 2).1, 5)
        assertCodecError(try constant.decode(Data(hex: "0102ff")), .codecsInvalidConstant)
    }

    func testArraysSetsAndMaps() throws {
        let u8 = getU8Codec()
        let u16 = getU16Codec()
        let u64 = getU64Codec()
        let u32String = addCodecSizePrefix(getUtf8Codec(), prefix: getU32Codec())

        let prefixedArray = getArrayCodec(u8)
        XCTAssertEqual(try prefixedArray.encode([42, 1, 2]).hex, "030000002a0102")
        XCTAssertEqual(try prefixedArray.read(Data(hex: "ffff030000002a0102"), at: 2).0, [42, 1, 2])
        XCTAssertEqual(try prefixedArray.read(Data(hex: "ffff030000002a0102"), at: 2).1, 9)

        let oneBytePrefix = getArrayCodec(u8, size: u8)
        XCTAssertEqual(try oneBytePrefix.encode([]).hex, "00")

        let fixedArray = getArrayCodec(u16, size: 3)
        XCTAssertEqual(try fixedArray.encode([42, 1, 2]).hex, "2a0001000200")
        assertCodecError(try fixedArray.encode([42]), .codecsInvalidNumberOfItems)

        let remainderString = getArrayCodecRemainder(fixCodecSize(getUtf8Codec(), fixedBytes: 1))
        XCTAssertEqual(try remainderString.encode(["a", "b"]).hex, "6162")
        XCTAssertEqual(try remainderString.read(Data(hex: "6162"), at: 0).0, ["a", "b"])

        let arrayU64 = getArrayCodec(u64, size: 1)
        XCTAssertEqual(try arrayU64.encode([2]).hex, "0200000000000000")
        XCTAssertEqual(try arrayU64.decode(Data(hex: "0200000000000000")), [2])

        let set = getSetCodec(getU8Codec())
        XCTAssertEqual(try set.encode([42, 1, 2]).hex, "030000002a0102")
        XCTAssertEqual(try getSetCodecRemainder(getU8Codec()).read(Data(hex: "2a0102"), at: 0).0, [42, 1, 2])

        let lettersMap = getMapCodec(u32String, u8)
        let letters = [MapEntry("a", 1), MapEntry("b", 2)]
        XCTAssertEqual(try lettersMap.encode(letters).hex, "02000000010000006101010000006202")
        XCTAssertEqual(try lettersMap.read(Data(hex: "02000000010000006101010000006202"), at: 0).0, letters)

        let fixedMap = getMapCodec(getU8Codec(), getU8Codec(), size: 1)
        XCTAssertEqual(try fixedMap.encode([MapEntry(1, 2)]).hex, "0102")
        assertCodecError(try fixedMap.encode([]), .codecsInvalidNumberOfItems)
    }

    func testTupleStructUnionAndDiscriminatedUnionCodecs() throws {
        let u8Value = intValueCodec(getU8Codec())
        let u16Value = intValueCodec(getU16Codec())
        let stringValue = stringValueCodec(addCodecSizePrefix(getUtf8Codec(), prefix: getU32Codec()))

        let tuple = getTupleCodec([u8Value, u16Value])
        XCTAssertEqual(try tuple.encode(.array([.int(0), .int(42)])).hex, "002a00")
        XCTAssertEqual(try tuple.decode(Data(hex: "002a00")), .array([.int(0), .int(42)]))
        assertCodecError(try tuple.encode(.array([.int(0)])), .codecsInvalidNumberOfItems)

        let person = getStructCodec([
            StructField("name", stringValue),
            StructField("age", u8Value),
        ])
        let alice = CodecValue.object(["name": .string("Alice"), "age": .int(32)])
        XCTAssertEqual(try person.encode(alice).hex, "05000000416c69636520")
        XCTAssertEqual(try person.decode(Data(hex: "05000000416c69636520")), alice)
        let bobWithExtra = CodecValue.object(["name": .string("Bob"), "age": .int(28), "dob": .string("1995-06-01")])
        XCTAssertEqual(try person.encode(bobWithExtra).hex, "03000000426f621c")

        let union = getUnionCodec(
            [stringValueCodec(fixCodecSize(getUtf8Codec(), fixedBytes: 8)), u16Value, booleanValueCodec(getBooleanCodec())],
            getIndexFromValue: { value in
                if case .string = value { return 0 }
                if case .int = value { return 1 }
                if case .bool = value { return 2 }
                return 999
            },
            getIndexFromBytes: { bytes, offset in
                switch bytes.count - offset {
                case 8: return 0
                case 2: return 1
                case 1: return 2
                default: return 999
                }
            }
        )
        XCTAssertEqual(try union.encode(CodecValue.string("hello")).hex, "68656c6c6f000000")
        XCTAssertEqual(try union.encode(CodecValue.int(42)).hex, "2a00")
        XCTAssertEqual(try union.decode(Data(hex: "01")), CodecValue.bool(true))
        assertCodecError(try union.encode(CodecValue.void), .codecsUnionVariantOutOfRange)

        let webEvent = getDiscriminatedUnionCodec([
            DiscriminatedUnionVariant(.string("PageLoad"), unitValueCodec()),
            DiscriminatedUnionVariant(.string("Click"), getStructCodec([
                StructField("x", u8Value),
                StructField("y", u8Value),
            ])),
            DiscriminatedUnionVariant(.string("KeyPress"), getStructCodec([
                StructField("fields", getTupleCodec([stringValue])),
            ])),
        ])
        let click = CodecValue.object(["__kind": .string("Click"), "x": .int(1), "y": .int(2)])
        XCTAssertEqual(try webEvent.encode(click).hex, "010102")
        XCTAssertEqual(try webEvent.decode(Data(hex: "010102")), click)
        XCTAssertEqual(
            try webEvent.encode(.object(["__kind": .string("KeyPress"), "fields": .array([.string("語")])])).hex,
            "0203000000e8aa9e"
        )
        assertCodecError(try webEvent.encode(.object(["__kind": .string("Missing")])), .codecsInvalidDiscriminatedUnionVariant)
    }

    func testLiteralUnionEnumNullableAndHiddenCodecs() throws {
        let literal = getLiteralUnionCodec([.string("A"), .string("B"), .string("C")])
        XCTAssertEqual(try literal.encode(.string("A")).hex, "00")
        XCTAssertEqual(try literal.decode(Data(hex: "02")), .string("C"))
        assertCodecError(try literal.encode(.string("missing")), .codecsInvalidLiteralUnionVariant)
        assertCodecError(try literal.decode(Data(hex: "03")), .codecsLiteralUnionDiscriminatorOutOfRange)

        let feedback = [EnumCase("Bad", .int(0)), EnumCase("Good", .int(1))]
        let feedbackCodec = getEnumCodec(feedback)
        XCTAssertEqual(try feedbackCodec.encode(.string("Bad")).hex, "00")
        XCTAssertEqual(try feedbackCodec.encode(.int(1)).hex, "01")
        XCTAssertEqual(try feedbackCodec.decode(Data(hex: "01")), .int(1))
        assertCodecError(try feedbackCodec.encode(.string("Missing")), .codecsInvalidEnumVariant)

        let explicitValues = [
            EnumCase("Zero", .int(0)),
            EnumCase("Five", .int(5)),
            EnumCase("Six", .int(6)),
            EnumCase("Nine", .int(9)),
        ]
        let valueDiscriminator = getEnumCodec(explicitValues, useValuesAsDiscriminators: true)
        XCTAssertEqual(try valueDiscriminator.encode(.string("Five")).hex, "05")
        XCTAssertEqual(try valueDiscriminator.decode(Data(hex: "09")), .int(9))
        XCTAssertEqual(formatNumericalValues([1, 2, 3, 5, 12, 13, 14, 15, 42, 89, 90, 100]), "1-3, 5, 12-15, 42, 89-90, 100")

        let nullable = getNullableCodec(getU16Codec())
        XCTAssertEqual(try nullable.encode(Optional<Int>.some(42)).hex, "012a00")
        XCTAssertEqual(try nullable.encode(Optional<Int>.none).hex, "00")
        XCTAssertEqual(try nullable.decode(Data(hex: "012a00")), 42)
        XCTAssertNil(try nullable.decode(Data(hex: "00")))

        let noPrefixNullable = getNullableCodec(getU16Codec(), prefix: .none)
        XCTAssertEqual(try noPrefixNullable.encode(Optional<Int>.some(42)).hex, "2a00")
        XCTAssertEqual(try noPrefixNullable.encode(Optional<Int>.none).hex, "")
        XCTAssertEqual(try noPrefixNullable.read(Data(hex: "ffff010100"), at: 2).0, 257)
        XCTAssertEqual(try noPrefixNullable.read(Data(hex: "ffff010100"), at: 2).1, 4)
        XCTAssertNil(try noPrefixNullable.read(Data(hex: "ffff"), at: 2).0)
        XCTAssertEqual(try noPrefixNullable.read(Data(hex: "ffff"), at: 2).1, 2)

        let zeroable = try getFixedNullableCodec(getU16Codec(), prefix: .none, noneValue: .zeroes)
        XCTAssertEqual(try zeroable.encode(Optional<Int>.some(42)).hex, "2a00")
        XCTAssertEqual(try zeroable.encode(Optional<Int>.none).hex, "0000")
        XCTAssertNil(try zeroable.decode(Data(hex: "0000")))

        let customNoneBytes = try Data(hex: "ffff")
        let prefixedCustomNone = getNullableCodec(getU16Codec(), prefix: .u8, noneValue: .bytes(customNoneBytes))
        XCTAssertNil(try prefixedCustomNone.decode(Data(hex: "00ffff")))
        XCTAssertThrowsError(try prefixedCustomNone.decode(Data(hex: "000000"))) { error in
            guard case CodecsError.invalidConstant(let constant, _, let offset) = error else {
                return XCTFail("Expected invalidConstant, got \(error)")
            }
            XCTAssertEqual(constant, customNoneBytes)
            XCTAssertEqual(offset, 1)
        }

        let hiddenPrefix = try getHiddenPrefixCodec(getU8Codec(), prefixes: [getConstantCodec(Data(hex: "aa")), getConstantCodec(Data(hex: "bb"))])
        XCTAssertEqual(try hiddenPrefix.encode(1).hex, "aabb01")
        XCTAssertEqual(try hiddenPrefix.read(Data(hex: "ffffaabb0100"), at: 2).0, 1)

        let hiddenSuffix = try getHiddenSuffixCodec(getU8Codec(), suffixes: [getConstantCodec(Data(hex: "aa")), getConstantCodec(Data(hex: "bb"))])
        XCTAssertEqual(try hiddenSuffix.encode(1).hex, "01aabb")
        XCTAssertEqual(try hiddenSuffix.read(Data(hex: "ffff01aabb00"), at: 2).1, 5)
    }

    func testPatternMatchCodec() throws {
        let zero = byteValueCodec(byte: 0, value: .int(0))
        let one = byteValueCodec(byte: 1, value: .int(1))
        let two = byteValueCodec(byte: 2, value: .int(2))

        let codec = getPatternMatchCodec([
            (value: { $0 == .int(0) }, bytes: { $0.first == 0 }, codec: zero),
            (value: { $0 == .int(1) }, bytes: { $0.first == 1 }, codec: one),
            (value: { $0 == .int(2) }, bytes: { $0.first == 2 }, codec: two),
        ])
        XCTAssertEqual(try codec.encode(.int(0)).hex, "00")
        XCTAssertEqual(try codec.encode(.int(2)).hex, "02")
        XCTAssertEqual(try codec.decode(Data(hex: "01")), .int(1))
        assertCodecError(try codec.encode(.int(42)), .codecsInvalidPatternMatchValue)
        assertCodecError(try codec.decode(Data(hex: "2a")), .codecsInvalidPatternMatchBytes)
    }

    func testPredicateCodecUsesIndependentValueCodecs() throws {
        let matching = byteValueCodec(byte: 1, value: .string("matched"))
        let fallback = byteValueCodec(byte: 0, value: .bool(false))
        let codec = getPredicateCodec(
            encodePredicate: { $0 == .string("matched") },
            decodePredicate: { $0.first == 1 },
            ifTrue: matching,
            ifFalse: fallback
        )

        XCTAssertEqual(try codec.encode(.string("matched")).hex, "01")
        XCTAssertEqual(try codec.encode(.bool(false)).hex, "00")
        XCTAssertEqual(try codec.decode(Data(hex: "01")), .string("matched"))
        XCTAssertEqual(try codec.decode(Data(hex: "00")), .bool(false))
    }
}

private func byteValueCodec(byte: UInt8, value: CodecValue) -> AnyValueCodec {
    .fixed(createCodec(fixedSize: 1) { _, bytes, offset in
        bytes[offset] = byte
        return offset + 1
    } read: { _, offset in
        (value, offset + 1)
    })
}

private func assertCodecError<T>(
    _ expression: @autoclosure () throws -> T,
    _ expectedCode: SolanaErrorCode,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        XCTAssertEqual((error as? CodecsError)?.code, expectedCode.rawValue, file: file, line: line)
    }
}

private extension Data {
    init(hex: String) throws {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let byte = try XCTUnwrap(UInt8(hex[index..<next], radix: 16))
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
