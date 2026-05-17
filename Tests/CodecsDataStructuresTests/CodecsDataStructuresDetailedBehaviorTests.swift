import CodecsCore
import CodecsDataStructures
import CodecsNumbers
import CodecsStrings
import Foundation
import SolanaErrors
import XCTest

final class CodecsDataStructuresDetailedBehaviorTests: XCTestCase {
    func testCollectionCodecsHandleEmptyValuesSizeStrategiesAndRemainders() throws {
        let u8 = getU8Codec()
        let u16 = getU16Codec()
        let u64 = getU64Codec()
        let u8String = addCodecSizePrefix(getUtf8Codec(), prefix: getU8Codec())
        let u32String = addCodecSizePrefix(getUtf8Codec(), prefix: getU32Codec())

        let prefixedArray = getArrayCodec(u8)
        XCTAssertEqual(try prefixedArray.encode([]).hex, "00000000")
        XCTAssertEqual(try prefixedArray.read(Data(hex: "00000000"), at: 0).0, [])
        XCTAssertEqual(try prefixedArray.read(Data(hex: "00000000"), at: 0).1, 4)
        XCTAssertEqual(try prefixedArray.read(Data(), at: 0).0, [])
        XCTAssertEqual(try prefixedArray.getSizeFromValue([1, 2]), 6)
        XCTAssertNil(prefixedArray.maxSize)

        let u8PrefixedArray = getArrayCodec(u8, size: u8)
        XCTAssertEqual(try u8PrefixedArray.encode([]).hex, "00")
        XCTAssertEqual(try u8PrefixedArray.read(Data(hex: "00"), at: 0).1, 1)
        XCTAssertEqual(try u8PrefixedArray.getSizeFromValue([1, 2]), 3)

        let zeroArray = getArrayCodec(u8, size: 0)
        XCTAssertEqual(zeroArray.fixedSize, 0)
        XCTAssertEqual(try zeroArray.encode([]).hex, "")
        XCTAssertEqual(try zeroArray.read(Data(), at: 0).0, [])

        let fixedArray = getArrayCodec(u16, size: 3)
        XCTAssertEqual(fixedArray.fixedSize, 6)
        XCTAssertEqual(try fixedArray.encode([42, 1, 2]).hex, "2a0001000200")
        XCTAssertEqual(try fixedArray.read(Data(hex: "ffff2a0001000200"), at: 2).0, [42, 1, 2])
        XCTAssertEqual(try fixedArray.read(Data(hex: "ffff2a0001000200"), at: 2).1, 8)

        let fixedStringArray = getArrayCodec(u32String, size: 2)
        XCTAssertEqual(try fixedStringArray.encode(["a", "b"]).hex, "01000000610100000062")
        XCTAssertEqual(try fixedStringArray.read(Data(hex: "01000000610100000062"), at: 0).0, ["a", "b"])
        XCTAssertNil(fixedStringArray.maxSize)
        assertExactCodecError(
            try getArrayCodec(u32String, size: 1, description: "items").encode([]),
            .invalidNumberOfItems(codecDescription: "items", expected: 1, actual: 0)
        )

        let remainderStringArray = getArrayCodecRemainder(u8String)
        XCTAssertEqual(try remainderStringArray.encode(["a", "bc"]).hex, "0161026263")
        XCTAssertEqual(try remainderStringArray.read(Data(hex: "0161026263"), at: 0).0, ["a", "bc"])
        XCTAssertEqual(try remainderStringArray.getSizeFromValue(["a", "bc"]), 5)

        let arrayU64 = getArrayCodec(u64)
        XCTAssertEqual(try arrayU64.encode([2]).hex, "010000000200000000000000")
        XCTAssertEqual(try arrayU64.read(Data(hex: "010000000200000000000000"), at: 0).0, [UInt64(2)])

        let prefixedSet = getSetCodec(u8)
        XCTAssertEqual(try prefixedSet.encode([]).hex, "00000000")
        XCTAssertEqual(try prefixedSet.encode([42, 1, 2]).hex, "030000002a0102")
        XCTAssertEqual(try prefixedSet.read(Data(hex: "ffff030000002a0102"), at: 2).1, 9)

        let fixedSet = getSetCodec(u16, size: 2)
        XCTAssertEqual(fixedSet.fixedSize, 4)
        XCTAssertEqual(try fixedSet.encode([42, 1]).hex, "2a000100")
        assertExactCodecError(
            try fixedSet.encode([42]),
            .invalidNumberOfItems(codecDescription: "array", expected: 2, actual: 1)
        )

        let remainderSet = getSetCodecRemainder(u8String)
        XCTAssertEqual(try remainderSet.encode(["a", "bc"]).hex, "0161026263")
        XCTAssertEqual(try remainderSet.read(Data(hex: "0161026263"), at: 0).0, ["a", "bc"])

        let prefixedMap = getMapCodec(u32String, u8)
        let letters = [MapEntry("a", 1), MapEntry("b", 2)]
        XCTAssertEqual(try prefixedMap.encode(letters).hex, "02000000010000006101010000006202")
        XCTAssertEqual(try prefixedMap.read(Data(hex: "02000000010000006101010000006202"), at: 0).0, letters)
        XCTAssertEqual(try prefixedMap.read(Data(hex: "02000000010000006101010000006202"), at: 0).1, 16)

        let emptyMap = getMapCodec(u8, u8)
        XCTAssertEqual(try emptyMap.encode([]).hex, "00000000")
        XCTAssertEqual(try emptyMap.read(Data(hex: "00000000"), at: 0).0, [])
        XCTAssertEqual(try emptyMap.getSizeFromValue([MapEntry(1, 2), MapEntry(3, 4)]), 8)

        let fixedMap = getMapCodec(u8, u16, size: 2)
        XCTAssertEqual(fixedMap.fixedSize, 6)
        XCTAssertEqual(try fixedMap.encode([MapEntry(1, 2), MapEntry(3, 4)]).hex, "010200030400")
        assertExactCodecError(
            try fixedMap.encode([MapEntry(1, 2)]),
            .invalidNumberOfItems(codecDescription: "array", expected: 2, actual: 1)
        )

        let remainderMap = getMapCodecRemainder(u8String, u8)
        let compactLetters = [MapEntry("a", 6), MapEntry("bc", 7)]
        XCTAssertEqual(try remainderMap.encode(compactLetters).hex, "01610602626307")
        XCTAssertEqual(try remainderMap.read(Data(hex: "01610602626307"), at: 0).0, compactLetters)
    }

    func testTupleStructAndUnionCodecsReportSizesAndPreserveOffsets() throws {
        let u8Value = intValueCodec(getU8Codec())
        let i16Value = intValueCodec(getI16Codec())
        let stringValue = stringValueCodec(addCodecSizePrefix(getUtf8Codec(), prefix: getU32Codec()))

        let emptyTuple = getTupleCodec([])
        XCTAssertEqual(emptyTuple.fixedSize, 0)
        XCTAssertEqual(try emptyTuple.encode(.array([])).hex, "")
        XCTAssertEqual(try emptyTuple.decode(Data()), .array([]))

        let tuple = getTupleCodec([u8Value, i16Value])
        XCTAssertEqual(tuple.fixedSize, 3)
        XCTAssertEqual(try tuple.encode(.array([.int(0), .int(-42)])).hex, "00d6ff")
        XCTAssertEqual(try tuple.decode(Data(hex: "00d6ff")), .array([.int(0), .int(-42)]))
        XCTAssertEqual(try writtenOffset(tuple, value: .array([.int(1), .int(2)]), offset: 3, byteCount: 8), 6)
        XCTAssertEqual(try tuple.read(Data(hex: "ffff010200"), at: 2).1, 5)
        assertExactCodecError(
            try tuple.encode(.array([.int(42)])),
            .invalidNumberOfItems(codecDescription: "tuple", expected: 2, actual: 1)
        )

        let describedTuple = getTupleCodec([u8Value, u8Value], description: "pair")
        assertExactCodecError(
            try describedTuple.encode(.array([.int(42)])),
            .invalidNumberOfItems(codecDescription: "pair", expected: 2, actual: 1)
        )

        let variableTuple = getTupleCodec([u8Value, stringValue, i16Value])
        XCTAssertNil(variableTuple.fixedSize)
        XCTAssertEqual(try variableTuple.getSizeFromValue(.array([.int(1), .string("ABC"), .int(2)])), 10)
        XCTAssertNil(variableTuple.maxSize)

        let emptyStruct = getStructCodec([])
        XCTAssertEqual(emptyStruct.fixedSize, 0)
        XCTAssertEqual(try emptyStruct.encode(.object([:])).hex, "")
        XCTAssertEqual(try emptyStruct.decode(Data()), .object([:]))

        let person = getStructCodec([
            StructField("name", stringValue),
            StructField("age", u8Value),
        ])
        let alice = CodecValue.object(["name": .string("Alice"), "age": .int(32)])
        XCTAssertEqual(try person.encode(alice).hex, "05000000416c69636520")
        XCTAssertEqual(try person.read(Data(hex: "ffff05000000416c69636520"), at: 2).0, alice)
        XCTAssertEqual(try person.read(Data(hex: "ffff05000000416c69636520"), at: 2).1, 12)
        XCTAssertEqual(try person.getSizeFromValue(.object(["name": .string("ABC"), "age": .int(42)])), 8)
        XCTAssertNil(person.maxSize)

        let balance = getStructCodec([StructField("value", uint64ValueCodec(getU64Codec()))])
        XCTAssertEqual(try balance.encode(.object(["value": .int(2)])).hex, "0200000000000000")
        XCTAssertEqual(try balance.encode(.object(["value": .uint64(2)])).hex, "0200000000000000")
        XCTAssertEqual(try balance.decode(Data(hex: "0200000000000000")), .object(["value": .uint64(2)]))

        let union = makeMixedUnionCodec()
        XCTAssertEqual(try union.encode(.string("hello")).hex, "68656c6c6f000000")
        XCTAssertEqual(try union.encode(.int(42)).hex, "2a00")
        XCTAssertEqual(try union.encode(.bool(true)).hex, "01")
        XCTAssertEqual(try union.encode(.object(["x": .int(1), "y": .int(2)])).hex, "01000200")
        XCTAssertEqual(try union.decode(Data(hex: "68656c6c6f000000")), .string("hello"))
        XCTAssertEqual(try union.decode(Data(hex: "2a00")), .int(42))
        XCTAssertEqual(try union.decode(Data(hex: "01")), .bool(true))
        XCTAssertEqual(try union.decode(Data(hex: "01000200")), .object(["x": .int(1), "y": .int(2)]))
        XCTAssertEqual(try union.getSizeFromValue(.string("hello")), 8)
        XCTAssertEqual(try union.getSizeFromValue(.object(["x": .int(1), "y": .int(2)])), 4)
        XCTAssertEqual(union.maxSize, 8)
        assertExactCodecError(
            try union.decode(Data(hex: "ffffff")),
            .unionVariantOutOfRange(variant: 999, minRange: 0, maxRange: 3)
        )

        let sameSizeUnion = getUnionCodec(
            [u8Value, booleanValueCodec(getBooleanCodec())],
            getIndexFromValue: { _ in 0 },
            getIndexFromBytes: { _, _ in 0 }
        )
        XCTAssertEqual(sameSizeUnion.fixedSize, 1)
    }

    func testLiteralUnionCodecsSupportValueKindsCustomSizesAndErrors() throws {
        let variants: [CodecValue] = [.string("one"), .int(2), .uint64(3), .bool(false), .null, .void]
        let codec = getLiteralUnionCodec(variants)

        XCTAssertEqual(codec.fixedSize, 1)
        XCTAssertEqual(try codec.encode(.string("one")).hex, "00")
        XCTAssertEqual(try codec.encode(.int(2)).hex, "01")
        XCTAssertEqual(try codec.encode(.uint64(3)).hex, "02")
        XCTAssertEqual(try codec.encode(.bool(false)).hex, "03")
        XCTAssertEqual(try codec.encode(.null).hex, "04")
        XCTAssertEqual(try codec.encode(.void).hex, "05")
        XCTAssertEqual(try codec.decode(Data(hex: "00")), .string("one"))
        XCTAssertEqual(try codec.decode(Data(hex: "01")), .int(2))
        XCTAssertEqual(try codec.decode(Data(hex: "02")), .uint64(3))
        XCTAssertEqual(try codec.decode(Data(hex: "03")), .bool(false))
        XCTAssertEqual(try codec.decode(Data(hex: "04")), .null)
        XCTAssertEqual(try codec.decode(Data(hex: "05")), .void)
        XCTAssertEqual(try writtenOffset(codec, value: .string("one"), offset: 6), 7)
        XCTAssertEqual(try codec.read(Data(hex: "ffff00"), at: 2).0, .string("one"))
        XCTAssertEqual(try codec.read(Data(hex: "ffff00"), at: 2).1, 3)

        let u32Codec = getLiteralUnionCodec(variants, size: intValueCodec(getU32Codec()))
        XCTAssertEqual(u32Codec.fixedSize, 4)
        XCTAssertEqual(try u32Codec.encode(.uint64(3)).hex, "02000000")
        XCTAssertEqual(try u32Codec.decode(Data(hex: "02000000")), .uint64(3))

        let shortU16Codec = getLiteralUnionCodec(variants, size: intValueCodec(getShortU16Codec()))
        XCTAssertNil(shortU16Codec.fixedSize)
        XCTAssertEqual(shortU16Codec.maxSize, 3)
        XCTAssertEqual(try shortU16Codec.getSizeFromValue(.string("one")), 1)

        assertExactCodecError(
            try codec.encode(.string("missing")),
            .invalidLiteralUnionVariant(
                value: "missing",
                variants: ["one", "2", "3", "false", "null", "undefined"]
            )
        )
        assertExactCodecError(
            try codec.decode(Data(hex: "06")),
            .literalUnionDiscriminatorOutOfRange(discriminator: 6, minRange: 0, maxRange: 5)
        )
    }

    func testEnumHelpersAndCodecsHandleConflictsRangesAndLexicalValues() throws {
        let feedback = [EnumCase("Bad", .int(0)), EnumCase("Good", .int(1))]
        let feedbackStats = getEnumStats(feedback)
        XCTAssertEqual(feedbackStats.enumKeys, ["Bad", "Good"])
        XCTAssertEqual(feedbackStats.enumValues, [.int(0), .int(1)])
        XCTAssertEqual(feedbackStats.numericalValues, [0, 1])
        XCTAssertEqual(feedbackStats.stringValues, ["Bad", "Good"])

        let lexical = [
            EnumCase("Up", .string("up")),
            EnumCase("Down", .string("down")),
            EnumCase("Left", .string("left")),
            EnumCase("Right", .string("right")),
        ]
        let lexicalStats = getEnumStats(lexical)
        XCTAssertEqual(lexicalStats.numericalValues, [])
        XCTAssertEqual(lexicalStats.stringValues, ["Up", "Down", "Left", "Right", "up", "down", "left", "right"])

        let crossed = [EnumCase("A", .string("B")), EnumCase("B", .string("A"))]
        let crossedStats = getEnumStats(crossed)
        XCTAssertEqual(getEnumIndexFromVariant(stats: crossedStats, variant: .string("A")), 1)
        XCTAssertEqual(getEnumIndexFromVariant(stats: crossedStats, variant: .string("B")), 0)

        let duplicates = [EnumCase("A", .int(42)), EnumCase("B", .int(42))]
        let duplicateStats = getEnumStats(duplicates)
        XCTAssertEqual(getEnumIndexFromVariant(stats: duplicateStats, variant: .int(42)), 1)
        XCTAssertEqual(getEnumIndexFromVariant(stats: duplicateStats, variant: .string("A")), 0)
        XCTAssertEqual(getEnumIndexFromDiscriminator(stats: duplicateStats, discriminator: 42, useValuesAsDiscriminators: true), 1)
        XCTAssertEqual(getEnumIndexFromDiscriminator(stats: duplicateStats, discriminator: 2, useValuesAsDiscriminators: false), -1)

        XCTAssertEqual(formatNumericalValues([]), "")
        XCTAssertEqual(formatNumericalValues([1]), "1")
        XCTAssertEqual(formatNumericalValues([4, 5, 6, 7, 8]), "4-8")
        XCTAssertEqual(formatNumericalValues([3, 5, 7, 11, 13]), "3, 5, 7, 11, 13")

        let numbers = [
            EnumCase("Zero", .int(0)),
            EnumCase("Five", .int(5)),
            EnumCase("Six", .int(6)),
            EnumCase("Nine", .int(9)),
        ]
        let positionalCodec = getEnumCodec(numbers)
        XCTAssertEqual(positionalCodec.fixedSize, 1)
        XCTAssertEqual(try positionalCodec.encode(.int(5)).hex, "01")
        XCTAssertEqual(try positionalCodec.encode(.string("Nine")).hex, "03")
        XCTAssertEqual(try positionalCodec.decode(Data(hex: "03")), .int(9))
        XCTAssertEqual(try writtenOffset(positionalCodec, value: .string("Zero"), offset: 6), 7)
        XCTAssertEqual(try positionalCodec.read(Data(hex: "ffff00"), at: 2).1, 3)
        assertExactCodecError(
            try positionalCodec.encode(.string("Missing")),
            .invalidEnumVariant(
                variant: "Missing",
                stringValues: ["Zero", "Five", "Six", "Nine"],
                numericalValues: [0, 5, 6, 9],
                formattedNumericalValues: "0, 5-6, 9"
            )
        )
        assertExactCodecError(
            try positionalCodec.decode(Data(hex: "04")),
            .enumDiscriminatorOutOfRange(
                discriminator: 4,
                formattedValidDiscriminators: "0-3",
                validDiscriminators: [0, 1, 2, 3]
            )
        )

        let valueDiscriminatorCodec = getEnumCodec(numbers, useValuesAsDiscriminators: true)
        XCTAssertEqual(try valueDiscriminatorCodec.encode(.string("Five")).hex, "05")
        XCTAssertEqual(try valueDiscriminatorCodec.encode(.int(9)).hex, "09")
        XCTAssertEqual(try valueDiscriminatorCodec.decode(Data(hex: "09")), .int(9))
        assertExactCodecError(
            try valueDiscriminatorCodec.decode(Data(hex: "01")),
            .enumDiscriminatorOutOfRange(
                discriminator: 1,
                formattedValidDiscriminators: "0, 5-6, 9",
                validDiscriminators: [0, 5, 6, 9]
            )
        )

        let duplicateCodec = getEnumCodec(duplicates)
        XCTAssertEqual(try duplicateCodec.encode(.int(42)).hex, "01")
        XCTAssertEqual(try duplicateCodec.encode(.string("A")).hex, "00")
        XCTAssertEqual(try duplicateCodec.encode(.string("B")).hex, "01")

        let duplicateValueCodec = getEnumCodec(duplicates, useValuesAsDiscriminators: true)
        XCTAssertEqual(try duplicateValueCodec.encode(.int(42)).hex, "2a")
        XCTAssertEqual(try duplicateValueCodec.encode(.string("A")).hex, "2a")
        XCTAssertEqual(try duplicateValueCodec.decode(Data(hex: "2a")), .int(42))

        let hybrid = [
            EnumCase("Zero", .int(0)),
            EnumCase("Five", .int(5)),
            EnumCase("Seven", .string("seven")),
        ]
        let hybridValueCodec = getEnumCodec(hybrid, useValuesAsDiscriminators: true)
        assertExactCodecError(
            try hybridValueCodec.encode(.string("Zero")),
            .cannotUseLexicalValuesAsEnumDiscriminators(stringValues: ["seven"])
        )
    }

    func testNullableCodecsCoverPrefixNoneValueSizeAndErrorCases() throws {
        let defaultCodec = getNullableCodec(getU16Codec())
        XCTAssertEqual(try defaultCodec.encode(Optional<Int>.some(0)).hex, "010000")
        XCTAssertEqual(try defaultCodec.encode(Optional<Int>.some(42)).hex, "012a00")
        XCTAssertEqual(try defaultCodec.encode(Optional<Int>.none).hex, "00")
        XCTAssertEqual(try defaultCodec.decode(Data(hex: "010000")), 0)
        XCTAssertEqual(try defaultCodec.decode(Data(hex: "012a00")), 42)
        XCTAssertNil(try defaultCodec.decode(Data(hex: "00")))
        XCTAssertEqual(try writtenOffset(defaultCodec, value: Optional<Int>.some(257), offset: 3), 6)
        XCTAssertEqual(try writtenOffset(defaultCodec, value: Optional<Int>.none, offset: 3), 4)
        XCTAssertEqual(try defaultCodec.read(Data(hex: "ffff01010100"), at: 2).0, 257)
        XCTAssertEqual(try defaultCodec.read(Data(hex: "ffff01010100"), at: 2).1, 5)
        XCTAssertNil(try defaultCodec.read(Data(hex: "ffff00"), at: 2).0)
        XCTAssertEqual(try defaultCodec.read(Data(hex: "ffff00"), at: 2).1, 3)
        XCTAssertEqual(try defaultCodec.getSizeFromValue(nil), 1)
        XCTAssertEqual(try defaultCodec.getSizeFromValue(42), 3)
        XCTAssertEqual(defaultCodec.maxSize, 3)

        let u32PrefixCodec = getNullableCodec(getU16Codec(), prefix: .fixed(getU32Codec()))
        XCTAssertEqual(try u32PrefixCodec.encode(Optional<Int>.some(42)).hex, "010000002a00")
        XCTAssertEqual(try u32PrefixCodec.encode(Optional<Int>.none).hex, "00000000")
        XCTAssertEqual(try u32PrefixCodec.decode(Data(hex: "010000002a00")), 42)
        XCTAssertNil(try u32PrefixCodec.decode(Data(hex: "00000000")))

        let nullableString = getNullableCodec(getUtf8Codec())
        XCTAssertEqual(try nullableString.encode(Optional<String>.some("Hello")).hex, "0148656c6c6f")
        XCTAssertEqual(try nullableString.encode(Optional<String>.none).hex, "00")
        XCTAssertEqual(try nullableString.decode(Data(hex: "0148656c6c6f")), "Hello")
        XCTAssertNil(try nullableString.decode(Data(hex: "00")))

        let noPrefix = getNullableCodec(getU16Codec(), prefix: .none)
        XCTAssertEqual(try noPrefix.encode(Optional<Int>.some(42)).hex, "2a00")
        XCTAssertEqual(try noPrefix.encode(Optional<Int>.none).hex, "")
        XCTAssertEqual(try noPrefix.decode(Data(hex: "2a00")), 42)
        XCTAssertNil(try noPrefix.decode(Data()))
        XCTAssertEqual(try writtenOffset(noPrefix, value: Optional<Int>.some(257), offset: 3), 5)
        XCTAssertEqual(try writtenOffset(noPrefix, value: Optional<Int>.none, offset: 3), 3)
        XCTAssertEqual(try noPrefix.getSizeFromValue(nil), 0)
        XCTAssertEqual(try noPrefix.getSizeFromValue(42), 2)
        XCTAssertEqual(noPrefix.maxSize, 2)

        let zeroNoPrefix = try getFixedNullableCodec(getU16Codec(), prefix: .none, noneValue: .zeroes)
        XCTAssertEqual(zeroNoPrefix.fixedSize, 2)
        XCTAssertEqual(try zeroNoPrefix.encode(Optional<Int>.some(42)).hex, "2a00")
        XCTAssertEqual(try zeroNoPrefix.encode(Optional<Int>.none).hex, "0000")
        XCTAssertEqual(try zeroNoPrefix.encode(Optional<Int>.some(0)).hex, "0000")
        XCTAssertNil(try zeroNoPrefix.decode(Data(hex: "0000")))
        XCTAssertEqual(try zeroNoPrefix.decode(Data(hex: "2a00")), 42)

        let customNoneBytes = try Data(hex: "ffff")
        let customNoPrefix = getNullableCodec(getU16Codec(), prefix: .none, noneValue: .bytes(customNoneBytes))
        XCTAssertEqual(try customNoPrefix.encode(Optional<Int>.some(42)).hex, "2a00")
        XCTAssertEqual(try customNoPrefix.encode(Optional<Int>.none).hex, "ffff")
        XCTAssertEqual(try customNoPrefix.encode(Optional<Int>.some(65_535)).hex, "ffff")
        XCTAssertNil(try customNoPrefix.decode(Data(hex: "ffff")))
        XCTAssertEqual(try customNoPrefix.decode(Data(hex: "2a00")), 42)

        let longerCustomNone = getNullableCodec(getU16Codec(), prefix: .none, noneValue: .bytes(try Data(hex: "ffffffff")))
        XCTAssertEqual(try longerCustomNone.getSizeFromValue(nil), 4)
        XCTAssertEqual(try longerCustomNone.getSizeFromValue(42), 2)
        XCTAssertEqual(longerCustomNone.maxSize, 4)

        let customWithPrefix = getNullableCodec(getU16Codec(), prefix: .u8, noneValue: .bytes(customNoneBytes))
        XCTAssertEqual(try customWithPrefix.encode(Optional<Int>.some(42)).hex, "012a00")
        XCTAssertEqual(try customWithPrefix.encode(Optional<Int>.none).hex, "00ffff")
        XCTAssertNil(try customWithPrefix.decode(Data(hex: "00ffff")))
        assertExactCodecError(
            try customWithPrefix.decode(Data(hex: "000000")),
            .invalidConstant(constant: customNoneBytes, data: try Data(hex: "000000"), offset: 1)
        )

        let variablePrefixZeroes = getNullableCodec(
            getU16Codec(),
            prefix: .variable(getShortU16Codec()),
            noneValue: .zeroes
        )
        XCTAssertEqual(try variablePrefixZeroes.encode(Optional<Int>.some(42)).hex, "012a00")
        XCTAssertEqual(try variablePrefixZeroes.encode(Optional<Int>.none).hex, "000000")
        XCTAssertEqual(try variablePrefixZeroes.getSizeFromValue(nil), 3)
        XCTAssertEqual(try variablePrefixZeroes.getSizeFromValue(42), 3)
        XCTAssertEqual(variablePrefixZeroes.maxSize, 5)

        assertExactCodecError(
            try getFixedNullableCodec(getU16Codec(), prefix: .variable(getShortU16Codec()), noneValue: .zeroes),
            .expectedFixedLength
        )
    }

    func testDiscriminatedUnionCodecsCoverVariantShapesDiscriminatorsAndSizes() throws {
        let webEvent = makeWebEventCodec()
        let pageLoad = CodecValue.object(["__kind": .string("PageLoad")])
        let pageUnload = CodecValue.object(["__kind": .string("PageUnload")])
        XCTAssertEqual(try webEvent.encode(pageLoad).hex, "00")
        XCTAssertEqual(try webEvent.read(Data(hex: "ffff00"), at: 2).0, pageLoad)
        XCTAssertEqual(try webEvent.read(Data(hex: "ffff00"), at: 2).1, 3)
        XCTAssertEqual(try webEvent.encode(pageUnload).hex, "03")
        XCTAssertEqual(try webEvent.read(Data(hex: "ffff03"), at: 2).0, pageUnload)
        XCTAssertEqual(try webEvent.getSizeFromValue(pageLoad), 1)
        XCTAssertEqual(try webEvent.getSizeFromValue(.object(["__kind": .string("Click"), "x": .int(0), "y": .int(1)])), 3)
        XCTAssertEqual(try webEvent.getSizeFromValue(.object(["__kind": .string("KeyPress"), "fields": .array([.string("ABC")])])), 8)
        XCTAssertNil(webEvent.maxSize)

        let click = CodecValue.object(["__kind": .string("Click"), "x": .int(1), "y": .int(2)])
        XCTAssertEqual(try webEvent.encode(click).hex, "010102")
        XCTAssertEqual(try webEvent.read(Data(hex: "010102"), at: 0).0, click)
        XCTAssertEqual(try webEvent.read(Data(hex: "ffff010102"), at: 2).1, 5)

        let keyPress = CodecValue.object(["__kind": .string("KeyPress"), "fields": .array([.string("enter")])])
        XCTAssertEqual(try webEvent.encode(keyPress).hex, "0205000000656e746572")
        XCTAssertEqual(try webEvent.read(Data(hex: "0205000000656e746572"), at: 0).0, keyPress)

        assertExactCodecError(
            try webEvent.encode(.object(["__kind": .string("Missing")])),
            .invalidDiscriminatedUnionVariant(
                value: "Missing",
                variants: ["PageLoad", "Click", "KeyPress", "PageUnload"]
            )
        )
        assertExactCodecError(
            try webEvent.decode(Data(hex: "04")),
            .unionVariantOutOfRange(variant: 4, minRange: 0, maxRange: 3)
        )

        let sameSize = getDiscriminatedUnionCodec([
            DiscriminatedUnionVariant(.string("A"), getStructCodec([StructField("value", intValueCodec(getU16Codec()))])),
            DiscriminatedUnionVariant(.string("B"), getStructCodec([
                StructField("x", intValueCodec(getU8Codec())),
                StructField("y", intValueCodec(getU8Codec())),
            ])),
            DiscriminatedUnionVariant(.string("C"), getStructCodec([
                StructField("items", getTupleCodec([booleanValueCodec(getBooleanCodec()), booleanValueCodec(getBooleanCodec())])),
            ])),
        ])
        XCTAssertEqual(sameSize.fixedSize, 3)

        let sameSizeU32 = getDiscriminatedUnionCodec([
            DiscriminatedUnionVariant(.string("A"), getStructCodec([StructField("value", intValueCodec(getU16Codec()))])),
            DiscriminatedUnionVariant(.string("B"), getStructCodec([
                StructField("x", intValueCodec(getU8Codec())),
                StructField("y", intValueCodec(getU8Codec())),
            ])),
        ], size: intValueCodec(getU32Codec()))
        let a = CodecValue.object(["__kind": .string("A"), "value": .int(42)])
        XCTAssertEqual(sameSizeU32.fixedSize, 6)
        XCTAssertEqual(try sameSizeU32.encode(a).hex, "000000002a00")
        XCTAssertEqual(try sameSizeU32.read(Data(hex: "000000002a00"), at: 0).0, a)

        let customDiscriminator = getDiscriminatedUnionCodec([
            DiscriminatedUnionVariant(.string("small"), getStructCodec([StructField("value", intValueCodec(getU8Codec()))])),
            DiscriminatedUnionVariant(.string("large"), getStructCodec([StructField("value", intValueCodec(getU32Codec()))])),
        ], discriminator: "size")
        let small = CodecValue.object(["size": .string("small"), "value": .int(42)])
        let large = CodecValue.object(["size": .string("large"), "value": .int(42)])
        XCTAssertEqual(try customDiscriminator.encode(small).hex, "002a")
        XCTAssertEqual(try customDiscriminator.read(Data(hex: "002a"), at: 0).0, small)
        XCTAssertEqual(try customDiscriminator.encode(large).hex, "012a000000")
        XCTAssertEqual(try customDiscriminator.read(Data(hex: "012a000000"), at: 0).0, large)

        let numericDiscriminator = getDiscriminatedUnionCodec([
            DiscriminatedUnionVariant(.int(1), getStructCodec([StructField("one", intValueCodec(getU8Codec()))])),
            DiscriminatedUnionVariant(.int(2), getStructCodec([StructField("two", intValueCodec(getU32Codec()))])),
        ])
        let one = CodecValue.object(["__kind": .int(1), "one": .int(42)])
        XCTAssertEqual(try numericDiscriminator.encode(one).hex, "002a")
        XCTAssertEqual(try numericDiscriminator.read(Data(hex: "002a"), at: 0).0, one)

        let booleanDiscriminator = getDiscriminatedUnionCodec([
            DiscriminatedUnionVariant(.bool(true), getStructCodec([StructField("truth", intValueCodec(getU8Codec()))])),
            DiscriminatedUnionVariant(.bool(false), getStructCodec([StructField("lie", intValueCodec(getU32Codec()))])),
        ])
        let truth = CodecValue.object(["__kind": .bool(true), "truth": .int(42)])
        XCTAssertEqual(try booleanDiscriminator.encode(truth).hex, "002a")
        XCTAssertEqual(try booleanDiscriminator.read(Data(hex: "002a"), at: 0).0, truth)

        let u64Enum = getDiscriminatedUnionCodec([
            DiscriminatedUnionVariant(.string("A"), unitValueCodec()),
            DiscriminatedUnionVariant(.string("B"), getStructCodec([StructField("value", uint64ValueCodec(getU64Codec()))])),
        ])
        XCTAssertNil(u64Enum.fixedSize)
        XCTAssertEqual(u64Enum.maxSize, 9)
        let b = CodecValue.object(["__kind": .string("B"), "value": .uint64(2)])
        XCTAssertEqual(try u64Enum.encode(b).hex, "010200000000000000")
        XCTAssertEqual(try u64Enum.read(Data(hex: "010200000000000000"), at: 0).0, b)
    }

    func testHiddenPrefixSuffixPredicateAndPatternMatchCodecsPreserveOrdering() throws {
        let prefix = try getHiddenPrefixCodec(
            getUtf8Codec(),
            prefixes: [getConstantCodec(Data(hex: "010203")), getConstantCodec(Data(hex: "040506"))]
        )
        XCTAssertEqual(try prefix.encode("Hello").hex, "01020304050648656c6c6f")
        XCTAssertEqual(try prefix.decode(Data(hex: "01020304050648656c6c6f")), "Hello")
        XCTAssertEqual(try prefix.getSizeFromValue("Hello"), 11)

        let suffix = try getHiddenSuffixCodec(
            getUtf8Codec(),
            suffixes: [getConstantCodec(Data(hex: "010203")), getConstantCodec(Data(hex: "040506"))]
        )
        XCTAssertEqual(try suffix.encode("Hello").hex, "48656c6c6f010203040506")
        XCTAssertEqual(try suffix.getSizeFromValue("Hello"), 11)

        let fixedPrefix = try getHiddenPrefixCodec(
            getU8Codec(),
            prefixes: [getConstantCodec(Data(hex: "aa")), getConstantCodec(Data(hex: "bb"))]
        )
        XCTAssertEqual(fixedPrefix.fixedSize, 3)
        XCTAssertEqual(try writtenOffset(fixedPrefix, value: 1, offset: 2), 5)
        XCTAssertEqual(try fixedPrefix.read(Data(hex: "ffffaabb0100"), at: 2).0, 1)
        XCTAssertEqual(try fixedPrefix.read(Data(hex: "ffffaabb0100"), at: 2).1, 5)

        let fixedSuffix = try getHiddenSuffixCodec(
            getU8Codec(),
            suffixes: [getConstantCodec(Data(hex: "aa")), getConstantCodec(Data(hex: "bb"))]
        )
        XCTAssertEqual(fixedSuffix.fixedSize, 3)
        XCTAssertEqual(try writtenOffset(fixedSuffix, value: 1, offset: 2), 5)
        XCTAssertEqual(try fixedSuffix.read(Data(hex: "ffff01aabb00"), at: 2).0, 1)
        XCTAssertEqual(try fixedSuffix.read(Data(hex: "ffff01aabb00"), at: 2).1, 5)

        let small = byteValueCodec(byte: 1, value: .int(1))
        let large = byteValueCodec(byte: 2, value: .int(2))
        let predicate = getPredicateCodec(
            encodePredicate: { $0 == .int(1) },
            decodePredicate: { $0.first == 1 },
            ifTrue: small,
            ifFalse: large
        )
        XCTAssertEqual(try predicate.encode(.int(1)).hex, "01")
        XCTAssertEqual(try predicate.encode(.int(2)).hex, "02")
        XCTAssertEqual(try predicate.decode(Data(hex: "01")), .int(1))
        XCTAssertEqual(try predicate.decode(Data(hex: "02")), .int(2))

        let pattern = getPatternMatchCodec([
            (value: { $0 == .int(0) }, bytes: { $0.first == 0 }, codec: byteValueCodec(byte: 0, value: .int(0))),
            (value: { $0 == .int(1) }, bytes: { $0.first == 1 }, codec: byteValueCodec(byte: 1, value: .int(1))),
            (value: { $0 == .int(2) }, bytes: { $0.first == 2 }, codec: byteValueCodec(byte: 2, value: .int(2))),
        ])
        XCTAssertEqual(try pattern.encode(.int(0)).hex, "00")
        XCTAssertEqual(try pattern.encode(.int(2)).hex, "02")
        XCTAssertEqual(try pattern.decode(Data(hex: "01")), .int(1))
        assertExactCodecError(try pattern.encode(.int(42)), .invalidPatternMatchValue)
        assertExactCodecError(try pattern.decode(Data(hex: "2a")), .invalidPatternMatchBytes)
    }

    func testScalarCodecsExposeExpectedSizesOffsetsAndBytePacking() throws {
        let bytes = getBytesCodec()
        XCTAssertEqual(try bytes.encode(Data()).hex, "")
        XCTAssertEqual(try bytes.decode(Data()).hex, "")
        XCTAssertEqual(try bytes.encode(Data(hex: "1234567890")).hex, "1234567890")
        XCTAssertEqual(try bytes.decode(Data(hex: "1234567890")).hex, "1234567890")
        XCTAssertEqual(try writtenOffset(bytes, value: Data(hex: "2aff"), offset: 3), 5)
        XCTAssertEqual(try bytes.read(Data(hex: "ffff2aff00"), at: 2).0.hex, "2aff00")
        XCTAssertEqual(try bytes.read(Data(hex: "ffff2aff00"), at: 2).1, 5)
        XCTAssertEqual(try bytes.getSizeFromValue(Data(hex: "2aff")), 2)

        let fixedBytes = fixCodecSize(getBytesCodec(), fixedBytes: 3)
        XCTAssertEqual(fixedBytes.fixedSize, 3)
        XCTAssertEqual(try fixedBytes.encode(Data(hex: "2aff")).hex, "2aff00")
        XCTAssertEqual(try fixedBytes.encode(Data(hex: "2aff0000")).hex, "2aff00")
        XCTAssertEqual(try fixedBytes.decode(Data(hex: "2aff00")).hex, "2aff00")

        let prefixedBytes = addCodecSizePrefix(getBytesCodec(), prefix: getU8Codec())
        XCTAssertEqual(try prefixedBytes.encode(Data(hex: "2aff")).hex, "022aff")
        XCTAssertEqual(try prefixedBytes.decode(Data(hex: "022aff")).hex, "2aff")
        XCTAssertEqual(try prefixedBytes.getSizeFromValue(Data(hex: "2aff")), 3)

        XCTAssertEqual(getBooleanCodec().fixedSize, 1)
        XCTAssertEqual(try writtenOffset(getBooleanCodec(), value: true, offset: 6), 7)
        XCTAssertEqual(try getBooleanCodec().read(Data(hex: "ffff00"), at: 2).0, false)
        XCTAssertEqual(try getBooleanCodec().read(Data(hex: "ffff00"), at: 2).1, 3)
        XCTAssertEqual(getBooleanCodec(size: getU32Codec()).fixedSize, 4)
        XCTAssertEqual(try writtenOffset(getBooleanCodec(size: getU32Codec()), value: true, offset: 3), 7)
        XCTAssertEqual(try getBooleanCodec(size: getU32Codec()).read(Data(hex: "ffff00000000"), at: 2).1, 6)

        let mappedShortU16 = transformCodec(
            getShortU16Codec(),
            encode: { (value: Int) in value == 0 ? 0 : 0xffff },
            decode: { (value: Int) in value == 0 ? 0 : 1 }
        )
        let variableBoolean = getBooleanCodec(size: mappedShortU16)
        XCTAssertEqual(try variableBoolean.encode(true).hex, "ffff03")
        XCTAssertEqual(try variableBoolean.encode(false).hex, "00")
        XCTAssertEqual(try variableBoolean.decode(Data(hex: "ffff03")), true)
        XCTAssertEqual(try variableBoolean.decode(Data(hex: "00")), false)
        XCTAssertEqual(try variableBoolean.getSizeFromValue(false), 1)
        XCTAssertEqual(try variableBoolean.getSizeFromValue(true), 3)
        XCTAssertEqual(variableBoolean.maxSize, 3)

        let bits = getBitArrayCodec(1)
        XCTAssertEqual(bits.fixedSize, 1)
        XCTAssertEqual(try bits.encode([true, false, true, false]).hex, "a0")
        XCTAssertEqual(try bits.decode(Data(hex: "a0")), [true, false, true, false, false, false, false, false])

        let backwardBits = getBitArrayCodec(1, backward: true)
        XCTAssertEqual(try backwardBits.encode([true, false, true, false]).hex, "05")
        XCTAssertEqual(try backwardBits.decode(Data(hex: "05")), [true, false, true, false, false, false, false, false])

        assertExactCodecError(
            try getBitArrayCodec(3).read(Data(hex: "ff"), at: 0),
            .invalidByteLength(codecDescription: "bitArray", expected: 3, bytesLength: 1)
        )

        let unit = getUnitCodec()
        XCTAssertEqual(unit.fixedSize, 0)
        XCTAssertEqual(try unit.encode(()).hex, "")
        XCTAssertEqual(try unit.read(Data(hex: "00"), at: 1).1, 1)

        let constant = try getConstantCodec(Data(hex: "010203"))
        XCTAssertEqual(constant.fixedSize, 3)
        XCTAssertEqual(try constant.encode(()).hex, "010203")
        XCTAssertEqual(try constant.read(Data(hex: "ffff01020300"), at: 2).1, 5)
        assertExactCodecError(
            try constant.decode(Data(hex: "0102ff")),
            .invalidConstant(constant: try Data(hex: "010203"), data: try Data(hex: "0102ff"), offset: 0)
        )
    }
}

private func makeWebEventCodec() -> AnyValueCodec {
    let u8Value = intValueCodec(getU8Codec())
    let stringValue = stringValueCodec(addCodecSizePrefix(getUtf8Codec(), prefix: getU32Codec()))
    return getDiscriminatedUnionCodec([
        DiscriminatedUnionVariant(.string("PageLoad"), unitValueCodec()),
        DiscriminatedUnionVariant(.string("Click"), getStructCodec([
            StructField("x", u8Value),
            StructField("y", u8Value),
        ])),
        DiscriminatedUnionVariant(.string("KeyPress"), getStructCodec([
            StructField("fields", getTupleCodec([stringValue])),
        ])),
        DiscriminatedUnionVariant(.string("PageUnload"), getStructCodec([])),
    ])
}

private func makeMixedUnionCodec() -> AnyValueCodec {
    getUnionCodec(
        [
            stringValueCodec(fixCodecSize(getUtf8Codec(), fixedBytes: 8)),
            intValueCodec(getU16Codec()),
            booleanValueCodec(getBooleanCodec()),
            getStructCodec([
                StructField("x", intValueCodec(getU16Codec())),
                StructField("y", intValueCodec(getU16Codec())),
            ]),
        ],
        getIndexFromValue: { value in
            if value == .int(999) {
                return 999
            }
            if case .string = value {
                return 0
            }
            if case .int = value {
                return 1
            }
            if case .bool = value {
                return 2
            }
            return 3
        },
        getIndexFromBytes: { bytes, offset in
            let length = bytes.count - offset
            if length == 3, bytes.dropFirst(offset).allSatisfy({ $0 == 0xff }) {
                return 999
            }
            switch length {
            case 8:
                return 0
            case 2:
                return 1
            case 1:
                return 2
            default:
                return 3
            }
        }
    )
}

private func byteValueCodec(byte: UInt8, value: CodecValue) -> AnyValueCodec {
    .fixed(createCodec(fixedSize: 1) { _, bytes, offset in
        bytes[offset] = byte
        return offset + 1
    } read: { _, offset in
        (value, offset + 1)
    })
}

private func writtenOffset(
    _ codec: AnyValueCodec,
    value: CodecValue,
    offset: Offset,
    byteCount: Int = 10
) throws -> Offset {
    var bytes = Data(count: byteCount)
    return try codec.write(value, into: &bytes, at: offset)
}

private func writtenOffset<E: Encoder>(
    _ encoder: E,
    value: E.Encoded,
    offset: Offset,
    byteCount: Int = 10
) throws -> Offset {
    var bytes = Data(count: byteCount)
    return try encoder.write(value, into: &bytes, at: offset)
}

private func assertExactCodecError<T>(
    _ expression: @autoclosure () throws -> T,
    _ expected: CodecsError,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        XCTAssertEqual(error as? CodecsError, expected, file: file, line: line)
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
