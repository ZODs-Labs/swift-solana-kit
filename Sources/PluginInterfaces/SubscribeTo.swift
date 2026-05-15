public typealias SubscribeToFn = @Sendable (@escaping @Sendable () -> Void) -> @Sendable () -> Void

public protocol ClientWithSubscribeToPayer: Sendable {
    var subscribeToPayer: SubscribeToFn { get }
}

public protocol ClientWithSubscribeToIdentity: Sendable {
    var subscribeToIdentity: SubscribeToFn { get }
}
