internal import FastStableStringify
import Foundation

public enum RpcGraphqlArgumentValue: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case int(Int)
    case uint(UInt64)
    case number(String)
    case string(String)
    case enumCase(String)
    case variable(String)
    case object([String: RpcGraphqlArgumentValue])
    case list([RpcGraphqlArgumentValue])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(UInt64.self) {
            self = .uint(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(NSDecimalNumber(decimal: value).stringValue)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([RpcGraphqlArgumentValue].self) {
            self = .list(value)
        } else {
            let object = try decoder.container(keyedBy: RpcGraphqlDynamicCodingKey.self)
            var fields: [String: RpcGraphqlArgumentValue] = [:]
            for key in object.allKeys {
                fields[key.stringValue] = try object.decode(RpcGraphqlArgumentValue.self, forKey: key)
            }
            self = .object(fields)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .uint(value):
            try container.encode(value)
        case let .number(value):
            if let decimal = Decimal(string: value) {
                try container.encode(decimal)
            } else {
                try container.encode(value)
            }
        case let .string(value), let .enumCase(value), let .variable(value):
            try container.encode(value)
        case let .object(fields):
            try container.encode(fields)
        case let .list(values):
            try container.encode(values)
        }
    }

    public func resolved(using variables: [String: RpcGraphqlArgumentValue]) -> RpcGraphqlArgumentValue {
        switch self {
        case let .variable(name):
            variables[name] ?? .null
        default:
            self
        }
    }

    public var stringValue: String? {
        switch self {
        case let .string(value), let .enumCase(value):
            value
        case let .int(value):
            String(value)
        case let .uint(value):
            String(value)
        case let .number(value):
            value
        default:
            nil
        }
    }

    public var intValue: Int? {
        switch self {
        case let .int(value):
            value
        case let .uint(value):
            Int(exactly: value)
        case let .number(value):
            Int(value)
        case let .string(value):
            Int(value)
        default:
            nil
        }
    }

    var stableKeyValue: StableStringifyValue {
        switch self {
        case .null:
            .null
        case let .bool(value):
            .bool(value)
        case let .int(value):
            .number(String(value))
        case let .uint(value):
            .bigint(String(value))
        case let .number(value):
            .number(value)
        case let .string(value), let .enumCase(value), let .variable(value):
            .string(value)
        case let .object(values):
            .object(values.mapValues(\.stableKeyValue))
        case let .list(values):
            .array(values.map(\.stableKeyValue))
        }
    }
}

struct RpcGraphqlDynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
