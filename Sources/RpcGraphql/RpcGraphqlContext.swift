enum RpcGraphqlLoadResult<Value: Sendable>: Sendable {
    case value(Value)
    case failure(String)
}

struct RpcGraphqlLoader<Arguments: Sendable, Value: Sendable>: Sendable {
    var loadMany: @Sendable ([Arguments]) async -> [RpcGraphqlLoadResult<Value>]
}

struct RpcGraphqlLoaders: Sendable {
    var account: RpcGraphqlLoader<RpcGraphqlAccountLoaderArguments, RpcGraphqlAccountRecord?>
    var block: RpcGraphqlLoader<RpcGraphqlBlockLoaderArguments, RpcGraphqlArgumentValue?>
    var programAccounts: RpcGraphqlLoader<RpcGraphqlProgramAccountsLoaderArguments, [RpcGraphqlAccountRecord]>
    var transaction: RpcGraphqlLoader<RpcGraphqlTransactionLoaderArguments, RpcGraphqlArgumentValue?>
}

struct RpcGraphqlContext: Sendable {
    var loaders: RpcGraphqlLoaders
}
