import FastStableStringify
import Foundation
import XCTest

final class FastStableStringifyDetailedBehaviorTests: XCTestCase {
    func testEscapedObjectKeysSortByUtf16Order() {
        let mixed = "Aa1 Bb2 Cc3 \u{0000}\u{001F}\u{0020}\u{FFFF}☃\"\\/\u{000C}\n\r\t\u{0008}"
        let value: StableStringifyValue = .object([
            "": .string("EMPTY_STRING"),
            "\u{0000}\u{001F}": .string("ESCAPE_RANGE"),
            "\u{0008}": .string("BACKSPACE"),
            "\t": .string("TAB"),
            "\n": .string("LINE_FEED"),
            "\u{000C}": .string("FORM_FEED"),
            "\r": .string("CARRIAGE_RETURN"),
            "\u{0020}\u{FFFF}": .string("NON_ESCAPE_RANGE"),
            "\"": .string("QUOTATION_MARK"),
            "/": .string("SOLIDUS"),
            "ABC": .string("UPPERCASE"),
            mixed: .string("MIXED"),
            "NUMBER_ONLY": .string("123"),
            "\\": .string("REVERSE_SOLIDUS"),
            "a b c": .string("VALUES_WITH_SPACES"),
            "abc": .string("LOWERCASE"),
            "☃": .string("UTF16"),
        ])

        XCTAssertEqual(
            fastStableStringify(value),
            #"{"":"EMPTY_STRING","\u0000\u001f":"ESCAPE_RANGE","\b":"BACKSPACE","\t":"TAB","\n":"LINE_FEED","\f":"FORM_FEED","\r":"CARRIAGE_RETURN"," ￿":"NON_ESCAPE_RANGE","\"":"QUOTATION_MARK","/":"SOLIDUS","ABC":"UPPERCASE","Aa1 Bb2 Cc3 \u0000\u001f ￿☃\"\\/\f\n\r\t\b":"MIXED","NUMBER_ONLY":"123","\\":"REVERSE_SOLIDUS","a b c":"VALUES_WITH_SPACES","abc":"LOWERCASE","☃":"UTF16"}"#
        )
    }

    func testNestedMixedValuesApplyContainerRulesRecursively() {
        let mixed = "Aa1 Bb2 Cc3 \u{0000}\u{001F}\u{0020}\u{FFFF}☃\"\\/\u{000C}\n\r\t\u{0008}"
        let value: StableStringifyValue = .array([
            .object([
                mixed: .string("MIXED"),
                "DATE": .toJSON(.string("2017-01-01T00:00:00.000Z")),
                "FALSE": .bool(false),
                "FUNCTION": .function,
                "IMPLEMENTING_TO_JSON": .toJSON(.string("dummy!")),
                "MAX_VALUE": .number("1.7976931348623157e+308"),
                "MIN_VALUE": .number("5e-324"),
                "MIXED": .string(mixed),
                "NEGATIVE_MAX_VALUE": .number("-1.7976931348623157e+308"),
                "NEGATIVE_MIN_VALUE": .number("-5e-324"),
                "NOT_IMPLEMENTING_TO_JSON": .object([:]),
                "NULL": .null,
                "TRUE": .bool(true),
                "UNDEFINED": .undefined,
                "zzz": .string("ending"),
            ]),
            .number("-1.7976931348623157e+308"),
            .number("-5e-324"),
            .string(mixed),
            .bool(true),
            .bool(false),
            .null,
            .undefined,
            .toJSON(.string("2017-01-01T00:00:00.000Z")),
            .function,
            .toJSON(.string("dummy!")),
            .object([:]),
        ])

        XCTAssertEqual(
            fastStableStringify(value),
            #" [{"Aa1 Bb2 Cc3 \u0000\u001f ￿☃\"\\/\f\n\r\t\b":"MIXED","DATE":"2017-01-01T00:00:00.000Z","FALSE":false,"IMPLEMENTING_TO_JSON":"dummy!","MAX_VALUE":1.7976931348623157e+308,"MIN_VALUE":5e-324,"MIXED":"Aa1 Bb2 Cc3 \u0000\u001f ￿☃\"\\/\f\n\r\t\b","NEGATIVE_MAX_VALUE":-1.7976931348623157e+308,"NEGATIVE_MIN_VALUE":-5e-324,"NOT_IMPLEMENTING_TO_JSON":{},"NULL":null,"TRUE":true,"zzz":"ending"},-1.7976931348623157e+308,-5e-324,"Aa1 Bb2 Cc3 \u0000\u001f ￿☃\"\\/\f\n\r\t\b",true,false,null,null,"2017-01-01T00:00:00.000Z",null,"dummy!",{}]"#.trimmingCharacters(in: .whitespaces)
        )
    }
}
