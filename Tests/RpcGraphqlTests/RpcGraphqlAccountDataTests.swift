import XCTest
@testable import RpcGraphql

final class RpcGraphqlAccountDataTests: XCTestCase {
    func testSlicesBase64AccountData() throws {
        let account = RpcGraphqlAccountRecord(
            data: .encoded("AQIDBAUG", encoding: .base64),
            executable: nil,
            lamports: nil,
            owner: nil,
            space: nil,
            fields: [:]
        )

        let sliced = try RpcGraphqlAccountDataSlicer.slice(
            account,
            dataSlice: RpcGraphqlDataSlice(length: 2, offset: 2)
        )

        XCTAssertEqual(sliced?.data, .encoded("AwQ=", encoding: .base64))
    }

    func testDoesNotSliceBase64ZstdAccountData() throws {
        let account = RpcGraphqlAccountRecord(
            data: .encoded("opaque", encoding: .base64Zstd),
            executable: nil,
            lamports: nil,
            owner: nil,
            space: nil,
            fields: [:]
        )

        let sliced = try RpcGraphqlAccountDataSlicer.slice(
            account,
            dataSlice: RpcGraphqlDataSlice(length: 2, offset: 2)
        )

        XCTAssertEqual(sliced?.data, .encoded("opaque", encoding: .base64Zstd))
    }
}
