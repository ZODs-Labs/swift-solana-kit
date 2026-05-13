public import Foundation
public import SolanaErrors

public enum SignatureValidationError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case keys(KeysError)
    case codecs(CodecsError)

    public var code: Int {
        switch self {
        case let .keys(error):
            error.code
        case let .codecs(error):
            error.code
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .keys(error):
            error.errorDescription
        case let .codecs(error):
            error.errorDescription
        }
    }

    public var contextDescription: String {
        switch self {
        case let .keys(error):
            error.contextDescription
        case let .codecs(error):
            error.contextDescription
        }
    }

    public static var errorDomain: String {
        "Solana.SignatureValidationError"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        switch self {
        case let .keys(error):
            error.errorUserInfo
        case let .codecs(error):
            error.errorUserInfo
        }
    }
}
