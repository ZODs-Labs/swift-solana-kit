public import Accounts
public import Addresses
public import CodecsCore
public import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarSlotHashesEntry: Sendable, Equatable, Hashable {
    public let hash: Blockhash
    public let slot: Slot

    public init(hash: Blockhash, slot: Slot) {
        self.hash = hash
        self.slot = slot
    }
}

public typealias SysvarSlotHashes = [SysvarSlotHashesEntry]

public func getSysvarSlotHashesEncoder() -> AnyVariableSizeEncoder<SysvarSlotHashes> {
    createEncoder { value in
        4 + value.count * 40
    } write: { value, bytes, offset in
        var next = try writeU32(value.count, into: &bytes, at: offset)
        for entry in value {
            next = try writeU64(entry.slot, into: &bytes, at: next)
            next = try writeBlockhash(entry.hash, into: &bytes, at: next)
        }
        return next
    }
}

public func getSysvarSlotHashesDecoder() -> AnyVariableSizeDecoder<SysvarSlotHashes> {
    createDecoder { bytes, offset in
        let (count, afterCount) = try readU32(bytes, offset)
        var next = afterCount
        var entries: [SysvarSlotHashesEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let (slot, o1) = try readU64(bytes, next)
            let (hash, o2) = try readBlockhash(bytes, o1)
            entries.append(SysvarSlotHashesEntry(hash: hash, slot: slot))
            next = o2
        }
        return (entries, next)
    }
}

public func getSysvarSlotHashesCodec() -> AnyVariableSizeCodec<SysvarSlotHashes, SysvarSlotHashes> {
    createCodec { value in
        try getSysvarSlotHashesEncoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getSysvarSlotHashesEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarSlotHashesDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarSlotHashes(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarSlotHashes {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarSlotHashesAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarSlotHashesDecoder()).data
}
