# AirdropIOS

AirdropIOS is a SwiftUI app example for iOS developers who want a safe devnet faucet flow.

## Use Case

Mobile wallet and onboarding screens often need a way to fund a devnet address during development. This example validates a recipient address, converts a SOL amount to lamports with Kit, sends `requestAirdrop`, shows the returned signature and checks the balance after the request when available.

## Build

```sh
swift build
```

The package includes macOS as a host build platform so command-line validation can run with SwiftPM. Open the package in Xcode and choose an iOS simulator or device to run the app as an iOS example.

## Xcode

Open this folder in Xcode, choose the `AirdropIOS` scheme and choose an iPhone simulator for the iOS flow. You can also choose `My Mac` to run the same screen as a visual host check.

## Test

```sh
swift test
```

Tests use deterministic mock RPC closures. They do not call devnet.

## Run

```sh
swift run AirdropIOS
```

The command-line run launches the SwiftUI app on macOS for validation. Use Xcode for the intended iOS simulator flow.

## Safety

AirdropIOS defaults to devnet and caps requests at 2 SOL. It does not ask for private keys or wallet secrets.
