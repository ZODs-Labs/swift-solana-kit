import XCTest
@testable import RpcGraphql

final class RpcGraphqlSchemaTests: XCTestCase {
    func testSchemaIncludesFullAccountAndInstructionSurfaces() {
        let typeDefs = RpcGraphqlSchema.createSolanaGraphqlTypeDefs().joined(separator: "\n")

        XCTAssertTrue(typeDefs.contains("interface SplTokenExtension"))
        XCTAssertTrue(typeDefs.contains("type SplTokenExtensionConfidentialTransferAccount implements SplTokenExtension"))
        XCTAssertTrue(typeDefs.contains("type LookupTableAccount implements Account"))
        XCTAssertTrue(typeDefs.contains("type SysvarEpochRewardsAccount implements Account"))
        XCTAssertTrue(typeDefs.contains("type CreateLookupTableInstruction implements TransactionInstruction"))
        XCTAssertTrue(typeDefs.contains("type SplTokenTransferCheckedInstruction implements TransactionInstruction"))
    }

    func testSchemaIncludesFullTransactionSupportTypes() {
        let typeDefs = RpcGraphqlSchema.createSolanaGraphqlTypeDefs().joined(separator: "\n")

        XCTAssertTrue(typeDefs.contains("type TransactionStatusOk"))
        XCTAssertTrue(typeDefs.contains("union TransactionStatus = TransactionStatusOk | TransactionStatusErr"))
        XCTAssertTrue(typeDefs.contains("type TransactionLoadedAddresses"))
        XCTAssertTrue(typeDefs.contains("type TransactionMessageHeader"))
        XCTAssertTrue(typeDefs.contains("type ReturnData"))
        XCTAssertTrue(typeDefs.contains("type Reward"))
    }
}
