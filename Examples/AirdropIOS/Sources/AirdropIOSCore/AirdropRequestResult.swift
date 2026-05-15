public import Kit

public struct AirdropRequestResult: Sendable, Equatable, Hashable {
    public let address: Address
    public let endpoint: AirdropEndpoint
    public let requestedLamports: Lamports
    public let requestedSolText: String
    public let signature: Signature
    public let balanceAfterLamports: Lamports?
    public let balanceSlot: Slot?

    public init(
        address: Address,
        endpoint: AirdropEndpoint,
        requestedLamports: Lamports,
        requestedSolText: String,
        signature: Signature,
        balanceAfterLamports: Lamports?,
        balanceSlot: Slot?
    ) {
        self.address = address
        self.endpoint = endpoint
        self.requestedLamports = requestedLamports
        self.requestedSolText = requestedSolText
        self.signature = signature
        self.balanceAfterLamports = balanceAfterLamports
        self.balanceSlot = balanceSlot
    }
}
