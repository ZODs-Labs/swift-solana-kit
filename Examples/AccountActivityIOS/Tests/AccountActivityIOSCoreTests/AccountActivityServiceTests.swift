import AccountActivityIOSCore
import Kit
import XCTest

final class AccountActivityServiceTests: XCTestCase {
    func testLookupFetchesBalanceAndRecentSignatures() async throws {
        let expectedAddress = try address("11111111111111111111111111111111")
        let service = AccountActivityService(
            fetchBalance: { address, endpoint in
                XCTAssertEqual(address, expectedAddress)
                XCTAssertEqual(endpoint.absoluteString, ActivityEndpoint.mainnetBeta.url.absoluteString)
                return .object([
                    RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .bigint("42"))])),
                    RpcJsonObjectMember("value", .bigint("2039280")),
                ])
            },
            fetchSignatures: { address, limit, endpoint in
                XCTAssertEqual(address, expectedAddress)
                XCTAssertEqual(limit, 10)
                XCTAssertEqual(endpoint.absoluteString, ActivityEndpoint.mainnetBeta.url.absoluteString)
                return .array([
                    .object([
                        RpcJsonObjectMember("signature", .string("5h6s9V9pJ1MRcW8Q8V9gN9HxT2dV1aM7bC3sK2pQ1zYx")),
                        RpcJsonObjectMember("slot", .bigint("41")),
                        RpcJsonObjectMember("err", .null),
                        RpcJsonObjectMember("memo", .null),
                        RpcJsonObjectMember("blockTime", .bigint("1710000000")),
                        RpcJsonObjectMember("confirmationStatus", .string("confirmed")),
                    ]),
                    .object([
                        RpcJsonObjectMember("signature", .string("4y3s9V9pJ1MRcW8Q8V9gN9HxT2dV1aM7bC3sK2pQ1zZa")),
                        RpcJsonObjectMember("slot", .bigint("40")),
                        RpcJsonObjectMember("err", .object([RpcJsonObjectMember("InstructionError", .array([.bigint("0"), .string("Custom")]))])),
                        RpcJsonObjectMember("memo", .string("memo text")),
                        RpcJsonObjectMember("blockTime", .null),
                        RpcJsonObjectMember("confirmationStatus", .string("finalized")),
                    ]),
                ])
            }
        )

        let snapshot = try await service.lookup(addressText: expectedAddress.rawValue, endpoint: .mainnetBeta, limit: 10)

        XCTAssertEqual(snapshot.address, expectedAddress)
        XCTAssertEqual(snapshot.lamports, 2_039_280)
        XCTAssertEqual(snapshot.solText, "0.00203928")
        XCTAssertEqual(snapshot.slot, 42)
        XCTAssertEqual(snapshot.signatures.count, 2)
        XCTAssertEqual(snapshot.signatures[0].statusText, "Confirmed")
        XCTAssertTrue(snapshot.signatures[0].isSuccessful)
        XCTAssertEqual(snapshot.signatures[1].statusText, "Failed")
        XCTAssertFalse(snapshot.signatures[1].isSuccessful)
        XCTAssertEqual(snapshot.signatures[1].memo, "memo text")
    }

    func testInvalidAddressDoesNotCallRpc() async {
        let service = AccountActivityService(
            fetchBalance: { _, _ in
                XCTFail("getBalance should not be called")
                return .null
            },
            fetchSignatures: { _, _, _ in
                XCTFail("getSignaturesForAddress should not be called")
                return .null
            }
        )

        await XCTAssertThrowsErrorAsync(try await service.lookup(addressText: "bad", endpoint: .mainnetBeta, limit: 10)) { error in
            XCTAssertEqual(error as? ActivityLookupError, .invalidAddress("bad"))
        }
    }

    func testInvalidLimitDoesNotCallRpc() async {
        let service = AccountActivityService(
            fetchBalance: { _, _ in
                XCTFail("getBalance should not be called")
                return .null
            },
            fetchSignatures: { _, _, _ in
                XCTFail("getSignaturesForAddress should not be called")
                return .null
            }
        )

        await XCTAssertThrowsErrorAsync(try await service.lookup(addressText: "11111111111111111111111111111111", endpoint: .mainnetBeta, limit: 0)) { error in
            XCTAssertEqual(error as? ActivityLookupError, .invalidLimit(0))
        }
    }

    func testMalformedSignatureResponseIsRejected() async {
        let service = AccountActivityService(
            fetchBalance: { _, _ in
                .object([
                    RpcJsonObjectMember("context", .object([RpcJsonObjectMember("slot", .bigint("42"))])),
                    RpcJsonObjectMember("value", .bigint("2039280")),
                ])
            },
            fetchSignatures: { _, _, _ in
                .object([RpcJsonObjectMember("value", .null)])
            }
        )

        await XCTAssertThrowsErrorAsync(try await service.lookup(addressText: "11111111111111111111111111111111", endpoint: .mainnetBeta, limit: 10)) { error in
            guard case .malformedResponse = error as? ActivityLookupError else {
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
