# BalanceMac

BalanceMac is a small macOS SwiftUI app that uses `swift-solana-kit` to inspect a Solana account balance.

## Use Case

Apple developers often need a quick desktop check for a public address while building wallet, analytics or support tools. This example validates an address, sends `getBalance` through Kit, displays lamports, displays SOL and shows the response slot.

## Build

```sh
swift build
```

## Xcode

Open this folder in Xcode, choose the `BalanceMac` scheme, choose `My Mac` and press `Cmd+R`. The example opens a macOS window from the package executable.

## Test

```sh
swift test
```

Tests use deterministic mock RPC responses. They do not call a live Solana endpoint.

## Run

```sh
swift run BalanceMac
```

The app defaults to devnet and includes testnet, mainnet beta and custom endpoint options. Live requests require network access.

## Safety

BalanceMac only reads public account data. It does not ask for private keys or wallet secrets.
