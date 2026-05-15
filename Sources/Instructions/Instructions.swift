public import Addresses
public import Foundation
public import SolanaErrors

private let signerBitmask: UInt8 = 0b10
private let writableBitmask: UInt8 = 0b01

public enum AccountRole: UInt8, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case readonly = 0b00
    case writable = 0b01
    case readonlySigner = 0b10
    case writableSigner = 0b11
}

public struct AccountMeta: Sendable, Equatable, Hashable, Codable {
    public let address: Address
    public let role: AccountRole

    public init(address: Address, role: AccountRole) {
        self.address = address
        self.role = role
    }
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

    public init(address: Address, addressIndex: Int, lookupTableAddress: Address, role: AccountRole) {
        self.address = address
        self.addressIndex = addressIndex
        self.lookupTableAddress = lookupTableAddress
        self.role = downgradeRoleToNonSigner(role)
    }
}

public typealias ReadonlyAccountLookup = AccountLookupMeta
public typealias WritableAccountLookup = AccountLookupMeta

public enum InstructionAccount: Sendable, Equatable, Hashable, Codable {
    case account(AccountMeta)
    case lookup(AccountLookupMeta)

    public var address: Address {
        switch self {
        case let .account(account):
            account.address
        case let .lookup(account):
            account.address
        }
    }

    public var role: AccountRole {
        switch self {
        case let .account(account):
            account.role
        case let .lookup(account):
            account.role
        }
    }
}

public struct Instruction: Sendable, Equatable, Hashable, Codable {
    public let accounts: [InstructionAccount]?
    public let data: Data?
    public let programAddress: Address

    public init(programAddress: Address, accounts: [InstructionAccount]? = nil, data: Data? = nil) {
        self.accounts = accounts
        self.data = data
        self.programAddress = programAddress
    }
}

public typealias InstructionWithAccounts = Instruction
public typealias InstructionWithData = Instruction

public func downgradeRoleToNonSigner(_ role: AccountRole) -> AccountRole {
    accountRole(rawValue: role.rawValue & ~signerBitmask)
}

public func downgradeRoleToReadonly(_ role: AccountRole) -> AccountRole {
    accountRole(rawValue: role.rawValue & ~writableBitmask)
}

public func isSignerRole(_ role: AccountRole) -> Bool {
    role.rawValue >= AccountRole.readonlySigner.rawValue
}

public func isWritableRole(_ role: AccountRole) -> Bool {
    (role.rawValue & writableBitmask) != 0
}

public func mergeRoles(_ roleA: AccountRole, _ roleB: AccountRole) -> AccountRole {
    accountRole(rawValue: roleA.rawValue | roleB.rawValue)
}

public func upgradeRoleToSigner(_ role: AccountRole) -> AccountRole {
    accountRole(rawValue: role.rawValue | signerBitmask)
}

public func upgradeRoleToWritable(_ role: AccountRole) -> AccountRole {
    accountRole(rawValue: role.rawValue | writableBitmask)
}

public func readonlyAccount(_ address: Address) -> AccountMeta {
    AccountMeta(address: address, role: .readonly)
}

public func writableAccount(_ address: Address) -> AccountMeta {
    AccountMeta(address: address, role: .writable)
}

public func readonlySignerAccount(_ address: Address) -> AccountMeta {
    AccountMeta(address: address, role: .readonlySigner)
}

public func writableSignerAccount(_ address: Address) -> AccountMeta {
    AccountMeta(address: address, role: .writableSigner)
}

public func readonlyLookupAccount(
    address: Address,
    addressIndex: Int,
    lookupTableAddress: Address
) -> AccountLookupMeta {
    AccountLookupMeta(
        address: address,
        addressIndex: addressIndex,
        lookupTableAddress: lookupTableAddress,
        role: .readonly
    )
}

public func writableLookupAccount(
    address: Address,
    addressIndex: Int,
    lookupTableAddress: Address
) -> AccountLookupMeta {
    AccountLookupMeta(
        address: address,
        addressIndex: addressIndex,
        lookupTableAddress: lookupTableAddress,
        role: .writable
    )
}

public func isInstructionForProgram(_ instruction: Instruction, programAddress: Address) -> Bool {
    instruction.programAddress == programAddress
}

public func assertIsInstructionForProgram(
    _ instruction: Instruction,
    programAddress: Address
) throws(SolanaError) {
    guard isInstructionForProgram(instruction, programAddress: programAddress) else {
        throw SolanaError(
            .instructionProgramIDMismatch,
            context: [
                "actualProgramAddress": .string(instruction.programAddress.rawValue),
                "expectedProgramAddress": .string(programAddress.rawValue),
            ]
        )
    }
}

public func isInstructionWithAccounts(_ instruction: Instruction) -> Bool {
    instruction.accounts != nil
}

public func assertIsInstructionWithAccounts(_ instruction: Instruction) throws(SolanaError) {
    guard isInstructionWithAccounts(instruction) else {
        var context: SolanaErrorContext = ["programAddress": .string(instruction.programAddress.rawValue)]
        if let data = instruction.data {
            context.values["data"] = .bytes(data)
        }
        throw SolanaError(.instructionExpectedToHaveAccounts, context: context)
    }
}

public func isInstructionWithData(_ instruction: Instruction) -> Bool {
    instruction.data != nil
}

public func assertIsInstructionWithData(_ instruction: Instruction) throws(SolanaError) {
    guard isInstructionWithData(instruction) else {
        var context: SolanaErrorContext = ["programAddress": .string(instruction.programAddress.rawValue)]
        if let accounts = instruction.accounts {
            context.values["accountAddresses"] = .stringArray(accounts.map(\.address.rawValue))
        }
        throw SolanaError(.instructionExpectedToHaveData, context: context)
    }
}

private func accountRole(rawValue: UInt8) -> AccountRole {
    AccountRole(rawValue: rawValue) ?? .readonly
}
