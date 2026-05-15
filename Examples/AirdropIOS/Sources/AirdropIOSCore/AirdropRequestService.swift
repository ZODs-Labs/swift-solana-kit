public import Foundation
public import Kit

public struct AirdropRequestService: Sendable {
    public typealias RequestAirdrop = @Sendable (Address, Lamports, URL) async throws -> RpcJsonValue
    public typealias FetchBalance = @Sendable (Address, URL) async throws -> RpcJsonValue

    private let requestAirdrop: RequestAirdrop
    private let fetchBalance: FetchBalance
    private let maximumLamports: Lamports

    public init(
        maximumLamports: Lamports = 2_000_000_000,
        requestAirdrop: @escaping RequestAirdrop = AirdropRequestService.liveRequestAirdrop,
        fetchBalance: @escaping FetchBalance = AirdropRequestService.liveFetchBalance
    ) {
        self.maximumLamports = maximumLamports
        self.requestAirdrop = requestAirdrop
        self.fetchBalance = fetchBalance
    }

    public func request(addressText: String, solAmountText: String, endpoint: AirdropEndpoint = .devnet) async throws -> AirdropRequestResult {
        let recipient: Address
        do {
            recipient = try address(addressText.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            throw AirdropRequestError.invalidAddress(addressText)
        }

        let lamports = try lamportsFromSolText(solAmountText)
        guard lamports > 0 else {
            throw AirdropRequestError.invalidAmount(solAmountText)
        }
        guard lamports <= maximumLamports else {
            throw AirdropRequestError.amountExceedsLimit(requested: lamports, limit: maximumLamports)
        }

        let signatureValue = try await requestAirdrop(recipient, lamports, endpoint.url)
        guard case let .string(signatureString) = signatureValue else {
            throw AirdropRequestError.malformedResponse("requestAirdrop result is not a signature string")
        }

        let balance = try? parseBalanceResponse(try await fetchBalance(recipient, endpoint.url))
        return AirdropRequestResult(
            address: recipient,
            endpoint: endpoint,
            requestedLamports: lamports,
            requestedSolText: solDisplayString(from: lamports),
            signature: Signature(rawValue: signatureString),
            balanceAfterLamports: balance?.lamports,
            balanceSlot: balance?.slot
        )
    }

    public func lamportsFromSolText(_ value: String) throws -> Lamports {
        do {
            return try solToLamports(sol(value.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch {
            throw AirdropRequestError.invalidAmount(value)
        }
    }

    public static func liveRequestAirdrop(address: Address, lamports: Lamports, endpoint: URL) async throws -> RpcJsonValue {
        let rpc = try createSolanaRpc(endpoint)
        let config: RpcJsonValue = .object([RpcJsonObjectMember("commitment", .string("confirmed"))])
        return try await rpc.request(
            "requestAirdrop",
            params: [.string(address.rawValue), .bigint(String(lamports)), config]
        ).send()
    }

    public static func liveFetchBalance(address: Address, endpoint: URL) async throws -> RpcJsonValue {
        let rpc = try createSolanaRpc(endpoint)
        return try await rpc.getBalance(address).send()
    }

    private func parseBalanceResponse(_ response: RpcJsonValue) throws -> (lamports: Lamports, slot: Slot) {
        (
            lamports: try unsignedInteger(response.value(for: "value"), field: "value"),
            slot: try unsignedInteger(response.value(for: "context")?.value(for: "slot"), field: "context.slot")
        )
    }

    private func unsignedInteger(_ value: RpcJsonValue?, field: String) throws -> UInt64 {
        switch value {
        case let .bigint(raw)?, let .string(raw)?:
            guard let parsed = UInt64(raw) else {
                throw AirdropRequestError.malformedResponse("\(field) is outside UInt64 range")
            }
            return parsed
        case let .number(number)?:
            guard number.isFinite,
                  number.rounded(.towardZero) == number,
                  let parsed = UInt64(exactly: number)
            else {
                throw AirdropRequestError.malformedResponse("\(field) is not an exact unsigned integer")
            }
            return parsed
        default:
            throw AirdropRequestError.malformedResponse("\(field) is missing")
        }
    }
}
