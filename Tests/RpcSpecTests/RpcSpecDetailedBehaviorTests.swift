import Promises
import RpcSpec
import RpcSpecTypes
import XCTest

final class RpcSpecDetailedBehaviorTests: XCTestCase {
    func testJsonRpcPayloadRejectsEveryNonObjectAndMissingRequiredFieldShape() {
        let nonObjects: [RpcJsonValue] = [
            .null,
            .bool(true),
            .bool(false),
            .array([]),
            .string("o hai"),
            .number(123),
            .bigint("123"),
        ]

        for value in nonObjects {
            XCTAssertFalse(isJsonRpcPayload(value))
        }

        XCTAssertFalse(isJsonRpcPayload(.object([RpcJsonObjectMember]())))
        XCTAssertFalse(isJsonRpcPayload(.object([
            RpcJsonObjectMember("jsonrpc", .string("2.0")),
            RpcJsonObjectMember("params", .array([.number(123)])),
        ])))
        XCTAssertFalse(isJsonRpcPayload(.object([
            RpcJsonObjectMember("jsonrpc", .string("2.0")),
            RpcJsonObjectMember("method", .string("getFoo")),
        ])))
        XCTAssertFalse(isJsonRpcPayload(.object([
            RpcJsonObjectMember("jsonrpc", .string("2.0")),
            RpcJsonObjectMember("method", .number(1)),
            RpcJsonObjectMember("params", .array([.number(123)])),
        ])))
    }

    func testJsonRpcPayloadAcceptsNullParamsAndLastDuplicateMembers() {
        XCTAssertTrue(isJsonRpcPayload(.object([
            RpcJsonObjectMember("jsonrpc", .string("1.0")),
            RpcJsonObjectMember("jsonrpc", .string("2.0")),
            RpcJsonObjectMember("method", .number(1)),
            RpcJsonObjectMember("method", .string("getFoo")),
            RpcJsonObjectMember("params", .null),
        ])))
    }

    func testResponseTransformerReceivesTheTransformedRequest() async throws {
        let api = createJsonRpcApi(
            config: RpcApiConfig(
                requestTransformer: { request in
                    RpcRequest(methodName: "\(request.methodName)Transformed", params: .array([.number(2)]))
                },
                responseTransformer: RpcResponseTransformer { response, request in
                    .object([
                        RpcJsonObjectMember("method", .string(request.methodName)),
                        RpcJsonObjectMember("params", request.params),
                        RpcJsonObjectMember("response", response),
                    ])
                }
            )
        )

        let result = try await api.plan(methodName: "someMethod", params: [.number(1)])
            .execute(transport: { _ in .string("ok") })

        XCTAssertEqual(result.value(for: "method"), .string("someMethodTransformed"))
        XCTAssertEqual(result.value(for: "params"), .array([.number(2)]))
        XCTAssertEqual(result.value(for: "response"), .string("ok"))
    }

    func testRequestTransformerFailurePreventsTransportExecution() async {
        let api = createJsonRpcApi(config: RpcApiConfig(requestTransformer: { _ in throw RpcSpecTestError() }))

        do {
            _ = try api.plan(methodName: "someMethod", params: [])
            XCTFail("Expected request transformer failure")
        } catch {
            XCTAssertTrue(error is RpcSpecTestError)
        }
    }

    func testRpcRequestBuilderCreatesPendingRequestsThatReuseTheConfiguredTransport() async throws {
        let recorder = RpcSpecTransportRecorder()
        let rpc = createRpc(api: createJsonRpcApi(), transport: { config in
            await recorder.record(config)
            return .string("ok")
        })
        let signal = AbortSignal()

        let result = try await rpc.request("someMethod", params: [.string("value")]).send(abortSignal: signal)

        XCTAssertEqual(result, .string("ok"))
        let payload = await recorder.payloads.first
        XCTAssertEqual(payload?.value(for: "jsonrpc"), .string("2.0"))
        XCTAssertEqual(payload?.value(for: "method"), .string("someMethod"))
        XCTAssertEqual(payload?.value(for: "params"), .array([.string("value")]))
        let capturedSignal = await recorder.abortSignals.first ?? nil
        XCTAssertTrue(capturedSignal === signal)
    }
}

private struct RpcSpecTestError: Error {}

private actor RpcSpecTransportRecorder {
    private(set) var payloads: [RpcJsonValue] = []
    private(set) var abortSignals: [AbortSignal?] = []

    func record(_ config: RpcTransportConfig) {
        payloads.append(config.payload)
        abortSignals.append(config.abortSignal)
    }
}
