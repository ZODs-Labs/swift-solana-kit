public import Addresses

public struct ProgramErrorInstruction: Sendable, Equatable
public let ProgramErrorInstruction.programAddress: Address
public init ProgramErrorInstruction(programAddress: Address)

public struct ProgramInstructionMessage: Sendable, Equatable
public let ProgramInstructionMessage.instructions: [ProgramErrorInstruction]
public init ProgramInstructionMessage(instructions: [ProgramErrorInstruction])

public func isProgramError(_ error: any Error, transactionMessage: ProgramInstructionMessage, programAddress: Address, code expectedCode: Int? = nil) -> Bool
