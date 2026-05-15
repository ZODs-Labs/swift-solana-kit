public import Addresses
public import Foundation
public import RpcTypes

public let baseAccountSize = 128

public struct BaseAccount: Sendable, Equatable, Hashable {
    public let executable: Bool
    public let lamports: Lamports
    public let programAddress: Address
    public let space: UInt64

    public init(executable: Bool, lamports: Lamports, programAddress: Address, space: UInt64) {
        self.executable = executable
        self.lamports = lamports
        self.programAddress = programAddress
        self.space = space
    }
}

public struct Account<TData: Sendable>: Sendable {
    public let address: Address
    public let data: TData
    public let executable: Bool
    public let lamports: Lamports
    public let programAddress: Address
    public let space: UInt64
    public let exists: Bool

    public init(address: Address, data: TData, base: BaseAccount, exists: Bool = true) {
        self.address = address
        self.data = data
        self.executable = base.executable
        self.lamports = base.lamports
        self.programAddress = base.programAddress
        self.space = base.space
        self.exists = exists
    }

    public init(
        address: Address,
        data: TData,
        executable: Bool,
        lamports: Lamports,
        programAddress: Address,
        space: UInt64,
        exists: Bool = true
    ) {
        self.address = address
        self.data = data
        self.executable = executable
        self.lamports = lamports
        self.programAddress = programAddress
        self.space = space
        self.exists = exists
    }

    var base: BaseAccount {
        BaseAccount(executable: executable, lamports: lamports, programAddress: programAddress, space: space)
    }
}

extension Account: Equatable where TData: Equatable {}
extension Account: Hashable where TData: Hashable {}

public typealias EncodedAccount = Account<Data>
