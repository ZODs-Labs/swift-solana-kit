public import Foundation
public import Kit

public enum AirdropRequestError: Error, Sendable, Equatable, LocalizedError {
    case invalidAddress(String)
    case invalidAmount(String)
    case amountExceedsLimit(requested: Lamports, limit: Lamports)
    case malformedResponse(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidAddress(value):
            "Invalid Solana address: \(value)"
        case let .invalidAmount(value):
            "Invalid SOL amount: \(value)"
        case let .amountExceedsLimit(requested, limit):
            "Requested \(requested) lamports, which is above the \(limit) lamport limit"
        case let .malformedResponse(reason):
            "Malformed RPC response: \(reason)"
        }
    }
}
