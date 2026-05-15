public import Accounts
public import Addresses
public import RpcSpec

public func fetchEncodedSysvarAccount(
    rpc: Rpc,
    address: Address,
    config: FetchAccountConfig = FetchAccountConfig()
) async throws -> MaybeEncodedAccount {
    try await fetchEncodedAccount(rpc: rpc, address: address, config: config)
}

public func fetchJsonParsedSysvarAccount(
    rpc: Rpc,
    address: Address,
    config: FetchAccountConfig = FetchAccountConfig()
) async throws -> MaybeJsonParsedOrEncodedAccount {
    try await fetchJsonParsedAccount(rpc: rpc, address: address, config: config)
}
