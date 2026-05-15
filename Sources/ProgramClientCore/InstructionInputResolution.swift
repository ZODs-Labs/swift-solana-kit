public import Addresses
import Instructions
public import Signers
public import SolanaErrors

public enum ResolvedInstructionAccountValue: Sendable {
    case address(Address)
    case programDerivedAddress(ProgramDerivedAddress)
    case transactionSigner(TransactionSigner)

    public var address: Address {
        switch self {
        case let .address(address):
            address
        case let .programDerivedAddress(pda):
            pda.address
        case let .transactionSigner(signer):
            signer.address
        }
    }
}

public struct ResolvedInstructionAccount: Sendable {
    public let isWritable: Bool
    public let value: ResolvedInstructionAccountValue?

    public init(isWritable: Bool, value: ResolvedInstructionAccountValue?) {
        self.isWritable = isWritable
        self.value = value
    }
}

public enum OptionalAccountStrategy: Sendable, Equatable, Hashable {
    case omitted
    case programID
}

public func getNonNullResolvedInstructionInput<T>(
    _ inputName: String,
    _ value: T?
) throws(SolanaError) -> T {
    guard let value else {
        throw SolanaError(
            .programClientsResolvedInstructionInputMustBeNonNull,
            context: ["inputName": .string(inputName)]
        )
    }
    return value
}

public func getAddressFromResolvedInstructionAccount(
    _ inputName: String,
    _ value: ResolvedInstructionAccountValue?
) throws(SolanaError) -> Address {
    try getNonNullResolvedInstructionInput(inputName, value).address
}

public func getResolvedInstructionAccountAsProgramDerivedAddress(
    _ inputName: String,
    _ value: ResolvedInstructionAccountValue?
) throws(SolanaError) -> ProgramDerivedAddress {
    guard case let .programDerivedAddress(pda)? = value else {
        throw unexpectedResolvedInstructionInputType(inputName: inputName, expectedType: "ProgramDerivedAddress")
    }
    return pda
}

public func getResolvedInstructionAccountAsTransactionSigner(
    _ inputName: String,
    _ value: ResolvedInstructionAccountValue?
) throws(SolanaError) -> TransactionSigner {
    guard case let .transactionSigner(signer)? = value, isTransactionSigner(signer) else {
        throw unexpectedResolvedInstructionInputType(inputName: inputName, expectedType: "TransactionSigner")
    }
    return signer
}

public typealias AccountMetaFactory = @Sendable (
    _ inputName: String,
    _ account: ResolvedInstructionAccount
) throws(SolanaError) -> InstructionAccountWithSigner?

public func getAccountMetaFactory(
    programAddress: Address,
    optionalAccountStrategy: OptionalAccountStrategy
) -> AccountMetaFactory {
    { inputName, account in
        guard let value = account.value else {
            switch optionalAccountStrategy {
            case .omitted:
                return nil
            case .programID:
                return .account(AccountMeta(address: programAddress, role: .readonly))
            }
        }

        let writableRole: AccountRole = account.isWritable ? .writable : .readonly
        switch value {
        case .address, .programDerivedAddress:
            return .account(AccountMeta(
                address: try getAddressFromResolvedInstructionAccount(inputName, value),
                role: writableRole
            ))
        case let .transactionSigner(signer):
            return try .signer(AccountSignerMeta(
                address: signer.address,
                role: upgradeRoleToSigner(writableRole),
                signer: signer
            ))
        }
    }
}

private func unexpectedResolvedInstructionInputType(
    inputName: String,
    expectedType: String
) -> SolanaError {
    SolanaError(
        .programClientsUnexpectedResolvedInstructionInputType,
        context: [
            "expectedType": .string(expectedType),
            "inputName": .string(inputName),
        ]
    )
}
