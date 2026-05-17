import Foundation
import Promises
import RpcSpec
import RpcSpecTypes
@testable import RpcTransportHttp
import SolanaErrors
import XCTest
import os

final class RpcTransportHttpDetailedBehaviorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RpcTransportHttpURLProtocol.reset()
        URLProtocol.registerClass(RpcTransportHttpURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(RpcTransportHttpURLProtocol.self)
        RpcTransportHttpURLProtocol.reset()
        super.tearDown()
    }

    func testHttpTransportSendsPostRequestWithJsonHeadersAndCustomBody() async throws {
        RpcTransportHttpURLProtocol.setResponse(statusCode: 200, headers: ["Content-Type": "application/json"], body: #"{"ok":true}"#)
        let payload = RpcJsonValue.object([("foo", .number(123))])
        let transport = try createHttpTransport(
            HttpTransportConfig(
                url: rpcTransportHttpURL(),
                headers: ["Authorization": "Bearer token", "Solana-Client": "swift/test"],
                toJson: { value in
                    XCTAssertEqual(value, payload)
                    return #"{"custom":"body"}"#
                }
            )
        )

        _ = try await transport(RpcTransportConfig(payload: payload))

        let request = try XCTUnwrap(RpcTransportHttpURLProtocol.requests().first)
        XCTAssertEqual(request.url, rpcTransportHttpURL())
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.header("accept"), "application/json")
        XCTAssertEqual(request.header("content-type"), "application/json; charset=utf-8")
        XCTAssertEqual(request.header("content-length"), "17")
        XCTAssertEqual(request.header("authorization"), "Bearer token")
        XCTAssertEqual(request.header("solana-client"), "swift/test")
        XCTAssertEqual(request.bodyString, #"{"custom":"body"}"#)
    }

    func testHttpTransportUsesCustomResponseParserWithRawBodyAndOriginalPayload() async throws {
        RpcTransportHttpURLProtocol.setResponse(statusCode: 200, body: #"{"result":456}"#)
        let payload = RpcJsonValue.object([("foo", .number(123))])
        let transport = try createHttpTransport(
            HttpTransportConfig(
                url: rpcTransportHttpURL(),
                fromJson: { rawResponse, originalPayload in
                    XCTAssertEqual(rawResponse, #"{"result":456}"#)
                    XCTAssertEqual(originalPayload, payload)
                    return .object([("parsed", .bool(true))])
                }
            )
        )

        let response = try await transport(RpcTransportConfig(payload: payload))

        XCTAssertEqual(response.value(for: "parsed"), .bool(true))
    }

    func testHttpTransportReportsHttpStatusAndHeadersWithoutParsingBody() async throws {
        RpcTransportHttpURLProtocol.setResponse(statusCode: 404, headers: ["Sekrit-Response-Header": "doNotLog"], body: #"{"ignored":true}"#)
        let transport = try createHttpTransport(HttpTransportConfig(url: rpcTransportHttpURL()))

        do {
            _ = try await transport(RpcTransportConfig(payload: .number(123)))
            XCTFail("Expected HTTP error")
        } catch let error as RpcError {
            XCTAssertEqual(error.code, SolanaErrorCode.rpcTransportHTTPError.rawValue)
            XCTAssertEqual(error.context["statusCode"], .int(404))
            XCTAssertEqual(error.context["headers"], .object(["Sekrit-Response-Header": .string("doNotLog")]))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHttpTransportRejectsNonUtf8ResponseBodies() async throws {
        RpcTransportHttpURLProtocol.setResponse(statusCode: 200, bodyData: Data([0xff, 0xfe]))
        let transport = try createHttpTransport(HttpTransportConfig(url: rpcTransportHttpURL()))

        do {
            _ = try await transport(RpcTransportConfig(payload: .number(123)))
            XCTFail("Expected malformed JSON")
        } catch let error as SolanaError {
            XCTAssertEqual(error.solanaCode, .malformedJSONRPCError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlreadyAbortedSignalPreventsTheRequestFromStarting() async throws {
        RpcTransportHttpURLProtocol.setResponse(statusCode: 200, body: #"{"ok":true}"#)
        let signal = AbortSignal(abortedWith: AbortError(reason: "stop"))
        let transport = try createHttpTransport(HttpTransportConfig(url: rpcTransportHttpURL()))

        do {
            _ = try await transport(RpcTransportConfig(payload: .number(123), abortSignal: signal))
            XCTFail("Expected abort")
        } catch let error as AbortError {
            XCTAssertEqual(error.reason, "stop")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(RpcTransportHttpURLProtocol.requests().count, 0)
    }
}

private func rpcTransportHttpURL() -> URL {
    URL(string: "https://unit.test/rpc")!
}

private final class RpcTransportHttpURLProtocol: URLProtocol {
    private struct StubState: Sendable {
        var response: StubResponse = StubResponse()
        var requests: [RecordedRequest] = []
    }

    private struct StubResponse: Sendable {
        var statusCode = 200
        var headers: [String: String] = [:]
        var body = Data(#"{"ok":true}"#.utf8)
    }

    private static let state = OSAllocatedUnfairLock(initialState: StubState())

    static func reset() {
        state.withLock { $0 = StubState() }
    }

    static func setResponse(statusCode: Int, headers: [String: String] = [:], body: String) {
        setResponse(statusCode: statusCode, headers: headers, bodyData: Data(body.utf8))
    }

    static func setResponse(statusCode: Int, headers: [String: String] = [:], bodyData: Data) {
        state.withLock {
            $0.response = StubResponse(statusCode: statusCode, headers: headers, body: bodyData)
        }
    }

    static func requests() -> [RecordedRequest] {
        state.withLock(\.requests)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "unit.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let capturedRequest = request
        let recordedRequest = RecordedRequest(request: capturedRequest)
        let response = Self.state.withLock { state -> StubResponse in
            state.requests.append(recordedRequest)
            return state.response
        }
        guard let url = request.url,
              let httpResponse = HTTPURLResponse(
                  url: url,
                  statusCode: response.statusCode,
                  httpVersion: nil,
                  headerFields: response.headers
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct RecordedRequest: Sendable {
    let url: URL?
    let method: String?
    let headers: [String: String]
    let body: Data?

    var bodyString: String? {
        body.flatMap { String(data: $0, encoding: .utf8) }
    }

    init(request: URLRequest) {
        url = request.url
        method = request.httpMethod
        headers = request.allHTTPHeaderFields ?? [:]
        body = request.httpBody ?? request.httpBodyStream.flatMap(Self.readBodyStream)
    }

    func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private static func readBodyStream(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
