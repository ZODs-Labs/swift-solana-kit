enum RpcGraphqlValueAccess {
    static func object(_ value: RpcGraphqlArgumentValue?) -> [String: RpcGraphqlArgumentValue]? {
        guard case let .object(fields)? = value else {
            return nil
        }
        return fields
    }

    static func list(_ value: RpcGraphqlArgumentValue?) -> [RpcGraphqlArgumentValue]? {
        guard case let .list(values)? = value else {
            return nil
        }
        return values
    }

    static func string(_ value: RpcGraphqlArgumentValue?) -> String? {
        value?.stringValue
    }

    static func bool(_ value: RpcGraphqlArgumentValue?) -> Bool? {
        guard case let .bool(value)? = value else {
            return nil
        }
        return value
    }

    static func uint(_ value: RpcGraphqlArgumentValue?) -> UInt64? {
        switch value {
        case let .uint(value):
            value
        case let .int(value) where value >= 0:
            UInt64(value)
        case let .number(value):
            UInt64(value)
        case let .string(value):
            UInt64(value)
        default:
            nil
        }
    }
}
