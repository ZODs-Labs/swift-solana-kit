public import Foundation
import Promises
public import RpcSpec
public import RpcSpecTypes
import SolanaErrors

public typealias HttpRequestHeaders = [String: String]

public struct HttpTransportConfig: Sendable {
    public let url: URL
    public let headers: HttpRequestHeaders
    public let toJson: (@Sendable (RpcJsonValue) throws -> String)?
    public let fromJson: (@Sendable (String, RpcJsonValue) throws -> RpcJsonValue)?

    public init(
        url: URL,
        headers: HttpRequestHeaders = [:],
        toJson: (@Sendable (RpcJsonValue) throws -> String)? = nil,
        fromJson: (@Sendable (String, RpcJsonValue) throws -> RpcJsonValue)? = nil
    ) {
        self.url = url
        self.headers = headers
        self.toJson = toJson
        self.fromJson = fromJson
    }
}

public let solanaRpcMethods: Set<String> = [
    "getAccountInfo",
    "getBalance",
    "getBlock",
    "getBlockCommitment",
    "getBlockHeight",
    "getBlockProduction",
    "getBlocks",
    "getBlocksWithLimit",
    "getBlockTime",
    "getClusterNodes",
    "getEpochInfo",
    "getEpochSchedule",
    "getFeeForMessage",
    "getFirstAvailableBlock",
    "getGenesisHash",
    "getHealth",
    "getHighestSnapshotSlot",
    "getIdentity",
    "getInflationGovernor",
    "getInflationRate",
    "getInflationReward",
    "getLargestAccounts",
    "getLatestBlockhash",
    "getLeaderSchedule",
    "getMaxRetransmitSlot",
    "getMaxShredInsertSlot",
    "getMinimumBalanceForRentExemption",
    "getMultipleAccounts",
    "getProgramAccounts",
    "getRecentPerformanceSamples",
    "getRecentPrioritizationFees",
    "getSignaturesForAddress",
    "getSignatureStatuses",
    "getSlot",
    "getSlotLeader",
    "getSlotLeaders",
    "getStakeMinimumDelegation",
    "getSupply",
    "getTokenAccountBalance",
    "getTokenAccountsByDelegate",
    "getTokenAccountsByOwner",
    "getTokenLargestAccounts",
    "getTokenSupply",
    "getTransaction",
    "getTransactionCount",
    "getVersion",
    "getVoteAccounts",
    "index",
    "isBlockhashValid",
    "minimumLedgerSlot",
    "requestAirdrop",
    "sendTransaction",
    "simulateTransaction",
]

private let forbiddenHeaderNames: Set<String> = [
    "accept-charset",
    "access-control-request-headers",
    "access-control-request-method",
    "connection",
    "content-length",
    "cookie",
    "date",
    "dnt",
    "expect",
    "host",
    "keep-alive",
    "permissions-policy",
    "referer",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
    "via",
]

private let disallowedHeaderNames: Set<String> = [
    "accept",
    "content-length",
    "content-type",
]

public func assertIsAllowedHttpRequestHeaders(_ headers: HttpRequestHeaders) throws {
    let badHeaders = headers.keys.filter { headerName in
        let lowercased = headerName.lowercased()
        return disallowedHeaderNames.contains(lowercased)
            || forbiddenHeaderNames.contains(lowercased)
            || lowercased.hasPrefix("proxy-")
            || lowercased.hasPrefix("sec-")
    }
    guard badHeaders.isEmpty else {
        throw RpcError.transportHTTPHeaderForbidden(headers: badHeaders.sorted())
    }
}

public func normalizeHeaders(_ headers: HttpRequestHeaders) -> HttpRequestHeaders {
    var out: HttpRequestHeaders = [:]
    for (key, value) in headers {
        out[key.lowercased()] = value
    }
    return out
}

public func createHttpTransport(_ config: HttpTransportConfig) throws -> RpcTransport {
    #if DEBUG
    try assertIsAllowedHttpRequestHeaders(config.headers)
    #endif
    let normalizedHeaders = normalizeHeaders(config.headers)

    return { requestConfig in
        let body = try config.toJson?(requestConfig.payload) ?? stringifyJson(requestConfig.payload)
        let bodyData = Data(body.utf8)
        var request = URLRequest(url: config.url)
        request.httpMethod = "POST"
        request.httpBody = bodyData

        var headers = normalizedHeaders
        headers["accept"] = "application/json"
        headers["content-length"] = httpContentLengthHeaderValue(for: body)
        headers["content-type"] = "application/json; charset=utf-8"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await performRequest(request, abortSignal: requestConfig.abortSignal)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RpcError.transportHTTPError(statusCode: -1, message: "Missing HTTP response", headers: [:])
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw RpcError.transportHTTPError(
                statusCode: httpResponse.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                headers: httpHeaders(from: httpResponse)
            )
        }
        guard let rawResponse = String(data: data, encoding: .utf8) else {
            throw SolanaError(.malformedJSONRPCError)
        }
        if let fromJson = config.fromJson {
            return try fromJson(rawResponse, requestConfig.payload)
        }
        return try parseJson(rawResponse)
    }
}

private func httpHeaders(from response: HTTPURLResponse) -> [String: String] {
    var headers: [String: String] = [:]
    for (key, value) in response.allHeaderFields {
        headers[String(describing: key)] = String(describing: value)
    }
    return headers
}

func httpContentLengthHeaderValue(for body: String) -> String {
    String(body.utf16.count)
}

private func performRequest(
    _ request: URLRequest,
    abortSignal: AbortSignal?
) async throws -> (Data, URLResponse) {
    if let reason = abortSignal?.abortReason() {
        throw reason
    }
    return try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
        group.addTask {
            try await URLSession.shared.data(for: request)
        }
        if let abortSignal {
            group.addTask {
                let reason = await abortSignal.waitUntilAborted()
                throw reason
            }
        }
        guard let first = try await group.next() else {
            throw CancellationError()
        }
        group.cancelAll()
        return first
    }
}

public func createHttpTransportForSolanaRpc(url: URL, headers: HttpRequestHeaders = [:]) throws -> RpcTransport {
    try createHttpTransport(
        HttpTransportConfig(
            url: url,
            headers: headers,
            toJson: { payload in
                if isSolanaRequest(payload) {
                    return try stringifyJsonWithBigInts(payload)
                }
                return try stringifyJson(payload)
            },
            fromJson: { rawResponse, payload in
                if isSolanaRequest(payload) {
                    return try parseJsonWithBigInts(rawResponse)
                }
                return try parseJson(rawResponse)
            }
        )
    )
}

public func isSolanaRequest(_ payload: RpcJsonValue) -> Bool {
    guard isJsonRpcPayload(payload),
          case let .string(method)? = payload.value(for: "method")
    else {
        return false
    }
    return solanaRpcMethods.contains(method)
}
