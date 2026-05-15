public import Accounts
public import Addresses
public import CodecsCore
public import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarEpochSchedule: Sendable, Equatable, Hashable {
    public let firstNormalEpoch: Epoch
    public let firstNormalSlot: Slot
    public let leaderScheduleSlotOffset: UInt64
    public let slotsPerEpoch: UInt64
    public let warmup: Bool

    public init(firstNormalEpoch: Epoch, firstNormalSlot: Slot, leaderScheduleSlotOffset: UInt64, slotsPerEpoch: UInt64, warmup: Bool) {
        self.firstNormalEpoch = firstNormalEpoch
        self.firstNormalSlot = firstNormalSlot
        self.leaderScheduleSlotOffset = leaderScheduleSlotOffset
        self.slotsPerEpoch = slotsPerEpoch
        self.warmup = warmup
    }
}

public func getSysvarEpochScheduleEncoder() -> AnyFixedSizeEncoder<SysvarEpochSchedule> {
    createEncoder(fixedSize: 33) { value, bytes, offset in
        var next = try writeU64(value.slotsPerEpoch, into: &bytes, at: offset)
        next = try writeU64(value.leaderScheduleSlotOffset, into: &bytes, at: next)
        next = try writeBool(value.warmup, into: &bytes, at: next)
        next = try writeU64(value.firstNormalEpoch, into: &bytes, at: next)
        return try writeU64(value.firstNormalSlot, into: &bytes, at: next)
    }
}

public func getSysvarEpochScheduleDecoder() -> AnyFixedSizeDecoder<SysvarEpochSchedule> {
    createDecoder(fixedSize: 33) { bytes, offset in
        let (slotsPerEpoch, o1) = try readU64(bytes, offset)
        let (leaderScheduleSlotOffset, o2) = try readU64(bytes, o1)
        let (warmup, o3) = try readBool(bytes, o2)
        let (firstNormalEpoch, o4) = try readU64(bytes, o3)
        let (firstNormalSlot, o5) = try readU64(bytes, o4)
        return (
            SysvarEpochSchedule(
                firstNormalEpoch: firstNormalEpoch,
                firstNormalSlot: firstNormalSlot,
                leaderScheduleSlotOffset: leaderScheduleSlotOffset,
                slotsPerEpoch: slotsPerEpoch,
                warmup: warmup
            ),
            o5
        )
    }
}

public func getSysvarEpochScheduleCodec() -> AnyFixedSizeCodec<SysvarEpochSchedule, SysvarEpochSchedule> {
    createCodec(fixedSize: 33) { value, bytes, offset in
        try getSysvarEpochScheduleEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarEpochScheduleDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarEpochSchedule(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarEpochSchedule {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarEpochScheduleAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarEpochScheduleDecoder()).data
}
