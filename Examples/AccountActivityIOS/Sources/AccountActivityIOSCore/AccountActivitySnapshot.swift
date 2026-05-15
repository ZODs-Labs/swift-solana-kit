public import Kit

public struct AccountActivitySnapshot: Sendable, Equatable, Hashable {
    public let address: Address
    public let endpoint: ActivityEndpoint
    public let lamports: Lamports
    public let slot: Slot
    public let solText: String
    public let signatures: [ActivitySignatureSummary]

    public init(
        address: Address,
        endpoint: ActivityEndpoint,
        lamports: Lamports,
        slot: Slot,
        solText: String,
        signatures: [ActivitySignatureSummary]
    ) {
        self.address = address
        self.endpoint = endpoint
        self.lamports = lamports
        self.slot = slot
        self.solText = solText
        self.signatures = signatures
    }
}
