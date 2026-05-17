import Addresses
import SolanaErrors
@testable import Programs
import XCTest

final class ProgramsDetailedBehaviorTests: XCTestCase {
    func testProgramErrorRejectsNonSolanaAndNonCustomErrors() throws {
        let programAddress = try programsProgramAddress()
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: programAddress),
        ])

        XCTAssertFalse(isProgramError(ProgramsTestError(), transactionMessage: message, programAddress: programAddress))
        XCTAssertFalse(
            isProgramError(
                SolanaError(.instructionErrorUnknown, context: ["index": .int(0), "code": .int(42)]),
                transactionMessage: message,
                programAddress: programAddress
            )
        )
    }

    func testProgramErrorRejectsMissingMalformedAndNegativeIndexes() throws {
        let programAddress = try programsProgramAddress()
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: programAddress),
        ])

        let errors = [
            SolanaError(.instructionErrorCustom, context: ["code": .int(42)]),
            SolanaError(.instructionErrorCustom, context: ["index": .string("nope"), "code": .int(42)]),
            SolanaError(.instructionErrorCustom, context: ["index": .int(-1), "code": .int(42)]),
        ]

        for error in errors {
            XCTAssertFalse(isProgramError(error, transactionMessage: message, programAddress: programAddress))
        }
    }

    func testProgramErrorAcceptsIntegerCompatibleIndexAndCodeContexts() throws {
        let programAddress = try programsProgramAddress()
        let otherProgramAddress = try programsOtherProgramAddress()
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: otherProgramAddress),
            ProgramErrorInstruction(programAddress: programAddress),
        ])

        XCTAssertTrue(
            isProgramError(
                SolanaError(.instructionErrorCustom, context: ["index": .uint(1), "code": .bigint("42")]),
                transactionMessage: message,
                programAddress: programAddress,
                code: 42
            )
        )
        XCTAssertTrue(
            isProgramError(
                SolanaError(.instructionErrorCustom, context: ["index": .string("1"), "code": .string("7")]),
                transactionMessage: message,
                programAddress: programAddress,
                code: 7
            )
        )
    }

    func testProgramErrorWithoutExpectedCodeIgnoresMalformedCodeContext() throws {
        let programAddress = try programsProgramAddress()
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: programAddress),
        ])
        let error = SolanaError(.instructionErrorCustom, context: [
            "index": .int(0),
            "code": .string("not a number"),
        ])

        XCTAssertTrue(isProgramError(error, transactionMessage: message, programAddress: programAddress))
        XCTAssertFalse(isProgramError(error, transactionMessage: message, programAddress: programAddress, code: 0))
    }

    func testProgramInstructionMessagePreservesInstructionOrder() throws {
        let first = try programsOtherProgramAddress()
        let second = try programsProgramAddress()
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: first),
            ProgramErrorInstruction(programAddress: second),
        ])
        let error = SolanaError(.instructionErrorCustom, context: [
            "index": .int(1),
            "code": .int(9),
        ])

        XCTAssertFalse(isProgramError(error, transactionMessage: message, programAddress: first, code: 9))
        XCTAssertTrue(isProgramError(error, transactionMessage: message, programAddress: second, code: 9))
    }
}

private struct ProgramsTestError: Error {}

private func programsProgramAddress() throws -> Address {
    try address("11111111111111111111111111111111")
}

private func programsOtherProgramAddress() throws -> Address {
    try address("Sysvar1111111111111111111111111111111111111")
}
