import CryptoBackend
import XCTest

final class CryptoBackendTests: XCTestCase {
    func testKeyPairBytesExposeSolanaLayout() {
        let keyPair = CryptoKeyPairBytes(privateKey: Data(repeating: 1, count: 32), publicKey: Data(repeating: 2, count: 32))
        XCTAssertEqual(keyPair.solanaKeyPairBytes.count, 64)
        XCTAssertEqual(keyPair.solanaKeyPairBytes.prefix(32), Data(repeating: 1, count: 32))
        XCTAssertEqual(keyPair.solanaKeyPairBytes.suffix(32), Data(repeating: 2, count: 32))
    }
}
