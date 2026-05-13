import Foundation

public protocol SolanaErrorCoded: Error, Sendable {
    var code: UInt32 { get }
    var contextDescription: String { get }
}

public enum CodecsError: SolanaErrorCoded { /* per-domain typed throws */ }
public enum TransactionError: SolanaErrorCoded { /* per-domain typed throws */ }
public enum SignerError: SolanaErrorCoded { /* per-domain typed throws */ }
public enum RpcError: SolanaErrorCoded { /* per-domain typed throws */ }
public enum AddressError: SolanaErrorCoded { /* per-domain typed throws */ }
