import Addresses
import Instructions
import SolanaErrors
import XCTest

final class InstructionsTests: XCTestCase {
    func testRoleRawValuesMatchBitFlags() {
        XCTAssertEqual(AccountRole.readonly.rawValue, 0b00)
        XCTAssertEqual(AccountRole.writable.rawValue, 0b01)
        XCTAssertEqual(AccountRole.readonlySigner.rawValue, 0b10)
        XCTAssertEqual(AccountRole.writableSigner.rawValue, 0b11)
    }

    func testDowngradeRoleToNonSigner() {
        XCTAssertEqual(downgradeRoleToNonSigner(.readonly), .readonly)
        XCTAssertEqual(downgradeRoleToNonSigner(.writable), .writable)
        XCTAssertEqual(downgradeRoleToNonSigner(.readonlySigner), .readonly)
        XCTAssertEqual(downgradeRoleToNonSigner(.writableSigner), .writable)
    }

    func testDowngradeRoleToReadonly() {
        XCTAssertEqual(downgradeRoleToReadonly(.readonly), .readonly)
        XCTAssertEqual(downgradeRoleToReadonly(.writable), .readonly)
        XCTAssertEqual(downgradeRoleToReadonly(.readonlySigner), .readonlySigner)
        XCTAssertEqual(downgradeRoleToReadonly(.writableSigner), .readonlySigner)
    }

    func testRolePredicates() {
        XCTAssertFalse(isSignerRole(.readonly))
        XCTAssertFalse(isSignerRole(.writable))
        XCTAssertTrue(isSignerRole(.readonlySigner))
        XCTAssertTrue(isSignerRole(.writableSigner))

        XCTAssertFalse(isWritableRole(.readonly))
        XCTAssertFalse(isWritableRole(.readonlySigner))
        XCTAssertTrue(isWritableRole(.writable))
        XCTAssertTrue(isWritableRole(.writableSigner))
    }

    func testMergeRoles() {
        let cases: [(AccountRole, AccountRole, AccountRole)] = [
            (.readonly, .readonly, .readonly),
            (.readonly, .writable, .writable),
            (.readonly, .readonlySigner, .readonlySigner),
            (.readonly, .writableSigner, .writableSigner),
            (.writable, .readonly, .writable),
            (.writable, .writable, .writable),
            (.writable, .readonlySigner, .writableSigner),
            (.writable, .writableSigner, .writableSigner),
            (.readonlySigner, .readonly, .readonlySigner),
            (.readonlySigner, .writable, .writableSigner),
            (.readonlySigner, .readonlySigner, .readonlySigner),
            (.readonlySigner, .writableSigner, .writableSigner),
            (.writableSigner, .readonly, .writableSigner),
            (.writableSigner, .writable, .writableSigner),
            (.writableSigner, .readonlySigner, .writableSigner),
            (.writableSigner, .writableSigner, .writableSigner),
        ]

        for (lhs, rhs, expected) in cases {
            XCTAssertEqual(mergeRoles(lhs, rhs), expected)
        }
    }

    func testUpgradeRoles() {
        XCTAssertEqual(upgradeRoleToSigner(.readonly), .readonlySigner)
        XCTAssertEqual(upgradeRoleToSigner(.writable), .writableSigner)
        XCTAssertEqual(upgradeRoleToSigner(.readonlySigner), .readonlySigner)
        XCTAssertEqual(upgradeRoleToSigner(.writableSigner), .writableSigner)

        XCTAssertEqual(upgradeRoleToWritable(.readonly), .writable)
        XCTAssertEqual(upgradeRoleToWritable(.writable), .writable)
        XCTAssertEqual(upgradeRoleToWritable(.readonlySigner), .writableSigner)
        XCTAssertEqual(upgradeRoleToWritable(.writableSigner), .writableSigner)
    }

    func testAccountConstructorsSetRoles() throws {
        let accountAddress = try accountAddress()
        let otherProgramAddress = try otherProgramAddress()

        XCTAssertEqual(readonlyAccount(accountAddress).role, .readonly)
        XCTAssertEqual(writableAccount(accountAddress).role, .writable)
        XCTAssertEqual(readonlySignerAccount(accountAddress).role, .readonlySigner)
        XCTAssertEqual(writableSignerAccount(accountAddress).role, .writableSigner)

        let lookup = writableLookupAccount(
            address: accountAddress,
            addressIndex: 7,
            lookupTableAddress: otherProgramAddress
        )
        XCTAssertEqual(lookup.address, accountAddress)
        XCTAssertEqual(lookup.addressIndex, 7)
        XCTAssertEqual(lookup.lookupTableAddress, otherProgramAddress)
        XCTAssertEqual(lookup.role, .writable)
    }

    func testLookupAccountsCannotBecomeSigners() throws {
        let accountAddress = try accountAddress()
        let lookupTableAddress = try otherProgramAddress()

        XCTAssertEqual(
            AccountLookupMeta(
                address: accountAddress,
                addressIndex: 0,
                lookupTableAddress: lookupTableAddress,
                role: .readonlySigner
            ).role,
            .readonly
        )
        XCTAssertEqual(
            AccountLookupMeta(
                address: accountAddress,
                addressIndex: 0,
                lookupTableAddress: lookupTableAddress,
                role: .writableSigner
            ).role,
            .writable
        )
    }

    func testInstructionForProgramChecksProgramAddress() throws {
        let programAddress = try programAddress()
        let otherProgramAddress = try otherProgramAddress()
        let instruction = Instruction(programAddress: programAddress)

        XCTAssertTrue(isInstructionForProgram(instruction, programAddress: programAddress))
        XCTAssertFalse(isInstructionForProgram(instruction, programAddress: otherProgramAddress))
        XCTAssertNoThrow(try assertIsInstructionForProgram(instruction, programAddress: programAddress))
        XCTAssertThrowsError(try assertIsInstructionForProgram(instruction, programAddress: otherProgramAddress)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.instructionProgramIDMismatch.rawValue)
        }
    }

    func testInstructionWithAccountsChecksPresenceNotEmptiness() throws {
        let programAddress = try programAddress()
        let accountAddress = try accountAddress()
        let account = InstructionAccount.account(readonlyAccount(accountAddress))
        let withAccounts = Instruction(programAddress: programAddress, accounts: [account])
        let withEmptyAccounts = Instruction(programAddress: programAddress, accounts: [])
        let withoutAccounts = Instruction(programAddress: programAddress)

        XCTAssertTrue(isInstructionWithAccounts(withAccounts))
        XCTAssertTrue(isInstructionWithAccounts(withEmptyAccounts))
        XCTAssertFalse(isInstructionWithAccounts(withoutAccounts))
        XCTAssertNoThrow(try assertIsInstructionWithAccounts(withAccounts))
        XCTAssertNoThrow(try assertIsInstructionWithAccounts(withEmptyAccounts))
        XCTAssertThrowsError(try assertIsInstructionWithAccounts(withoutAccounts)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.instructionExpectedToHaveAccounts.rawValue)
        }
    }

    func testInstructionWithDataChecksPresenceNotEmptiness() throws {
        let programAddress = try programAddress()
        let withData = Instruction(programAddress: programAddress, data: Data([1, 2, 3, 4]))
        let withEmptyData = Instruction(programAddress: programAddress, data: Data())
        let withoutData = Instruction(programAddress: programAddress)

        XCTAssertTrue(isInstructionWithData(withData))
        XCTAssertTrue(isInstructionWithData(withEmptyData))
        XCTAssertFalse(isInstructionWithData(withoutData))
        XCTAssertNoThrow(try assertIsInstructionWithData(withData))
        XCTAssertNoThrow(try assertIsInstructionWithData(withEmptyData))
        XCTAssertThrowsError(try assertIsInstructionWithData(withoutData)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.instructionExpectedToHaveData.rawValue)
        }
    }
}

private func programAddress() throws -> Address {
    try address("11111111111111111111111111111111")
}

private func otherProgramAddress() throws -> Address {
    try address("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")
}

private func accountAddress() throws -> Address {
    try address("SysvarRent111111111111111111111111111111111")
}

private func solanaCode(_ error: any Error) -> Int? {
    (error as? any SolanaErrorCoded)?.code
}
