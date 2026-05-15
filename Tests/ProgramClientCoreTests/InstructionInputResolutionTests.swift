import Addresses
import Instructions
import ProgramClientCore
import Signers
import SolanaErrors
import XCTest

final class InstructionInputResolutionTests: XCTestCase {
    func testNonNullResolvedInstructionInputReturnsValue() throws {
        XCTAssertEqual(try getNonNullResolvedInstructionInput("mint", "value"), "value")
    }

    func testNonNullResolvedInstructionInputThrowsProgramClientError() {
        XCTAssertThrowsError(try getNonNullResolvedInstructionInput("mint", Optional<String>.none)) { error in
            guard let solanaError = error as? SolanaError else {
                return XCTFail("Expected SolanaError")
            }
            XCTAssertEqual(solanaError.solanaCode, .programClientsResolvedInstructionInputMustBeNonNull)
            XCTAssertEqual(solanaError.context["inputName"], .string("mint"))
        }
    }

    func testAddressExtractionSupportsAddressPdaAndSigner() throws {
        let address = try Address("11111111111111111111111111111111")
        let bump = try ProgramDerivedAddressBump(255)
        let signer = NoopSigner(address: address).transactionSigner

        XCTAssertEqual(
            try getAddressFromResolvedInstructionAccount("address", .address(address)),
            address
        )
        XCTAssertEqual(
            try getAddressFromResolvedInstructionAccount(
                "pda",
                .programDerivedAddress(ProgramDerivedAddress(address: address, bump: bump))
            ),
            address
        )
        XCTAssertEqual(
            try getAddressFromResolvedInstructionAccount("signer", .transactionSigner(signer)),
            address
        )
    }

    func testPdaAndSignerExtractionRejectWrongTypes() throws {
        let address = try Address("11111111111111111111111111111111")
        let signer = NoopSigner(address: address).transactionSigner

        XCTAssertThrowsError(try getResolvedInstructionAccountAsProgramDerivedAddress("mint", .transactionSigner(signer))) { error in
            guard let solanaError = error as? SolanaError else {
                return XCTFail("Expected SolanaError")
            }
            XCTAssertEqual(solanaError.solanaCode, .programClientsUnexpectedResolvedInstructionInputType)
            XCTAssertEqual(solanaError.context["expectedType"], .string("ProgramDerivedAddress"))
        }

        XCTAssertThrowsError(try getResolvedInstructionAccountAsTransactionSigner("mint", .address(address))) { error in
            guard let solanaError = error as? SolanaError else {
                return XCTFail("Expected SolanaError")
            }
            XCTAssertEqual(solanaError.solanaCode, .programClientsUnexpectedResolvedInstructionInputType)
            XCTAssertEqual(solanaError.context["expectedType"], .string("TransactionSigner"))
        }
    }

    func testAccountMetaFactoryHandlesRolesAndOptionalAccounts() throws {
        let programAddress = try Address("11111111111111111111111111111111")
        let signerAddress = programAddress
        let signer = NoopSigner(address: signerAddress).transactionSigner
        let factory = getAccountMetaFactory(programAddress: programAddress, optionalAccountStrategy: .programID)

        let readonly = try factory("authority", ResolvedInstructionAccount(isWritable: false, value: .address(programAddress)))
        XCTAssertEqual(readonly?.address, programAddress)
        XCTAssertEqual(readonly?.role, .readonly)

        let writableSigner = try factory("authority", ResolvedInstructionAccount(isWritable: true, value: .transactionSigner(signer)))
        XCTAssertEqual(writableSigner?.address, signerAddress)
        XCTAssertEqual(writableSigner?.role, .writableSigner)
        XCTAssertNotNil(writableSigner?.signer)

        let optional = try factory("optional", ResolvedInstructionAccount(isWritable: true, value: nil))
        XCTAssertEqual(optional?.address, programAddress)
        XCTAssertEqual(optional?.role, .readonly)
    }

    func testAccountMetaFactoryOmitStrategyReturnsNilForMissingOptionalAccount() throws {
        let programAddress = try Address("11111111111111111111111111111111")
        let factory = getAccountMetaFactory(programAddress: programAddress, optionalAccountStrategy: .omitted)

        let meta = try factory("optional", ResolvedInstructionAccount(isWritable: false, value: nil))

        XCTAssertNil(meta)
    }
}
