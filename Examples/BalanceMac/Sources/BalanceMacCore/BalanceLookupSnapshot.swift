public import Kit

public struct BalanceLookupSnapshot: Sendable, Equatable, Hashable {
    public let address: Address
    public let endpoint: SolanaEndpoint
    public let lamports: Lamports
    public let slot: Slot
    public let solText: String

    public init(address: Address, endpoint: SolanaEndpoint, lamports: Lamports, slot: Slot, solText: String) {
        self.address = address
        self.endpoint = endpoint
        self.lamports = lamports
        self.slot = slot
        self.solText = solText
    }
}
