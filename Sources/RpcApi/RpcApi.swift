public import Addresses
public import RpcSpec
public import RpcSpecTypes
public import RpcTransformers
public import RpcTypes

public struct SolanaRpcApi: Sendable {
    private let api: JsonRpcApi

    public init(api: JsonRpcApi) {
        self.api = api
    }

    public func plan(methodName: String, params: [RpcJsonValue]) throws -> RpcPlan {
        try api.plan(methodName: methodName, params: params)
    }

    public func getAccountInfo(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getAccountInfo", params: compact([.string(address.rawValue), config]))
    }

    public func getBalance(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getBalance", params: compact([.string(address.rawValue), config]))
    }

    public func getBlock(_ slot: Slot, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getBlock", params: compact([.bigint(String(slot)), config]))
    }

    public func getBlockCommitment(_ slot: Slot) throws -> RpcPlan {
        try plan(methodName: "getBlockCommitment", params: [.bigint(String(slot))])
    }

    public func getBlockHeight(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getBlockHeight", params: compact([config]))
    }

    public func getBlockProduction(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getBlockProduction", params: compact([config]))
    }

    public func getBlockTime(_ blockNumber: Slot) throws -> RpcPlan {
        try plan(methodName: "getBlockTime", params: [.bigint(String(blockNumber))])
    }

    public func getBlocks(
        _ startSlotInclusive: Slot,
        endSlotInclusive: Slot? = nil,
        config: RpcJsonValue? = nil
    ) throws -> RpcPlan {
        var params: [RpcJsonValue?] = [.bigint(String(startSlotInclusive))]
        params.append(endSlotInclusive.map { .bigint(String($0)) })
        params.append(config)
        return try plan(methodName: "getBlocks", params: compact(params))
    }

    public func getBlocksWithLimit(_ startSlotInclusive: Slot, limit: Int, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getBlocksWithLimit", params: compact([.bigint(String(startSlotInclusive)), .bigint(String(limit)), config]))
    }

    public func getClusterNodes() throws -> RpcPlan {
        try plan(methodName: "getClusterNodes", params: [])
    }
}

public typealias SolanaRpcApiDevnet = SolanaRpcApi
public typealias SolanaRpcApiTestnet = SolanaRpcApi
public typealias SolanaRpcApiMainnet = SolanaRpcApi

public func createSolanaRpcApi(_ config: RequestTransformerConfig = RequestTransformerConfig()) -> SolanaRpcApi {
    let api = createJsonRpcApi(
        config: RpcApiConfig(
            requestTransformer: getDefaultRequestTransformerForSolanaRpc(config),
            responseTransformer: getDefaultResponseTransformerForSolanaRpc(
                ResponseTransformerConfig(allowedNumericKeyPaths: getAllowedNumericKeypathsForSolanaRpcApi())
            )
        )
    )
    return SolanaRpcApi(api: api)
}

public func getAllowedNumericKeypathsForSolanaRpcApi() -> [String: [RpcKeyPath]] {
    var getBlockKeyPaths: [RpcKeyPath] = [
        [.key("transactions"), .wildcard, .key("meta"), .key("preTokenBalances"), .wildcard, .key("accountIndex")],
        [
            .key("transactions"),
            .wildcard,
            .key("meta"),
            .key("preTokenBalances"),
            .wildcard,
            .key("uiTokenAmount"),
            .key("decimals"),
        ],
        [.key("transactions"), .wildcard, .key("meta"), .key("postTokenBalances"), .wildcard, .key("accountIndex")],
        [
            .key("transactions"),
            .wildcard,
            .key("meta"),
            .key("postTokenBalances"),
            .wildcard,
            .key("uiTokenAmount"),
            .key("decimals"),
        ],
        [.key("transactions"), .wildcard, .key("meta"), .key("rewards"), .wildcard, .key("commission")],
    ]
    getBlockKeyPaths.append(contentsOf: prefixed(
        [.key("transactions"), .wildcard, .key("meta"), .key("innerInstructions"), .wildcard],
        innerInstructionsConfigs
    ))
    getBlockKeyPaths.append(contentsOf: prefixed(
        [.key("transactions"), .wildcard, .key("transaction"), .key("message")],
        messageConfig
    ))
    getBlockKeyPaths.append([.key("rewards"), .wildcard, .key("commission")])
    return [
        "getAccountInfo": prefixed([.key("value")], jsonParsedAccountsConfigs),
        "getClusterNodes": [
            [.wildcard, .key("featureSet")],
            [.wildcard, .key("shredVersion")],
        ],
        "getBlock": getBlockKeyPaths,
    ]
}

private func compact(_ params: [RpcJsonValue?]) -> [RpcJsonValue] {
    var output = params
    while let last = output.last, last == nil {
        output.removeLast()
    }
    return output.map { $0 ?? .null }
}

private let jsonParsedTokenAccountsConfigs: [RpcKeyPath] = [
    [.key("data"), .key("parsed"), .key("info"), .key("tokenAmount"), .key("decimals")],
    [.key("data"), .key("parsed"), .key("info"), .key("tokenAmount"), .key("uiAmount")],
    [.key("data"), .key("parsed"), .key("info"), .key("rentExemptReserve"), .key("decimals")],
    [.key("data"), .key("parsed"), .key("info"), .key("rentExemptReserve"), .key("uiAmount")],
    [.key("data"), .key("parsed"), .key("info"), .key("delegatedAmount"), .key("decimals")],
    [.key("data"), .key("parsed"), .key("info"), .key("delegatedAmount"), .key("uiAmount")],
    [
        .key("data"),
        .key("parsed"),
        .key("info"),
        .key("extensions"),
        .wildcard,
        .key("state"),
        .key("olderTransferFee"),
        .key("transferFeeBasisPoints"),
    ],
    [
        .key("data"),
        .key("parsed"),
        .key("info"),
        .key("extensions"),
        .wildcard,
        .key("state"),
        .key("newerTransferFee"),
        .key("transferFeeBasisPoints"),
    ],
    [.key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("preUpdateAverageRate")],
    [.key("data"), .key("parsed"), .key("info"), .key("extensions"), .wildcard, .key("state"), .key("currentRate")],
]

private let jsonParsedAccountsConfigs: [RpcKeyPath] = jsonParsedTokenAccountsConfigs + [
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

private let innerInstructionsConfigs: [RpcKeyPath] = [
    [.key("index")],
    [.key("instructions"), .wildcard, .key("accounts"), .wildcard],
    [.key("instructions"), .wildcard, .key("programIdIndex")],
    [.key("instructions"), .wildcard, .key("stackHeight")],
]

private let messageConfig: [RpcKeyPath] = [
    [.key("addressTableLookups"), .wildcard, .key("writableIndexes"), .wildcard],
    [.key("addressTableLookups"), .wildcard, .key("readonlyIndexes"), .wildcard],
    [.key("header"), .key("numReadonlySignedAccounts")],
    [.key("header"), .key("numReadonlyUnsignedAccounts")],
    [.key("header"), .key("numRequiredSignatures")],
    [.key("instructions"), .wildcard, .key("accounts"), .wildcard],
    [.key("instructions"), .wildcard, .key("programIdIndex")],
    [.key("instructions"), .wildcard, .key("stackHeight")],
]

private func prefixed(_ prefix: RpcKeyPath, _ keyPaths: [RpcKeyPath]) -> [RpcKeyPath] {
    keyPaths.map { prefix + $0 }
}
