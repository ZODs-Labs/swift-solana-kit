import Foundation
import XCTest

final class OracleFullTests: XCTestCase {
    func testPhaseOneFixtureCorpusIsPresentAndPinned() throws {
        let expectations = [
            "errors.generated.json": ("solanaErrors", 308),
            "codecs-core.generated.json": ("codecsCore", 30),
            "keys-crypto.generated.json": ("keysCrypto", 16),
            "curve25519.generated.json": ("curve25519", 6)
        ]

        for (filename, expected) in expectations {
            let document: OracleDocument = try OracleFixtures.load(filename)
            XCTAssertEqual(document.pinnedReference, OracleFixtures.pin, filename)
            XCTAssertEqual(document.kind, expected.0, filename)
            XCTAssertEqual(document.cases.count, expected.1, filename)
            XCTAssertFalse(document.upstreamSources.isEmpty, filename)
            XCTAssertTrue(document.cases.allSatisfy { !$0.id.isEmpty }, filename)
        }
    }
}

private struct OracleFixtures {
    static let pin = "b4542070c3a092558ee5e716c15f652e826fbc71"

    static func load<T: Decodable>(_ filename: String, filePath: String = #filePath) throws -> T {
        var url = URL(fileURLWithPath: filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.appendPathComponent("Oracle/Fixtures/Phase1")
        url.appendPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct OracleDocument: Decodable {
    let schemaVersion: Int
    let pinnedReference: String
    let kind: String
    let upstreamSources: [String]
    let cases: [OracleCase]
}

private struct OracleCase: Decodable {
    let id: String
}
