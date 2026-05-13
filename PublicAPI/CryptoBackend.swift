import Foundation
import SolanaErrors

public struct CryptoKeyPairBytes: Sendable, Equatable, Hashable {
    public let privateKey: Data
    public let publicKey: Data
    public init(privateKey: Data, publicKey: Data)
    public var solanaKeyPairBytes: Data { get }
}

public protocol CryptoBackend: Sendable {
    func generateKeyPair() throws(KeysError) -> CryptoKeyPairBytes
    func createKeyPair(privateKeyBytes: Data) throws(KeysError) -> CryptoKeyPairBytes
    func createKeyPair(solanaKeyPairBytes: Data) throws(KeysError) -> CryptoKeyPairBytes
    func publicKey(privateKeyBytes: Data) throws(KeysError) -> Data
    func sign(_ message: Data, privateKeyBytes: Data) throws(KeysError) -> Data
    func verify(signature: Data, message: Data, publicKeyBytes: Data) throws(KeysError) -> Bool
    func sha256(_ data: Data) -> Data
    func isOnCurve(_ compressedEdwardsY: Data) -> Bool
}
