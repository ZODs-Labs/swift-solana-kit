public import Accounts
public import Addresses
public import CodecsCore
public import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarStakeHistoryValue: Sendable, Equatable, Hashable {
    public let activating: Lamports
    public let deactivating: Lamports
    public let effective: Lamports

    public init(activating: Lamports, deactivating: Lamports, effective: Lamports) {
        self.activating = activating
        self.deactivating = deactivating
        self.effective = effective
    }
}

public struct SysvarStakeHistoryEntry: Sendable, Equatable, Hashable {
    public let epoch: Epoch
    public let stakeHistory: SysvarStakeHistoryValue

    public init(epoch: Epoch, stakeHistory: SysvarStakeHistoryValue) {
        self.epoch = epoch
        self.stakeHistory = stakeHistory
    }
}

public typealias SysvarStakeHistory = [SysvarStakeHistoryEntry]

public func getSysvarStakeHistoryEncoder() -> AnyVariableSizeEncoder<SysvarStakeHistory> {
    createEncoder { value in
        8 + value.count * 32
    } write: { value, bytes, offset in
        var next = try writeU64(UInt64(value.count), into: &bytes, at: offset)
        for entry in value {
            next = try writeU64(entry.epoch, into: &bytes, at: next)
            next = try writeU64(entry.stakeHistory.effective, into: &bytes, at: next)
            next = try writeU64(entry.stakeHistory.activating, into: &bytes, at: next)
            next = try writeU64(entry.stakeHistory.deactivating, into: &bytes, at: next)
        }
        return next
    }
}

public func getSysvarStakeHistoryDecoder() -> AnyVariableSizeDecoder<SysvarStakeHistory> {
    createDecoder { bytes, offset in
        let (count, afterCount) = try readU64(bytes, offset)
        let itemCount = try checkedInt(count, codecDescription: "SysvarStakeHistoryCodec")
        var next = afterCount
        var entries: [SysvarStakeHistoryEntry] = []
        entries.reserveCapacity(itemCount)
        for _ in 0..<itemCount {
            let (epoch, o1) = try readU64(bytes, next)
            let (effective, o2) = try readU64(bytes, o1)
            let (activating, o3) = try readU64(bytes, o2)
            let (deactivating, o4) = try readU64(bytes, o3)
            entries.append(SysvarStakeHistoryEntry(
                epoch: epoch,
                stakeHistory: SysvarStakeHistoryValue(
                    activating: activating,
                    deactivating: deactivating,
                    effective: effective
                )
            ))
            next = o4
        }
        return (entries, next)
    }
}

public func getSysvarStakeHistoryCodec() -> AnyVariableSizeCodec<SysvarStakeHistory, SysvarStakeHistory> {
    createCodec { value in
        try getSysvarStakeHistoryEncoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getSysvarStakeHistoryEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarStakeHistoryDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarStakeHistory(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarStakeHistory {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarStakeHistoryAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarStakeHistoryDecoder()).data
}
