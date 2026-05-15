import Foundation

public struct EmptyPluginClientValue: Sendable, Equatable {
    public init() {}
}

public struct PluginClient<Value: Sendable>: Sendable {
    public let value: Value

    public init(_ value: Value) {
        self.value = value
    }

    public func use<Output: Sendable>(
        _ plugin: @Sendable (Value) throws -> Output
    ) rethrows -> PluginClient<Output> {
        PluginClient<Output>(try plugin(value))
    }

    public func useAsync<Output: Sendable>(
        _ plugin: @Sendable @escaping (Value) async throws -> Output
    ) -> AsyncPluginClient<Output> {
        AsyncPluginClient<Output> {
            try await plugin(value)
        }
    }
}

public struct AsyncPluginClient<Value: Sendable>: Sendable {
    private let resolve: @Sendable () async throws -> Value

    public init(_ resolve: @Sendable @escaping () async throws -> Value) {
        self.resolve = resolve
    }

    public func value() async throws -> PluginClient<Value> {
        PluginClient<Value>(try await resolve())
    }

    public func use<Output: Sendable>(
        _ plugin: @Sendable @escaping (Value) throws -> Output
    ) -> AsyncPluginClient<Output> {
        AsyncPluginClient<Output> {
            try plugin(try await resolve())
        }
    }

    public func useAsync<Output: Sendable>(
        _ plugin: @Sendable @escaping (Value) async throws -> Output
    ) -> AsyncPluginClient<Output> {
        AsyncPluginClient<Output> {
            try await plugin(try await resolve())
        }
    }
}

public func createClient() -> PluginClient<EmptyPluginClientValue> {
    PluginClient(EmptyPluginClientValue())
}

public func createClient<Value: Sendable>(_ value: Value) -> PluginClient<Value> {
    PluginClient(value)
}

public func createEmptyClient() -> PluginClient<EmptyPluginClientValue> {
    createClient()
}

public enum PluginClientPropertyValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
}

public struct PluginClientProperties: Sendable, Equatable {
    private var storage: [String: PluginClientPropertyValue]

    public init(_ storage: [String: PluginClientPropertyValue] = [:]) {
        self.storage = storage
    }

    public subscript(_ key: String) -> PluginClientPropertyValue? {
        storage[key]
    }

    public var keys: [String] {
        storage.keys.sorted()
    }

    public func extending(with additions: PluginClientProperties) -> PluginClientProperties {
        var result = storage
        for key in additions.storage.keys {
            result[key] = additions.storage[key]
        }
        return PluginClientProperties(result)
    }
}

public func extendClient(
    _ client: PluginClientProperties,
    _ additions: PluginClientProperties
) -> PluginClientProperties {
    client.extending(with: additions)
}

public struct CleanableClient<Value: Sendable>: Sendable {
    public let value: Value
    private let cleanups: [@Sendable () -> Void]

    public init(value: Value, cleanups: [@Sendable () -> Void]) {
        self.value = value
        self.cleanups = cleanups
    }

    public func dispose() {
        for cleanup in cleanups {
            cleanup()
        }
    }

    public func addingCleanup(_ cleanup: @escaping @Sendable () -> Void) -> CleanableClient<Value> {
        CleanableClient(value: value, cleanups: [cleanup] + cleanups)
    }
}

public func withCleanup<Value: Sendable>(
    _ client: Value,
    cleanup: @escaping @Sendable () -> Void
) -> CleanableClient<Value> {
    CleanableClient(value: client, cleanups: [cleanup])
}

public func withCleanup<Value: Sendable>(
    _ client: CleanableClient<Value>,
    cleanup: @escaping @Sendable () -> Void
) -> CleanableClient<Value> {
    client.addingCleanup(cleanup)
}
