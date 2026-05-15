import FastStableStringify
import XCTest

final class FastStableStringifyTests: XCTestCase {
    func testSortsObjectKeysAndStringifiesJsonValues() {
        XCTAssertEqual(
            fastStableStringify(.object(["d": .number("0"), "c": .number("1"), "a": .number("2"), "b": .number("3"), "e": .number("4")])),
            #"{"a":2,"b":3,"c":1,"d":0,"e":4}"#
        )
        XCTAssertEqual(
            fastStableStringify(.object(["z": .string("ending"), "false": .bool(false), "true": .bool(true), "null": .null])),
            #"{"false":false,"null":null,"true":true,"z":"ending"}"#
        )
    }

    func testEscapesStringsLikeJSONStringify() {
        XCTAssertEqual(
            fastStableStringify(.string("Aa1 Bb2 Cc3 \u{0000}\u{001F}\u{0020}\u{FFFF}☃\"\\/\u{000C}\n\r\t\u{0008}")),
            #""Aa1 Bb2 Cc3 \u0000\u001f ￿☃\"\\/\f\n\r\t\b""#
        )
    }

    func testUndefinedAndFunctionsFollowJSONContainerRules() {
        XCTAssertNil(fastStableStringify(.undefined))
        XCTAssertNil(fastStableStringify(.function))
        XCTAssertEqual(fastStableStringify(.array([.undefined, .function, .number("1")])), "[null,null,1]")
        XCTAssertEqual(
            fastStableStringify(.object(["one": .undefined, "two": .function, "three": .number("3")])),
            #"{"three":3}"#
        )
    }

    func testBigIntsAndNonFiniteNumbers() {
        XCTAssertEqual(fastStableStringify(.bigint("200")), "200n")
        XCTAssertEqual(
            fastStableStringify(.object(["foo": .bigint("100"), "goo": .string("100n")])),
            #"{"foo":100n,"goo":"100n"}"#
        )
        XCTAssertEqual(fastStableStringify(.array([.number("1.5"), .nonFiniteNumber, .nonFiniteNumber])), "[1.5,null,null]")
    }

    func testToJSONValueIsStringifiedBeforeContainerRules() {
        XCTAssertEqual(fastStableStringify(.toJSON(.string("dummy!"))), #""dummy!""#)
        XCTAssertNil(fastStableStringify(.toJSON(.undefined)))
        XCTAssertEqual(fastStableStringify(.array([.toJSON(.undefined)])), "[null]")
    }
}
