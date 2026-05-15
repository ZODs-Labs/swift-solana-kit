import XCTest
@testable import RpcGraphql

final class RpcGraphqlResolveInfoPlannerTests: XCTestCase {
    func testAccountAddressOnlyDoesNotBuildLoaderArguments() {
        let info = RpcGraphqlResolveInfo(selections: [
            .field(name: "address", arguments: [:], selections: []),
        ])

        let arguments = RpcGraphqlResolvers.accountLoaderArguments(
            address: "AyGCwnwxQMCqaU4ixReHt8h5W4dwmxU7eM3BEQBdWVca",
            info: info
        )

        XCTAssertTrue(arguments.isEmpty)
    }

    func testAccountInlineFragmentRequestsJsonParsed() {
        let info = RpcGraphqlResolveInfo(selections: [
            .inlineFragment(typeCondition: "MintAccount", selections: [
                .field(name: "supply", arguments: [:], selections: []),
            ]),
        ])

        let arguments = RpcGraphqlResolvers.accountLoaderArguments(
            address: "AyGCwnwxQMCqaU4ixReHt8h5W4dwmxU7eM3BEQBdWVca",
            info: info
        )

        XCTAssertEqual(arguments.map(\.encoding), [nil, .jsonParsed])
    }

    func testAccountDataFieldMapsEncodingAndSlice() {
        let info = RpcGraphqlResolveInfo(selections: [
            .field(
                name: "data",
                arguments: [
                    "dataSlice": .object([
                        "length": .int(8),
                        "offset": .int(4),
                    ]),
                    "encoding": .enumCase("BASE_64"),
                ],
                selections: []
            ),
        ])

        let arguments = RpcGraphqlResolvers.accountLoaderArguments(
            address: "AyGCwnwxQMCqaU4ixReHt8h5W4dwmxU7eM3BEQBdWVca",
            info: info
        )

        XCTAssertEqual(arguments.count, 2)
        XCTAssertEqual(arguments[1].encoding, .base64)
        XCTAssertEqual(arguments[1].dataSlice, RpcGraphqlDataSlice(length: 8, offset: 4))
    }

    func testTransactionMessageRequestsJsonParsed() {
        let info = RpcGraphqlResolveInfo(selections: [
            .field(name: "message", arguments: [:], selections: [
                .field(name: "instructions", arguments: [:], selections: []),
            ]),
        ])

        let arguments = RpcGraphqlResolvers.transactionLoaderArguments(
            signature: "67rSZV97NzE4B4ZeFqULqWZcNEV2KwNfDLMzecJmBheZ4sWhudqGAzypoBCKfeLkKtDQBGnkwgdrrFM8ZMaS3pkk",
            info: info
        )

        XCTAssertEqual(arguments.map(\.encoding), [nil, .jsonParsed])
    }

    func testBlockTransactionsReuseTransactionPlanner() {
        let info = RpcGraphqlResolveInfo(selections: [
            .field(name: "transactions", arguments: [:], selections: [
                .field(name: "data", arguments: ["encoding": .enumCase("BASE_58")], selections: []),
            ]),
        ])

        let arguments = RpcGraphqlResolvers.blockLoaderArguments(slot: 511_226, info: info)

        XCTAssertEqual(arguments.count, 3)
        XCTAssertEqual(arguments[1].transactionDetails, .full)
        XCTAssertEqual(arguments[2].transactionDetails, .full)
        XCTAssertEqual(arguments[2].encoding, .base58)
        XCTAssertEqual(arguments[1].maxSupportedTransactionVersion, 0)
    }
}
