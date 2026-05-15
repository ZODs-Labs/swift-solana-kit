import BalanceMacCore
import Kit
import XCTest

final class BalanceLookupServiceTests: XCTestCase {
    func testLookupParsesBalanceAndSlot() async throws {
        let expectedAddress = try address("11111111111111111111111111111111")
        let service = BalanceLookupService { address, endpoint in
            XCTAssertEqual(address, expectedAddress)
            XCTAssertEqual(endpoint.absoluteString, SolanaEndpoint.devnet.url.absoluteString)
            return .object([
                RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .bigint("42"))])),
                RpcJsonObjectMember("value", .bigint("2039280")),
            ])
        }

        let snapshot = try await service.lookup(addressText: expectedAddress.rawValue, endpoint: .devnet)

        XCTAssertEqual(snapshot.address, expectedAddress)
        XCTAssertEqual(snapshot.lamports, 2_039_280)
        XCTAssertEqual(snapshot.slot, 42)
        XCTAssertEqual(snapshot.solText, "0.00203928")
    }

    func testLookupRejectsInvalidAddressBeforeRpcCall() async {
        let service = BalanceLookupService { _, _ in
            XCTFail("RPC should not be called for an invalid address")
            return .null
        }

        await XCTAssertThrowsErrorAsync(try await service.lookup(addressText: "not-an-address", endpoint: .devnet)) { error in
            XCTAssertEqual(error as? BalanceLookupError, .invalidAddress("not-an-address"))
        }
    }

    func testLookupRejectsMalformedResponse() async throws {
        let service = BalanceLookupService { _, _ in
            .object([
                RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .bigint("42"))])),
                RpcJsonObjectMember("value", .string("not-a-number")),
            ])
        }

        await XCTAssertThrowsErrorAsync(try await service.lookup(addressText: "11111111111111111111111111111111", endpoint: .devnet)) { error in
            guard case .malformedResponse = error as? BalanceLookupError else {
                return XCTFail("Expected malformed response error")
            }
        }
    }

    func testSolDisplayStringUsesIntegerMath() {
        XCTAssertEqual(solDisplayString(from: 0), "0")
        XCTAssertEqual(solDisplayString(from: 1), "0.000000001")
        XCTAssertEqual(solDisplayString(from: 1_000_000_000), "1")
        XCTAssertEqual(solDisplayString(from: 2_039_280), "0.00203928")
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Sendable,
    _ handler: (any Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        handler(error)
    }
}
