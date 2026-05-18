# swift-solana-kit

[![Release](https://img.shields.io/github/v/release/ZODs-Labs/swift-solana-kit?sort=semver)](https://github.com/ZODs-Labs/swift-solana-kit/releases)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FZODs-Labs%2Fswift-solana-kit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ZODs-Labs/swift-solana-kit)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FZODs-Labs%2Fswift-solana-kit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ZODs-Labs/swift-solana-kit)
[![Documentation](https://img.shields.io/badge/docs-Swift%20Package%20Index-blue)](https://swiftpackageindex.com/ZODs-Labs/swift-solana-kit/documentation/kit)

A Swift SDK for building Solana applications on Apple platforms. It uses Swift 6, Foundation, CryptoKit, URLSession and Swift concurrency with no third-party SDK dependencies in core targets.

## Requirements

macOS 14+, iOS 17+, Swift 6.0+ and Xcode 16.0+.

## Installation

The current public candidate is `0.9.0-rc.1`. Pin release candidates exactly while validating them in production:

```swift
dependencies: [
    .package(url: "https://github.com/ZODs-Labs/swift-solana-kit.git", exact: "0.9.0-rc.1")
]
```

After the stable `0.9.0` tag is published, applications can move to the normal SwiftPM version range:

```swift
dependencies: [
    .package(url: "https://github.com/ZODs-Labs/swift-solana-kit.git", from: "0.9.0")
]
```

Most applications should depend on the `Kit` product:

```swift
.target(
    name: "WalletApp",
    dependencies: [
        .product(name: "Kit", package: "swift-solana-kit")
    ]
)
```

## Library Products

| Product | Use |
| --- | --- |
| `Kit` | Umbrella product for Solana accounts, addresses, codecs, RPC, signers, transactions and high-level helpers. |
| `SolanaErrors` | Stable error codes, typed error values and user-facing error descriptions. |
| `CodecsCore` | Base encoder, decoder and codec protocols for byte-level serialization. |
| `Rpc` | JSON-RPC client construction, transport coalescing and Solana response safety checks. |
| `RpcGraphql` | GraphQL-style account, block, program account and transaction query planning over Solana RPC. |
| `ProgramClientCore` | Program client helpers for account resolution, self-fetching codecs and plan-and-send flows. |

## Quick Start

Validate an address and encode it as bytes:

<!-- snippet-source: Tests/AddressesTests/AddressesTests.swift:47 -->

```swift
import Kit

let owner = try address("4wBqpZM9xaSheZzJSMawUHDgZ7miWfSsxmfVF5jJpYP")
let bytes = try getAddressEncoder().encode(owner)

print(owner.rawValue)
print(bytes.count)
```

Create an RPC client and request the latest blockhash:

<!-- snippet-source: Tests/RpcApiTests/RpcApiTests.swift:67 -->

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

Send and confirm through the high-level factory:

<!-- snippet-source: Sources/Kit/SendTransaction.swift:48 -->

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

## Documentation

API documentation is hosted through Swift Package Index after the package is indexed:

https://swiftpackageindex.com/ZODs-Labs/swift-solana-kit/documentation/kit

The local DocC catalogs live next to their library targets under `Sources/<Target>/Documentation.docc/`.

## Public API

Every public surface is tracked in `PublicAPI/<TargetName>.swift`. New public symbols must be added to the matching contract file before they are considered stable API. Source examples should compile under the platform floors listed above.

## Scope

The current package supports Apple platforms only. Linux support is planned behind the crypto backend boundary.

Core targets are source-distributed and dependency-light. Additional platform backends will be considered after the Apple SDK is stable.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Public API changes need tests and contract updates.

## Security

Report security issues through [SECURITY.md](SECURITY.md). Please do not open public issues for vulnerabilities.

## License

swift-solana-kit is available under the Apache License 2.0. See [LICENSE](LICENSE).
