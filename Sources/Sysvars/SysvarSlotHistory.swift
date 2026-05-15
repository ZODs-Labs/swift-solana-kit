public import Accounts
import Addresses
public import CodecsCore
import Foundation
public import RpcSpec
public import RpcTypes
import SolanaErrors

public struct SysvarSlotHistory: Sendable, Equatable, Hashable {
    public let bits: [UInt64]
    public let nextSlot: Slot

    public init(bits: [UInt64], nextSlot: Slot) {
        self.bits = bits
        self.nextSlot = nextSlot
    }
}

public func getSysvarSlotHistoryEncoder() -> AnyFixedSizeEncoder<SysvarSlotHistory> {
    createEncoder(fixedSize: slotHistoryAccountDataStaticSize) { value, bytes, offset in
        var next = try writeU8(bitvecDiscriminator, into: &bytes, at: offset)
        next = try writeU64(UInt64(bitvecLength), into: &bytes, at: next)
        for index in 0..<bitvecLength {
            let word = index < value.bits.count ? value.bits[index] : 0
            next = try writeU64(word, into: &bytes, at: next)
        }
        next = try writeU64(UInt64(bitvecNumBits), into: &bytes, at: next)
        return try writeU64(value.nextSlot, into: &bytes, at: next)
    }
}

public func getSysvarSlotHistoryDecoder() -> AnyFixedSizeDecoder<SysvarSlotHistory> {
    createDecoder(fixedSize: slotHistoryAccountDataStaticSize) { bytes, offset in
        try exactByteLength(bytes, expected: slotHistoryAccountDataStaticSize, codecDescription: "SysvarSlotHistoryCodec")
        let (discriminator, o1) = try readU8(bytes, offset)
        guard discriminator == bitvecDiscriminator else {
            throw CodecsError.enumDiscriminatorOutOfRange(
                discriminator: discriminator,
                formattedValidDiscriminators: String(bitvecDiscriminator),
                validDiscriminators: [bitvecDiscriminator]
            )
        }
        let (encodedLength, o2) = try readU64(bytes, o1)
        guard encodedLength == UInt64(bitvecLength) else {
            throw CodecsError.invalidNumberOfItems(
                codecDescription: "SysvarSlotHistoryCodec",
                expected: bitvecLength,
                actual: try checkedInt(encodedLength, codecDescription: "SysvarSlotHistoryCodec")
            )
        }
        var bits: [UInt64] = []
        bits.reserveCapacity(bitvecLength)
        var next = o2
        for _ in 0..<bitvecLength {
            let (word, afterWord) = try readU64(bytes, next)
            bits.append(word)
            next = afterWord
        }
        let (numBits, o3) = try readU64(bytes, next)
        guard numBits == UInt64(bitvecNumBits) else {
            throw CodecsError.invalidNumberOfItems(
                codecDescription: "SysvarSlotHistoryCodec",
                expected: bitvecNumBits,
                actual: try checkedInt(numBits, codecDescription: "SysvarSlotHistoryCodec")
            )
        }
        let (nextSlot, o4) = try readU64(bytes, o3)
        return (SysvarSlotHistory(bits: bits, nextSlot: nextSlot), o4)
    }
}

public func getSysvarSlotHistoryCodec() -> AnyFixedSizeCodec<SysvarSlotHistory, SysvarSlotHistory> {
    createCodec(fixedSize: slotHistoryAccountDataStaticSize) { value, bytes, offset in
        try getSysvarSlotHistoryEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarSlotHistoryDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarSlotHistory(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarSlotHistory {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarSlotHistoryAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarSlotHistoryDecoder()).data
}
