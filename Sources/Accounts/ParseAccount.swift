public import Addresses
public import CodecsStrings
public import Foundation
public import RpcSpecTypes
public import RpcTypes
import SolanaErrors

public struct ParsedAccountMeta: Sendable, Equatable, Hashable {
    public let program: String?
    public let type: String?

    public init(program: String? = nil, type: String? = nil) {
        self.program = program
        self.type = type
    }
}

public struct JsonParsedAccountData: Sendable, Equatable, Hashable {
    public let info: RpcTypeJsonValue
    public let parsedAccountMeta: ParsedAccountMeta?

    public init(info: RpcTypeJsonValue, parsedAccountMeta: ParsedAccountMeta? = nil) {
        self.info = info
        self.parsedAccountMeta = parsedAccountMeta
    }
}

public struct Base64RpcAccount: Sendable, Equatable, Hashable {
    public let base: AccountInfoBase
    public let data: Base64EncodedDataResponse

    public init(base: AccountInfoBase, data: Base64EncodedDataResponse) {
        self.base = base
        self.data = data
    }
}

public struct Base58RpcAccount: Sendable, Equatable, Hashable {
    public let base: AccountInfoBase
    public let data: Base58EncodedDataResponse

    public init(base: AccountInfoBase, data: Base58EncodedDataResponse) {
        self.base = base
        self.data = data
    }
}

public struct JsonParsedRpcAccount: Sendable, Equatable, Hashable {
    public let base: AccountInfoBase
    public let data: AccountInfoJsonParsedData

    public init(base: AccountInfoBase, data: AccountInfoJsonParsedData) {
        self.base = base
        self.data = data
    }
}

public func parseBase64RpcAccount(_ address: Address, _ rpcAccount: Base64RpcAccount?) throws -> MaybeEncodedAccount {
    guard let rpcAccount else {
        return .missing(address: address)
    }
    let data = try getBase64Encoder().encode(rpcAccount.data.bytes)
    return .exists(Account(address: address, data: data, base: parseBaseAccount(rpcAccount.base), exists: true))
}

public func parseBase58RpcAccount(_ address: Address, _ rpcAccount: Base58RpcAccount?) throws -> MaybeEncodedAccount {
    guard let rpcAccount else {
        return .missing(address: address)
    }
    let data = try getBase58Encoder().encode(rpcAccount.data.bytes)
    return .exists(Account(address: address, data: data, base: parseBaseAccount(rpcAccount.base), exists: true))
}

public func parseJsonRpcAccount(
    _ address: Address,
    _ rpcAccount: JsonParsedRpcAccount?
) -> MaybeAccount<JsonParsedAccountData> {
    guard let rpcAccount else {
        return .missing(address: address)
    }
    let parsed = rpcAccount.data.parsed
    let meta = rpcAccount.data.program.isEmpty && parsed.type.isEmpty
        ? nil
        : ParsedAccountMeta(
            program: rpcAccount.data.program.isEmpty ? nil : rpcAccount.data.program,
            type: parsed.type.isEmpty ? nil : parsed.type
        )
    let data = JsonParsedAccountData(info: parsed.info ?? .object([:]), parsedAccountMeta: meta)
    return .exists(Account(address: address, data: data, base: parseBaseAccount(rpcAccount.base), exists: true))
}

public func parseBase64RpcAccount(_ address: Address, _ rpcAccount: RpcJsonValue) throws -> MaybeEncodedAccount {
    if rpcAccount == .null {
        return .missing(address: address)
    }
    let base = try accountInfoBase(from: rpcAccount)
    let bytes = try encodedDataString(from: rpcAccount, expectedEncoding: "base64")
    return try parseBase64RpcAccount(address, Base64RpcAccount(base: base, data: Base64EncodedDataResponse(bytes)))
}

public func parseJsonRpcAccount(_ address: Address, _ rpcAccount: RpcJsonValue) throws -> MaybeAccount<JsonParsedAccountData> {
    if rpcAccount == .null {
        return .missing(address: address)
    }
    guard let data = rpcAccount.value(for: "data") else {
        throw SolanaError(.malformedJSONRPCError)
    }
    let parsed = try jsonParsedData(from: data)
    let base = try accountInfoBase(from: rpcAccount)
    return parseJsonRpcAccount(address, JsonParsedRpcAccount(base: base, data: parsed))
}

private func parseBaseAccount(_ rpcAccount: AccountInfoBase) -> BaseAccount {
    BaseAccount(
        executable: rpcAccount.executable,
        lamports: rpcAccount.lamports,
        programAddress: rpcAccount.owner,
        space: rpcAccount.space
    )
}

private func accountInfoBase(from value: RpcJsonValue) throws -> AccountInfoBase {
    guard case .object = value else {
        throw SolanaError(.malformedJSONRPCError)
    }
    guard case let .bool(executable)? = value.value(for: "executable"),
          let lamports = try optionalUInt64(from: value.value(for: "lamports")),
          case let .string(ownerString)? = value.value(for: "owner"),
          let space = try optionalUInt64(from: value.value(for: "space"))
    else {
        throw SolanaError(.malformedJSONRPCError)
    }
    let owner = try Address(ownerString)
    return AccountInfoBase(executable: executable, lamports: lamports, owner: owner, space: space)
}

private func encodedDataString(from value: RpcJsonValue, expectedEncoding: String) throws -> String {
    guard let data = value.value(for: "data") else {
        throw SolanaError(.malformedJSONRPCError)
    }
    switch data {
    case let .array(values):
        guard values.count >= 2,
              case let .string(bytes) = values[0],
              case let .string(encoding) = values[1],
              encoding == expectedEncoding
        else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return bytes
    case let .string(bytes) where expectedEncoding == "base58":
        return bytes
    default:
        throw SolanaError(.malformedJSONRPCError)
    }
}

private func jsonParsedData(from value: RpcJsonValue) throws -> AccountInfoJsonParsedData {
    guard case .object = value,
          let parsedValue = value.value(for: "parsed"),
          case .object = parsedValue
    else {
        throw SolanaError(.malformedJSONRPCError)
    }
    let info = try parsedValue.value(for: "info").map(rpcTypeJsonValue(from:)) ?? .object([:])
    let type: String
    if case let .string(parsedType)? = parsedValue.value(for: "type") {
        type = parsedType
    } else {
        type = ""
    }
    let program: String
    if case let .string(programValue)? = value.value(for: "program") {
        program = programValue
    } else {
        program = ""
    }
    let space = try optionalUInt64(from: value.value(for: "space")) ?? 0
    return AccountInfoJsonParsedData(parsed: AccountInfoParsedData(info: info, type: type), program: program, space: space)
}

private func optionalUInt64(from value: RpcJsonValue?) throws -> UInt64? {
    guard let value else {
        return nil
    }
    switch value {
    case let .bigint(string), let .string(string):
        guard let parsed = UInt64(string) else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return parsed
    case let .number(number):
        guard number.isFinite,
              number.rounded(.towardZero) == number,
              number >= 0,
              number <= 9_007_199_254_740_991
        else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return UInt64(number)
    default:
        throw SolanaError(.malformedJSONRPCError)
    }
}

private func rpcTypeJsonValue(from value: RpcJsonValue) throws -> RpcTypeJsonValue {
    switch value {
    case .null:
        return .null
    case let .bool(bool):
        return .bool(bool)
    case let .string(string):
        return .string(string)
    case let .number(number):
        return .number(decimalString(from: number))
    case let .bigint(string):
        return .number(string)
    case let .array(values):
        return .array(try values.map(rpcTypeJsonValue(from:)))
    case let .object(members):
        var object: [String: RpcTypeJsonValue] = [:]
        for member in members {
            object[member.key] = try rpcTypeJsonValue(from: member.value)
        }
        return .object(object)
    }
}

private func decimalString(from number: Double) -> String {
    if number.isFinite,
       number.rounded(.towardZero) == number,
       number >= Double(Int64.min),
       number <= Double(Int64.max) {
        return String(Int64(number))
    }
    return String(number)
}
