import CryptoKitBackend
import SolanaErrors
import XCTest

final class CryptoKitBackendTests: XCTestCase {
    func testRFC8032KeyDerivationAndSignatureVector() throws {
        let backend = CryptoKitBackend()
        let seed = Data(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
        let expectedPublicKey = Data(hex: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
        let expectedSignature = Data(hex: "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")

        let keyPair = try backend.createKeyPair(privateKeyBytes: seed)
        XCTAssertEqual(keyPair.publicKey.hex, expectedPublicKey.hex)

        let signature = try backend.sign(Data(), privateKeyBytes: seed)
        XCTAssertEqual(signature.hex, expectedSignature.hex)
        XCTAssertTrue(try backend.verify(signature: signature, message: Data(), publicKeyBytes: expectedPublicKey))
    }

    func testReferenceSigningVector() throws {
        let backend = CryptoKitBackend()
        let seed = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a")
        let message = Data([1, 2, 3])
        let expectedPublicKey = Data(hex: "1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b5")
        let expectedSignature = Data(hex: "426fb8e4efbd7f2e17a875453a8f84a470bdcbe4b7970017b3b5344b70e19680b8a4241565cd731c7fdd1887e50845e810e12ce511ecceae66cf4ffd6007ae0a")

        let keyPair = try backend.createKeyPair(privateKeyBytes: seed)
        let signature = try backend.sign(message, privateKeyBytes: seed)

        XCTAssertEqual(keyPair.publicKey.hex, expectedPublicKey.hex)
        XCTAssertEqual(signature.hex, expectedSignature.hex)
        XCTAssertTrue(try backend.verify(signature: signature, message: message, publicKeyBytes: expectedPublicKey))
        XCTAssertFalse(try backend.verify(signature: Data(repeating: 1, count: 64), message: message, publicKeyBytes: expectedPublicKey))
    }

    func testDefaultSigningModeIsDeterministicAndReferenceCompatible() throws {
        let backend = CryptoKitBackend()
        let seed = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a")
        let message = Data([1, 2, 3])

        let first = try backend.sign(message, privateKeyBytes: seed)
        let second = try backend.sign(message, privateKeyBytes: seed)

        XCTAssertEqual(first, second)
        XCTAssertEqual(
            first.hex,
            "426fb8e4efbd7f2e17a875453a8f84a470bdcbe4b7970017b3b5344b70e19680b8a4241565cd731c7fdd1887e50845e810e12ce511ecceae66cf4ffd6007ae0a"
        )
    }

    func testPlatformSigningModeProducesVerifiableSignature() throws {
        let backend = CryptoKitBackend(signingMode: .platform)
        let seed = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a")
        let message = Data([1, 2, 3])
        let publicKey = try backend.publicKey(privateKeyBytes: seed)

        let signature = try backend.sign(message, privateKeyBytes: seed)

        XCTAssertEqual(signature.count, 64)
        XCTAssertTrue(try backend.verify(signature: signature, message: message, publicKeyBytes: publicKey))
    }

    func testPlatformSigningModeUsesRandomizedCryptoKitOutput() throws {
        let backend = CryptoKitBackend(signingMode: .platform)
        let seed = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a")
        let message = Data([1, 2, 3])
        let publicKey = try backend.publicKey(privateKeyBytes: seed)

        let first = try backend.sign(message, privateKeyBytes: seed)
        let second = try backend.sign(message, privateKeyBytes: seed)

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(try backend.verify(signature: first, message: message, publicKeyBytes: publicKey))
        XCTAssertTrue(try backend.verify(signature: second, message: message, publicKeyBytes: publicKey))
    }

    func testSolanaKeyPairRejectsMismatchedPublicKey() {
        let backend = CryptoKitBackend()
        let mismatched = Data(repeating: 1, count: 64)
        XCTAssertThrowsError(try backend.createKeyPair(solanaKeyPairBytes: mismatched))
    }

    func testVerifyReturnsFalseForMalformedSignatureLengths() throws {
        let backend = CryptoKitBackend()
        let publicKey = Data(hex: "1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b5")
        let message = Data([1, 2, 3])

        XCTAssertFalse(try backend.verify(signature: Data(repeating: 0, count: 63), message: message, publicKeyBytes: publicKey))
        XCTAssertFalse(try backend.verify(signature: Data(repeating: 0, count: 65), message: message, publicKeyBytes: publicKey))
    }

    func testVerifyReturnsFalseForMalformedPublicKeyBytes() throws {
        let backend = CryptoKitBackend()
        XCTAssertFalse(try backend.verify(signature: Data(repeating: 0, count: 64), message: Data(), publicKeyBytes: Data(repeating: 0, count: 31)))
    }

    func testSHA256AndCurveChecksAreAvailable() {
        let backend = CryptoKitBackend()
        XCTAssertEqual(backend.sha256(Data()).count, 32)
        XCTAssertTrue(backend.isOnCurve(Data(hex: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")))
    }
}

private extension Data {
    init(hex: String) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
