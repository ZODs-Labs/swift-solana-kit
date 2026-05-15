public import Foundation
public import Kit

public struct AccountActivityService: Sendable {
    public typealias FetchBalance = @Sendable (Address, URL) async throws -> RpcJsonValue
    public typealias FetchSignatures = @Sendable (Address, Int, URL) async throws -> RpcJsonValue

    private let fetchBalance: FetchBalance
    private let fetchSignatures: FetchSignatures

    public init(
        fetchBalance: @escaping FetchBalance = AccountActivityService.liveFetchBalance,
        fetchSignatures: @escaping FetchSignatures = AccountActivityService.liveFetchSignatures
    ) {
        self.fetchBalance = fetchBalance
        self.fetchSignatures = fetchSignatures
    }

    public func lookup(addressText: String, endpoint: ActivityEndpoint = .mainnetBeta, limit: Int = 10) async throws -> AccountActivitySnapshot {
        guard (1...25).contains(limit) else {
            throw ActivityLookupError.invalidLimit(limit)
        }

        let accountAddress: Address
        do {
            accountAddress = try address(addressText.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            throw ActivityLookupError.invalidAddress(addressText)
        }

        async let balanceResponse = fetchBalance(accountAddress, endpoint.url)
        async let signaturesResponse = fetchSignatures(accountAddress, limit, endpoint.url)

        let parsedBalance = try parseBalanceResponse(await balanceResponse)
        let parsedSignatures = try parseSignaturesResponse(await signaturesResponse)

        return AccountActivitySnapshot(
            address: accountAddress,
            endpoint: endpoint,
            lamports: parsedBalance.lamports,
            slot: parsedBalance.slot,
            solText: solDisplayString(from: parsedBalance.lamports),
            signatures: parsedSignatures
        )
    }

    public static func liveFetchBalance(address: Address, endpoint: URL) async throws -> RpcJsonValue {
        let rpc = try createSolanaRpc(endpoint)
        return try await rpc.getBalance(address).send()
    }

    public static func liveFetchSignatures(address: Address, limit: Int, endpoint: URL) async throws -> RpcJsonValue {
        let rpc = try createSolanaRpc(endpoint)
        let config: RpcJsonValue = .object([
            RpcJsonObjectMember("commitment", .string("confirmed")),
            RpcJsonObjectMember("limit", .bigint(String(limit))),
        ])
        return try await rpc.request(
            "getSignaturesForAddress",
            params: [.string(address.rawValue), config]
        ).send()
    }

    private func parseBalanceResponse(_ response: RpcJsonValue) throws -> (lamports: Lamports, slot: Slot) {
        (
            lamports: try unsignedInteger(response.value(for: "value"), field: "value"),
            slot: try unsignedInteger(response.value(for: "context")?.value(for: "slot"), field: "context.slot")
        )
    }

    private func parseSignaturesResponse(_ response: RpcJsonValue) throws -> [ActivitySignatureSummary] {
        guard case let .array(items) = response else {
            throw ActivityLookupError.malformedResponse("getSignaturesForAddress result is not an array")
        }

        return try items.map { item in
            guard case let .object(members) = item else {
                throw ActivityLookupError.malformedResponse("signature item is not an object")
            }
            let object = RpcJsonValue.object(members)
            guard case let .string(signature)? = object.value(for: "signature") else {
                throw ActivityLookupError.malformedResponse("signature is missing")
            }
            let slot = try unsignedInteger(object.value(for: "slot"), field: "slot")
            let confirmationStatus = optionalString(object.value(for: "confirmationStatus"))
            let memo = optionalString(object.value(for: "memo"))
            let blockTime = try optionalUnsignedInteger(object.value(for: "blockTime"), field: "blockTime")
            let isSuccessful = isNullOrMissing(object.value(for: "err"))

            return ActivitySignatureSummary(
                signature: signature,
                slot: slot,
                confirmationStatus: confirmationStatus,
                blockTime: blockTime,
                memo: memo,
                isSuccessful: isSuccessful
            )
        }
    }

    private func unsignedInteger(_ value: RpcJsonValue?, field: String) throws -> UInt64 {
        switch value {
        case let .bigint(raw)?, let .string(raw)?:
            guard let parsed = UInt64(raw) else {
                throw ActivityLookupError.malformedResponse("\(field) is outside UInt64 range")
            }
            return parsed
        case let .number(number)?:
            guard number.isFinite,
                  number.rounded(.towardZero) == number,
                  let parsed = UInt64(exactly: number)
            else {
                throw ActivityLookupError.malformedResponse("\(field) is not an exact unsigned integer")
            }
            return parsed
        default:
            throw ActivityLookupError.malformedResponse("\(field) is missing")
        }
    }

    private func optionalUnsignedInteger(_ value: RpcJsonValue?, field: String) throws -> UInt64? {
        guard let value, value != .null else {
            return nil
        }
        return try unsignedInteger(value, field: field)
    }

    private func optionalString(_ value: RpcJsonValue?) -> String? {
        guard case let .string(raw)? = value else {
            return nil
        }
        return raw
    }

    private func isNullOrMissing(_ value: RpcJsonValue?) -> Bool {
        value == nil || value == .null
    }
}
