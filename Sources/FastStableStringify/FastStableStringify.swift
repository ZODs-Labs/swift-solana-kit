import Foundation

public enum StableStringifyValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case string(String)
    case number(String)
    case nonFiniteNumber
    case bigint(String)
    case array([StableStringifyValue])
    case object([String: StableStringifyValue])
    case undefined
    case function
    indirect case toJSON(StableStringifyValue)
}

public func fastStableStringify(_ value: StableStringifyValue) -> String? {
    stringify(value, isArrayProperty: false)
}

private func stringify(_ value: StableStringifyValue, isArrayProperty: Bool) -> String? {
    switch value {
    case .null:
        return "null"
    case let .bool(value):
        return value ? "true" : "false"
    case let .string(value):
        return quoteJSONString(value)
    case let .number(value):
        return value
    case .nonFiniteNumber:
        return "null"
    case let .bigint(value):
        return "\(value)n"
    case let .array(values):
        let body = values
            .map { stringify($0, isArrayProperty: true) ?? "null" }
            .joined(separator: ",")
        return "[\(body)]"
    case let .object(values):
        let body = values.keys
            .sorted(by: utf16LexicographicPrecedes)
            .compactMap { key -> String? in
                guard let value = values[key], let property = stringify(value, isArrayProperty: false) else {
                    return nil
                }
                return "\(quoteJSONString(key)):\(property)"
            }
            .joined(separator: ",")
        return "{\(body)}"
    case .undefined, .function:
        return isArrayProperty ? "null" : nil
    case let .toJSON(value):
        return stringify(value, isArrayProperty: isArrayProperty)
    }
}

private func utf16LexicographicPrecedes(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf16.lexicographicallyPrecedes(rhs.utf16)
}

private func quoteJSONString(_ value: String) -> String {
    var output = "\""
    for scalar in value.unicodeScalars {
        switch scalar.value {
        case 0x08:
            output += "\\b"
        case 0x09:
            output += "\\t"
        case 0x0a:
            output += "\\n"
        case 0x0c:
            output += "\\f"
        case 0x0d:
            output += "\\r"
        case 0x22:
            output += "\\\""
        case 0x5c:
            output += "\\\\"
        case 0x00 ... 0x1f:
            output += String(format: "\\u%04x", scalar.value)
        default:
            output.unicodeScalars.append(scalar)
        }
    }
    output += "\""
    return output
}
