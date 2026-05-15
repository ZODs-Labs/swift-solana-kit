public import RpcTypes

public struct GetMinimumBalanceConfig: Sendable, Equatable, Hashable {
    public let withoutHeader: Bool

    public init(withoutHeader: Bool = false) {
        self.withoutHeader = withoutHeader
    }
}

public protocol ClientWithGetMinimumBalance: Sendable {
    func getMinimumBalance(space: Int, config: GetMinimumBalanceConfig?) async throws -> Lamports
}

public extension ClientWithGetMinimumBalance {
    func getMinimumBalance(space: Int) async throws -> Lamports {
        try await getMinimumBalance(space: space, config: nil)
    }
}
