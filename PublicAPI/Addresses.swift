import CodecsCore
import CryptoBackend
import Foundation
import SolanaErrors

public struct Address: Sendable, Equatable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let rawValue: String
    public var description: String { get }
    public init(_ rawValue: String) throws(AddressValidationError)
    public init(from decoder: any Swift.Decoder) throws
    public func encode(to encoder: any Swift.Encoder) throws
    public static func < (lhs: Address, rhs: Address) -> Bool
}

public enum AddressValidationError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case addresses(AddressError)
    case codecs(CodecsError)
    public var code: Int { get }
    public var errorDescription: String? { get }
    public var contextDescription: String { get }
    public static var errorDomain: String { get }
    public var errorCode: Int { get }
    public var errorUserInfo: [String: Any] { get }
}

public struct OffCurveAddress: Sendable, Equatable, Hashable, CustomStringConvertible {
    public let address: Address
    public var rawValue: String { get }
    public var description: String { get }
}

public enum ProgramDerivedAddressSeed: Sendable, Equatable {
    case bytes(Data)
    case utf8(String)
}

public struct ProgramDerivedAddressBump: Sendable, Equatable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let rawValue: UInt8
    public var description: String { get }
    public init(_ rawValue: Int) throws(AddressError)
    public static func < (lhs: ProgramDerivedAddressBump, rhs: ProgramDerivedAddressBump) -> Bool
}

public struct ProgramDerivedAddress: Sendable, Equatable, Hashable, Codable {
    public let address: Address
    public let bump: ProgramDerivedAddressBump
    public init(address: Address, bump: ProgramDerivedAddressBump)
}

public func assertIsAddress(_ putativeAddress: String) throws(AddressValidationError)
public func isAddress(_ putativeAddress: String) -> Bool
public func address(_ putativeAddress: String) throws(AddressValidationError) -> Address
public func getAddressEncoder() -> AnyFixedSizeEncoder<Address>
public func getAddressDecoder() -> AnyFixedSizeDecoder<Address>
public func getAddressCodec() -> AnyFixedSizeCodec<Address, Address>
public func getAddressComparator() -> @Sendable (Address, Address) -> Int

public func isOffCurveAddress(_ putativeOffCurveAddress: Address, using backend: any CryptoBackend) -> Bool
public func assertIsOffCurveAddress(_ putativeOffCurveAddress: Address, using backend: any CryptoBackend) throws(AddressError)
public func offCurveAddress(_ putativeOffCurveAddress: Address, using backend: any CryptoBackend) throws(AddressError) -> OffCurveAddress

public func getAddressFromPublicKey(_ publicKeyBytes: Data) throws(AddressError) -> Address
public func getPublicKeyFromAddress(_ address: Address) throws(CodecsError) -> Data

public func isProgramDerivedAddress(_ value: ProgramDerivedAddress) -> Bool
public func assertIsProgramDerivedAddress(_ value: ProgramDerivedAddress) throws(AddressError)
public func getProgramDerivedAddress(
    programAddress: Address,
    seeds: [ProgramDerivedAddressSeed],
    using backend: any CryptoBackend
) throws(AddressError) -> ProgramDerivedAddress
public func createAddressWithSeed(
    baseAddress: Address,
    programAddress: Address,
    seed: ProgramDerivedAddressSeed,
    using backend: any CryptoBackend
) throws(AddressError) -> Address
