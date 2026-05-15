import Promises
import XCTest
import os

final class PromisesTests: XCTestCase {
    func testAbortErrorRecognition() {
        XCTAssertTrue(isAbortError(AbortError(reason: "aborted")))
        XCTAssertFalse(isAbortError(PromiseTestError.message("nope")))
    }

    func testAbortablePromiseReturnsOperationWithoutSignal() async throws {
        let value = try await getAbortablePromise {
            123
        }
        XCTAssertEqual(value, 123)
    }

    func testAlreadyAbortedSignalWinsOverReadyOperation() async {
        let signal = AbortSignal(abortedWith: AbortError(reason: "o no"))

        await XCTAssertThrowsAbortReason("o no") {
            try await getAbortablePromise({ 123 }, abortSignal: signal)
        }
    }

    func testSignalAbortWinsBeforeOperationSettles() async {
        let signal = AbortSignal()
        let task = Task {
            try await getAbortablePromise(
                {
                    try await Task.sleep(nanoseconds: 50_000_000)
                    return 123
                },
                abortSignal: signal
            )
        }

        signal.abort(reason: AbortError(reason: "o no"))
        await XCTAssertThrowsAbortReason("o no") {
            try await task.value
        }
    }

    func testAbortHandlerRunsSynchronouslyAndOnlyOnce() {
        let signal = AbortSignal()
        let calls = OSAllocatedUnfairLock(initialState: [String]())
        _ = signal.addAbortHandler { error in
            calls.withLock { $0.append((error as? AbortError)?.reason ?? "missing") }
        }

        signal.abort(reason: AbortError(reason: "now"))
        XCTAssertEqual(calls.withLock { $0 }, ["now"])

        signal.abort(reason: AbortError(reason: "again"))
        XCTAssertEqual(calls.withLock { $0 }, ["now"])
    }

    func testAbortHandlerCanBeRemovedBeforeAbort() {
        let signal = AbortSignal()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let remove = signal.addAbortHandler { _ in
            calls.withLock { $0 += 1 }
        }

        remove()
        signal.abort()

        XCTAssertEqual(calls.withLock { $0 }, 0)
    }

    func testOperationResolveAndRejectWinBeforeAbort() async throws {
        let resolveSignal = AbortSignal()
        let resolved = try await getAbortablePromise({ "done" }, abortSignal: resolveSignal)
        XCTAssertEqual(resolved, "done")

        let rejectSignal = AbortSignal()
        do {
            _ = try await getAbortablePromise(
                { () async throws -> String in throw PromiseTestError.message("mais non") },
                abortSignal: rejectSignal
            )
            XCTFail("Expected PromiseTestError")
        } catch let error as PromiseTestError {
            XCTAssertEqual(error, .message("mais non"))
        } catch {
            XCTFail("Expected PromiseTestError, got \(error)")
        }
    }

    func testSafeRaceReturnsFirstSettledValueAndPropagatesErrors() async throws {
        let slow: @Sendable () async throws -> String = {
            try await Task.sleep(nanoseconds: 50_000_000)
            return "slow"
        }
        let fast: @Sendable () async throws -> String = {
            "fast"
        }
        let value = try await safeRace([slow, fast])
        XCTAssertEqual(value, "fast")

        do {
            let failing: @Sendable () async throws -> String = {
                throw PromiseTestError.message("boom")
            }
            let unused: @Sendable () async throws -> String = {
                try await Task.sleep(nanoseconds: 50_000_000)
                return "unused"
            }
            _ = try await safeRace([failing, unused])
            XCTFail("Expected PromiseTestError")
        } catch let error as PromiseTestError {
            XCTAssertEqual(error, .message("boom"))
        } catch {
            XCTFail("Expected PromiseTestError, got \(error)")
        }
    }

    func testSafeRaceAllowsLosingContendersToSettle() async throws {
        let didSettle = OSAllocatedUnfairLock(initialState: false)
        let slow: @Sendable () async throws -> String = {
            try await Task.sleep(nanoseconds: 10_000_000)
            didSettle.withLock { $0 = true }
            return "slow"
        }
        let fast: @Sendable () async throws -> String = {
            "fast"
        }

        let value = try await safeRace([slow, fast])
        XCTAssertEqual(value, "fast")

        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(didSettle.withLock { $0 })
    }

    func testSafeRaceWithNoContendersPendsUntilTaskCancellation() async {
        let completed = OSAllocatedUnfairLock(initialState: false)
        let task = Task {
            defer {
                completed.withLock { $0 = true }
            }
            _ = try await safeRace([]) as String
        }

        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertFalse(completed.withLock { $0 })
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            XCTAssertTrue(completed.withLock { $0 })
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}

private enum PromiseTestError: Error, Sendable, Equatable {
    case message(String)
}

private func XCTAssertThrowsAbortReason<T>(
    _ reason: String,
    operation: () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await operation()
        XCTFail("Expected AbortError", file: file, line: line)
    } catch let error as AbortError {
        XCTAssertEqual(error.reason, reason, file: file, line: line)
    } catch {
        XCTFail("Expected AbortError, got \(error)", file: file, line: line)
    }
}
