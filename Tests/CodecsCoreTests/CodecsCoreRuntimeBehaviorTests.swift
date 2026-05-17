import CodecsCore
import os
import SolanaErrors
import XCTest

final class CodecsCoreRuntimeBehaviorTests: XCTestCase {
    func testByteHelpersHandleNegativeOffsetsSlicesAndSingleArrayReuseSemantics() {
        let bytes = Data([0x01, 0x02, 0x03, 0x04])

        XCTAssertEqual(mergeBytes([Data(), Data([0x09]), Data()]), Data([0x09]))
        XCTAssertEqual(padBytes(Data([0x01, 0x02]), length: 4), Data([0x01, 0x02, 0x00, 0x00]))
        XCTAssertEqual(fixBytes(Data([0x01, 0x02, 0x03]), length: 2), Data([0x01, 0x02]))
        XCTAssertEqual(toArrayBuffer(bytes, offset: -4), bytes)
        XCTAssertEqual(toArrayBuffer(bytes, offset: -10), Data())
        XCTAssertEqual(toArrayBuffer(bytes, offset: -2, length: 1), Data([0x03]))
        XCTAssertEqual(toArrayBuffer(bytes, offset: 1, length: 2), Data([0x02, 0x03]))
        XCTAssertTrue(containsBytes(bytes, bytes, at: -4))
        XCTAssertTrue(containsBytes(bytes, bytes, at: -5))
        XCTAssertFalse(containsBytes(bytes, Data([0x03, 0x04]), at: -2))
        XCTAssertFalse(containsBytes(bytes, Data([0x02, 0x04]), at: 1))
    }

    func testSizePrefixCodecsPreservePayloadOffsetsAndSurfacePrefixFailures() throws {
        let dataCodec = createCodec(maxSize: 4) { (value: Data) in
            value.count
        } write: { value, bytes, offset in
            bytes.replaceSubrange(offset ..< offset + value.count, with: value)
            return offset + value.count
        } read: { bytes, offset in
            (Data(bytes[offset...]), bytes.count)
        }
        let prefixCodec = codecsCoreRuntimeU8IntCodec()
        let prefixed = addCodecSizePrefix(dataCodec, prefix: prefixCodec)

        XCTAssertEqual(try prefixed.encode(Data([0xaa, 0xbb])), Data([0x02, 0xaa, 0xbb]))
        let (decoded, offset) = try prefixed.read(Data([0x99, 0x02, 0xaa, 0xbb, 0xcc]), at: 1)
        XCTAssertEqual(decoded, Data([0xaa, 0xbb]))
        XCTAssertEqual(offset, 4)

        XCTAssertThrowsError(try prefixed.encode(Data(repeating: 0xff, count: 256))) { error in
            guard case let CodecsError.invalidByteLength(codecDescription, expected, bytesLength) = error else {
                return XCTFail("Expected prefix byte length failure, got \(error)")
            }
            XCTAssertEqual(codecDescription, "u8-prefix")
            XCTAssertEqual(expected, 255)
            XCTAssertEqual(bytesLength, 256)
        }
    }

    func testReverseDecoderUsesReversedWindowWithoutMutatingInputBytes() throws {
        let input = Data([0x00, 0x12, 0x34, 0xff])
        let bytesSeenByInnerDecoder = OSAllocatedUnfairLock<Data?>(initialState: nil)
        let decoder = createDecoder(fixedSize: 2) { bytes, offset in
            bytesSeenByInnerDecoder.withLock { $0 = bytes }
            return (UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1]), offset + 2)
        }
        let reversed = reverseDecoder(decoder)

        let (value, offset) = try reversed.read(input, at: 1)

        XCTAssertEqual(value, 0x3412)
        XCTAssertEqual(offset, 3)
        XCTAssertEqual(bytesSeenByInnerDecoder.withLock { $0 }, Data([0x00, 0x34, 0x12, 0xff]))
        XCTAssertEqual(input, Data([0x00, 0x12, 0x34, 0xff]))
    }
}

private func codecsCoreRuntimeU8IntCodec() -> AnyFixedSizeCodec<Int, Int> {
    createCodec(fixedSize: 1) { value, bytes, offset in
        guard value <= 255 else {
            throw CodecsError.invalidByteLength(codecDescription: "u8-prefix", expected: 255, bytesLength: value)
        }
        bytes[offset] = UInt8(value)
        return offset + 1
    } read: { bytes, offset in
        try assertByteArrayHasEnoughBytesForCodec("u8-prefix", expected: 1, bytes: bytes, offset: offset)
        return (Int(bytes[offset]), offset + 1)
    }
}
