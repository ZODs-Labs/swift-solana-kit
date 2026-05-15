# AccountActivityIOS

AccountActivityIOS is a read-only SwiftUI iOS example for inspecting a public Solana account.

## Use Case

Mobile wallet, support and analytics screens often need a safe way to show a public account summary. This example validates an address, fetches `getBalance`, fetches `getSignaturesForAddress`, shows SOL, lamports, slot and recent activity status without private keys or signing.

## Build

```sh
swift build
```

The package includes macOS as a host build platform so command-line validation can run with SwiftPM.

## iOS Simulator

Run the real iOS app in Simulator:

```sh
bash Scripts/run_ios_simulator.sh
```

You can pass a simulator UDID when you want a specific device:

```sh
bash Scripts/run_ios_simulator.sh <simulator-udid>
```

SwiftPM builds the iOS binary. The script creates a local simulator app bundle under `.build/`, installs it and launches it.

## Xcode Host

Open this folder in Xcode, choose the `AccountActivityIOS` scheme and choose `My Mac` to run the same screen as a visual host check.

## Test

```sh
swift test
```

Tests use deterministic mock RPC closures. They do not call a live Solana endpoint.

## Steps In The App

1. Paste a public address.
2. Choose a cluster and history depth.
3. Tap `Fetch Activity`.
4. Review balance, slot and recent signatures.

## Safety

AccountActivityIOS only reads public account data. It does not request funds, sign messages or ask for wallet secrets.
