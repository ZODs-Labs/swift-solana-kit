public import Foundation

public typealias RpcGraphqlAddress = String
public typealias RpcGraphqlSignature = String
public typealias RpcGraphqlSlot = UInt64

public enum RpcGraphqlCommitment: String, Sendable, Equatable
public enum RpcGraphqlCommitment.case processed
public enum RpcGraphqlCommitment.case confirmed
public enum RpcGraphqlCommitment.case finalized

public enum RpcGraphqlAccountEncoding: Sendable, Equatable
public enum RpcGraphqlAccountEncoding.case base58
public enum RpcGraphqlAccountEncoding.case base64
public enum RpcGraphqlAccountEncoding.case base64Zstd
public enum RpcGraphqlAccountEncoding.case jsonParsed
public var RpcGraphqlAccountEncoding.rpcValue: String { get }

public enum RpcGraphqlBlockEncoding: String, Sendable, Equatable
public enum RpcGraphqlBlockEncoding.case base58
public enum RpcGraphqlBlockEncoding.case base64
public enum RpcGraphqlBlockEncoding.case json
public enum RpcGraphqlBlockEncoding.case jsonParsed

public enum RpcGraphqlTransactionEncoding: String, Sendable, Equatable
public enum RpcGraphqlTransactionEncoding.case base58
public enum RpcGraphqlTransactionEncoding.case base64
public enum RpcGraphqlTransactionEncoding.case json
public enum RpcGraphqlTransactionEncoding.case jsonParsed

public enum RpcGraphqlTransactionDetails: String, Sendable, Equatable
public enum RpcGraphqlTransactionDetails.case accounts
public enum RpcGraphqlTransactionDetails.case full
public enum RpcGraphqlTransactionDetails.case none
public enum RpcGraphqlTransactionDetails.case signatures

public struct RpcGraphqlDataSlice: Sendable, Equatable
public var RpcGraphqlDataSlice.length: Int
public var RpcGraphqlDataSlice.offset: Int
public init RpcGraphqlDataSlice(length: Int, offset: Int)

public struct RpcGraphqlProgramAccountsDataSizeFilter: Sendable, Equatable
public var RpcGraphqlProgramAccountsDataSizeFilter.dataSize: Int
public init RpcGraphqlProgramAccountsDataSizeFilter(dataSize: Int)

public struct RpcGraphqlProgramAccountsMemcmpFilter: Sendable, Equatable
public var RpcGraphqlProgramAccountsMemcmpFilter.offset: Int
public var RpcGraphqlProgramAccountsMemcmpFilter.bytes: String
public var RpcGraphqlProgramAccountsMemcmpFilter.encoding: String?
public init RpcGraphqlProgramAccountsMemcmpFilter(offset: Int, bytes: String, encoding: String? = nil)

public enum RpcGraphqlProgramAccountsFilter: Sendable, Equatable
public enum RpcGraphqlProgramAccountsFilter.case dataSize(RpcGraphqlProgramAccountsDataSizeFilter)
public enum RpcGraphqlProgramAccountsFilter.case memcmp(RpcGraphqlProgramAccountsMemcmpFilter)

public struct RpcGraphqlConfig: Sendable, Equatable
public var RpcGraphqlConfig.maxDataSliceByteRange: Int
public var RpcGraphqlConfig.maxMultipleAccountsBatchSize: Int
public init RpcGraphqlConfig(maxDataSliceByteRange: Int, maxMultipleAccountsBatchSize: Int)
public static let RpcGraphqlConfig.default: RpcGraphqlConfig

public enum RpcGraphqlArgumentValue: Sendable, Equatable, Codable
public enum RpcGraphqlArgumentValue.case null
public enum RpcGraphqlArgumentValue.case bool(Bool)
public enum RpcGraphqlArgumentValue.case int(Int)
public enum RpcGraphqlArgumentValue.case uint(UInt64)
public enum RpcGraphqlArgumentValue.case number(String)
public enum RpcGraphqlArgumentValue.case string(String)
public enum RpcGraphqlArgumentValue.case enumCase(String)
public enum RpcGraphqlArgumentValue.case variable(String)
public enum RpcGraphqlArgumentValue.case object([String: RpcGraphqlArgumentValue])
public enum RpcGraphqlArgumentValue.case list([RpcGraphqlArgumentValue])
public init RpcGraphqlArgumentValue(from decoder: any Decoder) throws
public func RpcGraphqlArgumentValue.encode(to encoder: any Encoder) throws
public func RpcGraphqlArgumentValue.resolved(using variables: [String: RpcGraphqlArgumentValue]) -> RpcGraphqlArgumentValue
public var RpcGraphqlArgumentValue.stringValue: String? { get }
public var RpcGraphqlArgumentValue.intValue: Int? { get }

public enum RpcGraphqlSelection: Sendable, Equatable
public enum RpcGraphqlSelection.case field(name: String, arguments: [String: RpcGraphqlArgumentValue], selections: [RpcGraphqlSelection])
public enum RpcGraphqlSelection.case fragmentSpread(name: String)
public enum RpcGraphqlSelection.case inlineFragment(typeCondition: String?, selections: [RpcGraphqlSelection])
public var RpcGraphqlSelection.fieldName: String? { get }

public struct RpcGraphqlResolveInfo: Sendable, Equatable
public var RpcGraphqlResolveInfo.selections: [RpcGraphqlSelection]
public var RpcGraphqlResolveInfo.fragments: [String: [RpcGraphqlSelection]]
public var RpcGraphqlResolveInfo.variableValues: [String: RpcGraphqlArgumentValue]
public var RpcGraphqlResolveInfo.accountInterfaceFields: Set<String>
public init RpcGraphqlResolveInfo(selections: [RpcGraphqlSelection], fragments: [String: [RpcGraphqlSelection]] = [:], variableValues: [String: RpcGraphqlArgumentValue] = [:], accountInterfaceFields: Set<String> = RpcGraphqlSchema.accountInterfaceFields)

public enum RpcGraphqlRpcError: Error, Sendable, Equatable
public enum RpcGraphqlRpcError.case missingResult
public enum RpcGraphqlRpcError.case responseError(code: Int?, message: String)

public struct RpcGraphqlRpcTransport: Sendable
public init RpcGraphqlRpcTransport(send: @escaping @Sendable (String, [RpcGraphqlArgumentValue]) async throws -> RpcGraphqlArgumentValue)
public func RpcGraphqlRpcTransport.send(_ method: String, params: [RpcGraphqlArgumentValue]) async throws -> RpcGraphqlArgumentValue
public static func RpcGraphqlRpcTransport.http(endpoint: URL, headers: [String: String] = [:]) -> RpcGraphqlRpcTransport

public struct RpcGraphqlExecutionResult: Sendable, Equatable
public var RpcGraphqlExecutionResult.data: [String: RpcGraphqlArgumentValue]
public var RpcGraphqlExecutionResult.errors: [String]
public init RpcGraphqlExecutionResult(data: [String: RpcGraphqlArgumentValue], errors: [String])

public enum RpcGraphqlRootQuery: Sendable, Equatable
public enum RpcGraphqlRootQuery.case account(alias: String, address: RpcGraphqlAddress, commitment: RpcGraphqlCommitment?, minContextSlot: RpcGraphqlSlot?, info: RpcGraphqlResolveInfo)
public enum RpcGraphqlRootQuery.case block(alias: String, slot: RpcGraphqlSlot, commitment: RpcGraphqlCommitment?, info: RpcGraphqlResolveInfo)
public enum RpcGraphqlRootQuery.case programAccounts(alias: String, programAddress: RpcGraphqlAddress, commitment: RpcGraphqlCommitment?, dataSizeFilters: [RpcGraphqlProgramAccountsDataSizeFilter]?, memcmpFilters: [RpcGraphqlProgramAccountsMemcmpFilter]?, minContextSlot: RpcGraphqlSlot?, info: RpcGraphqlResolveInfo)
public enum RpcGraphqlRootQuery.case transaction(alias: String, signature: RpcGraphqlSignature, commitment: RpcGraphqlCommitment?, info: RpcGraphqlResolveInfo)

public struct RpcGraphqlClient: Sendable
public init RpcGraphqlClient(transport: RpcGraphqlRpcTransport, config: RpcGraphqlConfig = .default)
public func RpcGraphqlClient.query(_ queries: [RpcGraphqlRootQuery]) async -> RpcGraphqlExecutionResult
public func RpcGraphqlClient.query(source: String, variableValues: [String: RpcGraphqlArgumentValue] = [:]) async -> RpcGraphqlExecutionResult

public enum RpcGraphqlSchema
public static let RpcGraphqlSchema.accountInterfaceFields: Set<String>
public static func RpcGraphqlSchema.createSolanaGraphqlTypeDefs() -> [String]

public enum RpcGraphqlTypeResolvers
public static let RpcGraphqlTypeResolvers.accountEncodingCases: [String: String]
public static let RpcGraphqlTypeResolvers.commitmentCases: [String: String]
public static let RpcGraphqlTypeResolvers.commitmentWithoutProcessedCases: [String: String]
public static let RpcGraphqlTypeResolvers.transactionEncodingCases: [String: String]
public static let RpcGraphqlTypeResolvers.programAccountsMemcmpFilterAccountEncodingCases: [String: String]
public static let RpcGraphqlTypeResolvers.splTokenDefaultAccountStateCases: [String: String]
public static let RpcGraphqlTypeResolvers.splTokenExtensionCases: [String: String]
public static func RpcGraphqlTypeResolvers.accountTypeName(accountType: String?, programName: String?) -> String
public static func RpcGraphqlTypeResolvers.splTokenExtensionTypeName(_ extensionName: String) -> String?
public static func RpcGraphqlTypeResolvers.instructionTypeName(programName: String?, instructionType: String?) -> String

public func createRpcGraphQL(transport: RpcGraphqlRpcTransport, config: RpcGraphqlConfig = .default) -> RpcGraphqlClient
public func createSolanaRpcGraphQL(transport: RpcGraphqlRpcTransport, config: RpcGraphqlConfig = .default) -> RpcGraphqlClient
public func createSolanaGraphQLTypeDefs() -> [String]
public func createSolanaGraphQLTypeResolvers() -> RpcGraphqlTypeResolvers.Type
