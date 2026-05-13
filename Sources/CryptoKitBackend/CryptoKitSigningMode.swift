public enum CryptoKitSigningMode: Sendable, Equatable {
    /// Preserve byte-for-byte parity with the pinned kit Ed25519 signature fixtures.
    case kitDeterministic

    /// Use Apple's CryptoKit signer. Signatures verify as Ed25519, but CryptoKit
    /// randomizes signing output, so bytes are not expected to match kit fixtures.
    case platform
}
