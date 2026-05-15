public import Foundation

public enum ActivityLookupError: Error, Sendable, Equatable, LocalizedError {
    case invalidAddress(String)
    case invalidLimit(Int)
    case malformedResponse(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidAddress(value):
            "Invalid Solana address: \(value)"
        case let .invalidLimit(value):
            "History limit must be between 1 and 25: \(value)"
        case let .malformedResponse(reason):
            "Malformed RPC response: \(reason)"
        }
    }
}
