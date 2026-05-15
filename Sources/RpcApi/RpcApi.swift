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

    public func getEpochInfo(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getEpochInfo", params: compact([config]))
    }

    public func getEpochSchedule() throws -> RpcPlan {
        try plan(methodName: "getEpochSchedule", params: [])
    }

    public func getFeeForMessage(_ message: String, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getFeeForMessage", params: compact([.string(message), config]))
    }

    public func getFirstAvailableBlock() throws -> RpcPlan {
        try plan(methodName: "getFirstAvailableBlock", params: [])
    }

    public func getGenesisHash() throws -> RpcPlan {
        try plan(methodName: "getGenesisHash", params: [])
    }

    public func getHealth() throws -> RpcPlan {
        try plan(methodName: "getHealth", params: [])
    }

    public func getHighestSnapshotSlot() throws -> RpcPlan {
        try plan(methodName: "getHighestSnapshotSlot", params: [])
    }

    public func getIdentity() throws -> RpcPlan {
        try plan(methodName: "getIdentity", params: [])
    }

    public func getInflationGovernor(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getInflationGovernor", params: compact([config]))
    }

    public func getInflationRate() throws -> RpcPlan {
        try plan(methodName: "getInflationRate", params: [])
    }

    public func getInflationReward(_ addresses: [Address], config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getInflationReward", params: compact([addressArray(addresses), config]))
    }

    public func getLargestAccounts(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getLargestAccounts", params: compact([config]))
    }

    public func getLatestBlockhash(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getLatestBlockhash", params: compact([config]))
    }

    public func getLeaderSchedule() throws -> RpcPlan {
        try plan(methodName: "getLeaderSchedule", params: [])
    }

    public func getLeaderSchedule(_ slot: Slot?, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getLeaderSchedule", params: compact([slot.map { .bigint(String($0)) } ?? .null, config]))
    }

    public func getMaxRetransmitSlot() throws -> RpcPlan {
        try plan(methodName: "getMaxRetransmitSlot", params: [])
    }

    public func getMaxShredInsertSlot() throws -> RpcPlan {
        try plan(methodName: "getMaxShredInsertSlot", params: [])
    }

    public func getMinimumBalanceForRentExemption(_ size: UInt64, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getMinimumBalanceForRentExemption", params: compact([.bigint(String(size)), config]))
    }

    public func getMultipleAccounts(_ addresses: [Address], config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getMultipleAccounts", params: compact([addressArray(addresses), config]))
    }

    public func getProgramAccounts(_ program: Address, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getProgramAccounts", params: compact([.string(program.rawValue), config]))
    }

    public func getRecentPerformanceSamples(limit: Int? = nil) throws -> RpcPlan {
        try plan(methodName: "getRecentPerformanceSamples", params: compact([limit.map { .bigint(String($0)) }]))
    }

    public func getRecentPrioritizationFees(_ addresses: [Address]? = nil) throws -> RpcPlan {
        try plan(methodName: "getRecentPrioritizationFees", params: compact([addresses.map(addressArray)]))
    }

    public func getSignatureStatuses(_ signatures: [String], config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getSignatureStatuses", params: compact([stringArray(signatures), config]))
    }

    public func getSignaturesForAddress(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getSignaturesForAddress", params: compact([.string(address.rawValue), config]))
    }

    public func getSlot(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getSlot", params: compact([config]))
    }

    public func getSlotLeader(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getSlotLeader", params: compact([config]))
    }

    public func getSlotLeaders(_ startSlotInclusive: Slot, limit: Int) throws -> RpcPlan {
        try plan(methodName: "getSlotLeaders", params: [.bigint(String(startSlotInclusive)), .bigint(String(limit))])
    }

    public func getStakeMinimumDelegation(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getStakeMinimumDelegation", params: compact([config]))
    }

    public func getSupply(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getSupply", params: compact([config]))
    }

    public func getTokenAccountBalance(_ address: Address, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getTokenAccountBalance", params: compact([.string(address.rawValue), config]))
    }

    public func getTokenAccountsByDelegate(_ delegate: Address, filter: RpcJsonValue, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getTokenAccountsByDelegate", params: compact([.string(delegate.rawValue), filter, config]))
    }

    public func getTokenAccountsByOwner(_ owner: Address, filter: RpcJsonValue, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getTokenAccountsByOwner", params: compact([.string(owner.rawValue), filter, config]))
    }

    public func getTokenLargestAccounts(_ tokenMint: Address, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getTokenLargestAccounts", params: compact([.string(tokenMint.rawValue), config]))
    }

    public func getTokenSupply(_ tokenMint: Address, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getTokenSupply", params: compact([.string(tokenMint.rawValue), config]))
    }

    public func getTransaction(_ signature: String, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getTransaction", params: compact([.string(signature), config]))
    }

    public func getTransactionCount(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getTransactionCount", params: compact([config]))
    }

    public func getVersion() throws -> RpcPlan {
        try plan(methodName: "getVersion", params: [])
    }

    public func getVoteAccounts(config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "getVoteAccounts", params: compact([config]))
    }

    public func isBlockhashValid(_ blockhash: Blockhash, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "isBlockhashValid", params: compact([.string(blockhash), config]))
    }

    public func minimumLedgerSlot() throws -> RpcPlan {
        try plan(methodName: "minimumLedgerSlot", params: [])
    }

    public func requestAirdrop(_ recipientAccount: Address, lamports: Lamports, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "requestAirdrop", params: compact([.string(recipientAccount.rawValue), .bigint(String(lamports)), config]))
    }

    public func sendTransaction(_ base64EncodedWireTransaction: String, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "sendTransaction", params: compact([.string(base64EncodedWireTransaction), config]))
    }

    public func simulateTransaction(_ wireTransaction: String, config: RpcJsonValue? = nil) throws -> RpcPlan {
        try plan(methodName: "simulateTransaction", params: compact([.string(wireTransaction), config]))
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
        "getBlock": getBlockKeyPaths,
        "getClusterNodes": [
            [.wildcard, .key("featureSet")],
            [.wildcard, .key("shredVersion")],
        ],
        "getInflationGovernor": [
            [.key("initial")],
            [.key("foundation")],
            [.key("foundationTerm")],
            [.key("taper")],
            [.key("terminal")],
        ],
        "getInflationRate": [
            [.key("foundation")],
            [.key("total")],
            [.key("validator")],
        ],
        "getInflationReward": [
            [.wildcard, .key("commission")],
        ],
        "getMultipleAccounts": prefixed([.key("value"), .wildcard], jsonParsedAccountsConfigs),
        "getProgramAccounts": prefixed([.key("value"), .wildcard, .key("account")], jsonParsedAccountsConfigs)
            + prefixed([.wildcard, .key("account")], jsonParsedAccountsConfigs),
        "getRecentPerformanceSamples": [
            [.wildcard, .key("samplePeriodSecs")],
        ],
        "getTokenAccountBalance": [
            [.key("value"), .key("decimals")],
            [.key("value"), .key("uiAmount")],
        ],
        "getTokenAccountsByDelegate": prefixed([.key("value"), .wildcard, .key("account")], jsonParsedTokenAccountsConfigs),
        "getTokenAccountsByOwner": prefixed([.key("value"), .wildcard, .key("account")], jsonParsedTokenAccountsConfigs),
        "getTokenLargestAccounts": [
            [.key("value"), .wildcard, .key("decimals")],
            [.key("value"), .wildcard, .key("uiAmount")],
        ],
        "getTokenSupply": [
            [.key("value"), .key("decimals")],
            [.key("value"), .key("uiAmount")],
        ],
        "getTransaction": getTransactionKeyPaths,
        "getVersion": [
            [.key("feature-set")],
        ],
        "getVoteAccounts": [
            [.key("current"), .wildcard, .key("commission")],
            [.key("delinquent"), .wildcard, .key("commission")],
        ],
        "simulateTransaction": simulateTransactionKeyPaths,
    ]
}

private func compact(_ params: [RpcJsonValue?]) -> [RpcJsonValue] {
    var output = params
    while let last = output.last, last == nil {
        output.removeLast()
    }
    return output.map { $0 ?? .null }
}

private func addressArray(_ addresses: [Address]) -> RpcJsonValue {
    .array(addresses.map { .string($0.rawValue) })
}

private func stringArray(_ values: [String]) -> RpcJsonValue {
    .array(values.map { .string($0) })
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

private let getTransactionKeyPaths: [RpcKeyPath] = [
    [.key("meta"), .key("preTokenBalances"), .wildcard, .key("accountIndex")],
    [.key("meta"), .key("preTokenBalances"), .wildcard, .key("uiTokenAmount"), .key("decimals")],
    [.key("meta"), .key("postTokenBalances"), .wildcard, .key("accountIndex")],
    [.key("meta"), .key("postTokenBalances"), .wildcard, .key("uiTokenAmount"), .key("decimals")],
    [.key("meta"), .key("rewards"), .wildcard, .key("commission")],
]
    + prefixed([.key("meta"), .key("innerInstructions"), .wildcard], innerInstructionsConfigs)
    + prefixed([.key("transaction"), .key("message")], messageConfig)

private let simulateTransactionKeyPaths: [RpcKeyPath] = [
    [.key("value"), .key("loadedAccountsDataSize")],
]
    + prefixed([.key("value"), .key("accounts"), .wildcard], jsonParsedAccountsConfigs)
    + prefixed([.key("value"), .key("innerInstructions"), .wildcard], innerInstructionsConfigs)

private func prefixed(_ prefix: RpcKeyPath, _ keyPaths: [RpcKeyPath]) -> [RpcKeyPath] {
    keyPaths.map { prefix + $0 }
}
