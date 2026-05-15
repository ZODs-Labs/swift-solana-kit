public enum RpcGraphqlSelection: Sendable, Equatable {
    case field(name: String, arguments: [String: RpcGraphqlArgumentValue], selections: [RpcGraphqlSelection])
    case fragmentSpread(name: String)
    case inlineFragment(typeCondition: String?, selections: [RpcGraphqlSelection])

    public var fieldName: String? {
        if case let .field(name, _, _) = self {
            return name
        }
        return nil
    }
}

public struct RpcGraphqlResolveInfo: Sendable, Equatable {
    public var selections: [RpcGraphqlSelection]
    public var fragments: [String: [RpcGraphqlSelection]]
    public var variableValues: [String: RpcGraphqlArgumentValue]
    public var accountInterfaceFields: Set<String>

    public init(
        selections: [RpcGraphqlSelection],
        fragments: [String: [RpcGraphqlSelection]] = [:],
        variableValues: [String: RpcGraphqlArgumentValue] = [:],
        accountInterfaceFields: Set<String> = RpcGraphqlSchema.accountInterfaceFields
    ) {
        self.selections = selections
        self.fragments = fragments
        self.variableValues = variableValues
        self.accountInterfaceFields = accountInterfaceFields
    }
}

enum RpcGraphqlSelectionVisitor {
    static func canonicalFieldName(
        _ name: String,
        arguments: [String: RpcGraphqlArgumentValue]
    ) -> String {
        arguments["__fieldName"]?.stringValue ?? name
    }

    static func directSelections(in info: RpcGraphqlResolveInfo, root: [RpcGraphqlSelection]? = nil) -> [RpcGraphqlSelection] {
        root ?? info.selections
    }

    static func onlyFieldsRequested(
        _ fieldNames: Set<String>,
        in info: RpcGraphqlResolveInfo,
        root: [RpcGraphqlSelection]? = nil
    ) -> Bool {
        var result = true
        visitRoot(info, root: root) { selection in
            guard case let .field(name, _, _) = selection else {
                return true
            }
            if name == "__id" || name == "__typename" {
                return true
            }
            result = fieldNames.contains(name)
            return result
        }
        return result
    }

    static func visitRoot(
        _ info: RpcGraphqlResolveInfo,
        root: [RpcGraphqlSelection]? = nil,
        field: (RpcGraphqlSelection) -> Bool
    ) {
        for selection in root ?? info.selections {
            switch selection {
            case let .field(name, arguments, selections):
                let canonicalName = canonicalFieldName(name, arguments: arguments)
                let canonicalSelection = RpcGraphqlSelection.field(
                    name: canonicalName,
                    arguments: arguments,
                    selections: selections
                )
                if !field(canonicalSelection) {
                    return
                }
            case let .fragmentSpread(name):
                if let fragment = info.fragments[name] {
                    visitRoot(info, root: fragment, field: field)
                }
            case let .inlineFragment(_, selections):
                visitRoot(info, root: selections, field: field)
            }
        }
    }
}
