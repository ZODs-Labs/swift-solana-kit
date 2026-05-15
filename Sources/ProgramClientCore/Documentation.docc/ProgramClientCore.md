# ``ProgramClientCore``

Shared helpers for generated and hand-written Solana program clients.

## Overview

`ProgramClientCore` contains small building blocks for program client ergonomics. It resolves instruction accounts into metas, attaches self-fetch behavior to codecs and wraps instructions or plans with send helpers.

Use this product from program-specific packages that need account resolution and transaction planning support without importing the umbrella SDK product.

## Topics

### Instruction Accounts

- ``ResolvedInstructionAccount``
- ``ResolvedInstructionAccountValue``
- ``OptionalAccountStrategy``
- ``getAccountMetaFactory(programAddress:optionalAccountStrategy:)``

### Self Fetching

- ``SelfFetchingCodec``
- ``addSelfFetchFunctions(client:codec:)``

### Plan And Send

- ``SelfPlanAndSendItem``
- ``addSelfPlanAndSendFunctions(client:input:)``
