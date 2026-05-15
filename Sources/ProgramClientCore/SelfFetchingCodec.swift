public import Accounts
public import Addresses
public import CodecsCore
public import Foundation
public import PluginInterfaces
public import RpcSpec
public import SolanaErrors

public struct SelfFetchingCodec<Base: Codec>: Codec where Base.Decoded: Sendable {
    public typealias Encoded = Base.Encoded
    public typealias Decoded = Base.Decoded

    public let base: Base
    private let rpc: Rpc

    public init(base: Base, rpc: Rpc) {
        self.base = base
        self.rpc = rpc
    }

    public func encode(_ value: Base.Encoded) throws(CodecsError) -> Data {
        try base.encode(value)
    }

    public func write(_ value: Base.Encoded, into bytes: inout Data, at offset: Offset) throws(CodecsError) -> Offset {
        try base.write(value, into: &bytes, at: offset)
    }

    public func decode(_ bytes: Data, at offset: Offset = 0) throws(CodecsError) -> Base.Decoded {
        try base.decode(bytes, at: offset)
    }

    public func read(_ bytes: Data, at offset: Offset) throws(CodecsError) -> (Base.Decoded, Offset) {
        try base.read(bytes, at: offset)
    }

    public func fetch(_ address: Address, config: FetchAccountConfig = FetchAccountConfig()) async throws -> Account<Base.Decoded> {
        try assertAccountExists(try await fetchMaybe(address, config: config))
    }

    public func fetchMaybe(
        _ address: Address,
        config: FetchAccountConfig = FetchAccountConfig()
    ) async throws -> MaybeAccount<Base.Decoded> {
        let maybeAccount = try await fetchEncodedAccount(rpc: rpc, address: address, config: config)
        return try decodeAccount(maybeAccount, using: base)
    }

    public func fetchAll(
        _ addresses: [Address],
        config: FetchAccountsConfig = FetchAccountsConfig()
    ) async throws -> [Account<Base.Decoded>] {
        try assertAccountsExist(try await fetchAllMaybe(addresses, config: config))
    }

    public func fetchAllMaybe(
        _ addresses: [Address],
        config: FetchAccountsConfig = FetchAccountsConfig()
    ) async throws -> [MaybeAccount<Base.Decoded>] {
        let maybeAccounts = try await fetchEncodedAccounts(rpc: rpc, addresses: addresses, config: config)
        return try maybeAccounts.map { maybeAccount in
            try decodeAccount(maybeAccount, using: base)
        }
    }
}

extension SelfFetchingCodec: FixedSizeEncoder where Base: FixedSizeCodec {}

extension SelfFetchingCodec: FixedSizeDecoder where Base: FixedSizeCodec {}

extension SelfFetchingCodec: FixedSizeCodec where Base: FixedSizeCodec {
    public var fixedSize: Int {
        base.fixedSize
    }
}

extension SelfFetchingCodec: VariableSizeEncoder where Base: VariableSizeCodec {}

extension SelfFetchingCodec: VariableSizeDecoder where Base: VariableSizeCodec {}

extension SelfFetchingCodec: VariableSizeCodec where Base: VariableSizeCodec {
    public var maxSize: Int? {
        base.maxSize
    }

    public func getSizeFromValue(_ value: Base.Encoded) throws(CodecsError) -> Int {
        try base.getSizeFromValue(value)
    }
}

public func addSelfFetchFunctions<C: Codec, Client: ClientWithRpc>(
    client: Client,
    codec: C
) -> SelfFetchingCodec<C> where C.Decoded: Sendable {
    SelfFetchingCodec(base: codec, rpc: client.rpc)
}
