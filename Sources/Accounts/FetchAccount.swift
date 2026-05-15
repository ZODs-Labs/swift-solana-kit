public import Addresses
public import Foundation
public import Promises
public import RpcSpec
public import RpcSpecTypes
public import RpcTypes
import SolanaErrors

public struct FetchAccountConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment?
    public let minContextSlot: Slot?

    public init(abortSignal: AbortSignal? = nil, commitment: Commitment? = nil, minContextSlot: Slot? = nil) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.minContextSlot = minContextSlot
    }
}

public struct FetchAccountsConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment?
    public let minContextSlot: Slot?

    public init(abortSignal: AbortSignal? = nil, commitment: Commitment? = nil, minContextSlot: Slot? = nil) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.minContextSlot = minContextSlot
    }
}

public func fetchEncodedAccount(
    rpc: Rpc,
    address: Address,
    config: FetchAccountConfig = FetchAccountConfig()
) async throws -> MaybeEncodedAccount {
    let response = try await rpc
        .request("getAccountInfo", params: [.string(address.rawValue), accountConfig(encoding: "base64", config: config)])
        .send(abortSignal: config.abortSignal)
    return try parseBase64RpcAccount(address, response.value(for: "value") ?? response)
}

public func fetchJsonParsedAccount(
    rpc: Rpc,
    address: Address,
    config: FetchAccountConfig = FetchAccountConfig()
) async throws -> MaybeJsonParsedOrEncodedAccount {
    let response = try await rpc
        .request("getAccountInfo", params: [.string(address.rawValue), accountConfig(encoding: "jsonParsed", config: config)])
        .send(abortSignal: config.abortSignal)
    return try parseJsonParsedOrEncodedRpcAccount(address, response.value(for: "value") ?? response)
}

public func fetchEncodedAccounts(
    rpc: Rpc,
    addresses: [Address],
    config: FetchAccountsConfig = FetchAccountsConfig()
) async throws -> [MaybeEncodedAccount] {
    let response = try await rpc
        .request(
            "getMultipleAccounts",
            params: [.array(addresses.map { .string($0.rawValue) }), accountsConfig(encoding: "base64", config: config)]
        )
        .send(abortSignal: config.abortSignal)
    guard case let .array(values) = response.value(for: "value") ?? response else {
        return []
    }
    return try zip(addresses, values).map { address, value in
        try parseBase64RpcAccount(address, value)
    }
}

public func fetchJsonParsedAccounts(
    rpc: Rpc,
    addresses: [Address],
    config: FetchAccountsConfig = FetchAccountsConfig()
) async throws -> [MaybeJsonParsedOrEncodedAccount] {
    let response = try await rpc
        .request(
            "getMultipleAccounts",
            params: [.array(addresses.map { .string($0.rawValue) }), accountsConfig(encoding: "jsonParsed", config: config)]
        )
        .send(abortSignal: config.abortSignal)
    guard case let .array(values) = response.value(for: "value") ?? response else {
        return []
    }
    return try zip(addresses, values).map { address, value in
        try parseJsonParsedOrEncodedRpcAccount(address, value)
    }
}

private func parseJsonParsedOrEncodedRpcAccount(
    _ address: Address,
    _ rpcAccount: RpcJsonValue
) throws -> MaybeJsonParsedOrEncodedAccount {
    if rpcAccount == .null {
        return .missing(address: address)
    }
    guard let data = rpcAccount.value(for: "data") else {
        throw SolanaError(.malformedJSONRPCError)
    }
    if case .object = data, data.value(for: "parsed") != nil {
        let account = try parseJsonRpcAccount(address, rpcAccount)
        switch account {
        case let .missing(address):
            return .missing(address: address)
        case let .exists(account):
            return .parsed(account)
        }
    }
    let account = try parseBase64RpcAccount(address, rpcAccount)
    switch account {
    case let .missing(address):
        return .missing(address: address)
    case let .exists(account):
        return .encoded(account)
    }
}

private func accountConfig(encoding: String, config: FetchAccountConfig) -> RpcJsonValue {
    var members = [RpcJsonObjectMember("encoding", .string(encoding))]
    if let commitment = config.commitment {
        members.append(RpcJsonObjectMember("commitment", .string(commitment.rawValue)))
    }
    if let minContextSlot = config.minContextSlot {
        members.append(RpcJsonObjectMember("minContextSlot", .bigint(String(minContextSlot))))
    }
    return .object(members)
}

private func accountsConfig(encoding: String, config: FetchAccountsConfig) -> RpcJsonValue {
    var members = [RpcJsonObjectMember("encoding", .string(encoding))]
    if let commitment = config.commitment {
        members.append(RpcJsonObjectMember("commitment", .string(commitment.rawValue)))
    }
    if let minContextSlot = config.minContextSlot {
        members.append(RpcJsonObjectMember("minContextSlot", .bigint(String(minContextSlot))))
    }
    return .object(members)
}
