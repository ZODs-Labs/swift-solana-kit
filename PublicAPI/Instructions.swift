import Addresses
import Foundation
import SolanaErrors

public enum AccountRole: UInt8, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case readonly
    case writable
    case readonlySigner
    case writableSigner
}

public struct AccountMeta: Sendable, Equatable, Hashable, Codable {
    public let address: Address
    public let role: AccountRole
    public init(address: Address, role: AccountRole)
}

public typealias ReadonlyAccount = AccountMeta
public typealias WritableAccount = AccountMeta
public typealias ReadonlySignerAccount = AccountMeta
public typealias WritableSignerAccount = AccountMeta

public struct AccountLookupMeta: Sendable, Equatable, Hashable, Codable {
    public let address: Address
    public let addressIndex: Int
    public let lookupTableAddress: Address
    public let role: AccountRole
    public init(address: Address, addressIndex: Int, lookupTableAddress: Address, role: AccountRole)
}

public typealias ReadonlyAccountLookup = AccountLookupMeta
public typealias WritableAccountLookup = AccountLookupMeta

public enum InstructionAccount: Sendable, Equatable, Hashable, Codable {
    case account(AccountMeta)
    case lookup(AccountLookupMeta)
    public var address: Address { get }
    public var role: AccountRole { get }
}

public struct Instruction: Sendable, Equatable, Hashable, Codable {
    public let accounts: [InstructionAccount]?
    public let data: Data?
    public let programAddress: Address
    public init(programAddress: Address, accounts: [InstructionAccount]? = nil, data: Data? = nil)
}

public typealias InstructionWithAccounts = Instruction
public typealias InstructionWithData = Instruction

public func downgradeRoleToNonSigner(_ role: AccountRole) -> AccountRole
public func downgradeRoleToReadonly(_ role: AccountRole) -> AccountRole
public func isSignerRole(_ role: AccountRole) -> Bool
public func isWritableRole(_ role: AccountRole) -> Bool
public func mergeRoles(_ roleA: AccountRole, _ roleB: AccountRole) -> AccountRole
public func upgradeRoleToSigner(_ role: AccountRole) -> AccountRole
public func upgradeRoleToWritable(_ role: AccountRole) -> AccountRole

public func readonlyAccount(_ address: Address) -> AccountMeta
public func writableAccount(_ address: Address) -> AccountMeta
public func readonlySignerAccount(_ address: Address) -> AccountMeta
public func writableSignerAccount(_ address: Address) -> AccountMeta
public func readonlyLookupAccount(address: Address, addressIndex: Int, lookupTableAddress: Address) -> AccountLookupMeta
public func writableLookupAccount(address: Address, addressIndex: Int, lookupTableAddress: Address) -> AccountLookupMeta

public func isInstructionForProgram(_ instruction: Instruction, programAddress: Address) -> Bool
public func assertIsInstructionForProgram(_ instruction: Instruction, programAddress: Address) throws(SolanaError)
public func isInstructionWithAccounts(_ instruction: Instruction) -> Bool
public func assertIsInstructionWithAccounts(_ instruction: Instruction) throws(SolanaError)
public func isInstructionWithData(_ instruction: Instruction) -> Bool
public func assertIsInstructionWithData(_ instruction: Instruction) throws(SolanaError)
