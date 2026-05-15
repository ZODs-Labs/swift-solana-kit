public struct RpcGraphqlExecutionResult: Sendable, Equatable {
    public var data: [String: RpcGraphqlArgumentValue]
    public var errors: [String]

    public init(data: [String: RpcGraphqlArgumentValue], errors: [String]) {
        self.data = data
        self.errors = errors
    }
}

public enum RpcGraphqlRootQuery: Sendable, Equatable {
    case account(
        alias: String,
        address: RpcGraphqlAddress,
        commitment: RpcGraphqlCommitment?,
        minContextSlot: RpcGraphqlSlot?,
        info: RpcGraphqlResolveInfo
    )
    case block(alias: String, slot: RpcGraphqlSlot, commitment: RpcGraphqlCommitment?, info: RpcGraphqlResolveInfo)
    case programAccounts(
        alias: String,
        programAddress: RpcGraphqlAddress,
        commitment: RpcGraphqlCommitment?,
        dataSizeFilters: [RpcGraphqlProgramAccountsDataSizeFilter]?,
        memcmpFilters: [RpcGraphqlProgramAccountsMemcmpFilter]?,
        minContextSlot: RpcGraphqlSlot?,
        info: RpcGraphqlResolveInfo
    )
    case transaction(
        alias: String,
        signature: RpcGraphqlSignature,
        commitment: RpcGraphqlCommitment?,
        info: RpcGraphqlResolveInfo
    )
}

public struct RpcGraphqlClient: Sendable {
    private var context: RpcGraphqlContext

    init(context: RpcGraphqlContext) {
        self.context = context
    }

    public init(transport: RpcGraphqlRpcTransport, config: RpcGraphqlConfig = .default) {
        self.context = RpcGraphqlLoaderFactory.createSolanaGraphQLContext(transport: transport, config: config)
    }

    public func query(_ queries: [RpcGraphqlRootQuery]) async -> RpcGraphqlExecutionResult {
        var data: [String: RpcGraphqlArgumentValue] = [:]
        var errors: [String] = []

        for query in queries {
            switch query {
            case let .account(alias, address, commitment, minContextSlot, info):
                let result = await RpcGraphqlResolvers.resolveAccount(
                    address: address,
                    commitment: commitment,
                    minContextSlot: minContextSlot,
                    context: context,
                    info: info
                )
                data[alias] = result.map(accountValue(from:)) ?? .null
            case let .block(alias, slot, commitment, info):
                let arguments = RpcGraphqlResolvers.blockLoaderArguments(
                    slot: slot,
                    commitment: commitment,
                    info: info
                )
                let loaded = await context.loaders.block.loadMany(arguments)
                data[alias] = firstValue(from: loaded) ?? .null
                errors.append(contentsOf: failures(from: loaded))
            case let .programAccounts(alias, programAddress, commitment, dataSizeFilters, memcmpFilters, minContextSlot, info):
                let result = await RpcGraphqlResolvers.resolveProgramAccounts(
                    programAddress: programAddress,
                    commitment: commitment,
                    dataSizeFilters: dataSizeFilters,
                    memcmpFilters: memcmpFilters,
                    minContextSlot: minContextSlot,
                    context: context,
                    info: info
                )
                data[alias] = .list(result?.map(accountValue(from:)) ?? [])
            case let .transaction(alias, signature, commitment, info):
                let arguments = RpcGraphqlResolvers.transactionLoaderArguments(
                    signature: signature,
                    commitment: commitment,
                    info: info
                )
                let loaded = await context.loaders.transaction.loadMany(arguments)
                data[alias] = firstValue(from: loaded) ?? .null
                errors.append(contentsOf: failures(from: loaded))
            }
        }

        return RpcGraphqlExecutionResult(data: data, errors: errors)
    }

    public func query(
        source: String,
        variableValues: [String: RpcGraphqlArgumentValue] = [:]
    ) async -> RpcGraphqlExecutionResult {
        await RpcGraphqlSourceQueryExecutor(context: context).query(
            source: source,
            variableValues: variableValues
        )
    }
}

private func firstValue(
    from results: [RpcGraphqlLoadResult<RpcGraphqlArgumentValue?>]
) -> RpcGraphqlArgumentValue? {
    for result in results {
        if case let .value(value?) = result {
            return value
        }
    }
    return nil
}

private func failures<Value: Sendable>(from results: [RpcGraphqlLoadResult<Value>]) -> [String] {
    results.compactMap {
        if case let .failure(message) = $0 {
            return message
        }
        return nil
    }
}

private func accountValue(from result: RpcGraphqlAccountResult) -> RpcGraphqlArgumentValue {
    var fields = result.fields
    fields["address"] = .string(result.address)
    if let ownerProgram = result.ownerProgram {
        fields["ownerProgram"] = .string(ownerProgram)
    }
    if !result.encodedData.isEmpty {
        fields["encodedData"] = .object(result.encodedData.mapValues { .string($0) })
    }
    if !result.jsonParsedConfigs.isEmpty {
        fields["jsonParsedConfigs"] = .object(result.jsonParsedConfigs.mapValues { .string($0) })
    }
    return .object(fields)
}
