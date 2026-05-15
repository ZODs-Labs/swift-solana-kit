public import Foundation

public enum BalanceLookupError: Error, Sendable, Equatable, LocalizedError {
    case invalidAddress(String)
    case invalidEndpoint(String)
    case malformedResponse(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidAddress(value):
            "Invalid Solana address: \(value)"
        case let .invalidEndpoint(value):
            "Invalid endpoint URL: \(value)"
        case let .malformedResponse(reason):
            "Malformed RPC response: \(reason)"
        }
    }
}
