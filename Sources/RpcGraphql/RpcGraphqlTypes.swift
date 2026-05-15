import Foundation

public typealias RpcGraphqlAddress = String
public typealias RpcGraphqlSignature = String
public typealias RpcGraphqlSlot = UInt64

public enum RpcGraphqlCommitment: String, Sendable, Equatable {
    case processed
    case confirmed
    case finalized
}

public enum RpcGraphqlAccountEncoding: Sendable, Equatable {
    case base58
    case base64
    case base64Zstd
    case jsonParsed

    public var rpcValue: String {
        switch self {
        case .base58:
            "base58"
        case .base64:
            "base64"
        case .base64Zstd:
            "base64+zstd"
        case .jsonParsed:
            "jsonParsed"
        }
    }
}

public enum RpcGraphqlBlockEncoding: String, Sendable, Equatable {
    case base58
    case base64
    case json
    case jsonParsed
}

public enum RpcGraphqlTransactionEncoding: String, Sendable, Equatable {
    case base58
    case base64
    case json
    case jsonParsed
}

public enum RpcGraphqlTransactionDetails: String, Sendable, Equatable {
    case accounts
    case full
    case none
    case signatures
}

public struct RpcGraphqlDataSlice: Sendable, Equatable {
    public var length: Int
    public var offset: Int

    public init(length: Int, offset: Int) {
        self.length = length
        self.offset = offset
    }
}

public struct RpcGraphqlProgramAccountsDataSizeFilter: Sendable, Equatable {
    public var dataSize: Int

    public init(dataSize: Int) {
        self.dataSize = dataSize
    }
}

public struct RpcGraphqlProgramAccountsMemcmpFilter: Sendable, Equatable {
    public var offset: Int
    public var bytes: String
    public var encoding: String?

    public init(offset: Int, bytes: String, encoding: String? = nil) {
        self.offset = offset
        self.bytes = bytes
        self.encoding = encoding
    }
}

public enum RpcGraphqlProgramAccountsFilter: Sendable, Equatable {
    case dataSize(RpcGraphqlProgramAccountsDataSizeFilter)
    case memcmp(RpcGraphqlProgramAccountsMemcmpFilter)
}

public struct RpcGraphqlConfig: Sendable, Equatable {
    public var maxDataSliceByteRange: Int
    public var maxMultipleAccountsBatchSize: Int

    public init(maxDataSliceByteRange: Int, maxMultipleAccountsBatchSize: Int) {
        self.maxDataSliceByteRange = maxDataSliceByteRange
        self.maxMultipleAccountsBatchSize = maxMultipleAccountsBatchSize
    }

    public static let `default` = RpcGraphqlConfig(
        maxDataSliceByteRange: 200,
        maxMultipleAccountsBatchSize: 100
    )
}
