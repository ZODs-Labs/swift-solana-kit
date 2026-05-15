public import Signers

public protocol ClientWithIdentity: Sendable {
    var identity: TransactionSigner { get }
}
