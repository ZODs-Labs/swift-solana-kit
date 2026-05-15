import Addresses
import SolanaErrors
@testable import Programs
import XCTest

final class ProgramsTests: XCTestCase {
    func test_isProgramError_identifiesCustomProgramError() throws {
        let programAddress = try address("11111111111111111111111111111111")
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: programAddress),
        ])
        let error = SolanaError(.instructionErrorCustom, context: [
            "code": .int(42),
            "index": .int(0),
        ])

        XCTAssertTrue(isProgramError(error, transactionMessage: message, programAddress: programAddress))
        XCTAssertTrue(isProgramError(error, transactionMessage: message, programAddress: programAddress, code: 42))
    }

    func test_isProgramError_rejectsNonMatchingProgramAddress() throws {
        let programAddress = try address("11111111111111111111111111111111")
        let otherProgramAddress = try address("Sysvar1111111111111111111111111111111111111")
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: programAddress),
        ])
        let error = SolanaError(.instructionErrorCustom, context: [
            "code": .int(42),
            "index": .int(0),
        ])

        XCTAssertFalse(isProgramError(error, transactionMessage: message, programAddress: otherProgramAddress))
    }

    func test_isProgramError_rejectsMissingInstruction() throws {
        let programAddress = try address("11111111111111111111111111111111")
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: programAddress),
        ])
        let error = SolanaError(.instructionErrorCustom, context: [
            "code": .int(42),
            "index": .int(999),
        ])

        XCTAssertFalse(isProgramError(error, transactionMessage: message, programAddress: programAddress))
    }

    func test_isProgramError_rejectsNonMatchingCode() throws {
        let programAddress = try address("11111111111111111111111111111111")
        let message = ProgramInstructionMessage(instructions: [
            ProgramErrorInstruction(programAddress: programAddress),
        ])
        let error = SolanaError(.instructionErrorCustom, context: [
            "code": .int(42),
            "index": .int(0),
        ])

        XCTAssertFalse(isProgramError(error, transactionMessage: message, programAddress: programAddress, code: 43))
    }
}
