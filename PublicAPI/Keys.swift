import CryptoBackend
import Foundation
import NominalTypes
import SolanaErrors

public typealias Signature = EncodedString<Base58Encoding>

public struct PrivateKey: Sendable {
    public init(_ rawValue: Data) throws(KeysError)
}

public struct PublicKey: Sendable, Equatable, Hashable {
    public let rawValue: Data
    public init(_ rawValue: Data) throws(KeysError)
}

public struct SignatureBytes: Sendable, Equatable, Hashable {
    public let rawValue: Data
    public init(_ rawValue: Data) throws(KeysError)
}

public struct KeyPair: Sendable {
    public let privateKey: PrivateKey
    public let publicKey: PublicKey
    public init(privateKey: PrivateKey, publicKey: PublicKey)
}

public enum SignatureValidationError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case keys(KeysError)
    case codecs(CodecsError)
    public var code: Int { get }
    public var errorDescription: String? { get }
    public var contextDescription: String { get }
    public static var errorDomain: String { get }
    public var errorCode: Int { get }
    public var errorUserInfo: [String: Any] { get }
}

public func generateKeyPair(using backend: any CryptoBackend) throws(KeysError) -> KeyPair
public func createPrivateKeyFromBytes(_ bytes: Data) throws(KeysError) -> PrivateKey
public func createKeyPairFromBytes(_ bytes: Data, using backend: any CryptoBackend) throws(KeysError) -> KeyPair
public func createKeyPairFromPrivateKeyBytes(_ bytes: Data, using backend: any CryptoBackend) throws(KeysError) -> KeyPair
public func getPublicKeyFromPrivateKey(_ privateKey: PrivateKey, using backend: any CryptoBackend) throws(KeysError) -> PublicKey
public func assertIsSignature(_ putativeSignature: String) throws(SignatureValidationError)
public func isSignature(_ putativeSignature: String) -> Bool
public func signature(_ putativeSignature: String) throws(SignatureValidationError) -> Signature
public func assertIsSignatureBytes(_ putativeSignatureBytes: Data) throws(KeysError)
public func isSignatureBytes(_ putativeSignatureBytes: Data) -> Bool
public func signatureBytes(_ putativeSignatureBytes: Data) throws(KeysError) -> SignatureBytes
public func signBytes(_ data: Data, with privateKey: PrivateKey, using backend: any CryptoBackend) throws(KeysError) -> SignatureBytes
public func verifySignature(_ signature: SignatureBytes, of data: Data, using publicKey: PublicKey, backend: any CryptoBackend) throws(KeysError) -> Bool
public func base58EncodedSignature(_ signature: SignatureBytes) -> Signature
