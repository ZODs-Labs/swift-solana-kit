public import Promises
public import Rpc
import RpcSpecTypes
public import RpcTypes
import SolanaErrors
public import TransactionMessages
import Transactions

let kitProvisoryComputeUnitLimit = 0
let kitMaximumComputeUnitLimit = 1_400_000

public struct EstimateComputeUnitLimitFactoryConfig: Sendable {
    public let rpc: SolanaRpc

    public init(rpc: SolanaRpc) {
        self.rpc = rpc
    }
}

public struct EstimateComputeUnitLimitConfig: Sendable {
    public let abortSignal: AbortSignal?
    public let commitment: Commitment?
    public let minContextSlot: Slot?

    public init(abortSignal: AbortSignal? = nil, commitment: Commitment? = nil, minContextSlot: Slot? = nil) {
        self.abortSignal = abortSignal
        self.commitment = commitment
        self.minContextSlot = minContextSlot
    }
}

public typealias EstimateComputeUnitLimitFunction = @Sendable (TransactionMessage, EstimateComputeUnitLimitConfig?) async throws -> UInt32
public typealias EstimateAndSetComputeUnitLimitFunction = @Sendable (TransactionMessage, EstimateComputeUnitLimitConfig?) async throws -> TransactionMessage

public func estimateComputeUnitLimitFactory(
    _ config: EstimateComputeUnitLimitFactoryConfig
) -> EstimateComputeUnitLimitFunction {
    { transactionMessage, estimateConfig in
        let estimateConfig = estimateConfig ?? EstimateComputeUnitLimitConfig()
        let replaceRecentBlockhash = !isTransactionMessageWithDurableNonceLifetime(transactionMessage)
        let message = try setTransactionMessageComputeUnitLimit(kitMaximumComputeUnitLimit, transactionMessage)
        let transaction = try compileTransaction(message)
        let wireTransactionBytes = try getBase64EncodedWireTransaction(transaction)
        do {
            let response = try await config.rpc
                .request(
                    "simulateTransaction",
                    params: [
                        .string(wireTransactionBytes),
                        kitRpcConfig([
                            ("commitment", estimateConfig.commitment.map { .string($0.rawValue) }),
                            ("encoding", .string("base64")),
                            ("minContextSlot", estimateConfig.minContextSlot.map { .bigint(String($0)) }),
                            ("replaceRecentBlockhash", .bool(replaceRecentBlockhash)),
                            ("sigVerify", .bool(false)),
                        ]),
                    ]
                )
                .send(abortSignal: estimateConfig.abortSignal)
            return try kitEstimatedComputeUnitLimit(from: response)
        } catch let solanaError as SolanaError
            where solanaError.solanaCode == .transactionFailedWhenSimulatingToEstimateComputeLimit {
            throw solanaError
        } catch {
            let cause: SolanaErrorContextValue
            if let solanaError = error as? SolanaError {
                cause = kitSolanaErrorContextValue(solanaError)
            } else {
                cause = .string(String(describing: error))
            }
            throw SolanaError(
                .transactionFailedToEstimateComputeLimit,
                context: ["cause": cause]
            )
        }
    }
}

public func estimateAndSetComputeUnitLimitFactory(
    _ estimateComputeUnitLimit: @escaping EstimateComputeUnitLimitFunction
) -> EstimateAndSetComputeUnitLimitFunction {
    { transactionMessage, config in
        let existingLimit = try getTransactionMessageComputeUnitLimit(transactionMessage)
        if let existingLimit, existingLimit != kitProvisoryComputeUnitLimit, existingLimit != kitMaximumComputeUnitLimit {
            return transactionMessage
        }
        let estimatedUnits = try await estimateComputeUnitLimit(transactionMessage, config)
        return try setTransactionMessageComputeUnitLimit(Int(estimatedUnits), transactionMessage)
    }
}

public func fillTransactionMessageProvisoryComputeUnitLimit(
    _ transactionMessage: TransactionMessage
) throws -> TransactionMessage {
    if try getTransactionMessageComputeUnitLimit(transactionMessage) != nil {
        return transactionMessage
    }
    return try setTransactionMessageComputeUnitLimit(kitProvisoryComputeUnitLimit, transactionMessage)
}

func kitEstimatedComputeUnitLimit(from response: RpcJsonValue) throws -> UInt32 {
    let value = response.value(for: "value") ?? response
    guard let unitsConsumedValue = value.value(for: "unitsConsumed"),
          let unitsConsumed = kitUInt64(unitsConsumedValue)
    else {
        throw SolanaError(.transactionFailedToEstimateComputeLimit)
    }
    if let errorValue = value.value(for: "err"),
       let transactionError = kitRpcTransactionError(errorValue) {
        throw SolanaError(
            .transactionFailedWhenSimulatingToEstimateComputeLimit,
            context: kitSimulationErrorContext(from: value, transactionError: transactionError)
        )
    }
    return unitsConsumed > UInt64(UInt32.max) ? UInt32.max : UInt32(unitsConsumed)
}
