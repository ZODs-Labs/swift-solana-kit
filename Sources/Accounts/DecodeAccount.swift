public import CodecsCore
public import Foundation
import SolanaErrors

public func decodeAccount<D: Decoder>(
    _ encodedAccount: EncodedAccount,
    using decoder: D
) throws -> Account<D.Decoded> where D.Decoded: Sendable {
    do {
        let data = try decoder.decode(encodedAccount.data, at: 0)
        return Account(address: encodedAccount.address, data: data, base: encodedAccount.base, exists: true)
    } catch {
        throw SolanaError(
            .accountsFailedToDecodeAccount,
            context: ["address": .string(encodedAccount.address.rawValue)]
        )
    }
}

public func decodeAccount<D: Decoder>(
    _ encodedAccount: MaybeEncodedAccount,
    using decoder: D
) throws -> MaybeAccount<D.Decoded> where D.Decoded: Sendable {
    switch encodedAccount {
    case let .missing(address):
        return .missing(address: address)
    case let .exists(account):
        return try .exists(decodeAccount(account, using: decoder))
    }
}

public func assertAccountDecoded<TData: Sendable>(_ account: Account<TData>) throws {
    if TData.self == Data.self {
        throw SolanaError(.accountsExpectedDecodedAccount, context: ["address": .string(account.address.rawValue)])
    }
}

public func assertAccountDecoded<TData: Sendable>(_ account: MaybeAccount<TData>) throws {
    if case let .exists(existing) = account {
        try assertAccountDecoded(existing)
    }
}

public func assertAccountsDecoded<TData: Sendable>(_ accounts: [Account<TData>]) throws {
    if TData.self == Data.self {
        let addresses = accounts.map(\.address.rawValue)
        if !addresses.isEmpty {
            throw SolanaError(.accountsExpectedAllAccountsToBeDecoded, context: ["addresses": .stringArray(addresses)])
        }
    }
}

public func assertAccountsDecoded<TData: Sendable>(_ accounts: [MaybeAccount<TData>]) throws {
    if TData.self == Data.self {
        let addresses = accounts.compactMap { account -> String? in
            if case let .exists(existing) = account {
                return existing.address.rawValue
            }
            return nil
        }
        if !addresses.isEmpty {
            throw SolanaError(.accountsExpectedAllAccountsToBeDecoded, context: ["addresses": .stringArray(addresses)])
        }
    }
}
