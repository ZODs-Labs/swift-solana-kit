extension RpcGraphqlAccountLoaderArguments {
    func withDefaultCommitment() -> Self {
        var copy = self
        copy.commitment = copy.commitment ?? .confirmed
        return copy
    }

    func rpcConfig() -> RpcGraphqlArgumentValue {
        rpcGraphqlRpcConfig([
            "commitment": commitment.map { .string($0.rawValue) },
            "dataSlice": dataSlice?.rpcValue,
            "encoding": encoding.map { .string($0.rpcValue) },
            "minContextSlot": minContextSlot.map { .uint($0) },
        ])
    }
}

extension RpcGraphqlProgramAccountsLoaderArguments {
    func withDefaultCommitment() -> Self {
        var copy = self
        copy.commitment = copy.commitment ?? .confirmed
        return copy
    }

    func rpcConfig() -> RpcGraphqlArgumentValue {
        rpcGraphqlRpcConfig([
            "commitment": commitment.map { .string($0.rawValue) },
            "dataSlice": dataSlice?.rpcValue,
            "encoding": encoding.map { .string($0.rpcValue) },
            "filters": filters.map { .list($0.map(\.rpcValue)) },
            "minContextSlot": minContextSlot.map { .uint($0) },
        ])
    }
}

extension RpcGraphqlBlockLoaderArguments {
    func withRpcDefaults() -> Self {
        var copy = self
        copy.commitment = copy.commitment ?? .confirmed
        copy.maxSupportedTransactionVersion = copy.maxSupportedTransactionVersion ?? 0
        return copy
    }

    func rpcConfig() -> RpcGraphqlArgumentValue {
        rpcGraphqlRpcConfig([
            "commitment": commitment.map { .string($0.rawValue) },
            "encoding": encoding.map { .string($0.rawValue) },
            "maxSupportedTransactionVersion": maxSupportedTransactionVersion.map { .int($0) },
            "rewards": rewards.map { .bool($0) },
            "transactionDetails": transactionDetails.map { .string($0.rawValue) },
        ])
    }
}

extension RpcGraphqlTransactionLoaderArguments {
    func withDefaultCommitment() -> Self {
        var copy = self
        copy.commitment = copy.commitment ?? .confirmed
        return copy
    }

    func rpcConfig() -> RpcGraphqlArgumentValue {
        rpcGraphqlRpcConfig([
            "commitment": commitment.map { .string($0.rawValue) },
            "encoding": encoding.map { .string($0.rawValue) },
        ])
    }
}

extension RpcGraphqlDataSlice {
    var rpcValue: RpcGraphqlArgumentValue {
        .object([
            "length": .int(length),
            "offset": .int(offset),
        ])
    }
}

extension RpcGraphqlProgramAccountsFilter {
    var rpcValue: RpcGraphqlArgumentValue {
        switch self {
        case let .dataSize(filter):
            .object(["dataSize": .int(filter.dataSize)])
        case let .memcmp(filter):
            .object(["memcmp": filter.rpcValue])
        }
    }
}

extension RpcGraphqlProgramAccountsMemcmpFilter {
    var rpcValue: RpcGraphqlArgumentValue {
        var fields: [String: RpcGraphqlArgumentValue] = [
            "bytes": .string(bytes),
            "offset": .int(offset),
        ]
        if let encoding {
            fields["encoding"] = .string(encoding)
        }
        return .object(fields)
    }
}

private func rpcGraphqlRpcConfig(_ fields: [String: RpcGraphqlArgumentValue?]) -> RpcGraphqlArgumentValue {
    var object: [String: RpcGraphqlArgumentValue] = [:]
    for (key, value) in fields {
        if let value {
            object[key] = value
        }
    }
    return .object(object)
}
