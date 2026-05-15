import CryptoKitBackend
import Keys
import SolanaErrors
import XCTest

final class KeysTests: XCTestCase {
    func testCreateKeyPairAndSignUsingBackend() throws {
        let backend = CryptoKitBackend()
        let seed = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a")
        let keyPair = try createKeyPairFromPrivateKeyBytes(seed, using: backend)

        XCTAssertEqual(keyPair.publicKey.rawValue.hex, Data(hex: "1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b5").hex)

        let signatureBytes = try signBytes(Data([1, 2, 3]), with: keyPair.privateKey, using: backend)
        XCTAssertEqual(signatureBytes.rawValue.hex, Data(hex: "426fb8e4efbd7f2e17a875453a8f84a470bdcbe4b7970017b3b5344b70e19680b8a4241565cd731c7fdd1887e50845e810e12ce511ecceae66cf4ffd6007ae0a").hex)
        XCTAssertTrue(try verifySignature(signatureBytes, of: Data([1, 2, 3]), using: keyPair.publicKey, backend: backend))
        XCTAssertTrue(isSignature(base58EncodedSignature(signatureBytes).rawValue))
    }

    func testCreateKeyPairFromBytesValidatesLengthAndPublicKeyMatch() throws {
        let backend = CryptoKitBackend()
        let keyPairBytes = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b5")
        let invalidKeyPairBytes = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b1")

        XCTAssertEqual(try createKeyPairFromBytes(keyPairBytes, using: backend).publicKey.rawValue.hex, Data(keyPairBytes.suffix(32)).hex)

        XCTAssertThrowsError(try createKeyPairFromBytes(Data(keyPairBytes.prefix(31)), using: backend)) { error in
            XCTAssertEqual((error as? KeysError)?.code, SolanaErrorCode.keysInvalidKeyPairByteLength.rawValue)
        }
        XCTAssertThrowsError(try createKeyPairFromBytes(invalidKeyPairBytes, using: backend)) { error in
            XCTAssertEqual((error as? KeysError)?.code, SolanaErrorCode.keysPublicKeyMustMatchPrivateKey.rawValue)
        }
    }

    func testSignatureValidationEnforcesLengthRules() throws {
        XCTAssertThrowsError(try assertIsSignature("short")) { error in
            let validationError = error as? SignatureValidationError
            XCTAssertEqual(validationError?.code, SolanaErrorCode.keysSignatureStringLengthOutOfRange.rawValue)
            XCTAssertEqual(validationError?.contextDescription, "actualLength=5")
            XCTAssertEqual(
                validationError,
                .keys(KeysError.signatureStringLengthOutOfRange(actualLength: 5))
            )
        }
        XCTAssertThrowsError(try signature("short")) { error in
            XCTAssertEqual((error as? SignatureValidationError)?.code, SolanaErrorCode.keysSignatureStringLengthOutOfRange.rawValue)
        }

        let valid = "5awYiUvGiDFA33EJjj4TXJG44a5afJc8QjWRpGgQiu6b23jCr7yndW2fmp9ujwqJVe32J456wV3VF78Asb1obnTc"
        XCTAssertTrue(isSignature(valid))
        XCTAssertEqual(try signature(valid).rawValue, valid)
        XCTAssertFalse(isSignature("not-a-base-58-encoded-string"))

        let invalidBase58WithValidLength = "1111111111111111111111111111111111111111111111111111111111111110"
        XCTAssertFalse(isSignature(invalidBase58WithValidLength))
        XCTAssertThrowsError(try assertIsSignature(invalidBase58WithValidLength)) { error in
            let validationError = error as? SignatureValidationError
            XCTAssertEqual(validationError?.code, SolanaErrorCode.codecsInvalidStringForBase.rawValue)
            XCTAssertEqual(
                validationError?.errorDescription,
                "Invalid value \(invalidBase58WithValidLength) for base 58 with alphabet 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz."
            )
            XCTAssertEqual(
                validationError,
                .codecs(
                    CodecsError.invalidStringForBase(
                        value: invalidBase58WithValidLength,
                        base: 58,
                        alphabet: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
                    )
                )
            )
        }
        XCTAssertThrowsError(try signature(invalidBase58WithValidLength)) { error in
            XCTAssertEqual((error as? SignatureValidationError)?.code, SolanaErrorCode.codecsInvalidStringForBase.rawValue)
        }
    }

    func testSignatureBytesValidation() {
        XCTAssertTrue(isSignatureBytes(Data(repeating: 7, count: 64)))
        XCTAssertThrowsError(try signatureBytes(Data(repeating: 7, count: 63))) { error in
            XCTAssertEqual((error as? KeysError)?.code, SolanaErrorCode.keysInvalidSignatureByteLength.rawValue)
        }
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
