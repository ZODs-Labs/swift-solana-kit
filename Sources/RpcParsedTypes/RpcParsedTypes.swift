public import Addresses
public import RpcTypes

public struct RpcParsedInfo<Info: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let info: Info

    public init(info: Info) {
        self.info = info
    }
}

public struct RpcParsedType<Info: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let info: Info
    public let type: String

    public init(type: String, info: Info) {
        self.info = info
        self.type = type
    }
}

public struct RpcParsedAccountData: Sendable, Equatable, Hashable {
    public let program: String
    public let type: String
    public let info: RpcTypeJsonValue?

    public init(program: String, type: String, info: RpcTypeJsonValue? = nil) {
        self.program = program
        self.type = type
        self.info = info
    }
}

public struct RpcParsedAccount<Value: Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    public let pubkey: Address
    public let account: Value

    public init(pubkey: Address, account: Value) {
        self.pubkey = pubkey
        self.account = account
    }
}

public struct JsonParsedAddressLookupTableAccountInfo: Sendable, Equatable, Hashable {
    public let addresses: [Address]
    public let authority: Address?
    public let deactivationSlot: StringifiedBigInt
    public let lastExtendedSlot: StringifiedBigInt
    public let lastExtendedSlotStartIndex: Int

    public init(
        addresses: [Address],
        authority: Address? = nil,
        deactivationSlot: StringifiedBigInt,
        lastExtendedSlot: StringifiedBigInt,
        lastExtendedSlotStartIndex: Int
    ) {
        self.addresses = addresses
        self.authority = authority
        self.deactivationSlot = deactivationSlot
        self.lastExtendedSlot = lastExtendedSlot
        self.lastExtendedSlotStartIndex = lastExtendedSlotStartIndex
    }
}

public typealias JsonParsedAddressLookupTableAccount = RpcParsedInfo<JsonParsedAddressLookupTableAccountInfo>

public struct JsonParsedBpfProgramAccount: Sendable, Equatable, Hashable {
    public let programData: Address

    public init(programData: Address) {
        self.programData = programData
    }
}

public struct JsonParsedBpfProgramDataAccount: Sendable, Equatable, Hashable {
    public let authority: Address?
    public let data: Base64EncodedDataResponse
    public let slot: Slot

    public init(authority: Address? = nil, data: Base64EncodedDataResponse, slot: Slot) {
        self.authority = authority
        self.data = data
        self.slot = slot
    }
}

public enum JsonParsedBpfUpgradeableLoaderProgramAccount: Sendable, Equatable, Hashable {
    case program(RpcParsedType<JsonParsedBpfProgramAccount>)
    case programData(RpcParsedType<JsonParsedBpfProgramDataAccount>)
}

public struct JsonParsedStakeConfigAccount: Sendable, Equatable, Hashable {
    public let slashPenalty: Int
    public let warmupCooldownRate: F64UnsafeSeeDocumentation

    public init(slashPenalty: Int, warmupCooldownRate: F64UnsafeSeeDocumentation) {
        self.slashPenalty = slashPenalty
        self.warmupCooldownRate = warmupCooldownRate
    }
}

public struct JsonParsedValidatorInfoKey: Sendable, Equatable, Hashable {
    public let pubkey: Address
    public let signer: Bool

    public init(pubkey: Address, signer: Bool) {
        self.pubkey = pubkey
        self.signer = signer
    }
}

public struct JsonParsedValidatorInfoAccount: Sendable, Equatable, Hashable {
    public let configData: RpcTypeJsonValue
    public let keys: [JsonParsedValidatorInfoKey]

    public init(configData: RpcTypeJsonValue, keys: [JsonParsedValidatorInfoKey]) {
        self.configData = configData
        self.keys = keys
    }
}

public enum JsonParsedConfigProgramAccount: Sendable, Equatable, Hashable {
    case stakeConfig(RpcParsedType<JsonParsedStakeConfigAccount>)
    case validatorInfo(RpcParsedType<JsonParsedValidatorInfoAccount>)
}

public struct JsonParsedNonceFeeCalculator: Sendable, Equatable, Hashable {
    public let lamportsPerSignature: StringifiedBigInt

    public init(lamportsPerSignature: StringifiedBigInt) {
        self.lamportsPerSignature = lamportsPerSignature
    }
}

public struct JsonParsedNonceAccountInfo: Sendable, Equatable, Hashable {
    public let authority: Address
    public let blockhash: Blockhash
    public let feeCalculator: JsonParsedNonceFeeCalculator

    public init(authority: Address, blockhash: Blockhash, feeCalculator: JsonParsedNonceFeeCalculator) {
        self.authority = authority
        self.blockhash = blockhash
        self.feeCalculator = feeCalculator
    }
}

public typealias JsonParsedNonceAccount = RpcParsedInfo<JsonParsedNonceAccountInfo>

public struct JsonParsedStakeAuthorized: Sendable, Equatable, Hashable {
    public let staker: Address
    public let withdrawer: Address

    public init(staker: Address, withdrawer: Address) {
        self.staker = staker
        self.withdrawer = withdrawer
    }
}

public struct JsonParsedStakeLockup: Sendable, Equatable, Hashable {
    public let custodian: Address
    public let epoch: UInt64
    public let unixTimestamp: UnixTimestamp

    public init(custodian: Address, epoch: UInt64, unixTimestamp: UnixTimestamp) {
        self.custodian = custodian
        self.epoch = epoch
        self.unixTimestamp = unixTimestamp
    }
}

public struct JsonParsedStakeMeta: Sendable, Equatable, Hashable {
    public let authorized: JsonParsedStakeAuthorized
    public let lockup: JsonParsedStakeLockup
    public let rentExemptReserve: StringifiedBigInt

    public init(authorized: JsonParsedStakeAuthorized, lockup: JsonParsedStakeLockup, rentExemptReserve: StringifiedBigInt) {
        self.authorized = authorized
        self.lockup = lockup
        self.rentExemptReserve = rentExemptReserve
    }
}

public struct JsonParsedStakeDelegation: Sendable, Equatable, Hashable {
    public let activationEpoch: StringifiedBigInt
    public let deactivationEpoch: StringifiedBigInt
    public let stake: StringifiedBigInt
    public let voter: Address
    public let warmupCooldownRate: F64UnsafeSeeDocumentation

    public init(
        activationEpoch: StringifiedBigInt,
        deactivationEpoch: StringifiedBigInt,
        stake: StringifiedBigInt,
        voter: Address,
        warmupCooldownRate: F64UnsafeSeeDocumentation
    ) {
        self.activationEpoch = activationEpoch
        self.deactivationEpoch = deactivationEpoch
        self.stake = stake
        self.voter = voter
        self.warmupCooldownRate = warmupCooldownRate
    }
}

public struct JsonParsedStakeDetails: Sendable, Equatable, Hashable {
    public let creditsObserved: UInt64
    public let delegation: JsonParsedStakeDelegation

    public init(creditsObserved: UInt64, delegation: JsonParsedStakeDelegation) {
        self.creditsObserved = creditsObserved
        self.delegation = delegation
    }
}

public struct JsonParsedStakeAccount: Sendable, Equatable, Hashable {
    public let meta: JsonParsedStakeMeta
    public let stake: JsonParsedStakeDetails?

    public init(meta: JsonParsedStakeMeta, stake: JsonParsedStakeDetails?) {
        self.meta = meta
        self.stake = stake
    }
}

public enum JsonParsedStakeProgramAccount: Sendable, Equatable, Hashable {
    case delegated(RpcParsedType<JsonParsedStakeAccount>)
    case initialized(RpcParsedType<JsonParsedStakeAccount>)
}

public struct JsonParsedFeeCalculator: Sendable, Equatable, Hashable {
    public let lamportsPerSignature: StringifiedBigInt

    public init(lamportsPerSignature: StringifiedBigInt) {
        self.lamportsPerSignature = lamportsPerSignature
    }
}

public struct JsonParsedClockAccount: Sendable, Equatable, Hashable {
    public let epoch: Epoch
    public let epochStartTimestamp: UnixTimestamp
    public let leaderScheduleEpoch: Epoch
    public let slot: Slot
    public let unixTimestamp: UnixTimestamp

    public init(epoch: Epoch, epochStartTimestamp: UnixTimestamp, leaderScheduleEpoch: Epoch, slot: Slot, unixTimestamp: UnixTimestamp) {
        self.epoch = epoch
        self.epochStartTimestamp = epochStartTimestamp
        self.leaderScheduleEpoch = leaderScheduleEpoch
        self.slot = slot
        self.unixTimestamp = unixTimestamp
    }
}

public struct JsonParsedEpochScheduleAccount: Sendable, Equatable, Hashable {
    public let firstNormalEpoch: Epoch
    public let firstNormalSlot: Slot
    public let leaderScheduleSlotOffset: UInt64
    public let slotsPerEpoch: UInt64
    public let warmup: Bool

    public init(firstNormalEpoch: Epoch, firstNormalSlot: Slot, leaderScheduleSlotOffset: UInt64, slotsPerEpoch: UInt64, warmup: Bool) {
        self.firstNormalEpoch = firstNormalEpoch
        self.firstNormalSlot = firstNormalSlot
        self.leaderScheduleSlotOffset = leaderScheduleSlotOffset
        self.slotsPerEpoch = slotsPerEpoch
        self.warmup = warmup
    }
}

public struct JsonParsedFeesAccount: Sendable, Equatable, Hashable {
    public let feeCalculator: JsonParsedFeeCalculator

    public init(feeCalculator: JsonParsedFeeCalculator) {
        self.feeCalculator = feeCalculator
    }
}

public struct JsonParsedRecentBlockhashesEntry: Sendable, Equatable, Hashable {
    public let blockhash: Blockhash
    public let feeCalculator: JsonParsedFeeCalculator

    public init(blockhash: Blockhash, feeCalculator: JsonParsedFeeCalculator) {
        self.blockhash = blockhash
        self.feeCalculator = feeCalculator
    }
}

public struct JsonParsedRentAccount: Sendable, Equatable, Hashable {
    public let burnPercent: Int
    public let exemptionThreshold: F64UnsafeSeeDocumentation
    public let lamportsPerByteYear: StringifiedBigInt

    public init(burnPercent: Int, exemptionThreshold: F64UnsafeSeeDocumentation, lamportsPerByteYear: StringifiedBigInt) {
        self.burnPercent = burnPercent
        self.exemptionThreshold = exemptionThreshold
        self.lamportsPerByteYear = lamportsPerByteYear
    }
}

public struct JsonParsedSlotHashesEntry: Sendable, Equatable, Hashable {
    public let hash: String
    public let slot: Slot

    public init(hash: String, slot: Slot) {
        self.hash = hash
        self.slot = slot
    }
}

public struct JsonParsedSlotHistoryAccount: Sendable, Equatable, Hashable {
    public let bits: String
    public let nextSlot: Slot

    public init(bits: String, nextSlot: Slot) {
        self.bits = bits
        self.nextSlot = nextSlot
    }
}

public struct JsonParsedStakeHistoryValue: Sendable, Equatable, Hashable {
    public let activating: UInt64
    public let deactivating: UInt64
    public let effective: UInt64

    public init(activating: UInt64, deactivating: UInt64, effective: UInt64) {
        self.activating = activating
        self.deactivating = deactivating
        self.effective = effective
    }
}

public struct JsonParsedStakeHistoryEntry: Sendable, Equatable, Hashable {
    public let epoch: Epoch
    public let stakeHistory: JsonParsedStakeHistoryValue

    public init(epoch: Epoch, stakeHistory: JsonParsedStakeHistoryValue) {
        self.epoch = epoch
        self.stakeHistory = stakeHistory
    }
}

public struct JsonParsedLastRestartSlotAccount: Sendable, Equatable, Hashable {
    public let lastRestartSlot: Slot

    public init(lastRestartSlot: Slot) {
        self.lastRestartSlot = lastRestartSlot
    }
}

public struct JsonParsedEpochRewardsAccount: Sendable, Equatable, Hashable {
    public let distributedRewards: UInt64
    public let distributionCompleteBlockHeight: UInt64
    public let totalRewards: UInt64

    public init(distributedRewards: UInt64, distributionCompleteBlockHeight: UInt64, totalRewards: UInt64) {
        self.distributedRewards = distributedRewards
        self.distributionCompleteBlockHeight = distributionCompleteBlockHeight
        self.totalRewards = totalRewards
    }
}

public enum JsonParsedSysvarAccount: Sendable, Equatable, Hashable {
    case clock(RpcParsedType<JsonParsedClockAccount>)
    case epochRewards(RpcParsedType<JsonParsedEpochRewardsAccount>)
    case epochSchedule(RpcParsedType<JsonParsedEpochScheduleAccount>)
    case fees(RpcParsedType<JsonParsedFeesAccount>)
    case lastRestartSlot(RpcParsedType<JsonParsedLastRestartSlotAccount>)
    case recentBlockhashes(RpcParsedType<[JsonParsedRecentBlockhashesEntry]>)
    case rent(RpcParsedType<JsonParsedRentAccount>)
    case slotHashes(RpcParsedType<[JsonParsedSlotHashesEntry]>)
    case slotHistory(RpcParsedType<JsonParsedSlotHistoryAccount>)
    case stakeHistory(RpcParsedType<[JsonParsedStakeHistoryEntry]>)
}

public enum TokenAccountState: String, Sendable, Equatable, Hashable, Codable {
    case frozen
    case initialized
    case uninitialized
}

public struct JsonParsedTokenAccount: Sendable, Equatable, Hashable {
    public let closeAuthority: Address?
    public let delegate: Address?
    public let delegatedAmount: TokenAmount?
    public let extensions: [RpcTypeJsonValue]?
    public let isNative: Bool
    public let mint: Address
    public let owner: Address
    public let rentExemptReserve: TokenAmount?
    public let state: TokenAccountState
    public let tokenAmount: TokenAmount

    public init(
        closeAuthority: Address? = nil,
        delegate: Address? = nil,
        delegatedAmount: TokenAmount? = nil,
        extensions: [RpcTypeJsonValue]? = nil,
        isNative: Bool,
        mint: Address,
        owner: Address,
        rentExemptReserve: TokenAmount? = nil,
        state: TokenAccountState,
        tokenAmount: TokenAmount
    ) {
        self.closeAuthority = closeAuthority
        self.delegate = delegate
        self.delegatedAmount = delegatedAmount
        self.extensions = extensions
        self.isNative = isNative
        self.mint = mint
        self.owner = owner
        self.rentExemptReserve = rentExemptReserve
        self.state = state
        self.tokenAmount = tokenAmount
    }
}

public struct JsonParsedMintAccount: Sendable, Equatable, Hashable {
    public let decimals: Int
    public let extensions: [RpcTypeJsonValue]?
    public let freezeAuthority: Address?
    public let isInitialized: Bool
    public let mintAuthority: Address?
    public let supply: StringifiedBigInt

    public init(decimals: Int, extensions: [RpcTypeJsonValue]? = nil, freezeAuthority: Address?, isInitialized: Bool, mintAuthority: Address?, supply: StringifiedBigInt) {
        self.decimals = decimals
        self.extensions = extensions
        self.freezeAuthority = freezeAuthority
        self.isInitialized = isInitialized
        self.mintAuthority = mintAuthority
        self.supply = supply
    }
}

public struct JsonParsedMultisigAccount: Sendable, Equatable, Hashable {
    public let isInitialized: Bool
    public let numRequiredSigners: Int
    public let numValidSigners: Int
    public let signers: [Address]

    public init(isInitialized: Bool, numRequiredSigners: Int, numValidSigners: Int, signers: [Address]) {
        self.isInitialized = isInitialized
        self.numRequiredSigners = numRequiredSigners
        self.numValidSigners = numValidSigners
        self.signers = signers
    }
}

public enum JsonParsedTokenProgramAccount: Sendable, Equatable, Hashable {
    case account(RpcParsedType<JsonParsedTokenAccount>)
    case mint(RpcParsedType<JsonParsedMintAccount>)
    case multisig(RpcParsedType<JsonParsedMultisigAccount>)
}

public struct JsonParsedAuthorizedVoter: Sendable, Equatable, Hashable {
    public let authorizedVoter: Address
    public let epoch: Epoch

    public init(authorizedVoter: Address, epoch: Epoch) {
        self.authorizedVoter = authorizedVoter
        self.epoch = epoch
    }
}

public struct JsonParsedEpochCredits: Sendable, Equatable, Hashable {
    public let credits: StringifiedBigInt
    public let epoch: Epoch
    public let previousCredits: StringifiedBigInt

    public init(credits: StringifiedBigInt, epoch: Epoch, previousCredits: StringifiedBigInt) {
        self.credits = credits
        self.epoch = epoch
        self.previousCredits = previousCredits
    }
}

public struct JsonParsedVoteLastTimestamp: Sendable, Equatable, Hashable {
    public let slot: Slot
    public let timestamp: UnixTimestamp

    public init(slot: Slot, timestamp: UnixTimestamp) {
        self.slot = slot
        self.timestamp = timestamp
    }
}

public struct JsonParsedPriorVoter: Sendable, Equatable, Hashable {
    public let authorizedPubkey: Address
    public let epochOfLastAuthorizedSwitch: Epoch
    public let targetEpoch: Epoch

    public init(authorizedPubkey: Address, epochOfLastAuthorizedSwitch: Epoch, targetEpoch: Epoch) {
        self.authorizedPubkey = authorizedPubkey
        self.epochOfLastAuthorizedSwitch = epochOfLastAuthorizedSwitch
        self.targetEpoch = targetEpoch
    }
}

public struct JsonParsedVote: Sendable, Equatable, Hashable {
    public let confirmationCount: Int
    public let latency: UInt64
    public let slot: Slot

    public init(confirmationCount: Int, latency: UInt64, slot: Slot) {
        self.confirmationCount = confirmationCount
        self.latency = latency
        self.slot = slot
    }
}

public struct JsonParsedVoteAccountInfo: Sendable, Equatable, Hashable {
    public let authorizedVoters: [JsonParsedAuthorizedVoter]
    public let authorizedWithdrawer: Address
    public let blockRevenueCollector: Address
    public let blockRevenueCommissionBps: UInt64
    public let blsPubkeyCompressed: String?
    public let commission: Int
    public let epochCredits: [JsonParsedEpochCredits]
    public let inflationRewardsCollector: Address
    public let inflationRewardsCommissionBps: UInt64
    public let lastTimestamp: JsonParsedVoteLastTimestamp
    public let nodePubkey: Address
    public let pendingDelegatorRewards: StringifiedBigInt
    public let priorVoters: [JsonParsedPriorVoter]
    public let rootSlot: Slot?
    public let votes: [JsonParsedVote]

    public init(
        authorizedVoters: [JsonParsedAuthorizedVoter],
        authorizedWithdrawer: Address,
        blockRevenueCollector: Address,
        blockRevenueCommissionBps: UInt64,
        blsPubkeyCompressed: String?,
        commission: Int,
        epochCredits: [JsonParsedEpochCredits],
        inflationRewardsCollector: Address,
        inflationRewardsCommissionBps: UInt64,
        lastTimestamp: JsonParsedVoteLastTimestamp,
        nodePubkey: Address,
        pendingDelegatorRewards: StringifiedBigInt,
        priorVoters: [JsonParsedPriorVoter],
        rootSlot: Slot?,
        votes: [JsonParsedVote]
    ) {
        self.authorizedVoters = authorizedVoters
        self.authorizedWithdrawer = authorizedWithdrawer
        self.blockRevenueCollector = blockRevenueCollector
        self.blockRevenueCommissionBps = blockRevenueCommissionBps
        self.blsPubkeyCompressed = blsPubkeyCompressed
        self.commission = commission
        self.epochCredits = epochCredits
        self.inflationRewardsCollector = inflationRewardsCollector
        self.inflationRewardsCommissionBps = inflationRewardsCommissionBps
        self.lastTimestamp = lastTimestamp
        self.nodePubkey = nodePubkey
        self.pendingDelegatorRewards = pendingDelegatorRewards
        self.priorVoters = priorVoters
        self.rootSlot = rootSlot
        self.votes = votes
    }
}

public typealias JsonParsedVoteAccount = RpcParsedInfo<JsonParsedVoteAccountInfo>

public typealias RpcParsedTypeName = String
public typealias AddressLookupTableAccountType = JsonParsedAddressLookupTableAccount
public typealias BpfUpgradeableLoaderAccountType = JsonParsedBpfUpgradeableLoaderProgramAccount
public typealias ConfigAccountType = JsonParsedConfigProgramAccount
public typealias NonceAccountType = JsonParsedNonceAccount
public typealias StakeAccountType = JsonParsedStakeProgramAccount
public typealias SysvarAccountType = JsonParsedSysvarAccount
public typealias TokenAccountType = JsonParsedTokenProgramAccount
public typealias VoteAccountType = JsonParsedVoteAccount
