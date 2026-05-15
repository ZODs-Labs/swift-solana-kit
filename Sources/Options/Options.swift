public import CodecsCore
import CodecsNumbers
public import Foundation
public import SolanaErrors

public enum Option<Wrapped: Sendable>: Sendable {
    case some(Wrapped)
    case none
}

extension Option: Equatable where Wrapped: Equatable {}
extension Option: Hashable where Wrapped: Hashable {}

public enum OptionNoneValue: Sendable, Equatable {
    case absent
    case zeroes
    case bytes(Data)
}

public enum OptionPrefix: Sendable {
    case none
    case fixed(AnyFixedSizeCodec<Int, Int>)
    case variable(AnyVariableSizeCodec<Int, Int>)

    public static var u8: OptionPrefix {
        .fixed(getU8Codec())
    }
}

public indirect enum OptionTreeValue: Sendable, Equatable {
    case null
    case int(Int)
    case string(String)
    case bool(Bool)
    case bytes(Data)
    case array([OptionTreeValue])
    case object([String: OptionTreeValue])
    case option(Option<OptionTreeValue>)
}

public func some<T: Sendable>(_ value: T) -> Option<T> {
    .some(value)
}

public func none<T: Sendable>() -> Option<T> {
    .none
}

public func isOption<T: Sendable>(_ value: Option<T>) -> Bool {
    switch value {
    case .some, .none:
        true
    }
}

public func isSome<T: Sendable>(_ option: Option<T>) -> Bool {
    if case .some = option {
        return true
    }
    return false
}

public func isNone<T: Sendable>(_ option: Option<T>) -> Bool {
    if case .none = option {
        return true
    }
    return false
}

public func wrapNullable<T: Sendable>(_ nullable: T?) -> Option<T> {
    if let nullable {
        return .some(nullable)
    }
    return .none
}

public extension Encoder {
    func encode<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Data where Encoded == Option<Wrapped> {
        try encode(.some(value))
    }

    func encode<Wrapped: Sendable>(_ value: Wrapped?) throws(CodecsError) -> Data where Encoded == Option<Wrapped> {
        try encode(wrapNullable(value))
    }

    func write<Wrapped: Sendable>(
        _ value: Wrapped,
        into bytes: inout Data,
        at offset: Offset
    ) throws(CodecsError) -> Offset where Encoded == Option<Wrapped> {
        try write(.some(value), into: &bytes, at: offset)
    }

    func write<Wrapped: Sendable>(
        _ value: Wrapped?,
        into bytes: inout Data,
        at offset: Offset
    ) throws(CodecsError) -> Offset where Encoded == Option<Wrapped> {
        try write(wrapNullable(value), into: &bytes, at: offset)
    }

    func encode<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Data where Encoded == Option<Option<Wrapped>> {
        try encode(.some(.some(value)))
    }

    func write<Wrapped: Sendable>(
        _ value: Wrapped,
        into bytes: inout Data,
        at offset: Offset
    ) throws(CodecsError) -> Offset where Encoded == Option<Option<Wrapped>> {
        try write(.some(.some(value)), into: &bytes, at: offset)
    }
}

public extension VariableSizeEncoder {
    func getSizeFromValue<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Int where Encoded == Option<Wrapped> {
        try getSizeFromValue(.some(value))
    }

    func getSizeFromValue<Wrapped: Sendable>(_ value: Wrapped?) throws(CodecsError) -> Int where Encoded == Option<Wrapped> {
        try getSizeFromValue(wrapNullable(value))
    }

    func getSizeFromValue<Wrapped: Sendable>(_ value: Wrapped) throws(CodecsError) -> Int where Encoded == Option<Option<Wrapped>> {
        try getSizeFromValue(.some(.some(value)))
    }
}

public func unwrapOption<T: Sendable>(_ option: Option<T>) -> T? {
    switch option {
    case let .some(value):
        value
    case .none:
        nil
    }
}

public func unwrapOption<T: Sendable>(_ option: Option<T>, fallback: () -> T) -> T {
    switch option {
    case let .some(value):
        value
    case .none:
        fallback()
    }
}

public func unwrapOptionRecursively(_ input: OptionTreeValue, fallback: (() -> OptionTreeValue)? = nil) -> OptionTreeValue {
    switch input {
    case let .option(option):
        switch option {
        case let .some(value):
            return unwrapOptionRecursively(value, fallback: fallback)
        case .none:
            return fallback?() ?? .null
        }
    case let .array(values):
        return .array(values.map { unwrapOptionRecursively($0, fallback: fallback) })
    case let .object(values):
        return .object(values.mapValues { unwrapOptionRecursively($0, fallback: fallback) })
    case .null, .int, .string, .bool, .bytes:
        return input
    }
}

public func getOptionEncoder<E: Encoder>(
    _ item: E,
    prefix: OptionPrefix = .u8,
    noneValue: OptionNoneValue = .absent
) throws(CodecsError) -> AnyVariableSizeEncoder<Option<E.Encoded>> {
    try validateOptionNoneValue(noneValue, encoder: item)
    return createEncoder(maxSize: optionMaxSize(item: item, prefix: prefix, noneValue: noneValue)) { value in
        switch value {
        case let .some(inner):
            return try optionPrefixSize(prefix, flag: true) + optionEncodedSize(inner, using: item)
        case .none:
            return try optionPrefixSize(prefix, flag: false) + optionNoneValueSize(noneValue, item: item)
        }
    } write: { value, bytes, offset in
        var cursor = offset
        switch value {
        case let .some(inner):
            cursor = try writeOptionPrefix(prefix, flag: true, into: &bytes, at: cursor)
            return try item.write(inner, into: &bytes, at: cursor)
        case .none:
            cursor = try writeOptionPrefix(prefix, flag: false, into: &bytes, at: cursor)
            return try writeOptionNoneValue(noneValue, item: item, into: &bytes, at: cursor)
        }
    }
}

public func getOptionDecoder<D: Decoder>(
    _ item: D,
    prefix: OptionPrefix = .u8,
    noneValue: OptionNoneValue = .absent
) throws(CodecsError) -> AnyVariableSizeDecoder<Option<D.Decoded>> {
    try validateOptionNoneValue(noneValue, decoder: item)
    return createDecoder(maxSize: optionDecoderMaxSize(item: item, prefix: prefix, noneValue: noneValue)) { bytes, offset in
        let decision = try optionDecision(prefix: prefix, noneValue: noneValue, item: item, bytes: bytes, offset: offset)
        if decision.isSome {
            let (value, cursor) = try item.read(bytes, at: decision.valueOffset)
            return (Option<D.Decoded>.some(value), cursor)
        }
        return (Option<D.Decoded>.none, decision.noneOffset)
    }
}

public func getOptionCodec<C: Codec>(
    _ item: C,
    prefix: OptionPrefix = .u8,
    noneValue: OptionNoneValue = .absent
) throws(CodecsError) -> AnyVariableSizeCodec<Option<C.Encoded>, Option<C.Decoded>> {
    let encoder = try getOptionEncoder(item, prefix: prefix, noneValue: noneValue)
    let decoder = try getOptionDecoder(item, prefix: prefix, noneValue: noneValue)
    return createCodec(maxSize: optionMaxSize(item: item, prefix: prefix, noneValue: noneValue)) { value in
        try encoder.getSizeFromValue(value)
    } write: { value, bytes, offset in
        try encoder.write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try decoder.read(bytes, at: offset)
    }
}

public func getFixedOptionCodec<C: FixedSizeCodec>(
    _ item: C,
    prefix: OptionPrefix = .none,
    noneValue: OptionNoneValue = .zeroes
) throws(CodecsError) -> AnyFixedSizeCodec<Option<C.Encoded>, Option<C.Decoded>> {
    let prefixFixedSize = try optionFixedPrefixSize(prefix)
    let fixedSize = prefixFixedSize + item.fixedSize
    return createCodec(fixedSize: fixedSize) { value, bytes, offset in
        var cursor = offset
        switch value {
        case let .some(inner):
            cursor = try writeOptionPrefix(prefix, flag: true, into: &bytes, at: cursor)
            return try item.write(inner, into: &bytes, at: cursor)
        case .none:
            cursor = try writeOptionPrefix(prefix, flag: false, into: &bytes, at: cursor)
            return try writeOptionNoneValue(noneValue, item: item, into: &bytes, at: cursor)
        }
    } read: { bytes, offset in
        let decision = try optionDecision(prefix: prefix, noneValue: noneValue, item: item, bytes: bytes, offset: offset)
        if decision.isSome {
            let (value, cursor) = try item.read(bytes, at: decision.valueOffset)
            return (.some(value), cursor)
        }
        return (.none, decision.noneOffset)
    }
}

private struct OptionDecision {
    let isSome: Bool
    let valueOffset: Offset
    let noneOffset: Offset
}

private func validateOptionNoneValue<E: Encoder>(_ noneValue: OptionNoneValue, encoder: E) throws(CodecsError) {
    if case .zeroes = noneValue, (encoder as? any FixedSizeEncoder<E.Encoded>) == nil {
        throw CodecsError.expectedFixedLength
    }
}

private func validateOptionNoneValue<D: Decoder>(_ noneValue: OptionNoneValue, decoder: D) throws(CodecsError) {
    if case .zeroes = noneValue, (decoder as? any FixedSizeDecoder<D.Decoded>) == nil {
        throw CodecsError.expectedFixedLength
    }
}

private func optionDecision<D: Decoder>(
    prefix: OptionPrefix,
    noneValue: OptionNoneValue,
    item: D,
    bytes: Data,
    offset: Offset
) throws(CodecsError) -> OptionDecision {
    switch prefix {
    case .none:
        if noneValue == .absent {
            return OptionDecision(isSome: offset < bytes.count, valueOffset: offset, noneOffset: offset)
        }
        let noneBytes = try optionNoneBytes(noneValue, item: item)
        if containsBytes(bytes, noneBytes, at: offset) {
            return OptionDecision(isSome: false, valueOffset: offset, noneOffset: offset + noneBytes.count)
        }
        return OptionDecision(isSome: true, valueOffset: offset, noneOffset: offset)
    case let .fixed(prefixCodec):
        let (flag, valueOffset) = try prefixCodec.read(bytes, at: offset)
        if flag == 1 {
            return OptionDecision(isSome: true, valueOffset: valueOffset, noneOffset: valueOffset)
        }
        try validatePrefixedNoneValue(noneValue, item: item, bytes: bytes, offset: valueOffset)
        let noneBytes = try optionNoneBytes(noneValue, item: item)
        return OptionDecision(isSome: false, valueOffset: valueOffset, noneOffset: valueOffset + noneBytes.count)
    case let .variable(prefixCodec):
        let (flag, valueOffset) = try prefixCodec.read(bytes, at: offset)
        if flag == 1 {
            return OptionDecision(isSome: true, valueOffset: valueOffset, noneOffset: valueOffset)
        }
        try validatePrefixedNoneValue(noneValue, item: item, bytes: bytes, offset: valueOffset)
        let noneBytes = try optionNoneBytes(noneValue, item: item)
        return OptionDecision(isSome: false, valueOffset: valueOffset, noneOffset: valueOffset + noneBytes.count)
    }
}

private func validatePrefixedNoneValue<D: Decoder>(
    _ noneValue: OptionNoneValue,
    item: D,
    bytes: Data,
    offset: Offset
) throws(CodecsError) {
    guard case let .bytes(expectedBytes) = noneValue else {
        return
    }
    guard containsBytes(bytes, expectedBytes, at: offset) else {
        throw CodecsError.invalidConstant(constant: expectedBytes, data: bytes, offset: offset)
    }
}

private func writeOptionPrefix(_ prefix: OptionPrefix, flag: Bool, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
    switch prefix {
    case .none:
        return offset
    case let .fixed(codec):
        return try codec.write(flag ? 1 : 0, into: &bytes, at: offset)
    case let .variable(codec):
        return try codec.write(flag ? 1 : 0, into: &bytes, at: offset)
    }
}

private func optionPrefixSize(_ prefix: OptionPrefix, flag: Bool) throws(CodecsError) -> Int {
    switch prefix {
    case .none:
        return 0
    case let .fixed(codec):
        return codec.fixedSize
    case let .variable(codec):
        return try codec.getSizeFromValue(flag ? 1 : 0)
    }
}

private func optionFixedPrefixSize(_ prefix: OptionPrefix) throws(CodecsError) -> Int {
    switch prefix {
    case .none:
        return 0
    case let .fixed(codec):
        return codec.fixedSize
    case .variable:
        throw CodecsError.expectedFixedLength
    }
}

private func optionNoneValueSize<E: Encoder>(_ noneValue: OptionNoneValue, item: E) throws(CodecsError) -> Int {
    switch noneValue {
    case .absent:
        return 0
    case .zeroes:
        guard let fixed = item as? any FixedSizeEncoder<E.Encoded> else {
            throw CodecsError.expectedFixedLength
        }
        return fixed.fixedSize
    case let .bytes(bytes):
        return bytes.count
    }
}

private func writeOptionNoneValue<E: Encoder>(
    _ noneValue: OptionNoneValue,
    item: E,
    into bytes: inout Data,
    at offset: Offset
) throws(CodecsError) -> Offset {
    switch noneValue {
    case .absent:
        return offset
    case .zeroes:
        guard let fixed = item as? any FixedSizeEncoder<E.Encoded> else {
            throw CodecsError.expectedFixedLength
        }
        let zeroes = Data(repeating: 0, count: fixed.fixedSize)
        try writeOptionData(zeroes, into: &bytes, at: offset, codecDescription: "option")
        return offset + zeroes.count
    case let .bytes(value):
        try writeOptionData(value, into: &bytes, at: offset, codecDescription: "option")
        return offset + value.count
    }
}

private func optionNoneBytes<D: Decoder>(_ noneValue: OptionNoneValue, item: D) throws(CodecsError) -> Data {
    switch noneValue {
    case .absent:
        return Data()
    case .zeroes:
        guard let fixed = item as? any FixedSizeDecoder<D.Decoded> else {
            throw CodecsError.expectedFixedLength
        }
        return Data(repeating: 0, count: fixed.fixedSize)
    case let .bytes(bytes):
        return bytes
    }
}

private func optionEncodedSize<E: Encoder>(_ value: E.Encoded, using encoder: E) throws(CodecsError) -> Int {
    if let fixed = encoder as? any FixedSizeEncoder<E.Encoded> {
        return fixed.fixedSize
    }
    if let variable = encoder as? any VariableSizeEncoder<E.Encoded> {
        return try variable.getSizeFromValue(value)
    }
    return try encoder.encode(value).count
}

private func optionMaxSize<E: Encoder>(item: E, prefix: OptionPrefix, noneValue: OptionNoneValue) -> Int? {
    let prefixMax: Int?
    switch prefix {
    case .none:
        prefixMax = 0
    case let .fixed(codec):
        prefixMax = codec.fixedSize
    case let .variable(codec):
        prefixMax = codec.maxSize
    }
    guard let prefixMax else {
        return nil
    }
    let someMax = optionEncoderMaxSize(item)
    let noneMax: Int?
    switch noneValue {
    case .absent:
        noneMax = 0
    case .zeroes:
        noneMax = optionEncoderMaxSize(item)
    case let .bytes(bytes):
        noneMax = bytes.count
    }
    guard let someMax, let noneMax else {
        return nil
    }
    return prefixMax + max(someMax, noneMax)
}

private func optionEncoderMaxSize<E: Encoder>(_ encoder: E) -> Int? {
    if let fixed = encoder as? any FixedSizeEncoder<E.Encoded> {
        return fixed.fixedSize
    }
    if let variable = encoder as? any VariableSizeEncoder<E.Encoded> {
        return variable.maxSize
    }
    return nil
}

private func optionDecoderMaxSize<D: Decoder>(item: D, prefix: OptionPrefix, noneValue: OptionNoneValue) -> Int? {
    let prefixMax: Int?
    switch prefix {
    case .none:
        prefixMax = 0
    case let .fixed(codec):
        prefixMax = codec.fixedSize
    case let .variable(codec):
        prefixMax = codec.maxSize
    }
    guard let prefixMax else {
        return nil
    }
    let someMax = optionDecoderMaxSize(item)
    let noneMax: Int?
    switch noneValue {
    case .absent:
        noneMax = 0
    case .zeroes:
        noneMax = optionDecoderMaxSize(item)
    case let .bytes(bytes):
        noneMax = bytes.count
    }
    guard let someMax, let noneMax else {
        return nil
    }
    return prefixMax + max(someMax, noneMax)
}

private func optionDecoderMaxSize<D: Decoder>(_ decoder: D) -> Int? {
    if let fixed = decoder as? any FixedSizeDecoder<D.Decoded> {
        return fixed.fixedSize
    }
    if let variable = decoder as? any VariableSizeDecoder<D.Decoded> {
        return variable.maxSize
    }
    return nil
}

private func writeOptionData(_ source: Data, into destination: inout Data, at offset: Offset, codecDescription: String) throws(CodecsError) {
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: offset, bytesLength: destination.count)
    let end = offset + source.count
    if end > destination.count {
        throw CodecsError.invalidByteLength(codecDescription: codecDescription, expected: end, bytesLength: destination.count)
    }
    destination.replaceSubrange(offset ..< end, with: source)
}
