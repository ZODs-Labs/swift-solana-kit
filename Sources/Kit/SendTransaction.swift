import Keys
public import Promises
public import Rpc
import RpcSpecTypes
public import RpcSubscriptionsSpec
public import RpcTypes
import SolanaErrors
import TransactionConfirmation
public import Transactions

public struct SendTransactionConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment
    public let maxRetries: UInt64?
    public let minContextSlot: Slot?
    public let preflightCommitment: Commitment?
    public let skipPreflight: Bool?

    public init(
        abortSignal: AbortSignal? = nil,
        commitment: Commitment,
        maxRetries: UInt64? = nil,
        minContextSlot: Slot? = nil,
        preflightCommitment: Commitment? = nil,
        skipPreflight: Bool? = nil
    ) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.maxRetries = maxRetries
        self.minContextSlot = minContextSlot
        self.preflightCommitment = preflightCommitment
        self.skipPreflight = skipPreflight
    }
}

public typealias SendTransactionWithoutConfirmingFunction = @Sendable (Transaction, SendTransactionConfig) async throws -> Void
public typealias SendAndConfirmTransactionFunction = @Sendable (Transaction, SendTransactionConfig) async throws -> Void
public typealias SendAndConfirmDurableNonceTransactionFunction = @Sendable (Transaction, SendTransactionConfig) async throws -> Void

public struct SendTransactionWithoutConfirmingFactoryConfig: Sendable {
    public let rpc: SolanaRpc

    public init(rpc: SolanaRpc) {
        self.rpc = rpc
    }
}

public struct SendAndConfirmTransactionFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public let rpcSubscriptions: RpcSubscriptions

    public init(rpc: SolanaRpc, rpcSubscriptions: RpcSubscriptions) {
        self.rpc = rpc
        self.rpcSubscriptions = rpcSubscriptions
    }
}

public struct SendAndConfirmDurableNonceTransactionFactoryConfig: Sendable {
    public let rpc: SolanaRpc
    public let rpcSubscriptions: RpcSubscriptions

    public init(rpc: SolanaRpc, rpcSubscriptions: RpcSubscriptions) {
        self.rpc = rpc
        self.rpcSubscriptions = rpcSubscriptions
    }
}

public func sendTransactionWithoutConfirmingFactory(
    _ config: SendTransactionWithoutConfirmingFactoryConfig
) -> SendTransactionWithoutConfirmingFunction {
    { transaction, sendConfig in
        _ = try await kitSendTransaction(rpc: config.rpc, transaction: transaction, config: sendConfig)
    }
}

public func sendAndConfirmTransactionFactory(
    _ config: SendAndConfirmTransactionFactoryConfig
) -> SendAndConfirmTransactionFunction {
    let getBlockHeightExceedencePromise = createBlockHeightExceedencePromiseFactory(
        kitBlockHeightExceedenceSources(rpc: config.rpc, rpcSubscriptions: config.rpcSubscriptions)
    )
    let getRecentSignatureConfirmationPromise = createRecentSignatureConfirmationPromiseFactory(
        kitRecentSignatureConfirmationSources(rpc: config.rpc, rpcSubscriptions: config.rpcSubscriptions)
    )
    return { transaction, sendConfig in
        let signature = try await kitSendTransaction(rpc: config.rpc, transaction: transaction, config: sendConfig)
        _ = signature
        try await waitForRecentTransactionConfirmation(
            RecentTransactionConfirmationConfig(
                abortSignal: sendConfig.abortSignal,
                commitment: sendConfig.commitment,
                getBlockHeightExceedencePromise: getBlockHeightExceedencePromise,
                getRecentSignatureConfirmationPromise: getRecentSignatureConfirmationPromise,
                transaction: transaction
            )
        )
    }
}

public func sendAndConfirmDurableNonceTransactionFactory(
    _ config: SendAndConfirmDurableNonceTransactionFactoryConfig
) -> SendAndConfirmDurableNonceTransactionFunction {
    let getNonceInvalidationPromise = createNonceInvalidationPromiseFactory(
        kitNonceInvalidationSources(rpc: config.rpc, rpcSubscriptions: config.rpcSubscriptions)
    )
    let getRecentSignatureConfirmationPromise = createRecentSignatureConfirmationPromiseFactory(
        kitRecentSignatureConfirmationSources(rpc: config.rpc, rpcSubscriptions: config.rpcSubscriptions)
    )
    return { transaction, sendConfig in
        _ = try await kitSendTransaction(rpc: config.rpc, transaction: transaction, config: sendConfig)
        let signature = try getSignatureFromTransaction(transaction)
        let wrappedNoncePromise = kitNonceInvalidationPromiseHandlingRaceCondition(
            signature: signature,
            rpc: config.rpc,
            getNonceInvalidationPromise: getNonceInvalidationPromise
        )
        try await waitForDurableNonceTransactionConfirmation(
            DurableNonceTransactionConfirmationConfig(
                abortSignal: sendConfig.abortSignal,
                commitment: sendConfig.commitment,
                getNonceInvalidationPromise: wrappedNoncePromise,
                getRecentSignatureConfirmationPromise: getRecentSignatureConfirmationPromise,
                transaction: transaction
            )
        )
    }
}

func kitSendTransaction(rpc: SolanaRpc, transaction: Transaction, config: SendTransactionConfig) async throws -> Signature {
    let base64EncodedWireTransaction = try getBase64EncodedWireTransaction(transaction)
    let response = try await rpc
        .request(
            "sendTransaction",
            params: [
                .string(base64EncodedWireTransaction),
                kitSendTransactionConfig(config),
            ]
        )
        .send(abortSignal: config.abortSignal)
    guard let signatureString = kitString(response) else {
        throw SolanaError(.malformedJSONRPCError)
    }
    return Signature(rawValue: signatureString)
}

func kitRecentSignatureConfirmationSources(
    rpc: SolanaRpc,
    rpcSubscriptions: RpcSubscriptions
) -> RecentSignatureConfirmationSources {
    RecentSignatureConfirmationSources(
        getSignatureStatuses: { signatures, abortSignal in
            let response = try await rpc
                .request(
                    "getSignatureStatuses",
                    params: [.array(signatures.map { .string($0.rawValue) })]
                )
                .send(abortSignal: abortSignal)
            return kitSignatureStatuses(from: response)
        },
        signatureNotifications: { signature, commitment, abortSignal in
            let config = kitRpcConfig([("commitment", .string(commitment.rawValue))])
            let sequence = try await rpcSubscriptions
                .request(
                    "signatureNotifications",
                    params: [.string(signature.rawValue), config],
                    as: RpcJsonValue.self
                )
                .subscribe(RpcSubscribeOptions(abortSignal: abortSignal))
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await value in sequence {
                            if let notification = kitSignatureNotification(from: value) {
                                continuation.yield(notification)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )
}

func kitBlockHeightExceedenceSources(
    rpc: SolanaRpc,
    rpcSubscriptions: RpcSubscriptions
) -> BlockHeightExceedenceSources {
    BlockHeightExceedenceSources(
        getEpochInfo: { commitment, abortSignal in
            let config = commitment.map { kitRpcConfig([("commitment", .string($0.rawValue))]) }
            let response = try await rpc
                .request("getEpochInfo", params: config.map { [$0] } ?? [])
                .send(abortSignal: abortSignal)
            return try kitEpochInfo(from: response)
        },
        slotNotifications: { abortSignal in
            let sequence = try await rpcSubscriptions
                .request("slotNotifications", as: RpcJsonValue.self)
                .subscribe(RpcSubscribeOptions(abortSignal: abortSignal))
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await value in sequence {
                            if let notification = kitSlotNotification(from: value) {
                                continuation.yield(notification)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )
}

func kitNonceInvalidationSources(
    rpc: SolanaRpc,
    rpcSubscriptions: RpcSubscriptions
) -> NonceInvalidationSources {
    NonceInvalidationSources(
        getAccountInfo: { address, commitment, abortSignal in
            let config = kitRpcConfig([
                ("commitment", .string(commitment.rawValue)),
                ("dataSlice", kitRpcConfig([
                    ("length", .bigint("32")),
                    ("offset", .bigint(String(kitNonceValueOffset))),
                ])),
                ("encoding", .string("base58")),
            ])
            let response = try await rpc
                .request("getAccountInfo", params: [.string(address.rawValue), config])
                .send(abortSignal: abortSignal)
            return try kitNonceAccountInfo(from: response)
        },
        accountNotifications: { address, commitment, abortSignal in
            let config = kitRpcConfig([
                ("commitment", .string(commitment.rawValue)),
                ("encoding", .string("base64")),
            ])
            let sequence = try await rpcSubscriptions
                .request(
                    "accountNotifications",
                    params: [.string(address.rawValue), config],
                    as: RpcJsonValue.self
                )
                .subscribe(RpcSubscribeOptions(abortSignal: abortSignal))
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await value in sequence {
                            if let notification = try kitAccountNotification(from: value) {
                                continuation.yield(notification)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )
}

let kitNonceValueOffset = 4 + 4 + 32

func kitNonceInvalidationPromiseHandlingRaceCondition(
    signature: Signature,
    rpc: SolanaRpc,
    getNonceInvalidationPromise: @escaping GetNonceInvalidationPromise
) -> GetNonceInvalidationPromise {
    { config in
        do {
            try await getNonceInvalidationPromise(config)
        } catch {
            guard let solanaError = error as? SolanaError,
                  solanaError.solanaCode == .invalidNonce
            else {
                throw error
            }
            let response = try? await rpc
                .request(
                    "getSignatureStatuses",
                    params: [.array([.string(signature.rawValue)])]
                )
                .send(abortSignal: config.abortSignal)
            guard let status = response.map(kitSignatureStatuses(from:))?.first ?? nil else {
                throw error
            }
            guard let confirmationStatus = status.confirmationStatus,
                  commitmentComparator(confirmationStatus, config.commitment) >= 0
            else {
                try await kitNeverResolvingPromise(abortSignal: config.abortSignal)
                return
            }
            if let transactionError = status.err {
                throw kitSolanaError(from: transactionError)
            }
        }
    }
}

func kitNeverResolvingPromise(abortSignal: AbortSignal) async throws {
    while true {
        if let reason = abortSignal.abortReason() {
            throw reason
        }
        try await Task.sleep(nanoseconds: 60_000_000_000)
    }
}
