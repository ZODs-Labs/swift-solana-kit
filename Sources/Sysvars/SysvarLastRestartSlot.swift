public import Accounts
public import Addresses
public import CodecsCore
public import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarLastRestartSlot: Sendable, Equatable, Hashable {
    public let lastRestartSlot: Slot

    public init(lastRestartSlot: Slot) {
        self.lastRestartSlot = lastRestartSlot
    }
}

public func getSysvarLastRestartSlotEncoder() -> AnyFixedSizeEncoder<SysvarLastRestartSlot> {
    createEncoder(fixedSize: 8) { value, bytes, offset in
        try writeU64(value.lastRestartSlot, into: &bytes, at: offset)
    }
}

public func getSysvarLastRestartSlotDecoder() -> AnyFixedSizeDecoder<SysvarLastRestartSlot> {
    createDecoder(fixedSize: 8) { bytes, offset in
        let (lastRestartSlot, next) = try readU64(bytes, offset)
        return (SysvarLastRestartSlot(lastRestartSlot: lastRestartSlot), next)
    }
}

public func getSysvarLastRestartSlotCodec() -> AnyFixedSizeCodec<SysvarLastRestartSlot, SysvarLastRestartSlot> {
    createCodec(fixedSize: 8) { value, bytes, offset in
        try getSysvarLastRestartSlotEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarLastRestartSlotDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarLastRestartSlot(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarLastRestartSlot {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarLastRestartSlotAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarLastRestartSlotDecoder()).data
}
