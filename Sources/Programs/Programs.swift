public import Addresses
import SolanaErrors

public struct ProgramErrorInstruction: Sendable, Equatable {
    public let programAddress: Address

    public init(programAddress: Address) {
        self.programAddress = programAddress
    }
}

public struct ProgramInstructionMessage: Sendable, Equatable {
    public let instructions: [ProgramErrorInstruction]

    public init(instructions: [ProgramErrorInstruction]) {
        self.instructions = instructions
    }
}

public func isProgramError(
    _ error: any Error,
    transactionMessage: ProgramInstructionMessage,
    programAddress: Address,
    code expectedCode: Int? = nil
) -> Bool {
    guard let error = error as? SolanaError,
          error.solanaCode == .instructionErrorCustom,
          let instructionIndex = error.context.integerValue(for: "index"),
          instructionIndex >= 0,
          instructionIndex < transactionMessage.instructions.count
    else {
        return false
    }

    let instruction = transactionMessage.instructions[instructionIndex]
    guard instruction.programAddress == programAddress else {
        return false
    }

    guard let expectedCode else {
        return true
    }
    return error.context.integerValue(for: "code") == expectedCode
}

private extension SolanaErrorContext {
    func integerValue(for key: String) -> Int? {
        guard let value = self[key] else {
            return nil
        }
        switch value {
        case let .int(value):
            return value
        case let .uint(value):
            return Int(exactly: value)
        case let .bigint(value), let .string(value):
            return Int(value)
        default:
            return nil
        }
    }
}
