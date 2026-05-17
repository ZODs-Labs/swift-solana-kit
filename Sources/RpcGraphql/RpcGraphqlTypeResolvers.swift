public enum RpcGraphqlTypeResolvers {
    public static let accountEncodingCases: [String: String] = [
        "BASE_58": "base58",
        "BASE_64": "base64",
        "BASE_64_ZSTD": "base64+zstd",
    ]

    public static let commitmentCases: [String: String] = [
        "CONFIRMED": "confirmed",
        "FINALIZED": "finalized",
        "PROCESSED": "processed",
    ]

    public static let commitmentWithoutProcessedCases: [String: String] = [
        "CONFIRMED": "confirmed",
        "FINALIZED": "finalized",
    ]

    public static let transactionEncodingCases: [String: String] = [
        "BASE_58": "base58",
        "BASE_64": "base64",
    ]

    public static let programAccountsMemcmpFilterAccountEncodingCases: [String: String] = [
        "BASE_58": "base58",
        "BASE_64": "base64",
    ]

    public static let splTokenDefaultAccountStateCases: [String: String] = [
        "FROZEN": "frozen",
        "INITIALIZED": "initialized",
        "UNINITIALIZED": "uninitialized",
    ]

    public static let splTokenExtensionCases: [String: String] = [
        "CONFIDENTIAL_TRANSFER_ACCOUNT": "confidentialTransferAccount",
        "CONFIDENTIAL_TRANSFER_FEE_AMOUNT": "confidentialTransferFeeAmount",
        "CONFIDENTIAL_TRANSFER_FEE_CONFIG": "confidentialTransferFeeConfig",
        "CONFIDENTIAL_TRANSFER_MINT": "confidentialTransferMint",
        "CPI_GUARD": "cpiGuard",
        "DEFAULT_ACCOUNT_STATE": "defaultAccountState",
        "GROUP_MEMBER_POINTER": "groupMemberPointer",
        "GROUP_POINTER": "groupPointer",
        "IMMUTABLE_OWNER": "immutableOwner",
        "INTEREST_BEARING_CONFIG": "interestBearingConfig",
        "MEMO_TRANSFER": "memoTransfer",
        "METADATA_POINTER": "metadataPointer",
        "MINT_CLOSE_AUTHORITY": "mintCloseAuthority",
        "NON_TRANSFERABLE": "nonTransferable",
        "NON_TRANSFERABLE_ACCOUNT": "nonTransferableAccount",
        "PERMANENT_DELEGATE": "permanentDelegate",
        "TOKEN_GROUP": "tokenGroup",
        "TOKEN_GROUP_MEMBER": "tokenGroupMember",
        "TOKEN_METADATA": "tokenMetadata",
        "TRANSFER_FEE_AMOUNT": "transferFeeAmount",
        "TRANSFER_FEE_CONFIG": "transferFeeConfig",
        "TRANSFER_HOOK": "transferHook",
        "TRANSFER_HOOK_ACCOUNT": "transferHookAccount",
        "UNINITIALIZED": "uninitialized",
        "UNPARSEABLE_EXTENSION": "unparseableExtension",
    ]

    public static func accountTypeName(accountType: String?, programName: String?) -> String {
        if accountType == "lookupTable" && programName == "address-lookup-table" {
            return "LookupTableAccount"
        }
        if programName == "spl-token" || programName == "spl-token-2022" {
            if accountType == "mint" {
                return "MintAccount"
            }
            if accountType == "account" {
                return "TokenAccount"
            }
        }
        if programName == "nonce" {
            return "NonceAccount"
        }
        if programName == "stake" {
            return "StakeAccount"
        }
        if programName == "vote" {
            return "VoteAccount"
        }
        if programName == "sysvar" {
            return sysvarAccountTypeName(accountType) ?? "GenericAccount"
        }
        return "GenericAccount"
    }

    public static func splTokenExtensionTypeName(_ extensionName: String) -> String? {
        [
            "confidentialTransferAccount": "SplTokenExtensionConfidentialTransferAccount",
            "confidentialTransferFeeAmount": "SplTokenExtensionConfidentialTransferFeeAmount",
            "confidentialTransferFeeConfig": "SplTokenExtensionConfidentialTransferFeeConfig",
            "confidentialTransferMint": "SplTokenExtensionConfidentialTransferMint",
            "cpiGuard": "SplTokenExtensionCpiGuard",
            "defaultAccountState": "SplTokenExtensionDefaultAccountState",
            "groupMemberPointer": "SplTokenExtensionGroupMemberPointer",
            "groupPointer": "SplTokenExtensionGroupPointer",
            "immutableOwner": "SplTokenExtensionImmutableOwner",
            "interestBearingConfig": "SplTokenExtensionInterestBearingConfig",
            "memoTransfer": "SplTokenExtensionMemoTransfer",
            "metadataPointer": "SplTokenExtensionMetadataPointer",
            "mintCloseAuthority": "SplTokenExtensionMintCloseAuthority",
            "nonTransferable": "SplTokenExtensionNonTransferable",
            "nonTransferableAccount": "SplTokenExtensionNonTransferableAccount",
            "permanentDelegate": "SplTokenExtensionPermanentDelegate",
            "tokenGroup": "SplTokenExtensionTokenGroup",
            "tokenGroupMember": "SplTokenExtensionTokenGroupMember",
            "tokenMetadata": "SplTokenExtensionTokenMetadata",
            "transferFeeAmount": "SplTokenExtensionTransferFeeAmount",
            "transferFeeConfig": "SplTokenExtensionTransferFeeConfig",
            "transferHook": "SplTokenExtensionTransferHook",
            "transferHookAccount": "SplTokenExtensionTransferHookAccount",
            "unparseableExtension": "SplTokenExtensionUnparseable",
        ][extensionName]
    }

    public static func instructionTypeName(programName: String?, instructionType: String?) -> String {
        guard let programName, let instructionType else {
            return "GenericInstruction"
        }
        if programName == "address-lookup-table" {
            return addressLookupTableInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        if programName == "bpf-loader" {
            return bpfLoaderInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        if programName == "bpf-upgradeable-loader" {
            return bpfUpgradeableLoaderInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        if programName == "spl-associated-token-account" {
            return splAssociatedTokenInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        if programName == "spl-memo" {
            return "SplMemoInstruction"
        }
        if programName == "system" {
            return systemInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        if programName == "stake" {
            return stakeInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        if programName == "vote" {
            return voteInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        if programName == "spl-token" || programName == "spl-token-2022" {
            return splTokenInstructionTypeName(instructionType) ?? "GenericInstruction"
        }
        return "GenericInstruction"
    }

    private static func addressLookupTableInstructionTypeName(_ type: String) -> String? {
        [
            "createLookupTable": "CreateLookupTableInstruction",
            "extendLookupTable": "ExtendLookupTableInstruction",
            "freezeLookupTable": "FreezeLookupTableInstruction",
            "deactivateLookupTable": "DeactivateLookupTableInstruction",
            "closeLookupTable": "CloseLookupTableInstruction",
        ][type]
    }

    private static func bpfLoaderInstructionTypeName(_ type: String) -> String? {
        [
            "write": "BpfLoaderWriteInstruction",
            "finalize": "BpfLoaderFinalizeInstruction",
        ][type]
    }

    private static func bpfUpgradeableLoaderInstructionTypeName(_ type: String) -> String? {
        [
            "initializeBuffer": "BpfUpgradeableLoaderInitializeBufferInstruction",
            "write": "BpfUpgradeableLoaderWriteInstruction",
            "deployWithMaxDataLen": "BpfUpgradeableLoaderDeployWithMaxDataLenInstruction",
            "upgrade": "BpfUpgradeableLoaderUpgradeInstruction",
            "setAuthority": "BpfUpgradeableLoaderSetAuthorityInstruction",
            "setAuthorityChecked": "BpfUpgradeableLoaderSetAuthorityCheckedInstruction",
            "close": "BpfUpgradeableLoaderCloseInstruction",
            "extendProgram": "BpfUpgradeableLoaderExtendProgramInstruction",
        ][type]
    }

    private static func splAssociatedTokenInstructionTypeName(_ type: String) -> String? {
        [
            "create": "SplAssociatedTokenCreateInstruction",
            "createIdempotent": "SplAssociatedTokenCreateIdempotentInstruction",
            "recoverNested": "SplAssociatedTokenRecoverNestedInstruction",
        ][type]
    }

    private static func sysvarAccountTypeName(_ type: String?) -> String? {
        guard let type else {
            return nil
        }
        return [
            "clock": "SysvarClockAccount",
            "epochRewards": "SysvarEpochRewardsAccount",
            "epochSchedule": "SysvarEpochScheduleAccount",
            "lastRestartSlot": "SysvarLastRestartSlotAccount",
            "recentBlockhashes": "SysvarRecentBlockhashesAccount",
            "rent": "SysvarRentAccount",
            "slotHashes": "SysvarSlotHashesAccount",
            "slotHistory": "SysvarSlotHistoryAccount",
            "stakeHistory": "SysvarStakeHistoryAccount",
        ][type]
    }

    private static func systemInstructionTypeName(_ type: String) -> String? {
        [
            "advanceNonceAccount": "AdvanceNonceAccountInstruction",
            "allocate": "AllocateInstruction",
            "allocateWithSeed": "AllocateWithSeedInstruction",
            "assign": "AssignInstruction",
            "assignWithSeed": "AssignWithSeedInstruction",
            "authorizeNonceAccount": "AuthorizeNonceAccountInstruction",
            "createAccount": "CreateAccountInstruction",
            "createAccountWithSeed": "CreateAccountWithSeedInstruction",
            "initializeNonceAccount": "InitializeNonceAccountInstruction",
            "transfer": "TransferInstruction",
            "transferWithSeed": "TransferWithSeedInstruction",
            "upgradeNonceAccount": "UpgradeNonceAccountInstruction",
            "withdrawNonceAccount": "WithdrawNonceAccountInstruction",
        ][type]
    }

    private static func stakeInstructionTypeName(_ type: String) -> String? {
        [
            "authorize": "StakeAuthorizeInstruction",
            "authorizeChecked": "StakeAuthorizeCheckedInstruction",
            "authorizeCheckedWithSeed": "StakeAuthorizeCheckedWithSeedInstruction",
            "authorizeWithSeed": "StakeAuthorizeWithSeedInstruction",
            "deactivateDelinquent": "StakeDeactivateDelinquentInstruction",
            "delegate": "StakeDelegateStakeInstruction",
            "deactivate": "StakeDeactivateInstruction",
            "initialize": "StakeInitializeInstruction",
            "initializeChecked": "StakeInitializeCheckedInstruction",
            "merge": "StakeMergeInstruction",
            "redelegate": "StakeRedelegateInstruction",
            "setLockup": "StakeSetLockupInstruction",
            "setLockupChecked": "StakeSetLockupCheckedInstruction",
            "split": "StakeSplitInstruction",
            "withdraw": "StakeWithdrawInstruction",
        ][type]
    }

    private static func voteInstructionTypeName(_ type: String) -> String? {
        [
            "authorize": "VoteAuthorizeInstruction",
            "authorizeChecked": "VoteAuthorizeCheckedInstruction",
            "authorizeCheckedWithSeed": "VoteAuthorizeCheckedWithSeedInstruction",
            "authorizeWithSeed": "VoteAuthorizeWithSeedInstruction",
            "compactUpdateVoteState": "VoteCompactUpdateVoteStateInstruction",
            "compactUpdateVoteStateSwitch": "VoteCompactUpdateVoteStateSwitchInstruction",
            "initialize": "VoteInitializeAccountInstruction",
            "updateCommission": "VoteUpdateCommissionInstruction",
            "updateVoteState": "VoteUpdateVoteStateInstruction",
            "updateVoteStateSwitch": "VoteUpdateVoteStateSwitchInstruction",
            "updateValidatorIdentity": "VoteUpdateValidatorIdentityInstruction",
            "vote": "VoteVoteInstruction",
            "voteSwitch": "VoteVoteSwitchInstruction",
            "withdraw": "VoteWithdrawInstruction",
        ][type]
    }

    private static func splTokenInstructionTypeName(_ type: String) -> String? {
        [
            "amountToUiAmount": "SplTokenAmountToUiAmountInstruction",
            "approve": "SplTokenApproveInstruction",
            "approveChecked": "SplTokenApproveCheckedInstruction",
            "approveConfidentialTransferAccount": "SplTokenApproveConfidentialTransferAccount",
            "applyPendingConfidentialTransferBalance": "SplTokenApplyPendingConfidentialTransferBalance",
            "burn": "SplTokenBurnInstruction",
            "burnChecked": "SplTokenBurnCheckedInstruction",
            "closeAccount": "SplTokenCloseAccountInstruction",
            "configureConfidentialTransferAccount": "SplTokenConfigureConfidentialTransferAccount",
            "confidentialTransfer": "SplTokenConfidentialTransfer",
            "confidentialTransferWithSplitProofs": "SplTokenConfidentialTransferWithSplitProofs",
            "depositConfidentialTransfer": "SplTokenDepositConfidentialTransfer",
            "disableConfidentialTransferConfidentialCredits": "SplTokenDisableConfidentialTransferConfidentialCredits",
            "disableConfidentialTransferFeeHarvestToMint": "SplTokenDisableConfidentialTransferFeeHarvestToMint",
            "disableConfidentialTransferNonConfidentialCredits": "SplTokenDisableConfidentialTransferNonConfidentialCredits",
            "disableCpiGuard": "SplTokenDisableCpiGuardInstruction",
            "disableRequiredMemoTransfers": "SplTokenDisableRequiredMemoTransfers",
            "emptyConfidentialTransferAccount": "SplTokenEmptyConfidentialTransferAccount",
            "enableConfidentialTransferConfidentialCredits": "SplTokenEnableConfidentialTransferConfidentialCredits",
            "enableConfidentialTransferFeeHarvestToMint": "SplTokenEnableConfidentialTransferFeeHarvestToMint",
            "enableConfidentialTransferNonConfidentialCredits": "SplTokenEnableConfidentialTransferNonConfidentialCredits",
            "enableCpiGuard": "SplTokenEnableCpiGuardInstruction",
            "enableRequiredMemoTransfers": "SplTokenEnableRequiredMemoTransfers",
            "freezeAccount": "SplTokenFreezeAccountInstruction",
            "getAccountDataSize": "SplTokenGetAccountDataSizeInstruction",
            "harvestWithheldConfidentialTransferTokensToMint": "SplTokenHarvestWithheldConfidentialTransferTokensToMint",
            "harvestWithheldTokensToMint": "SplTokenHarvestWithheldTokensToMint",
            "initializeAccount2": "SplTokenInitializeAccount2Instruction",
            "initializeAccount3": "SplTokenInitializeAccount3Instruction",
            "initializeAccount": "SplTokenInitializeAccountInstruction",
            "initializeConfidentialTransferFeeConfig": "SplTokenInitializeConfidentialTransferFeeConfig",
            "initializeConfidentialTransferMint": "SplTokenInitializeConfidentialTransferMint",
            "initializeDefaultAccountState": "SplTokenInitializeDefaultAccountStateInstruction",
            "initializeGroupMemberPointer": "SplTokenInitializeGroupMemberPointerInstruction",
            "initializeGroupPointer": "SplTokenInitializeGroupPointerInstruction",
            "initializeGroup": "SplTokenGroupInitializeGroup",
            "initializeInterestBearingConfig": "SplTokenInitializeInterestBearingConfig",
            "initializeMetadataPointer": "SplTokenInitializeMetadataPointerInstruction",
            "initializeMint2": "SplTokenInitializeMint2Instruction",
            "initializeMint": "SplTokenInitializeMintInstruction",
            "initializeMintCloseAuthority": "SplTokenInitializeMintCloseAuthorityInstruction",
            "initializeMultisig2": "SplTokenInitializeMultisig2Instruction",
            "initializeMultisig": "SplTokenInitializeMultisigInstruction",
            "initializePermanentDelegate": "SplTokenInitializePermanentDelegateInstruction",
            "initializeTokenGroup": "SplTokenGroupInitializeGroup",
            "initializeTokenGroupMember": "SplTokenGroupInitializeMember",
            "initializeTokenMetadata": "SplTokenMetadataInitialize",
            "initializeTransferFeeConfig": "SplTokenInitializeTransferFeeConfig",
            "initializeTransferHook": "SplTokenInitializeTransferHookInstruction",
            "mintTo": "SplTokenMintToInstruction",
            "mintToChecked": "SplTokenMintToCheckedInstruction",
            "removeTokenMetadataKey": "SplTokenMetadataRemoveKey",
            "reallocate": "SplTokenReallocate",
            "revoke": "SplTokenRevokeInstruction",
            "setAuthority": "SplTokenSetAuthorityInstruction",
            "syncNative": "SplTokenSyncNativeInstruction",
            "thawAccount": "SplTokenThawAccountInstruction",
            "transfer": "SplTokenTransferInstruction",
            "transferChecked": "SplTokenTransferCheckedInstruction",
            "transferCheckedWithFee": "SplTokenTransferCheckedWithFee",
            "uiAmountToAmount": "SplTokenUiAmountToAmountInstruction",
            "updateConfidentialTransferMint": "SplTokenUpdateConfidentialTransferMint",
            "updateDefaultAccountState": "SplTokenUpdateDefaultAccountStateInstruction",
            "updateGroupMemberPointer": "SplTokenUpdateGroupMemberPointerInstruction",
            "updateGroupPointer": "SplTokenUpdateGroupPointerInstruction",
            "updateGroupAuthority": "SplTokenGroupUpdateGroupAuthority",
            "updateGroupMaxSize": "SplTokenGroupUpdateGroupMaxSize",
            "updateInterestBearingConfig": "SplTokenUpdateInterestBearingConfigRate",
            "updateMetadataPointer": "SplTokenUpdateMetadataPointerInstruction",
            "updateTokenMetadataAuthority": "SplTokenMetadataUpdateAuthority",
            "updateTokenMetadataField": "SplTokenMetadataUpdateField",
            "updateTransferHook": "SplTokenUpdateTransferHookInstruction",
            "withdrawConfidentialTransfer": "SplTokenWithdrawConfidentialTransfer",
            "withdrawWithheldConfidentialTransferTokensFromAccounts": "SplTokenWithdrawWithheldConfidentialTransferTokensFromAccounts",
            "withdrawWithheldConfidentialTransferTokensFromMint": "SplTokenWithdrawWithheldConfidentialTransferTokensFromMint",
            "withdrawWithheldTokensFromAccounts": "SplTokenWithdrawWithheldTokensFromAccounts",
            "withdrawWithheldTokensFromMint": "SplTokenWithdrawWithheldTokensFromMint",
        ][type]
    }
}
