import AirdropIOSCore
import Kit
import XCTest

final class AirdropRequestServiceTests: XCTestCase {
    func testRequestAirdropParsesSignatureAndBalance() async throws {
        let expectedAddress = try address("11111111111111111111111111111111")
        let service = AirdropRequestService(
            requestAirdrop: { address, lamports, endpoint in
                XCTAssertEqual(address, expectedAddress)
                XCTAssertEqual(lamports, 500_000_000)
                XCTAssertEqual(endpoint.absoluteString, AirdropEndpoint.devnet.url.absoluteString)
                return .string("3mJr7AoUXx2Wqd")
            },
            fetchBalance: { address, endpoint in
                XCTAssertEqual(address, expectedAddress)
                XCTAssertEqual(endpoint.absoluteString, AirdropEndpoint.devnet.url.absoluteString)
                return .object([
                    RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .bigint("77"))])),
                    RpcJsonObjectMember("value", .bigint("1500000000")),
                ])
            }
        )

        let result = try await service.request(addressText: expectedAddress.rawValue, solAmountText: "0.5")

        XCTAssertEqual(result.address, expectedAddress)
        XCTAssertEqual(result.requestedLamports, 500_000_000)
        XCTAssertEqual(result.requestedSolText, "0.5")
        XCTAssertEqual(result.signature.rawValue, "3mJr7AoUXx2Wqd")
        XCTAssertEqual(result.balanceAfterLamports, 1_500_000_000)
        XCTAssertEqual(result.balanceSlot, 77)
    }

    func testInvalidAddressDoesNotCallRpc() async {
        let service = AirdropRequestService(
            requestAirdrop: { _, _, _ in
                XCTFail("requestAirdrop should not be called")
                return .null
            },
            fetchBalance: { _, _ in
                XCTFail("getBalance should not be called")
                return .null
            }
        )

        await XCTAssertThrowsErrorAsync(try await service.request(addressText: "bad", solAmountText: "1")) { error in
            XCTAssertEqual(error as? AirdropRequestError, .invalidAddress("bad"))
        }
    }

    func testAmountLimitIsEnforcedBeforeRpcCall() async {
        let service = AirdropRequestService(
            requestAirdrop: { _, _, _ in
                XCTFail("requestAirdrop should not be called")
                return .null
            },
            fetchBalance: { _, _ in
                XCTFail("getBalance should not be called")
                return .null
            }
        )

        await XCTAssertThrowsErrorAsync(try await service.request(addressText: "11111111111111111111111111111111", solAmountText: "3")) { error in
            XCTAssertEqual(error as? AirdropRequestError, .amountExceedsLimit(requested: 3_000_000_000, limit: 2_000_000_000))
        }
    }

    func testInvalidAmountIsRejected() throws {
        let service = AirdropRequestService()

        XCTAssertThrowsError(try service.lamportsFromSolText("abc")) { error in
            XCTAssertEqual(error as? AirdropRequestError, .invalidAmount("abc"))
        }
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
