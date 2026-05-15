import Foundation
import Sysvars
import XCTest

final class SysvarsTests: XCTestCase {
    func testDecodeClock() throws {
        let clockState = Data([
            119, 233, 246, 16, 0, 0, 0, 0,
            246, 255, 255, 255, 255, 255, 255, 255,
            4, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            224, 177, 255, 255, 255, 255, 255, 255,
        ])

        let clock = try getSysvarClockCodec().decode(clockState)

        XCTAssertEqual(clock, SysvarClock(
            epoch: 4,
            epochStartTimestamp: -10,
            leaderScheduleEpoch: 0,
            slot: 284_617_079,
            unixTimestamp: -20_000
        ))
    }

    func testDecodeEpochRewards() throws {
        let epochRewardsState = Data([
            0xab, 0xa8, 0x87, 0x12, 0x00, 0x00, 0x00, 0x00,
            0x3a, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x67, 0x8b, 0xd4, 0xe4, 0xc8, 0x5c, 0x10, 0x87,
            0xa8, 0x0a, 0xfb, 0x2f, 0x0d, 0xbb, 0x13, 0x27,
            0x16, 0x11, 0x3a, 0xc7, 0xc7, 0xb0, 0xc7, 0xe4,
            0x99, 0x51, 0x4d, 0x42, 0xdb, 0x43, 0xd7, 0x1c,
            0x10, 0xbe, 0x90, 0x99, 0x7a, 0x16, 0x9e, 0xa5,
            0xc2, 0x2d, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0xb3, 0x04, 0x4e, 0xd0, 0x20, 0x89, 0x00,
            0x00, 0xb8, 0xea, 0x37, 0xd0, 0x20, 0x89, 0x00,
            0x00,
        ])

        let rewards = try getSysvarEpochRewardsCodec().decode(epochRewardsState)

        XCTAssertFalse(rewards.active)
        XCTAssertEqual(rewards.distributionStartingBlockHeight, 310_880_427)
        XCTAssertEqual(rewards.numPartitions, 314)
        XCTAssertEqual(rewards.parentBlockhash, "7yCfKTaamnrmkAfefSgsonQ6rtwCfVaxQJircWb9K4Qj")
        XCTAssertEqual(rewards.totalPoints.description, "2633948733309470433656336")
        XCTAssertEqual(rewards.totalRewards, 38_598_150_843_577_088)
        XCTAssertEqual(rewards.distributedRewards, 38_598_150_472_775_680)
    }

    func testDecodeRent() throws {
        let rentState = Data([
            0, 225, 245, 5, 0, 0, 0, 0,
            0, 225, 245, 5, 0, 0, 0, 0,
            8,
        ])

        let rent = try getSysvarRentCodec().decode(rentState)

        XCTAssertEqual(rent.lamportsPerByteYear, 100_000_000)
        XCTAssertEqual(rent.exemptionThreshold, 4.94065646e-316)
        XCTAssertEqual(rent.burnPercent, 8)
    }

    func testDecodeSlotHistory() throws {
        let codec = getSysvarSlotHistoryCodec()
        var slotHistoryState = Data(repeating: 1, count: codec.fixedSize)
        var offset = 0
        slotHistoryState[offset] = 1
        offset += 1
        slotHistoryState.replaceSubrange(offset..<offset + 8, with: Data([0, 64, 0, 0, 0, 0, 0, 0]))
        offset += 8
        offset += 16_384 * 8
        slotHistoryState.replaceSubrange(offset..<offset + 8, with: Data([0, 0, 16, 0, 0, 0, 0, 0]))
        offset += 8
        slotHistoryState.replaceSubrange(offset..<offset + 8, with: Data([134, 74, 2, 0, 0, 0, 0, 0]))

        let slotHistory = try codec.decode(slotHistoryState)

        XCTAssertEqual(slotHistory.bits.first, 72_340_172_838_076_673)
        XCTAssertEqual(slotHistory.nextSlot, 150_150)
    }

    func testDecodeStakeHistory() throws {
        let stakeHistoryState = Data([
            2, 0, 0, 0, 0, 0, 0, 0,
            1, 0, 0, 0, 0, 0, 0, 0,
            0, 208, 237, 144, 46, 0, 0, 0,
            0, 160, 219, 33, 93, 0, 0, 0,
            0, 112, 201, 178, 139, 0, 0, 0,
            2, 0, 0, 0, 0, 0, 0, 0,
            0, 160, 219, 33, 93, 0, 0, 0,
            0, 112, 201, 178, 139, 0, 0, 0,
            0, 64, 183, 67, 186, 0, 0, 0,
        ])

        let stakeHistory = try getSysvarStakeHistoryCodec().decode(stakeHistoryState)

        XCTAssertEqual(stakeHistory[0].epoch, 1)
        XCTAssertEqual(stakeHistory[0].stakeHistory.effective, 200_000_000_000)
        XCTAssertEqual(stakeHistory[0].stakeHistory.activating, 400_000_000_000)
        XCTAssertEqual(stakeHistory[0].stakeHistory.deactivating, 600_000_000_000)
        XCTAssertEqual(stakeHistory[1].epoch, 2)
        XCTAssertEqual(stakeHistory[1].stakeHistory.effective, 400_000_000_000)
        XCTAssertEqual(stakeHistory[1].stakeHistory.activating, 600_000_000_000)
        XCTAssertEqual(stakeHistory[1].stakeHistory.deactivating, 800_000_000_000)
    }
}
