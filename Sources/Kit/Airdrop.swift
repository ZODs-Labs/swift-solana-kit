public import Addresses
public import Keys
public import Promises
public import Rpc
public import RpcSubscriptionsSpec
public import RpcTypes
import SolanaErrors
import TransactionConfirmation

public struct AirdropFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public let rpcSubscriptions: RpcSubscriptions

    public init(rpc: SolanaRpc, rpcSubscriptions: RpcSubscriptions) {
        self.rpc = rpc
        self.rpcSubscriptions = rpcSubscriptions
    }
}

public struct AirdropConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment
    public let lamports: Lamports
    public let recipientAddress: Address

    public init(abortSignal: AbortSignal? = nil, commitment: Commitment, lamports: Lamports, recipientAddress: Address) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.lamports = lamports
        self.recipientAddress = recipientAddress
    }
}

public typealias AirdropFunction = @Sendable (AirdropConfig) async throws -> Signature

public func airdropFactory(_ config: AirdropFactoryConfig) -> AirdropFunction {
    let getRecentSignatureConfirmationPromise = createRecentSignatureConfirmationPromiseFactory(
        kitRecentSignatureConfirmationSources(rpc: config.rpc, rpcSubscriptions: config.rpcSubscriptions)
    )
    return { airdropConfig in
        let requestConfig = kitRpcConfig([("commitment", .string(airdropConfig.commitment.rawValue))])
        let response = try await config.rpc
            .request(
                "requestAirdrop",
                params: [
                    .string(airdropConfig.recipientAddress.rawValue),
                    .bigint(String(airdropConfig.lamports)),
                    requestConfig,
                ]
            )
            .send(abortSignal: airdropConfig.abortSignal)
        guard let signatureString = kitString(response) else {
            throw SolanaError(.malformedJSONRPCError)
        }
        let signature = Signature(rawValue: signatureString)
        try await waitForRecentTransactionConfirmationUntilTimeout(
            TimeBasedTransactionConfirmationConfig(
                abortSignal: airdropConfig.abortSignal,
                commitment: airdropConfig.commitment,
                getRecentSignatureConfirmationPromise: getRecentSignatureConfirmationPromise,
                getTimeoutPromise: getTimeoutPromise,
                signature: signature
            )
        )
        return signature
    }
}
