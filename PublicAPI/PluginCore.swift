import Foundation

public struct EmptyPluginClientValue: Sendable, Equatable
public init EmptyPluginClientValue()

public struct PluginClient<Value: Sendable>: Sendable
public let PluginClient.value: Value
public init PluginClient(_ value: Value)
public func PluginClient.use<Output: Sendable>(_ plugin: @Sendable (Value) throws -> Output) rethrows -> PluginClient<Output>
public func PluginClient.useAsync<Output: Sendable>(_ plugin: @Sendable @escaping (Value) async throws -> Output) -> AsyncPluginClient<Output>

public struct AsyncPluginClient<Value: Sendable>: Sendable
public init AsyncPluginClient(_ resolve: @Sendable @escaping () async throws -> Value)
public func AsyncPluginClient.value() async throws -> PluginClient<Value>
public func AsyncPluginClient.use<Output: Sendable>(_ plugin: @Sendable @escaping (Value) throws -> Output) -> AsyncPluginClient<Output>
public func AsyncPluginClient.useAsync<Output: Sendable>(_ plugin: @Sendable @escaping (Value) async throws -> Output) -> AsyncPluginClient<Output>

public enum PluginClientPropertyValue: Sendable, Equatable
public enum PluginClientPropertyValue.case string(String)
public enum PluginClientPropertyValue.case int(Int)
public enum PluginClientPropertyValue.case bool(Bool)

public struct PluginClientProperties: Sendable, Equatable
public init PluginClientProperties(_ storage: [String: PluginClientPropertyValue] = [:])
public subscript PluginClientProperties(_ key: String) -> PluginClientPropertyValue? { get }
public var PluginClientProperties.keys: [String] { get }
public func PluginClientProperties.extending(with additions: PluginClientProperties) -> PluginClientProperties

public struct CleanableClient<Value: Sendable>: Sendable
public let CleanableClient.value: Value
public init CleanableClient(value: Value, cleanups: [@Sendable () -> Void])
public func CleanableClient.dispose()
public func CleanableClient.addingCleanup(_ cleanup: @escaping @Sendable () -> Void) -> CleanableClient<Value>

public func createClient() -> PluginClient<EmptyPluginClientValue>
public func createClient<Value: Sendable>(_ value: Value) -> PluginClient<Value>
public func createEmptyClient() -> PluginClient<EmptyPluginClientValue>
public func extendClient(_ client: PluginClientProperties, _ additions: PluginClientProperties) -> PluginClientProperties
public func withCleanup<Value: Sendable>(_ client: Value, cleanup: @escaping @Sendable () -> Void) -> CleanableClient<Value>
public func withCleanup<Value: Sendable>(_ client: CleanableClient<Value>, cleanup: @escaping @Sendable () -> Void) -> CleanableClient<Value>
