public import Foundation

public enum RpcGraphqlRpcError: Error, Sendable, Equatable {
    case missingResult
    case responseError(code: Int?, message: String)
}

public struct RpcGraphqlRpcTransport: Sendable {
    private let sendBody: @Sendable (String, [RpcGraphqlArgumentValue]) async throws -> RpcGraphqlArgumentValue

    public init(send: @escaping @Sendable (String, [RpcGraphqlArgumentValue]) async throws -> RpcGraphqlArgumentValue) {
        sendBody = send
    }

    public func send(_ method: String, params: [RpcGraphqlArgumentValue]) async throws -> RpcGraphqlArgumentValue {
        try await sendBody(method, params)
    }

    public static func http(endpoint: URL, headers: [String: String] = [:]) -> RpcGraphqlRpcTransport {
        RpcGraphqlRpcTransport { method, params in
            let requestBody = RpcGraphqlJsonRpcRequest(id: 1, method: method, params: params)
            let body = try JSONEncoder().encode(requestBody)
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type")
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(RpcGraphqlJsonRpcResponse.self, from: data)
            if let error = response.error {
                throw RpcGraphqlRpcError.responseError(code: error.code, message: error.message)
            }
            guard let result = response.result else {
                throw RpcGraphqlRpcError.missingResult
            }
            return result
        }
    }
}

private struct RpcGraphqlJsonRpcRequest: Encodable {
    var id: Int
    var jsonrpc = "2.0"
    var method: String
    var params: [RpcGraphqlArgumentValue]
}

private struct RpcGraphqlJsonRpcResponse: Decodable {
    var result: RpcGraphqlArgumentValue?
    var error: RpcGraphqlJsonRpcError?
}

private struct RpcGraphqlJsonRpcError: Decodable {
    var code: Int?
    var message: String
}
