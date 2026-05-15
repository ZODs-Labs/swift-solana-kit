# ``Kit``

A Swift SDK for building Solana applications on Apple platforms.

## Overview

`Kit` is the umbrella library product for application code. It re-exports the address, codec, RPC, signer, transaction and helper APIs most apps need when talking to Solana from Swift.

Use the lower-level library products when you want a smaller dependency surface or a custom composition point. Use `Kit` when you want the default SDK entry point.

## Topics

### Guides

- <doc:GettingStarted>
- <doc:ProductGuide>

### Addresses

- ``Address``
- ``address(_:)``
- ``ProgramDerivedAddress``
- ``ProgramDerivedAddressSeed``
- ``getProgramDerivedAddress(programAddress:seeds:using:)``

### RPC

- ``SolanaRpc``
- ``createSolanaRpc(_:headers:)``
- ``createSolanaRpcFromTransport(_:)``
- ``createSolanaRpcSubscriptions(_:)``
- ``createSolanaRpcSubscriptionsFromTransport(_:)``

### Transactions

- ``sendAndConfirmTransactionFactory(_:)``
- ``Transaction``

### Signers

- ``KeyPairSigner``
- ``generateKeyPairSigner(using:identity:)``
- ``createSignerFromKeyPair(_:using:identity:)``

### Errors

- ``SolanaError``
- ``SolanaErrorCode``
