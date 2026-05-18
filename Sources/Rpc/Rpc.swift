public import Addresses
import FastStableStringify
public import Foundation
import Promises
public import RpcApi
public import RpcSpec
public import RpcSpecTypes
public import RpcTransformers
import RpcTransportHttp
public import RpcTypes
public import SolanaErrors
import os

public typealias RpcTransportDevnet = RpcTransport
public typealias RpcTransportTestnet = RpcTransport
public typealias RpcTransportMainnet = RpcTransport

public struct DefaultRpcTransportConfig: Sendable {
    public let url: URL
    public let headers: [String: String]

    public init(url: URL, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
    }
}

/// A Solana JSON-RPC client backed by a request planner and transport.
public struct SolanaRpc: Sendable {
    private let api: SolanaRpcApi
    private let transport: RpcTransport

    public init(api: SolanaRpcApi, transport: @escaping RpcTransport) {
        self.api = api
        self.transport = transport
    }

    /// Creates a request for a Solana JSON-RPC method.
    public func request(_ methodName: String, params: [RpcJsonValue]) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.plan(methodName: methodName, params: params), transport: transport)
    }

    public func getAccountInfo(_ address: Address, config: RpcJsonValue? = nil) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getAccountInfo(address, config: config), transport: transport)
    }

    public func getBalance(_ address: Address, config: RpcJsonValue? = nil) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getBalance(address, config: config), transport: transport)
    }

    public func getBlock(_ slot: Slot, config: RpcJsonValue? = nil) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getBlock(slot, config: config), transport: transport)
    }

    public func getBlockCommitment(_ slot: Slot) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getBlockCommitment(slot), transport: transport)
    }

    public func getBlockHeight(config: RpcJsonValue? = nil) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getBlockHeight(config: config), transport: transport)
    }

    public func getBlockProduction(config: RpcJsonValue? = nil) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getBlockProduction(config: config), transport: transport)
    }

    public func getBlockTime(_ blockNumber: Slot) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getBlockTime(blockNumber), transport: transport)
    }

    public func getBlocks(
        _ startSlotInclusive: Slot,
        endSlotInclusive: Slot? = nil,
        config: RpcJsonValue? = nil
    ) throws -> PendingRpcRequest {
        PendingRpcRequest(
            plan: try api.getBlocks(startSlotInclusive, endSlotInclusive: endSlotInclusive, config: config),
            transport: transport
        )
    }

    public func getBlocksWithLimit(_ startSlotInclusive: Slot, limit: Int, config: RpcJsonValue? = nil) throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getBlocksWithLimit(startSlotInclusive, limit: limit, config: config), transport: transport)
    }

    public func getClusterNodes() throws -> PendingRpcRequest {
        PendingRpcRequest(plan: try api.getClusterNodes(), transport: transport)
    }
}

public func createSolanaJsonRpcIntegerOverflowError(methodName: String, keyPath: RpcKeyPath, value: String) -> SolanaError {
    let argumentLabel = argumentLabel(from: keyPath.first)
    let path = pathLabel(from: Array(keyPath.dropFirst()))
    var context: SolanaErrorContext = [
        "argumentLabel": .string(argumentLabel),
        "keyPath": .string(renderKeyPath(keyPath)),
        "methodName": .string(methodName),
        "optionalPathLabel": .string(path.map { " at path `\($0)`" } ?? ""),
        "value": .string(value),
    ]
    if let path {
        context.values["path"] = .string(path)
    }
    return SolanaError(.rpcIntegerOverflow, context: context)
}

public func defaultRpcConfig() -> RequestTransformerConfig {
    RequestTransformerConfig(defaultCommitment: .confirmed) { request, keyPath, value in
        throw createSolanaJsonRpcIntegerOverflowError(methodName: request.methodName, keyPath: keyPath, value: value)
    }
}

public func getSolanaRpcPayloadDeduplicationKey(_ payload: RpcJsonValue) throws -> String? {
    guard isJsonRpcPayload(payload),
          let method = payload.value(for: "method"),
          let params = payload.value(for: "params")
    else {
        return nil
    }
    return fastStableStringify(stableStringifyValue(from: .array([method, params])))
}

public func getRpcTransportWithRequestCoalescing(
    _ transport: @escaping RpcTransport,
    getDeduplicationKey: @escaping @Sendable (RpcJsonValue) throws -> String?
) -> RpcTransport {
    let coalescer = RpcRequestCoalescer()
    return { config in
        guard let deduplicationKey = try getDeduplicationKey(config.payload) else {
            return try await transport(config)
        }
        let consumer = await coalescer.consumer(for: deduplicationKey, config: config, transport: transport)
        return try await consumer.response(callerAbortSignal: config.abortSignal)
    }
}

public func createDefaultRpcTransport(_ config: DefaultRpcTransportConfig) throws -> RpcTransport {
    let headers = defaultRpcTransportHeaders(config.headers)
    let transport = try createHttpTransportForSolanaRpc(url: config.url, headers: headers)
    return getRpcTransportWithRequestCoalescing(transport) { payload in
        try getSolanaRpcPayloadDeduplicationKey(payload)
    }
}

func defaultRpcTransportHeaders(_ headers: [String: String]) -> [String: String] {
    var normalized = normalizeHeaders(headers)
    normalized["solana-client"] = "UNKNOWN"
    return normalized
}

/// Creates a Solana RPC client using the default HTTP transport.
public func createSolanaRpc(_ clusterUrl: URL, headers: [String: String] = [:]) throws -> SolanaRpc {
    try createSolanaRpcFromTransport(createDefaultRpcTransport(DefaultRpcTransportConfig(url: clusterUrl, headers: headers)))
}

/// Creates a Solana RPC client using a caller-supplied transport.
public func createSolanaRpcFromTransport(_ transport: @escaping RpcTransport) -> SolanaRpc {
    SolanaRpc(api: createSolanaRpcApi(defaultRpcConfig()), transport: transport)
}

private func argumentLabel(from component: RpcKeyPathComponent?) -> String {
    switch component {
    case let .index(index):
        let position = index + 1
        let lastDigit = position % 10
        let lastTwoDigits = position % 100
        if lastDigit == 1 && lastTwoDigits != 11 {
            return "\(position)st"
        }
        if lastDigit == 2 && lastTwoDigits != 12 {
            return "\(position)nd"
        }
        if lastDigit == 3 && lastTwoDigits != 13 {
            return "\(position)rd"
        }
        return "\(position)th"
    case let .key(key):
        return "`\(key)`"
    case .wildcard:
        return "`*`"
    case nil:
        return ""
    }
}

private func pathLabel(from keyPath: RpcKeyPath) -> String? {
    guard !keyPath.isEmpty else { return nil }
    return keyPath.map { component in
        switch component {
        case let .index(index):
            return "[\(index)]"
        case let .key(key):
            return key
        case .wildcard:
            return "*"
        }
    }.joined(separator: ".")
}

private func renderKeyPath(_ keyPath: RpcKeyPath) -> String {
    keyPath.map { component in
        switch component {
        case let .index(index):
            return String(index)
        case let .key(key):
            return key
        case .wildcard:
            return "*"
        }
    }.joined(separator: ".")
}

private func stableStringifyValue(from value: RpcJsonValue) -> StableStringifyValue {
    switch value {
    case .null:
        return .null
    case let .bool(value):
        return .bool(value)
    case let .string(value):
        return .string(value)
    case let .number(value):
        return value.isFinite ? .number(numberString(value)) : .nonFiniteNumber
    case let .bigint(value):
        return .bigint(value)
    case let .array(values):
        return .array(values.map(stableStringifyValue))
    case let .object(members):
        var out: [String: StableStringifyValue] = [:]
        for member in members {
            out[member.key] = stableStringifyValue(from: member.value)
        }
        return .object(out)
    }
}

private func numberString(_ value: Double) -> String {
    if value == 0 {
        return "0"
    }
    let absolute = abs(value)
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

private actor RpcRequestCoalescer {
    private static let schedulingWindowNanoseconds: UInt64 = 100_000

    private var requestsByDeduplicationKey: [String: CoalescedRequest]?
    private var resetTask: Task<Void, Never>?

    func consumer(
        for deduplicationKey: String,
        config: RpcTransportConfig,
        transport: @escaping RpcTransport
    ) -> CoalescedConsumer {
        if requestsByDeduplicationKey == nil {
            requestsByDeduplicationKey = [:]
            let task = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.schedulingWindowNanoseconds)
                await self?.reset()
            }
            resetTask = task
        }
        let request: CoalescedRequest
        if let existing = requestsByDeduplicationKey?[deduplicationKey] {
            request = existing
        } else {
            request = CoalescedRequest(config: config, transport: transport)
            requestsByDeduplicationKey?[deduplicationKey] = request
        }
        request.addConsumer()
        return CoalescedConsumer(request: request, resetTask: resetTask)
    }

    private func reset() {
        requestsByDeduplicationKey = nil
        resetTask = nil
    }
}

private struct CoalescedConsumer: Sendable {
    let request: CoalescedRequest
    let resetTask: Task<Void, Never>?

    func response(callerAbortSignal: AbortSignal?) async throws -> RpcJsonValue {
        guard let callerAbortSignal else {
            return try await waitForCoalescingWindowToClose {
                try await request.task.value
            }
        }
        if let reason = callerAbortSignal.abortReason() {
            request.consumerAborted()
            throw reason
        }
        return try await waitForCoalescingWindowToClose {
            try await withThrowingTaskGroup(of: RpcJsonValue.self) { group in
                group.addTask { [request] in
                    try await request.task.value
                }
                group.addTask { [request, callerAbortSignal] in
                    let reason = await callerAbortSignal.waitUntilAborted()
                    try Task.checkCancellation()
                    request.consumerAborted()
                    throw reason
                }
                do {
                    guard let value = try await group.next() else {
                        throw CancellationError()
                    }
                    group.cancelAll()
                    return value
                } catch {
                    group.cancelAll()
                    throw error
                }
            }
        }
    }

    private func waitForCoalescingWindowToClose(
        _ operation: () async throws -> RpcJsonValue
    ) async throws -> RpcJsonValue {
        do {
            let value = try await operation()
            await resetTask?.value
            return value
        } catch {
            await resetTask?.value
            throw error
        }
    }
}

private final class CoalescedRequest: Sendable {
    private struct State: Sendable {
        var consumers = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let underlyingAbortSignal = AbortSignal()
    let task: Task<RpcJsonValue, any Error>

    init(config: RpcTransportConfig, transport: @escaping RpcTransport) {
        let payload = config.payload
        let abortSignal = underlyingAbortSignal
        task = Task {
            try await transport(RpcTransportConfig(payload: payload, abortSignal: abortSignal))
        }
    }

    func addConsumer() {
        state.withLock { state in
            state.consumers += 1
        }
    }

    func consumerAborted() {
        state.withLock { state in
            state.consumers -= 1
        }
        Task { [weak self] in
            await Task.yield()
            self?.abortTransportIfUnused()
        }
    }

    private func abortTransportIfUnused() {
        let shouldAbort = state.withLock { state in
            state.consumers == 0
        }
        if shouldAbort {
            underlyingAbortSignal.abort(reason: CoalescedTransportAbort())
        }
    }
}

private struct CoalescedTransportAbort: Error, Sendable {}
