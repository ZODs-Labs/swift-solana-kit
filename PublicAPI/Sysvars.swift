public import Accounts
public import Addresses
public import CodecsCore
public import CodecsNumbers
public import Foundation
public import RpcSpec
public import RpcTypes

public let sysvarClockAddress: String
public let sysvarEpochRewardsAddress: String
public let sysvarEpochScheduleAddress: String
public let sysvarInstructionsAddress: String
public let sysvarLastRestartSlotAddress: String
public let sysvarRecentBlockhashesAddress: String
public let sysvarRentAddress: String
public let sysvarSlotHashesAddress: String
public let sysvarSlotHistoryAddress: String
public let sysvarStakeHistoryAddress: String

public struct SysvarClock: Sendable, Equatable, Hashable
public struct SysvarEpochRewards: Sendable, Equatable, Hashable
public struct SysvarEpochSchedule: Sendable, Equatable, Hashable
public struct SysvarLastRestartSlot: Sendable, Equatable, Hashable
public struct SysvarRecentBlockhashesFeeCalculator: Sendable, Equatable, Hashable
public struct SysvarRecentBlockhashesEntry: Sendable, Equatable, Hashable
public struct SysvarRent: Sendable, Equatable, Hashable
public struct SysvarSlotHashesEntry: Sendable, Equatable, Hashable
public struct SysvarSlotHistory: Sendable, Equatable, Hashable
public struct SysvarStakeHistoryValue: Sendable, Equatable, Hashable
public struct SysvarStakeHistoryEntry: Sendable, Equatable, Hashable

public typealias SysvarRecentBlockhashes = [SysvarRecentBlockhashesEntry]
public typealias SysvarSlotHashes = [SysvarSlotHashesEntry]
public typealias SysvarStakeHistory = [SysvarStakeHistoryEntry]

public let SysvarClock.epoch: Epoch
public let SysvarClock.epochStartTimestamp: UnixTimestamp
public let SysvarClock.leaderScheduleEpoch: Epoch
public let SysvarClock.slot: Slot
public let SysvarClock.unixTimestamp: UnixTimestamp
public init SysvarClock(epoch: Epoch, epochStartTimestamp: UnixTimestamp, leaderScheduleEpoch: Epoch, slot: Slot, unixTimestamp: UnixTimestamp)

public let SysvarEpochRewards.active: Bool
public let SysvarEpochRewards.distributedRewards: Lamports
public let SysvarEpochRewards.distributionStartingBlockHeight: UInt64
public let SysvarEpochRewards.numPartitions: UInt64
public let SysvarEpochRewards.parentBlockhash: Blockhash
public let SysvarEpochRewards.totalPoints: UInt128Value
public let SysvarEpochRewards.totalRewards: Lamports
public init SysvarEpochRewards(active: Bool, distributedRewards: Lamports, distributionStartingBlockHeight: UInt64, numPartitions: UInt64, parentBlockhash: Blockhash, totalPoints: UInt128Value, totalRewards: Lamports)

public let SysvarEpochSchedule.firstNormalEpoch: Epoch
public let SysvarEpochSchedule.firstNormalSlot: Slot
public let SysvarEpochSchedule.leaderScheduleSlotOffset: UInt64
public let SysvarEpochSchedule.slotsPerEpoch: UInt64
public let SysvarEpochSchedule.warmup: Bool
public init SysvarEpochSchedule(firstNormalEpoch: Epoch, firstNormalSlot: Slot, leaderScheduleSlotOffset: UInt64, slotsPerEpoch: UInt64, warmup: Bool)

public let SysvarLastRestartSlot.lastRestartSlot: Slot
public init SysvarLastRestartSlot(lastRestartSlot: Slot)

public let SysvarRecentBlockhashesFeeCalculator.lamportsPerSignature: Lamports
public init SysvarRecentBlockhashesFeeCalculator(lamportsPerSignature: Lamports)
public let SysvarRecentBlockhashesEntry.blockhash: Blockhash
public let SysvarRecentBlockhashesEntry.feeCalculator: SysvarRecentBlockhashesFeeCalculator
public init SysvarRecentBlockhashesEntry(blockhash: Blockhash, feeCalculator: SysvarRecentBlockhashesFeeCalculator)

public let SysvarRent.burnPercent: Int
public let SysvarRent.exemptionThreshold: F64UnsafeSeeDocumentation
public let SysvarRent.lamportsPerByteYear: Lamports
public init SysvarRent(burnPercent: Int, exemptionThreshold: F64UnsafeSeeDocumentation, lamportsPerByteYear: Lamports)

public let SysvarSlotHashesEntry.hash: Blockhash
public let SysvarSlotHashesEntry.slot: Slot
public init SysvarSlotHashesEntry(hash: Blockhash, slot: Slot)

public let SysvarSlotHistory.bits: [UInt64]
public let SysvarSlotHistory.nextSlot: Slot
public init SysvarSlotHistory(bits: [UInt64], nextSlot: Slot)

public let SysvarStakeHistoryValue.activating: Lamports
public let SysvarStakeHistoryValue.deactivating: Lamports
public let SysvarStakeHistoryValue.effective: Lamports
public init SysvarStakeHistoryValue(activating: Lamports, deactivating: Lamports, effective: Lamports)
public let SysvarStakeHistoryEntry.epoch: Epoch
public let SysvarStakeHistoryEntry.stakeHistory: SysvarStakeHistoryValue
public init SysvarStakeHistoryEntry(epoch: Epoch, stakeHistory: SysvarStakeHistoryValue)

public func fetchEncodedSysvarAccount(rpc: Rpc, address: Address, config: FetchAccountConfig = FetchAccountConfig()) async throws -> MaybeEncodedAccount
public func fetchJsonParsedSysvarAccount(rpc: Rpc, address: Address, config: FetchAccountConfig = FetchAccountConfig()) async throws -> MaybeJsonParsedOrEncodedAccount

public func getSysvarClockEncoder() -> AnyFixedSizeEncoder<SysvarClock>
public func getSysvarClockDecoder() -> AnyFixedSizeDecoder<SysvarClock>
public func getSysvarClockCodec() -> AnyFixedSizeCodec<SysvarClock, SysvarClock>
public func fetchSysvarClock(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarClock

public func getSysvarEpochRewardsEncoder() -> AnyFixedSizeEncoder<SysvarEpochRewards>
public func getSysvarEpochRewardsDecoder() -> AnyFixedSizeDecoder<SysvarEpochRewards>
public func getSysvarEpochRewardsCodec() -> AnyFixedSizeCodec<SysvarEpochRewards, SysvarEpochRewards>
public func fetchSysvarEpochRewards(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarEpochRewards

public func getSysvarEpochScheduleEncoder() -> AnyFixedSizeEncoder<SysvarEpochSchedule>
public func getSysvarEpochScheduleDecoder() -> AnyFixedSizeDecoder<SysvarEpochSchedule>
public func getSysvarEpochScheduleCodec() -> AnyFixedSizeCodec<SysvarEpochSchedule, SysvarEpochSchedule>
public func fetchSysvarEpochSchedule(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarEpochSchedule

public func getSysvarLastRestartSlotEncoder() -> AnyFixedSizeEncoder<SysvarLastRestartSlot>
public func getSysvarLastRestartSlotDecoder() -> AnyFixedSizeDecoder<SysvarLastRestartSlot>
public func getSysvarLastRestartSlotCodec() -> AnyFixedSizeCodec<SysvarLastRestartSlot, SysvarLastRestartSlot>
public func fetchSysvarLastRestartSlot(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarLastRestartSlot

public func getSysvarRecentBlockhashesEncoder() -> AnyVariableSizeEncoder<SysvarRecentBlockhashes>
public func getSysvarRecentBlockhashesDecoder() -> AnyVariableSizeDecoder<SysvarRecentBlockhashes>
public func getSysvarRecentBlockhashesCodec() -> AnyVariableSizeCodec<SysvarRecentBlockhashes, SysvarRecentBlockhashes>
public func fetchSysvarRecentBlockhashes(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarRecentBlockhashes

public func getSysvarRentEncoder() -> AnyFixedSizeEncoder<SysvarRent>
public func getSysvarRentDecoder() -> AnyFixedSizeDecoder<SysvarRent>
public func getSysvarRentCodec() -> AnyFixedSizeCodec<SysvarRent, SysvarRent>
public func fetchSysvarRent(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarRent

public func getSysvarSlotHashesEncoder() -> AnyVariableSizeEncoder<SysvarSlotHashes>
public func getSysvarSlotHashesDecoder() -> AnyVariableSizeDecoder<SysvarSlotHashes>
public func getSysvarSlotHashesCodec() -> AnyVariableSizeCodec<SysvarSlotHashes, SysvarSlotHashes>
public func fetchSysvarSlotHashes(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarSlotHashes

public func getSysvarSlotHistoryEncoder() -> AnyFixedSizeEncoder<SysvarSlotHistory>
public func getSysvarSlotHistoryDecoder() -> AnyFixedSizeDecoder<SysvarSlotHistory>
public func getSysvarSlotHistoryCodec() -> AnyFixedSizeCodec<SysvarSlotHistory, SysvarSlotHistory>
public func fetchSysvarSlotHistory(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarSlotHistory

public func getSysvarStakeHistoryEncoder() -> AnyVariableSizeEncoder<SysvarStakeHistory>
public func getSysvarStakeHistoryDecoder() -> AnyVariableSizeDecoder<SysvarStakeHistory>
public func getSysvarStakeHistoryCodec() -> AnyVariableSizeCodec<SysvarStakeHistory, SysvarStakeHistory>
public func fetchSysvarStakeHistory(rpc: Rpc, config: FetchAccountConfig = FetchAccountConfig()) async throws -> SysvarStakeHistory
