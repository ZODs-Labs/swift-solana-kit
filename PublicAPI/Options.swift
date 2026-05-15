// Closed public API contract for Options.

public enum Option<Wrapped: Sendable>: Sendable
public enum OptionNoneValue: Sendable, Equatable
public enum OptionPrefix: Sendable
public indirect enum OptionTreeValue: Sendable, Equatable

Option.case some(Wrapped)
Option.case none
OptionNoneValue.case absent
OptionNoneValue.case zeroes
OptionNoneValue.case bytes(Data)
OptionPrefix.case none
OptionPrefix.case fixed(AnyFixedSizeCodec<Int, Int>)
OptionPrefix.case variable(AnyVariableSizeCodec<Int, Int>)
OptionPrefix.u8: OptionPrefix
OptionTreeValue.case null
OptionTreeValue.case int(Int)
OptionTreeValue.case string(String)
OptionTreeValue.case bool(Bool)
OptionTreeValue.case bytes(Data)
OptionTreeValue.case array([OptionTreeValue])
OptionTreeValue.case object([String: OptionTreeValue])
OptionTreeValue.case option(Option<OptionTreeValue>)

public func some<T: Sendable>(_ value: T) -> Option<T>
public func none<T: Sendable>() -> Option<T>
public func isOption<T: Sendable>(_ value: Option<T>) -> Bool
public func isSome<T: Sendable>(_ option: Option<T>) -> Bool
public func isNone<T: Sendable>(_ option: Option<T>) -> Bool
public func wrapNullable<T: Sendable>(_ nullable: T?) -> Option<T>
public extension Encoder {
    func encode<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Data where Encoded == Option<Wrapped>
    func encode<Wrapped: Sendable>(_ value: Wrapped?) throws(CodecsError) -> Data where Encoded == Option<Wrapped>
    func write<Wrapped: Sendable>(_ value: Wrapped, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset where Encoded == Option<Wrapped>
    func write<Wrapped: Sendable>(_ value: Wrapped?, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset where Encoded == Option<Wrapped>
    func encode<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Data where Encoded == Option<Option<Wrapped>>
    func write<Wrapped: Sendable>(_ value: Wrapped, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset where Encoded == Option<Option<Wrapped>>
}
public extension VariableSizeEncoder {
    func getSizeFromValue<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Int where Encoded == Option<Wrapped>
    func getSizeFromValue<Wrapped: Sendable>(_ value: Wrapped?) throws(CodecsError) -> Int where Encoded == Option<Wrapped>
    func getSizeFromValue<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Int where Encoded == Option<Option<Wrapped>>
}
public func unwrapOption<T: Sendable>(_ option: Option<T>) -> T?
public func unwrapOption<T: Sendable>(_ option: Option<T>, fallback: () -> T) -> T
public func unwrapOptionRecursively(_ input: OptionTreeValue, fallback: (() -> OptionTreeValue)? = nil) -> OptionTreeValue

public func getOptionEncoder<E: Encoder>(_ item: E, prefix: OptionPrefix = .u8, noneValue: OptionNoneValue = .absent) throws(CodecsError) -> AnyVariableSizeEncoder<Option<E.Encoded>>
public func getOptionDecoder<D: Decoder>(_ item: D, prefix: OptionPrefix = .u8, noneValue: OptionNoneValue = .absent) throws(CodecsError) -> AnyVariableSizeDecoder<Option<D.Decoded>>
public func getOptionCodec<C: Codec>(_ item: C, prefix: OptionPrefix = .u8, noneValue: OptionNoneValue = .absent) throws(CodecsError) -> AnyVariableSizeCodec<Option<C.Encoded>, Option<C.Decoded>>
public func getFixedOptionCodec<C: FixedSizeCodec>(_ item: C, prefix: OptionPrefix = .none, noneValue: OptionNoneValue = .zeroes) throws(CodecsError) -> AnyFixedSizeCodec<Option<C.Encoded>, Option<C.Decoded>>
