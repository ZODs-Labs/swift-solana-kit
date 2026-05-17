import Promises
import XCTest
import os

final class PromisesDetailedBehaviorTests: XCTestCase {
    func testDefaultAbortReasonIsAbortErrorAndDescribesTheOperation() {
        let signal = AbortSignal(abortedWith: nil)

        XCTAssertTrue(signal.aborted)
        XCTAssertTrue(signal.abortReason() is AbortError)
        XCTAssertEqual((signal.abortReason() as? AbortError)?.reason, nil)
        XCTAssertEqual((signal.abortReason() as? AbortError)?.errorDescription, "The operation was aborted.")
    }

    func testAbortResumesEveryWaiterWithTheSameFirstReason() async {
        let signal = AbortSignal()
        let first = Task { await signal.waitUntilAborted() }
        let second = Task { await signal.waitUntilAborted() }

        await Task.yield()
        signal.abort(reason: AbortError(reason: "first"))
        signal.abort(reason: AbortError(reason: "second"))

        let firstReason = await first.value as? AbortError
        let secondReason = await second.value as? AbortError

        XCTAssertEqual(firstReason?.reason, "first")
        XCTAssertEqual(secondReason?.reason, "first")
        XCTAssertEqual((signal.abortReason() as? AbortError)?.reason, "first")
    }

    func testCancelledAbortWaiterReturnsCancellationWithoutAbortingSignal() async {
        let signal = AbortSignal()
        let waiter = Task {
            await signal.waitUntilAborted()
        }

        waiter.cancel()
        let reason = await waiter.value

        XCTAssertTrue(reason is CancellationError)
        XCTAssertFalse(signal.aborted)
        XCTAssertNil(signal.abortReason())
    }

    func testAbortablePromiseUsesDefaultAbortErrorWhenSignalHasNoReason() async {
        let signal = AbortSignal(abortedWith: nil)

        do {
            _ = try await getAbortablePromise({ 123 }, abortSignal: signal)
            XCTFail("Expected abort")
        } catch let error as AbortError {
            XCTAssertNil(error.reason)
            XCTAssertEqual(error.errorDescription, "The operation was aborted.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlreadyAbortedSignalPreventsOperationExecution() async {
        let signal = AbortSignal(abortedWith: AbortError(reason: "o no"))
        let callCount = OSAllocatedUnfairLock(initialState: 0)

        do {
            _ = try await getAbortablePromise(
                { () async throws -> Int in
                    callCount.withLock { $0 += 1 }
                    throw PromiseDetailedError()
                },
                abortSignal: signal
            )
            XCTFail("Expected abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "o no")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(callCount.withLock { $0 }, 0)
    }

    func testAbortErrorEqualityDependsOnReason() {
        XCTAssertEqual(AbortError(reason: "a"), AbortError(reason: "a"))
        XCTAssertNotEqual(AbortError(reason: "a"), AbortError(reason: "b"))
        XCTAssertNotEqual(AbortError(reason: nil), AbortError(reason: ""))
    }
}

private struct PromiseDetailedError: Error {}
