public import Addresses
public import Keys
public import Promises
public import RpcTypes

public protocol ClientWithAirdrop: Sendable {
    func airdrop(
        address: Address,
        amount: Lamports,
        abortSignal: AbortSignal?
    ) async throws -> Signature?
}

public extension ClientWithAirdrop {
    func airdrop(address: Address, amount: Lamports) async throws -> Signature? {
        try await airdrop(address: address, amount: amount, abortSignal: nil)
    }
}
