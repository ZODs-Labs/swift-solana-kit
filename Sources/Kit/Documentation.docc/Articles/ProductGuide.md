# Library Products

Choose the product that matches the layer you are building against.

## Kit

Use `Kit` for application code that needs the default SDK surface. It re-exports addresses, codecs, RPC, signers, transactions and helper factories.

## SolanaErrors

Use `SolanaErrors` when a library target needs typed error codes, localized messages and structured error context without importing the umbrella product.

## CodecsCore

Use `CodecsCore` when defining byte encoders, byte decoders or full codecs for custom Solana data.

## Rpc

Use `Rpc` when you need JSON-RPC requests, default HTTP transport behavior or a custom transport composition point.

## RpcGraphql

Use `RpcGraphql` when account, block and transaction queries are easier to express as a client-side GraphQL selection.

## ProgramClientCore

Use `ProgramClientCore` when building program clients that resolve account metas, attach self-fetching codecs or compose plan-and-send helpers.
