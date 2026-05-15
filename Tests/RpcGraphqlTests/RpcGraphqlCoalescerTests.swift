import XCTest
@testable import RpcGraphql

final class RpcGraphqlCoalescerTests: XCTestCase {
    func testCoalescesOrphanAccountFetchIntoBase64Request() {
        let address = "Gh9ZwEmdLJ8DscKNTkTqPbNwLNNBjuSzaG9Vp2KGtKJr"
        let requests = [
            RpcGraphqlLoadRequest(
                key: address,
                arguments: RpcGraphqlAccountLoaderArguments(
                    address: address,
                    commitment: .confirmed,
                    dataSlice: nil,
                    encoding: nil,
                    minContextSlot: nil
                )
            ),
            RpcGraphqlLoadRequest(
                key: address,
                arguments: RpcGraphqlAccountLoaderArguments(
                    address: address,
                    commitment: .confirmed,
                    dataSlice: nil,
                    encoding: .base58,
                    minContextSlot: nil
                )
            ),
        ]

        let fetches = RpcGraphqlCoalescer.coalesceDataSlices(requests, maxDataSliceByteRange: 200)

        XCTAssertEqual(fetches.count, 1)
        XCTAssertEqual(fetches[0].arguments.encoding, .base58)
        XCTAssertEqual(fetches[0].callbacksByKey[address]?.map(\.requestIndex), [1, 0])
    }

    func testDataSlicesMergeWhenWastedBytesStayInsideLimit() {
        let address = "Gh9ZwEmdLJ8DscKNTkTqPbNwLNNBjuSzaG9Vp2KGtKJr"
        let requests = [
            RpcGraphqlLoadRequest(
                key: address,
                arguments: RpcGraphqlAccountLoaderArguments(
                    address: address,
                    commitment: .confirmed,
                    dataSlice: RpcGraphqlDataSlice(length: 4, offset: 4),
                    encoding: .base64,
                    minContextSlot: nil
                )
            ),
            RpcGraphqlLoadRequest(
                key: address,
                arguments: RpcGraphqlAccountLoaderArguments(
                    address: address,
                    commitment: .confirmed,
                    dataSlice: RpcGraphqlDataSlice(length: 8, offset: 0),
                    encoding: .base64,
                    minContextSlot: nil
                )
            ),
        ]

        let fetches = RpcGraphqlCoalescer.coalesceDataSlices(requests, maxDataSliceByteRange: 200)

        XCTAssertEqual(fetches.count, 1)
        XCTAssertEqual(fetches[0].arguments.dataSlice, RpcGraphqlDataSlice(length: 8, offset: 0))
        XCTAssertEqual(fetches[0].callbacksByKey[address]?.map(\.requestIndex), [0, 1])
    }

    func testTransactionOrphanUsesBase64Default() {
        let signature = "67rSZV97NzE4B4ZeFqULqWZcNEV2KwNfDLMzecJmBheZ4sWhudqGAzypoBCKfeLkKtDQBGnkwgdrrFM8ZMaS3pkk"
        let requests = [
            RpcGraphqlLoadRequest(
                key: signature,
                arguments: RpcGraphqlTransactionLoaderArguments(
                    signature: signature,
                    commitment: .confirmed,
                    encoding: nil
                )
            ),
        ]

        let fetches = RpcGraphqlCoalescer.coalesce(
            requests,
            orphanCriteria: { $0.encoding == nil },
            orphanDefaults: { $0.withDefaultEncoding("base64") },
            orphanHashOmit: ["encoding"]
        )

        XCTAssertEqual(fetches.count, 1)
        XCTAssertEqual(fetches[0].arguments.encoding, .base64)
        XCTAssertEqual(fetches[0].callbacksByKey[signature], [0])
    }
}
