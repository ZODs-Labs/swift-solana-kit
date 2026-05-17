import Addresses
import Foundation
import Instructions
import SolanaErrors
import XCTest

final class InstructionsDetailedBehaviorTests: XCTestCase {
    func testLookupAccountInitializersDowngradeSignerRolesAndPreserveLookupFields() throws {
        let accountAddress = try instructionsAccountAddress()
        let lookupTableAddress = try instructionsLookupTableAddress()

        let readonlySigner = AccountLookupMeta(
            address: accountAddress,
            addressIndex: 3,
            lookupTableAddress: lookupTableAddress,
            role: .readonlySigner
        )
        let writableSigner = AccountLookupMeta(
            address: accountAddress,
            addressIndex: 8,
            lookupTableAddress: lookupTableAddress,
            role: .writableSigner
        )

        XCTAssertEqual(readonlySigner.address, accountAddress)
        XCTAssertEqual(readonlySigner.addressIndex, 3)
        XCTAssertEqual(readonlySigner.lookupTableAddress, lookupTableAddress)
        XCTAssertEqual(readonlySigner.role, .readonly)

        XCTAssertEqual(writableSigner.address, accountAddress)
        XCTAssertEqual(writableSigner.addressIndex, 8)
        XCTAssertEqual(writableSigner.lookupTableAddress, lookupTableAddress)
        XCTAssertEqual(writableSigner.role, .writable)
    }

    func testInstructionAccountAccessorsExposeWrappedAddressAndRole() throws {
        let accountAddress = try instructionsAccountAddress()
        let lookupAddress = try instructionsLookupAccountAddress()
        let lookupTableAddress = try instructionsLookupTableAddress()

        let account = InstructionAccount.account(writableSignerAccount(accountAddress))
        let lookup = InstructionAccount.lookup(
            writableLookupAccount(
                address: lookupAddress,
                addressIndex: 4,
                lookupTableAddress: lookupTableAddress
            )
        )

        XCTAssertEqual(account.address, accountAddress)
        XCTAssertEqual(account.role, .writableSigner)
        XCTAssertEqual(lookup.address, lookupAddress)
        XCTAssertEqual(lookup.role, .writable)
    }

    func testInstructionAssertionsExposeExactFailureContexts() throws {
        let programAddress = try instructionsProgramAddress()
        let expectedProgramAddress = try instructionsLookupTableAddress()
        let accountAddress = try instructionsAccountAddress()
        let instruction = Instruction(
            programAddress: programAddress,
            accounts: [.account(readonlyAccount(accountAddress))],
            data: Data([1, 2, 3, 4])
        )

        do {
            try assertIsInstructionForProgram(instruction, programAddress: expectedProgramAddress)
            XCTFail("Expected program mismatch")
        } catch let error {
            XCTAssertEqual(error.solanaCode, .instructionProgramIDMismatch)
            XCTAssertEqual(error.context["actualProgramAddress"], .string(programAddress.rawValue))
            XCTAssertEqual(error.context["expectedProgramAddress"], .string(expectedProgramAddress.rawValue))
        }

        do {
            try assertIsInstructionWithAccounts(Instruction(programAddress: programAddress, data: Data([9, 8])))
            XCTFail("Expected missing accounts")
        } catch let error {
            XCTAssertEqual(error.solanaCode, .instructionExpectedToHaveAccounts)
            XCTAssertEqual(error.context["programAddress"], .string(programAddress.rawValue))
            XCTAssertEqual(error.context["data"], .bytes(Data([9, 8])))
        }

        do {
            try assertIsInstructionWithData(
                Instruction(programAddress: programAddress, accounts: [.account(readonlyAccount(accountAddress))])
            )
            XCTFail("Expected missing data")
        } catch let error {
            XCTAssertEqual(error.solanaCode, .instructionExpectedToHaveData)
            XCTAssertEqual(error.context["programAddress"], .string(programAddress.rawValue))
            XCTAssertEqual(error.context["accountAddresses"], .stringArray([accountAddress.rawValue]))
        }
    }

    func testInstructionAssertionsOmitUndefinedOptionalContextFields() throws {
        let programAddress = try instructionsProgramAddress()

        do {
            try assertIsInstructionWithAccounts(Instruction(programAddress: programAddress))
            XCTFail("Expected missing accounts")
        } catch let error {
            XCTAssertEqual(error.context["programAddress"], .string(programAddress.rawValue))
            XCTAssertNil(error.context["data"])
        }

        do {
            try assertIsInstructionWithData(Instruction(programAddress: programAddress))
            XCTFail("Expected missing data")
        } catch let error {
            XCTAssertEqual(error.context["programAddress"], .string(programAddress.rawValue))
            XCTAssertNil(error.context["accountAddresses"])
        }
    }

    func testAccountRoleCodableUsesNumericFlags() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertEqual(String(data: try encoder.encode(AccountRole.readonly), encoding: .utf8), "0")
        XCTAssertEqual(String(data: try encoder.encode(AccountRole.writable), encoding: .utf8), "1")
        XCTAssertEqual(String(data: try encoder.encode(AccountRole.readonlySigner), encoding: .utf8), "2")
        XCTAssertEqual(String(data: try encoder.encode(AccountRole.writableSigner), encoding: .utf8), "3")

        XCTAssertEqual(try decoder.decode(AccountRole.self, from: Data("0".utf8)), .readonly)
        XCTAssertEqual(try decoder.decode(AccountRole.self, from: Data("3".utf8)), .writableSigner)
        XCTAssertThrowsError(try decoder.decode(AccountRole.self, from: Data("4".utf8)))
    }

    func testInstructionRoundTripsThroughJSONWithAccountVariantsAndDataBytes() throws {
        let programAddress = try instructionsProgramAddress()
        let accountAddress = try instructionsAccountAddress()
        let lookupAddress = try instructionsLookupAccountAddress()
        let lookupTableAddress = try instructionsLookupTableAddress()
        let instruction = Instruction(
            programAddress: programAddress,
            accounts: [
                .account(readonlySignerAccount(accountAddress)),
                .lookup(
                    writableLookupAccount(
                        address: lookupAddress,
                        addressIndex: 5,
                        lookupTableAddress: lookupTableAddress
                    )
                ),
            ],
            data: Data([0, 1, 2, 255])
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(instruction)
        let decoded = try JSONDecoder().decode(Instruction.self, from: encoded)

        XCTAssertEqual(decoded, instruction)
        XCTAssertEqual(
            String(data: encoded, encoding: .utf8),
            #"{"accounts":[{"account":{"_0":{"address":"SysvarRent111111111111111111111111111111111","role":2}}},{"lookup":{"_0":{"address":"SysvarC1ock11111111111111111111111111111111","addressIndex":5,"lookupTableAddress":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA","role":1}}}],"data":"AAEC\/w==","programAddress":"11111111111111111111111111111111"}"#
        )
    }
}

private func instructionsProgramAddress() throws -> Address {
    try address("11111111111111111111111111111111")
}

private func instructionsAccountAddress() throws -> Address {
    try address("SysvarRent111111111111111111111111111111111")
}

private func instructionsLookupAccountAddress() throws -> Address {
    try address("SysvarC1ock11111111111111111111111111111111")
}

private func instructionsLookupTableAddress() throws -> Address {
    try address("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")
}
