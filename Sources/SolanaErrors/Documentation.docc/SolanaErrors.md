# ``SolanaErrors``

Typed Solana error codes, error values and message rendering.

## Overview

`SolanaErrors` gives library targets a shared error model. Each error can carry a stable code, a Swift error type and contextual values that improve diagnostics without losing structured handling.

Use `SolanaError` for cross-target SDK errors. Use the narrower enums when a caller can react to a specific domain such as codecs, addresses, RPC, signers or transactions.

## Topics

### Core Model

- ``SolanaError``
- ``SolanaErrorCode``
- ``SolanaErrorCoded``
- ``solanaErrorMessage(code:context:)``

### Domains

- ``CodecsError``
- ``AddressError``
- ``RpcError``
- ``SignerError``
- ``TransactionError``
