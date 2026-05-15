enum RpcGraphqlLoaderFactory {
    static func createSolanaGraphQLContext(
        transport: RpcGraphqlRpcTransport,
        config: RpcGraphqlConfig = .default
    ) -> RpcGraphqlContext {
        RpcGraphqlContext(
            loaders: RpcGraphqlLoaders(
                account: createAccountLoader(transport: transport, config: config),
                block: createBlockLoader(transport: transport),
                programAccounts: createProgramAccountsLoader(transport: transport, config: config),
                transaction: createTransactionLoader(transport: transport)
            )
        )
    }

    private static func createAccountLoader(
        transport: RpcGraphqlRpcTransport,
        config: RpcGraphqlConfig
    ) -> RpcGraphqlLoader<RpcGraphqlAccountLoaderArguments, RpcGraphqlAccountRecord?> {
        RpcGraphqlLoader { arguments in
            let requests = arguments.map { arguments in
                RpcGraphqlLoadRequest(key: arguments.address, arguments: arguments.withDefaultCommitment())
            }
            let fetches = coalesceAccountFetches(requests, maxDataSliceByteRange: config.maxDataSliceByteRange)
            var results = emptyResults(count: arguments.count, as: RpcGraphqlAccountRecord?.self)

            for fetch in fetches {
                let addresses = orderedKeys(fetch.callbacksByKey)
                do {
                    if addresses.count == 1, let address = addresses.first {
                        let response = try await transport.send(
                            "getAccountInfo",
                            params: [.string(address), fetch.arguments.rpcConfig()]
                        )
                        let account = RpcGraphqlRpcParsing.accountInfoValue(from: response)
                        assignAccount(account, address: address, fetch: fetch, results: &results)
                    } else {
                        let chunks = addresses.chunked(max: config.maxMultipleAccountsBatchSize)
                        for chunk in chunks {
                            let response = try await transport.send(
                                "getMultipleAccounts",
                                params: [.list(chunk.map { .string($0) }), fetch.arguments.rpcConfig()]
                            )
                            let accounts = RpcGraphqlRpcParsing.multipleAccountValues(from: response)
                            for (offset, address) in chunk.enumerated() {
                                let account = offset < accounts.count ? accounts[offset] : nil
                                assignAccount(account, address: address, fetch: fetch, results: &results)
                            }
                        }
                    }
                } catch {
                    assignFailure(String(describing: error), fetch: fetch, results: &results)
                }
            }
            return results
        }
    }

    private static func createProgramAccountsLoader(
        transport: RpcGraphqlRpcTransport,
        config: RpcGraphqlConfig
    ) -> RpcGraphqlLoader<RpcGraphqlProgramAccountsLoaderArguments, [RpcGraphqlAccountRecord]> {
        RpcGraphqlLoader { arguments in
            let requests = arguments.map { arguments in
                RpcGraphqlLoadRequest(key: arguments.programAddress, arguments: arguments.withDefaultCommitment())
            }
            let fetches = RpcGraphqlCoalescer.coalesceDataSlices(
                requests,
                maxDataSliceByteRange: config.maxDataSliceByteRange
            )
            var results = emptyResults(count: arguments.count, as: [RpcGraphqlAccountRecord].self)

            for fetch in fetches {
                do {
                    for programAddress in orderedKeys(fetch.callbacksByKey) {
                        let response = try await transport.send(
                            "getProgramAccounts",
                            params: [.string(programAddress), fetch.arguments.rpcConfig()]
                        )
                        let accounts = RpcGraphqlRpcParsing.programAccountValues(from: response)
                        assignProgramAccounts(accounts, programAddress: programAddress, fetch: fetch, results: &results)
                    }
                } catch {
                    assignFailure(String(describing: error), fetch: fetch, results: &results)
                }
            }
            return results
        }
    }

    private static func createBlockLoader(
        transport: RpcGraphqlRpcTransport
    ) -> RpcGraphqlLoader<RpcGraphqlBlockLoaderArguments, RpcGraphqlArgumentValue?> {
        RpcGraphqlLoader { arguments in
            let requests = arguments.map { arguments in
                let arguments = arguments.withRpcDefaults()
                return RpcGraphqlLoadRequest(key: String(arguments.slot), arguments: arguments)
            }
            let fetches = RpcGraphqlCoalescer.coalesce(
                requests,
                orphanCriteria: { $0.encoding == nil && $0.transactionDetails != .signatures },
                orphanDefaults: { $0.withTransactionDetails(.none) },
                orphanHashOmit: ["encoding", "transactionDetails"]
            )
            var results = emptyResults(count: arguments.count, as: RpcGraphqlArgumentValue?.self)

            for fetch in fetches {
                do {
                    for slot in orderedKeys(fetch.callbacksByKey) {
                        var callArguments = fetch.arguments
                        callArguments.slot = UInt64(slot) ?? callArguments.slot
                        let response = try await transport.send(
                            "getBlock",
                            params: [.uint(callArguments.slot), callArguments.rpcConfig()]
                        )
                        assignValue(response == .null ? nil : response, key: slot, fetch: fetch, results: &results)
                    }
                } catch {
                    assignFailure(String(describing: error), fetch: fetch, results: &results)
                }
            }
            return results
        }
    }

    private static func createTransactionLoader(
        transport: RpcGraphqlRpcTransport
    ) -> RpcGraphqlLoader<RpcGraphqlTransactionLoaderArguments, RpcGraphqlArgumentValue?> {
        RpcGraphqlLoader { arguments in
            let requests = arguments.map { arguments in
                RpcGraphqlLoadRequest(key: arguments.signature, arguments: arguments.withDefaultCommitment())
            }
            let fetches = RpcGraphqlCoalescer.coalesce(
                requests,
                orphanCriteria: { $0.encoding == nil },
                orphanDefaults: { $0.withDefaultEncoding("base64") },
                orphanHashOmit: ["encoding"]
            )
            var results = emptyResults(count: arguments.count, as: RpcGraphqlArgumentValue?.self)

            for fetch in fetches {
                do {
                    for signature in orderedKeys(fetch.callbacksByKey) {
                        var callArguments = fetch.arguments
                        callArguments.signature = signature
                        let response = try await transport.send(
                            "getTransaction",
                            params: [.string(signature), callArguments.rpcConfig()]
                        )
                        assignValue(response == .null ? nil : response, key: signature, fetch: fetch, results: &results)
                    }
                } catch {
                    assignFailure(String(describing: error), fetch: fetch, results: &results)
                }
            }
            return results
        }
    }
}

private func emptyResults<Value: Sendable>(
    count: Int,
    as valueType: Value.Type
) -> [RpcGraphqlLoadResult<Value>] {
    Array(repeating: .failure("Result was not assigned"), count: count)
}

private func orderedKeys<Callbacks>(_ callbacksByKey: [String: Callbacks]) -> [String] {
    callbacksByKey.keys.sorted()
}

private func assignAccount(
    _ account: RpcGraphqlAccountRecord?,
    address: String,
    fetch: RpcGraphqlCoalescedDataSliceFetch<RpcGraphqlAccountLoaderArguments>,
    results: inout [RpcGraphqlLoadResult<RpcGraphqlAccountRecord?>]
) {
    guard let callbacks = fetch.callbacksByKey[address] else {
        return
    }
    for callback in callbacks {
        do {
            let sliced = try RpcGraphqlAccountDataSlicer.slice(
                account,
                dataSlice: callback.dataSlice,
                masterDataSlice: fetch.arguments.dataSlice
            )
            results[callback.requestIndex] = .value(sliced)
        } catch {
            results[callback.requestIndex] = .failure(String(describing: error))
        }
    }
}

private func assignProgramAccounts(
    _ accounts: [RpcGraphqlAccountRecord],
    programAddress: String,
    fetch: RpcGraphqlCoalescedDataSliceFetch<RpcGraphqlProgramAccountsLoaderArguments>,
    results: inout [RpcGraphqlLoadResult<[RpcGraphqlAccountRecord]>]
) {
    guard let callbacks = fetch.callbacksByKey[programAddress] else {
        return
    }
    for callback in callbacks {
        do {
            let slicedAccounts = try accounts.map {
                try RpcGraphqlAccountDataSlicer.slice(
                    $0,
                    dataSlice: callback.dataSlice,
                    masterDataSlice: fetch.arguments.dataSlice
                ) ?? $0
            }
            results[callback.requestIndex] = .value(slicedAccounts)
        } catch {
            results[callback.requestIndex] = .failure(String(describing: error))
        }
    }
}

private func assignValue<Value: Sendable>(
    _ value: Value,
    key: String,
    fetch: RpcGraphqlCoalescedFetch<some Sendable>,
    results: inout [RpcGraphqlLoadResult<Value>]
) {
    guard let callbacks = fetch.callbacksByKey[key] else {
        return
    }
    for index in callbacks {
        results[index] = .value(value)
    }
}

private func assignFailure<Value: Sendable, Arguments: Sendable>(
    _ message: String,
    fetch: RpcGraphqlCoalescedFetch<Arguments>,
    results: inout [RpcGraphqlLoadResult<Value>]
) {
    for callbacks in fetch.callbacksByKey.values {
        for index in callbacks {
            results[index] = .failure(message)
        }
    }
}

private func assignFailure<Value: Sendable, Arguments: Sendable>(
    _ message: String,
    fetch: RpcGraphqlCoalescedDataSliceFetch<Arguments>,
    results: inout [RpcGraphqlLoadResult<Value>]
) {
    for callbacks in fetch.callbacksByKey.values {
        for callback in callbacks {
            results[callback.requestIndex] = .failure(message)
        }
    }
}

private func coalesceAccountFetches(
    _ requests: [RpcGraphqlLoadRequest<RpcGraphqlAccountLoaderArguments>],
    maxDataSliceByteRange: Int
) -> [RpcGraphqlCoalescedDataSliceFetch<RpcGraphqlAccountLoaderArguments>] {
    var fetches: [RpcGraphqlCoalescedDataSliceFetch<RpcGraphqlAccountLoaderArguments>] = []
    var orphans: [(index: Int, request: RpcGraphqlLoadRequest<RpcGraphqlAccountLoaderArguments>)] = []

    for (index, request) in requests.enumerated() {
        let arguments = request.arguments
        if arguments.encoding == nil {
            orphans.append((index, request))
            continue
        }
        if arguments.encoding != .base64Zstd, let dataSlice = arguments.dataSlice {
            var merged = false
            for fetchIndex in fetches.indices {
                let fetchArguments = fetches[fetchIndex].arguments
                if arguments.stableKey(omitting: ["address", "dataSlice"])
                    != fetchArguments.stableKey(omitting: ["address", "dataSlice"]) {
                    continue
                }
                if let groupedSlice = fetchArguments.dataSlice {
                    if let updatedSlice = mergedDataSlice(
                        dataSlice,
                        groupedSlice,
                        maxDataSliceByteRange: maxDataSliceByteRange
                    ) {
                        fetches[fetchIndex].arguments = fetchArguments.withDataSlice(updatedSlice)
                        fetches[fetchIndex].callbacksByKey[request.key, default: []].append(
                            RpcGraphqlCoalescedDataSliceCallback(requestIndex: index, dataSlice: dataSlice)
                        )
                        merged = true
                        break
                    }
                } else {
                    fetches[fetchIndex].arguments = fetchArguments.withDataSlice(dataSlice)
                    fetches[fetchIndex].callbacksByKey[request.key, default: []].append(
                        RpcGraphqlCoalescedDataSliceCallback(requestIndex: index, dataSlice: dataSlice)
                    )
                    merged = true
                    break
                }
            }
            if merged {
                continue
            }
        }
        appendAccountFetch(index: index, request: request, arguments: arguments, dataSlice: arguments.dataSlice, to: &fetches)
    }

    for (index, request) in orphans {
        if let fetchIndex = fetches.firstIndex(where: {
            request.arguments.stableKey(omitting: ["address", "encoding", "dataSlice"])
                == $0.arguments.stableKey(omitting: ["address", "encoding", "dataSlice"])
        }) {
            fetches[fetchIndex].callbacksByKey[request.key, default: []].append(
                RpcGraphqlCoalescedDataSliceCallback(requestIndex: index, dataSlice: nil)
            )
            continue
        }
        let arguments = request.arguments.withDefaultEncoding("base64")
        appendAccountFetch(index: index, request: request, arguments: arguments, dataSlice: nil, to: &fetches)
    }

    return fetches
}

private func appendAccountFetch(
    index: Int,
    request: RpcGraphqlLoadRequest<RpcGraphqlAccountLoaderArguments>,
    arguments: RpcGraphqlAccountLoaderArguments,
    dataSlice: RpcGraphqlDataSlice?,
    to fetches: inout [RpcGraphqlCoalescedDataSliceFetch<RpcGraphqlAccountLoaderArguments>]
) {
    let argumentsKey = arguments.stableKey(omitting: ["address"])
    if let fetchIndex = fetches.firstIndex(where: { $0.arguments.stableKey(omitting: ["address"]) == argumentsKey }) {
        fetches[fetchIndex].callbacksByKey[request.key, default: []].append(
            RpcGraphqlCoalescedDataSliceCallback(requestIndex: index, dataSlice: dataSlice)
        )
        return
    }
    fetches.append(
        RpcGraphqlCoalescedDataSliceFetch(
            arguments: arguments,
            callbacksByKey: [
                request.key: [RpcGraphqlCoalescedDataSliceCallback(requestIndex: index, dataSlice: dataSlice)],
            ]
        )
    )
}

private func mergedDataSlice(
    _ requested: RpcGraphqlDataSlice,
    _ grouped: RpcGraphqlDataSlice,
    maxDataSliceByteRange: Int
) -> RpcGraphqlDataSlice? {
    if requested.offset <= grouped.offset,
       grouped.offset - requested.offset + requested.length <= maxDataSliceByteRange {
        return RpcGraphqlDataSlice(
            length: max(requested.length, grouped.offset + grouped.length - requested.offset),
            offset: requested.offset
        )
    }
    if requested.offset >= grouped.offset,
       requested.offset - grouped.offset + grouped.length <= maxDataSliceByteRange {
        return RpcGraphqlDataSlice(
            length: max(grouped.length, requested.offset + requested.length - grouped.offset),
            offset: grouped.offset
        )
    }
    return nil
}

private extension Array {
    func chunked(max size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }
        var chunks: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            chunks.append(Array(self[index ..< end]))
            index = end
        }
        return chunks
    }
}
