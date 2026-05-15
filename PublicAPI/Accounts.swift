public import Addresses
public import CodecsCore
public import Foundation
public import Promises
public import RpcSpec
public import RpcSpecTypes
public import RpcTypes

public let baseAccountSize: Int

public struct BaseAccount: Sendable, Equatable, Hashable
public struct Account<TData: Sendable>: Sendable
public enum MaybeAccount<TData: Sendable>: Sendable
public struct ParsedAccountMeta: Sendable, Equatable, Hashable
public struct JsonParsedAccountData: Sendable, Equatable, Hashable
public struct Base64RpcAccount: Sendable, Equatable, Hashable
public struct Base58RpcAccount: Sendable, Equatable, Hashable
public struct JsonParsedRpcAccount: Sendable, Equatable, Hashable
public enum MaybeJsonParsedOrEncodedAccount: Sendable
public struct FetchAccountConfig: Sendable
public struct FetchAccountsConfig: Sendable

public typealias EncodedAccount = Account<Data>
public typealias MaybeEncodedAccount = MaybeAccount<Data>

public let BaseAccount.executable: Bool
public let BaseAccount.lamports: Lamports
public let BaseAccount.programAddress: Address
public let BaseAccount.space: UInt64
public init BaseAccount(executable: Bool, lamports: Lamports, programAddress: Address, space: UInt64)

public let Account.address: Address
public let Account.data: TData
public let Account.executable: Bool
public let Account.lamports: Lamports
public let Account.programAddress: Address
public let Account.space: UInt64
public let Account.exists: Bool
public init Account(address: Address, data: TData, base: BaseAccount, exists: Bool = true)
public init Account(address: Address, data: TData, executable: Bool, lamports: Lamports, programAddress: Address, space: UInt64, exists: Bool = true)

extension Account: Equatable where TData: Equatable
extension Account: Hashable where TData: Hashable

public enum MaybeAccount.case missing(address: Address)
public enum MaybeAccount.case exists(Account<TData>)
public var MaybeAccount.address: Address { get }
public var MaybeAccount.exists: Bool { get }
public var MaybeAccount.account: Account<TData>? { get }

extension MaybeAccount: Equatable where TData: Equatable
extension MaybeAccount: Hashable where TData: Hashable

public enum MaybeJsonParsedOrEncodedAccount.case missing(address: Address)
public enum MaybeJsonParsedOrEncodedAccount.case parsed(Account<JsonParsedAccountData>)
public enum MaybeJsonParsedOrEncodedAccount.case encoded(EncodedAccount)
public var MaybeJsonParsedOrEncodedAccount.address: Address { get }
public var MaybeJsonParsedOrEncodedAccount.exists: Bool { get }
public var MaybeJsonParsedOrEncodedAccount.parsedAccount: Account<JsonParsedAccountData>? { get }
public var MaybeJsonParsedOrEncodedAccount.encodedAccount: EncodedAccount? { get }

extension MaybeJsonParsedOrEncodedAccount: Equatable
extension MaybeJsonParsedOrEncodedAccount: Hashable

public let ParsedAccountMeta.program: String?
public let ParsedAccountMeta.type: String?
public init ParsedAccountMeta(program: String? = nil, type: String? = nil)

public let JsonParsedAccountData.info: RpcTypeJsonValue
public let JsonParsedAccountData.parsedAccountMeta: ParsedAccountMeta?
public init JsonParsedAccountData(info: RpcTypeJsonValue, parsedAccountMeta: ParsedAccountMeta? = nil)

public let Base64RpcAccount.base: AccountInfoBase
public let Base64RpcAccount.data: Base64EncodedDataResponse
public init Base64RpcAccount(base: AccountInfoBase, data: Base64EncodedDataResponse)

public let Base58RpcAccount.base: AccountInfoBase
public let Base58RpcAccount.data: Base58EncodedDataResponse
public init Base58RpcAccount(base: AccountInfoBase, data: Base58EncodedDataResponse)

public let JsonParsedRpcAccount.base: AccountInfoBase
public let JsonParsedRpcAccount.data: AccountInfoJsonParsedData
public init JsonParsedRpcAccount(base: AccountInfoBase, data: AccountInfoJsonParsedData)

public let FetchAccountConfig.abortSignal: AbortSignal?
public let FetchAccountConfig.commitment: Commitment?
public let FetchAccountConfig.minContextSlot: Slot?
public init FetchAccountConfig(abortSignal: AbortSignal? = nil, commitment: Commitment? = nil, minContextSlot: Slot? = nil)

public let FetchAccountsConfig.abortSignal: AbortSignal?
public let FetchAccountsConfig.commitment: Commitment?
public let FetchAccountsConfig.minContextSlot: Slot?
public init FetchAccountsConfig(abortSignal: AbortSignal? = nil, commitment: Commitment? = nil, minContextSlot: Slot? = nil)

public func decodeAccount<D: Decoder>(_ encodedAccount: EncodedAccount, using decoder: D) throws -> Account<D.Decoded> where D.Decoded: Sendable
public func decodeAccount<D: Decoder>(_ encodedAccount: MaybeEncodedAccount, using decoder: D) throws -> MaybeAccount<D.Decoded> where D.Decoded: Sendable
public func assertAccountExists<TData: Sendable>(_ account: MaybeAccount<TData>) throws -> Account<TData>
public func assertAccountsExist<TData: Sendable>(_ accounts: [MaybeAccount<TData>]) throws -> [Account<TData>]
public func assertAccountDecoded<TData: Sendable>(_ account: Account<TData>) throws
public func assertAccountDecoded<TData: Sendable>(_ account: MaybeAccount<TData>) throws
public func assertAccountDecoded(_ account: MaybeJsonParsedOrEncodedAccount) throws -> MaybeAccount<JsonParsedAccountData>
public func assertAccountsDecoded<TData: Sendable>(_ accounts: [Account<TData>]) throws
public func assertAccountsDecoded<TData: Sendable>(_ accounts: [MaybeAccount<TData>]) throws
public func assertAccountsDecoded(_ accounts: [MaybeJsonParsedOrEncodedAccount]) throws -> [MaybeAccount<JsonParsedAccountData>]

public func parseBase64RpcAccount(_ address: Address, _ rpcAccount: Base64RpcAccount?) throws -> MaybeEncodedAccount
public func parseBase58RpcAccount(_ address: Address, _ rpcAccount: Base58RpcAccount?) throws -> MaybeEncodedAccount
public func parseJsonRpcAccount(_ address: Address, _ rpcAccount: JsonParsedRpcAccount?) -> MaybeAccount<JsonParsedAccountData>
public func parseBase64RpcAccount(_ address: Address, _ rpcAccount: RpcJsonValue) throws -> MaybeEncodedAccount
public func parseJsonRpcAccount(_ address: Address, _ rpcAccount: RpcJsonValue) throws -> MaybeAccount<JsonParsedAccountData>

public func fetchEncodedAccount(rpc: Rpc, address: Address, config: FetchAccountConfig = FetchAccountConfig()) async throws -> MaybeEncodedAccount
public func fetchJsonParsedAccount(rpc: Rpc, address: Address, config: FetchAccountConfig = FetchAccountConfig()) async throws -> MaybeJsonParsedOrEncodedAccount
public func fetchEncodedAccounts(rpc: Rpc, addresses: [Address], config: FetchAccountsConfig = FetchAccountsConfig()) async throws -> [MaybeEncodedAccount]
public func fetchJsonParsedAccounts(rpc: Rpc, addresses: [Address], config: FetchAccountsConfig = FetchAccountsConfig()) async throws -> [MaybeJsonParsedOrEncodedAccount]
