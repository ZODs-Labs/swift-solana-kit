import Foundation
import FastStableStringify
public import Promises
import RpcSpecTypes
import RpcSubscriptionsApi
import RpcSubscriptionsChannelWebsocket
public import RpcSubscriptionsSpec
import RpcTransformers
public import RpcTypes
import SolanaErrors
import Subscribable
import os

public struct DefaultRpcSubscriptionsChannelConfig: Sendable {
    public let intervalMs: Int
    public let maxSubscriptionsPerChannel: Int
    public let minChannels: Int
    public let sendBufferHighWatermark: Int
    public let url: ClusterUrl

    public init(
        url: ClusterUrl,
        intervalMs: Int = 5_000,
        maxSubscriptionsPerChannel: Int = 100,
        minChannels: Int = 1,
        sendBufferHighWatermark: Int = 131_072
    ) {
        self.intervalMs = intervalMs
        self.maxSubscriptionsPerChannel = maxSubscriptionsPerChannel
        self.minChannels = minChannels
        self.url = url
        self.sendBufferHighWatermark = sendBufferHighWatermark
    }
}

public struct ChannelPoolingConfig: Sendable {
    public let maxSubscriptionsPerChannel: Int
    public let minChannels: Int

    public init(maxSubscriptionsPerChannel: Int, minChannels: Int) {
        self.maxSubscriptionsPerChannel = maxSubscriptionsPerChannel
        self.minChannels = minChannels
    }
}

public let defaultRpcSubscriptionsCommitment: Commitment = .confirmed

public func getRpcSubscriptionsChannelWithAutoping(
    abortSignal: AbortSignal,
    channel: RpcSubscriptionsChannel,
    intervalMs: Int
) -> RpcSubscriptionsChannel {
    let runtime = RpcSubscriptionsAutopingRuntime(
        abortSignal: abortSignal,
        channel: channel,
        intervalMs: intervalMs
    )
    runtime.start()
    return RpcSubscriptionsChannel(dataPublisher: channel) { payload in
        runtime.restartPingTimer()
        try await channel.send(payload)
    }
}

public func getChannelPoolingChannelCreator(
    _ createChannel: @escaping RpcSubscriptionsChannelCreator,
    config: ChannelPoolingConfig
) -> RpcSubscriptionsChannelCreator {
    let state = RpcSubscriptionsChannelPoolState(config: config)
    return { abortSignal in
        let claim = state.acquire(createChannel: createChannel, abortSignal: abortSignal)
        let unsubscribeAbortHandler = abortSignal.addAbortHandler { _ in
            state.release(entryID: claim.id)
        }
        do {
            let channel = try await claim.channelTask.value
            state.attachErrorListenerIfNeeded(entryID: claim.id, channel: channel)
            return channel
        } catch {
            unsubscribeAbortHandler()
            state.destroy(entryID: claim.id)
            throw error
        }
    }
}

public func getRpcSubscriptionsChannelWithJSONSerialization(_ channel: RpcSubscriptionsChannel) -> RpcSubscriptionsChannel {
    let inbound = transformChannelInboundMessages(channel) { payload in
        guard let string = payload as? String else {
            return payload
        }
        return try parseJson(string)
    }
    return transformChannelOutboundMessages(inbound) { payload in
        try stringifyRpcSubscriptionsPayload(payload, usingBigInts: false)
    }
}

public func getRpcSubscriptionsChannelWithBigIntJSONSerialization(_ channel: RpcSubscriptionsChannel) -> RpcSubscriptionsChannel {
    let inbound = transformChannelInboundMessages(channel) { payload in
        guard let string = payload as? String else {
            return payload
        }
        return try parseJsonWithBigInts(string)
    }
    return transformChannelOutboundMessages(inbound) { payload in
        try stringifyRpcSubscriptionsPayload(payload, usingBigInts: true)
    }
}

public func getRpcSubscriptionsTransportWithSubscriptionCoalescing(
    _ transport: @escaping RpcSubscriptionsTransport
) -> RpcSubscriptionsTransport {
    let state = RpcSubscriptionsCoalescingState(transport: transport)
    return { config in
        try await state.execute(config)
    }
}

public func createRpcSubscriptionsTransportFromChannelCreator(
    _ createChannel: @escaping RpcSubscriptionsChannelCreator
) -> RpcSubscriptionsTransport {
    { config in
        let channel = try await createChannel(config.signal)
        return try await config.execute(RpcSubscriptionsPlanExecutionConfig(channel: channel, signal: config.signal))
    }
}

public func createDefaultRpcSubscriptionsChannelCreator(
    _ config: DefaultRpcSubscriptionsChannelConfig
) throws -> RpcSubscriptionsChannelCreator {
    try createDefaultRpcSubscriptionsChannelCreator(config, jsonSerializer: getRpcSubscriptionsChannelWithJSONSerialization)
}

public func createDefaultSolanaRpcSubscriptionsChannelCreator(
    _ config: DefaultRpcSubscriptionsChannelConfig
) throws -> RpcSubscriptionsChannelCreator {
    try createDefaultRpcSubscriptionsChannelCreator(config, jsonSerializer: getRpcSubscriptionsChannelWithBigIntJSONSerialization)
}

private func createDefaultRpcSubscriptionsChannelCreator(
    _ config: DefaultRpcSubscriptionsChannelConfig,
    jsonSerializer: @escaping @Sendable (RpcSubscriptionsChannel) -> RpcSubscriptionsChannel
) throws -> RpcSubscriptionsChannelCreator {
    guard let url = URL(string: config.url),
          url.scheme == "ws" || url.scheme == "wss" else {
        throw SolanaError(.rpcSubscriptionsChannelFailedToConnect)
    }
    let createChannel: RpcSubscriptionsChannelCreator = { abortSignal in
        let rawChannel = try await createWebSocketChannel(
            WebSocketChannelConfig(
                sendBufferHighWatermark: config.sendBufferHighWatermark,
                signal: abortSignal,
                url: url
            )
        )
        let serialized = jsonSerializer(rawChannel)
        return getRpcSubscriptionsChannelWithAutoping(
            abortSignal: abortSignal,
            channel: serialized,
            intervalMs: config.intervalMs
        )
    }
    return getChannelPoolingChannelCreator(
        createChannel,
        config: ChannelPoolingConfig(
            maxSubscriptionsPerChannel: config.maxSubscriptionsPerChannel,
            minChannels: config.minChannels
        )
    )
}

private final class RpcSubscriptionsAutopingRuntime: Sendable {
    private struct State: Sendable {
        var abortTask: Task<Void, Never>?
        var errorUnsubscribe: DataPublisherUnsubscribe?
        var messageUnsubscribe: DataPublisherUnsubscribe?
        var stopped = false
        var timerTask: Task<Void, Never>?
    }

    private let abortSignal: AbortSignal
    private let channel: RpcSubscriptionsChannel
    private let intervalNanoseconds: UInt64
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(abortSignal: AbortSignal, channel: RpcSubscriptionsChannel, intervalMs: Int) {
        self.abortSignal = abortSignal
        self.channel = channel
        intervalNanoseconds = UInt64(max(0, intervalMs)) * 1_000_000
    }

    func start() {
        let errorUnsubscribe = try? channel.on("error", subscriber: { [weak self] _ in
            self?.stop()
        })
        let messageUnsubscribe = try? channel.on("message", subscriber: { [weak self] _ in
            self?.restartPingTimer()
        })
        let abortTask = Task { [weak self, abortSignal] in
            _ = await abortSignal.waitUntilAborted()
            self?.stop()
        }
        state.withLock { state in
            state.abortTask = abortTask
            state.errorUnsubscribe = errorUnsubscribe
            state.messageUnsubscribe = messageUnsubscribe
        }
        restartPingTimer()
    }

    func restartPingTimer() {
        let timer = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
                await sendPingFromTimer()
            } catch {
                return
            }
        }
        let oldTimer = state.withLock { state -> Task<Void, Never>? in
            guard !state.stopped else {
                timer.cancel()
                return nil
            }
            let oldTimer = state.timerTask
            state.timerTask = timer
            return oldTimer
        }
        oldTimer?.cancel()
    }

    private func sendPingFromTimer() async {
        guard !state.withLock(\.stopped) else {
            return
        }
        do {
            try await channel.send(
                RpcJsonValue.object([
                    RpcJsonObjectMember("jsonrpc", .string("2.0")),
                    RpcJsonObjectMember("method", .string("ping")),
                ])
            )
            restartPingTimer()
        } catch let error as any SolanaErrorCoded {
            if error.code == SolanaErrorCode.rpcSubscriptionsChannelConnectionClosed.rawValue {
                stop()
            } else {
                restartPingTimer()
            }
        } catch {
            restartPingTimer()
        }
    }

    private func stop() {
        let cleanup = state.withLock { state -> (Task<Void, Never>?, DataPublisherUnsubscribe?, DataPublisherUnsubscribe?, Task<Void, Never>?)? in
            guard !state.stopped else {
                return nil
            }
            state.stopped = true
            let cleanup = (state.abortTask, state.errorUnsubscribe, state.messageUnsubscribe, state.timerTask)
            state.abortTask = nil
            state.errorUnsubscribe = nil
            state.messageUnsubscribe = nil
            state.timerTask = nil
            return cleanup
        }
        guard let cleanup else {
            return
        }
        cleanup.0?.cancel()
        cleanup.1?()
        cleanup.2?()
        cleanup.3?.cancel()
    }
}

private struct RpcSubscriptionsChannelPoolClaim: Sendable {
    let id: UUID
    let channelTask: Task<RpcSubscriptionsChannel, any Error>
}

private final class RpcSubscriptionsChannelPoolState: Sendable {
    private struct Entry: Sendable {
        let abortSignal: AbortSignal
        let channelTask: Task<RpcSubscriptionsChannel, any Error>
        var errorListenerAttached = false
        let id: UUID
        var subscriptionCount: Int
    }

    private struct State: Sendable {
        var entries: [Entry] = []
        var freeChannelIndex = -1
    }

    private let config: ChannelPoolingConfig
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(config: ChannelPoolingConfig) {
        self.config = config
    }

    func acquire(
        createChannel: @escaping RpcSubscriptionsChannelCreator,
        abortSignal: AbortSignal
    ) -> RpcSubscriptionsChannelPoolClaim {
        state.withLock { state in
            let index: Int
            if state.freeChannelIndex == -1 {
                let internalSignal = AbortSignal()
                let task = Task {
                    try await createChannel(internalSignal)
                }
                let entry = Entry(
                    abortSignal: internalSignal,
                    channelTask: task,
                    id: UUID(),
                    subscriptionCount: 0
                )
                state.entries.append(entry)
                index = state.entries.count - 1
            } else {
                index = state.freeChannelIndex
            }
            state.entries[index].subscriptionCount += 1
            let entry = state.entries[index]
            recomputeFreeChannelIndex(&state)
            return RpcSubscriptionsChannelPoolClaim(id: entry.id, channelTask: entry.channelTask)
        }
    }

    func attachErrorListenerIfNeeded(entryID: UUID, channel: RpcSubscriptionsChannel) {
        let signal = state.withLock { state -> AbortSignal? in
            guard let index = state.entries.firstIndex(where: { $0.id == entryID }),
                  !state.entries[index].errorListenerAttached else {
                return nil
            }
            state.entries[index].errorListenerAttached = true
            return state.entries[index].abortSignal
        }
        guard let signal else {
            return
        }
        _ = try? channel.on(
            "error",
            subscriber: { [weak self] _ in
                self?.destroy(entryID: entryID)
            },
            options: DataPublisherSubscriptionOptions(signal: signal)
        )
    }

    func release(entryID: UUID) {
        let signalToAbort = state.withLock { state -> AbortSignal? in
            guard let index = state.entries.firstIndex(where: { $0.id == entryID }) else {
                return nil
            }
            state.entries[index].subscriptionCount -= 1
            if state.entries[index].subscriptionCount <= 0 {
                let signal = state.entries[index].abortSignal
                state.entries.remove(at: index)
                recomputeFreeChannelIndex(&state)
                return signal
            }
            if state.freeChannelIndex != -1 {
                state.freeChannelIndex -= 1
            }
            recomputeFreeChannelIndex(&state)
            return nil
        }
        signalToAbort?.abort()
    }

    func destroy(entryID: UUID) {
        let signalToAbort = state.withLock { state -> AbortSignal? in
            guard let index = state.entries.firstIndex(where: { $0.id == entryID }) else {
                return nil
            }
            let signal = state.entries[index].abortSignal
            state.entries.remove(at: index)
            recomputeFreeChannelIndex(&state)
            return signal
        }
        signalToAbort?.abort()
    }

    private func recomputeFreeChannelIndex(_ state: inout State) {
        guard state.entries.count >= config.minChannels else {
            state.freeChannelIndex = -1
            return
        }
        var mostFree: (poolIndex: Int, subscriptionCount: Int)?
        for offset in 0 ..< state.entries.count {
            let nextIndex = positiveModulo(state.freeChannelIndex + offset + 2, state.entries.count)
            let entry = state.entries[nextIndex]
            if entry.subscriptionCount < config.maxSubscriptionsPerChannel,
               mostFree == nil || mostFree!.subscriptionCount >= entry.subscriptionCount {
                mostFree = (nextIndex, entry.subscriptionCount)
            }
        }
        state.freeChannelIndex = mostFree?.poolIndex ?? -1
    }
}

private final class RpcSubscriptionsCoalescingState: Sendable {
    private struct Entry: Sendable {
        let abortSignal: AbortSignal
        var errorListenerAttached = false
        let id: UUID
        var numSubscribers: Int
        let publisherTask: Task<any DataPublisher, any Error>
    }

    private struct State: Sendable {
        var entries: [String: Entry] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let transport: RpcSubscriptionsTransport

    init(transport: @escaping RpcSubscriptionsTransport) {
        self.transport = transport
    }

    func execute(_ config: RpcSubscriptionsTransportConfig) async throws -> any DataPublisher {
        let key = coalescingKey(for: config.request)
        let claim = state.withLock { state -> (id: UUID, signal: AbortSignal, task: Task<any DataPublisher, any Error>) in
            if var entry = state.entries[key] {
                entry.numSubscribers += 1
                state.entries[key] = entry
                return (entry.id, entry.abortSignal, entry.publisherTask)
            }
            let signal = AbortSignal()
            let task = Task { [transport] in
                try await transport(
                    RpcSubscriptionsTransportConfig(
                        request: config.request,
                        signal: signal,
                        execute: config.execute
                    )
                )
            }
            let entry = Entry(
                abortSignal: signal,
                id: UUID(),
                numSubscribers: 1,
                publisherTask: task
            )
            state.entries[key] = entry
            return (entry.id, signal, task)
        }
        _ = config.signal.addAbortHandler { [weak self] _ in
            self?.release(key: key, entryID: claim.id)
        }
        let publisher = try await claim.task.value
        attachErrorListenerIfNeeded(key: key, entryID: claim.id, signal: claim.signal, publisher: publisher)
        return publisher
    }

    private func attachErrorListenerIfNeeded(
        key: String,
        entryID: UUID,
        signal: AbortSignal,
        publisher: any DataPublisher
    ) {
        let shouldAttach = state.withLock { state -> Bool in
            guard var entry = state.entries[key],
                  entry.id == entryID,
                  !entry.errorListenerAttached else {
                return false
            }
            entry.errorListenerAttached = true
            state.entries[key] = entry
            return true
        }
        guard shouldAttach else {
            return
        }
        _ = try? publisher.on(
            "error",
            subscriber: { [weak self] _ in
                self?.removeErroredEntry(key: key, entryID: entryID)
            },
            options: DataPublisherSubscriptionOptions(signal: signal)
        )
    }

    private func release(key: String, entryID: UUID) {
        let shouldScheduleRemoval = state.withLock { state -> Bool in
            guard var entry = state.entries[key], entry.id == entryID else {
                return false
            }
            entry.numSubscribers -= 1
            state.entries[key] = entry
            return entry.numSubscribers == 0
        }
        guard shouldScheduleRemoval else {
            return
        }
        Task { [weak self] in
            await Task.yield()
            self?.removeIfStillUnsubscribed(key: key, entryID: entryID)
        }
    }

    private func removeIfStillUnsubscribed(key: String, entryID: UUID) {
        let signalToAbort = state.withLock { state -> AbortSignal? in
            guard let entry = state.entries[key],
                  entry.id == entryID,
                  entry.numSubscribers == 0 else {
                return nil
            }
            state.entries.removeValue(forKey: key)
            return entry.abortSignal
        }
        signalToAbort?.abort()
    }

    private func removeErroredEntry(key: String, entryID: UUID) {
        let signalToAbort = state.withLock { state -> AbortSignal? in
            guard let entry = state.entries[key], entry.id == entryID else {
                return nil
            }
            state.entries.removeValue(forKey: key)
            return entry.abortSignal
        }
        signalToAbort?.abort()
    }
}

private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
    let remainder = value % modulus
    return remainder >= 0 ? remainder : remainder + modulus
}

private func coalescingKey(for request: RpcRequest) -> String {
    fastStableStringify(.array([.string(request.methodName), stableStringifyValue(from: request.params)]))
        ?? "\(request.methodName):\(request.params)"
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
        return value.isFinite ? .number(subscriptionNumberString(value)) : .nonFiniteNumber
    case let .bigint(value):
        return .bigint(value)
    case let .array(values):
        return .array(values.map(stableStringifyValue))
    case let .object(members):
        var object: [String: StableStringifyValue] = [:]
        for member in members {
            object[member.key] = stableStringifyValue(from: member.value)
        }
        return .object(object)
    }
}

func subscriptionNumberString(_ value: Double) -> String {
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

public func createDefaultRpcSubscriptionsTransport(
    createChannel: @escaping RpcSubscriptionsChannelCreator
) -> RpcSubscriptionsTransport {
    getRpcSubscriptionsTransportWithSubscriptionCoalescing(
        createRpcSubscriptionsTransportFromChannelCreator(createChannel)
    )
}

public func createSolanaRpcSubscriptionsFromTransport(_ transport: @escaping RpcSubscriptionsTransport) -> RpcSubscriptions {
    createSubscriptionRpc(
        RpcSubscriptionsConfig(
            api: createSolanaRpcSubscriptionsApi(defaultRpcSubscriptionsRequestTransformerConfig()),
            transport: transport
        )
    )
}

public func createSolanaRpcSubscriptions(_ clusterUrl: ClusterUrl, config: DefaultRpcSubscriptionsChannelConfig?) throws -> RpcSubscriptions {
    let channelConfig = defaultRpcSubscriptionsChannelConfig(clusterUrl: clusterUrl, config: config)
    let transport = createDefaultRpcSubscriptionsTransport(
        createChannel: try createDefaultSolanaRpcSubscriptionsChannelCreator(channelConfig)
    )
    return createSolanaRpcSubscriptionsFromTransport(transport)
}

func defaultRpcSubscriptionsChannelConfig(
    clusterUrl: ClusterUrl,
    config: DefaultRpcSubscriptionsChannelConfig?
) -> DefaultRpcSubscriptionsChannelConfig {
    guard let config else {
        return DefaultRpcSubscriptionsChannelConfig(url: clusterUrl)
    }
    return DefaultRpcSubscriptionsChannelConfig(
        url: clusterUrl,
        intervalMs: config.intervalMs,
        maxSubscriptionsPerChannel: config.maxSubscriptionsPerChannel,
        minChannels: config.minChannels,
        sendBufferHighWatermark: config.sendBufferHighWatermark
    )
}

public func createSolanaRpcSubscriptions(_ clusterUrl: ClusterUrl) throws -> RpcSubscriptions {
    try createSolanaRpcSubscriptions(clusterUrl, config: nil)
}

public func createSolanaRpcSubscriptions_UNSTABLE(_ clusterUrl: ClusterUrl, config: DefaultRpcSubscriptionsChannelConfig?) throws -> RpcSubscriptions {
    try createSolanaRpcSubscriptions(clusterUrl, config: config)
}

public func createSolanaRpcSubscriptions_UNSTABLE(_ clusterUrl: ClusterUrl) throws -> RpcSubscriptions {
    try createSolanaRpcSubscriptions_UNSTABLE(clusterUrl, config: nil)
}

private func defaultRpcSubscriptionsRequestTransformerConfig() -> RequestTransformerConfig {
    RequestTransformerConfig(
        defaultCommitment: defaultRpcSubscriptionsCommitment,
        onIntegerOverflow: { request, keyPath, value in
            throw rpcSubscriptionsIntegerOverflowError(methodName: request.methodName, keyPath: keyPath, value: value)
        }
    )
}

private func stringifyRpcSubscriptionsPayload(_ payload: DataPublisherPayload, usingBigInts: Bool) throws -> DataPublisherPayload {
    let value: RpcJsonValue
    switch payload {
    case let message as RpcMessage:
        value = message.jsonValue
    case let jsonValue as RpcJsonValue:
        value = jsonValue
    case let string as String:
        value = .string(string)
    case let bool as Bool:
        value = .bool(bool)
    case let int as Int:
        value = .number(Double(int))
    case let uint as UInt:
        value = .number(Double(uint))
    case let double as Double:
        value = .number(double)
    case .none:
        value = .null
    default:
        value = .string(String(describing: payload))
    }
    return try usingBigInts ? stringifyJsonWithBigInts(value) : stringifyJson(value)
}

private func rpcSubscriptionsIntegerOverflowError(methodName: String, keyPath: RpcKeyPath, value: String) -> SolanaError {
    var context: SolanaErrorContext = [
        "argumentLabel": .string("params"),
        "methodName": .string(methodName),
        "optionalPathLabel": .string(""),
        "value": .string(value),
    ]
    if !keyPath.isEmpty {
        context.values["optionalPathLabel"] = .string(" at key path \(keyPath.map(pathComponentDescription).joined(separator: "."))")
    }
    return SolanaError(.rpcIntegerOverflow, context: context)
}

private func pathComponentDescription(_ component: RpcKeyPathComponent) -> String {
    switch component {
    case let .key(value):
        return value
    case let .index(value):
        return String(value)
    case .wildcard:
        return "*"
    }
}
