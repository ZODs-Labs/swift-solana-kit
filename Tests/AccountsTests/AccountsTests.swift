import Accounts
import Addresses
import CodecsCore
import Foundation
import RpcSpec
import RpcSpecTypes
import RpcTypes
import SolanaErrors
import XCTest

final class AccountsTests: XCTestCase {
    func testParseBase64RpcAccount() throws {
        let owner = try address("11111111111111111111111111111111")
        let accountAddress = try address("Sysvar1111111111111111111111111111111111111")
        let rpcAccount = Base64RpcAccount(
            base: AccountInfoBase(executable: false, lamports: 1_000_000_000, owner: owner, space: 6),
            data: Base64EncodedDataResponse("somedata")
        )

        let parsed = try parseBase64RpcAccount(accountAddress, rpcAccount)
        let account = try assertAccountExists(parsed)

        XCTAssertEqual(account.address, accountAddress)
        XCTAssertEqual(account.data, Data([178, 137, 158, 117, 171, 90]))
        XCTAssertEqual(account.lamports, 1_000_000_000)
        XCTAssertEqual(account.programAddress, owner)
        XCTAssertEqual(account.space, 6)
    }

    func testParseJsonRpcAccountPreservesMetadata() throws {
        let owner = try address("11111111111111111111111111111111")
        let accountAddress = try address("Sysvar1111111111111111111111111111111111111")
        let rpcAccount = JsonParsedRpcAccount(
            base: AccountInfoBase(executable: false, lamports: 1_000_000_000, owner: owner, space: 165),
            data: AccountInfoJsonParsedData(
                parsed: AccountInfoParsedData(
                    info: .object(["mint": .string("2222"), "owner": .string("3333")]),
                    type: "token"
                ),
                program: "splToken",
                space: 165
            )
        )

        let parsed = parseJsonRpcAccount(accountAddress, rpcAccount)
        let account = try assertAccountExists(parsed)

        XCTAssertEqual(account.data.info, .object(["mint": .string("2222"), "owner": .string("3333")]))
        XCTAssertEqual(account.data.parsedAccountMeta, ParsedAccountMeta(program: "splToken", type: "token"))
    }

    func testFetchJsonParsedAccountFallsBackToEncodedAccount() async throws {
        let owner = try address("11111111111111111111111111111111")
        let accountAddress = try address("Sysvar1111111111111111111111111111111111111")
        let rpcAccount = Self.base64RpcJsonAccount(owner: owner)
        let rpc = createRpc(api: createJsonRpcApi()) { _ in
            .object([RpcJsonObjectMember("value", rpcAccount)])
        }

        let fetched = try await fetchJsonParsedAccount(rpc: rpc, address: accountAddress)

        guard case let .encoded(account) = fetched else {
            return XCTFail("Expected encoded fallback account")
        }
        XCTAssertEqual(account.address, accountAddress)
        XCTAssertEqual(account.data, Data([178, 137, 158, 117, 171, 90]))
        XCTAssertEqual(account.lamports, 1_000_000_000)
        XCTAssertEqual(account.programAddress, owner)
        XCTAssertEqual(account.space, 6)
    }

    func testFetchJsonParsedAccountsPreservesMixedParsedEncodedAndMissingResults() async throws {
        let owner = try address("11111111111111111111111111111111")
        let parsedAddress = try address("Sysvar1111111111111111111111111111111111111")
        let encodedAddress = try address("SysvarC1ock11111111111111111111111111111111")
        let missingAddress = try address("SysvarRent111111111111111111111111111111111")
        let rpc = createRpc(api: createJsonRpcApi()) { _ in
            .object([
                RpcJsonObjectMember(
                    "value",
                    .array([
                        Self.jsonParsedRpcJsonAccount(owner: owner),
                        Self.base64RpcJsonAccount(owner: owner),
                        .null,
                    ])
                ),
            ])
        }

        let fetched = try await fetchJsonParsedAccounts(
            rpc: rpc,
            addresses: [parsedAddress, encodedAddress, missingAddress]
        )

        XCTAssertEqual(fetched.count, 3)
        guard case let .parsed(parsed) = fetched[0] else {
            return XCTFail("Expected parsed account")
        }
        guard case let .encoded(encoded) = fetched[1] else {
            return XCTFail("Expected encoded account")
        }
        guard case let .missing(address) = fetched[2] else {
            return XCTFail("Expected missing account")
        }
        XCTAssertEqual(parsed.address, parsedAddress)
        XCTAssertEqual(parsed.data.info, .object(["mint": .string("2222"), "owner": .string("3333")]))
        XCTAssertEqual(encoded.address, encodedAddress)
        XCTAssertEqual(encoded.data, Data([178, 137, 158, 117, 171, 90]))
        XCTAssertEqual(address, missingAddress)
    }

    func testAssertAccountDecodedRejectsEncodedFallbackAccount() throws {
        let owner = try address("11111111111111111111111111111111")
        let accountAddress = try address("Sysvar1111111111111111111111111111111111111")
        let encoded = EncodedAccount(
            address: accountAddress,
            data: Data([1, 2, 3]),
            executable: false,
            lamports: 1,
            programAddress: owner,
            space: 3
        )

        XCTAssertThrowsError(try assertAccountDecoded(.encoded(encoded))) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.solanaCode, .accountsExpectedDecodedAccount)
            XCTAssertEqual(solanaError?.context["address"], .string(accountAddress.rawValue))
        }
    }

    func testDecodeAccountReturnsMissingAsIs() throws {
        let accountAddress = try address("Sysvar1111111111111111111111111111111111111")
        let missing: MaybeEncodedAccount = .missing(address: accountAddress)
        let decoder = createDecoder(fixedSize: 0) { _, offset in
            (42, offset)
        }

        let decoded = try decodeAccount(missing, using: decoder)

        XCTAssertEqual(decoded, .missing(address: accountAddress))
    }

    func testAssertAccountsExistReportsMissingAddresses() throws {
        let first = try address("11111111111111111111111111111111")
        let second = try address("Sysvar1111111111111111111111111111111111111")

        XCTAssertThrowsError(try assertAccountsExist([MaybeEncodedAccount.missing(address: first), .missing(address: second)])) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.solanaCode, .accountsOneOrMoreAccountsNotFound)
            XCTAssertEqual(solanaError?.context["addresses"], .stringArray([first.rawValue, second.rawValue]))
        }
    }

    private static func base64RpcJsonAccount(owner: Address) -> RpcJsonValue {
        .object([
            ("data", .array([.string("somedata"), .string("base64")])),
            ("executable", .bool(false)),
            ("lamports", .bigint("1000000000")),
            ("owner", .string(owner.rawValue)),
            ("space", .bigint("6")),
        ])
    }

    private static func jsonParsedRpcJsonAccount(owner: Address) -> RpcJsonValue {
        .object([
            (
                "data",
                .object([
                    (
                        "parsed",
                        .object([
                            ("info", .object([("mint", .string("2222")), ("owner", .string("3333"))])),
                            ("type", .string("token")),
                        ])
                    ),
                    ("program", .string("splToken")),
                    ("space", .bigint("165")),
                ])
            ),
            ("executable", .bool(false)),
            ("lamports", .bigint("1000000000")),
            ("owner", .string(owner.rawValue)),
            ("space", .bigint("165")),
        ])
    }
}
