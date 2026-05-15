public import Accounts
import Addresses
public import CodecsCore
import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarRecentBlockhashesFeeCalculator: Sendable, Equatable, Hashable {
    public let lamportsPerSignature: Lamports

    public init(lamportsPerSignature: Lamports) {
        self.lamportsPerSignature = lamportsPerSignature
    }
}

public struct SysvarRecentBlockhashesEntry: Sendable, Equatable, Hashable {
    public let blockhash: Blockhash
    public let feeCalculator: SysvarRecentBlockhashesFeeCalculator

    public init(blockhash: Blockhash, feeCalculator: SysvarRecentBlockhashesFeeCalculator) {
        self.blockhash = blockhash
        self.feeCalculator = feeCalculator
    }
}

public typealias SysvarRecentBlockhashes = [SysvarRecentBlockhashesEntry]

public func getSysvarRecentBlockhashesEncoder() -> AnyVariableSizeEncoder<SysvarRecentBlockhashes> {
    createEncoder { value in
        4 + value.count * 40
    } write: { value, bytes, offset in
        var next = try writeU32(value.count, into: &bytes, at: offset)
        for entry in value {
            next = try writeBlockhash(entry.blockhash, into: &bytes, at: next)
            next = try writeU64(entry.feeCalculator.lamportsPerSignature, into: &bytes, at: next)
        }
        return next
    }
}

public func getSysvarRecentBlockhashesDecoder() -> AnyVariableSizeDecoder<SysvarRecentBlockhashes> {
    createDecoder { bytes, offset in
        let (count, afterCount) = try readU32(bytes, offset)
        var next = afterCount
        var entries: [SysvarRecentBlockhashesEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let (blockhash, o1) = try readBlockhash(bytes, next)
            let (lamportsPerSignature, o2) = try readU64(bytes, o1)
            entries.append(SysvarRecentBlockhashesEntry(
                blockhash: blockhash,
                feeCalculator: SysvarRecentBlockhashesFeeCalculator(lamportsPerSignature: lamportsPerSignature)
            ))
            next = o2
        }
        return (entries, next)
    }
}

public func getSysvarRecentBlockhashesCodec() -> AnyVariableSizeCodec<SysvarRecentBlockhashes, SysvarRecentBlockhashes> {
    createCodec { value in
        try getSysvarRecentBlockhashesEncoder().getSizeFromValue(value)
    } write: { value, bytes, offset in
        try getSysvarRecentBlockhashesEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarRecentBlockhashesDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarRecentBlockhashes(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarRecentBlockhashes {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarRecentBlockhashesAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarRecentBlockhashesDecoder()).data
}
