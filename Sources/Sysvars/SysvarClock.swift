public import Accounts
import Addresses
public import CodecsCore
import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarClock: Sendable, Equatable, Hashable {
    public let epoch: Epoch
    public let epochStartTimestamp: UnixTimestamp
    public let leaderScheduleEpoch: Epoch
    public let slot: Slot
    public let unixTimestamp: UnixTimestamp

    public init(epoch: Epoch, epochStartTimestamp: UnixTimestamp, leaderScheduleEpoch: Epoch, slot: Slot, unixTimestamp: UnixTimestamp) {
        self.epoch = epoch
        self.epochStartTimestamp = epochStartTimestamp
        self.leaderScheduleEpoch = leaderScheduleEpoch
        self.slot = slot
        self.unixTimestamp = unixTimestamp
    }
}

public func getSysvarClockEncoder() -> AnyFixedSizeEncoder<SysvarClock> {
    createEncoder(fixedSize: 40) { value, bytes, offset in
        var next = try writeU64(value.slot, into: &bytes, at: offset)
        next = try writeI64(value.epochStartTimestamp, into: &bytes, at: next)
        next = try writeU64(value.epoch, into: &bytes, at: next)
        next = try writeU64(value.leaderScheduleEpoch, into: &bytes, at: next)
        return try writeI64(value.unixTimestamp, into: &bytes, at: next)
    }
}

public func getSysvarClockDecoder() -> AnyFixedSizeDecoder<SysvarClock> {
    createDecoder(fixedSize: 40) { bytes, offset in
        let (slot, o1) = try readU64(bytes, offset)
        let (epochStartTimestamp, o2) = try readI64(bytes, o1)
        let (epoch, o3) = try readU64(bytes, o2)
        let (leaderScheduleEpoch, o4) = try readU64(bytes, o3)
        let (unixTimestamp, o5) = try readI64(bytes, o4)
        return (
            SysvarClock(
                epoch: epoch,
                epochStartTimestamp: epochStartTimestamp,
                leaderScheduleEpoch: leaderScheduleEpoch,
                slot: slot,
                unixTimestamp: unixTimestamp
            ),
            o5
        )
    }
}

public func getSysvarClockCodec() -> AnyFixedSizeCodec<SysvarClock, SysvarClock> {
    createCodec(fixedSize: 40) { value, bytes, offset in
        try getSysvarClockEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarClockDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarClock(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarClock {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarClockAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarClockDecoder()).data
}
