import Accounts
import Addresses
import CodecsCore
import Foundation
import Promises
import RpcSpec
import RpcSpecTypes
import RpcTypes
import SolanaErrors
import Sysvars
import XCTest

final class SysvarsDetailedBehaviorTests: XCTestCase {
    func testDecodeEpochScheduleAndLastRestartSlotFixtures() throws {
        let epochScheduleState = Data([
            16, 39, 0, 0, 0, 0, 0, 0,
            134, 74, 2, 0, 0, 0, 0, 0,
            1,
            38, 2, 0, 0, 0, 0, 0, 0,
            128, 147, 220, 20, 0, 0, 0, 0,
        ])
        let epochSchedule = try getSysvarEpochScheduleCodec().decode(epochScheduleState)
        XCTAssertEqual(epochSchedule.slotsPerEpoch, 10_000)
        XCTAssertEqual(epochSchedule.leaderScheduleSlotOffset, 150_150)
        XCTAssertTrue(epochSchedule.warmup)
        XCTAssertEqual(epochSchedule.firstNormalEpoch, 550)
        XCTAssertEqual(epochSchedule.firstNormalSlot, 350_000_000)

        let lastRestartSlotState = Data([119, 233, 246, 16, 0, 0, 0, 0])
        let lastRestartSlot = try getSysvarLastRestartSlotCodec().decode(lastRestartSlotState)
        XCTAssertEqual(lastRestartSlot.lastRestartSlot, 284_617_079)
    }

    func testDecodeRecentBlockhashesAndSlotHashesFixtures() throws {
        let recentBlockhashesState = Data([
            2, 0, 0, 0,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            134, 74, 2, 0, 0, 0, 0, 0,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            134, 74, 2, 0, 0, 0, 0, 0,
        ])
        let recentBlockhashes = try getSysvarRecentBlockhashesCodec().decode(recentBlockhashesState)
        XCTAssertEqual(recentBlockhashes.map(\.blockhash), [
            "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi",
            "8qbHbw2BbbTHBW1sbeqakYXVKRQM8Ne7pLK7m6CVfeR",
        ])
        XCTAssertEqual(recentBlockhashes.map(\.feeCalculator.lamportsPerSignature), [150_150, 150_150])

        let slotHashesState = Data([
            2, 0, 0, 0,
            134, 74, 2, 0, 0, 0, 0, 0,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            134, 74, 2, 0, 0, 0, 0, 0,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
            2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        ])
        let slotHashes = try getSysvarSlotHashesCodec().decode(slotHashesState)
        XCTAssertEqual(slotHashes.map(\.slot), [150_150, 150_150])
        XCTAssertEqual(slotHashes.map(\.hash), [
            "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi",
            "8qbHbw2BbbTHBW1sbeqakYXVKRQM8Ne7pLK7m6CVfeR",
        ])
    }

    func testSlotHistoryRejectsMalformedStaticFields() throws {
        let codec = getSysvarSlotHistoryCodec()

        var badDiscriminator = sysvarsValidSlotHistoryData()
        badDiscriminator[0] = 2
        XCTAssertThrowsError(try codec.decode(badDiscriminator)) { error in
            guard case let CodecsError.enumDiscriminatorOutOfRange(
                discriminator: discriminator,
                formattedValidDiscriminators: _,
                validDiscriminators: valid
            ) = error else {
                return XCTFail("Expected invalid discriminator")
            }
            XCTAssertEqual(discriminator, 2)
            XCTAssertEqual(valid, [1])
        }

        var badLength = sysvarsValidSlotHistoryData()
        sysvarsWriteU64(1, into: &badLength, at: 1)
        XCTAssertThrowsError(try codec.decode(badLength)) { error in
            guard case let CodecsError.invalidNumberOfItems(
                codecDescription: description,
                expected: expected,
                actual: actual
            ) = error else {
                return XCTFail("Expected invalid item count")
            }
            XCTAssertEqual(description, "SysvarSlotHistoryCodec")
            XCTAssertEqual(expected, 16_384)
            XCTAssertEqual(actual, 1)
        }

        var badNumBits = sysvarsValidSlotHistoryData()
        sysvarsWriteU64(1, into: &badNumBits, at: 1 + 8 + 16_384 * 8)
        XCTAssertThrowsError(try codec.decode(badNumBits)) { error in
            guard case let CodecsError.invalidNumberOfItems(
                codecDescription: description,
                expected: expected,
                actual: actual
            ) = error else {
                return XCTFail("Expected invalid bit count")
            }
            XCTAssertEqual(description, "SysvarSlotHistoryCodec")
            XCTAssertEqual(expected, 1_048_576)
            XCTAssertEqual(actual, 1)
        }
    }

    func testCodecsRoundTripValuesAndRespectWriteOffsets() throws {
        let rent = SysvarRent(burnPercent: 8, exemptionThreshold: 4.94065646e-316, lamportsPerByteYear: 100_000_000)
        let rentCodec = getSysvarRentCodec()
        var rentBytes = Data(repeating: 0xaa, count: 21)
        XCTAssertEqual(try rentCodec.write(rent, into: &rentBytes, at: 2), 19)
        XCTAssertEqual(try rentCodec.read(rentBytes, at: 2).0, rent)
        XCTAssertEqual(rentBytes.prefix(2), Data([0xaa, 0xaa]))
        XCTAssertEqual(rentBytes.suffix(2), Data([0xaa, 0xaa]))

        let entry = SysvarSlotHashesEntry(
            hash: "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi",
            slot: 150_150
        )
        let slotHashesCodec = getSysvarSlotHashesCodec()
        XCTAssertEqual(try slotHashesCodec.getSizeFromValue([entry]), 44)
        XCTAssertEqual(try slotHashesCodec.decode(try slotHashesCodec.encode([entry])), [entry])
    }

    func testFetchHelpersForwardAddressEncodingAndConfig() async throws {
        let owner = try Address("11111111111111111111111111111111")
        let clockAddress = try Address(sysvarClockAddress)
        let rentAddress = try Address(sysvarRentAddress)
        let signal = AbortSignal()
        let recorder = SysvarsRpcRecorder(responses: [
            .object([("value", sysvarsEncodedAccount(owner: owner, bytes: "somedata"))]),
            .object([("value", sysvarsParsedAccount(owner: owner))]),
        ])
        let rpc = await recorder.makeRpc()

        let encoded = try await fetchEncodedSysvarAccount(
            rpc: rpc,
            address: clockAddress,
            config: FetchAccountConfig(abortSignal: signal, commitment: .confirmed, minContextSlot: 12)
        )
        let parsed = try await fetchJsonParsedSysvarAccount(
            rpc: rpc,
            address: rentAddress,
            config: FetchAccountConfig(abortSignal: signal, commitment: .processed, minContextSlot: 13)
        )

        let encodedAccount: Account<Data> = try assertAccountExists(encoded)
        let parsedAccount = try assertAccountExists(try assertAccountDecoded(parsed))
        XCTAssertEqual(encodedAccount.address, clockAddress)
        XCTAssertEqual(parsedAccount.address, rentAddress)

        let configs = await recorder.configs()
        XCTAssertEqual(configs.count, 2)
        XCTAssertTrue(configs[0].abortSignal === signal)
        XCTAssertTrue(configs[1].abortSignal === signal)
        XCTAssertEqual(configs[0].payload.value(for: "method"), .string("getAccountInfo"))
        XCTAssertEqual(
            configs[0].payload.value(for: "params"),
            .array([
                .string(clockAddress.rawValue),
                .object([
                    ("encoding", .string("base64")),
                    ("commitment", .string("confirmed")),
                    ("minContextSlot", .bigint("12")),
                ]),
            ])
        )
        XCTAssertEqual(
            configs[1].payload.value(for: "params"),
            .array([
                .string(rentAddress.rawValue),
                .object([
                    ("encoding", .string("jsonParsed")),
                    ("commitment", .string("processed")),
                    ("minContextSlot", .bigint("13")),
                ]),
            ])
        )
    }
}

private actor SysvarsRpcRecorder {
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

    func transport(_ config: RpcTransportConfig) throws -> RpcJsonValue {
        recordedConfigs.append(config)
        guard !responses.isEmpty else {
            throw SysvarsDetailedError(message: "missing response")
        }
        return responses.removeFirst()
    }

    func configs() -> [RpcTransportConfig] {
        recordedConfigs
    }
}

private struct SysvarsDetailedError: Error, Sendable, Equatable {
    let message: String
}

private func sysvarsValidSlotHistoryData() -> Data {
    let codec = getSysvarSlotHistoryCodec()
    var data = Data(repeating: 0, count: codec.fixedSize)
    data[0] = 1
    sysvarsWriteU64(16_384, into: &data, at: 1)
    sysvarsWriteU64(1_048_576, into: &data, at: 1 + 8 + 16_384 * 8)
    sysvarsWriteU64(150_150, into: &data, at: 1 + 8 + 16_384 * 8 + 8)
    return data
}

private func sysvarsWriteU64(_ value: UInt64, into data: inout Data, at offset: Int) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) {
        data.replaceSubrange(offset..<offset + 8, with: $0)
    }
}

private func sysvarsEncodedAccount(owner: Address, bytes: String) -> RpcJsonValue {
    .object([
        ("data", .array([.string(bytes), .string("base64")])),
        ("executable", .bool(false)),
        ("lamports", .bigint("1000000000")),
        ("owner", .string(owner.rawValue)),
        ("space", .bigint("6")),
    ])
}

private func sysvarsParsedAccount(owner: Address) -> RpcJsonValue {
    .object([
        (
            "data",
            .object([
                (
                    "parsed",
                    .object([
                        ("info", .object([("mint", .string("2222"))])),
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

private extension RpcJsonValue {
    func value(for key: String) -> RpcJsonValue? {
        guard case let .object(members) = self else {
            return nil
        }
        return members.last { $0.key == key }?.value
    }
}
