import Addresses
import CodecsCore
import CodecsNumbers
import RpcTypes
import SolanaErrors
import XCTest

final class RpcTypesTests: XCTestCase {
    func testCommitmentComparatorOrdersByFinality() {
        XCTAssertLessThan(commitmentComparator(.processed, .confirmed), 0)
        XCTAssertLessThan(commitmentComparator(.confirmed, .finalized), 0)
        XCTAssertEqual(commitmentComparator(.finalized, .finalized), 0)
    }

    func testBlockhashValidationAndCodec() throws {
        let valid = "11111111111111111111111111111111"
        XCTAssertTrue(isBlockhash(valid))
        XCTAssertEqual(try blockhash(valid), valid)

        let encoded = try getBlockhashEncoder().encode(valid)
        XCTAssertEqual(encoded.count, 32)
        XCTAssertEqual(encoded, Data(repeating: 0, count: 32))
        XCTAssertEqual(try getBlockhashDecoder().decode(encoded), valid)

        let nonZero = "4wBqpZM9xaSheZzJSMawUHDgZ7miWfSsxmfVF5jJpYP"
        XCTAssertEqual(
            try getBlockhashCodec().encode(nonZero),
            Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        )
        XCTAssertEqual(
            try getBlockhashCodec().decode(Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34])),
            "4wBqpZM9xaSheZzJSMawUKKwhdpChKbZ5eu5ky4Vigw"
        )
    }

    func testBlockhashComparatorSortsBase58ValuesByLocaleRules() {
        let values = [
            "Ht1VrhoyhwMGMpBBi89BPdJp5R39Mu49suKx3A22W9Qs",
            "J9ZSLc9qPg3FR8UqfN6ae1QkVReUmnpLgQqFkGEPqmod",
            "6JYSQqSHY1E5JDwEfgWMieozqA1KCwiP2cH69to9eWKH",
            "7YR1xA7yzFAT4yQCsS4rpowjU1tsh5YUJd9hWMHRppcX",
            "7grJ9YUAEHxckLFqCY7fq8cM1UrragNSuPH1dvwJ8EEK",
            "AJBPNWCjVLwxff2eJynW56cMRCGmyU4y3vbuvtVdgVgb",
            "B8A2zUEDtJjR7nrokNUJYhgUQiwEBzC88rZc6WUE5ZeF",
            "BKggsVVp7yLmXtPuBDtC3FXBzvLyyye3Q2tFKUUGCHLj",
            "Ds72joawSKQ9nCDAAmGMKFiwiY6HR7PDzYDHDzZom3tj",
            "F1zKr4ZUYo5UAnH1fvYaD6R7ne137NYfS1r5HrCb8NpF",
        ]

        XCTAssertEqual(
            values.sorted(by: { getBlockhashComparator()($0, $1) < 0 }),
            [
                "6JYSQqSHY1E5JDwEfgWMieozqA1KCwiP2cH69to9eWKH",
                "7grJ9YUAEHxckLFqCY7fq8cM1UrragNSuPH1dvwJ8EEK",
                "7YR1xA7yzFAT4yQCsS4rpowjU1tsh5YUJd9hWMHRppcX",
                "AJBPNWCjVLwxff2eJynW56cMRCGmyU4y3vbuvtVdgVgb",
                "B8A2zUEDtJjR7nrokNUJYhgUQiwEBzC88rZc6WUE5ZeF",
                "BKggsVVp7yLmXtPuBDtC3FXBzvLyyye3Q2tFKUUGCHLj",
                "Ds72joawSKQ9nCDAAmGMKFiwiY6HR7PDzYDHDzZom3tj",
                "F1zKr4ZUYo5UAnH1fvYaD6R7ne137NYfS1r5HrCb8NpF",
                "Ht1VrhoyhwMGMpBBi89BPdJp5R39Mu49suKx3A22W9Qs",
                "J9ZSLc9qPg3FR8UqfN6ae1QkVReUmnpLgQqFkGEPqmod",
            ]
        )
    }

    func testLamportsAndSolCodecsShareU64WireFormat() throws {
        XCTAssertEqual(lamports(1_000_000_000), 1_000_000_000)
        XCTAssertEqual(try getDefaultLamportsEncoder().encode(1_000_000_000), Data([0, 202, 154, 59, 0, 0, 0, 0]))

        let oneSol = try sol("1")
        XCTAssertEqual(try solToLamports(oneSol), 1_000_000_000)
        XCTAssertEqual(try getSolEncoder().encode(oneSol), Data([0, 202, 154, 59, 0, 0, 0, 0]))
    }

    func testLamportsCodecsWrapCustomNumberCodecs() throws {
        let u16Lamports = getLamportsCodec(getU16Codec())

        XCTAssertEqual(try u16Lamports.encode(256), Data([0, 1]))
        XCTAssertEqual(try u16Lamports.decode(Data([0, 1])), 256)
        XCTAssertThrowsError(try u16Lamports.encode(UInt64(Int.max) + 1)) { error in
            XCTAssertEqual((error as? CodecsError)?.code, SolanaErrorCode.codecsNumberOutOfRange.rawValue)
        }
    }

    func testStringifiedValuesValidateNumericText() throws {
        XCTAssertTrue(isStringifiedBigInt("-12345678901234567890"))
        XCTAssertFalse(isStringifiedBigInt("12.5"))
        XCTAssertTrue(isStringifiedNumber("-42.1"))
        XCTAssertFalse(isStringifiedNumber("not-a-number"))

        XCTAssertThrowsError(try stringifiedBigInt("12.5")) { error in
            XCTAssertEqual((error as? SolanaError)?.code, SolanaErrorCode.malformedBigintString.rawValue)
        }
    }

    func testStringifiedBigIntValidationMatchesJavaScriptBigIntParsing() throws {
        for validValue in ["", " ", "+1", "-1", "0", "01", "0x10", "0X10", "0b10", "0B10", "0o10", "0O10"] {
            XCTAssertTrue(isStringifiedBigInt(validValue), validValue)
            XCTAssertNoThrow(try assertIsStringifiedBigInt(validValue), validValue)
        }

        for invalidValue in ["abc", "123a", "123.0", "123.5", "1e2", "Infinity", "NaN", "+0x10", "-0x10", "0x", "0b2", "0o8", "１２３"] {
            XCTAssertFalse(isStringifiedBigInt(invalidValue), invalidValue)
            XCTAssertThrowsError(try assertIsStringifiedBigInt(invalidValue), invalidValue) { error in
                XCTAssertEqual((error as? SolanaError)?.code, SolanaErrorCode.malformedBigintString.rawValue)
            }
        }
    }

    func testStringifiedNumberValidationMatchesJavaScriptNumberParsing() throws {
        for validValue in ["", " ", "-123", "123.0", "123.5", ".5", "+.5", "-.5", "1.", "1.e2", "1e2", "+Infinity", "-Infinity", "0x10", "0b10", "0o10"] {
            XCTAssertTrue(isStringifiedNumber(validValue), validValue)
            XCTAssertNoThrow(try assertIsStringifiedNumber(validValue), validValue)
        }

        for invalidValue in ["abc", "123a", "NaN", "infinity", ".", ".e2", "1e", "1e+", "+0x10", "-0x10", "0x", "0b2", "0o8", "１２３"] {
            XCTAssertFalse(isStringifiedNumber(invalidValue), invalidValue)
            XCTAssertThrowsError(try assertIsStringifiedNumber(invalidValue), invalidValue) { error in
                XCTAssertEqual((error as? SolanaError)?.code, SolanaErrorCode.malformedNumberString.rawValue)
            }
        }
    }

    func testEncodedDataResponsesUseArrayWireShape() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let base58 = Base58EncodedDataResponse("1111")
        let base64 = Base64EncodedDataResponse("AQID")
        let compressed = Base64EncodedZStdCompressedDataResponse("KLUv")

        XCTAssertEqual(String(data: try encoder.encode(base58), encoding: .utf8), "[\"1111\",\"base58\"]")
        XCTAssertEqual(String(data: try encoder.encode(base64), encoding: .utf8), "[\"AQID\",\"base64\"]")
        XCTAssertEqual(String(data: try encoder.encode(compressed), encoding: .utf8), "[\"KLUv\",\"base64+zstd\"]")

        XCTAssertEqual(
            try decoder.decode(Base64EncodedDataResponse.self, from: Data(#"["AQID","base64"]"#.utf8)),
            base64
        )
    }

    func testAccountInfoAndFilterModelsPreserveRpcShapes() throws {
        let owner = try address("11111111111111111111111111111111")
        let base = AccountInfoBase(executable: false, lamports: 5000, owner: owner, space: 165)
        let parsed = AccountInfoWithJsonData(
            data: .parsed(
                AccountInfoJsonParsedData(
                    parsed: AccountInfoParsedData(info: .object(["mint": .string(owner.rawValue)]), type: "account"),
                    program: "spl-token",
                    space: 165
                )
            )
        )
        let filter = GetProgramAccountsFilter.memcmp(
            GetProgramAccountsMemcmpFilter(
                memcmp: ProgramNotificationsMemcmpFilter(bytes: owner.rawValue, encoding: .base58, offset: 32)
            )
        )

        XCTAssertEqual(base.owner, owner)
        XCTAssertEqual(parsed.data, .parsed(AccountInfoJsonParsedData(parsed: AccountInfoParsedData(info: .object(["mint": .string(owner.rawValue)]), type: "account"), program: "spl-token", space: 165)))
        XCTAssertEqual(filter, .memcmp(GetProgramAccountsMemcmpFilter(memcmp: ProgramNotificationsMemcmpFilter(bytes: owner.rawValue, encoding: .base58, offset: 32))))
    }

    func testTransactionErrorAndMetaModelsRepresentRpcUnions() throws {
        let account = try address("11111111111111111111111111111111")
        let transactionError = RpcTransactionError.instructionError(index: 2, error: .custom(6000))
        let status = TransactionStatus.err(transactionError)
        let tokenAmount = TokenAmount(amount: "1", decimals: 0, uiAmount: 1, uiAmountString: "1")
        let balance = TokenBalance(accountIndex: 0, mint: account, uiTokenAmount: tokenAmount)
        let meta = TransactionForAccountsMetaBase(
            err: transactionError,
            fee: 5000,
            postBalances: [1],
            postTokenBalances: [balance],
            preBalances: [5001],
            status: status
        )
        let reward = Reward(lamports: -1, postBalance: 100, pubkey: account, rewardType: .fee)
        let fullMeta = TransactionForFullMetaBase(
            accountsMeta: meta,
            computeUnitsConsumed: 123,
            logMessages: ["Program log"],
            returnData: ReturnData(data: Base64EncodedDataResponse("AQID"), programId: account),
            rewards: [reward]
        )

        XCTAssertEqual(meta.status, .err(.instructionError(index: 2, error: .custom(6000))))
        XCTAssertEqual(fullMeta.fee, 5000)
        XCTAssertEqual(fullMeta.returnData?.data, Base64EncodedDataResponse("AQID"))
        XCTAssertEqual(fullMeta.rewards?.first?.rewardType, .fee)
        XCTAssertNil(fullMeta.rewards?.first?.commission)
        XCTAssertEqual(Reward(commission: 7, lamports: 2, postBalance: 101, pubkey: account, rewardType: .voting).commission, 7)
    }

    func testTransactionResponseModelsCoverAccountsAndFullEncodings() throws {
        let account = try address("11111111111111111111111111111111")
        let parsedAccount = TransactionParsedAccount(pubkey: account, signer: true, source: .transaction, writable: true)
        let meta = TransactionForAccountsMetaBase(
            err: nil,
            fee: 5000,
            postBalances: [10],
            preBalances: [5010],
            status: .ok
        )
        let header = TransactionMessageHeader(numReadonlySignedAccounts: 0, numReadonlyUnsignedAccounts: 1, numRequiredSignatures: 1)
        let messageBase = TransactionMessageBase(header: header, recentBlockhash: account.rawValue)
        let instruction = TransactionInstruction(accounts: [0], data: "1111", programIdIndex: 0, stackHeight: 1)
        let jsonMessage = TransactionForFullJsonMessage(accountKeys: [account], base: messageBase, instructions: [instruction])
        let jsonTransaction = TransactionForFullJsonTransaction(
            addressTableLookups: [RpcAddressTableLookup(accountKey: account, readonlyIndexes: [1], writableIndexes: [0])],
            message: jsonMessage,
            signatures: ["5"]
        )
        let accounts = TransactionForAccountsVersioned(
            meta: meta,
            transaction: TransactionForAccountsVersionedTransaction(accountKeys: [parsedAccount], signatures: ["5"]),
            version: .number(0)
        )
        let binary = TransactionForFullBase64Versioned(meta: nil, transaction: Base64EncodedDataResponse("AQID"), version: .number(0))
        let json = TransactionForFullJsonVersioned(meta: nil, transaction: jsonTransaction, version: .number(0))

        XCTAssertEqual(accounts.transaction.accountKeys.first?.source, .transaction)
        XCTAssertEqual(binary.transaction, Base64EncodedDataResponse("AQID"))
        XCTAssertEqual(json.transaction.addressTableLookups?.first?.readonlyIndexes, [1])
        XCTAssertEqual(json.transaction.message.addressTableLookups?.first?.writableIndexes, [0])
        XCTAssertEqual(json.transaction.message.base.header.numRequiredSignatures, 1)
    }

    func testFullTransactionMetaModelsIncludeInnerInstructionsAndLoadedAddresses() throws {
        let account = try address("11111111111111111111111111111111")
        let accountsMeta = TransactionForAccountsMetaBase(
            err: nil,
            fee: 5000,
            postBalances: [10],
            preBalances: [5010],
            status: .ok
        )
        let unparsedInstruction = TransactionInstruction(accounts: [0], data: "1111", programIdIndex: 0)
        let loadedAddresses = TransactionLoadedAddresses(readonly: [account], writable: [])
        let unparsedMeta = TransactionForFullUnparsedMeta(
            accountsMeta: accountsMeta,
            computeUnitsConsumed: 42,
            logMessages: nil,
            rewards: nil,
            innerInstructions: [
                TransactionForFullMetaInnerInstruction(index: 0, instructions: [unparsedInstruction]),
            ],
            loadedAddresses: loadedAddresses
        )

        XCTAssertEqual(unparsedMeta.innerInstructions.first?.instructions.first?.programIdIndex, 0)
        XCTAssertEqual(unparsedMeta.loadedAddresses?.readonly, [account])
        XCTAssertEqual(TransactionForFullBase64Versioned(meta: unparsedMeta, transaction: Base64EncodedDataResponse("AQID"), version: .number(0)).meta?.computeUnitsConsumed, 42)

        let parsedInstruction = ParsedTransactionInstruction(
            parsed: AccountInfoParsedData(type: "transfer"),
            program: "system",
            programId: account
        )
        let parsedMeta = TransactionForFullParsedMeta(
            accountsMeta: accountsMeta,
            logMessages: [],
            rewards: [],
            innerInstructions: [
                TransactionForFullMetaInnerInstruction(index: 1, instructions: [.parsed(parsedInstruction)]),
            ],
            loadedAddresses: loadedAddresses
        )

        XCTAssertEqual(parsedMeta.innerInstructions.first?.index, 1)
        XCTAssertEqual(TransactionForFullJsonParsedVersioned(meta: parsedMeta, transaction: TransactionForFullJsonParsedTransaction(message: TransactionForFullJsonParsedMessage(accountKeys: [], header: TransactionMessageHeader(numReadonlySignedAccounts: 0, numReadonlyUnsignedAccounts: 0, numRequiredSignatures: 0), instructions: [], recentBlockhash: account.rawValue), signatures: []), version: .number(0)).meta?.loadedAddresses?.readonly, [account])
    }
}
