import Foundation
import os
import Promises
@testable import RpcSubscriptionsChannelWebsocket
import SolanaErrors
import Subscribable
import XCTest

final class RpcSubscriptionsChannelWebsocketTests: XCTestCase {
    func testCreateWebSocketChannelRejectsAlreadyAbortedSignal() async throws {
        let signal = AbortSignal()
        signal.abort(reason: AbortError(reason: "stop"))
        do {
            _ = try await createWebSocketChannel(
                WebSocketChannelConfig(
                    sendBufferHighWatermark: 0,
                    signal: signal,
                    url: try XCTUnwrap(URL(string: "wss://example.invalid"))
                )
            )
            XCTFail("Expected aborted channel creation to throw")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "stop")
        }
    }

    func testHarnessPublishesMessagesAndSuppressesAfterAbort() async throws {
        let signal = AbortSignal()
        let harness = WebSocketChannelHarness(highWatermark: 10, signal: signal)
        let channel = try await harness.channel()
        let received = OSAllocatedUnfairLock(initialState: [String]())
        _ = try channel.on("message", subscriber: { payload in
            if let value = payload as? String {
                received.withLock { $0.append(value) }
            }
        })
        harness.receive("one")
        try await Task.sleep(nanoseconds: 1_000_000)
        signal.abort()
        harness.receive("two")
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertEqual(received.withLock { $0 }, ["one"])
    }

    func testHarnessPublishesErrorsForUncleanCloseOnly() async throws {
        let signal = AbortSignal()
        let harness = WebSocketChannelHarness(highWatermark: 10, signal: signal)
        let channel = try await harness.channel()
        let errorCodes = OSAllocatedUnfairLock(initialState: [Int]())
        _ = try channel.on("error", subscriber: { payload in
            if let error = payload as? any SolanaErrorCoded {
                errorCodes.withLock { $0.append(error.code) }
            }
        })
        harness.close(wasClean: true, code: 1000)
        XCTAssertEqual(errorCodes.withLock { $0 }, [])

        let second = WebSocketChannelHarness(highWatermark: 10, signal: AbortSignal())
        let secondChannel = try await second.channel()
        _ = try secondChannel.on("error", subscriber: { payload in
            if let error = payload as? any SolanaErrorCoded {
                errorCodes.withLock { $0.append(error.code) }
            }
        })
        second.close(wasClean: false, code: 1006)
        XCTAssertEqual(errorCodes.withLock { $0 }, [SolanaErrorCode.rpcSubscriptionsChannelConnectionClosed.rawValue])
    }

    func testHarnessSendThrowsWhenClosed() async throws {
        let harness = WebSocketChannelHarness(highWatermark: 10, signal: AbortSignal())
        let channel = try await harness.channel()
        harness.close(wasClean: false, code: 1006)
        let code = await throwingCode {
            try await channel.send("message")
        }
        XCTAssertEqual(code, SolanaErrorCode.rpcSubscriptionsChannelConnectionClosed.rawValue)
    }

    func testHarnessSendThrowsImmediatelyAfterAbortSignal() async throws {
        let signal = AbortSignal()
        let harness = WebSocketChannelHarness(highWatermark: 10, signal: signal)
        let channel = try await harness.channel()

        signal.abort()
        let code = await throwingCode {
            try await channel.send("message")
        }

        XCTAssertEqual(code, SolanaErrorCode.rpcSubscriptionsChannelConnectionClosed.rawValue)
    }

    func testOpenObserverRejectsWhenTaskFailsBeforeOpen() async throws {
        let observer = WebSocketOpenObserver()
        let session = URLSession(configuration: .ephemeral, delegate: observer, delegateQueue: nil)
        let task = session.webSocketTask(with: try XCTUnwrap(URL(string: "wss://example.invalid")))
        let waiter = Task {
            try await observer.waitUntilOpen(signal: AbortSignal(), task: task)
        }

        try await Task.sleep(nanoseconds: 1_000_000)
        observer.urlSession(session, task: task, didCompleteWithError: URLError(.cannotConnectToHost))

        do {
            try await waiter.value
            XCTFail("Expected early task failure to reject channel creation")
        } catch let error as any SolanaErrorCoded {
            XCTAssertEqual(error.code, SolanaErrorCode.rpcSubscriptionsChannelFailedToConnect.rawValue)
        }
    }

    func testHarnessQueuesUntilBufferedAmountFalls() async throws {
        let harness = WebSocketChannelHarness(highWatermark: 10, signal: AbortSignal())
        let channel = try await harness.channel()
        harness.setBufferedAmount(11)
        let sendTask = Task {
            try await channel.send("queued")
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertEqual(harness.sentMessages().compactMap { $0 as? String }, [])
        harness.setBufferedAmount(10)
        try await sendTask.value
        XCTAssertEqual(harness.sentMessages().compactMap { $0 as? String }, ["queued"])
    }

    func testHarnessQueuedSendThrowsWhenClosedBeforeBuffering() async throws {
        let harness = WebSocketChannelHarness(highWatermark: 10, signal: AbortSignal())
        let channel = try await harness.channel()
        harness.setBufferedAmount(11)
        let sendTask = Task {
            try await channel.send("queued")
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        harness.close(wasClean: false, code: 1006)
        do {
            try await sendTask.value
            XCTFail("Expected queued send to throw")
        } catch let error as any SolanaErrorCoded {
            XCTAssertEqual(error.code, SolanaErrorCode.rpcSubscriptionsChannelClosedBeforeMessageBuffered.rawValue)
        }
    }
}

private func throwingCode(_ body: () async throws -> Void) async -> Int? {
    do {
        try await body()
        return nil
    } catch let error as any SolanaErrorCoded {
        return error.code
    } catch {
        return nil
    }
}
