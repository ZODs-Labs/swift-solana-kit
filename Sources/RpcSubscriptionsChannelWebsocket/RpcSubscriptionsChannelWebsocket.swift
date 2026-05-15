public import Foundation
public import Promises
public import RpcSubscriptionsSpec
import SolanaErrors
import Subscribable
import os

public struct WebSocketChannelConfig: Sendable {
    public let sendBufferHighWatermark: Int
    public let signal: AbortSignal
    public let url: URL

    public init(sendBufferHighWatermark: Int, signal: AbortSignal, url: URL) {
        self.sendBufferHighWatermark = sendBufferHighWatermark
        self.signal = signal
        self.url = url
    }
}

public func createWebSocketChannel(_ config: WebSocketChannelConfig) async throws -> RpcSubscriptionsChannel {
    if let reason = config.signal.abortReason() {
        throw reason
    }
    guard config.url.scheme == "ws" || config.url.scheme == "wss" else {
        throw SolanaError(.rpcSubscriptionsChannelFailedToConnect)
    }
    let publisher = EventDataPublisher()
    let runtime = URLSessionWebSocketChannelRuntime(config: config, publisher: publisher)
    try await runtime.start()
    return RpcSubscriptionsChannel(dataPublisher: publisher) { payload in
        try await runtime.send(payload)
    }
}

private let normalClosureCode = URLSessionWebSocketTask.CloseCode.normalClosure

private final class URLSessionWebSocketChannelRuntime: Sendable {
    private enum ReadyState: Sendable {
        case connecting
        case open
        case closing
        case closed
    }

    private struct State: Sendable {
        var readyState: ReadyState = .connecting
    }

    private let config: WebSocketChannelConfig
    private let openObserver: WebSocketOpenObserver
    private let publisher: EventDataPublisher
    private let sendBuffer: WebSocketSendBuffer
    private let session: URLSession
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let task: URLSessionWebSocketTask

    init(config: WebSocketChannelConfig, publisher: EventDataPublisher) {
        self.config = config
        self.publisher = publisher
        sendBuffer = WebSocketSendBuffer(highWatermark: config.sendBufferHighWatermark)
        let observer = WebSocketOpenObserver()
        openObserver = observer
        session = URLSession(configuration: .default, delegate: observer, delegateQueue: nil)
        task = session.webSocketTask(with: config.url)
        observer.setCloseHandler { [weak self] closeCode in
            self?.handleDelegateClose(closeCode: closeCode)
        }
    }

    func start() async throws {
        task.resume()
        do {
            try await openObserver.waitUntilOpen(signal: config.signal, task: task)
        } catch {
            closeNormally()
            throw error
        }
        state.withLock { $0.readyState = .open }
        _ = config.signal.addAbortHandler { [weak self] _ in
            self?.closeNormally()
        }
        Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func send(_ payload: DataPublisherPayload) async throws {
        guard state.withLock({ $0.readyState == .open }) else {
            throw SolanaError(.rpcSubscriptionsChannelConnectionClosed)
        }
        let message: URLSessionWebSocketTask.Message
        switch payload {
        case let value as String:
            message = .string(value)
        case let value as Data:
            message = .data(value)
        case .none:
            message = .string("")
        default:
            message = .string(String(describing: payload))
        }
        try await sendBuffer.send(byteCount: webSocketMessageByteCount(message)) { [task] in
            try await task.send(message)
        }
    }

    private func closeNormally() {
        let shouldClose = state.withLock { state -> Bool in
            guard state.readyState == .open || state.readyState == .connecting else {
                return false
            }
            state.readyState = .closing
            return true
        }
        if shouldClose {
            Task { [sendBuffer] in
                await sendBuffer.close()
            }
            task.cancel(with: normalClosureCode, reason: nil)
        }
    }

    private func receiveLoop() async {
        while state.withLock({ $0.readyState == .open }) {
            do {
                let message = try await task.receive()
                if config.signal.aborted {
                    continue
                }
                switch message {
                case let .string(value):
                    publisher.publish("message", value)
                case let .data(value):
                    publisher.publish("message", value)
                @unknown default:
                    break
                }
            } catch {
                handleClose(error: error)
                return
            }
        }
    }

    private func handleClose(error: any Error) {
        let shouldPublish = state.withLock { state -> Bool in
            if state.readyState == .closed {
                return false
            }
            let wasAbort = state.readyState == .closing
            state.readyState = .closed
            return !wasAbort
        }
        Task { [sendBuffer] in
            await sendBuffer.close()
        }
        guard shouldPublish else {
            return
        }
        Task { [config, publisher] in
            if config.signal.aborted {
                return
            }
            publisher.publish("error", SolanaError(.rpcSubscriptionsChannelConnectionClosed))
        }
    }

    private func handleDelegateClose(closeCode: URLSessionWebSocketTask.CloseCode) {
        let shouldPublish = state.withLock { state -> Bool in
            if state.readyState == .closed {
                return false
            }
            let wasAbort = state.readyState == .closing
            state.readyState = .closed
            return !wasAbort && closeCode != normalClosureCode
        }
        Task { [sendBuffer] in
            await sendBuffer.close()
        }
        guard shouldPublish else {
            return
        }
        Task { [config, publisher] in
            if config.signal.aborted {
                return
            }
            publisher.publish("error", SolanaError(.rpcSubscriptionsChannelConnectionClosed))
        }
    }
}

private actor WebSocketSendBuffer {
    private var closed = false
    private let highWatermark: Int
    private var inFlightBytes = 0

    init(highWatermark: Int) {
        self.highWatermark = max(0, highWatermark)
    }

    func close() {
        closed = true
    }

    func send(
        byteCount: Int,
        operation: @Sendable () async throws -> Void
    ) async throws {
        guard !closed else {
            throw SolanaError(.rpcSubscriptionsChannelConnectionClosed)
        }
        while inFlightBytes > highWatermark {
            guard !closed else {
                throw SolanaError(.rpcSubscriptionsChannelClosedBeforeMessageBuffered)
            }
            try await Task.sleep(nanoseconds: 16_000_000)
        }
        let admittedBytes = max(0, byteCount)
        inFlightBytes += admittedBytes
        defer {
            inFlightBytes -= admittedBytes
        }
        try await operation()
    }
}

private func webSocketMessageByteCount(_ message: URLSessionWebSocketTask.Message) -> Int {
    switch message {
    case let .string(value):
        return value.utf8.count
    case let .data(value):
        return value.count
    @unknown default:
        return 0
    }
}

final class WebSocketOpenObserver: NSObject, URLSessionWebSocketDelegate, Sendable {
    private struct State: Sendable {
        var closeHandler: (@Sendable (URLSessionWebSocketTask.CloseCode) -> Void)?
        var didCloseBeforeOpen = false
        var didOpen = false
        var continuation: CheckedContinuation<Void, any Error>?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func setCloseHandler(_ handler: @escaping @Sendable (URLSessionWebSocketTask.CloseCode) -> Void) {
        state.withLock { state in
            state.closeHandler = handler
        }
    }

    func waitUntilOpen(signal: AbortSignal, task: URLSessionWebSocketTask) async throws {
        if let reason = signal.abortReason() {
            task.cancel(with: normalClosureCode, reason: nil)
            throw reason
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                try await waitForDelegateOpen()
            }
            group.addTask {
                let reason = await signal.waitUntilAborted()
                task.cancel(with: normalClosureCode, reason: nil)
                throw reason
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func waitForDelegateOpen() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let action = state.withLock { state -> WebSocketOpenAction in
                if state.didOpen {
                    return .resumeOpen
                }
                if state.didCloseBeforeOpen {
                    return .resumeFailed
                }
                state.continuation = continuation
                return .stored
            }
            switch action {
            case .resumeOpen:
                continuation.resume()
            case .resumeFailed:
                continuation.resume(throwing: SolanaError(.rpcSubscriptionsChannelFailedToConnect))
            case .stored:
                break
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            state.didOpen = true
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        continuation?.resume()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let action = state.withLock { state -> WebSocketCloseAction in
            if state.didOpen {
                return .closedAfterOpen(state.closeHandler)
            } else {
                state.didCloseBeforeOpen = true
                let continuation = state.continuation
                state.continuation = nil
                return .closedBeforeOpen(continuation)
            }
        }
        switch action {
        case let .closedAfterOpen(handler):
            handler?(closeCode)
        case let .closedBeforeOpen(continuation):
            continuation?.resume(throwing: SolanaError(.rpcSubscriptionsChannelFailedToConnect))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard error != nil else {
            return
        }
        let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            guard !state.didOpen else {
                return nil
            }
            state.didCloseBeforeOpen = true
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        continuation?.resume(throwing: SolanaError(.rpcSubscriptionsChannelFailedToConnect))
    }
}

private enum WebSocketOpenAction: Sendable {
    case resumeOpen
    case resumeFailed
    case stored
}

private enum WebSocketCloseAction: Sendable {
    case closedAfterOpen((@Sendable (URLSessionWebSocketTask.CloseCode) -> Void)?)
    case closedBeforeOpen(CheckedContinuation<Void, any Error>?)
}

final class WebSocketChannelHarness: Sendable {
    private enum ReadyState: Sendable {
        case connecting
        case open
        case closing
        case closed
    }

    private struct State: Sendable {
        var readyState: ReadyState = .connecting
        var bufferedAmount = 0
        var queued: [DataPublisherPayload] = []
        var sent: [DataPublisherPayload] = []
    }

    let publisher = EventDataPublisher()
    private let highWatermark: Int
    private let signal: AbortSignal
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(highWatermark: Int, signal: AbortSignal) {
        self.highWatermark = highWatermark
        self.signal = signal
    }

    func channel() async throws -> RpcSubscriptionsChannel {
        if let reason = signal.abortReason() {
            throw reason
        }
        state.withLock { $0.readyState = .open }
        _ = signal.addAbortHandler { [weak self] _ in
            self?.close(wasClean: true, code: 1000)
        }
        return RpcSubscriptionsChannel(dataPublisher: publisher) { [weak self] payload in
            try await self?.send(payload)
        }
    }

    func sentMessages() -> [DataPublisherPayload] {
        state.withLock(\.sent)
    }

    func receive(_ message: DataPublisherPayload) {
        Task { [signal, publisher] in
            if signal.aborted {
                return
            }
            publisher.publish("message", message)
        }
    }

    func failToConnect() {
        state.withLock { $0.readyState = .closed }
        publisher.publish("error", SolanaError(.rpcSubscriptionsChannelFailedToConnect))
    }

    func close(wasClean: Bool, code: Int) {
        let shouldPublish = state.withLock { state -> Bool in
            guard state.readyState != .closed else {
                return false
            }
            let wasAbort = state.readyState == .closing || (wasClean && code == 1000)
            state.readyState = .closed
            return !wasAbort
        }
        if shouldPublish {
            publisher.publish("error", SolanaError(.rpcSubscriptionsChannelConnectionClosed))
        }
    }

    func setBufferedAmount(_ amount: Int) {
        let queued = state.withLock { state -> [DataPublisherPayload] in
            state.bufferedAmount = amount
            guard amount <= highWatermark else {
                return []
            }
            let queued = state.queued
            state.sent.append(contentsOf: queued)
            state.queued.removeAll()
            return queued
        }
        _ = queued
    }

    private func send(_ payload: DataPublisherPayload) async throws {
        let result = state.withLock { state -> WebSocketHarnessSendResult in
            switch state.readyState {
            case .closed, .closing, .connecting:
                return .closed
            case .open:
                if state.bufferedAmount > highWatermark {
                    state.queued.append(payload)
                    return .queued
                }
                state.sent.append(payload)
                return .sent
            }
        }
        switch result {
        case .sent:
            return
        case .queued:
            while true {
                try await Task.sleep(nanoseconds: 1_000_000)
                let status = state.withLock { state -> WebSocketHarnessSendResult in
                    if state.readyState != .open {
                        return .closedBeforeBuffered
                    }
                    if state.bufferedAmount <= highWatermark {
                        return .sent
                    }
                    return .queued
                }
                switch status {
                case .sent:
                    return
                case .closedBeforeBuffered:
                    throw SolanaError(.rpcSubscriptionsChannelClosedBeforeMessageBuffered)
                case .queued:
                    continue
                case .closed:
                    throw SolanaError(.rpcSubscriptionsChannelConnectionClosed)
                }
            }
        case .closed:
            throw SolanaError(.rpcSubscriptionsChannelConnectionClosed)
        case .closedBeforeBuffered:
            throw SolanaError(.rpcSubscriptionsChannelClosedBeforeMessageBuffered)
        }
    }
}

private enum WebSocketHarnessSendResult: Sendable {
    case sent
    case queued
    case closed
    case closedBeforeBuffered
}
