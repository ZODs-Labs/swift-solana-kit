public import Foundation
public import SolanaErrors

public typealias Offset = Int

public protocol Encoder<Encoded>: Sendable {
    associatedtype Encoded

    func encode(_ value: Encoded) throws(CodecsError) -> Data
    func write(_ value: Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset
}

public protocol Decoder<Decoded>: Sendable {
    associatedtype Decoded

    func decode(_ bytes: Data, at offset: Offset) throws(CodecsError) -> Decoded
    func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Decoded, Offset)
}

public protocol Codec<Encoded, Decoded>: Encoder, Decoder {
    associatedtype Encoded
    associatedtype Decoded
}

public protocol FixedSizeEncoder<Encoded>: Encoder {
    var fixedSize: Int { get }
}

public protocol FixedSizeDecoder<Decoded>: Decoder {
    var fixedSize: Int { get }
}

public protocol FixedSizeCodec<Encoded, Decoded>: Codec, FixedSizeEncoder, FixedSizeDecoder {}

public protocol VariableSizeEncoder<Encoded>: Encoder {
    var maxSize: Int? { get }
    func getSizeFromValue(_ value: Encoded) throws(CodecsError) -> Int
}

public protocol VariableSizeDecoder<Decoded>: Decoder {
    var maxSize: Int? { get }
}

public protocol VariableSizeCodec<Encoded, Decoded>: Codec, VariableSizeEncoder, VariableSizeDecoder {}

public struct AnyFixedSizeEncoder<Encoded>: FixedSizeEncoder {
    public let fixedSize: Int
    let writeBody: @Sendable (Encoded, inout Data, Offset) throws -> Offset

    public init(
        fixedSize: Int,
        write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset
    ) {
        self.fixedSize = fixedSize
        self.writeBody = write
    }

    public init<E: FixedSizeEncoder>(_ encoder: E) where E.Encoded == Encoded {
        self.fixedSize = encoder.fixedSize
        self.writeBody = { value, bytes, offset in
            try encoder.write(value, into: &bytes, at: offset)
        }
    }

    public func encode(_ value: Encoded) throws(CodecsError) -> Data {
        var bytes = Data(count: fixedSize)
        _ = try write(value, into: &bytes, at: 0)
        return bytes
    }

    public func write(_ value: Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
        try castCodecsError {
            try writeBody(value, &bytes, offset)
        }
    }
}

public struct AnyVariableSizeEncoder<Encoded>: VariableSizeEncoder {
    public let maxSize: Int?
    let sizeBody: @Sendable (Encoded) throws -> Int
    let writeBody: @Sendable (Encoded, inout Data, Offset) throws -> Offset

    public init(
        maxSize: Int? = nil,
        getSizeFromValue: @escaping @Sendable (Encoded) throws -> Int,
        write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset
    ) {
        self.maxSize = maxSize
        self.sizeBody = getSizeFromValue
        self.writeBody = write
    }

    public init<E: VariableSizeEncoder>(_ encoder: E) where E.Encoded == Encoded {
        self.maxSize = encoder.maxSize
        self.sizeBody = { value in try encoder.getSizeFromValue(value) }
        self.writeBody = { value, bytes, offset in
            try encoder.write(value, into: &bytes, at: offset)
        }
    }

    public func getSizeFromValue(_ value: Encoded) throws(CodecsError) -> Int {
        try castCodecsError {
            try sizeBody(value)
        }
    }

    public func encode(_ value: Encoded) throws(CodecsError) -> Data {
        let size = try getSizeFromValue(value)
        if size < 0 {
            throw CodecsError.expectedPositiveByteLength(codecDescription: "createEncoder", bytesLength: size)
        }
        var bytes = Data(count: size)
        _ = try write(value, into: &bytes, at: 0)
        return bytes
    }

    public func write(_ value: Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
        try castCodecsError {
            try writeBody(value, &bytes, offset)
        }
    }
}

public struct AnyFixedSizeDecoder<Decoded>: FixedSizeDecoder {
    public let fixedSize: Int
    let readBody: @Sendable (Data, Offset) throws -> (Decoded, Offset)

    public init(
        fixedSize: Int,
        read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)
    ) {
        self.fixedSize = fixedSize
        self.readBody = read
    }

    public init<D: FixedSizeDecoder>(_ decoder: D) where D.Decoded == Decoded {
        self.fixedSize = decoder.fixedSize
        self.readBody = { bytes, offset in
            try decoder.read(bytes, at: offset)
        }
    }

    public func decode(_ bytes: Data, at offset: Offset = 0) throws(CodecsError) -> Decoded {
        try read(bytes, at: offset).0
    }

    public func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Decoded, Offset) {
        try castCodecsError {
            try readBody(bytes, offset)
        }
    }
}

public struct AnyVariableSizeDecoder<Decoded>: VariableSizeDecoder {
    public let maxSize: Int?
    let readBody: @Sendable (Data, Offset) throws -> (Decoded, Offset)

    public init(
        maxSize: Int? = nil,
        read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)
    ) {
        self.maxSize = maxSize
        self.readBody = read
    }

    public init<D: VariableSizeDecoder>(_ decoder: D) where D.Decoded == Decoded {
        self.maxSize = decoder.maxSize
        self.readBody = { bytes, offset in
            try decoder.read(bytes, at: offset)
        }
    }

    public func decode(_ bytes: Data, at offset: Offset = 0) throws(CodecsError) -> Decoded {
        try read(bytes, at: offset).0
    }

    public func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Decoded, Offset) {
        try castCodecsError {
            try readBody(bytes, offset)
        }
    }
}

public struct AnyFixedSizeCodec<Encoded, Decoded>: FixedSizeCodec {
    public let fixedSize: Int
    let encoder: AnyFixedSizeEncoder<Encoded>
    let decoder: AnyFixedSizeDecoder<Decoded>

    public init(encoder: AnyFixedSizeEncoder<Encoded>, decoder: AnyFixedSizeDecoder<Decoded>) throws(CodecsError) {
        if encoder.fixedSize != decoder.fixedSize {
            throw CodecsError.encoderDecoderFixedSizeMismatch(
                encoderFixedSize: encoder.fixedSize,
                decoderFixedSize: decoder.fixedSize
            )
        }
        self.fixedSize = encoder.fixedSize
        self.encoder = encoder
        self.decoder = decoder
    }

    init(uncheckedFixedSize fixedSize: Int, encoder: AnyFixedSizeEncoder<Encoded>, decoder: AnyFixedSizeDecoder<Decoded>) {
        self.fixedSize = fixedSize
        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode(_ value: Encoded) throws(CodecsError) -> Data {
        try encoder.encode(value)
    }

    public func write(_ value: Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
        try encoder.write(value, into: &bytes, at: offset)
    }

    public func decode(_ bytes: Data, at offset: Offset = 0) throws(CodecsError) -> Decoded {
        try decoder.decode(bytes, at: offset)
    }

    public func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Decoded, Offset) {
        try decoder.read(bytes, at: offset)
    }
}

public struct AnyVariableSizeCodec<Encoded, Decoded>: VariableSizeCodec {
    public let maxSize: Int?
    let encoder: AnyVariableSizeEncoder<Encoded>
    let decoder: AnyVariableSizeDecoder<Decoded>

    public init(encoder: AnyVariableSizeEncoder<Encoded>, decoder: AnyVariableSizeDecoder<Decoded>) throws(CodecsError) {
        if encoder.maxSize != decoder.maxSize {
            throw CodecsError.encoderDecoderMaxSizeMismatch(
                encoderMaxSize: encoder.maxSize,
                decoderMaxSize: decoder.maxSize
            )
        }
        self.maxSize = encoder.maxSize
        self.encoder = encoder
        self.decoder = decoder
    }

    init(uncheckedMaxSize maxSize: Int?, encoder: AnyVariableSizeEncoder<Encoded>, decoder: AnyVariableSizeDecoder<Decoded>) {
        self.maxSize = maxSize
        self.encoder = encoder
        self.decoder = decoder
    }

    public func getSizeFromValue(_ value: Encoded) throws(CodecsError) -> Int {
        try encoder.getSizeFromValue(value)
    }

    public func encode(_ value: Encoded) throws(CodecsError) -> Data {
        try encoder.encode(value)
    }

    public func write(_ value: Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
        try encoder.write(value, into: &bytes, at: offset)
    }

    public func decode(_ bytes: Data, at offset: Offset = 0) throws(CodecsError) -> Decoded {
        try decoder.decode(bytes, at: offset)
    }

    public func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Decoded, Offset) {
        try decoder.read(bytes, at: offset)
    }
}

public struct OffsetContext: Sendable {
    public let bytes: Data
    public let preOffset: Offset

    public func wrapBytes(_ offset: Offset) -> Offset {
        modulo(offset, bytes.count)
    }
}

public struct PostOffsetContext: Sendable {
    public let bytes: Data
    public let preOffset: Offset
    public let newPreOffset: Offset
    public let postOffset: Offset

    public func wrapBytes(_ offset: Offset) -> Offset {
        modulo(offset, bytes.count)
    }
}

public struct OffsetConfig: Sendable {
    public let preOffset: (@Sendable (OffsetContext) -> Offset)?
    public let postOffset: (@Sendable (PostOffsetContext) -> Offset)?

    public init(
        preOffset: (@Sendable (OffsetContext) -> Offset)? = nil,
        postOffset: (@Sendable (PostOffsetContext) -> Offset)? = nil
    ) {
        self.preOffset = preOffset
        self.postOffset = postOffset
    }
}

public func createEncoder<Encoded>(
    fixedSize: Int,
    write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset
) -> AnyFixedSizeEncoder<Encoded> {
    AnyFixedSizeEncoder(fixedSize: fixedSize, write: write)
}

public func createEncoder<Encoded>(
    maxSize: Int? = nil,
    getSizeFromValue: @escaping @Sendable (Encoded) throws -> Int,
    write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset
) -> AnyVariableSizeEncoder<Encoded> {
    AnyVariableSizeEncoder(maxSize: maxSize, getSizeFromValue: getSizeFromValue, write: write)
}

public func createDecoder<Decoded>(
    fixedSize: Int,
    read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)
) -> AnyFixedSizeDecoder<Decoded> {
    AnyFixedSizeDecoder(fixedSize: fixedSize, read: read)
}

public func createDecoder<Decoded>(
    maxSize: Int? = nil,
    read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)
) -> AnyVariableSizeDecoder<Decoded> {
    AnyVariableSizeDecoder(maxSize: maxSize, read: read)
}

public func createCodec<Encoded, Decoded>(
    fixedSize: Int,
    write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset,
    read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)
) -> AnyFixedSizeCodec<Encoded, Decoded> {
    let encoder = AnyFixedSizeEncoder(fixedSize: fixedSize, write: write)
    let decoder = AnyFixedSizeDecoder(fixedSize: fixedSize, read: read)
    return AnyFixedSizeCodec(
        uncheckedFixedSize: fixedSize,
        encoder: encoder,
        decoder: decoder
    )
}

public func createCodec<Encoded, Decoded>(
    maxSize: Int? = nil,
    getSizeFromValue: @escaping @Sendable (Encoded) throws -> Int,
    write: @escaping @Sendable (Encoded, inout Data, Offset) throws -> Offset,
    read: @escaping @Sendable (Data, Offset) throws -> (Decoded, Offset)
) -> AnyVariableSizeCodec<Encoded, Decoded> {
    let encoder = AnyVariableSizeEncoder(maxSize: maxSize, getSizeFromValue: getSizeFromValue, write: write)
    let decoder = AnyVariableSizeDecoder<Decoded>(maxSize: maxSize, read: read)
    return AnyVariableSizeCodec(
        uncheckedMaxSize: maxSize,
        encoder: encoder,
        decoder: decoder
    )
}

public func getEncodedSize<E: FixedSizeEncoder>(_ value: E.Encoded, using encoder: E) -> Int {
    encoder.fixedSize
}

public func getEncodedSize<E: VariableSizeEncoder>(_ value: E.Encoded, using encoder: E) throws(CodecsError) -> Int {
    try encoder.getSizeFromValue(value)
}

public func assertByteArrayIsNotEmptyForCodec(
    _ codecDescription: String,
    bytes: Data,
    offset: Offset = 0
) throws(CodecsError) {
    if bytes.count - offset <= 0 {
        throw CodecsError.cannotDecodeEmptyByteArray(codecDescription: codecDescription)
    }
}

public func assertByteArrayHasEnoughBytesForCodec(
    _ codecDescription: String,
    expected: Int,
    bytes: Data,
    offset: Offset = 0
) throws(CodecsError) {
    let bytesLength = bytes.count - offset
    if bytesLength < expected {
        throw CodecsError.invalidByteLength(
            codecDescription: codecDescription,
            expected: expected,
            bytesLength: bytesLength
        )
    }
}

public func assertByteArrayOffsetIsNotOutOfRange(
    _ codecDescription: String,
    offset: Offset,
    bytesLength: Int
) throws(CodecsError) {
    if offset < 0 || offset > bytesLength {
        throw CodecsError.offsetOutOfRange(
            codecDescription: codecDescription,
            offset: offset,
            bytesLength: bytesLength
        )
    }
}

public func combineCodec<E: FixedSizeEncoder, D: FixedSizeDecoder>(
    _ encoder: E,
    _ decoder: D
) throws(CodecsError) -> AnyFixedSizeCodec<E.Encoded, D.Decoded> {
    try AnyFixedSizeCodec(encoder: AnyFixedSizeEncoder(encoder), decoder: AnyFixedSizeDecoder(decoder))
}

public func combineCodec<E: VariableSizeEncoder, D: VariableSizeDecoder>(
    _ encoder: E,
    _ decoder: D
) throws(CodecsError) -> AnyVariableSizeCodec<E.Encoded, D.Decoded> {
    try AnyVariableSizeCodec(encoder: AnyVariableSizeEncoder(encoder), decoder: AnyVariableSizeDecoder(decoder))
}

public func isFixedSize<E: Encoder>(_ encoder: E) -> Bool {
    encoder is any FixedSizeEncoder<E.Encoded>
}

public func isFixedSize<D: Decoder>(_ decoder: D) -> Bool {
    decoder is any FixedSizeDecoder<D.Decoded>
}

public func isFixedSize<C: Codec>(_ codec: C) -> Bool {
    codec is any FixedSizeCodec<C.Encoded, C.Decoded>
}

public func isVariableSize<E: Encoder>(_ encoder: E) -> Bool {
    !isFixedSize(encoder)
}

public func isVariableSize<D: Decoder>(_ decoder: D) -> Bool {
    !isFixedSize(decoder)
}

public func isVariableSize<C: Codec>(_ codec: C) -> Bool {
    !isFixedSize(codec)
}

public func assertIsFixedSize<E: Encoder>(_ encoder: E) throws(CodecsError) {
    if !isFixedSize(encoder) {
        throw CodecsError.expectedFixedLength
    }
}

public func assertIsFixedSize<D: Decoder>(_ decoder: D) throws(CodecsError) {
    if !isFixedSize(decoder) {
        throw CodecsError.expectedFixedLength
    }
}

public func assertIsFixedSize<C: Codec>(_ codec: C) throws(CodecsError) {
    if !isFixedSize(codec) {
        throw CodecsError.expectedFixedLength
    }
}

public func assertIsVariableSize<E: Encoder>(_ encoder: E) throws(CodecsError) {
    if !isVariableSize(encoder) {
        throw CodecsError.expectedVariableLength
    }
}

public func assertIsVariableSize<D: Decoder>(_ decoder: D) throws(CodecsError) {
    if !isVariableSize(decoder) {
        throw CodecsError.expectedVariableLength
    }
}

public func assertIsVariableSize<C: Codec>(_ codec: C) throws(CodecsError) {
    if !isVariableSize(codec) {
        throw CodecsError.expectedVariableLength
    }
}

public func addEncoderSizePrefix<E: FixedSizeEncoder, P: FixedSizeEncoder>(
    _ encoder: E,
    prefix: P
) -> AnyFixedSizeEncoder<E.Encoded> where P.Encoded == Int {
    AnyFixedSizeEncoder(fixedSize: prefix.fixedSize + encoder.fixedSize) { value, bytes, offset in
        let encoderBytes = try encoder.encode(value)
        var nextOffset = try prefix.write(encoderBytes.count, into: &bytes, at: offset)
        try writeBytes(encoderBytes, into: &bytes, at: nextOffset, codecDescription: "addEncoderSizePrefix")
        nextOffset += encoderBytes.count
        return nextOffset
    }
}

public func addEncoderSizePrefix<E: FixedSizeEncoder, P: VariableSizeEncoder>(
    _ encoder: E,
    prefix: P
) -> AnyVariableSizeEncoder<E.Encoded> where P.Encoded == Int {
    AnyVariableSizeEncoder(maxSize: combinedMaxSize(prefix.maxSize, encoder.fixedSize)) { _ in
        try prefix.getSizeFromValue(encoder.fixedSize) + encoder.fixedSize
    } write: { value, bytes, offset in
        let encoderBytes = try encoder.encode(value)
        var nextOffset = try prefix.write(encoderBytes.count, into: &bytes, at: offset)
        try writeBytes(encoderBytes, into: &bytes, at: nextOffset, codecDescription: "addEncoderSizePrefix")
        nextOffset += encoderBytes.count
        return nextOffset
    }
}

public func addEncoderSizePrefix<E: VariableSizeEncoder, P: FixedSizeEncoder>(
    _ encoder: E,
    prefix: P
) -> AnyVariableSizeEncoder<E.Encoded> where P.Encoded == Int {
    AnyVariableSizeEncoder(maxSize: encoder.maxSize.map { $0 + prefix.fixedSize }) { value in
        let encoderSize = try encoder.getSizeFromValue(value)
        return prefix.fixedSize + encoderSize
    } write: { value, bytes, offset in
        let encoderBytes = try encoder.encode(value)
        var nextOffset = try prefix.write(encoderBytes.count, into: &bytes, at: offset)
        try writeBytes(encoderBytes, into: &bytes, at: nextOffset, codecDescription: "addEncoderSizePrefix")
        nextOffset += encoderBytes.count
        return nextOffset
    }
}

public func addEncoderSizePrefix<E: VariableSizeEncoder, P: VariableSizeEncoder>(
    _ encoder: E,
    prefix: P
) -> AnyVariableSizeEncoder<E.Encoded> where P.Encoded == Int {
    AnyVariableSizeEncoder(maxSize: combinedMaxSize(prefix.maxSize, encoder.maxSize)) { value in
        let encoderSize = try encoder.getSizeFromValue(value)
        return try prefix.getSizeFromValue(encoderSize) + encoderSize
    } write: { value, bytes, offset in
        let encoderBytes = try encoder.encode(value)
        var nextOffset = try prefix.write(encoderBytes.count, into: &bytes, at: offset)
        try writeBytes(encoderBytes, into: &bytes, at: nextOffset, codecDescription: "addEncoderSizePrefix")
        nextOffset += encoderBytes.count
        return nextOffset
    }
}

public func addDecoderSizePrefix<D: FixedSizeDecoder, P: FixedSizeDecoder>(
    _ decoder: D,
    prefix: P
) -> AnyFixedSizeDecoder<D.Decoded> where P.Decoded == Int {
    AnyFixedSizeDecoder(fixedSize: prefix.fixedSize + decoder.fixedSize) { bytes, offset in
        try readSizePrefixed(decoder: decoder, prefix: prefix, bytes: bytes, offset: offset)
    }
}

public func addDecoderSizePrefix<D: FixedSizeDecoder, P: VariableSizeDecoder>(
    _ decoder: D,
    prefix: P
) -> AnyVariableSizeDecoder<D.Decoded> where P.Decoded == Int {
    AnyVariableSizeDecoder(maxSize: combinedMaxSize(prefix.maxSize, decoder.fixedSize)) { bytes, offset in
        try readSizePrefixed(decoder: decoder, prefix: prefix, bytes: bytes, offset: offset)
    }
}

public func addDecoderSizePrefix<D: VariableSizeDecoder, P: FixedSizeDecoder>(
    _ decoder: D,
    prefix: P
) -> AnyVariableSizeDecoder<D.Decoded> where P.Decoded == Int {
    AnyVariableSizeDecoder(maxSize: decoder.maxSize.map { $0 + prefix.fixedSize }) { bytes, offset in
        try readSizePrefixed(decoder: decoder, prefix: prefix, bytes: bytes, offset: offset)
    }
}

public func addDecoderSizePrefix<D: VariableSizeDecoder, P: VariableSizeDecoder>(
    _ decoder: D,
    prefix: P
) -> AnyVariableSizeDecoder<D.Decoded> where P.Decoded == Int {
    AnyVariableSizeDecoder(maxSize: combinedMaxSize(prefix.maxSize, decoder.maxSize)) { bytes, offset in
        try readSizePrefixed(decoder: decoder, prefix: prefix, bytes: bytes, offset: offset)
    }
}

public func addCodecSizePrefix<C: FixedSizeCodec, P: FixedSizeCodec>(
    _ codec: C,
    prefix: P
) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int {
    AnyFixedSizeCodec(
        uncheckedFixedSize: codec.fixedSize + prefix.fixedSize,
        encoder: addEncoderSizePrefix(codec, prefix: prefix),
        decoder: addDecoderSizePrefix(codec, prefix: prefix)
    )
}

public func addCodecSizePrefix<C: FixedSizeCodec, P: VariableSizeCodec>(
    _ codec: C,
    prefix: P
) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int {
    let encoder = addEncoderSizePrefix(codec, prefix: prefix)
    let decoder = addDecoderSizePrefix(codec, prefix: prefix)
    return AnyVariableSizeCodec(uncheckedMaxSize: encoder.maxSize, encoder: encoder, decoder: decoder)
}

public func addCodecSizePrefix<C: VariableSizeCodec, P: FixedSizeCodec>(
    _ codec: C,
    prefix: P
) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int {
    let encoder = addEncoderSizePrefix(codec, prefix: prefix)
    let decoder = addDecoderSizePrefix(codec, prefix: prefix)
    return AnyVariableSizeCodec(uncheckedMaxSize: encoder.maxSize, encoder: encoder, decoder: decoder)
}

public func addCodecSizePrefix<C: VariableSizeCodec, P: VariableSizeCodec>(
    _ codec: C,
    prefix: P
) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> where P.Encoded == Int, P.Decoded == Int {
    let encoder = addEncoderSizePrefix(codec, prefix: prefix)
    let decoder = addDecoderSizePrefix(codec, prefix: prefix)
    return AnyVariableSizeCodec(uncheckedMaxSize: encoder.maxSize, encoder: encoder, decoder: decoder)
}

public func fixEncoderSize<E: Encoder>(_ encoder: E, fixedBytes: Int) -> AnyFixedSizeEncoder<E.Encoded> {
    AnyFixedSizeEncoder(fixedSize: fixedBytes) { value, bytes, offset in
        let variableBytes = try encoder.encode(value)
        let fixedBytesData = fixBytes(variableBytes, length: fixedBytes)
        try writeBytes(fixedBytesData, into: &bytes, at: offset, codecDescription: "fixCodecSize")
        return offset + fixedBytes
    }
}

public func fixDecoderSize<D: Decoder>(_ decoder: D, fixedBytes: Int) -> AnyFixedSizeDecoder<D.Decoded> {
    AnyFixedSizeDecoder(fixedSize: fixedBytes) { bytes, offset in
        try assertByteArrayHasEnoughBytesForCodec("fixCodecSize", expected: fixedBytes, bytes: bytes, offset: offset)
        let end = saturatedAdd(offset, fixedBytes)
        var fixedBytesData = offset > 0 || bytes.count > fixedBytes
            ? sliceBytes(bytes, start: offset, end: end)
            : bytes
        if let fixedDecoder = decoder as? any FixedSizeDecoder<D.Decoded> {
            fixedBytesData = fixBytes(fixedBytesData, length: fixedDecoder.fixedSize)
        }
        let value = try decoder.read(fixedBytesData, at: 0).0
        return (value, offset + fixedBytes)
    }
}

public func fixCodecSize<C: Codec>(_ codec: C, fixedBytes: Int) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    AnyFixedSizeCodec(
        uncheckedFixedSize: fixedBytes,
        encoder: fixEncoderSize(codec, fixedBytes: fixedBytes),
        decoder: fixDecoderSize(codec, fixedBytes: fixedBytes)
    )
}

public func resizeEncoder<E: FixedSizeEncoder>(
    _ encoder: E,
    resize: @Sendable (Int) -> Int
) throws(CodecsError) -> AnyFixedSizeEncoder<E.Encoded> {
    let fixedSize = resize(encoder.fixedSize)
    if fixedSize < 0 {
        throw CodecsError.expectedPositiveByteLength(codecDescription: "resizeEncoder", bytesLength: fixedSize)
    }
    return AnyFixedSizeEncoder(fixedSize: fixedSize) { value, bytes, offset in
        try encoder.write(value, into: &bytes, at: offset)
    }
}

public func resizeEncoder<E: VariableSizeEncoder>(
    _ encoder: E,
    resize: @escaping @Sendable (Int) -> Int
) -> AnyVariableSizeEncoder<E.Encoded> {
    AnyVariableSizeEncoder(maxSize: encoder.maxSize) { value in
        let size = resize(try encoder.getSizeFromValue(value))
        if size < 0 {
            throw CodecsError.expectedPositiveByteLength(codecDescription: "resizeEncoder", bytesLength: size)
        }
        return size
    } write: { value, bytes, offset in
        try encoder.write(value, into: &bytes, at: offset)
    }
}

public func resizeDecoder<D: FixedSizeDecoder>(
    _ decoder: D,
    resize: @Sendable (Int) -> Int
) throws(CodecsError) -> AnyFixedSizeDecoder<D.Decoded> {
    let fixedSize = resize(decoder.fixedSize)
    if fixedSize < 0 {
        throw CodecsError.expectedPositiveByteLength(codecDescription: "resizeDecoder", bytesLength: fixedSize)
    }
    return AnyFixedSizeDecoder(fixedSize: fixedSize) { bytes, offset in
        try decoder.read(bytes, at: offset)
    }
}

public func resizeDecoder<D: VariableSizeDecoder>(
    _ decoder: D,
    resize: @escaping @Sendable (Int) -> Int
) -> AnyVariableSizeDecoder<D.Decoded> {
    _ = resize
    return AnyVariableSizeDecoder(maxSize: decoder.maxSize) { bytes, offset in
        try decoder.read(bytes, at: offset)
    }
}

public func resizeCodec<C: FixedSizeCodec>(
    _ codec: C,
    resize: @Sendable (Int) -> Int
) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    let encoder = try resizeEncoder(codec, resize: resize)
    let decoder = try resizeDecoder(codec, resize: resize)
    return AnyFixedSizeCodec(uncheckedFixedSize: encoder.fixedSize, encoder: encoder, decoder: decoder)
}

public func resizeCodec<C: VariableSizeCodec>(
    _ codec: C,
    resize: @escaping @Sendable (Int) -> Int
) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> {
    let encoder = resizeEncoder(codec, resize: resize)
    let decoder = resizeDecoder(codec, resize: resize)
    return AnyVariableSizeCodec(uncheckedMaxSize: codec.maxSize, encoder: encoder, decoder: decoder)
}

public func createDecoderThatConsumesEntireByteArray<D: Decoder>(_ decoder: D) -> AnyVariableSizeDecoder<D.Decoded> {
    AnyVariableSizeDecoder { bytes, offset in
        let (value, newOffset) = try decoder.read(bytes, at: offset)
        if bytes.count > newOffset {
            throw CodecsError.expectedDecoderToConsumeEntireByteArray(
                expectedLength: newOffset,
                numExcessBytes: bytes.count - newOffset
            )
        }
        return (value, newOffset)
    }
}

public func transformEncoder<E: FixedSizeEncoder, NewEncoded>(
    _ encoder: E,
    transform: @escaping @Sendable (NewEncoded) throws -> E.Encoded
) -> AnyFixedSizeEncoder<NewEncoded> {
    AnyFixedSizeEncoder(fixedSize: encoder.fixedSize) { value, bytes, offset in
        let oldValue = try castCodecsError { try transform(value) }
        return try encoder.write(oldValue, into: &bytes, at: offset)
    }
}

public func transformEncoder<E: VariableSizeEncoder, NewEncoded>(
    _ encoder: E,
    transform: @escaping @Sendable (NewEncoded) throws -> E.Encoded
) -> AnyVariableSizeEncoder<NewEncoded> {
    AnyVariableSizeEncoder(maxSize: encoder.maxSize) { value in
        let oldValue = try castCodecsError { try transform(value) }
        return try encoder.getSizeFromValue(oldValue)
    } write: { value, bytes, offset in
        let oldValue = try castCodecsError { try transform(value) }
        return try encoder.write(oldValue, into: &bytes, at: offset)
    }
}

public func transformDecoder<D: FixedSizeDecoder, NewDecoded>(
    _ decoder: D,
    transform: @escaping @Sendable (D.Decoded) throws -> NewDecoded
) -> AnyFixedSizeDecoder<NewDecoded> {
    AnyFixedSizeDecoder(fixedSize: decoder.fixedSize) { bytes, offset in
        let (oldValue, newOffset) = try decoder.read(bytes, at: offset)
        let newValue = try castCodecsError { try transform(oldValue) }
        return (newValue, newOffset)
    }
}

public func transformDecoder<D: VariableSizeDecoder, NewDecoded>(
    _ decoder: D,
    transform: @escaping @Sendable (D.Decoded) throws -> NewDecoded
) -> AnyVariableSizeDecoder<NewDecoded> {
    AnyVariableSizeDecoder(maxSize: decoder.maxSize) { bytes, offset in
        let (oldValue, newOffset) = try decoder.read(bytes, at: offset)
        let newValue = try castCodecsError { try transform(oldValue) }
        return (newValue, newOffset)
    }
}

public func transformCodec<C: FixedSizeCodec, NewEncoded, NewDecoded>(
    _ codec: C,
    encode: @escaping @Sendable (NewEncoded) throws -> C.Encoded,
    decode: @escaping @Sendable (C.Decoded) throws -> NewDecoded
) -> AnyFixedSizeCodec<NewEncoded, NewDecoded> {
    AnyFixedSizeCodec(
        uncheckedFixedSize: codec.fixedSize,
        encoder: transformEncoder(codec, transform: encode),
        decoder: transformDecoder(codec, transform: decode)
    )
}

public func transformCodec<C: VariableSizeCodec, NewEncoded, NewDecoded>(
    _ codec: C,
    encode: @escaping @Sendable (NewEncoded) throws -> C.Encoded,
    decode: @escaping @Sendable (C.Decoded) throws -> NewDecoded
) -> AnyVariableSizeCodec<NewEncoded, NewDecoded> {
    let encoder = transformEncoder(codec, transform: encode)
    let decoder = transformDecoder(codec, transform: decode)
    return AnyVariableSizeCodec(uncheckedMaxSize: codec.maxSize, encoder: encoder, decoder: decoder)
}

public func reverseEncoder<E: FixedSizeEncoder>(_ encoder: E) -> AnyFixedSizeEncoder<E.Encoded> {
    AnyFixedSizeEncoder(fixedSize: encoder.fixedSize) { value, bytes, offset in
        let newOffset = try encoder.write(value, into: &bytes, at: offset)
        try reverseBytes(in: &bytes, offset: offset, length: encoder.fixedSize, codecDescription: "reverseEncoder")
        return newOffset
    }
}

public func reverseDecoder<D: FixedSizeDecoder>(_ decoder: D) -> AnyFixedSizeDecoder<D.Decoded> {
    AnyFixedSizeDecoder(fixedSize: decoder.fixedSize) { bytes, offset in
        var reversedBytes = bytes
        try reverseBytes(in: &reversedBytes, offset: offset, length: decoder.fixedSize, codecDescription: "reverseDecoder")
        return try decoder.read(reversedBytes, at: offset)
    }
}

public func reverseCodec<C: FixedSizeCodec>(_ codec: C) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    AnyFixedSizeCodec(
        uncheckedFixedSize: codec.fixedSize,
        encoder: reverseEncoder(codec),
        decoder: reverseDecoder(codec)
    )
}

public func offsetEncoder<E: FixedSizeEncoder>(_ encoder: E, config: OffsetConfig) -> AnyFixedSizeEncoder<E.Encoded> {
    AnyFixedSizeEncoder(fixedSize: encoder.fixedSize) { value, bytes, preOffset in
        let newPreOffset = try resolvePreOffset(config, bytes: bytes, preOffset: preOffset, codecDescription: "offsetEncoder")
        let postOffset = try encoder.write(value, into: &bytes, at: newPreOffset)
        return try resolvePostOffset(
            config,
            bytes: bytes,
            preOffset: preOffset,
            newPreOffset: newPreOffset,
            postOffset: postOffset,
            codecDescription: "offsetEncoder"
        )
    }
}

public func offsetEncoder<E: VariableSizeEncoder>(_ encoder: E, config: OffsetConfig) -> AnyVariableSizeEncoder<E.Encoded> {
    AnyVariableSizeEncoder(maxSize: encoder.maxSize) { value in
        try encoder.getSizeFromValue(value)
    } write: { value, bytes, preOffset in
        let newPreOffset = try resolvePreOffset(config, bytes: bytes, preOffset: preOffset, codecDescription: "offsetEncoder")
        let postOffset = try encoder.write(value, into: &bytes, at: newPreOffset)
        return try resolvePostOffset(
            config,
            bytes: bytes,
            preOffset: preOffset,
            newPreOffset: newPreOffset,
            postOffset: postOffset,
            codecDescription: "offsetEncoder"
        )
    }
}

public func offsetDecoder<D: FixedSizeDecoder>(_ decoder: D, config: OffsetConfig) -> AnyFixedSizeDecoder<D.Decoded> {
    AnyFixedSizeDecoder(fixedSize: decoder.fixedSize) { bytes, preOffset in
        let newPreOffset = try resolvePreOffset(config, bytes: bytes, preOffset: preOffset, codecDescription: "offsetDecoder")
        let (value, postOffset) = try decoder.read(bytes, at: newPreOffset)
        let newPostOffset = try resolvePostOffset(
            config,
            bytes: bytes,
            preOffset: preOffset,
            newPreOffset: newPreOffset,
            postOffset: postOffset,
            codecDescription: "offsetDecoder"
        )
        return (value, newPostOffset)
    }
}

public func offsetDecoder<D: VariableSizeDecoder>(_ decoder: D, config: OffsetConfig) -> AnyVariableSizeDecoder<D.Decoded> {
    AnyVariableSizeDecoder(maxSize: decoder.maxSize) { bytes, preOffset in
        let newPreOffset = try resolvePreOffset(config, bytes: bytes, preOffset: preOffset, codecDescription: "offsetDecoder")
        let (value, postOffset) = try decoder.read(bytes, at: newPreOffset)
        let newPostOffset = try resolvePostOffset(
            config,
            bytes: bytes,
            preOffset: preOffset,
            newPreOffset: newPreOffset,
            postOffset: postOffset,
            codecDescription: "offsetDecoder"
        )
        return (value, newPostOffset)
    }
}

public func offsetCodec<C: FixedSizeCodec>(_ codec: C, config: OffsetConfig) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    AnyFixedSizeCodec(
        uncheckedFixedSize: codec.fixedSize,
        encoder: offsetEncoder(codec, config: config),
        decoder: offsetDecoder(codec, config: config)
    )
}

public func offsetCodec<C: VariableSizeCodec>(_ codec: C, config: OffsetConfig) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> {
    let encoder = offsetEncoder(codec, config: config)
    let decoder = offsetDecoder(codec, config: config)
    return AnyVariableSizeCodec(uncheckedMaxSize: codec.maxSize, encoder: encoder, decoder: decoder)
}

public func padLeftEncoder<E: FixedSizeEncoder>(_ encoder: E, offset: Offset) throws(CodecsError) -> AnyFixedSizeEncoder<E.Encoded> {
    try resizeEncoder(offsetEncoder(encoder, config: OffsetConfig(preOffset: { $0.preOffset + offset }))) { $0 + offset }
}

public func padRightEncoder<E: FixedSizeEncoder>(_ encoder: E, offset: Offset) throws(CodecsError) -> AnyFixedSizeEncoder<E.Encoded> {
    try resizeEncoder(offsetEncoder(encoder, config: OffsetConfig(postOffset: { $0.postOffset + offset }))) { $0 + offset }
}

public func padLeftDecoder<D: FixedSizeDecoder>(_ decoder: D, offset: Offset) throws(CodecsError) -> AnyFixedSizeDecoder<D.Decoded> {
    try resizeDecoder(offsetDecoder(decoder, config: OffsetConfig(preOffset: { $0.preOffset + offset }))) { $0 + offset }
}

public func padRightDecoder<D: FixedSizeDecoder>(_ decoder: D, offset: Offset) throws(CodecsError) -> AnyFixedSizeDecoder<D.Decoded> {
    try resizeDecoder(offsetDecoder(decoder, config: OffsetConfig(postOffset: { $0.postOffset + offset }))) { $0 + offset }
}

public func padLeftCodec<C: FixedSizeCodec>(_ codec: C, offset: Offset) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    AnyFixedSizeCodec(
        uncheckedFixedSize: codec.fixedSize + offset,
        encoder: try padLeftEncoder(codec, offset: offset),
        decoder: try padLeftDecoder(codec, offset: offset)
    )
}

public func padRightCodec<C: FixedSizeCodec>(_ codec: C, offset: Offset) throws(CodecsError) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    AnyFixedSizeCodec(
        uncheckedFixedSize: codec.fixedSize + offset,
        encoder: try padRightEncoder(codec, offset: offset),
        decoder: try padRightDecoder(codec, offset: offset)
    )
}

public func addEncoderSentinel<E: FixedSizeEncoder>(_ encoder: E, sentinel: Data) -> AnyFixedSizeEncoder<E.Encoded> {
    AnyFixedSizeEncoder(fixedSize: encoder.fixedSize + sentinel.count) { value, bytes, offset in
        let encodedBytes = try encoder.encode(value)
        if firstIndex(of: sentinel, in: encodedBytes) != nil {
            throw CodecsError.encodedBytesMustNotIncludeSentinel(encodedBytes: encodedBytes, sentinel: sentinel)
        }
        try writeBytes(encodedBytes, into: &bytes, at: offset, codecDescription: "addEncoderSentinel")
        try writeBytes(sentinel, into: &bytes, at: offset + encodedBytes.count, codecDescription: "addEncoderSentinel")
        return offset + encodedBytes.count + sentinel.count
    }
}

public func addEncoderSentinel<E: VariableSizeEncoder>(_ encoder: E, sentinel: Data) -> AnyVariableSizeEncoder<E.Encoded> {
    AnyVariableSizeEncoder(maxSize: encoder.maxSize.map { $0 + sentinel.count }) { value in
        try encoder.getSizeFromValue(value) + sentinel.count
    } write: { value, bytes, offset in
        let encodedBytes = try encoder.encode(value)
        if firstIndex(of: sentinel, in: encodedBytes) != nil {
            throw CodecsError.encodedBytesMustNotIncludeSentinel(encodedBytes: encodedBytes, sentinel: sentinel)
        }
        try writeBytes(encodedBytes, into: &bytes, at: offset, codecDescription: "addEncoderSentinel")
        try writeBytes(sentinel, into: &bytes, at: offset + encodedBytes.count, codecDescription: "addEncoderSentinel")
        return offset + encodedBytes.count + sentinel.count
    }
}

public func addDecoderSentinel<D: FixedSizeDecoder>(_ decoder: D, sentinel: Data) -> AnyFixedSizeDecoder<D.Decoded> {
    AnyFixedSizeDecoder(fixedSize: decoder.fixedSize + sentinel.count) { bytes, offset in
        let candidate = candidateBytes(from: bytes, offset: offset)
        guard let sentinelIndex = firstIndex(of: sentinel, in: candidate) else {
            throw CodecsError.sentinelMissingInDecodedBytes(decodedBytes: candidate, sentinel: sentinel)
        }
        let preSentinelBytes = Data(candidate[..<sentinelIndex])
        let value = try decoder.decode(preSentinelBytes, at: 0)
        return (value, offset + preSentinelBytes.count + sentinel.count)
    }
}

public func addDecoderSentinel<D: VariableSizeDecoder>(_ decoder: D, sentinel: Data) -> AnyVariableSizeDecoder<D.Decoded> {
    AnyVariableSizeDecoder(maxSize: decoder.maxSize.map { $0 + sentinel.count }) { bytes, offset in
        let candidate = candidateBytes(from: bytes, offset: offset)
        guard let sentinelIndex = firstIndex(of: sentinel, in: candidate) else {
            throw CodecsError.sentinelMissingInDecodedBytes(decodedBytes: candidate, sentinel: sentinel)
        }
        let preSentinelBytes = Data(candidate[..<sentinelIndex])
        let value = try decoder.decode(preSentinelBytes, at: 0)
        return (value, offset + preSentinelBytes.count + sentinel.count)
    }
}

public func addCodecSentinel<C: FixedSizeCodec>(_ codec: C, sentinel: Data) -> AnyFixedSizeCodec<C.Encoded, C.Decoded> {
    AnyFixedSizeCodec(
        uncheckedFixedSize: codec.fixedSize + sentinel.count,
        encoder: addEncoderSentinel(codec, sentinel: sentinel),
        decoder: addDecoderSentinel(codec, sentinel: sentinel)
    )
}

public func addCodecSentinel<C: VariableSizeCodec>(_ codec: C, sentinel: Data) -> AnyVariableSizeCodec<C.Encoded, C.Decoded> {
    let encoder = addEncoderSentinel(codec, sentinel: sentinel)
    let decoder = addDecoderSentinel(codec, sentinel: sentinel)
    return AnyVariableSizeCodec(uncheckedMaxSize: encoder.maxSize, encoder: encoder, decoder: decoder)
}

public func mergeBytes(_ byteArrays: [Data]) -> Data {
    let nonEmpty = byteArrays.filter { !$0.isEmpty }
    if nonEmpty.isEmpty {
        return byteArrays.first ?? Data()
    }
    if nonEmpty.count == 1 {
        return nonEmpty[0]
    }
    return nonEmpty.reduce(into: Data()) { result, bytes in
        result.append(bytes)
    }
}

public func padBytes(_ bytes: Data, length: Int) -> Data {
    if bytes.count >= length {
        return bytes
    }
    var output = Data(count: length)
    output.replaceSubrange(0..<bytes.count, with: bytes)
    return output
}

public func fixBytes(_ bytes: Data, length: Int) -> Data {
    if bytes.count > length {
        return padBytes(sliceBytes(bytes, start: 0, end: length), length: length)
    }
    return padBytes(bytes, length: length)
}

public func containsBytes(_ data: Data, _ bytes: Data, at offset: Int) -> Bool {
    let end = saturatedAdd(offset, bytes.count)
    let slice = (offset == 0 || offset <= -data.count) && data.count == bytes.count
        ? data
        : sliceBytes(data, start: offset, end: end)
    return bytesEqual(slice, bytes)
}

public func bytesEqual(_ lhs: Data, _ rhs: Data) -> Bool {
    lhs == rhs
}

public func toArrayBuffer(_ bytes: Data, offset: Int = 0, length: Int? = nil) -> Data {
    let bytesLength = length ?? bytes.count
    if (offset == 0 || offset == -bytes.count) && bytesLength == bytes.count {
        return bytes
    }
    return sliceBytes(bytes, start: offset, end: saturatedAdd(offset, bytesLength))
}

func writeBytes(_ source: Data, into destination: inout Data, at offset: Int, codecDescription: String) throws(CodecsError) {
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: offset, bytesLength: destination.count)
    let end = offset + source.count
    if end > destination.count {
        throw CodecsError.invalidByteLength(
            codecDescription: codecDescription,
            expected: end,
            bytesLength: destination.count
        )
    }
    destination.replaceSubrange(offset..<end, with: source)
}

func reverseBytes(in bytes: inout Data, offset: Int, length: Int, codecDescription: String) throws(CodecsError) {
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: offset, bytesLength: bytes.count)
    let end = saturatedAdd(offset, length)
    if end > bytes.count {
        throw CodecsError.invalidByteLength(
            codecDescription: codecDescription,
            expected: end,
            bytesLength: bytes.count
        )
    }
    guard end > offset else {
        return
    }
    bytes.replaceSubrange(offset..<end, with: bytes[offset..<end].reversed())
}

func firstIndex(of needle: Data, in haystack: Data) -> Int? {
    if needle.isEmpty {
        return haystack.isEmpty ? nil : 0
    }
    guard haystack.count >= needle.count else {
        return nil
    }
    for offset in 0...(haystack.count - needle.count) {
        if containsBytes(haystack, needle, at: offset) {
            return offset
        }
    }
    return nil
}

func candidateBytes(from bytes: Data, offset: Offset) -> Data {
    if offset == 0 || offset <= -bytes.count {
        return bytes
    }
    if offset < 0 {
        return Data(bytes[(bytes.count + offset)...])
    }
    if offset >= bytes.count {
        return Data()
    }
    return Data(bytes[offset...])
}

func boundedBytes(_ bytes: Data, offset: Offset, size: Int, codecDescription: String) throws(CodecsError) -> Data {
    let end = saturatedAdd(offset, size)
    let contained = offset > 0 || bytes.count > size
        ? sliceBytes(bytes, start: offset, end: end)
        : bytes
    try assertByteArrayHasEnoughBytesForCodec(codecDescription, expected: size, bytes: contained)
    return contained
}

func readSizePrefixed<D: Decoder, P: Decoder>(
    decoder: D,
    prefix: P,
    bytes: Data,
    offset: Offset
) throws(CodecsError) -> (D.Decoded, Offset) where P.Decoded == Int {
    let (size, decoderOffset) = try prefix.read(bytes, at: offset)
    let contained = try boundedBytes(
        bytes,
        offset: decoderOffset,
        size: size,
        codecDescription: "addDecoderSizePrefix"
    )
    let value = try decoder.decode(contained, at: 0)
    return (value, decoderOffset + size)
}

func combinedMaxSize(_ lhs: Int?, _ rhs: Int?) -> Int? {
    guard let lhs, let rhs else {
        return nil
    }
    return lhs + rhs
}

func sliceBytes(_ bytes: Data, start: Int, end: Int? = nil) -> Data {
    let lowerBound = normalizedSliceIndex(start, count: bytes.count)
    let upperBound = normalizedSliceIndex(end ?? bytes.count, count: bytes.count)
    guard upperBound > lowerBound else {
        return Data()
    }
    return bytes.subdata(in: lowerBound..<upperBound)
}

func normalizedSliceIndex(_ index: Int, count: Int) -> Int {
    if index < 0 {
        let adjusted = count.addingReportingOverflow(index)
        return adjusted.overflow ? 0 : max(adjusted.partialValue, 0)
    }
    return min(index, count)
}

func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
    let result = lhs.addingReportingOverflow(rhs)
    guard result.overflow else {
        return result.partialValue
    }
    return rhs >= 0 ? Int.max : Int.min
}

func resolvePreOffset(
    _ config: OffsetConfig,
    bytes: Data,
    preOffset: Offset,
    codecDescription: String
) throws(CodecsError) -> Offset {
    let context = OffsetContext(bytes: bytes, preOffset: preOffset)
    let newPreOffset = config.preOffset?(context) ?? preOffset
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: newPreOffset, bytesLength: bytes.count)
    return newPreOffset
}

func resolvePostOffset(
    _ config: OffsetConfig,
    bytes: Data,
    preOffset: Offset,
    newPreOffset: Offset,
    postOffset: Offset,
    codecDescription: String
) throws(CodecsError) -> Offset {
    let context = PostOffsetContext(bytes: bytes, preOffset: preOffset, newPreOffset: newPreOffset, postOffset: postOffset)
    let newPostOffset = config.postOffset?(context) ?? postOffset
    try assertByteArrayOffsetIsNotOutOfRange(codecDescription, offset: newPostOffset, bytesLength: bytes.count)
    return newPostOffset
}

func modulo(_ dividend: Int, _ divisor: Int) -> Int {
    if divisor == 0 {
        return 0
    }
    return ((dividend % divisor) + divisor) % divisor
}

func castCodecsError<T>(_ body: () throws -> T) throws(CodecsError) -> T {
    do {
        return try body()
    } catch let error as CodecsError {
        throw error
    } catch {
        throw CodecsError.invalidPatternMatchValue
    }
}
