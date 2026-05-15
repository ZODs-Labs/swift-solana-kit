public import Accounts
import Addresses
public import CodecsCore
public import CodecsNumbers
import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarEpochRewards: Sendable, Equatable, Hashable {
    public let active: Bool
    public let distributedRewards: Lamports
    public let distributionStartingBlockHeight: UInt64
    public let numPartitions: UInt64
    public let parentBlockhash: Blockhash
    public let totalPoints: UInt128Value
    public let totalRewards: Lamports

    public init(active: Bool, distributedRewards: Lamports, distributionStartingBlockHeight: UInt64, numPartitions: UInt64, parentBlockhash: Blockhash, totalPoints: UInt128Value, totalRewards: Lamports) {
        self.active = active
        self.distributedRewards = distributedRewards
        self.distributionStartingBlockHeight = distributionStartingBlockHeight
        self.numPartitions = numPartitions
        self.parentBlockhash = parentBlockhash
        self.totalPoints = totalPoints
        self.totalRewards = totalRewards
    }
}

public func getSysvarEpochRewardsEncoder() -> AnyFixedSizeEncoder<SysvarEpochRewards> {
    createEncoder(fixedSize: 81) { value, bytes, offset in
        var next = try writeU64(value.distributionStartingBlockHeight, into: &bytes, at: offset)
        next = try writeU64(value.numPartitions, into: &bytes, at: next)
        next = try writeBlockhash(value.parentBlockhash, into: &bytes, at: next)
        next = try writeU128(value.totalPoints, into: &bytes, at: next)
        next = try writeU64(value.totalRewards, into: &bytes, at: next)
        next = try writeU64(value.distributedRewards, into: &bytes, at: next)
        return try writeBool(value.active, into: &bytes, at: next)
    }
}

public func getSysvarEpochRewardsDecoder() -> AnyFixedSizeDecoder<SysvarEpochRewards> {
    createDecoder(fixedSize: 81) { bytes, offset in
        let (distributionStartingBlockHeight, o1) = try readU64(bytes, offset)
        let (numPartitions, o2) = try readU64(bytes, o1)
        let (parentBlockhash, o3) = try readBlockhash(bytes, o2)
        let (totalPoints, o4) = try readU128(bytes, o3)
        let (totalRewards, o5) = try readU64(bytes, o4)
        let (distributedRewards, o6) = try readU64(bytes, o5)
        let (active, o7) = try readBool(bytes, o6)
        return (
            SysvarEpochRewards(
                active: active,
                distributedRewards: distributedRewards,
                distributionStartingBlockHeight: distributionStartingBlockHeight,
                numPartitions: numPartitions,
                parentBlockhash: parentBlockhash,
                totalPoints: totalPoints,
                totalRewards: totalRewards
            ),
            o7
        )
    }
}

public func getSysvarEpochRewardsCodec() -> AnyFixedSizeCodec<SysvarEpochRewards, SysvarEpochRewards> {
    createCodec(fixedSize: 81) { value, bytes, offset in
        try getSysvarEpochRewardsEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarEpochRewardsDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarEpochRewards(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarEpochRewards {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarEpochRewardsAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarEpochRewardsDecoder()).data
}
