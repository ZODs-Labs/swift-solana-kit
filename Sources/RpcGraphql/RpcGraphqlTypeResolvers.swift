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
            "withdrawNonceAccount": "WithdrawNonceAccountInstruction",
        ][type]
    }

    private static func stakeInstructionTypeName(_ type: String) -> String? {
        [
            "authorize": "StakeAuthorizeInstruction",
            "authorizeChecked": "StakeAuthorizeCheckedInstruction",
            "delegate": "StakeDelegateStakeInstruction",
            "deactivate": "StakeDeactivateInstruction",
            "initialize": "StakeInitializeInstruction",
            "merge": "StakeMergeInstruction",
            "split": "StakeSplitInstruction",
            "withdraw": "StakeWithdrawInstruction",
        ][type]
    }

    private static func voteInstructionTypeName(_ type: String) -> String? {
        [
            "authorize": "VoteAuthorizeInstruction",
            "authorizeChecked": "VoteAuthorizeCheckedInstruction",
            "initialize": "VoteInitializeAccountInstruction",
            "updateCommission": "VoteUpdateCommissionInstruction",
            "updateValidatorIdentity": "VoteUpdateValidatorIdentityInstruction",
            "vote": "VoteVoteInstruction",
            "withdraw": "VoteWithdrawInstruction",
        ][type]
    }

    private static func splTokenInstructionTypeName(_ type: String) -> String? {
        [
            "approve": "SplTokenApproveInstruction",
            "burn": "SplTokenBurnInstruction",
            "closeAccount": "SplTokenCloseAccountInstruction",
            "freezeAccount": "SplTokenFreezeAccountInstruction",
            "initializeAccount": "SplTokenInitializeAccountInstruction",
            "initializeMint": "SplTokenInitializeMintInstruction",
            "mintTo": "SplTokenMintToInstruction",
            "reallocate": "SplTokenReallocate",
            "thawAccount": "SplTokenThawAccountInstruction",
            "transfer": "SplTokenTransferInstruction",
            "transferChecked": "SplTokenTransferCheckedInstruction",
        ][type]
    }
}
