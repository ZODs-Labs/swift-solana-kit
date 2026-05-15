public func createRpcGraphQL(
    transport: RpcGraphqlRpcTransport,
    config: RpcGraphqlConfig = .default
) -> RpcGraphqlClient {
    RpcGraphqlClient(transport: transport, config: config)
}

public func createSolanaRpcGraphQL(
    transport: RpcGraphqlRpcTransport,
    config: RpcGraphqlConfig = .default
) -> RpcGraphqlClient {
    createRpcGraphQL(transport: transport, config: config)
}

public func createSolanaGraphQLTypeDefs() -> [String] {
    RpcGraphqlSchema.createSolanaGraphqlTypeDefs()
}

public func createSolanaGraphQLTypeResolvers() -> RpcGraphqlTypeResolvers.Type {
    RpcGraphqlTypeResolvers.self
}
