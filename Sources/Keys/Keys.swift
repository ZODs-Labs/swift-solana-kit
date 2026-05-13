public import CryptoBackend
public import Foundation
public import NominalTypes
public import SolanaErrors

public typealias Signature = EncodedString<Base58Encoding>

public struct PrivateKey: Sendable {
    let rawValue: Data

    public init(_ rawValue: Data) throws(KeysError) {
        guard rawValue.count == 32 else {
            throw KeysError.invalidPrivateKeyByteLength(actualLength: rawValue.count)
        }
        self.rawValue = rawValue
    }
}

public struct PublicKey: Sendable, Equatable, Hashable {
    public let rawValue: Data

    public init(_ rawValue: Data) throws(KeysError) {
        guard rawValue.count == 32 else {
            throw KeysError.publicKeyMustMatchPrivateKey
        }
        self.rawValue = rawValue
    }
}

public struct SignatureBytes: Sendable, Equatable, Hashable {
    public let rawValue: Data

    public init(_ rawValue: Data) throws(KeysError) {
        guard rawValue.count == 64 else {
            throw KeysError.invalidSignatureByteLength(actualLength: rawValue.count)
        }
        self.rawValue = rawValue
    }
}

public struct KeyPair: Sendable {
    public let privateKey: PrivateKey
    public let publicKey: PublicKey

    public init(privateKey: PrivateKey, publicKey: PublicKey) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }
}

public func generateKeyPair(using backend: any CryptoBackend) throws(KeysError) -> KeyPair {
    try keyPair(from: backend.generateKeyPair())
}

public func createPrivateKeyFromBytes(_ bytes: Data) throws(KeysError) -> PrivateKey {
    try PrivateKey(bytes)
}

public func createKeyPairFromBytes(
    _ bytes: Data,
    using backend: any CryptoBackend
) throws(KeysError) -> KeyPair {
    try keyPair(from: backend.createKeyPair(solanaKeyPairBytes: bytes))
}

public func createKeyPairFromPrivateKeyBytes(
    _ bytes: Data,
    using backend: any CryptoBackend
) throws(KeysError) -> KeyPair {
    try keyPair(from: backend.createKeyPair(privateKeyBytes: bytes))
}

public func getPublicKeyFromPrivateKey(
    _ privateKey: PrivateKey,
    using backend: any CryptoBackend
) throws(KeysError) -> PublicKey {
    try PublicKey(backend.publicKey(privateKeyBytes: privateKey.rawValue))
}

public func assertIsSignature(_ putativeSignature: String) throws(SignatureValidationError) {
    if putativeSignature.count < 64 || putativeSignature.count > 88 {
        throw SignatureValidationError.keys(
            KeysError.signatureStringLengthOutOfRange(actualLength: putativeSignature.count)
        )
    }
    let decoded: Data
    do {
        decoded = try Base58.decode(putativeSignature)
    } catch {
        throw SignatureValidationError.codecs(error)
    }
    do {
        try assertIsSignatureBytes(decoded)
    } catch {
        throw SignatureValidationError.keys(error)
    }
}

public func isSignature(_ putativeSignature: String) -> Bool {
    do {
        try assertIsSignature(putativeSignature)
        return true
    } catch {
        return false
    }
}

public func signature(_ putativeSignature: String) throws(SignatureValidationError) -> Signature {
    try assertIsSignature(putativeSignature)
    return Signature(rawValue: putativeSignature)
}

public func assertIsSignatureBytes(_ putativeSignatureBytes: Data) throws(KeysError) {
    if putativeSignatureBytes.count != 64 {
        throw KeysError.invalidSignatureByteLength(actualLength: putativeSignatureBytes.count)
    }
}

public func isSignatureBytes(_ putativeSignatureBytes: Data) -> Bool {
    putativeSignatureBytes.count == 64
}

public func signatureBytes(_ putativeSignatureBytes: Data) throws(KeysError) -> SignatureBytes {
    try SignatureBytes(putativeSignatureBytes)
}

public func signBytes(
    _ data: Data,
    with privateKey: PrivateKey,
    using backend: any CryptoBackend
) throws(KeysError) -> SignatureBytes {
    try SignatureBytes(backend.sign(data, privateKeyBytes: privateKey.rawValue))
}

public func verifySignature(
    _ signature: SignatureBytes,
    of data: Data,
    using publicKey: PublicKey,
    backend: any CryptoBackend
) throws(KeysError) -> Bool {
    try backend.verify(signature: signature.rawValue, message: data, publicKeyBytes: publicKey.rawValue)
}

public func base58EncodedSignature(_ signature: SignatureBytes) -> Signature {
    Signature(rawValue: Base58.encode(signature.rawValue))
}

func keyPair(from bytes: CryptoKeyPairBytes) throws(KeysError) -> KeyPair {
    try KeyPair(
        privateKey: PrivateKey(bytes.privateKey),
        publicKey: PublicKey(bytes.publicKey)
    )
}

enum Base58 {
    static let alphabetString = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    static let alphabet = Array(alphabetString)
    static let indexes: [Character: Int] = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) })

    static func encode(_ data: Data) -> String {
        guard !data.isEmpty else {
            return ""
        }
        let leadingZeroes = data.prefix { $0 == 0 }.count
        let payload = data.dropFirst(leadingZeroes)
        guard !payload.isEmpty else {
            return String(repeating: "1", count: leadingZeroes)
        }
        var digits = [Int](repeating: 0, count: 1)
        for byte in payload {
            var carry = Int(byte)
            for index in digits.indices {
                let value = digits[index] * 256 + carry
                digits[index] = value % 58
                carry = value / 58
            }
            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }
        var output = String(repeating: "1", count: leadingZeroes)
        for digit in digits.reversed() {
            output.append(alphabet[digit])
        }
        return output
    }

    static func decode(_ string: String) throws(CodecsError) -> Data {
        guard !string.isEmpty else {
            return Data()
        }
        let leadingZeroes = string.prefix { $0 == "1" }.count
        let payload = string.dropFirst(leadingZeroes)
        guard !payload.isEmpty else {
            return Data(repeating: 0, count: leadingZeroes)
        }
        var bytes = [UInt8](repeating: 0, count: 1)
        for character in payload {
            guard let value = indexes[character] else {
                throw CodecsError.invalidStringForBase(value: string, base: 58, alphabet: alphabetString)
            }
            var carry = value
            for index in bytes.indices {
                let next = Int(bytes[index]) * 58 + carry
                bytes[index] = UInt8(next & 0xFF)
                carry = next >> 8
            }
            while carry > 0 {
                bytes.append(UInt8(carry & 0xFF))
                carry >>= 8
            }
        }
        var decoded = Array(repeating: UInt8(0), count: leadingZeroes)
        decoded.append(contentsOf: bytes.reversed())
        return Data(decoded)
    }
}
