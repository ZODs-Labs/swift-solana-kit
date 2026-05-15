public import Signers

public protocol ClientWithPayer: Sendable {
    var payer: TransactionSigner { get }
}
