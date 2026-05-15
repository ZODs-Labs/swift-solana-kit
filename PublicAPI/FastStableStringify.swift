// Closed public API contract for FastStableStringify.
public enum StableStringifyValue: Sendable, Equatable
StableStringifyValue.case null
StableStringifyValue.case bool(Bool)
StableStringifyValue.case string(String)
StableStringifyValue.case number(String)
StableStringifyValue.case nonFiniteNumber
StableStringifyValue.case bigint(String)
StableStringifyValue.case array([StableStringifyValue])
StableStringifyValue.case object([String: StableStringifyValue])
StableStringifyValue.case undefined
StableStringifyValue.case function
StableStringifyValue.case toJSON(StableStringifyValue)

public func fastStableStringify(_ value: StableStringifyValue) -> String?
