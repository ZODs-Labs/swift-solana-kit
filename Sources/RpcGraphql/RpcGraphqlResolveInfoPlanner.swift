enum RpcGraphqlResolveInfoPlanner {
    static func accountArguments(
        base arguments: RpcGraphqlAccountLoaderArguments,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlAccountLoaderArguments] {
        buildAccountArgumentSet(base: arguments, info: info)
    }

    static func programAccountsArguments(
        base arguments: RpcGraphqlProgramAccountsLoaderArguments,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlProgramAccountsLoaderArguments] {
        buildAccountArgumentSet(base: arguments, info: info)
    }

    static func blockArguments(
        base arguments: RpcGraphqlBlockLoaderArguments,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlBlockLoaderArguments] {
        var argSet = [arguments]
        RpcGraphqlSelectionVisitor.visitRoot(info) { selection in
            guard case let .field(name, _, selections) = selection else {
                return true
            }
            let fieldName = RpcGraphqlSelectionVisitor.canonicalFieldName(name, arguments: [:])
            if fieldName == "signatures" {
                argSet.append(arguments.withTransactionDetails(.signatures))
            } else if fieldName == "transactions" {
                var transactionBase = arguments.withTransactionDetails(.full)
                transactionBase.maxSupportedTransactionVersion = transactionBase.maxSupportedTransactionVersion ?? 0
                argSet.append(contentsOf: transactionArguments(base: transactionBase, transactionSelections: selections, info: info))
            }
            return true
        }
        return unique(argSet)
    }

    static func transactionArguments(
        base arguments: RpcGraphqlTransactionLoaderArguments,
        info: RpcGraphqlResolveInfo
    ) -> [RpcGraphqlTransactionLoaderArguments] {
        unique(transactionArguments(base: arguments, transactionSelections: info.selections, info: info))
    }

    private static func transactionArguments<Arguments: RpcGraphqlLoadArguments>(
        base arguments: Arguments,
        transactionSelections: [RpcGraphqlSelection],
        info: RpcGraphqlResolveInfo
    ) -> [Arguments] {
        var argSet = [arguments]
        RpcGraphqlSelectionVisitor.visitRoot(info, root: transactionSelections) { selection in
            guard case let .field(name, fieldArguments, _) = selection else {
                return true
            }
            let fieldName = RpcGraphqlSelectionVisitor.canonicalFieldName(name, arguments: fieldArguments)
            if fieldName == "message" || fieldName == "meta" {
                argSet.append(arguments.withDefaultEncoding("jsonParsed"))
            } else if fieldName == "data", let encoding = transactionEncoding(from: fieldArguments, variables: info.variableValues) {
                argSet.append(arguments.withDefaultEncoding(encoding.rawValue))
            }
            return true
        }
        return unique(argSet)
    }

    private static func buildAccountArgumentSet<Arguments: RpcGraphqlDataSliceLoadArguments>(
        base arguments: Arguments,
        info: RpcGraphqlResolveInfo
    ) -> [Arguments] {
        var argSet = [arguments]
        func visit(_ selections: [RpcGraphqlSelection]) {
            for selection in selections {
                switch selection {
                case let .field(name, fieldArguments, nestedSelections):
                    let fieldName = RpcGraphqlSelectionVisitor.canonicalFieldName(name, arguments: fieldArguments)
                    if fieldName == "data", let encoding = accountEncoding(from: fieldArguments, variables: info.variableValues) {
                        var next = arguments.withDefaultEncoding(encoding.rpcValue)
                        if let dataSlice = dataSlice(from: fieldArguments, variables: info.variableValues) {
                            next = next.withDataSlice(dataSlice)
                        }
                        argSet.append(next)
                    }
                    visit(nestedSelections)
                case let .inlineFragment(_, selections):
                    if !RpcGraphqlSelectionVisitor.onlyFieldsRequested(info.accountInterfaceFields, in: info, root: selections) {
                        argSet.append(arguments.withDefaultEncoding("jsonParsed"))
                    }
                    visit(selections)
                case let .fragmentSpread(name):
                    if let fragment = info.fragments[name] {
                        visit(fragment)
                    }
                }
            }
        }
        visit(info.selections)
        return unique(argSet)
    }

    private static func accountEncoding(
        from arguments: [String: RpcGraphqlArgumentValue],
        variables: [String: RpcGraphqlArgumentValue]
    ) -> RpcGraphqlAccountEncoding? {
        guard let value = arguments["encoding"]?.resolved(using: variables).stringValue else {
            return nil
        }
        switch value {
        case "BASE_58", "base58":
            return .base58
        case "BASE_64", "base64":
            return .base64
        case "BASE_64_ZSTD", "base64+zstd":
            return .base64Zstd
        default:
            return nil
        }
    }

    private static func transactionEncoding(
        from arguments: [String: RpcGraphqlArgumentValue],
        variables: [String: RpcGraphqlArgumentValue]
    ) -> RpcGraphqlTransactionEncoding? {
        guard let value = arguments["encoding"]?.resolved(using: variables).stringValue else {
            return nil
        }
        switch value {
        case "BASE_58", "base58":
            return .base58
        case "BASE_64", "base64":
            return .base64
        default:
            return nil
        }
    }

    private static func dataSlice(
        from arguments: [String: RpcGraphqlArgumentValue],
        variables: [String: RpcGraphqlArgumentValue]
    ) -> RpcGraphqlDataSlice? {
        guard let value = arguments["dataSlice"]?.resolved(using: variables) else {
            return nil
        }
        if case let .object(fields) = value {
            let resolvedFields = fields.mapValues { $0.resolved(using: variables) }
            guard let length = resolvedFields["length"]?.intValue,
                  let offset = resolvedFields["offset"]?.intValue else {
                return nil
            }
            return RpcGraphqlDataSlice(length: length, offset: offset)
        }
        if case let .variable(name) = value,
           case let .object(fields)? = variables[name] {
            let resolvedFields = fields.mapValues { $0.resolved(using: variables) }
            guard let length = resolvedFields["length"]?.intValue,
                  let offset = resolvedFields["offset"]?.intValue else {
                return nil
            }
            return RpcGraphqlDataSlice(length: length, offset: offset)
        }
        return nil
    }

    private static func unique<Arguments: RpcGraphqlLoadArguments>(_ arguments: [Arguments]) -> [Arguments] {
        var seen = Set<String>()
        var result: [Arguments] = []
        for argument in arguments {
            let key = argument.stableKey(omitting: [])
            if seen.insert(key).inserted {
                result.append(argument)
            }
        }
        return result
    }
}
