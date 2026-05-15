# Getting Started

Create a small Solana client by validating addresses, constructing RPC clients and composing transaction confirmation helpers.

## Requirements

swift-solana-kit supports macOS 14+, iOS 17+ and Swift 6.0+.

## Validate An Address

Use `address(_:)` when a value comes from user input, a configuration file or another untrusted source.

```swift
import Kit

let owner = try address("EKaNRGA37uiGRyRPMap5EZg9cmbT5mt7KWrGwKwAQ3rK")
print(owner.rawValue)
```

## Encode An Address

Address codecs convert validated addresses to and from their 32-byte representation.

```swift
import Kit

let owner = try address("4wBqpZM9xaSheZzJSMawUHDgZ7miWfSsxmfVF5jJpYP")
let bytes = try getAddressEncoder().encode(owner)

print(bytes.count)
```

## Create An RPC Client

`createSolanaRpc(_:)` builds a default HTTP JSON-RPC client. Custom transports can be supplied with `createSolanaRpcFromTransport(_:)`.

```swift
import Foundation
import Kit

func loadLatestBlockhash() async throws -> RpcJsonValue {
    let endpoint = URL(string: "https://api.mainnet-beta.solana.com")!
    let rpc = try createSolanaRpc(endpoint)

    return try await rpc
        .request("getLatestBlockhash", params: [])
        .send()
}
```

## Send And Confirm

`sendAndConfirmTransactionFactory(_:)` combines an RPC client with an RPC subscription client so a signed blockhash-based transaction can be sent and observed until it reaches the requested commitment.

```swift
import Foundation
import Kit

func sendAndConfirm(_ transaction: Transaction) async throws {
    let rpc = try createSolanaRpc(URL(string: "https://api.mainnet-beta.solana.com")!)
    let rpcSubscriptions = try createSolanaRpcSubscriptions("wss://api.mainnet-beta.solana.com")
    let send = sendAndConfirmTransactionFactory(
        SendAndConfirmTransactionFactoryConfig(
            rpc: rpc,
            rpcSubscriptions: rpcSubscriptions
        )
    )

    try await send(transaction, SendTransactionConfig(commitment: .confirmed))
}
```
