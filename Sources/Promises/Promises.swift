public import Foundation
import os

public struct AbortError: Error, Sendable, Equatable, LocalizedError {
    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }

    public var errorDescription: String? {
        reason ?? "The operation was aborted."
    }
}

public final class AbortSignal: Sendable {
    package typealias AbortHandler = @Sendable (any Error & Sendable) -> Void

    private struct State: Sendable {
        var abortState: (any Error & Sendable)?
        var continuations: [UUID: CheckedContinuation<any Error & Sendable, Never>] = [:]
        var handlers: [UUID: AbortHandler] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    public init(abortedWith reason: (any Error & Sendable)?) {
        state.withLock { state in
            state.abortState = reason ?? AbortError()
        }
    }

    public var aborted: Bool {
        state.withLock { $0.abortState != nil }
    }

    public func abort(reason: (any Error & Sendable)? = nil) {
        let pending = state.withLock { state -> (
            reason: any Error & Sendable,
            continuations: [CheckedContinuation<any Error & Sendable, Never>],
            handlers: [AbortHandler]
        )? in
            guard state.abortState == nil else {
                return nil
            }
            let error = reason ?? AbortError()
            state.abortState = error
            let continuations = Array(state.continuations.values)
            let handlers = Array(state.handlers.values)
            state.continuations.removeAll(keepingCapacity: false)
            state.handlers.removeAll(keepingCapacity: false)
            return (error, continuations, handlers)
        }
        guard let pending else {
            return
        }
        for handler in pending.handlers {
            handler(pending.reason)
        }
        for continuation in pending.continuations {
            continuation.resume(returning: pending.reason)
        }
    }

    public func abortReason() -> (any Error & Sendable)? {
        state.withLock(\.abortState)
    }

    public func waitUntilAborted() async -> any Error & Sendable {
        if let reason = abortReason() {
            return reason
        }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let immediate = state.withLock { state -> (any Error & Sendable)? in
                    if let abortState = state.abortState {
                        return abortState
                    }
                    if Task.isCancelled {
                        return CancellationError()
                    }
                    state.continuations[id] = continuation
                    return nil
                }
                if let immediate {
                    continuation.resume(returning: immediate)
                }
            }
        } onCancel: {
            cancelWaiter(id: id)
        }
    }

    package func waitUntilFutureAbort() async -> any Error & Sendable {
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let immediate = state.withLock { state -> (any Error & Sendable)? in
                    if Task.isCancelled {
                        return CancellationError()
                    }
                    state.continuations[id] = continuation
                    return nil
                }
                if let immediate {
                    continuation.resume(returning: immediate)
                }
            }
        } onCancel: {
            cancelWaiter(id: id)
        }
    }

    package func addAbortHandler(_ handler: @escaping AbortHandler) -> @Sendable () -> Void {
        let id = UUID()
        let shouldInstall = state.withLock { state -> Bool in
            guard state.abortState == nil else {
                return false
            }
            state.handlers[id] = handler
            return true
        }
        guard shouldInstall else {
            return {}
        }
        return { [weak self] in
            self?.removeAbortHandler(id: id)
        }
    }

    private func cancelWaiter(id: UUID) {
        let continuation = state.withLock { state in
            state.continuations.removeValue(forKey: id)
        }
        if let continuation {
            continuation.resume(returning: CancellationError())
        }
    }

    private func removeAbortHandler(id: UUID) {
        _ = state.withLock { state in
            state.handlers.removeValue(forKey: id)
        }
    }
}

public func isAbortError(_ error: any Error) -> Bool {
    error is AbortError
}

public func getAbortablePromise<T: Sendable>(
    _ operation: @Sendable @escaping () async throws -> T,
    abortSignal: AbortSignal? = nil
) async throws -> T {
    guard let abortSignal else {
        return try await operation()
    }
    if let reason = abortSignal.abortReason() {
        throw reason
    }
    return try await safeRace([
        {
            let reason = await abortSignal.waitUntilAborted()
            throw reason
        },
        operation
    ])
}

public func safeRace<T: Sendable>(_ contenders: [@Sendable () async throws -> T]) async throws -> T {
    let state = SafeRaceState<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            state.install(continuation)
            for contender in contenders {
                Task {
                    do {
                        let value = try await contender()
                        state.complete(.success(value))
                    } catch {
                        state.complete(.failure(error))
                    }
                }
            }
        }
    } onCancel: {
        state.cancel()
    }
}

private final class SafeRaceState<T: Sendable>: Sendable {
    private struct State: Sendable {
        var completed = false
        var continuation: CheckedContinuation<T, any Error>?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func install(_ continuation: CheckedContinuation<T, any Error>) {
        let result = state.withLock { state -> Result<T, any Error>? in
            if state.completed {
                return .failure(CancellationError())
            }
            state.continuation = continuation
            return nil
        }
        if let result {
            continuation.resume(with: result)
        }
    }

    func complete(_ result: Result<T, any Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<T, any Error>? in
            guard !state.completed else {
                return nil
            }
            state.completed = true
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        continuation?.resume(with: result)
    }

    func cancel() {
        complete(.failure(CancellationError()))
    }
}
