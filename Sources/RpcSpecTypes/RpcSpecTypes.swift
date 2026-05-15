import Foundation
import SolanaErrors
import os

public struct RpcJsonObjectMember: Sendable, Equatable, Hashable {
    public let key: String
    public let value: RpcJsonValue

    public init(_ key: String, _ value: RpcJsonValue) {
        self.key = key
        self.value = value
    }
}

public indirect enum RpcJsonValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case string(String)
    case number(Double)
    case bigint(String)
    case array([RpcJsonValue])
    case object([RpcJsonObjectMember])

    public static func object(_ pairs: [(String, RpcJsonValue)]) -> RpcJsonValue {
        .object(collapseObjectMembers(pairs.map(RpcJsonObjectMember.init)))
    }

    public var objectMembers: [RpcJsonObjectMember]? {
        guard case let .object(members) = self else { return nil }
        return members
    }

    public func value(for key: String) -> RpcJsonValue? {
        guard case let .object(members) = self else { return nil }
        return members.last { $0.key == key }?.value
    }
}

public struct RpcRequest: Sendable, Equatable, Hashable {
    public let methodName: String
    public let params: RpcJsonValue

    public init(methodName: String, params: RpcJsonValue) {
        self.methodName = methodName
        self.params = params
    }
}

public struct RpcMessage: Sendable, Equatable, Hashable {
    public let id: String
    public let jsonrpc: String
    public let method: String
    public let params: RpcJsonValue

    public init(id: String, jsonrpc: String = "2.0", method: String, params: RpcJsonValue) {
        self.id = id
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
    }

    public var jsonValue: RpcJsonValue {
        .object([
            RpcJsonObjectMember("id", .string(id)),
            RpcJsonObjectMember("jsonrpc", .string(jsonrpc)),
            RpcJsonObjectMember("method", .string(method)),
            RpcJsonObjectMember("params", params),
        ])
    }
}

public struct RpcResponseErrorPayload: Sendable, Equatable, Hashable {
    public let code: Int
    public let message: String
    public let data: RpcJsonValue?

    public init(code: Int, message: String, data: RpcJsonValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public enum RpcResponseData: Sendable, Equatable, Hashable {
    case result(id: String, value: RpcJsonValue)
    case error(id: String, error: RpcResponseErrorPayload)
}

public typealias RpcRequestTransformer = @Sendable (RpcRequest) throws -> RpcRequest

public struct RpcResponseTransformer: Sendable {
    package let identity: String
    private let transform: @Sendable (RpcJsonValue, RpcRequest) throws -> RpcJsonValue

    public init(_ transform: @escaping @Sendable (RpcJsonValue, RpcRequest) throws -> RpcJsonValue) {
        identity = UUID().uuidString
        self.transform = transform
    }

    public func callAsFunction(_ response: RpcJsonValue, _ request: RpcRequest) throws -> RpcJsonValue {
        try transform(response, request)
    }
}

private let nextMessageID = OSAllocatedUnfairLock<UInt64>(initialState: 0)

public func createRpcMessage(_ request: RpcRequest) -> RpcMessage {
    let id = nextMessageID.withLock { value in
        let id = value
        value += 1
        return String(id)
    }
    return RpcMessage(id: id, method: request.methodName, params: request.params)
}

public func parseJsonWithBigInts(_ json: String) throws -> RpcJsonValue {
    var parser = OrderedJSONParser(json: json, parseIntegersAsBigInts: true)
    return try parser.parse()
}

package func parseJson(_ json: String) throws -> RpcJsonValue {
    var parser = OrderedJSONParser(json: json, parseIntegersAsBigInts: false)
    return try parser.parse()
}

public func stringifyJsonWithBigInts(_ value: RpcJsonValue, space: Int? = nil) throws -> String {
    try stringify(value, indent: JSONStringIndent(number: space), level: 0, serializeBigInts: true)
}

public func stringifyJsonWithBigInts(_ value: RpcJsonValue, space: String) throws -> String {
    try stringify(value, indent: JSONStringIndent(string: space), level: 0, serializeBigInts: true)
}

package func stringifyJson(_ value: RpcJsonValue, space: Int? = nil) throws -> String {
    try stringify(value, indent: JSONStringIndent(number: space), level: 0, serializeBigInts: false)
}

package func stringifyJson(_ value: RpcJsonValue, space: String) throws -> String {
    try stringify(value, indent: JSONStringIndent(string: space), level: 0, serializeBigInts: false)
}

private func consumeJSONNumber(_ json: String, at start: String.Index) -> String? {
    var index = start
    if json[index] == "-" {
        index = json.index(after: index)
        guard index < json.endIndex else { return nil }
    }

    guard let first = jsonDigitValue(json[index]) else { return nil }
    if first == 0 {
        index = json.index(after: index)
    } else {
        repeat {
            index = json.index(after: index)
        } while index < json.endIndex && isJSONDigit(json[index])
    }

    if index < json.endIndex, json[index] == "." {
        index = json.index(after: index)
        guard index < json.endIndex, isJSONDigit(json[index]) else { return nil }
        repeat {
            index = json.index(after: index)
        } while index < json.endIndex && isJSONDigit(json[index])
    }

    if index < json.endIndex, json[index] == "e" || json[index] == "E" {
        index = json.index(after: index)
        if index < json.endIndex, json[index] == "+" || json[index] == "-" {
            index = json.index(after: index)
        }
        guard index < json.endIndex, isJSONDigit(json[index]) else { return nil }
        repeat {
            index = json.index(after: index)
        } while index < json.endIndex && isJSONDigit(json[index])
    }

    return String(json[start ..< index])
}

private struct OrderedJSONParser {
    let json: String
    let parseIntegersAsBigInts: Bool
    var index: String.Index

    init(json: String, parseIntegersAsBigInts: Bool) {
        self.json = json
        self.parseIntegersAsBigInts = parseIntegersAsBigInts
        self.index = json.startIndex
    }

    mutating func parse() throws -> RpcJsonValue {
        try skipWhitespace()
        let value = try parseValue()
        try skipWhitespace()
        guard index == json.endIndex else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return value
    }

    mutating func parseValue() throws -> RpcJsonValue {
        try skipWhitespace()
        guard index < json.endIndex else {
            throw SolanaError(.malformedJSONRPCError)
        }
        switch json[index] {
        case "{":
            return try parseObject()
        case "[":
            return try parseArray()
        case "\"":
            return .string(try parseString())
        case "t":
            try consumeLiteral("true")
            return .bool(true)
        case "f":
            try consumeLiteral("false")
            return .bool(false)
        case "n":
            try consumeLiteral("null")
            return .null
        default:
            return try parseNumber()
        }
    }

    mutating func parseObject() throws -> RpcJsonValue {
        try consume("{")
        try skipWhitespace()
        if try consumeIfPresent("}") {
            return .object([RpcJsonObjectMember]())
        }

        var members: [RpcJsonObjectMember] = []
        while true {
            try skipWhitespace()
            guard index < json.endIndex, json[index] == "\"" else {
                throw SolanaError(.malformedJSONRPCError)
            }
            let key = try parseString()
            try skipWhitespace()
            try consume(":")
            let value = try parseValue()
            members.append(RpcJsonObjectMember(key, value))
            try skipWhitespace()
            if try consumeIfPresent("}") {
                break
            }
            try consume(",")
        }
        return .object(collapseObjectMembers(members))
    }

    mutating func parseArray() throws -> RpcJsonValue {
        try consume("[")
        try skipWhitespace()
        if try consumeIfPresent("]") {
            return .array([])
        }

        var values: [RpcJsonValue] = []
        while true {
            values.append(try parseValue())
            try skipWhitespace()
            if try consumeIfPresent("]") {
                break
            }
            try consume(",")
        }
        return .array(values)
    }

    mutating func parseString() throws -> String {
        try consume("\"")
        var output = ""
        while index < json.endIndex {
            let character = json[index]
            index = json.index(after: index)
            switch character {
            case "\"":
                return output
            case "\\":
                try appendEscapedStringCharacter(to: &output)
            default:
                guard character.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) else {
                    throw SolanaError(.malformedJSONRPCError)
                }
                output.append(character)
            }
        }
        throw SolanaError(.malformedJSONRPCError)
    }

    mutating func appendEscapedStringCharacter(to output: inout String) throws {
        guard index < json.endIndex else {
            throw SolanaError(.malformedJSONRPCError)
        }
        let escaped = json[index]
        index = json.index(after: index)
        switch escaped {
        case "\"", "\\", "/":
            output.append(escaped)
        case "b":
            output.append("\u{08}")
        case "f":
            output.append("\u{0c}")
        case "n":
            output.append("\n")
        case "r":
            output.append("\r")
        case "t":
            output.append("\t")
        case "u":
            let scalar = try parseUnicodeEscape()
            output.unicodeScalars.append(scalar)
        default:
            throw SolanaError(.malformedJSONRPCError)
        }
    }

    mutating func parseUnicodeEscape() throws -> UnicodeScalar {
        let high = try parseHexScalarValue()
        if high >= 0xD800 && high <= 0xDBFF {
            let saved = index
            if index < json.endIndex, json[index] == "\\" {
                index = json.index(after: index)
                if index < json.endIndex, json[index] == "u" {
                    index = json.index(after: index)
                    let low = try parseHexScalarValue()
                    if low >= 0xDC00 && low <= 0xDFFF {
                        let combined = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
                        guard let scalar = UnicodeScalar(combined) else {
                            throw SolanaError(.malformedJSONRPCError)
                        }
                        return scalar
                    }
                }
            }
            index = saved
            throw SolanaError(.malformedJSONRPCError)
        }
        guard let scalar = UnicodeScalar(high), !(high >= 0xDC00 && high <= 0xDFFF) else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return scalar
    }

    mutating func parseHexScalarValue() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            guard index < json.endIndex,
                  let digit = json[index].hexDigitValue
            else {
                throw SolanaError(.malformedJSONRPCError)
            }
            value = (value << 4) | UInt32(digit)
            index = json.index(after: index)
        }
        return value
    }

    mutating func parseNumber() throws -> RpcJsonValue {
        guard let raw = consumeJSONNumber(json, at: index) else {
            throw SolanaError(.malformedJSONRPCError)
        }
        index = json.index(index, offsetBy: raw.count)
        if parseIntegersAsBigInts,
           raw.range(of: ".") == nil,
           raw.range(of: "e-") == nil,
           raw.range(of: "E-") == nil {
            return .bigint(try canonicalBigIntString(raw))
        }
        guard let value = Double(raw), value.isFinite else {
            throw SolanaError(.malformedJSONRPCError)
        }
        return .number(value)
    }

    mutating func consumeLiteral(_ literal: String) throws {
        guard json[index...].hasPrefix(literal) else {
            throw SolanaError(.malformedJSONRPCError)
        }
        index = json.index(index, offsetBy: literal.count)
    }

    mutating func consume(_ character: Character) throws {
        guard index < json.endIndex, json[index] == character else {
            throw SolanaError(.malformedJSONRPCError)
        }
        index = json.index(after: index)
    }

    mutating func consumeIfPresent(_ character: Character) throws -> Bool {
        guard index < json.endIndex, json[index] == character else {
            return false
        }
        index = json.index(after: index)
        return true
    }

    mutating func skipWhitespace() throws {
        while index < json.endIndex {
            switch json[index] {
            case " ", "\n", "\r", "\t":
                index = json.index(after: index)
            default:
                return
            }
        }
    }
}

private func canonicalBigIntString(_ value: String) throws -> String {
    let expanded: String
    if let exponentRange = value.range(of: "e", options: [.caseInsensitive]) {
        let units = String(value[..<exponentRange.lowerBound])
        let exponentText = String(value[exponentRange.upperBound...])
        guard !exponentText.hasPrefix("-"),
              let exponent = Int(exponentText.trimmingPrefix("+")),
              exponent >= 0
        else {
            throw SolanaError(.malformedBigintString, context: ["value": .string(value)])
        }
        let canonicalUnits = try canonicalPlainInteger(units)
        expanded = canonicalUnits == "0" ? "0" : canonicalUnits + String(repeating: "0", count: exponent)
    } else {
        expanded = value
    }
    return try canonicalPlainInteger(expanded)
}

private func canonicalPlainInteger(_ value: String) throws -> String {
    guard !value.isEmpty else {
        throw SolanaError(.malformedBigintString, context: ["value": .string(value)])
    }
    let isNegative = value.first == "-"
    let digits = isNegative ? String(value.dropFirst()) : value
    guard !digits.isEmpty, digits.allSatisfy(isJSONDigit) else {
        throw SolanaError(.malformedBigintString, context: ["value": .string(value)])
    }
    let trimmed = digits.drop { $0 == "0" }
    guard !trimmed.isEmpty else { return "0" }
    return isNegative ? "-\(trimmed)" : String(trimmed)
}

private func isJSONDigit(_ character: Character) -> Bool {
    jsonDigitValue(character) != nil
}

private func jsonDigitValue(_ character: Character) -> Int? {
    guard let scalar = character.unicodeScalars.first,
          character.unicodeScalars.count == 1
    else {
        return nil
    }
    guard scalar.value >= 48 && scalar.value <= 57 else {
        return nil
    }
    return Int(scalar.value - 48)
}

private struct JSONStringIndent {
    let unit: String

    var enabled: Bool {
        !unit.isEmpty
    }

    init(number: Int?) {
        let count = min(max(number ?? 0, 0), 10)
        unit = String(repeating: " ", count: count)
    }

    init(string: String) {
        unit = String(decoding: string.utf16.prefix(10), as: UTF16.self)
    }
}

private func stringify(_ value: RpcJsonValue, indent: JSONStringIndent, level: Int, serializeBigInts: Bool) throws -> String {
    switch value {
    case .null:
        return "null"
    case let .bool(value):
        return value ? "true" : "false"
    case let .string(value):
        return quoteJSONString(value)
    case let .number(value):
        guard value.isFinite else { return "null" }
        return try stringifyNumber(value)
    case let .bigint(value):
        guard serializeBigInts else {
            throw SolanaError(.malformedJSONRPCError, context: ["message": .string("BigInt value cannot be serialized with JSON.stringify")])
        }
        return try canonicalBigIntString(value)
    case let .array(values):
        return try stringifyArray(values, indent: indent, level: level, serializeBigInts: serializeBigInts)
    case let .object(members):
        return try stringifyObject(members, indent: indent, level: level, serializeBigInts: serializeBigInts)
    }
}

private func stringifyArray(_ values: [RpcJsonValue], indent: JSONStringIndent, level: Int, serializeBigInts: Bool) throws -> String {
    let body = try values.map { try stringify($0, indent: indent, level: level + 1, serializeBigInts: serializeBigInts) }
    guard indent.enabled else {
        return "[\(body.joined(separator: ","))]"
    }
    guard !body.isEmpty else { return "[]" }
    let currentPadding = String(repeating: indent.unit, count: level)
    let nextPadding = String(repeating: indent.unit, count: level + 1)
    return "[\n\(nextPadding)\(body.joined(separator: ",\n\(nextPadding)"))\n\(currentPadding)]"
}

private func stringifyObject(_ members: [RpcJsonObjectMember], indent: JSONStringIndent, level: Int, serializeBigInts: Bool) throws -> String {
    let body = try collapseObjectMembers(members).map { member in
        let value = try stringify(member.value, indent: indent, level: level + 1, serializeBigInts: serializeBigInts)
        return "\(quoteJSONString(member.key)):\(indent.enabled ? " " : "")\(value)"
    }
    guard indent.enabled else {
        return "{\(body.joined(separator: ","))}"
    }
    guard !body.isEmpty else { return "{}" }
    let currentPadding = String(repeating: indent.unit, count: level)
    let nextPadding = String(repeating: indent.unit, count: level + 1)
    return "{\n\(nextPadding)\(body.joined(separator: ",\n\(nextPadding)"))\n\(currentPadding)}"
}

private func collapseObjectMembers(_ members: [RpcJsonObjectMember]) -> [RpcJsonObjectMember] {
    var collapsed: [RpcJsonObjectMember] = []
    for member in members {
        if let index = collapsed.firstIndex(where: { $0.key == member.key }) {
            collapsed[index] = member
        } else {
            collapsed.append(member)
        }
    }
    return collapsed
}

private func stringifyNumber(_ value: Double) throws -> String {
    let absolute = Swift.abs(value)
    if value == 0 {
        return "0"
    }
    let raw = stripTrailingZeroFraction(normalizeExponent(String(value)))
    if absolute >= 0.000001 && absolute < 1e21 {
        return expandScientificNotation(raw) ?? raw
    }
    return raw
}

private func stripTrailingZeroFraction(_ value: String) -> String {
    guard value.hasSuffix(".0") else {
        return value
    }
    return String(value.dropLast(2))
}

private func normalizeExponent(_ value: String) -> String {
    guard let exponentIndex = value.firstIndex(where: { $0 == "e" || $0 == "E" }) else {
        return value
    }
    let significand = value[..<exponentIndex]
    let exponentStart = value.index(after: exponentIndex)
    var exponent = String(value[exponentStart...])
    var sign = ""
    if exponent.first == "+" || exponent.first == "-" {
        sign = String(exponent.removeFirst())
    }
    while exponent.count > 1 && exponent.first == "0" {
        exponent.removeFirst()
    }
    return "\(significand)e\(sign)\(exponent)"
}

private func expandScientificNotation(_ value: String) -> String? {
    let parts = value.split(separator: "e", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, let exponent = Int(parts[1]) else {
        return nil
    }
    var significand = String(parts[0])
    let sign: String
    if significand.first == "-" {
        sign = "-"
        significand.removeFirst()
    } else {
        sign = ""
    }
    let significandParts = significand.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let integerPart = String(significandParts[0])
    let fractionalPart = significandParts.count == 2 ? String(significandParts[1]) : ""
    let digits = integerPart + fractionalPart
    let decimalPosition = integerPart.count + exponent
    if decimalPosition <= 0 {
        return "\(sign)0.\(String(repeating: "0", count: -decimalPosition))\(digits)"
    }
    if decimalPosition >= digits.count {
        return "\(sign)\(digits)\(String(repeating: "0", count: decimalPosition - digits.count))"
    }
    let splitIndex = digits.index(digits.startIndex, offsetBy: decimalPosition)
    return "\(sign)\(digits[..<splitIndex]).\(digits[splitIndex...])"
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

private extension String {
    func trimmingPrefix(_ prefix: Character) -> String {
        first == prefix ? String(dropFirst()) : self
    }
}
