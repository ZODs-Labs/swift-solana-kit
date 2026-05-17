import CryptoBackend
import Keys
import SolanaErrors
import XCTest

final class KeysDetailedBehaviorTests: XCTestCase {
    func testPrivateKeyConstructionRejectsEveryNonThirtyTwoByteLength() {
        for length in [0, 16, 31, 33] {
            XCTAssertThrowsError(try createPrivateKeyFromBytes(Data(repeating: 0, count: length)), "length \(length)") { error in
                XCTAssertEqual(error as? KeysError, .invalidPrivateKeyByteLength(actualLength: length))
                XCTAssertEqual((error as? KeysError)?.code, SolanaErrorCode.keysInvalidPrivateKeyByteLength.rawValue)
                XCTAssertEqual((error as? KeysError)?.contextDescription, "actualLength=\(length)")
            }
        }
    }

    func testPublicKeyAndSignatureByteConstructionEnforceExactLengths() throws {
        XCTAssertThrowsError(try PublicKey(Data(repeating: 1, count: 31))) { error in
            XCTAssertEqual(error as? KeysError, .publicKeyMustMatchPrivateKey)
        }
        XCTAssertEqual(try PublicKey(Data(repeating: 1, count: 32)).rawValue, Data(repeating: 1, count: 32))

        for length in [0, 63, 65] {
            XCTAssertFalse(isSignatureBytes(Data(repeating: 7, count: length)))
            XCTAssertThrowsError(try assertIsSignatureBytes(Data(repeating: 7, count: length)), "length \(length)") { error in
                XCTAssertEqual(error as? KeysError, .invalidSignatureByteLength(actualLength: length))
            }
            XCTAssertThrowsError(try signatureBytes(Data(repeating: 7, count: length)), "length \(length)") { error in
                XCTAssertEqual((error as? KeysError)?.contextDescription, "actualLength=\(length)")
            }
        }

        XCTAssertNoThrow(try assertIsSignatureBytes(Data(repeating: 0, count: 64)))
        XCTAssertEqual(try signatureBytes(Data(repeating: 0, count: 64)).rawValue, Data(repeating: 0, count: 64))
    }

    func testSignatureStringValidationCoversStringAndDecodedByteLengths() throws {
        for length in [63, 89] {
            XCTAssertThrowsError(try signature(String(repeating: "t", count: length)), "length \(length)") { error in
                XCTAssertEqual(
                    error as? SignatureValidationError,
                    .keys(.signatureStringLengthOutOfRange(actualLength: length))
                )
            }
        }

        let decodedTooShort = "3bwsNoq6EP89sShUAKBeB26aCC3KLGNajRm5wqwr6zRPP3gErZH7erSg3332SVY7Ru6cME43qT35Z7JKpZqCoP"
        XCTAssertThrowsError(try signature(decodedTooShort)) { error in
            XCTAssertEqual(
                error as? SignatureValidationError,
                .keys(.invalidSignatureByteLength(actualLength: 63))
            )
        }

        let decodedTooLong = "ZbwsNoq6EP89sShUAKBeB26aCC3KLGNajRm5wqwr6zRPP3gErZH7erSg3332SVY7Ru6cME43qT35Z7JKPZqCoPZZ"
        XCTAssertThrowsError(try signature(decodedTooLong)) { error in
            XCTAssertEqual(
                error as? SignatureValidationError,
                .keys(.invalidSignatureByteLength(actualLength: 65))
            )
        }

        let zeroSignature = String(repeating: "1", count: 64)
        XCTAssertTrue(isSignature(zeroSignature))
        XCTAssertNoThrow(try assertIsSignature(zeroSignature))
        XCTAssertEqual(try signature(zeroSignature).rawValue, zeroSignature)

        for valid in [
            "5HkW5GttYoahVHaujuxEyfyq7RwvoKpc94ko5Fq9GuYdyhejg9cHcqm1MjEvHsjaADRe6hVBqB2E4RQgGgxeA2su",
            "2VZm7DkqSKaHxsGiAuVuSkvEbGWf7JrfRdPTw42WKuJC8qw7yQbGL5AE7UxHH3tprgmT9EVbambnK9h3PLpvMvES",
            "5sXRtm61WrRGRTjJ6f2anKUWt86Y4V9gWU4WUpue4T4Zh6zuvFoSyaX5LkEtChfqVC8oHdqLo2eUXbhVduThBdfG",
            "2Dy6Qai5JyChoP4BKoh9KAYhpD96CUhmEce1GJ8HpV5h8Q4CgUt8KZQzhVNDEQYcjARxYyBNhNjhKUGC2XLZtCCm",
        ] {
            XCTAssertTrue(isSignature(valid), valid)
            XCTAssertNoThrow(try assertIsSignature(valid), valid)
        }
    }

    func testBase58EncodedSignaturePreservesZeroBytesAndKnownBytes() throws {
        XCTAssertEqual(
            base58EncodedSignature(try SignatureBytes(Data(repeating: 0, count: 64))).rawValue,
            String(repeating: "1", count: 64)
        )

        let signatureBytes = try SignatureBytes(Data(hex: "426fb8e4efbd7f2e17a875453a8f84a470bdcbe4b7970017b3b5344b70e19680b8a4241565cd731c7fdd1887e50845e810e12ce511ecceae66cf4ffd6007ae0a"))
        XCTAssertEqual(
            base58EncodedSignature(signatureBytes).rawValue,
            "2L3KjHvkBYbmXpdwDwWzrkNUep4qUxpJ2g3gACpc1MfHDQ5ezcArStYTpyRx1iXTFHSCPXP8R3gGZBf8hDh8wtP3"
        )
    }

    func testBackendBasedOperationsUseReturnedBytesAndVerificationResult() throws {
        let privateBytes = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a")
        let publicBytes = Data(hex: "1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b5")
        let signatureBytes = Data(repeating: 9, count: 64)
        let backend = KeysDetailedBackend(
            keyPair: CryptoKeyPairBytes(privateKey: privateBytes, publicKey: publicBytes),
            signature: signatureBytes,
            verificationResult: false
        )

        let generated = try generateKeyPair(using: backend)
        XCTAssertEqual(generated.publicKey.rawValue, publicBytes)

        let fromPrivate = try createKeyPairFromPrivateKeyBytes(privateBytes, using: backend)
        XCTAssertEqual(fromPrivate.publicKey.rawValue, publicBytes)

        let publicKey = try getPublicKeyFromPrivateKey(fromPrivate.privateKey, using: backend)
        XCTAssertEqual(publicKey.rawValue, publicBytes)

        let signed = try signBytes(Data([1, 2, 3]), with: fromPrivate.privateKey, using: backend)
        XCTAssertEqual(signed.rawValue, signatureBytes)
        XCTAssertFalse(try verifySignature(signed, of: Data([1, 2, 3]), using: publicKey, backend: backend))
    }
}

private struct KeysDetailedBackend: CryptoBackend {
    let keyPair: CryptoKeyPairBytes
    let signature: Data
    let verificationResult: Bool

    func generateKeyPair() throws(KeysError) -> CryptoKeyPairBytes {
        keyPair
    }

    func createKeyPair(privateKeyBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        guard privateKeyBytes.count == 32 else {
            throw .invalidPrivateKeyByteLength(actualLength: privateKeyBytes.count)
        }
        return keyPair
    }

    func createKeyPair(solanaKeyPairBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        guard solanaKeyPairBytes.count == 64 else {
            throw .invalidKeyPairByteLength(byteLength: solanaKeyPairBytes.count)
        }
        return keyPair
    }

    func publicKey(privateKeyBytes: Data) throws(KeysError) -> Data {
        guard privateKeyBytes.count == 32 else {
            throw .invalidPrivateKeyByteLength(actualLength: privateKeyBytes.count)
        }
        return keyPair.publicKey
    }

    func sign(_ message: Data, privateKeyBytes: Data) throws(KeysError) -> Data {
        signature
    }

    func verify(signature: Data, message: Data, publicKeyBytes: Data) throws(KeysError) -> Bool {
        verificationResult
    }

    func sha256(_ data: Data) -> Data {
        data
    }

    func isOnCurve(_ compressedEdwardsY: Data) -> Bool {
        true
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
}
