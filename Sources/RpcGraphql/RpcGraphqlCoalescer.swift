struct RpcGraphqlLoadRequest<Arguments: Sendable>: Sendable {
    var key: String
    var arguments: Arguments
}

struct RpcGraphqlCoalescedFetch<Arguments: Sendable>: Sendable {
    var arguments: Arguments
    var callbacksByKey: [String: [Int]]
}

struct RpcGraphqlCoalescedDataSliceCallback: Sendable, Equatable {
    var requestIndex: Int
    var dataSlice: RpcGraphqlDataSlice?
}

struct RpcGraphqlCoalescedDataSliceFetch<Arguments: Sendable>: Sendable {
    var arguments: Arguments
    var callbacksByKey: [String: [RpcGraphqlCoalescedDataSliceCallback]]
}

enum RpcGraphqlCoalescer {
    static func coalesce<Arguments: RpcGraphqlLoadArguments>(
        _ requests: [RpcGraphqlLoadRequest<Arguments>],
        orphanCriteria: (Arguments) -> Bool,
        orphanDefaults: (Arguments) -> Arguments,
        orphanHashOmit: Set<String>
    ) -> [RpcGraphqlCoalescedFetch<Arguments>] {
        var fetches: [RpcGraphqlCoalescedFetch<Arguments>] = []
        var orphanedRequests: [(index: Int, request: RpcGraphqlLoadRequest<Arguments>)] = []

        for (index, request) in requests.enumerated() {
            if orphanCriteria(request.arguments) {
                orphanedRequests.append((index, request))
                continue
            }
            append(index: index, key: request.key, arguments: request.arguments, to: &fetches)
        }

        for (index, request) in orphanedRequests {
            if let bucketIndex = fetches.firstIndex(where: {
                request.arguments.stableKey(omitting: orphanHashOmit) == $0.arguments.stableKey(omitting: orphanHashOmit)
            }) {
                fetches[bucketIndex].callbacksByKey[request.key, default: []].append(index)
                continue
            }
            append(index: index, key: request.key, arguments: orphanDefaults(request.arguments), to: &fetches)
        }

        return fetches
    }

    static func coalesceDataSlices<Arguments: RpcGraphqlDataSliceLoadArguments>(
        _ requests: [RpcGraphqlLoadRequest<Arguments>],
        maxDataSliceByteRange: Int
    ) -> [RpcGraphqlCoalescedDataSliceFetch<Arguments>] {
        var fetches: [RpcGraphqlCoalescedDataSliceFetch<Arguments>] = []
        var orphanedRequests: [(index: Int, request: RpcGraphqlLoadRequest<Arguments>)] = []

        for (index, request) in requests.enumerated() {
            var arguments = request.arguments
            if arguments.encodingKey == nil {
                orphanedRequests.append((index, request))
                continue
            }

            if arguments.encodingKey != "base64+zstd", let dataSlice = arguments.dataSlice {
                var merged = false
                for fetchIndex in fetches.indices {
                    let fetchArguments = fetches[fetchIndex].arguments
                    if arguments.stableKey(omitting: ["dataSlice"]) != fetchArguments.stableKey(omitting: ["dataSlice"]) {
                        continue
                    }

                    if let groupedSlice = fetchArguments.dataSlice {
                        if let updatedSlice = mergedDataSlice(dataSlice, groupedSlice, maxDataSliceByteRange: maxDataSliceByteRange) {
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

            arguments = request.arguments
            appendDataSlice(
                index: index,
                key: request.key,
                arguments: arguments,
                dataSlice: arguments.dataSlice,
                to: &fetches
            )
        }

        for (index, request) in orphanedRequests {
            if let fetchIndex = fetches.firstIndex(where: {
                request.arguments.stableKey(omitting: ["encoding", "dataSlice"])
                    == $0.arguments.stableKey(omitting: ["encoding", "dataSlice"])
            }) {
                fetches[fetchIndex].callbacksByKey[request.key, default: []].append(
                    RpcGraphqlCoalescedDataSliceCallback(requestIndex: index, dataSlice: nil)
                )
                continue
            }
            let arguments = request.arguments.withDefaultEncoding("base64")
            appendDataSlice(index: index, key: request.key, arguments: arguments, dataSlice: nil, to: &fetches)
        }

        return fetches
    }

    private static func append<Arguments: Sendable>(
        index: Int,
        key: String,
        arguments: Arguments,
        to fetches: inout [RpcGraphqlCoalescedFetch<Arguments>]
    ) {
        let argumentsKey: String
        if let keyedArguments = arguments as? any RpcGraphqlLoadArguments {
            argumentsKey = keyedArguments.stableKey(omitting: [])
        } else {
            argumentsKey = String(index)
        }
        if let existingIndex = fetches.firstIndex(where: { fetch in
            if let keyed = fetch.arguments as? any RpcGraphqlLoadArguments {
                return keyed.stableKey(omitting: []) == argumentsKey
            }
            return false
        }) {
            fetches[existingIndex].callbacksByKey[key, default: []].append(index)
        } else {
            fetches.append(RpcGraphqlCoalescedFetch(arguments: arguments, callbacksByKey: [key: [index]]))
        }
    }

    private static func appendDataSlice<Arguments: Sendable>(
        index: Int,
        key: String,
        arguments: Arguments,
        dataSlice: RpcGraphqlDataSlice?,
        to fetches: inout [RpcGraphqlCoalescedDataSliceFetch<Arguments>]
    ) {
        fetches.append(
            RpcGraphqlCoalescedDataSliceFetch(
                arguments: arguments,
                callbacksByKey: [
                    key: [RpcGraphqlCoalescedDataSliceCallback(requestIndex: index, dataSlice: dataSlice)],
                ]
            )
        )
    }

    private static func mergedDataSlice(
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
}
