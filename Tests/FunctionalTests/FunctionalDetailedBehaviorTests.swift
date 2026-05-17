import Functional
import XCTest

final class FunctionalDetailedBehaviorTests: XCTestCase {
    func testPipePreservesReferenceIdentityWhenTransformReturnsSameInstance() {
        let start = PipeBox(hello: "world")
        let end = pipe(start) { box in
            box.hello = "there"
            return box
        }

        XCTAssertTrue(start === end)
        XCTAssertEqual(start.hello, "there")
    }

    func testPipeCanCreateIndependentValueCopies() {
        let start = PipeRecord(a: 1, b: "test")
        let end = pipe(start) { value in
            PipeRecord(a: value.a, b: "there")
        }

        XCTAssertEqual(start, PipeRecord(a: 1, b: "test"))
        XCTAssertEqual(end, PipeRecord(a: 1, b: "there"))
    }

    func testArrayFieldsCanBeCreatedAppendedDroppedAndRecreated() {
        let result = pipe(
            PipeRecord(a: 1, b: "test"),
            { addOrAppend($0, "test") },
            { addOrAppend($0, "test again") },
            { PipeRecord(a: $0.a, b: "\($0.b ?? "")!", d: $0.d) },
            dropArray,
            { addOrAppend($0, "test again") }
        )

        XCTAssertEqual(result, PipeRecord(a: 1, b: "test!", d: ["test again"]))
    }

    func testNestedPipesCanExtendObjectAndNestedArrayFields() {
        let result = pipe(
            PipeRecord(a: 1),
            { PipeRecord(a: $0.a, b: "2", d: $0.d) },
            { PipeRecord(a: $0.a + 2, b: $0.b, d: $0.d) },
            { value in
                PipeRecord(
                    a: value.a,
                    b: value.b,
                    d: pipe(
                        [String](),
                        { $0 + ["test"] },
                        { $0 + ["test again"] },
                        { $0 + ["test a third time"] }
                    )
                )
            },
            { PipeRecord(a: $0.a + 4, b: $0.b, d: $0.d) }
        )

        XCTAssertEqual(result, PipeRecord(a: 7, b: "2", d: ["test", "test again", "test a third time"]))
    }

    func testThrowStopsLaterTransforms() {
        let recorder = PipeCallRecorder()

        XCTAssertThrowsError(
            try pipe(
                "init",
                { value in recorder.record("first"); return value },
                { (_: String) throws -> String in recorder.record("throw"); throw FunctionalPipeError.test },
                { value in recorder.record("after"); return value.uppercased() }
            )
        ) { error in
            XCTAssertEqual(error as? FunctionalPipeError, .test)
        }
        XCTAssertEqual(recorder.calls, ["first", "throw"])
    }
}

private final class PipeBox {
    var hello: String

    init(hello: String) {
        self.hello = hello
    }
}

private struct PipeRecord: Equatable {
    let a: Int
    let b: String?
    let d: [String]?

    init(a: Int, b: String? = nil, d: [String]? = nil) {
        self.a = a
        self.b = b
        self.d = d
    }
}

private func addOrAppend(_ value: PipeRecord, _ item: String) -> PipeRecord {
    PipeRecord(a: value.a, b: value.b, d: (value.d ?? []) + [item])
}

private func dropArray(_ value: PipeRecord) -> PipeRecord {
    PipeRecord(a: value.a, b: value.b)
}

private final class PipeCallRecorder {
    private(set) var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}

private enum FunctionalPipeError: Error, Equatable {
    case test
}
