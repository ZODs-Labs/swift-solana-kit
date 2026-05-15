public enum CryptoKitSigningMode: Sendable, Equatable {
    /// Use deterministic Ed25519 signing with repeatable byte output.
    case deterministic

    /// Use Apple's CryptoKit signer. Signatures verify as Ed25519, but CryptoKit
    /// randomizes signing output.
    case platform
}
