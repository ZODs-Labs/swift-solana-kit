import Foundation
import Promises
import RpcSpec
import RpcSpecTypes
@testable import RpcTransportHttp
import SolanaErrors
import XCTest

final class RpcTransportHttpTests: XCTestCase {
    func testHeaderValidationMatchesForbiddenRuntimeSet() {
        XCTAssertThrowsError(try assertIsAllowedHttpRequestHeaders(["Sec-Fetch-Mode": "no-cors"])) { error in
            XCTAssertEqual((error as? RpcError)?.code, SolanaErrorCode.rpcTransportHTTPHeaderForbidden.rawValue)
            XCTAssertEqual((error as? RpcError)?.context["headers"], .stringArray(["Sec-Fetch-Mode"]))
        }
        XCTAssertNoThrow(try assertIsAllowedHttpRequestHeaders(["Authorization": "Bearer token"]))
        XCTAssertNoThrow(try assertIsAllowedHttpRequestHeaders(["Solana-Client": "swift/test"]))
    }

    func testNormalizeHeadersLowercasesNames() {
        XCTAssertEqual(normalizeHeaders(["Authorization": "Bearer token"]), ["authorization": "Bearer token"])
        let normalized = normalizeHeaders(["X-Test": "A", "x-test": "B"])
        XCTAssertEqual(Array(normalized.keys), ["x-test"])
        XCTAssertTrue(["A", "B"].contains(normalized["x-test"]))
    }

    func testCreateHttpTransportHeaderValidationFollowsBuildMode() {
        let config = HttpTransportConfig(
            url: URL(string: "http://127.0.0.1:9")!,
            headers: ["sEc-FeTcH-mOdE": "no-cors"]
        )
        #if DEBUG
        XCTAssertThrowsError(try createHttpTransport(config)) { error in
            XCTAssertEqual((error as? RpcError)?.code, SolanaErrorCode.rpcTransportHTTPHeaderForbidden.rawValue)
        }
        #else
        XCTAssertNoThrow(try createHttpTransport(config))
        #endif
    }

    func testIsSolanaRequestChecksJsonRpcPayloadAndMethodList() {
        XCTAssertTrue(isSolanaRequest(.object([
            ("jsonrpc", .string("2.0")),
            ("method", .string("getBalance")),
            ("params", .array([])),
        ].map(RpcJsonObjectMember.init))))
        XCTAssertFalse(isSolanaRequest(.object([
            ("jsonrpc", .string("2.0")),
            ("method", .string("getAssetsByAuthority")),
            ("params", .array([])),
        ].map(RpcJsonObjectMember.init))))
    }

    func testSolanaTransportJsonHooksOnlyUseBigintsForSolanaMethods() throws {
        let solanaPayload = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("id", .number(1)),
            ("method", .string("getBalance")),
            ("params", .array([.bigint("9007199254740993")])),
        ])
        let otherPayload = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("id", .number(1)),
            ("method", .string("notSolana")),
            ("params", .array([.number(Double("9007199254740993") ?? 0)])),
        ])

        XCTAssertEqual(
            try stringifyJsonWithBigInts(solanaPayload),
            #"{"jsonrpc":"2.0","id":1,"method":"getBalance","params":[9007199254740993]}"#
        )
        XCTAssertEqual(
            try stringifyJson(otherPayload),
            #"{"jsonrpc":"2.0","id":1,"method":"notSolana","params":[9007199254740992]}"#
        )

        let solanaResponse = try parseJsonWithBigInts(#"{"result":9007199254740993}"#)
        let otherResponse = try parseJson(#"{"result":9007199254740993}"#)
        XCTAssertEqual(solanaResponse.value(for: "result"), .bigint("9007199254740993"))
        XCTAssertEqual(otherResponse.value(for: "result"), .number(9_007_199_254_740_992))
    }

    func testHttpContentLengthUsesJavaScriptStringLength() throws {
        let payload = "\u{00AF}\\_\u{0028}\u{30C4}\u{0029}_/\u{00AF} \u{1F44B}\u{1F3FD} \u{1F469}\u{1F3FB}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F469}\u{1F3FF}"
        let body = try stringifyJson(.string(payload))

        XCTAssertEqual(httpContentLengthHeaderValue(for: body), "30")
        XCTAssertNotEqual(httpContentLengthHeaderValue(for: body), String(Data(body.utf8).count))
    }

    func testDefaultHttpTransportUsesPlainJsonSerialization() async throws {
        let transport = try createHttpTransport(
            HttpTransportConfig(url: URL(string: "http://127.0.0.1:9")!)
        )
        let payload = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("id", .number(1)),
            ("method", .string("notSolana")),
            ("params", .array([.bigint("42")])),
        ])

        do {
            _ = try await transport(RpcTransportConfig(payload: payload))
            XCTFail("Expected plain JSON serialization to reject bigint values")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.malformedJSONRPCError.rawValue)
        }
    }

    func testHttpTransportHonorsAlreadyAbortedSignalBeforeNetworkWork() async throws {
        let transport = try createHttpTransport(
            HttpTransportConfig(url: URL(string: "http://127.0.0.1:9")!)
        )
        let signal = AbortSignal(abortedWith: AbortError(reason: "cancelled"))
        let payload = RpcJsonValue.object([
            ("jsonrpc", .string("2.0")),
            ("id", .number(1)),
            ("method", .string("getBalance")),
            ("params", .array([])),
        ])

        do {
            _ = try await transport(RpcTransportConfig(payload: payload, abortSignal: signal))
            XCTFail("Expected abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "cancelled")
        }
    }
}
