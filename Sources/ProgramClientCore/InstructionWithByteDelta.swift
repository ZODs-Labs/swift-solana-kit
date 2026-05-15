public struct InstructionWithByteDelta: Sendable, Equatable, Hashable {
    public let byteDelta: Int

    public init(byteDelta: Int) {
        self.byteDelta = byteDelta
    }
}
