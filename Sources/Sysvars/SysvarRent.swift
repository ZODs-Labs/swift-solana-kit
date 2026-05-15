public import Accounts
public import Addresses
public import CodecsCore
public import Foundation
public import RpcSpec
public import RpcTypes

public struct SysvarRent: Sendable, Equatable, Hashable {
    public let burnPercent: Int
    public let exemptionThreshold: F64UnsafeSeeDocumentation
    public let lamportsPerByteYear: Lamports

    public init(burnPercent: Int, exemptionThreshold: F64UnsafeSeeDocumentation, lamportsPerByteYear: Lamports) {
        self.burnPercent = burnPercent
        self.exemptionThreshold = exemptionThreshold
        self.lamportsPerByteYear = lamportsPerByteYear
    }
}

public func getSysvarRentEncoder() -> AnyFixedSizeEncoder<SysvarRent> {
    createEncoder(fixedSize: 17) { value, bytes, offset in
        var next = try writeU64(value.lamportsPerByteYear, into: &bytes, at: offset)
        next = try writeF64(value.exemptionThreshold, into: &bytes, at: next)
        return try writeU8(value.burnPercent, into: &bytes, at: next)
    }
}

public func getSysvarRentDecoder() -> AnyFixedSizeDecoder<SysvarRent> {
    createDecoder(fixedSize: 17) { bytes, offset in
        let (lamportsPerByteYear, o1) = try readU64(bytes, offset)
        let (exemptionThreshold, o2) = try readF64(bytes, o1)
        let (burnPercent, o3) = try readU8(bytes, o2)
        return (
            SysvarRent(
                burnPercent: burnPercent,
                exemptionThreshold: exemptionThreshold,
                lamportsPerByteYear: lamportsPerByteYear
            ),
            o3
        )
    }
}

public func getSysvarRentCodec() -> AnyFixedSizeCodec<SysvarRent, SysvarRent> {
    createCodec(fixedSize: 17) { value, bytes, offset in
        try getSysvarRentEncoder().write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try getSysvarRentDecoder().read(bytes, at: offset)
    }
}

public func fetchSysvarRent(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarRent {
    let account = try await fetchEncodedSysvarAccount(rpc: rpc, address: try Address(sysvarRentAddress), config: config)
    return try decodeAccount(try assertAccountExists(account), using: getSysvarRentDecoder()).data
}
