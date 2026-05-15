struct RpcGraphqlAccountResult: Sendable, Equatable {
    var address: RpcGraphqlAddress
    var encodedData: [String: String]
    var jsonParsedConfigs: [String: String]
    var ownerProgram: RpcGraphqlAddress?
    var fields: [String: RpcGraphqlArgumentValue]
}

struct RpcGraphqlTransactionResult: Sendable, Equatable {
    var signature: RpcGraphqlSignature?
    var encodedData: [String: String]
    var fields: [String: RpcGraphqlArgumentValue]
}

enum RpcGraphqlResolvers {
    static func resolveAccount(
        parent: [String: RpcGraphqlArgumentValue] = [:],
        fieldName: String? = nil,
        address explicitAddress: RpcGraphqlAddress? = nil,
        commitment: RpcGraphqlCommitment? = nil,
        minContextSlot: RpcGraphqlSlot? = nil,
        context: RpcGraphqlContext,
        info: RpcGraphqlResolveInfo
    ) async -> RpcGraphqlAccountResult? {
        let address = fieldName.flatMap { parent[$0]?.stringValue } ?? explicitAddress
        guard let address else {
            return nil
        }
        if RpcGraphqlSelectionVisitor.onlyFieldsRequested(["address"], in: info) {
            return RpcGraphqlAccountResult(
                address: address,
                encodedData: [:],
                jsonParsedConfigs: [:],
                ownerProgram: nil,
                fields: [:]
            )
        }

        let argsSet = accountLoaderArguments(
            address: address,
            commitment: commitment,
            minContextSlot: minContextSlot,
            info: info
        )
        let loadedAccounts = await context.loaders.account.loadMany(argsSet)
        return accountResult(address: address, argsSet: argsSet, loadedAccounts: loadedAccounts)
    }

    static func resolveProgramAccounts(
        parent: [String: RpcGraphqlArgumentValue] = [:],
        fieldName: String? = nil,
        programAddress explicitProgramAddress: RpcGraphqlAddress? = nil,
        commitment: RpcGraphqlCommitment? = nil,
        dataSizeFilters: [RpcGraphqlProgramAccountsDataSizeFilter]? = nil,
        memcmpFilters: [RpcGraphqlProgramAccountsMemcmpFilter]? = nil,
        minContextSlot: RpcGraphqlSlot? = nil,
        context: RpcGraphqlContext,
        info: RpcGraphqlResolveInfo
    ) async -> [RpcGraphqlAccountResult]? {
        let programAddress = fieldName.flatMap { parent[$0]?.stringValue } ?? explicitProgramAddress
        guard let programAddress else {
            return nil
        }
        let argsSet = programAccountsLoaderArguments(
            programAddress: programAddress,
            commitment: commitment,
            dataSizeFilters: dataSizeFilters,
            memcmpFilters: memcmpFilters,
            minContextSlot: minContextSlot,
            info: info
        )
        let loadedLists = await context.loaders.programAccounts.loadMany(argsSet)
        var resultsByAddress: [RpcGraphqlAddress: RpcGraphqlAccountResult] = [:]

        for (index, loadResult) in loadedLists.enumerated() {
            guard case let .value(accounts) = loadResult else {
                continue
            }
            for account in accounts {
                guard let address = account.address else {
                    continue
                }
                var result = resultsByAddress[address] ?? RpcGraphqlAccountResult(
                    address: address,
                    encodedData: [:],
                    jsonParsedConfigs: [:],
                    ownerProgram: account.owner,
                    fields: account.fields
                )
                merge(account: account, arguments: argsSet[index], into: &result)
                resultsByAddress[address] = result
            }
        }

        return resultsByAddress.keys.sorted().compactMap { resultsByAddress[$0] }
    }

    static func resolveAccountData(
        parent: RpcGraphqlAccountResult?,
        encoding: RpcGraphqlAccountEncoding,
        dataSlice: RpcGraphqlDataSlice? = nil
    ) -> String? {
        guard let parent else {
            return nil
        }
        return parent.encodedData[
            rpcGraphqlObjectKey([
                "dataSlice": dataSlice?.stableKeyValue,
                "encoding": .string(encoding.rpcValue),
            ])
        ]
    }

    static func resolveTransactionData(
        parent: RpcGraphqlTransactionResult?,
        encoding: RpcGraphqlTransactionEncoding
    ) -> String? {
        guard let parent else {
            return nil
        }
        return parent.encodedData[
            rpcGraphqlObjectKey(["encoding": .string(encoding.rawValue)])
        ]
    }

    static func accountLoaderArguments(
        address: RpcGraphqlAddress,
        commitment: RpcGraphqlCommitment? = nil,
        minContextSlot: RpcGraphqlSlot? = nil,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlAccountLoaderArguments] {
        if RpcGraphqlSelectionVisitor.onlyFieldsRequested(["address"], in: info) {
            return []
        }
        return RpcGraphqlResolveInfoPlanner.accountArguments(
            base: RpcGraphqlAccountLoaderArguments(
                address: address,
                commitment: commitment,
                dataSlice: nil,
                encoding: nil,
                minContextSlot: minContextSlot
            ),
            info: info
        )
    }

    static func blockLoaderArguments(
        slot: RpcGraphqlSlot,
        commitment: RpcGraphqlCommitment? = nil,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlBlockLoaderArguments] {
        if RpcGraphqlSelectionVisitor.onlyFieldsRequested(["slot"], in: info) {
            return []
        }
        return RpcGraphqlResolveInfoPlanner.blockArguments(
            base: RpcGraphqlBlockLoaderArguments(
                slot: slot,
                commitment: commitment,
                encoding: nil,
                maxSupportedTransactionVersion: 0,
                rewards: nil,
                transactionDetails: nil
            ),
            info: info
        )
    }

    static func programAccountsLoaderArguments(
        programAddress: RpcGraphqlAddress,
        commitment: RpcGraphqlCommitment? = nil,
        dataSizeFilters: [RpcGraphqlProgramAccountsDataSizeFilter]? = nil,
        memcmpFilters: [RpcGraphqlProgramAccountsMemcmpFilter]? = nil,
        minContextSlot: RpcGraphqlSlot? = nil,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlProgramAccountsLoaderArguments] {
        var filters: [RpcGraphqlProgramAccountsFilter] = []
        filters.append(contentsOf: dataSizeFilters?.map { .dataSize($0) } ?? [])
        filters.append(contentsOf: memcmpFilters?.map { .memcmp($0) } ?? [])
        return RpcGraphqlResolveInfoPlanner.programAccountsArguments(
            base: RpcGraphqlProgramAccountsLoaderArguments(
                programAddress: programAddress,
                commitment: commitment,
                dataSlice: nil,
                encoding: nil,
                filters: filters.isEmpty ? nil : filters,
                minContextSlot: minContextSlot
            ),
            info: info
        )
    }

    static func transactionLoaderArguments(
        signature: RpcGraphqlSignature,
        commitment: RpcGraphqlCommitment? = nil,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlTransactionLoaderArguments] {
        if RpcGraphqlSelectionVisitor.onlyFieldsRequested(["signature"], in: info) {
            return []
        }
        return RpcGraphqlResolveInfoPlanner.transactionArguments(
            base: RpcGraphqlTransactionLoaderArguments(
                signature: signature,
                commitment: commitment,
                encoding: nil
            ),
            info: info
        )
    }

    private static func accountResult(
        address: RpcGraphqlAddress,
        argsSet: [RpcGraphqlAccountLoaderArguments],
        loadedAccounts: [RpcGraphqlLoadResult<RpcGraphqlAccountRecord?>]
    ) -> RpcGraphqlAccountResult {
        var result = RpcGraphqlAccountResult(
            address: address,
            encodedData: [:],
            jsonParsedConfigs: [:],
            ownerProgram: nil,
            fields: [:]
        )
        for (index, loadResult) in loadedAccounts.enumerated() {
            guard case let .value(account?) = loadResult else {
                continue
            }
            merge(account: account, arguments: argsSet[index], into: &result)
        }
        return result
    }

    private static func merge<Arguments: RpcGraphqlDataSliceLoadArguments>(
        account: RpcGraphqlAccountRecord,
        arguments: Arguments,
        into result: inout RpcGraphqlAccountResult
    ) {
        if result.ownerProgram == nil {
            result.ownerProgram = account.owner
            result.fields.merge(account.fields) { current, _ in current }
            if let executable = account.executable {
                result.fields["executable"] = .bool(executable)
            }
            if let lamports = account.lamports {
                result.fields["lamports"] = .uint(lamports)
            }
            if let owner = account.owner {
                result.fields["owner"] = .string(owner)
            }
            if let space = account.space {
                result.fields["space"] = .uint(space)
            }
        }

        if let jsonParsedConfigs = account.jsonParsedConfigs {
            result.jsonParsedConfigs = jsonParsedConfigs
        }

        guard let encoding = arguments.encodingKey, let data = account.data else {
            return
        }
        switch data {
        case let .encoded(value, accountEncoding):
            let keyEncoding = encoding == RpcGraphqlAccountEncoding.jsonParsed.rpcValue
                ? RpcGraphqlAccountEncoding.base64.rpcValue
                : accountEncoding.rpcValue
            result.encodedData[
                rpcGraphqlObjectKey([
                    "dataSlice": arguments.dataSlice?.stableKeyValue,
                    "encoding": .string(keyEncoding),
                ])
            ] = value
        case let .base58(value):
            result.encodedData[
                rpcGraphqlObjectKey([
                    "dataSlice": arguments.dataSlice?.stableKeyValue,
                    "encoding": .string(RpcGraphqlAccountEncoding.base58.rpcValue),
                ])
            ] = value
        case .jsonParsed:
            result.fields.merge(account.fields) { current, _ in current }
        }
    }
}
