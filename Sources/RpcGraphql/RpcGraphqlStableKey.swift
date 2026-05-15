internal import FastStableStringify

protocol RpcGraphqlStableKeyConvertible {
    var stableKeyValue: StableStringifyValue { get }
}

extension RpcGraphqlDataSlice: RpcGraphqlStableKeyConvertible {
    var stableKeyValue: StableStringifyValue {
        .object([
            "length": .number(String(length)),
            "offset": .number(String(offset)),
        ])
    }
}

extension RpcGraphqlProgramAccountsDataSizeFilter: RpcGraphqlStableKeyConvertible {
    var stableKeyValue: StableStringifyValue {
        .object(["dataSize": .number(String(dataSize))])
    }
}

extension RpcGraphqlProgramAccountsMemcmpFilter: RpcGraphqlStableKeyConvertible {
    var stableKeyValue: StableStringifyValue {
        var object: [String: StableStringifyValue] = [
            "bytes": .string(bytes),
            "offset": .number(String(offset)),
        ]
        if let encoding {
            object["encoding"] = .string(encoding)
        }
        return .object(object)
    }
}

extension RpcGraphqlProgramAccountsFilter: RpcGraphqlStableKeyConvertible {
    var stableKeyValue: StableStringifyValue {
        switch self {
        case let .dataSize(filter):
            filter.stableKeyValue
        case let .memcmp(filter):
            .object(["memcmp": filter.stableKeyValue])
        }
    }
}

func rpcGraphqlCacheKey(_ value: StableStringifyValue) -> String {
    fastStableStringify(value) ?? ""
}

func rpcGraphqlObjectKey(_ values: [String: StableStringifyValue?]) -> String {
    var object: [String: StableStringifyValue] = [:]
    for (key, value) in values {
        if let value {
            object[key] = value
        }
    }
    return rpcGraphqlCacheKey(.object(object))
}

extension Optional where Wrapped == RpcGraphqlCommitment {
    var stableKeyValue: StableStringifyValue? {
        map { .string($0.rawValue) }
    }
}

extension Optional where Wrapped == RpcGraphqlAccountEncoding {
    var stableKeyValue: StableStringifyValue? {
        map { .string($0.rpcValue) }
    }
}

extension Optional where Wrapped == RpcGraphqlBlockEncoding {
    var stableKeyValue: StableStringifyValue? {
        map { .string($0.rawValue) }
    }
}

extension Optional where Wrapped == RpcGraphqlTransactionEncoding {
    var stableKeyValue: StableStringifyValue? {
        map { .string($0.rawValue) }
    }
}

extension Optional where Wrapped == RpcGraphqlTransactionDetails {
    var stableKeyValue: StableStringifyValue? {
        map { .string($0.rawValue) }
    }
}
