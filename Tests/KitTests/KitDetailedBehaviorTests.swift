import Foundation
import Kit
import os
import XCTest

final class KitDetailedBehaviorTests: XCTestCase {
    func testEstimateComputeUnitLimitCapsLargeResponsesAndReportsSimulationFailures() async throws {
        let cappedRpc = kitDetailedRawRpc(responses: [
            .object([
                ("value", .object([
                    ("err", .null),
                    ("unitsConsumed", .bigint(String(UInt64(UInt32.max) + 1))),
                ])),
            ]),
        ])
        let cappedEstimate = estimateComputeUnitLimitFactory(EstimateComputeUnitLimitFactoryConfig(rpc: cappedRpc.rpc))
        let cappedUnits = try await cappedEstimate(try kitDetailedBlockhashMessage(), nil)
        XCTAssertEqual(cappedUnits, UInt32.max)

        let failedRpc = kitDetailedRawRpc(responses: [
            .object([
                ("value", .object([
                    ("err", .string("BlockhashNotFound")),
                    ("logs", .array([.string("failed")])),
                    ("unitsConsumed", .number(55)),
                ])),
            ]),
        ])
        let failedEstimate = estimateComputeUnitLimitFactory(EstimateComputeUnitLimitFactoryConfig(rpc: failedRpc.rpc))
        do {
            _ = try await failedEstimate(try kitDetailedBlockhashMessage(), nil)
            XCTFail("Expected simulation failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionFailedWhenSimulatingToEstimateComputeLimit.rawValue)
            XCTAssertEqual(error.context["unitsConsumed"], .int(55))
            XCTAssertEqual(error.context["logs"], .array([.string("failed")]))
            guard case let .object(cause)? = error.context["cause"] else {
                return XCTFail("Expected cause context")
            }
            XCTAssertEqual(cause["code"], .int(SolanaErrorCode.transactionErrorBlockhashNotFound.rawValue))
        }
    }

    func testEstimateComputeUnitLimitUsesDurableNonceReplacementRules() async throws {
        let rpc = kitDetailedRawRpc(responses: [
            .object([
                ("value", .object([
                    ("err", .null),
                    ("unitsConsumed", .number(1_234)),
                ])),
            ]),
        ])
        let estimate = estimateComputeUnitLimitFactory(EstimateComputeUnitLimitFactoryConfig(rpc: rpc.rpc))

        let units = try await estimate(try kitDetailedNonceMessage(), EstimateComputeUnitLimitConfig(commitment: .processed))

        let recordedPayload = await rpc.recorder.payload(at: 0)
        let payload = try XCTUnwrap(recordedPayload)
        let params = try kitDetailedRpcParams(from: payload)
        let config = try XCTUnwrap(params.dropFirst().first)
        XCTAssertEqual(units, 1_234)
        XCTAssertEqual(config.value(for: "commitment"), .string("processed"))
        XCTAssertEqual(config.value(for: "replaceRecentBlockhash"), .bool(false))
        XCTAssertEqual(config.value(for: "sigVerify"), .bool(false))
    }

    func testEstimateAndSetComputeUnitLimitOnlyUpdatesUnsetProvisoryAndMaximumValues() async throws {
        let base = try kitDetailedBlockhashMessage()
        let estimatorCalls = OSAllocatedUnfairLock(initialState: 0)
        let estimator: EstimateComputeUnitLimitFunction = { _, _ in
            estimatorCalls.withLock { $0 += 1 }
            return 42
        }
        let estimateAndSet = estimateAndSetComputeUnitLimitFactory(estimator)

        let filled = try fillTransactionMessageProvisoryComputeUnitLimit(base)
        let fromUnset = try await estimateAndSet(base, nil)
        let fromProvisory = try await estimateAndSet(try setTransactionMessageComputeUnitLimit(0, base), nil)
        let fromMaximum = try await estimateAndSet(try setTransactionMessageComputeUnitLimit(1_400_000, base), nil)

        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(filled), 0)
        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(fromUnset), 42)
        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(fromProvisory), 42)
        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(fromMaximum), 42)

        let explicit = try setTransactionMessageComputeUnitLimit(123_456, base)
        let unchanged = try await estimateAndSet(explicit, nil)
        XCTAssertEqual(unchanged, explicit)
        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(unchanged), 123_456)
        XCTAssertEqual(estimatorCalls.withLock { $0 }, 3)
    }

    func testFetchAddressesForLookupTablesHandlesEmptyMalformedAndMissingResponses() async throws {
        let emptyRpc = kitDetailedRawRpc(responses: [])
        let empty = try await fetchAddressesForLookupTables(lookupTableAddresses: [], rpc: emptyRpc.rpc)
        XCTAssertTrue(empty.isEmpty)
        let emptyPayload = await emptyRpc.recorder.payload(at: 0)
        XCTAssertNil(emptyPayload)

        let lookupTable = try address("AddressLookupTab1e1111111111111111111111111")
        let malformedRpc = kitDetailedRawRpc(responses: [
            .object([
                ("value", .array([
                    .object([
                        ("executable", .bool(false)),
                    ]),
                ])),
            ]),
        ])
        await kitDetailedAssertThrowsCode(.malformedJSONRPCError) {
            _ = try await fetchAddressesForLookupTables(lookupTableAddresses: [lookupTable], rpc: malformedRpc.rpc)
        }

        let missingRpc = kitDetailedRawRpc(responses: [
            .object([
                ("value", .array([.null])),
            ]),
        ])
        do {
            _ = try await fetchAddressesForLookupTables(lookupTableAddresses: [lookupTable], rpc: missingRpc.rpc)
            XCTFail("Expected missing account failure")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.accountsOneOrMoreAccountsNotFound.rawValue)
            XCTAssertEqual(error.context["addresses"], .stringArray([lookupTable.rawValue]))
        }
    }
}

private actor KitDetailedRpcCallRecorder {
    private var payloads: [RpcJsonValue] = []
    private var responses: [RpcJsonValue]

    init(responses: [RpcJsonValue]) {
        self.responses = responses
    }

    func transport(_ config: RpcTransportConfig) throws -> RpcJsonValue {
        payloads.append(config.payload)
        guard !responses.isEmpty else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return responses.removeFirst()
    }

    func payload(at index: Int) -> RpcJsonValue? {
        guard payloads.indices.contains(index) else {
            return nil
        }
        return payloads[index]
    }
}

private func kitDetailedRawRpc(responses: [RpcJsonValue]) -> (rpc: SolanaRpc, recorder: KitDetailedRpcCallRecorder) {
    let recorder = KitDetailedRpcCallRecorder(responses: responses)
    let rpc = SolanaRpc(
        api: SolanaRpcApi(api: createJsonRpcApi()),
        transport: { config in
            try await recorder.transport(config)
        }
    )
    return (rpc, recorder)
}

private func kitDetailedBlockhashMessage() throws -> TransactionMessage {
    let feePayer = try address("22222222222222222222222222222222222222222222")
    return setTransactionMessageLifetimeUsingBlockhash(
        BlockhashLifetimeConstraint(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 42),
        setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
    )
}

private func kitDetailedNonceMessage() throws -> TransactionMessage {
    let feePayer = try address("22222222222222222222222222222222222222222222")
    let nonceAccount = try address("33333333333333333333333333333333333333333333")
    let nonceAuthority = try address("44444444444444444444444444444444444444444444")
    let base = setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
    return setTransactionMessageLifetimeUsingDurableNonce(
        DurableNonceConfig(
            nonce: "11111111111111111111111111111111",
            nonceAccountAddress: nonceAccount,
            nonceAuthorityAddress: nonceAuthority
        ),
        base
    )
}

private func kitDetailedRpcParams(
    from payload: RpcJsonValue,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> [RpcJsonValue] {
    let paramsValue = try XCTUnwrap(payload.value(for: "params"), file: file, line: line)
    guard case let .array(params) = paramsValue else {
        XCTFail("Expected RPC params array", file: file, line: line)
        return []
    }
    return params
}

private func kitDetailedAssertThrowsCode(
    _ code: SolanaErrorCode,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> Void
) async {
    do {
        try await body()
        XCTFail("Expected error code \(code.rawValue)", file: file, line: line)
    } catch let error as any SolanaErrorCoded {
        XCTAssertEqual(error.code, code.rawValue, file: file, line: line)
    } catch {
        XCTFail("Expected SolanaErrorCoded, got \(error)", file: file, line: line)
    }
}

private extension RpcJsonValue {
    func value(for key: String) -> RpcJsonValue? {
        guard case let .object(members) = self else {
            return nil
        }
        return members.first { $0.key == key }?.value
    }
}
