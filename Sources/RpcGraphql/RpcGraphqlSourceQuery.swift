import Foundation

struct RpcGraphqlSourceQueryExecutor: Sendable {
    var context: RpcGraphqlContext

    func query(
        source: String,
        variableValues: [String: RpcGraphqlArgumentValue]
    ) async -> RpcGraphqlExecutionResult {
        do {
            var parser = RpcGraphqlSourceParser(source: source)
            let document = try parser.parse()
            var data: [String: RpcGraphqlArgumentValue] = [:]
            var errors: [String] = []

            for root in document.roots {
                do {
                    data[root.alias] = try await execute(root, document: document, variableValues: variableValues)
                } catch {
                    data[root.alias] = .null
                    errors.append(error.localizedDescription)
                }
            }

            return RpcGraphqlExecutionResult(data: data, errors: errors)
        } catch {
            return RpcGraphqlExecutionResult(data: [:], errors: [error.localizedDescription])
        }
    }

    private func execute(
        _ root: RpcGraphqlParsedRoot,
        document: RpcGraphqlParsedDocument,
        variableValues: [String: RpcGraphqlArgumentValue]
    ) async throws -> RpcGraphqlArgumentValue {
        let info = RpcGraphqlResolveInfo(
            selections: root.selections,
            fragments: document.fragments,
            variableValues: variableValues
        )
        switch root.fieldName {
        case "account":
            let address = try requiredString(root.arguments["address"], variables: variableValues, name: "address")
            let result = await RpcGraphqlResolvers.resolveAccount(
                address: address,
                commitment: commitment(root.arguments["commitment"], variables: variableValues),
                minContextSlot: slot(root.arguments["minContextSlot"], variables: variableValues),
                context: context,
                info: info
            )
            return await accountValue(result, selections: root.selections, info: info)
        case "programAccounts":
            let address = try requiredString(root.arguments["programAddress"], variables: variableValues, name: "programAddress")
            let result = await RpcGraphqlResolvers.resolveProgramAccounts(
                programAddress: address,
                commitment: commitment(root.arguments["commitment"], variables: variableValues),
                dataSizeFilters: dataSizeFilters(root.arguments["dataSizeFilters"], variables: variableValues),
                memcmpFilters: memcmpFilters(root.arguments["memcmpFilters"], variables: variableValues),
                minContextSlot: slot(root.arguments["minContextSlot"], variables: variableValues),
                context: context,
                info: info
            )
            let accounts = result ?? []
            let rendered = await accounts.asyncMap { account in
                await accountValue(account, selections: root.selections, info: info)
            }
            return .list(rendered)
        case "block":
            let blockSlot = try requiredSlot(root.arguments["slot"], variables: variableValues, name: "slot")
            let arguments = RpcGraphqlResolvers.blockLoaderArguments(
                slot: blockSlot,
                commitment: commitment(root.arguments["commitment"], variables: variableValues),
                info: info
            )
            let loaded = await context.loaders.block.loadMany(arguments)
            guard let value = firstValue(from: loaded) else {
                return .null
            }
            return render(value, selections: root.selections, info: info)
        case "transaction":
            let signature = try requiredString(root.arguments["signature"], variables: variableValues, name: "signature")
            let arguments = RpcGraphqlResolvers.transactionLoaderArguments(
                signature: signature,
                commitment: commitment(root.arguments["commitment"], variables: variableValues),
                info: info
            )
            let loaded = await context.loaders.transaction.loadMany(arguments)
            guard let value = firstValue(from: loaded) else {
                return .null
            }
            return render(value, selections: root.selections, info: info)
        default:
            throw RpcGraphqlSourceQueryError.unsupportedRootField(root.fieldName)
        }
    }

    private func accountValue(
        _ result: RpcGraphqlAccountResult?,
        selections: [RpcGraphqlSelection],
        info: RpcGraphqlResolveInfo
    ) async -> RpcGraphqlArgumentValue {
        guard let result else {
            return .null
        }
        var object: [String: RpcGraphqlArgumentValue] = [:]
        await renderAccountSelections(result, selections: selections, info: info, into: &object)
        return .object(object)
    }

    private func renderAccountSelections(
        _ result: RpcGraphqlAccountResult,
        selections: [RpcGraphqlSelection],
        info: RpcGraphqlResolveInfo,
        into object: inout [String: RpcGraphqlArgumentValue]
    ) async {
        for selection in selections {
            switch selection {
            case let .field(name, arguments, nestedSelections):
                let fieldName = RpcGraphqlSelectionVisitor.canonicalFieldName(name, arguments: arguments)
                if fieldName == "__typename" {
                    object[name] = .string(result.jsonParsedConfigs["accountType"] ?? "Account")
                } else if fieldName == "address" {
                    object[name] = .string(result.address)
                } else if fieldName == "data" {
                    object[name] = accountData(result, arguments: arguments, variables: info.variableValues)
                } else if fieldName == "ownerProgram" {
                    object[name] = await ownerProgram(result, arguments: arguments, selections: nestedSelections, info: info)
                } else if let value = result.fields[fieldName] {
                    object[name] = value
                } else {
                    object[name] = .null
                }
            case let .inlineFragment(_, selections):
                await renderAccountSelections(result, selections: selections, info: info, into: &object)
            case let .fragmentSpread(name):
                if let selections = info.fragments[name] {
                    await renderAccountSelections(result, selections: selections, info: info, into: &object)
                }
            }
        }
    }

    private func ownerProgram(
        _ result: RpcGraphqlAccountResult,
        arguments: [String: RpcGraphqlArgumentValue],
        selections: [RpcGraphqlSelection],
        info: RpcGraphqlResolveInfo
    ) async -> RpcGraphqlArgumentValue {
        guard let address = result.ownerProgram else {
            return .null
        }
        guard !selections.isEmpty else {
            return .string(address)
        }
        let nestedInfo = RpcGraphqlResolveInfo(
            selections: selections,
            fragments: info.fragments,
            variableValues: info.variableValues,
            accountInterfaceFields: info.accountInterfaceFields
        )
        let nested = await RpcGraphqlResolvers.resolveAccount(
            address: address,
            commitment: commitment(arguments["commitment"], variables: info.variableValues),
            minContextSlot: slot(arguments["minContextSlot"], variables: info.variableValues),
            context: context,
            info: nestedInfo
        )
        return await accountValue(nested, selections: selections, info: nestedInfo)
    }

    private func accountData(
        _ result: RpcGraphqlAccountResult,
        arguments: [String: RpcGraphqlArgumentValue],
        variables: [String: RpcGraphqlArgumentValue]
    ) -> RpcGraphqlArgumentValue {
        guard let encoding = accountEncoding(arguments["encoding"], variables: variables),
              let data = RpcGraphqlResolvers.resolveAccountData(
                  parent: result,
                  encoding: encoding,
                  dataSlice: dataSlice(arguments["dataSlice"], variables: variables)
              )
        else {
            return .null
        }
        return .string(data)
    }

    private func render(
        _ value: RpcGraphqlArgumentValue,
        selections: [RpcGraphqlSelection],
        info: RpcGraphqlResolveInfo
    ) -> RpcGraphqlArgumentValue {
        guard case let .object(fields) = value else {
            return value
        }
        return .object(renderObject(fields, selections: selections, info: info))
    }

    private func renderObject(
        _ fields: [String: RpcGraphqlArgumentValue],
        selections: [RpcGraphqlSelection],
        info: RpcGraphqlResolveInfo
    ) -> [String: RpcGraphqlArgumentValue] {
        var object: [String: RpcGraphqlArgumentValue] = [:]
        for selection in selections {
            switch selection {
            case let .field(name, arguments, nestedSelections):
                let fieldName = RpcGraphqlSelectionVisitor.canonicalFieldName(name, arguments: arguments)
                if fieldName == "data", let value = transactionData(fields: fields) {
                    object[name] = value
                    continue
                }
                guard let value = fields[fieldName] else {
                    object[name] = .null
                    continue
                }
                object[name] = renderNested(value, selections: nestedSelections, info: info)
            case let .inlineFragment(_, selections):
                object.merge(renderObject(fields, selections: selections, info: info)) { current, _ in current }
            case let .fragmentSpread(name):
                if let fragment = info.fragments[name] {
                    object.merge(renderObject(fields, selections: fragment, info: info)) { current, _ in current }
                }
            }
        }
        return object
    }

    private func transactionData(fields: [String: RpcGraphqlArgumentValue]) -> RpcGraphqlArgumentValue? {
        guard case let .list(values)? = fields["transaction"],
              values.count >= 1,
              let data = values[0].stringValue
        else {
            return nil
        }
        return .string(data)
    }

    private func renderNested(
        _ value: RpcGraphqlArgumentValue,
        selections: [RpcGraphqlSelection],
        info: RpcGraphqlResolveInfo
    ) -> RpcGraphqlArgumentValue {
        if selections.isEmpty {
            return value
        }
        switch value {
        case let .object(fields):
            return .object(renderObject(fields, selections: selections, info: info))
        case let .list(values):
            return .list(values.map { renderNested($0, selections: selections, info: info) })
        default:
            return value
        }
    }

    private func firstValue(
        from results: [RpcGraphqlLoadResult<RpcGraphqlArgumentValue?>]
    ) -> RpcGraphqlArgumentValue? {
        for result in results {
            if case let .value(value?) = result {
                return value
            }
        }
        return nil
    }
}

private struct RpcGraphqlParsedDocument: Sendable {
    var roots: [RpcGraphqlParsedRoot]
    var fragments: [String: [RpcGraphqlSelection]]
}

private struct RpcGraphqlParsedRoot: Sendable {
    var alias: String
    var fieldName: String
    var arguments: [String: RpcGraphqlArgumentValue]
    var selections: [RpcGraphqlSelection]
}

private enum RpcGraphqlSourceQueryError: Error, Sendable, LocalizedError, Equatable {
    case expected(String)
    case missingArgument(String)
    case unsupportedRootField(String)

    var errorDescription: String? {
        switch self {
        case let .expected(token):
            "Expected \(token)"
        case let .missingArgument(name):
            "Missing GraphQL argument \(name)"
        case let .unsupportedRootField(name):
            "Unsupported GraphQL root field \(name)"
        }
    }
}

private struct RpcGraphqlSourceParser {
    private var lexer: RpcGraphqlLexer

    init(source: String) {
        lexer = RpcGraphqlLexer(source)
    }

    mutating func parse() throws -> RpcGraphqlParsedDocument {
        var roots: [RpcGraphqlParsedRoot]?
        var fragments: [String: [RpcGraphqlSelection]] = [:]

        while try !lexer.isAtEnd() {
            if try lexer.consumeName("fragment") {
                let fragmentName = try lexer.consumeName()
                try lexer.expectName("on")
                _ = try lexer.consumeName()
                fragments[fragmentName] = try parseSelectionSet().map(\.selection)
            } else {
                roots = try parseOperation()
            }
        }

        guard let roots else {
            throw RpcGraphqlSourceQueryError.expected("query")
        }
        return RpcGraphqlParsedDocument(roots: roots, fragments: fragments)
    }

    private mutating func parseOperation() throws -> [RpcGraphqlParsedRoot] {
        if try lexer.peekPunctuation("{") {
            return try parseRootSelectionSet()
        }
        try lexer.expectName("query")
        if try lexer.peekKind(.name), try !lexer.peekPunctuation("{") {
            _ = try lexer.consumeName()
        }
        if try lexer.peekPunctuation("(") {
            try lexer.skipBalanced(open: "(", close: ")")
        }
        return try parseRootSelectionSet()
    }

    private mutating func parseRootSelectionSet() throws -> [RpcGraphqlParsedRoot] {
        try lexer.expectPunctuation("{")
        var roots: [RpcGraphqlParsedRoot] = []
        while try !lexer.consumePunctuation("}") {
            let parsed = try parseField()
            roots.append(RpcGraphqlParsedRoot(
                alias: parsed.alias ?? parsed.name,
                fieldName: parsed.name,
                arguments: parsed.arguments,
                selections: parsed.selections
            ))
        }
        return roots
    }

    private mutating func parseSelectionSet() throws -> [RpcGraphqlParsedField] {
        try lexer.expectPunctuation("{")
        var fields: [RpcGraphqlParsedField] = []
        while try !lexer.consumePunctuation("}") {
            fields.append(try parseField())
        }
        return fields
    }

    private mutating func parseField() throws -> RpcGraphqlParsedField {
        if try lexer.consumePunctuation("...") {
            if try lexer.consumeName("on") {
                let typeCondition = try lexer.consumeName()
                let selections = try parseSelectionSet().map(\.selection)
                return RpcGraphqlParsedField(
                    alias: nil,
                    name: "__inlineFragment",
                    arguments: [:],
                    selections: [.inlineFragment(typeCondition: typeCondition, selections: selections)]
                )
            }
            let name = try lexer.consumeName()
            return RpcGraphqlParsedField(
                alias: nil,
                name: "__fragmentSpread",
                arguments: [:],
                selections: [.fragmentSpread(name: name)]
            )
        }

        let firstName = try lexer.consumeName()
        let alias: String?
        let name: String
        if try lexer.consumePunctuation(":") {
            alias = firstName
            name = try lexer.consumeName()
        } else {
            alias = nil
            name = firstName
        }

        let arguments = try parseArgumentsIfPresent()
        let selections = try lexer.peekPunctuation("{") ? parseSelectionSet().map(\.selection) : []
        return RpcGraphqlParsedField(alias: alias, name: name, arguments: arguments, selections: selections)
    }

    private mutating func parseArgumentsIfPresent() throws -> [String: RpcGraphqlArgumentValue] {
        guard try lexer.consumePunctuation("(") else {
            return [:]
        }
        var arguments: [String: RpcGraphqlArgumentValue] = [:]
        while try !lexer.consumePunctuation(")") {
            let name = try lexer.consumeName()
            try lexer.expectPunctuation(":")
            arguments[name] = try parseValue()
            _ = try lexer.consumePunctuation(",")
        }
        return arguments
    }

    private mutating func parseValue() throws -> RpcGraphqlArgumentValue {
        if let variable = try lexer.consumeVariableIfPresent() {
            return .variable(variable)
        }
        if let string = try lexer.consumeStringIfPresent() {
            return .string(string)
        }
        if let number = try lexer.consumeNumberIfPresent() {
            if number.contains(".") {
                return .number(number)
            }
            if let value = Int(number) {
                return .int(value)
            }
            if let value = UInt64(number) {
                return .uint(value)
            }
            return .number(number)
        }
        if try lexer.consumePunctuation("{") {
            var object: [String: RpcGraphqlArgumentValue] = [:]
            while try !lexer.consumePunctuation("}") {
                let key = try lexer.consumeName()
                try lexer.expectPunctuation(":")
                object[key] = try parseValue()
                _ = try lexer.consumePunctuation(",")
            }
            return .object(object)
        }
        if try lexer.consumePunctuation("[") {
            var values: [RpcGraphqlArgumentValue] = []
            while try !lexer.consumePunctuation("]") {
                values.append(try parseValue())
                _ = try lexer.consumePunctuation(",")
            }
            return .list(values)
        }
        let name = try lexer.consumeName()
        switch name {
        case "true":
            return .bool(true)
        case "false":
            return .bool(false)
        case "null":
            return .null
        default:
            return .enumCase(name)
        }
    }
}

private struct RpcGraphqlParsedField: Sendable {
    var alias: String?
    var name: String
    var arguments: [String: RpcGraphqlArgumentValue]
    var selections: [RpcGraphqlSelection]

    var selection: RpcGraphqlSelection {
        if name == "__inlineFragment", let selection = selections.first {
            return selection
        }
        if name == "__fragmentSpread", let selection = selections.first {
            return selection
        }
        var selectionArguments = arguments
        if let alias {
            selectionArguments["__fieldName"] = .string(name)
            return .field(name: alias, arguments: selectionArguments, selections: selections)
        }
        return .field(name: name, arguments: selectionArguments, selections: selections)
    }
}

private enum RpcGraphqlTokenKind: Equatable {
    case name
    case punctuation(String)
    case string
    case number
    case variable
    case end
}

private struct RpcGraphqlToken: Equatable {
    var kind: RpcGraphqlTokenKind
    var text: String
}

private struct RpcGraphqlLexer {
    private var source: [Character]
    private var index = 0
    private var buffered: RpcGraphqlToken?

    init(_ source: String) {
        self.source = Array(source)
    }

    mutating func isAtEnd() throws -> Bool {
        try peek().kind == .end
    }

    mutating func peekKind(_ kind: RpcGraphqlTokenKind) throws -> Bool {
        try peek().kind == kind
    }

    mutating func peekPunctuation(_ punctuation: String) throws -> Bool {
        try peek().kind == .punctuation(punctuation)
    }

    mutating func consumePunctuation(_ punctuation: String) throws -> Bool {
        guard try peekPunctuation(punctuation) else {
            return false
        }
        _ = try next()
        return true
    }

    mutating func expectPunctuation(_ punctuation: String) throws {
        guard try consumePunctuation(punctuation) else {
            throw RpcGraphqlSourceQueryError.expected(punctuation)
        }
    }

    mutating func consumeName(_ expected: String) throws -> Bool {
        let token = try peek()
        guard token.kind == .name, token.text == expected else {
            return false
        }
        _ = try next()
        return true
    }

    mutating func consumeName() throws -> String {
        let token = try next()
        guard token.kind == .name else {
            throw RpcGraphqlSourceQueryError.expected("name")
        }
        return token.text
    }

    mutating func expectName(_ name: String) throws {
        guard try consumeName(name) else {
            throw RpcGraphqlSourceQueryError.expected(name)
        }
    }

    mutating func consumeVariableIfPresent() throws -> String? {
        let token = try peek()
        guard token.kind == .variable else {
            return nil
        }
        _ = try next()
        return token.text
    }

    mutating func consumeStringIfPresent() throws -> String? {
        let token = try peek()
        guard token.kind == .string else {
            return nil
        }
        _ = try next()
        return token.text
    }

    mutating func consumeNumberIfPresent() throws -> String? {
        let token = try peek()
        guard token.kind == .number else {
            return nil
        }
        _ = try next()
        return token.text
    }

    mutating func skipBalanced(open: String, close: String) throws {
        try expectPunctuation(open)
        var depth = 1
        while depth > 0 {
            let token = try next()
            if token.kind == .end {
                throw RpcGraphqlSourceQueryError.expected(close)
            }
            if token.kind == .punctuation(open) {
                depth += 1
            } else if token.kind == .punctuation(close) {
                depth -= 1
            }
        }
    }

    private mutating func peek() throws -> RpcGraphqlToken {
        if let buffered {
            return buffered
        }
        let token = try readToken()
        buffered = token
        return token
    }

    private mutating func next() throws -> RpcGraphqlToken {
        if let token = buffered {
            buffered = nil
            return token
        }
        return try readToken()
    }

    private mutating func readToken() throws -> RpcGraphqlToken {
        skipIgnored()
        guard index < source.count else {
            return RpcGraphqlToken(kind: .end, text: "")
        }
        let character = source[index]
        if character == ".", source[safe: index + 1] == ".", source[safe: index + 2] == "." {
            index += 3
            return RpcGraphqlToken(kind: .punctuation("..."), text: "...")
        }
        if "{}():![]=,".contains(character) {
            index += 1
            return RpcGraphqlToken(kind: .punctuation(String(character)), text: String(character))
        }
        if character == "$" {
            index += 1
            return RpcGraphqlToken(kind: .variable, text: readName())
        }
        if character == "\"" {
            return try readString()
        }
        if character == "-" || character.isNumber {
            return RpcGraphqlToken(kind: .number, text: readNumber())
        }
        if isNameStart(character) {
            return RpcGraphqlToken(kind: .name, text: readName())
        }
        throw RpcGraphqlSourceQueryError.expected("valid token")
    }

    private mutating func skipIgnored() {
        while index < source.count {
            let character = source[index]
            if character == "#" {
                while index < source.count, source[index] != "\n" {
                    index += 1
                }
            } else if character.isWhitespace || character == "," {
                index += 1
            } else {
                return
            }
        }
    }

    private mutating func readName() -> String {
        let start = index
        while index < source.count, isNameContinue(source[index]) {
            index += 1
        }
        return String(source[start..<index])
    }

    private mutating func readNumber() -> String {
        let start = index
        if source[index] == "-" {
            index += 1
        }
        while index < source.count, source[index].isNumber {
            index += 1
        }
        if index < source.count, source[index] == "." {
            index += 1
            while index < source.count, source[index].isNumber {
                index += 1
            }
        }
        return String(source[start..<index])
    }

    private mutating func readString() throws -> RpcGraphqlToken {
        index += 1
        var value = ""
        while index < source.count {
            let character = source[index]
            index += 1
            if character == "\"" {
                return RpcGraphqlToken(kind: .string, text: value)
            }
            if character == "\\" {
                guard index < source.count else {
                    throw RpcGraphqlSourceQueryError.expected("string escape")
                }
                let escaped = source[index]
                index += 1
                switch escaped {
                case "\"", "\\", "/":
                    value.append(escaped)
                case "b":
                    value.append("\u{08}")
                case "f":
                    value.append("\u{0c}")
                case "n":
                    value.append("\n")
                case "r":
                    value.append("\r")
                case "t":
                    value.append("\t")
                default:
                    throw RpcGraphqlSourceQueryError.expected("supported string escape")
                }
            } else {
                value.append(character)
            }
        }
        throw RpcGraphqlSourceQueryError.expected("string terminator")
    }

    private func isNameStart(_ character: Character) -> Bool {
        character == "_" || character.isLetter
    }

    private func isNameContinue(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber
    }
}

private func requiredString(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue],
    name: String
) throws -> String {
    guard let string = value?.resolved(using: variables).stringValue else {
        throw RpcGraphqlSourceQueryError.missingArgument(name)
    }
    return string
}

private func requiredSlot(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue],
    name: String
) throws -> RpcGraphqlSlot {
    guard let slot = uint(value, variables: variables) else {
        throw RpcGraphqlSourceQueryError.missingArgument(name)
    }
    return slot
}

private func commitment(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue]
) -> RpcGraphqlCommitment? {
    guard let value = value?.resolved(using: variables).stringValue else {
        return nil
    }
    switch value {
    case "PROCESSED", "processed":
        return .processed
    case "CONFIRMED", "confirmed":
        return .confirmed
    case "FINALIZED", "finalized":
        return .finalized
    default:
        return nil
    }
}

private func slot(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue]
) -> RpcGraphqlSlot? {
    uint(value, variables: variables)
}

private func uint(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue]
) -> UInt64? {
    switch value?.resolved(using: variables) {
    case let .uint(value):
        return value
    case let .int(value) where value >= 0:
        return UInt64(value)
    case let .number(value):
        return UInt64(value)
    case let .string(value):
        return UInt64(value)
    default:
        return nil
    }
}

private func accountEncoding(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue]
) -> RpcGraphqlAccountEncoding? {
    guard let value = value?.resolved(using: variables).stringValue else {
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

private func dataSlice(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue]
) -> RpcGraphqlDataSlice? {
    switch value?.resolved(using: variables) {
    case let .object(fields):
        guard let length = uint(fields["length"], variables: variables),
              let offset = uint(fields["offset"], variables: variables),
              let lengthInt = Int(exactly: length),
              let offsetInt = Int(exactly: offset)
        else {
            return nil
        }
        return RpcGraphqlDataSlice(length: lengthInt, offset: offsetInt)
    default:
        return nil
    }
}

private func dataSizeFilters(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue]
) -> [RpcGraphqlProgramAccountsDataSizeFilter]? {
    guard case let .list(values)? = value?.resolved(using: variables) else {
        return nil
    }
    return values.compactMap { value in
        guard case let .object(fields) = value,
              let dataSize = uint(fields["dataSize"], variables: variables),
              let dataSizeInt = Int(exactly: dataSize)
        else {
            return nil
        }
        return RpcGraphqlProgramAccountsDataSizeFilter(dataSize: dataSizeInt)
    }
}

private func memcmpFilters(
    _ value: RpcGraphqlArgumentValue?,
    variables: [String: RpcGraphqlArgumentValue]
) -> [RpcGraphqlProgramAccountsMemcmpFilter]? {
    guard case let .list(values)? = value?.resolved(using: variables) else {
        return nil
    }
    return values.compactMap { value in
        guard case let .object(fields) = value,
              let offset = uint(fields["offset"], variables: variables),
              let offsetInt = Int(exactly: offset),
              let bytes = fields["bytes"]?.resolved(using: variables).stringValue
        else {
            return nil
        }
        return RpcGraphqlProgramAccountsMemcmpFilter(
            offset: offsetInt,
            bytes: bytes,
            encoding: fields["encoding"]?.resolved(using: variables).stringValue
        )
    }
}

private extension Array where Element: Sendable {
    func asyncMap<NewElement: Sendable>(
        _ transform: @Sendable (Element) async -> NewElement
    ) async -> [NewElement] {
        var result: [NewElement] = []
        result.reserveCapacity(count)
        for element in self {
            result.append(await transform(element))
        }
        return result
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
