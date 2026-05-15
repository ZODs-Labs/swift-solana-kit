import CodecsCore
import SolanaErrors
import XCTest

final class CodecsCoreTests: XCTestCase {
    func testFixedSizeCodecEncodesAndDecodes() throws {
        let codec = makeU16Codec()
        XCTAssertEqual(try codec.encode(0x1234), Data([0x34, 0x12]))
        XCTAssertEqual(try codec.decode(Data([0x34, 0x12]), at: 0), 0x1234)
    }

    func testAssertionsUseStableCodecErrorCodes() {
        XCTAssertThrowsError(try assertByteArrayHasEnoughBytesForCodec("u16", expected: 2, bytes: Data([0x01]))) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsInvalidByteLength.rawValue)
        }
    }

    func testOffsetEncoderAppliesPreOffsetBeforeWrite() throws {
        let encoder = offsetEncoder(makeU16Codec(), config: OffsetConfig(preOffset: { $0.preOffset + 2 }))
        var bytes = Data(repeating: 0, count: 4)
        let nextOffset = try encoder.write(0x1234, into: &bytes, at: 0)
        XCTAssertEqual(bytes, Data([0x00, 0x00, 0x34, 0x12]))
        XCTAssertEqual(nextOffset, 4)
    }

    func testFixEncoderSizePadsAndTruncates() throws {
        let variable = createEncoder(getSizeFromValue: { (value: Data) in value.count }) { value, bytes, offset in
            bytes.replaceSubrange(offset..<offset + value.count, with: value)
            return offset + value.count
        }
        let fixed = fixEncoderSize(variable, fixedBytes: 4)
        XCTAssertEqual(try fixed.encode(Data([0x01, 0x02])), Data([0x01, 0x02, 0x00, 0x00]))
        XCTAssertEqual(try fixed.encode(Data([0x01, 0x02, 0x03, 0x04, 0x05])), Data([0x01, 0x02, 0x03, 0x04]))
    }

    func testFixBytesUsesExpectedSliceSemanticsForNegativeLengths() {
        XCTAssertEqual(fixBytes(Data([0x01, 0x02, 0x03]), length: -1), Data([0x01, 0x02]))
    }

    func testFixDecoderSizeSlicesBeforeNestedFixedDecoderPaddingForNegativeOffsets() throws {
        let fixed = fixDecoderSize(makeFixedDataDecoder(size: 2), fixedBytes: 2)

        let (value, offset) = try fixed.read(Data([0xaa, 0xbb, 0xcc]), at: -1)

        XCTAssertEqual(value, Data([0x00, 0x00]))
        XCTAssertEqual(offset, 1)
    }

    func testSentinelDecoderBoundsVariableBytes() throws {
        let decoder = createDecoder { (bytes: Data, offset: Offset) in
            (Data(bytes[offset...]), bytes.count)
        }
        let sentinelDecoder = addDecoderSentinel(decoder, sentinel: Data([0xff]))
        let (value, offset) = try sentinelDecoder.read(Data([0x01, 0x02, 0xff, 0x03]), at: 0)
        XCTAssertEqual(value, Data([0x01, 0x02]))
        XCTAssertEqual(offset, 3)
    }

    func testSentinelEncoderRejectsSentinelAnywhereInEncodedBytes() {
        let encoder = addEncoderSentinel(makeDataEncoder(), sentinel: Data([0x6c, 0x6c]))

        XCTAssertThrowsError(try encoder.encode(Data([0x68, 0x65, 0x6c, 0x6c, 0x6f]))) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsEncodedBytesMustNotIncludeSentinel.rawValue)
        }
    }

    func testSentinelDecoderHandlesNegativeOffsets() throws {
        let decoder = addDecoderSentinel(makeFixedDataDecoder(size: 2), sentinel: Data([0xff]))

        let (value, offset) = try decoder.read(Data([0x09, 0x01, 0x02, 0xff]), at: -3)

        XCTAssertEqual(value, Data([0x01, 0x02]))
        XCTAssertEqual(offset, 0)
    }

    func testSizePrefixCodecBoundsVariableBytes() throws {
        let bytesCodec = createCodec { (value: Data) in
            value.count
        } write: { value, bytes, offset in
            bytes.replaceSubrange(offset..<offset + value.count, with: value)
            return offset + value.count
        } read: { bytes, offset in
            (Data(bytes[offset...]), bytes.count)
        }
        let codec = addCodecSizePrefix(bytesCodec, prefix: makeU8SizePrefixCodec())

        XCTAssertEqual(try codec.encode(Data([0xaa, 0xbb])), Data([0x02, 0xaa, 0xbb]))
        let (value, offset) = try codec.read(Data([0x02, 0xaa, 0xbb, 0xcc]), at: 0)
        XCTAssertEqual(value, Data([0xaa, 0xbb]))
        XCTAssertEqual(offset, 3)
    }

    func testSizePrefixDecoderSlicesBeforeLengthAssertionForNegativeOffsets() {
        let decoder = createDecoder { (bytes: Data, offset: Offset) in
            (Data(bytes[offset...]), bytes.count)
        }
        let negativeOffsetPrefix = createDecoder(fixedSize: 0) { (_: Data, _: Offset) in
            (2, -1)
        }
        let prefixed = addDecoderSizePrefix(decoder, prefix: negativeOffsetPrefix)

        XCTAssertThrowsError(try prefixed.decode(Data([0xaa, 0xbb, 0xcc]))) { error in
            guard case let CodecsError.invalidByteLength(codecDescription, expected, bytesLength) = error else {
                XCTFail("Expected invalidByteLength, got \(error)")
                return
            }
            XCTAssertEqual(codecDescription, "addDecoderSizePrefix")
            XCTAssertEqual(expected, 2)
            XCTAssertEqual(bytesLength, 0)
        }
    }

    func testSizePrefixSupportsVariableSizePrefixes() throws {
        let prefixed = addCodecSizePrefix(makeU16Codec(), prefix: makeVariableSizePrefixCodec())

        XCTAssertTrue(isVariableSize(prefixed))
        XCTAssertEqual(try prefixed.getSizeFromValue(0x1234), 3)
        XCTAssertEqual(try prefixed.encode(0x1234), Data([0x02, 0x34, 0x12]))

        let (value, offset) = try prefixed.read(Data([0x02, 0x34, 0x12, 0xff]), at: 0)
        XCTAssertEqual(value, 0x1234)
        XCTAssertEqual(offset, 3)
    }

    func testTransformAndReverseHelpersPreserveCodecSemantics() throws {
        let transformed = transformCodec(makeU16Codec()) { (value: String) in
            guard let parsed = UInt16(value) else {
                throw CodecsError.invalidPatternMatchValue
            }
            return parsed
        } decode: { value in
            String(value)
        }

        XCTAssertEqual(try transformed.encode("4660"), Data([0x34, 0x12]))
        XCTAssertEqual(try transformed.decode(Data([0x34, 0x12])), "4660")

        let reversed = reverseCodec(makeU16Codec())
        XCTAssertEqual(try reversed.encode(0x1234), Data([0x12, 0x34]))
        XCTAssertEqual(try reversed.decode(Data([0x12, 0x34])), 0x1234)
    }

    func testReverseEncoderUsesNestedWriteAtCallerOffset() throws {
        let encoder = createEncoder(fixedSize: 2) { (_: Int, bytes: inout Data, offset: Offset) in
            bytes[offset] = UInt8(offset)
            bytes[offset + 1] = UInt8(offset + 1)
            return offset + 2
        }
        let reversed = reverseEncoder(encoder)
        var bytes = Data([0x09, 0x09, 0x09, 0x09])

        let offset = try reversed.write(0, into: &bytes, at: 2)

        XCTAssertEqual(bytes, Data([0x09, 0x09, 0x03, 0x02]))
        XCTAssertEqual(offset, 4)
    }

    func testReverseDecoderUsesNestedReadAtCallerOffset() throws {
        let decoder = createDecoder(fixedSize: 2) { bytes, offset in
            (Data(bytes[offset..<offset + 2]), offset + 10)
        }
        let reversed = reverseDecoder(decoder)

        let (value, offset) = try reversed.read(Data([0x00, 0x01, 0x02, 0x03]), at: 1)

        XCTAssertEqual(value, Data([0x02, 0x01]))
        XCTAssertEqual(offset, 11)
    }

    func testSizeGuardsUseExpectedErrorCodes() {
        XCTAssertNoThrow(try assertIsFixedSize(makeU16Codec()))
        XCTAssertThrowsError(try assertIsVariableSize(makeU16Codec())) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsExpectedVariableLength.rawValue)
        }

        let variable = makeDataEncoder()
        XCTAssertTrue(isVariableSize(variable))
        XCTAssertThrowsError(try assertIsFixedSize(variable)) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsExpectedFixedLength.rawValue)
        }
    }

    func testByteHelpers() {
        XCTAssertEqual(mergeBytes([Data(), Data([1, 2]), Data([3])]), Data([1, 2, 3]))
        XCTAssertTrue(containsBytes(Data([1, 2, 3, 4]), Data([2, 3]), at: 1))
        XCTAssertTrue(containsBytes(Data([1, 2, 3, 4]), Data([1, 2]), at: -4))
        XCTAssertFalse(containsBytes(Data([1, 2, 3, 4]), Data([1, 2]), at: -5))
        XCTAssertEqual(fixBytes(Data([1]), length: 3), Data([1, 0, 0]))
        XCTAssertEqual(toArrayBuffer(Data([1, 2, 3]), offset: 1), Data([2, 3]))
        XCTAssertEqual(toArrayBuffer(Data([1, 2, 3]), offset: -3, length: 3), Data([1, 2, 3]))
    }

    private func makeU16Codec() -> AnyFixedSizeCodec<UInt16, UInt16> {
        createCodec(fixedSize: 2) { value, bytes, offset in
            bytes[offset] = UInt8(value & 0xff)
            bytes[offset + 1] = UInt8(value >> 8)
            return offset + 2
        } read: { bytes, offset in
            try assertByteArrayHasEnoughBytesForCodec("u16", expected: 2, bytes: bytes, offset: offset)
            let value = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
            return (value, offset + 2)
        }
    }

    private func makeU8SizePrefixCodec() -> AnyFixedSizeCodec<Int, Int> {
        createCodec(fixedSize: 1) { value, bytes, offset in
            bytes[offset] = UInt8(value)
            return offset + 1
        } read: { bytes, offset in
            try assertByteArrayHasEnoughBytesForCodec("u8", expected: 1, bytes: bytes, offset: offset)
            return (Int(bytes[offset]), offset + 1)
        }
    }

    private func makeVariableSizePrefixCodec() -> AnyVariableSizeCodec<Int, Int> {
        createCodec { value in
            value < 256 ? 1 : 2
        } write: { value, bytes, offset in
            let size = value < 256 ? 1 : 2
            bytes[offset] = UInt8(value & 0xff)
            if size == 2 {
                bytes[offset + 1] = UInt8((value >> 8) & 0xff)
            }
            return offset + size
        } read: { bytes, offset in
            try assertByteArrayHasEnoughBytesForCodec("varPrefix", expected: 1, bytes: bytes, offset: offset)
            return (Int(bytes[offset]), offset + 1)
        }
    }

    private func makeDataEncoder() -> AnyVariableSizeEncoder<Data> {
        createEncoder { (value: Data) in
            value.count
        } write: { value, bytes, offset in
            bytes.replaceSubrange(offset..<offset + value.count, with: value)
            return offset + value.count
        }
    }

    private func makeFixedDataDecoder(size: Int) -> AnyFixedSizeDecoder<Data> {
        createDecoder(fixedSize: size) { bytes, offset in
            try assertByteArrayHasEnoughBytesForCodec("fixedData", expected: size, bytes: bytes, offset: offset)
            return (Data(bytes[offset..<offset + size]), offset + size)
        }
    }
}
