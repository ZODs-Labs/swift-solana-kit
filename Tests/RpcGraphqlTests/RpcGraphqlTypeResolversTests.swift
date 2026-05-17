import XCTest
@testable import RpcGraphql

final class RpcGraphqlTypeResolversTests: XCTestCase {
    func testResolvesAccountTypeNamesFromParsedConfigs() {
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.accountTypeName(
                accountType: "lookupTable",
                programName: "address-lookup-table"
            ),
            "LookupTableAccount"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.accountTypeName(accountType: "clock", programName: "sysvar"),
            "SysvarClockAccount"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.accountTypeName(accountType: "mint", programName: "spl-token-2022"),
            "MintAccount"
        )
    }

    func testResolvesSplTokenExtensionTypeNames() {
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.splTokenExtensionTypeName("transferHookAccount"),
            "SplTokenExtensionTransferHookAccount"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.splTokenExtensionTypeName("unparseableExtension"),
            "SplTokenExtensionUnparseable"
        )
    }

    func testResolvesInstructionTypeNamesAcrossSupportedPrograms() {
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "address-lookup-table",
                instructionType: "extendLookupTable"
            ),
            "ExtendLookupTableInstruction"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "bpf-upgradeable-loader",
                instructionType: "deployWithMaxDataLen"
            ),
            "BpfUpgradeableLoaderDeployWithMaxDataLenInstruction"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "spl-associated-token-account",
                instructionType: "createIdempotent"
            ),
            "SplAssociatedTokenCreateIdempotentInstruction"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "spl-token-2022",
                instructionType: "initializeTransferFeeConfig"
            ),
            "SplTokenInitializeTransferFeeConfig"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "spl-token-2022",
                instructionType: "confidentialTransferWithSplitProofs"
            ),
            "SplTokenConfidentialTransferWithSplitProofs"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "spl-token-2022",
                instructionType: "initializeGroup"
            ),
            "SplTokenGroupInitializeGroup"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "spl-token-2022",
                instructionType: "initializeTokenMetadata"
            ),
            "SplTokenMetadataInitialize"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "stake",
                instructionType: "authorizeCheckedWithSeed"
            ),
            "StakeAuthorizeCheckedWithSeedInstruction"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "vote",
                instructionType: "compactUpdateVoteStateSwitch"
            ),
            "VoteCompactUpdateVoteStateSwitchInstruction"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.instructionTypeName(
                programName: "system",
                instructionType: "advanceNonceAccount"
            ),
            "AdvanceNonceAccountInstruction"
        )
    }

    func testIncludesScalarEnumResolverMaps() {
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.programAccountsMemcmpFilterAccountEncodingCases["BASE_64"],
            "base64"
        )
        XCTAssertEqual(
            RpcGraphqlTypeResolvers.splTokenDefaultAccountStateCases["FROZEN"],
            "frozen"
        )
    }
}
