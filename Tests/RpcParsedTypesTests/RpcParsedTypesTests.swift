import Addresses
import RpcParsedTypes
import RpcTypes
import XCTest

final class RpcParsedTypesTests: XCTestCase {
    func testVoteAccountModelPreservesNestedFields() throws {
        let node = try address("11111111111111111111111111111111")
        let collector = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let info = JsonParsedVoteAccountInfo(
            authorizedVoters: [JsonParsedAuthorizedVoter(authorizedVoter: node, epoch: 42)],
            authorizedWithdrawer: node,
            blockRevenueCollector: collector,
            blockRevenueCommissionBps: 25,
            blsPubkeyCompressed: nil,
            commission: 7,
            epochCredits: [JsonParsedEpochCredits(credits: "10", epoch: 1, previousCredits: "9")],
            inflationRewardsCollector: collector,
            inflationRewardsCommissionBps: 50,
            lastTimestamp: JsonParsedVoteLastTimestamp(slot: 99, timestamp: 1_700_000_000),
            nodePubkey: node,
            pendingDelegatorRewards: "123",
            priorVoters: [JsonParsedPriorVoter(authorizedPubkey: collector, epochOfLastAuthorizedSwitch: 2, targetEpoch: 3)],
            rootSlot: nil,
            votes: [JsonParsedVote(confirmationCount: 31, latency: 2, slot: 100)]
        )
        let parsed = JsonParsedVoteAccount(info: info)

        XCTAssertEqual(parsed.info.authorizedVoters.first?.authorizedVoter, node)
        XCTAssertEqual(parsed.info.blockRevenueCommissionBps, 25)
        XCTAssertEqual(parsed.info.votes.first?.latency, 2)
    }

    func testTokenAccountModelKeepsOptionalAuthoritiesAndExtensions() throws {
        let mint = try address("11111111111111111111111111111111")
        let owner = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let amount = TokenAmount(amount: "1000500", decimals: 6, uiAmount: 1.0005, uiAmountString: "1.0005")
        let account = JsonParsedTokenAccount(
            extensions: [.object(["kind": .string("transferFee")])],
            isNative: false,
            mint: mint,
            owner: owner,
            state: .initialized,
            tokenAmount: amount
        )
        let parsed = JsonParsedTokenProgramAccount.account(RpcParsedType(type: "account", info: account))

        XCTAssertEqual(parsed, .account(RpcParsedType(type: "account", info: account)))
    }

    func testAddressLookupTableAndLoaderModelsUseConcreteInfo() throws {
        let tableAddress = try address("11111111111111111111111111111111")
        let authority = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let lookup = JsonParsedAddressLookupTableAccount(
            info: JsonParsedAddressLookupTableAccountInfo(
                addresses: [tableAddress],
                authority: authority,
                deactivationSlot: "18446744073709551615",
                lastExtendedSlot: "10",
                lastExtendedSlotStartIndex: 1
            )
        )
        let loader = JsonParsedBpfUpgradeableLoaderProgramAccount.programData(
            RpcParsedType(
                type: "programData",
                info: JsonParsedBpfProgramDataAccount(data: Base64EncodedDataResponse("AQID"), slot: 42)
            )
        )

        XCTAssertEqual(lookup.info.addresses, [tableAddress])
        XCTAssertEqual(loader, .programData(RpcParsedType(type: "programData", info: JsonParsedBpfProgramDataAccount(data: Base64EncodedDataResponse("AQID"), slot: 42))))
    }

    func testStakeNonceConfigAndSysvarModelsPreserveRemainingFamilies() throws {
        let staker = try address("11111111111111111111111111111111")
        let withdrawer = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let stakeAccount = JsonParsedStakeAccount(
            meta: JsonParsedStakeMeta(
                authorized: JsonParsedStakeAuthorized(staker: staker, withdrawer: withdrawer),
                lockup: JsonParsedStakeLockup(custodian: withdrawer, epoch: 9, unixTimestamp: 1_700_000_000),
                rentExemptReserve: "100"
            ),
            stake: nil
        )
        let delegated = JsonParsedStakeProgramAccount.delegated(RpcParsedType(type: "delegated", info: stakeAccount))

        let nonce = JsonParsedNonceAccount(
            info: JsonParsedNonceAccountInfo(
                authority: staker,
                blockhash: "11111111111111111111111111111111",
                feeCalculator: JsonParsedNonceFeeCalculator(lamportsPerSignature: "5000")
            )
        )
        let config = JsonParsedConfigProgramAccount.validatorInfo(
            RpcParsedType(
                type: "validatorInfo",
                info: JsonParsedValidatorInfoAccount(
                    configData: .object(["name": .string("validator")]),
                    keys: [JsonParsedValidatorInfoKey(pubkey: staker, signer: true)]
                )
            )
        )
        let recentBlockhashes = JsonParsedSysvarAccount.recentBlockhashes(
            RpcParsedType(
                type: "recentBlockhashes",
                info: [JsonParsedRecentBlockhashesEntry(blockhash: "11111111111111111111111111111111", feeCalculator: JsonParsedFeeCalculator(lamportsPerSignature: "5000"))]
            )
        )
        let stakeHistory = JsonParsedSysvarAccount.stakeHistory(
            RpcParsedType(
                type: "stakeHistory",
                info: [JsonParsedStakeHistoryEntry(epoch: 1, stakeHistory: JsonParsedStakeHistoryValue(activating: 2, deactivating: 3, effective: 4))]
            )
        )

        XCTAssertEqual(delegated, .delegated(RpcParsedType(type: "delegated", info: stakeAccount)))
        XCTAssertNil(stakeAccount.stake)
        XCTAssertEqual(nonce.info.feeCalculator.lamportsPerSignature, "5000")
        XCTAssertEqual(config, .validatorInfo(RpcParsedType(type: "validatorInfo", info: JsonParsedValidatorInfoAccount(configData: .object(["name": .string("validator")]), keys: [JsonParsedValidatorInfoKey(pubkey: staker, signer: true)]))))
        XCTAssertEqual(recentBlockhashes, .recentBlockhashes(RpcParsedType(type: "recentBlockhashes", info: [JsonParsedRecentBlockhashesEntry(blockhash: "11111111111111111111111111111111", feeCalculator: JsonParsedFeeCalculator(lamportsPerSignature: "5000"))])))
        XCTAssertEqual(stakeHistory, .stakeHistory(RpcParsedType(type: "stakeHistory", info: [JsonParsedStakeHistoryEntry(epoch: 1, stakeHistory: JsonParsedStakeHistoryValue(activating: 2, deactivating: 3, effective: 4))])))
    }

    func testMintAndProgramParsedTypesKeepNullLikeAuthorities() throws {
        let mint = JsonParsedMintAccount(
            decimals: 6,
            freezeAuthority: nil,
            isInitialized: true,
            mintAuthority: nil,
            supply: "1000000"
        )
        let multisig = JsonParsedMultisigAccount(isInitialized: true, numRequiredSigners: 2, numValidSigners: 3, signers: [])
        let program = JsonParsedBpfProgramAccount(programData: try address("11111111111111111111111111111111"))

        XCTAssertEqual(JsonParsedTokenProgramAccount.mint(RpcParsedType(type: "mint", info: mint)), .mint(RpcParsedType(type: "mint", info: mint)))
        XCTAssertNil(mint.freezeAuthority)
        XCTAssertNil(mint.mintAuthority)
        XCTAssertEqual(JsonParsedTokenProgramAccount.multisig(RpcParsedType(type: "multisig", info: multisig)), .multisig(RpcParsedType(type: "multisig", info: multisig)))
        XCTAssertEqual(JsonParsedBpfUpgradeableLoaderProgramAccount.program(RpcParsedType(type: "program", info: program)), .program(RpcParsedType(type: "program", info: program)))
    }
}
