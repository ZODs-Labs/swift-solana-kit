import Addresses
import Keys
import PluginInterfaces
import Promises
import RpcTypes
import Signers
import XCTest
import os

final class PluginInterfacesTests: XCTestCase {
    func testAirdropClientSignatureShape() async throws {
        let address = try Address("11111111111111111111111111111111")
        let client = MockAirdropClient(signature: nil)

        let signature = try await client.airdrop(address: address, amount: lamports(5))

        XCTAssertNil(signature)
    }

    func testMinimumBalanceConfigKeepsHeaderFlag() async throws {
        let client = MockMinimumBalanceClient()

        let balance = try await client.getMinimumBalance(
            space: 7,
            config: GetMinimumBalanceConfig(withoutHeader: true)
        )

        XCTAssertEqual(balance, 7)
    }

    func testIdentityAndPayerExposeTransactionSigners() throws {
        let address = try Address("11111111111111111111111111111111")
        let signer = NoopSigner(address: address).transactionSigner
        let client = MockSignerClient(identity: signer, payer: signer)

        XCTAssertEqual(client.identity.address, address)
        XCTAssertEqual(client.payer.address, address)
    }

    func testSubscribeToFnReturnsUnsubscribe() {
        let didUnsubscribe = OSAllocatedUnfairLock(initialState: false)
        let subscribe: SubscribeToFn = { listener in
            listener()
            return {
                didUnsubscribe.withLock { value in
                    value = true
                }
            }
        }

        let unsubscribe = subscribe({})
        unsubscribe()

        XCTAssertTrue(didUnsubscribe.withLock { $0 })
    }
}

private struct MockAirdropClient: ClientWithAirdrop {
    private let signature: Signature?

    init(signature: Signature?) {
        self.signature = signature
    }

    func airdrop(address: Address, amount: Lamports, abortSignal: AbortSignal?) async throws -> Signature? {
        return signature
    }
}

private struct MockMinimumBalanceClient: ClientWithGetMinimumBalance {
    func getMinimumBalance(space: Int, config: GetMinimumBalanceConfig?) async throws -> Lamports {
        Lamports(config?.withoutHeader == true ? space : space + 128)
    }
}

private struct MockSignerClient: ClientWithIdentity, ClientWithPayer {
    let identity: TransactionSigner
    let payer: TransactionSigner
}
