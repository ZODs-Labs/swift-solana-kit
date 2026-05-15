# ``Rpc``

JSON-RPC client construction and transport composition for Solana endpoints.

## Overview

`Rpc` builds typed request objects over a transport closure. The default constructor uses `URLSession` through the package transport stack, while `createSolanaRpcFromTransport(_:)` lets applications supply their own routing, retry or observability layer.

The request model follows Solana JSON-RPC method names and parameters. Responses are decoded through the RPC value model before callers transform them into domain types.

## Topics

### Clients

- ``SolanaRpc``
- ``createSolanaRpc(_:headers:)``
- ``createSolanaRpcFromTransport(_:)``

### Transports

- ``RpcTransport``
- ``createDefaultRpcTransport(_:)``
- ``getRpcTransportWithRequestCoalescing(_:getDeduplicationKey:)``

### Requests

- ``PendingRpcRequest``
