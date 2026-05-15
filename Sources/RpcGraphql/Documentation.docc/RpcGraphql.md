# ``RpcGraphql``

Client-side GraphQL query planning over Solana RPC.

## Overview

`RpcGraphql` resolves account, block and transaction selections against Solana RPC. It gives applications a query-shaped interface while keeping execution local to the client.

Use this product when a feature benefits from selection planning, batched account loading or a GraphQL result envelope without running a GraphQL server.

## Topics

### Client

- ``RpcGraphqlClient``
- ``createSolanaRpcGraphQL(transport:config:)``
- ``RpcGraphqlExecutionResult``

### Query Model

- ``RpcGraphqlRootQuery``
- ``RpcGraphqlResolveInfo``

### Transport

- ``RpcGraphqlRpcTransport``
