public import Addresses
public import Keys
public import RpcSpecTypes
public import RpcSubscriptionsSpec
public import RpcTransformers
import Subscribable

public typealias SolanaRpcSubscriptionsApi = RpcSubscriptionsApi
public typealias SolanaRpcSubscriptionsApiUnstable = RpcSubscriptionsApi

public enum SolanaRpcSubscriptionNotificationName: String, Sendable, CaseIterable {
    case accountNotifications
    case blockNotifications
    case logsNotifications
    case programNotifications
    case rootNotifications
    case signatureNotifications
    case slotNotifications
    case slotsUpdatesNotifications
    case voteNotifications
}

public func createSolanaRpcSubscriptionsApi(_ config: RequestTransformerConfig) -> RpcSubscriptionsApi {
    createSolanaRpcSubscriptionsApiInternal(config)
}

public func createSolanaRpcSubscriptionsApi() -> RpcSubscriptionsApi {
    createSolanaRpcSubscriptionsApi(RequestTransformerConfig())
}

public func createSolanaRpcSubscriptionsApi_UNSTABLE(_ config: RequestTransformerConfig) -> RpcSubscriptionsApi {
    createSolanaRpcSubscriptionsApiInternal(config)
}

public func createSolanaRpcSubscriptionsApi_UNSTABLE() -> RpcSubscriptionsApi {
    createSolanaRpcSubscriptionsApi_UNSTABLE(RequestTransformerConfig())
}

public func subscribeMethodName(for notificationName: String) -> String {
    notificationName.hasSuffix("Notifications")
        ? "\(notificationName.dropLast("Notifications".count))Subscribe"
        : notificationName
}

public func unsubscribeMethodName(for notificationName: String) -> String {
    notificationName.hasSuffix("Notifications")
        ? "\(notificationName.dropLast("Notifications".count))Unsubscribe"
        : notificationName
}

public extension RpcSubscriptionsApi {
    func accountNotifications(address: Address, config: RpcJsonValue? = nil) throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "accountNotifications", params: compactParams([.string(address.rawValue), config]), as: RpcJsonValue.self)
    }

    func blockNotifications(filter: RpcJsonValue, config: RpcJsonValue? = nil) throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "blockNotifications", params: compactParams([filter, config]), as: RpcJsonValue.self)
    }

    func logsNotifications(filter: RpcJsonValue, config: RpcJsonValue? = nil) throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "logsNotifications", params: compactParams([filter, config]), as: RpcJsonValue.self)
    }

    func programNotifications(programId: Address, config: RpcJsonValue? = nil) throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "programNotifications", params: compactParams([.string(programId.rawValue), config]), as: RpcJsonValue.self)
    }

    func rootNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "rootNotifications", params: [], as: RpcJsonValue.self)
    }

    func signatureNotifications(signature: Signature, config: RpcJsonValue? = nil) throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "signatureNotifications", params: compactParams([.string(signature.rawValue), config]), as: RpcJsonValue.self)
    }

    func slotNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "slotNotifications", params: [], as: RpcJsonValue.self)
    }

    func slotsUpdatesNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "slotsUpdatesNotifications", params: [], as: RpcJsonValue.self)
    }

    func voteNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue> {
        try plan(methodName: "voteNotifications", params: [], as: RpcJsonValue.self)
    }
}

private func createSolanaRpcSubscriptionsApiInternal(_ config: RequestTransformerConfig) -> RpcSubscriptionsApi {
    let requestTransformer = getDefaultRequestTransformerForSolanaRpc(config)
    let responseTransformer = getDefaultResponseTransformerForSolanaRpcSubscriptions(
        ResponseTransformerConfig(allowedNumericKeyPaths: allowedNumericKeyPaths())
    )
    return createRpcSubscriptionsApi(
        RpcSubscriptionsApiConfig(
            planExecutor: { execution in
                try await executeRpcPubSubSubscriptionPlan(
                    channel: execution.channel,
                    responseTransformer: responseTransformer,
                    signal: execution.signal,
                    subscribeRequest: RpcRequest(
                        methodName: subscribeMethodName(for: execution.request.methodName),
                        params: execution.request.params
                    ),
                    unsubscribeMethodName: unsubscribeMethodName(for: execution.request.methodName),
                    as: RpcJsonValue.self
                )
            },
            requestTransformer: requestTransformer
        )
    )
}

private func compactParams(_ params: [RpcJsonValue?]) -> [RpcJsonValue] {
    params.compactMap { $0 }
}

private func allowedNumericKeyPaths() -> [String: [RpcKeyPath]] {
    [
        "accountNotifications": jsonParsedAccountConfigKeyPaths(prefix: [.key("value")]),
        "blockNotifications": [
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("preTokenBalances"), .wildcard, .key("accountIndex")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("preTokenBalances"), .wildcard, .key("uiTokenAmount"), .key("decimals")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("postTokenBalances"), .wildcard, .key("accountIndex")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("postTokenBalances"), .wildcard, .key("uiTokenAmount"), .key("decimals")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("rewards"), .wildcard, .key("commission")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("innerInstructions"), .wildcard, .key("index")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("innerInstructions"), .wildcard, .key("instructions"), .wildcard, .key("programIdIndex")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("meta"), .key("innerInstructions"), .wildcard, .key("instructions"), .wildcard, .key("accounts"), .wildcard],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("transaction"), .key("message"), .key("addressTableLookups"), .wildcard, .key("writableIndexes"), .wildcard],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("transaction"), .key("message"), .key("addressTableLookups"), .wildcard, .key("readonlyIndexes"), .wildcard],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("transaction"), .key("message"), .key("instructions"), .wildcard, .key("programIdIndex")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("transaction"), .key("message"), .key("instructions"), .wildcard, .key("accounts"), .wildcard],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("transaction"), .key("message"), .key("header"), .key("numReadonlySignedAccounts")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("transaction"), .key("message"), .key("header"), .key("numReadonlyUnsignedAccounts")],
            [.key("value"), .key("block"), .key("transactions"), .wildcard, .key("transaction"), .key("message"), .key("header"), .key("numRequiredSignatures")],
            [.key("value"), .key("block"), .key("rewards"), .wildcard, .key("commission")],
        ],
        "programNotifications":
            jsonParsedAccountConfigKeyPaths(prefix: [.key("value"), .wildcard, .key("account")]) +
            jsonParsedAccountConfigKeyPaths(prefix: [.wildcard, .key("account")]),
    ]
}

private func jsonParsedAccountConfigKeyPaths(prefix: RpcKeyPath) -> [RpcKeyPath] {
    jsonParsedAccountConfigs.map { prefix + $0 }
}

private let jsonParsedAccountConfigs: [RpcKeyPath] = [
    [.key("data"), .key("parsed"), .key("info"), .key("tokenAmount"), .key("decimals")],
    [.key("data"), .key("parsed"), .key("info"), .key("tokenAmount"), .key("uiAmount")],
    [.key("data"), .key("parsed"), .key("info"), .key("rentExemptReserve"), .key("decimals")],
    [.key("data"), .key("parsed"), .key("info"), .key("rentExemptReserve"), .key("uiAmount")],
    [.key("data"), .key("parsed"), .key("info"), .key("delegatedAmount"), .key("decimals")],
    [.key("data"), .key("parsed"), .key("info"), .key("delegatedAmount"), .key("uiAmount")],
    [.key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("olderTransferFee"), .key("transferFeeBasisPoints")],
    [.key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("newerTransferFee"), .key("transferFeeBasisPoints")],
    [.key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("preUpdateAverageRate")],
    [.key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("currentRate")],
    [.key("data"), .key("parsed"), .key("info"), .key("lastExtendedSlotStartIndex")],
    [.key("data"), .key("parsed"), .key("info"), .key("slashPenalty")],
    [.key("data"), .key("parsed"), .key("info"), .key("warmupCooldownRate")],
    [.key("data"), .key("parsed"), .key("info"), .key("decimals")],
    [.key("data"), .key("parsed"), .key("info"), .key("numRequiredSigners")],
    [.key("data"), .key("parsed"), .key("info"), .key("numValidSigners")],
    [.key("data"), .key("parsed"), .key("info"), .key("stake"), .key("delegation"), .key("warmupCooldownRate")],
    [.key("data"), .key("parsed"), .key("info"), .key("exemptionThreshold")],
    [.key("data"), .key("parsed"), .key("info"), .key("burnPercent")],
    [.key("data"), .key("parsed"), .key("info"), .key("commission")],
    [.key("data"), .key("parsed"), .key("info"), .key("votes"), .wildcard, .key("confirmationCount")],
]
