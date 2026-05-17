import Addresses
import CodecsCore
import CryptoBackend
import Foundation
import SolanaErrors
import XCTest

final class AddressesDetailedBehaviorTests: XCTestCase {
    func testAddressCodableRoundTripsAndRejectsInvalidDecodedStrings() throws {
        let value = try address("11111111111111111111111111111111")
        let encoded = try JSONEncoder().encode(value)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"11111111111111111111111111111111\"")
        XCTAssertEqual(try JSONDecoder().decode(Address.self, from: encoded), value)

        XCTAssertThrowsError(try JSONDecoder().decode(Address.self, from: Data("\"short\"".utf8))) { error in
            XCTAssertEqual(error as? AddressValidationError, .addresses(.stringLengthOutOfRange(actualLength: 5)))
        }
    }

    func testAddressValidationExposesExactWrappedErrorContexts() throws {
        XCTAssertThrowsError(try assertIsAddress(String(repeating: "1", count: 31))) { error in
            XCTAssertEqual(error as? AddressValidationError, .addresses(.stringLengthOutOfRange(actualLength: 31)))
            XCTAssertEqual((error as? AddressValidationError)?.contextDescription, "actualLength=31")
        }

        let invalidBase = "11111111111111111111111111111110"
        XCTAssertThrowsError(try assertIsAddress(invalidBase)) { error in
            XCTAssertEqual(
                error as? AddressValidationError,
                .codecs(
                    .invalidStringForBase(
                        value: invalidBase,
                        base: 58,
                        alphabet: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
                    )
                )
            )
        }

        let invalidLength = "JJEfe6DcPM2ziB2vfUWDV6aHVerXRGkv3TcyvJUNGHZz"
        XCTAssertThrowsError(try assertIsAddress(invalidLength)) { error in
            XCTAssertEqual(error as? AddressValidationError, .addresses(.invalidByteLength(actualLength: 33)))
        }
    }

    func testAddressCodecPreservesOffsetsForReadsAndWrites() throws {
        let codec = getAddressCodec()
        let value = try address("11111111111111111111111111111111")
        var bytes = Data(repeating: 0xee, count: 36)

        let writeOffset = try codec.write(value, into: &bytes, at: 2)
        XCTAssertEqual(writeOffset, 34)
        XCTAssertEqual(bytes.prefix(2), Data([0xee, 0xee]))
        XCTAssertEqual(bytes.dropFirst(2).prefix(32), Data(repeating: 0, count: 32))
        XCTAssertEqual(bytes.suffix(2), Data([0xee, 0xee]))

        let read = try codec.read(Data([0xaa, 0xbb] + Array(repeating: 0, count: 32) + [0xcc]), at: 2)
        XCTAssertEqual(read.0.rawValue, value.rawValue)
        XCTAssertEqual(read.1, 34)
    }

    func testPublicKeyAddressConversionsRejectInvalidLengthsAndRoundTripZeroBytes() throws {
        let zeroAddress = try getAddressFromPublicKey(Data(repeating: 0, count: 32))
        XCTAssertEqual(zeroAddress.rawValue, "11111111111111111111111111111111")
        XCTAssertEqual(try getPublicKeyFromAddress(zeroAddress), Data(repeating: 0, count: 32))

        for length in [0, 31, 33] {
            XCTAssertThrowsError(try getAddressFromPublicKey(Data(repeating: 1, count: length)), "length \(length)") { error in
                XCTAssertEqual(error as? AddressError, .invalidEd25519PublicKey)
            }
        }
    }

    func testOffCurveAddressUsesBackendCurveDecision() throws {
        let value = try address("11111111111111111111111111111111")
        let offCurveBackend = AddressesDetailedBackend(curveResult: false)
        let onCurveBackend = AddressesDetailedBackend(curveResult: true)

        XCTAssertTrue(isOffCurveAddress(value, using: offCurveBackend))
        XCTAssertEqual(try offCurveAddress(value, using: offCurveBackend).rawValue, value.rawValue)
        XCTAssertFalse(isOffCurveAddress(value, using: onCurveBackend))
        XCTAssertThrowsError(try assertIsOffCurveAddress(value, using: onCurveBackend)) { error in
            XCTAssertEqual(error as? AddressError, .invalidOffCurveAddress)
        }
    }

    func testProgramDerivedAddressFailsWhenEveryBumpIsOnCurve() throws {
        let backend = AddressesDetailedBackend(curveResult: true)

        XCTAssertThrowsError(
            try getProgramDerivedAddress(
                programAddress: try address("11111111111111111111111111111111"),
                seeds: [],
                using: backend
            )
        ) { error in
            XCTAssertEqual(error as? AddressError, .failedToFindViablePDABumpSeed)
        }
    }
}

private struct AddressesDetailedBackend: CryptoBackend {
    let curveResult: Bool

    func generateKeyPair() throws(KeysError) -> CryptoKeyPairBytes {
        CryptoKeyPairBytes(privateKey: Data(repeating: 0, count: 32), publicKey: Data(repeating: 0, count: 32))
    }

    func createKeyPair(privateKeyBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        CryptoKeyPairBytes(privateKey: privateKeyBytes, publicKey: Data(repeating: 0, count: 32))
    }

    func createKeyPair(solanaKeyPairBytes: Data) throws(KeysError) -> CryptoKeyPairBytes {
        CryptoKeyPairBytes(
            privateKey: Data(solanaKeyPairBytes.prefix(32)),
            publicKey: Data(solanaKeyPairBytes.dropFirst(32).prefix(32))
        )
    }

    func publicKey(privateKeyBytes: Data) throws(KeysError) -> Data {
        Data(repeating: 0, count: 32)
    }

    func sign(_ message: Data, privateKeyBytes: Data) throws(KeysError) -> Data {
        Data(repeating: 0, count: 64)
    }

    func verify(signature: Data, message: Data, publicKeyBytes: Data) throws(KeysError) -> Bool {
        true
    }

    func sha256(_ data: Data) -> Data {
        Data(repeating: 1, count: 32)
    }

    func isOnCurve(_ compressedEdwardsY: Data) -> Bool {
        curveResult
    }
}
