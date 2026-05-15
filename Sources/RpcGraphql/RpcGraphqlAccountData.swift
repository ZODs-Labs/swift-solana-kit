internal import CodecsStrings
import Foundation

enum RpcGraphqlAccountData: Sendable, Equatable {
    case base58(String)
    case encoded(String, encoding: RpcGraphqlAccountEncoding)
    case jsonParsed(RpcGraphqlArgumentValue)
}

struct RpcGraphqlAccountRecord: Sendable, Equatable {
    var data: RpcGraphqlAccountData?
    var executable: Bool?
    var lamports: UInt64?
    var owner: RpcGraphqlAddress?
    var space: UInt64?
    var fields: [String: RpcGraphqlArgumentValue]
    var address: RpcGraphqlAddress? = nil
    var jsonParsedConfigs: [String: String]? = nil
}

enum RpcGraphqlAccountDataSlicer {
    static func slice(
        _ account: RpcGraphqlAccountRecord?,
        dataSlice: RpcGraphqlDataSlice?,
        masterDataSlice: RpcGraphqlDataSlice? = nil
    ) throws -> RpcGraphqlAccountRecord? {
        guard var account, let dataSlice, let data = account.data else {
            return account
        }
        account.data = try sliced(data, dataSlice: dataSlice, masterDataSlice: masterDataSlice)
        return account
    }

    static func sliced(
        _ data: RpcGraphqlAccountData,
        dataSlice: RpcGraphqlDataSlice,
        masterDataSlice: RpcGraphqlDataSlice? = nil
    ) throws -> RpcGraphqlAccountData {
        let masterOffset = masterDataSlice?.offset ?? 0
        let trueOffset = max(0, dataSlice.offset - masterOffset)
        switch data {
        case let .encoded(value, encoding):
            if encoding == .base64Zstd {
                return data
            }
            return try .encoded(
                slice(value, encoding: encoding, offset: trueOffset, length: dataSlice.length),
                encoding: encoding
            )
        case let .base58(value):
            return try .base58(slice(value, encoding: .base58, offset: trueOffset, length: dataSlice.length))
        case .jsonParsed:
            return data
        }
    }

    private static func slice(
        _ value: String,
        encoding: RpcGraphqlAccountEncoding,
        offset: Int,
        length: Int
    ) throws -> String {
        let codec = encoding == .base58 ? getBase58Codec() : getBase64Codec()
        let bytes = try codec.encode(value)
        let lowerBound = min(offset, bytes.count)
        let upperBound = min(lowerBound + length, bytes.count)
        let slicedBytes = Data(bytes[lowerBound ..< upperBound])
        return try codec.decode(slicedBytes)
    }
}
