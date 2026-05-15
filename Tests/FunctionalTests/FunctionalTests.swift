import Functional
import XCTest

final class FunctionalTests: XCTestCase {
    func testPipesSingleValuesAndSingleFunction() throws {
        XCTAssertEqual(pipe(true), true)
        XCTAssertEqual(pipe("test"), "test")
        XCTAssertEqual(pipe(1), 1)
        XCTAssertEqual(pipe(Optional<Int>.none), nil)
        XCTAssertEqual(pipe("test") { $0.uppercased() }, "TEST")
    }

    func testPipesMultipleFunctionsAndTypes() throws {
        XCTAssertEqual(
            pipe(
                "test",
                { $0.uppercased() },
                { $0 + "!" },
                { String(repeating: $0, count: 3) }
            ),
            "TEST!TEST!TEST!"
        )
        XCTAssertEqual(
            pipe(
                1,
                { $0 + 1 },
                { $0 * 2 },
                { $0 - 1 },
                { "\($0)" },
                { $0 + "!" }
            ),
            "3!"
        )
    }

    func testCombinesArraysDictionariesAndNestedPipes() throws {
        XCTAssertEqual(
            pipe(
                [1],
                { $0 + [2] },
                { $0 + [3] },
                { $0 + [4] }
            ),
            [1, 2, 3, 4]
        )

        XCTAssertEqual(
            pipe(
                ["a": 1],
                { $0.merging(["b": 2]) { _, new in new } },
                { $0.merging(["c": 3]) { _, new in new } },
                { dictionary in
                    pipe(
                        dictionary,
                        { $0.merging(["d": 4]) { _, new in new } },
                        { $0.merging(["e": 5]) { _, new in new } }
                    )
                }
            ),
            ["a": 1, "b": 2, "c": 3, "d": 4, "e": 5]
        )
    }

    func testCapturesThrownErrors() {
        XCTAssertThrowsError(
            try pipe(
                "init",
                { (_: String) throws -> String in throw PipeTestError.test },
                { $0.uppercased() }
            )
        ) { error in
            XCTAssertEqual(error as? PipeTestError, .test)
        }
    }

    func testTenTransforms() throws {
        XCTAssertEqual(
            pipe(
                0,
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 },
                { $0 + 1 }
            ),
            10
        )
    }
}

private enum PipeTestError: Error, Equatable {
    case test
}
