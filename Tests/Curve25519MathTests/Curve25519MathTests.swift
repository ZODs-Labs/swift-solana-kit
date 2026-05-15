@testable import Curve25519Math
import SolanaErrors
import XCTest

final class Curve25519MathTests: XCTestCase {
    func testBasepointCompression() {
        XCTAssertEqual(
            EdwardsPoint.basepoint.multiplied(by: Data([1])).compressed().hex,
            "5866666666666666666666666666666666666666666666666666666666666666"
        )
    }

    func testPrivateSeedPublicKeyVector() {
        let seed = Data(hex: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a")
        XCTAssertEqual(
            try ed25519PublicKey(seed: seed).hex,
            "1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b5"
        )
    }

    func testDeterministicSignatureMatchesKnownVectors() throws {
        let vectors = [
            Ed25519SigningVector(
                seed: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
                publicKey: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
                message: "",
                signature: "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
            ),
            Ed25519SigningVector(
                seed: "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb",
                publicKey: "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
                message: "72",
                signature: "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
            ),
            Ed25519SigningVector(
                seed: "c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7",
                publicKey: "fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025",
                message: "af82",
                signature: "6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a"
            ),
            Ed25519SigningVector(
                seed: "ebfa65eb93dc79157abadea2f794379dfc071d688687376dc5d5a054121d344a",
                publicKey: "1d0e93864dcc815fc3f286180911d00a3fd206de31a1c94287cb43f05fc9f2b5",
                message: "010203",
                signature: "426fb8e4efbd7f2e17a875453a8f84a470bdcbe4b7970017b3b5344b70e19680b8a4241565cd731c7fdd1887e50845e810e12ce511ecceae66cf4ffd6007ae0a"
            )
        ]

        for vector in vectors {
            let signature = try ed25519DeterministicSignature(
                message: Data(hex: vector.message),
                privateKeySeed: Data(hex: vector.seed),
                publicKey: Data(hex: vector.publicKey)
            )
            XCTAssertEqual(signature.hex, vector.signature)
        }
    }

    func testDeterministicSignatureRejectsInvalidInputs() {
        XCTAssertThrowsError(
            try ed25519DeterministicSignature(
                message: Data(),
                privateKeySeed: Data(repeating: 0, count: 31),
                publicKey: Data(repeating: 0, count: 32)
            )
        ) { error in
            XCTAssertEqual((error as? KeysError)?.code, SolanaErrorCode.keysInvalidPrivateKeyByteLength.rawValue)
        }

        XCTAssertThrowsError(
            try ed25519DeterministicSignature(
                message: Data(),
                privateKeySeed: Data(repeating: 0, count: 32),
                publicKey: Data(repeating: 0, count: 31)
            )
        ) { error in
            XCTAssertEqual((error as? KeysError)?.code, SolanaErrorCode.keysPublicKeyMustMatchPrivateKey.rawValue)
        }
    }

    func testKnownCompressedPointsOnCurve() {
        let onCurvePoints = [
            "6b8d57af651bd83aee5fc1af1597cf661c6b9db2454dcb59c74da2131b6c399b",
            "345ea16d373ea40cb7a538705667136dc4215d2a8f06ddacad158260aa6552c8",
            "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        ].map(Data.init(hex:))

        for point in onCurvePoints {
            XCTAssertTrue(compressedEdwardsYIsOnCurve(point))
            XCTAssertTrue(isCompressedEdwardsYOnCurve(point))
        }
    }

    func testKnownCompressedPointsOffCurve() {
        let offCurvePoints = [
            "0079f082a61cc74ea5e2abed64bbf75f32fbdd537afff75257ed6716c9e37299",
            "c2dec53d44e1fcc69b96f72c2d0a73080c328a0c6ac74bac9f575e7afbf6884b"
        ].map(Data.init(hex:))

        for point in offCurvePoints {
            XCTAssertFalse(compressedEdwardsYIsOnCurve(point))
            XCTAssertFalse(isCompressedEdwardsYOnCurve(point))
        }
    }

    func testInvalidLengthIsOffCurve() {
        XCTAssertFalse(compressedEdwardsYIsOnCurve(Data([1, 2, 3])))
    }
}

private struct Ed25519SigningVector {
    let seed: String
    let publicKey: String
    let message: String
    let signature: String
}

private extension Data {
    init(hex: String) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
