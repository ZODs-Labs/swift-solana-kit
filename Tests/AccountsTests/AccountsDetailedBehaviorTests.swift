import Accounts
import Addresses
import CodecsCore
import Foundation
import Promises
import RpcSpec
import RpcSpecTypes
import RpcTypes
import SolanaErrors
import XCTest

final class AccountsDetailedBehaviorTests: XCTestCase {
    func testBaseAccountConstantsAndMaybeAccessorsExposeExistenceState() throws {
        let owner = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("Sysvar1111111111111111111111111111111111111")
        let existing = Account(
            address: accountAddress,
            data: Data([1, 2, 3]),
            executable: true,
            lamports: 44,
            programAddress: owner,
            space: 3
        )
        let maybeExisting = MaybeEncodedAccount.exists(existing)
        let maybeMissing = MaybeEncodedAccount.missing(address: owner)

        XCTAssertEqual(baseAccountSize, 128)
        XCTAssertEqual(maybeExisting.address, accountAddress)
        XCTAssertTrue(maybeExisting.exists)
        XCTAssertEqual(maybeExisting.account, existing)
        XCTAssertEqual(maybeMissing.address, owner)
        XCTAssertFalse(maybeMissing.exists)
        XCTAssertNil(maybeMissing.account)

        let parsedData = JsonParsedAccountData(info: .object(["mint": .string("2222")]))
        let parsedAccount = Account(
            address: accountAddress,
            data: parsedData,
            executable: false,
            lamports: 1,
            programAddress: owner,
            space: 1
        )
        let parsed = MaybeJsonParsedOrEncodedAccount.parsed(parsedAccount)
        let encoded = MaybeJsonParsedOrEncodedAccount.encoded(existing)

        XCTAssertEqual(parsed.parsedAccount, parsedAccount)
        XCTAssertNil(parsed.encodedAccount)
        XCTAssertEqual(encoded.encodedAccount, existing)
        XCTAssertNil(encoded.parsedAccount)
    }

    func testBase58AndBase64ParsingPreserveBytesAndMissingAccounts() throws {
        let owner = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("Sysvar1111111111111111111111111111111111111")
        let base = AccountInfoBase(executable: false, lamports: 1_000_000_000, owner: owner, space: 6)

        let base58 = try parseBase58RpcAccount(
            accountAddress,
            Base58RpcAccount(base: base, data: Base58EncodedDataResponse("somedata"))
        )
        let base64 = try parseBase64RpcAccount(
            accountAddress,
            Base64RpcAccount(base: base, data: Base64EncodedDataResponse("somedata"))
        )

        XCTAssertEqual(try assertAccountExists(base58).data, Data([102, 6, 221, 155, 82, 67]))
        XCTAssertEqual(try assertAccountExists(base64).data, Data([178, 137, 158, 117, 171, 90]))
        XCTAssertEqual(try parseBase58RpcAccount(accountAddress, nil), .missing(address: accountAddress))
        XCTAssertEqual(try parseBase64RpcAccount(accountAddress, nil), .missing(address: accountAddress))
    }

    func testJsonParsedMetadataVariantsAndNullInfo() throws {
        let owner = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("Sysvar1111111111111111111111111111111111111")
        let base = AccountInfoBase(executable: false, lamports: 1_000_000_000, owner: owner, space: 165)

        let programOnly = parseJsonRpcAccount(
            accountAddress,
            JsonParsedRpcAccount(
                base: base,
                data: AccountInfoJsonParsedData(
                    parsed: AccountInfoParsedData(info: .object(["mint": .string("2222")]), type: ""),
                    program: "splToken",
                    space: 165
                )
            )
        )
        let typeOnly = parseJsonRpcAccount(
            accountAddress,
            JsonParsedRpcAccount(
                base: base,
                data: AccountInfoJsonParsedData(
                    parsed: AccountInfoParsedData(info: .object(["mint": .string("2222")]), type: "token"),
                    program: "",
                    space: 165
                )
            )
        )
        let noMetadata = parseJsonRpcAccount(
            accountAddress,
            JsonParsedRpcAccount(
                base: base,
                data: AccountInfoJsonParsedData(
                    parsed: AccountInfoParsedData(info: .array([.object(["blockhash": .string("1111")])]), type: ""),
                    program: "",
                    space: 165
                )
            )
        )
        let nilInfo = parseJsonRpcAccount(
            accountAddress,
            JsonParsedRpcAccount(
                base: base,
                data: AccountInfoJsonParsedData(
                    parsed: AccountInfoParsedData(type: "token"),
                    program: "splToken",
                    space: 165
                )
            )
        )

        XCTAssertEqual(try assertAccountExists(programOnly).data.parsedAccountMeta, ParsedAccountMeta(program: "splToken"))
        XCTAssertEqual(try assertAccountExists(typeOnly).data.parsedAccountMeta, ParsedAccountMeta(type: "token"))
        XCTAssertNil(try assertAccountExists(noMetadata).data.parsedAccountMeta)
        XCTAssertEqual(try assertAccountExists(noMetadata).data.info, .array([.object(["blockhash": .string("1111")])]))
        XCTAssertEqual(try assertAccountExists(nilInfo).data.info, .object([:]))
        XCTAssertEqual(try assertAccountExists(nilInfo).data.parsedAccountMeta, ParsedAccountMeta(program: "splToken", type: "token"))
        XCTAssertEqual(parseJsonRpcAccount(accountAddress, nil), .missing(address: accountAddress))
    }

    func testJsonRpcParsingRejectsMalformedFieldsAndEncodings() throws {
        let owner = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("Sysvar1111111111111111111111111111111111111")
        let validBase = Self.encodedJsonAccount(owner: owner, bytes: "somedata", encoding: "base64")

        let malformedValues: [RpcJsonValue] = [
            .object([RpcJsonObjectMember]()),
            Self.encodedJsonAccount(owner: owner, bytes: "somedata", encoding: "base58"),
            .object([
                RpcJsonObjectMember("data", .array([.string("somedata"), .string("base64")])),
                RpcJsonObjectMember("executable", .bool(false)),
                RpcJsonObjectMember("lamports", .number(-1)),
                RpcJsonObjectMember("owner", .string(owner.rawValue)),
                RpcJsonObjectMember("space", .bigint("6")),
            ]),
            .object([
                RpcJsonObjectMember("data", .array([.string("somedata"), .string("base64")])),
                RpcJsonObjectMember("executable", .bool(false)),
                RpcJsonObjectMember("lamports", .string("not-number")),
                RpcJsonObjectMember("owner", .string(owner.rawValue)),
                RpcJsonObjectMember("space", .bigint("6")),
            ]),
        ]

        for value in malformedValues {
            assertAccountsSolanaError(
                try parseBase64RpcAccount(accountAddress, value),
                code: .malformedJSONRPCError
            )
        }
        assertAccountsSolanaError(
            try parseJsonRpcAccount(accountAddress, validBase),
            code: .malformedJSONRPCError
        )
    }

    func testDecodeAccountPreservesMetadataAndMapsDecoderFailures() throws {
        let owner = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("SysvarC1ock11111111111111111111111111111111")
        let encoded = EncodedAccount(
            address: accountAddress,
            data: Data([1, 2, 3]),
            executable: true,
            lamports: 99,
            programAddress: owner,
            space: 3
        )
        let decoder = createDecoder(fixedSize: 3) { bytes, offset in
            (AccountsDecodedSample(sum: bytes.reduce(0) { $0 + Int($1) }, offset: offset), offset + bytes.count)
        }
        let failingDecoder = createDecoder(fixedSize: 1) { (_: Data, _: Offset) in
            throw CodecsError.invalidPatternMatchBytes
        } as AnyFixedSizeDecoder<AccountsDecodedSample>

        let decoded = try decodeAccount(encoded, using: decoder)

        XCTAssertEqual(decoded.address, accountAddress)
        XCTAssertEqual(decoded.data, AccountsDecodedSample(sum: 6, offset: 0))
        XCTAssertTrue(decoded.executable)
        XCTAssertEqual(decoded.lamports, 99)
        XCTAssertEqual(decoded.programAddress, owner)
        XCTAssertEqual(decoded.space, 3)
        assertAccountsSolanaError(
            try decodeAccount(encoded, using: failingDecoder),
            code: .accountsFailedToDecodeAccount,
            context: ["address": .string(accountAddress.rawValue)]
        )
    }

    func testDecodedAssertionsIgnoreMissingAndReportEncodedAddressesInOrder() throws {
        let owner = try Address("11111111111111111111111111111111")
        let first = try Address("SysvarC1ock11111111111111111111111111111111")
        let second = try Address("SysvarRent111111111111111111111111111111111")
        let third = try Address("Sysvar1111111111111111111111111111111111111")
        let firstEncoded = EncodedAccount(address: first, data: Data(), executable: false, lamports: 1, programAddress: owner, space: 0)
        let secondEncoded = EncodedAccount(address: second, data: Data(), executable: false, lamports: 2, programAddress: owner, space: 0)
        let decoded = Account(
            address: third,
            data: AccountsDecodedSample(sum: 1, offset: 0),
            executable: false,
            lamports: 3,
            programAddress: owner,
            space: 0
        )

        XCTAssertNoThrow(try assertAccountDecoded(MaybeAccount<AccountsDecodedSample>.missing(address: third)))
        XCTAssertNoThrow(try assertAccountsDecoded([decoded]))
        assertAccountsSolanaError(
            try assertAccountDecoded(firstEncoded),
            code: .accountsExpectedDecodedAccount,
            context: ["address": .string(first.rawValue)]
        )
        assertAccountsSolanaError(
            try assertAccountsDecoded([MaybeEncodedAccount.exists(firstEncoded), .missing(address: third), .exists(secondEncoded)]),
            code: .accountsExpectedAllAccountsToBeDecoded,
            context: ["addresses": .stringArray([first.rawValue, second.rawValue])]
        )
    }

    func testJsonParsedDecodedAssertionsConvertParsedAndMissingAndRejectEncodedFallbacks() throws {
        let owner = try Address("11111111111111111111111111111111")
        let parsedAddress = try Address("Sysvar1111111111111111111111111111111111111")
        let encodedAddress = try Address("SysvarC1ock11111111111111111111111111111111")
        let missingAddress = try Address("SysvarRent111111111111111111111111111111111")
        let parsed = Account(
            address: parsedAddress,
            data: JsonParsedAccountData(info: .object(["mint": .string("2222")])),
            executable: false,
            lamports: 1,
            programAddress: owner,
            space: 1
        )
        let encoded = EncodedAccount(
            address: encodedAddress,
            data: Data([1]),
            executable: false,
            lamports: 1,
            programAddress: owner,
            space: 1
        )

        let decoded = try assertAccountsDecoded([
            MaybeJsonParsedOrEncodedAccount.parsed(parsed),
            .missing(address: missingAddress),
        ])
        XCTAssertEqual(decoded, [.exists(parsed), .missing(address: missingAddress)])
        assertAccountsSolanaError(
            try assertAccountDecoded(MaybeJsonParsedOrEncodedAccount.encoded(encoded)),
            code: .accountsExpectedDecodedAccount,
            context: ["address": .string(encodedAddress.rawValue)]
        )
        assertAccountsSolanaError(
            try assertAccountsDecoded([.parsed(parsed), .encoded(encoded), .missing(address: missingAddress)]),
            code: .accountsExpectedAllAccountsToBeDecoded,
            context: ["addresses": .stringArray([encodedAddress.rawValue])]
        )
    }

    func testFetchHelpersForwardEncodingCommitmentMinSlotAndAbortSignal() async throws {
        let owner = try Address("11111111111111111111111111111111")
        let first = try Address("SysvarC1ock11111111111111111111111111111111")
        let second = try Address("SysvarRent111111111111111111111111111111111")
        let signal = AbortSignal()
        let recorder = AccountsRpcRecorder(responses: [
            .object([RpcJsonObjectMember("value", Self.encodedJsonAccount(owner: owner, bytes: "somedata", encoding: "base64"))]),
            .object([
                RpcJsonObjectMember("value", .array([
                    Self.parsedJsonAccount(owner: owner),
                    .null,
                ])),
            ]),
        ])
        let rpc = await recorder.makeRpc()

        let encoded = try await fetchEncodedAccount(
            rpc: rpc,
            address: first,
            config: FetchAccountConfig(abortSignal: signal, commitment: .confirmed, minContextSlot: 12)
        )
        let parsed = try await fetchJsonParsedAccounts(
            rpc: rpc,
            addresses: [first, second],
            config: FetchAccountsConfig(abortSignal: signal, commitment: .processed, minContextSlot: 13)
        )

        XCTAssertEqual(try assertAccountExists(encoded).data, Data([178, 137, 158, 117, 171, 90]))
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].parsedAccount?.data.info, .object(["mint": .string("2222")]))
        XCTAssertEqual(parsed[1], .missing(address: second))

        let configs = await recorder.configs()
        XCTAssertEqual(configs.count, 2)
        XCTAssertTrue(configs[0].abortSignal === signal)
        XCTAssertTrue(configs[1].abortSignal === signal)
        XCTAssertEqual(configs[0].payload.value(for: "method"), .string("getAccountInfo"))
        XCTAssertEqual(
            configs[0].payload.value(for: "params"),
            .array([
                .string(first.rawValue),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("commitment", .string("confirmed")),
                    RpcJsonObjectMember("minContextSlot", .bigint("12")),
                ]),
            ])
        )
        XCTAssertEqual(configs[1].payload.value(for: "method"), .string("getMultipleAccounts"))
        XCTAssertEqual(
            configs[1].payload.value(for: "params"),
            .array([
                .array([.string(first.rawValue), .string(second.rawValue)]),
                .object([
                    RpcJsonObjectMember("encoding", .string("jsonParsed")),
                    RpcJsonObjectMember("commitment", .string("processed")),
                    RpcJsonObjectMember("minContextSlot", .bigint("13")),
                ]),
            ])
        )
    }

    private static func encodedJsonAccount(owner: Address, bytes: String, encoding: String) -> RpcJsonValue {
        .object([
            RpcJsonObjectMember("data", .array([.string(bytes), .string(encoding)])),
            RpcJsonObjectMember("executable", .bool(false)),
            RpcJsonObjectMember("lamports", .bigint("1000000000")),
            RpcJsonObjectMember("owner", .string(owner.rawValue)),
            RpcJsonObjectMember("space", .bigint("6")),
        ])
    }

    private static func parsedJsonAccount(owner: Address) -> RpcJsonValue {
        .object([
            RpcJsonObjectMember(
                "data",
                .object([
                    RpcJsonObjectMember(
                        "parsed",
                        .object([
                            RpcJsonObjectMember("info", .object([RpcJsonObjectMember("mint", .string("2222"))])),
                            RpcJsonObjectMember("type", .string("token")),
                        ])
                    ),
                    RpcJsonObjectMember("program", .string("splToken")),
                    RpcJsonObjectMember("space", .bigint("165")),
                ])
            ),
            RpcJsonObjectMember("executable", .bool(false)),
            RpcJsonObjectMember("lamports", .bigint("1000000000")),
            RpcJsonObjectMember("owner", .string(owner.rawValue)),
            RpcJsonObjectMember("space", .bigint("165")),
        ])
    }
}

private struct AccountsDecodedSample: Sendable, Equatable, Hashable {
    let sum: Int
    let offset: Int
}

private actor AccountsRpcRecorder {
    private var responses: [RpcJsonValue]
    private var recordedConfigs: [RpcTransportConfig] = []

    init(responses: [RpcJsonValue]) {
        self.responses = responses
    }

    func makeRpc() -> Rpc {
        createRpc(api: createJsonRpcApi()) { config in
            try await self.transport(config)
        }
    }

    func transport(_ config: RpcTransportConfig) async throws -> RpcJsonValue {
        recordedConfigs.append(config)
        guard !responses.isEmpty else {
            throw AccountsTestError(message: "missing response")
        }
        return responses.removeFirst()
    }

    func configs() -> [RpcTransportConfig] {
        recordedConfigs
    }
}

private struct AccountsTestError: Error, Sendable, Equatable {
    let message: String
}

private func assertAccountsSolanaError<T>(
    _ expression: @autoclosure () throws -> T,
    code: SolanaErrorCode,
    context: [String: SolanaErrorContextValue] = [:],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        guard let solanaError = error as? SolanaError else {
            return XCTFail("Expected SolanaError", file: file, line: line)
        }
        XCTAssertEqual(solanaError.solanaCode, code, file: file, line: line)
        for (key, value) in context {
            XCTAssertEqual(solanaError.context[key], value, file: file, line: line)
        }
    }
}
