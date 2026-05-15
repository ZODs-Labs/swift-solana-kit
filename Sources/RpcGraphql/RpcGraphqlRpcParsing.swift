enum RpcGraphqlRpcParsing {
    static func accountRecord(from value: RpcGraphqlArgumentValue?) -> RpcGraphqlAccountRecord? {
        guard let fields = RpcGraphqlValueAccess.object(value) else {
            return nil
        }

        var parsedFields: [String: RpcGraphqlArgumentValue] = fields
        var jsonParsedConfigs: [String: String]?
        let data = accountData(from: fields["data"], fields: &parsedFields, jsonParsedConfigs: &jsonParsedConfigs)

        return RpcGraphqlAccountRecord(
            data: data,
            executable: RpcGraphqlValueAccess.bool(fields["executable"]),
            lamports: RpcGraphqlValueAccess.uint(fields["lamports"]),
            owner: RpcGraphqlValueAccess.string(fields["owner"]),
            space: RpcGraphqlValueAccess.uint(fields["space"]),
            fields: parsedFields,
            jsonParsedConfigs: jsonParsedConfigs
        )
    }

    static func accountInfoValue(from response: RpcGraphqlArgumentValue) -> RpcGraphqlAccountRecord? {
        let value = RpcGraphqlValueAccess.object(response)?["value"]
        return accountRecord(from: value)
    }

    static func multipleAccountValues(from response: RpcGraphqlArgumentValue) -> [RpcGraphqlAccountRecord?] {
        guard let values = RpcGraphqlValueAccess.list(RpcGraphqlValueAccess.object(response)?["value"]) else {
            return []
        }
        return values.map(accountRecord(from:))
    }

    static func programAccountValues(from response: RpcGraphqlArgumentValue) -> [RpcGraphqlAccountRecord] {
        guard let values = RpcGraphqlValueAccess.list(response) else {
            return []
        }
        return values.compactMap { value in
            guard let fields = RpcGraphqlValueAccess.object(value),
                  var account = accountRecord(from: fields["account"])
            else {
                return nil
            }
            account.address = RpcGraphqlValueAccess.string(fields["pubkey"])
            return account
        }
    }

    private static func accountData(
        from value: RpcGraphqlArgumentValue?,
        fields: inout [String: RpcGraphqlArgumentValue],
        jsonParsedConfigs: inout [String: String]?
    ) -> RpcGraphqlAccountData? {
        if case let .string(data)? = value {
            return .base58(data)
        }
        if case let .list(values)? = value,
           values.count >= 2,
           let data = values[0].stringValue,
           let encodingValue = values[1].stringValue,
           let encoding = RpcGraphqlAccountEncoding(rpcValue: encodingValue) {
            return .encoded(data, encoding: encoding)
        }
        guard let dataFields = RpcGraphqlValueAccess.object(value),
              let parsed = RpcGraphqlValueAccess.object(dataFields["parsed"])
        else {
            return nil
        }

        var configs: [String: String] = [:]
        if let type = RpcGraphqlValueAccess.string(parsed["type"]) {
            configs["accountType"] = type
        }
        if let program = RpcGraphqlValueAccess.string(dataFields["program"]) {
            configs["programName"] = program
        }
        if let programId = RpcGraphqlValueAccess.string(dataFields["programId"]) {
            configs["programId"] = programId
        }
        jsonParsedConfigs = configs.isEmpty ? nil : configs

        if let info = parsed["info"] {
            if case let .object(infoFields) = info {
                for (key, value) in infoFields {
                    fields[key] = value
                }
            } else if case .list = info {
                fields["entries"] = info
            }
            return .jsonParsed(info)
        }
        return .jsonParsed(.object(parsed))
    }
}
