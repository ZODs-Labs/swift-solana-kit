import CryptoBackend
import Foundation
import SolanaErrors

public enum CryptoKitSigningMode: Sendable, Equatable {
    case kitDeterministic
    case platform
}

public struct CryptoKitBackend: CryptoBackend {
    public init(signingMode: CryptoKitSigningMode = .kitDeterministic)
    public func generateKeyPair() throws(KeysError) -> CryptoKeyPairBytes
    public func createKeyPair(privateKeyBytes: Data) throws(KeysError) -> CryptoKeyPairBytes
    public func createKeyPair(solanaKeyPairBytes: Data) throws(KeysError) -> CryptoKeyPairBytes
    public func publicKey(privateKeyBytes: Data) throws(KeysError) -> Data
    public func sign(_ message: Data, privateKeyBytes: Data) throws(KeysError) -> Data
    public func verify(signature: Data, message: Data, publicKeyBytes: Data) throws(KeysError) -> Bool
    public func sha256(_ data: Data) -> Data
    public func isOnCurve(_ compressedEdwardsY: Data) -> Bool
}
