public import Addresses
public import Keys
public import RpcSpecTypes
public import RpcSubscriptionsSpec
public import RpcTransformers

public typealias SolanaRpcSubscriptionsApi = RpcSubscriptionsApi
public typealias SolanaRpcSubscriptionsApiUnstable = RpcSubscriptionsApi

public enum SolanaRpcSubscriptionNotificationName: String, Sendable, CaseIterable {
    case accountNotifications
    case blockNotifications
    case logsNotifications
    case programNotifications
    case rootNotifications
    case signatureNotifications
    case slotNotifications
    case slotsUpdatesNotifications
    case voteNotifications
}

public func createSolanaRpcSubscriptionsApi(_ config: RequestTransformerConfig) -> RpcSubscriptionsApi
public func createSolanaRpcSubscriptionsApi() -> RpcSubscriptionsApi
public func createSolanaRpcSubscriptionsApi_UNSTABLE(_ config: RequestTransformerConfig) -> RpcSubscriptionsApi
public func createSolanaRpcSubscriptionsApi_UNSTABLE() -> RpcSubscriptionsApi

public func subscribeMethodName(for notificationName: String) -> String
public func unsubscribeMethodName(for notificationName: String) -> String

public extension RpcSubscriptionsApi {
    func accountNotifications(address: Address, config: RpcJsonValue?) throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func blockNotifications(filter: RpcJsonValue, config: RpcJsonValue?) throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func logsNotifications(filter: RpcJsonValue, config: RpcJsonValue?) throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func programNotifications(programId: Address, config: RpcJsonValue?) throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func rootNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func signatureNotifications(signature: Signature, config: RpcJsonValue?) throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func slotNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func slotsUpdatesNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue>
    func voteNotifications() throws -> RpcSubscriptionsPlan<RpcJsonValue>
}
