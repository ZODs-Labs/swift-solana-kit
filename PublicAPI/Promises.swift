public import Foundation

public struct AbortError: Error, Sendable, Equatable, LocalizedError {
    public let reason: String?
    public init(reason: String? = nil)
    public var errorDescription: String? { get }
}

public final class AbortSignal: Sendable {
    public init()
    public init(abortedWith reason: (any Error & Sendable)?)
    public var aborted: Bool { get }
    public func abort(reason: (any Error & Sendable)? = nil)
    public func abortReason() -> (any Error & Sendable)?
    public func waitUntilAborted() async -> any Error & Sendable
}

public func isAbortError(_ error: any Error) -> Bool

public func getAbortablePromise<T: Sendable>(
    _ operation: @Sendable @escaping () async throws -> T,
    abortSignal: AbortSignal? = nil
) async throws -> T

public func safeRace<T: Sendable>(_ contenders: [@Sendable () async throws -> T]) async throws -> T
