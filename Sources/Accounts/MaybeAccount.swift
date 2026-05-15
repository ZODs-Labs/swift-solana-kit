public import Addresses
public import Foundation
import SolanaErrors

public enum MaybeAccount<TData: Sendable>: Sendable {
    case missing(address: Address)
    case exists(Account<TData>)

    public var address: Address {
        switch self {
        case let .missing(address):
            return address
        case let .exists(account):
            return account.address
        }
    }

    public var exists: Bool {
        switch self {
        case .missing:
            return false
        case .exists:
            return true
        }
    }

    public var account: Account<TData>? {
        switch self {
        case .missing:
            return nil
        case let .exists(account):
            return account
        }
    }
}

extension MaybeAccount: Equatable where TData: Equatable {}
extension MaybeAccount: Hashable where TData: Hashable {}

public typealias MaybeEncodedAccount = MaybeAccount<Data>

public func assertAccountExists<TData: Sendable>(_ account: MaybeAccount<TData>) throws -> Account<TData> {
    switch account {
    case let .exists(account):
        return account
    case let .missing(address):
        throw SolanaError(.accountsAccountNotFound, context: ["address": .string(address.rawValue)])
    }
}

public func assertAccountsExist<TData: Sendable>(_ accounts: [MaybeAccount<TData>]) throws -> [Account<TData>] {
    var existing: [Account<TData>] = []
    var missing: [String] = []
    existing.reserveCapacity(accounts.count)
    for account in accounts {
        switch account {
        case let .exists(account):
            existing.append(account)
        case let .missing(address):
            missing.append(address.rawValue)
        }
    }
    if !missing.isEmpty {
        throw SolanaError(.accountsOneOrMoreAccountsNotFound, context: ["addresses": .stringArray(missing)])
    }
    return existing
}
