import Foundation
import Promises
@testable import RpcSubscriptionsChannelWebsocket
import SolanaErrors
import XCTest

final class RpcSubscriptionsChannelWebsocketDetailedBehaviorTests: XCTestCase {
    func testCreateWebSocketChannelRejectsUnsupportedUrlSchemeBeforeOpening() async throws {
        do {
            _ = try await createWebSocketChannel(
                WebSocketChannelConfig(
                    sendBufferHighWatermark: 0,
                    signal: AbortSignal(),
                    url: try XCTUnwrap(URL(string: "https://example.invalid"))
                )
            )
            XCTFail("Expected unsupported URL scheme to throw")
        } catch let error as any SolanaErrorCoded {
            XCTAssertEqual(error.code, SolanaErrorCode.rpcSubscriptionsChannelFailedToConnect.rawValue)
        }
    }

    func testOpenObserverCompletesWhenOpenArrivesBeforeWaiting() async throws {
        let observer = WebSocketOpenObserver()
        let session = URLSession(configuration: .ephemeral, delegate: observer, delegateQueue: nil)
        let task = session.webSocketTask(with: try XCTUnwrap(URL(string: "wss://example.invalid")))

        observer.urlSession(session, webSocketTask: task, didOpenWithProtocol: nil)

        try await observer.waitUntilOpen(signal: AbortSignal(), task: task)
    }

    func testOpenObserverRejectsWhenCloseArrivesBeforeWaiting() async throws {
        let observer = WebSocketOpenObserver()
        let session = URLSession(configuration: .ephemeral, delegate: observer, delegateQueue: nil)
        let task = session.webSocketTask(with: try XCTUnwrap(URL(string: "wss://example.invalid")))

        observer.urlSession(session, webSocketTask: task, didCloseWith: .abnormalClosure, reason: nil)

        do {
            try await observer.waitUntilOpen(signal: AbortSignal(), task: task)
            XCTFail("Expected early close to reject channel creation")
        } catch let error as any SolanaErrorCoded {
            XCTAssertEqual(error.code, SolanaErrorCode.rpcSubscriptionsChannelFailedToConnect.rawValue)
        }
    }

    func testHarnessPreservesDataAndNilPayloadsInSendOrder() async throws {
        let harness = WebSocketChannelHarness(highWatermark: 10, signal: AbortSignal())
        let channel = try await harness.channel()
        let bytes = Data([1, 2, 3])

        try await channel.send(bytes)
        try await channel.send(nil)

        let sent = harness.sentMessages()
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent[0] as? Data, bytes)
        XCTAssertNil(sent[1])
    }
}
