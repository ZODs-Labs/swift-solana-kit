public import CryptoBackend
public import Foundation
public import SolanaErrors
internal import CryptoKit
internal import Curve25519Math

public struct CryptoKitBackend: CryptoBackend {
    private let signingMode: CryptoKitSigningMode

    public init(signingMode: CryptoKitSigningMode = .deterministic) {
        self.signingMode = signingMode
    }

    public func generateKeyPair() throws(KeysError) -> CryptoKeyPairBytes {
        let privateKey = Curve25519.Signing.PrivateKey()
        let privateKeyBytes = Data(privateKey.rawRepresentation)
        return CryptoKeyPairBytes(
            privateKey: privateKeyBytes,
            publicKey: Data(privateKey.publicKey.rawRepresentation)
        )
    }

    public func createKeyPair(privateKeyBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        guard privateKeyBytes.count == 32 else {
            throw KeysError.invalidPrivateKeyByteLength(actualLength: privateKeyBytes.count)
        }
        let privateKey = try makePrivateKey(from: privateKeyBytes)
        return CryptoKeyPairBytes(
            privateKey: privateKeyBytes,
            publicKey: Data(privateKey.publicKey.rawRepresentation)
        )
    }

    public func createKeyPair(solanaKeyPairBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        guard solanaKeyPairBytes.count == 64 else {
            throw KeysError.invalidKeyPairByteLength(byteLength: solanaKeyPairBytes.count)
        }
        let seed = Data(solanaKeyPairBytes.prefix(32))
        let storedPublicKey = Data(solanaKeyPairBytes.suffix(32))
        let keyPair = try createKeyPair(privateKeyBytes: seed)
        guard keyPair.publicKey == storedPublicKey else {
            throw KeysError.publicKeyMustMatchPrivateKey
        }
        return keyPair
    }

    public func publicKey(privateKeyBytes: Data) throws(KeysError) -> Data {
        let privateKey = try makePrivateKey(from: privateKeyBytes)
        return Data(privateKey.publicKey.rawRepresentation)
    }

    public func sign(_ message: Data, privateKeyBytes: Data) throws(KeysError) -> Data {
        let privateKey = try makePrivateKey(from: privateKeyBytes)
        switch signingMode {
        case .deterministic:
            return try ed25519DeterministicSignature(
                message: message,
                privateKeySeed: privateKeyBytes,
                publicKey: Data(privateKey.publicKey.rawRepresentation)
            )
        case .platform:
            do {
                return try privateKey.signature(for: message)
            } catch {
                throw KeysError.invalidPrivateKeyByteLength(actualLength: privateKeyBytes.count)
            }
        }
    }

    public func verify(signature: Data, message: Data, publicKeyBytes: Data) throws(KeysError) -> Bool {
        if signature.count != 64 {
            return false
        }
        guard publicKeyBytes.count == 32 else {
            return false
        }
        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyBytes)
        } catch {
            return false
        }
        return publicKey.isValidSignature(signature, for: message)
    }

    public func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    public func isOnCurve(_ compressedEdwardsY: Data) -> Bool {
        compressedEdwardsYIsOnCurve(compressedEdwardsY)
    }

    private func makePrivateKey(from bytes: Data) throws(KeysError) -> Curve25519.Signing.PrivateKey {
        guard bytes.count == 32 else {
            throw KeysError.invalidPrivateKeyByteLength(actualLength: bytes.count)
        }
        do {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: bytes)
        } catch {
            throw KeysError.invalidPrivateKeyByteLength(actualLength: bytes.count)
        }
    }
}
