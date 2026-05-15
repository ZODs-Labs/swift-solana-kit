public import Foundation
public import Kit

public struct BalanceLookupService: Sendable {
    public typealias FetchBalance = @Sendable (Address, URL) async throws -> RpcJsonValue

    private let fetchBalance: FetchBalance

    public init(fetchBalance: @escaping FetchBalance = BalanceLookupService.liveFetchBalance) {
        self.fetchBalance = fetchBalance
    }

    public func lookup(addressText: String, endpoint: SolanaEndpoint) async throws -> BalanceLookupSnapshot {
        let accountAddress: Address
        do {
            accountAddress = try address(addressText.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            throw BalanceLookupError.invalidAddress(addressText)
        }

        let response = try await fetchBalance(accountAddress, endpoint.url)
        let lamports = try Self.unsignedInteger(response.value(for: "value"), field: "value")
        let slot = try Self.unsignedInteger(response.value(for: "context")?.value(for: "slot"), field: "context.slot")

        return BalanceLookupSnapshot(
            address: accountAddress,
            endpoint: endpoint,
            lamports: lamports,
            slot: slot,
            solText: solDisplayString(from: lamports)
        )
    }

    public static func liveFetchBalance(address: Address, endpoint: URL) async throws -> RpcJsonValue {
        let rpc = try createSolanaRpc(endpoint)
        return try await rpc.getBalance(address).send()
    }

    private static func unsignedInteger(_ value: RpcJsonValue?, field: String) throws -> UInt64 {
        switch value {
        case let .bigint(raw)?, let .string(raw)?:
            guard let parsed = UInt64(raw) else {
                throw BalanceLookupError.malformedResponse("\(field) is outside UInt64 range")
            }
            return parsed
        case let .number(number)?:
            guard number.isFinite,
                  number.rounded(.towardZero) == number,
                  let parsed = UInt64(exactly: number)
            else {
                throw BalanceLookupError.malformedResponse("\(field) is not an exact unsigned integer")
            }
            return parsed
        default:
            throw BalanceLookupError.malformedResponse("\(field) is missing")
        }
    }
}
