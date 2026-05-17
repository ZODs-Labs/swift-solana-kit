import CodecsCore
import SolanaErrors
import XCTest

final class CodecsCoreDetailedBehaviorTests: XCTestCase {
    func testDecoderThatConsumesEntireByteArrayAllowsOffsetsAndReportsExcessBytes() throws {
        let byteDecoder = createDecoder(fixedSize: 1) { bytes, offset in
            try assertByteArrayHasEnoughBytesForCodec("byte", expected: 1, bytes: bytes, offset: offset)
            return (bytes[offset], offset + 1)
        }
        let decoder = createDecoderThatConsumesEntireByteArray(byteDecoder)

        XCTAssertEqual(try decoder.decode(Data([0x11])), 0x11)
        let (value, offset) = try decoder.read(Data([0x00, 0x22]), at: 1)
        XCTAssertEqual(value, 0x22)
        XCTAssertEqual(offset, 2)

        XCTAssertThrowsError(try decoder.decode(Data([0x11, 0x22]))) { error in
            guard case let CodecsError.expectedDecoderToConsumeEntireByteArray(expectedLength, numExcessBytes) = error else {
                return XCTFail("Expected consume-all failure, got \(error)")
            }
            XCTAssertEqual(expectedLength, 1)
            XCTAssertEqual(numExcessBytes, 1)
        }
    }

    func testCombineCodecRejectsFixedAndVariableSizeMismatches() throws {
        let fixedEncoder = createEncoder(fixedSize: 1) { (_: UInt8, bytes: inout Data, offset: Offset) in
            bytes[offset] = 0
            return offset + 1
        }
        let fixedDecoder = createDecoder(fixedSize: 2) { (_: Data, offset: Offset) in
            (0 as UInt8, offset + 2)
        }
        XCTAssertThrowsError(try combineCodec(fixedEncoder, fixedDecoder)) { error in
            guard case let CodecsError.encoderDecoderFixedSizeMismatch(encoderFixedSize, decoderFixedSize) = error else {
                return XCTFail("Expected fixed-size mismatch, got \(error)")
            }
            XCTAssertEqual(encoderFixedSize, 1)
            XCTAssertEqual(decoderFixedSize, 2)
        }

        let variableEncoder = createEncoder(maxSize: 4, getSizeFromValue: { (_: Data) in 0 }) { _, _, offset in
            offset
        }
        let variableDecoder = createDecoder(maxSize: 5) { (_: Data, offset: Offset) in
            (Data(), offset)
        }
        XCTAssertThrowsError(try combineCodec(variableEncoder, variableDecoder)) { error in
            guard case let CodecsError.encoderDecoderMaxSizeMismatch(encoderMaxSize, decoderMaxSize) = error else {
                return XCTFail("Expected max-size mismatch, got \(error)")
            }
            XCTAssertEqual(encoderMaxSize, 4)
            XCTAssertEqual(decoderMaxSize, 5)
        }
    }

    func testPaddingCodecsAdjustBytesSizesAndOffsets() throws {
        let codec = codecsCoreDetailedU16Codec()
        let left = try padLeftCodec(codec, offset: 2)
        let right = try padRightCodec(codec, offset: 2)

        XCTAssertEqual(left.fixedSize, 4)
        XCTAssertEqual(right.fixedSize, 4)
        XCTAssertEqual(try left.encode(0x1234), Data([0x00, 0x00, 0x34, 0x12]))
        XCTAssertEqual(try right.encode(0x1234), Data([0x34, 0x12, 0x00, 0x00]))

        let (leftValue, leftOffset) = try left.read(Data([0x00, 0x00, 0x34, 0x12]), at: 0)
        let (rightValue, rightOffset) = try right.read(Data([0x34, 0x12, 0x00, 0x00]), at: 0)
        XCTAssertEqual(leftValue, 0x1234)
        XCTAssertEqual(rightValue, 0x1234)
        XCTAssertEqual(leftOffset, 4)
        XCTAssertEqual(rightOffset, 4)
    }

    func testOffsetContextsWrapOffsetsAndRejectOutOfRangeResults() throws {
        let decoder = createDecoder(fixedSize: 1) { bytes, offset in
            try assertByteArrayHasEnoughBytesForCodec("byte", expected: 1, bytes: bytes, offset: offset)
            return (bytes[offset], offset + 1)
        }
        let wrapped = offsetDecoder(
            decoder,
            config: OffsetConfig(
                preOffset: { $0.wrapBytes($0.preOffset - 1) },
                postOffset: { $0.wrapBytes($0.postOffset + 10) }
            )
        )

        let (value, offset) = try wrapped.read(Data([0x10, 0x20, 0x30, 0x40]), at: 0)
        XCTAssertEqual(value, 0x40)
        XCTAssertEqual(offset, 2)

        let overflowing = offsetDecoder(
            decoder,
            config: OffsetConfig(preOffset: { $0.preOffset - 1 })
        )
        XCTAssertThrowsError(try overflowing.read(Data([0x10]), at: 0)) { error in
            guard case let CodecsError.offsetOutOfRange(codecDescription, offset, bytesLength) = error else {
                return XCTFail("Expected offset failure, got \(error)")
            }
            XCTAssertEqual(codecDescription, "offsetDecoder")
            XCTAssertEqual(offset, -1)
            XCTAssertEqual(bytesLength, 1)
        }
    }

    func testSentinelDecoderReportsMissingSentinelWithDecodedBytes() throws {
        let decoder = addDecoderSentinel(codecsCoreDetailedDataDecoder(), sentinel: Data([0xee, 0xff]))

        XCTAssertThrowsError(try decoder.decode(Data([0xaa, 0xbb, 0xcc]))) { error in
            guard case let CodecsError.sentinelMissingInDecodedBytes(decodedBytes, sentinel) = error else {
                return XCTFail("Expected sentinel failure, got \(error)")
            }
            XCTAssertEqual(decodedBytes, Data([0xaa, 0xbb, 0xcc]))
            XCTAssertEqual(sentinel, Data([0xee, 0xff]))
        }
    }

    func testResizeCodecsRejectNegativeFixedSizesAndVariableOutputSizes() throws {
        XCTAssertThrowsError(try resizeEncoder(codecsCoreDetailedU16Codec(), resize: { _ in -1 })) { error in
            guard case let CodecsError.expectedPositiveByteLength(codecDescription, bytesLength) = error else {
                return XCTFail("Expected positive length failure, got \(error)")
            }
            XCTAssertEqual(codecDescription, "resizeEncoder")
            XCTAssertEqual(bytesLength, -1)
        }

        let variable = createEncoder { (_: Data) in -1 } write: { _, _, offset in
            offset
        }
        XCTAssertThrowsError(try variable.encode(Data())) { error in
            guard case let CodecsError.expectedPositiveByteLength(codecDescription, bytesLength) = error else {
                return XCTFail("Expected positive length failure, got \(error)")
            }
            XCTAssertEqual(codecDescription, "createEncoder")
            XCTAssertEqual(bytesLength, -1)
        }
    }

    func testTransformHelpersWrapSolanaErrorsAndMapUnknownErrorsToPatternFailures() throws {
        let encoder = transformEncoder(codecsCoreDetailedU16Codec()) { (_: String) -> UInt16 in
            throw SolanaError(.instructionErrorCustom, context: ["code": .int(7)])
        }
        XCTAssertThrowsError(try encoder.encode("bad")) { error in
            guard case let CodecsError.wrappedSolanaError(code, context) = error else {
                return XCTFail("Expected wrapped Solana error, got \(error)")
            }
            XCTAssertEqual(code, SolanaErrorCode.instructionErrorCustom.rawValue)
            XCTAssertEqual(context["code"], .int(7))
        }

        let decoder = transformDecoder(codecsCoreDetailedU16Codec()) { (_: UInt16) -> String in
            throw CodecsCoreDetailedError()
        }
        XCTAssertThrowsError(try decoder.decode(Data([0x34, 0x12]))) { error in
            XCTAssertEqual(error as? CodecsError, .invalidPatternMatchValue)
        }
    }
}

private struct CodecsCoreDetailedError: Error {}

private func codecsCoreDetailedU16Codec() -> AnyFixedSizeCodec<UInt16, UInt16> {
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

private func codecsCoreDetailedDataDecoder() -> AnyVariableSizeDecoder<Data> {
    createDecoder { bytes, offset in
        (Data(bytes[offset...]), bytes.count)
    }
}
