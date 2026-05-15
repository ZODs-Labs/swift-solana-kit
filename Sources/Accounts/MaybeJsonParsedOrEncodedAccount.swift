public import Addresses
public import Foundation
import SolanaErrors

public enum MaybeJsonParsedOrEncodedAccount: Sendable {
    case missing(address: Address)
    case parsed(Account<JsonParsedAccountData>)
    case encoded(EncodedAccount)

    public var address: Address {
        switch self {
        case let .missing(address):
            return address
        case let .parsed(account):
            return account.address
        case let .encoded(account):
            return account.address
        }
    }

    public var exists: Bool {
        switch self {
        case .missing:
            return false
        case .parsed, .encoded:
            return true
        }
    }

    public var parsedAccount: Account<JsonParsedAccountData>? {
        switch self {
        case let .parsed(account):
            return account
        case .missing, .encoded:
            return nil
        }
    }

    public var encodedAccount: EncodedAccount? {
        switch self {
        case let .encoded(account):
            return account
        case .missing, .parsed:
            return nil
        }
    }
}

extension MaybeJsonParsedOrEncodedAccount: Equatable {}
extension MaybeJsonParsedOrEncodedAccount: Hashable {}

public func assertAccountDecoded(
    _ account: MaybeJsonParsedOrEncodedAccount
) throws -> MaybeAccount<JsonParsedAccountData> {
    switch account {
    case let .missing(address):
        return .missing(address: address)
    case let .parsed(account):
        return .exists(account)
    case let .encoded(account):
        throw SolanaError(.accountsExpectedDecodedAccount, context: ["address": .string(account.address.rawValue)])
    }
}

public func assertAccountsDecoded(
    _ accounts: [MaybeJsonParsedOrEncodedAccount]
) throws -> [MaybeAccount<JsonParsedAccountData>] {
    let encodedAddresses = accounts.compactMap { account -> String? in
        if case let .encoded(encoded) = account {
            return encoded.address.rawValue
        }
        return nil
    }
    if !encodedAddresses.isEmpty {
        throw SolanaError(.accountsExpectedAllAccountsToBeDecoded, context: ["addresses": .stringArray(encodedAddresses)])
    }
    return try accounts.map { account in
        switch account {
        case let .missing(address):
            return .missing(address: address)
        case let .parsed(account):
            return .exists(account)
        case let .encoded(account):
            throw SolanaError(.accountsExpectedDecodedAccount, context: ["address": .string(account.address.rawValue)])
        }
    }
}
