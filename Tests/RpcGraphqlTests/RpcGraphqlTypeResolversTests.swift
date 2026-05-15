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
