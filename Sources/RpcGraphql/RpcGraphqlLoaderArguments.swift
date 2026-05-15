internal import FastStableStringify

protocol RpcGraphqlLoadArguments: Sendable, Equatable {
    var encodingKey: String? { get }
    func stableKey(omitting omittedKeys: Set<String>) -> String
    func withDefaultEncoding(_ encoding: String) -> Self
}

protocol RpcGraphqlDataSliceLoadArguments: RpcGraphqlLoadArguments {
    var dataSlice: RpcGraphqlDataSlice? { get }
    func withDataSlice(_ dataSlice: RpcGraphqlDataSlice?) -> Self
}

struct RpcGraphqlAccountLoaderArguments: RpcGraphqlDataSliceLoadArguments {
    var address: RpcGraphqlAddress
    var commitment: RpcGraphqlCommitment?
    var dataSlice: RpcGraphqlDataSlice?
    var encoding: RpcGraphqlAccountEncoding?
    var minContextSlot: RpcGraphqlSlot?

    var encodingKey: String? {
        encoding?.rpcValue
    }

    func stableKey(omitting omittedKeys: Set<String> = []) -> String {
        var values: [String: StableStringifyValue?] = [
            "address": .string(address),
            "commitment": commitment.stableKeyValue,
            "dataSlice": dataSlice?.stableKeyValue,
            "encoding": encoding.stableKeyValue,
            "minContextSlot": minContextSlot.map { .bigint(String($0)) },
        ]
        for key in omittedKeys {
            values[key] = nil
        }
        return rpcGraphqlObjectKey(values)
    }

    func withDefaultEncoding(_ encoding: String) -> Self {
        var copy = self
        copy.encoding = RpcGraphqlAccountEncoding(rpcValue: encoding)
        return copy
    }

    func withDataSlice(_ dataSlice: RpcGraphqlDataSlice?) -> Self {
        var copy = self
        copy.dataSlice = dataSlice
        return copy
    }
}

struct RpcGraphqlBlockLoaderArguments: RpcGraphqlLoadArguments {
    var slot: RpcGraphqlSlot
    var commitment: RpcGraphqlCommitment?
    var encoding: RpcGraphqlBlockEncoding?
    var maxSupportedTransactionVersion: Int?
    var rewards: Bool?
    var transactionDetails: RpcGraphqlTransactionDetails?

    var encodingKey: String? {
        encoding?.rawValue
    }

    func stableKey(omitting omittedKeys: Set<String> = []) -> String {
        var values: [String: StableStringifyValue?] = [
            "commitment": commitment.stableKeyValue,
            "encoding": encoding.stableKeyValue,
            "maxSupportedTransactionVersion": maxSupportedTransactionVersion.map { .number(String($0)) },
            "rewards": rewards.map { .bool($0) },
            "slot": .bigint(String(slot)),
            "transactionDetails": transactionDetails.stableKeyValue,
        ]
        for key in omittedKeys {
            values[key] = nil
        }
        return rpcGraphqlObjectKey(values)
    }

    func withDefaultEncoding(_ encoding: String) -> Self {
        var copy = self
        copy.encoding = RpcGraphqlBlockEncoding(rawValue: encoding)
        return copy
    }

    func withTransactionDetails(_ transactionDetails: RpcGraphqlTransactionDetails) -> Self {
        var copy = self
        copy.transactionDetails = transactionDetails
        return copy
    }
}

struct RpcGraphqlProgramAccountsLoaderArguments: RpcGraphqlDataSliceLoadArguments {
    var programAddress: RpcGraphqlAddress
    var commitment: RpcGraphqlCommitment?
    var dataSlice: RpcGraphqlDataSlice?
    var encoding: RpcGraphqlAccountEncoding?
    var filters: [RpcGraphqlProgramAccountsFilter]?
    var minContextSlot: RpcGraphqlSlot?

    var encodingKey: String? {
        encoding?.rpcValue
    }

    func stableKey(omitting omittedKeys: Set<String> = []) -> String {
        var values: [String: StableStringifyValue?] = [
            "commitment": commitment.stableKeyValue,
            "dataSlice": dataSlice?.stableKeyValue,
            "encoding": encoding.stableKeyValue,
            "filters": filters.map { .array($0.map(\.stableKeyValue)) },
            "minContextSlot": minContextSlot.map { .bigint(String($0)) },
            "programAddress": .string(programAddress),
        ]
        for key in omittedKeys {
            values[key] = nil
        }
        return rpcGraphqlObjectKey(values)
    }

    func withDefaultEncoding(_ encoding: String) -> Self {
        var copy = self
        copy.encoding = RpcGraphqlAccountEncoding(rpcValue: encoding)
        return copy
    }

    func withDataSlice(_ dataSlice: RpcGraphqlDataSlice?) -> Self {
        var copy = self
        copy.dataSlice = dataSlice
        return copy
    }
}

struct RpcGraphqlTransactionLoaderArguments: RpcGraphqlLoadArguments {
    var signature: RpcGraphqlSignature
    var commitment: RpcGraphqlCommitment?
    var encoding: RpcGraphqlTransactionEncoding?

    var encodingKey: String? {
        encoding?.rawValue
    }

    func stableKey(omitting omittedKeys: Set<String> = []) -> String {
        var values: [String: StableStringifyValue?] = [
            "commitment": commitment.stableKeyValue,
            "encoding": encoding.stableKeyValue,
            "signature": .string(signature),
        ]
        for key in omittedKeys {
            values[key] = nil
        }
        return rpcGraphqlObjectKey(values)
    }

    func withDefaultEncoding(_ encoding: String) -> Self {
        var copy = self
        copy.encoding = RpcGraphqlTransactionEncoding(rawValue: encoding)
        return copy
    }
}

extension RpcGraphqlAccountEncoding {
    init?(rpcValue: String) {
        switch rpcValue {
        case "base58":
            self = .base58
        case "base64":
            self = .base64
        case "base64+zstd":
            self = .base64Zstd
        case "jsonParsed":
            self = .jsonParsed
        default:
            return nil
        }
    }
}
