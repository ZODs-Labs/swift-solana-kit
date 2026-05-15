public import Accounts
public import Addresses
import Foundation
public import Rpc
import RpcTypes
import RpcSpecTypes
import SolanaErrors
public import TransactionMessages

public func fetchAddressesForLookupTables(
    lookupTableAddresses: [Address],
    rpc: SolanaRpc,
    config: FetchAccountsConfig = FetchAccountsConfig()
) async throws -> AddressesByLookupTableAddress {
    if lookupTableAddresses.isEmpty {
        return [:]
    }
    let fetchedLookupTables = try await kitFetchJsonParsedAccounts(
        rpc: rpc,
        addresses: lookupTableAddresses,
        config: config
    )
    let decodedLookupTables: [MaybeAccount<JsonParsedAccountData>] = try assertAccountsDecoded(fetchedLookupTables)
    let lookupTables: [Account<JsonParsedAccountData>] = try assertAccountsExist(decodedLookupTables)
    var entries: [(Address, [Address])] = []
    for lookupTable in lookupTables {
        entries.append((lookupTable.address, try kitAddresses(from: lookupTable.data.info)))
    }
    return AddressesByLookupTableAddress(entries)
}

public func decompileTransactionMessageFetchingLookupTables(
    _ compiledTransactionMessage: CompiledTransactionMessage,
    rpc: SolanaRpc,
    config: FetchAccountsConfig = FetchAccountsConfig(),
    lastValidBlockHeight: UInt64? = nil
) async throws -> TransactionMessage {
    let lookupTableAddresses = kitLookupTableAddresses(from: compiledTransactionMessage)
    let addressesByLookupTableAddress = lookupTableAddresses.isEmpty
        ? AddressesByLookupTableAddress()
        : try await fetchAddressesForLookupTables(
            lookupTableAddresses: lookupTableAddresses,
            rpc: rpc,
            config: config
        )
    return try decompileTransactionMessage(
        compiledTransactionMessage,
        config: DecompileTransactionMessageConfig(
            addressesByLookupTableAddress: addressesByLookupTableAddress,
            lastValidBlockHeight: lastValidBlockHeight
        )
    )
}

func kitLookupTableAddresses(from message: CompiledTransactionMessage) -> [Address] {
    switch message {
    case .legacy, .v1:
        return []
    case let .v0(message):
        return message.addressTableLookups?.map(\.lookupTableAddress) ?? []
    }
}

func kitAddresses(from info: RpcTypeJsonValue) throws -> [Address] {
    guard case let .object(members) = info,
          let addressesValue = members["addresses"],
          case let .array(values) = addressesValue
    else {
        throw SolanaError(.malformedJSONRPCError)
    }
    return try values.map { value in
        guard case let .string(rawAddress) = value else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return Address(unchecked: rawAddress)
    }
}

func kitFetchJsonParsedAccounts(
    rpc: SolanaRpc,
    addresses: [Address],
    config: FetchAccountsConfig
) async throws -> [MaybeJsonParsedOrEncodedAccount] {
    let response = try await rpc
        .request(
            "getMultipleAccounts",
            params: [
                .array(addresses.map { .string($0.rawValue) }),
                kitFetchAccountsConfig(config),
            ]
        )
        .send(abortSignal: config.abortSignal)
    let value = response.value(for: "value") ?? response
    guard case let .array(accounts) = value else {
        throw SolanaError(.malformedJSONRPCError)
    }
    guard accounts.count == addresses.count else {
        throw SolanaError(.malformedJSONRPCError)
    }
    return try zip(addresses, accounts).map { address, account in
        if account == .null {
            return .missing(address: address)
        }
        guard let data = account.value(for: "data") else {
            throw SolanaError(.malformedJSONRPCError)
        }
        if case .object = data, data.value(for: "parsed") != nil {
            return .parsed(try kitJsonParsedLookupTableAccount(address: address, account: account, data: data))
        }
        return .encoded(kitEncodedLookupTableAccount(address: address, account: account))
    }
}

func kitFetchAccountsConfig(_ config: FetchAccountsConfig) -> RpcJsonValue {
    kitRpcConfig([
        ("commitment", config.commitment.map { .string($0.rawValue) }),
        ("encoding", .string("jsonParsed")),
        ("minContextSlot", config.minContextSlot.map { .bigint(String($0)) }),
    ])
}

func kitJsonParsedLookupTableAccount(
    address: Address,
    account: RpcJsonValue,
    data: RpcJsonValue
) throws -> Account<JsonParsedAccountData> {
    guard let parsed = data.value(for: "parsed"), case .object = parsed else {
        throw SolanaError(.malformedJSONRPCError)
    }
    let info = parsed.value(for: "info").map(kitRpcTypeJsonValue) ?? .object([:])
    let program = data.value(for: "program").flatMap(kitString)
    let type = parsed.value(for: "type").flatMap(kitString)
    let meta = (program == nil && type == nil) ? nil : ParsedAccountMeta(program: program, type: type)
    return Account(
        address: address,
        data: JsonParsedAccountData(info: info, parsedAccountMeta: meta),
        base: kitLookupTableAccountBase(from: account)
    )
}

func kitEncodedLookupTableAccount(address: Address, account: RpcJsonValue) -> EncodedAccount {
    Account(
        address: address,
        data: Data(),
        executable: account.value(for: "executable").flatMap(kitBool) ?? false,
        lamports: account.value(for: "lamports").flatMap(kitUInt64) ?? 0,
        programAddress: account.value(for: "owner").flatMap(kitString).map(Address.init(unchecked:)) ?? kitSystemProgramAddress,
        space: account.value(for: "space").flatMap(kitUInt64) ?? 0
    )
}

func kitLookupTableAccountBase(from account: RpcJsonValue) -> BaseAccount {
    BaseAccount(
        executable: account.value(for: "executable").flatMap(kitBool) ?? false,
        lamports: account.value(for: "lamports").flatMap(kitUInt64) ?? 0,
        programAddress: account.value(for: "owner").flatMap(kitString).map(Address.init(unchecked:)) ?? kitSystemProgramAddress,
        space: account.value(for: "space").flatMap(kitUInt64) ?? 0
    )
}

let kitSystemProgramAddress = Address(unchecked: "11111111111111111111111111111111")
