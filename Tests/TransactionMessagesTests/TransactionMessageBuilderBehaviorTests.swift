import Addresses
import Foundation
import Instructions
import SolanaErrors
import TransactionMessages
import XCTest

final class TransactionMessageBuilderBehaviorTests: XCTestCase {
    func testCreatesEmptyLegacyAndV0Messages() {
        let legacy = createTransactionMessage(version: .legacy)
        let v0 = createTransactionMessage(version: .v0)

        XCTAssertEqual(legacy.version, .legacy)
        XCTAssertTrue(legacy.instructions.isEmpty)
        XCTAssertNil(legacy.feePayer)
        XCTAssertNil(legacy.lifetimeConstraint)
        XCTAssertNil(legacy.config)
        XCTAssertEqual(v0.version, .v0)
        XCTAssertTrue(v0.instructions.isEmpty)
        XCTAssertNil(v0.feePayer)
        XCTAssertNil(v0.lifetimeConstraint)
        XCTAssertNil(v0.config)
    }

    func testBlockhashLifetimeValidationRejectsOtherLifetimesAndInvalidTokens() throws {
        let nonceMessage = TransactionMessage(
            version: .v0,
            lifetimeConstraint: .nonce(NonceLifetimeConstraint(nonce: "abcd"))
        )
        let invalidBlockhash = TransactionMessage(
            version: .v0,
            lifetimeConstraint: .blockhash(
                BlockhashLifetimeConstraint(blockhash: "not a valid blockhash value", lastValidBlockHeight: 1234)
            )
        )
        let validBlockhash = TransactionMessage(
            version: .v0,
            lifetimeConstraint: .blockhash(
                BlockhashLifetimeConstraint(
                    blockhash: "11111111111111111111111111111111",
                    lastValidBlockHeight: 1234
                )
            )
        )

        XCTAssertThrowsError(try assertIsTransactionMessageWithBlockhashLifetime(createTransactionMessage(version: .v0))) { error in
            XCTAssertEqual(errorCode(error), SolanaErrorCode.transactionExpectedBlockhashLifetime.rawValue)
        }
        XCTAssertThrowsError(try assertIsTransactionMessageWithBlockhashLifetime(nonceMessage)) { error in
            XCTAssertEqual(errorCode(error), SolanaErrorCode.transactionExpectedBlockhashLifetime.rawValue)
        }
        XCTAssertThrowsError(try assertIsTransactionMessageWithBlockhashLifetime(invalidBlockhash)) { error in
            XCTAssertEqual(errorCode(error), SolanaErrorCode.transactionExpectedBlockhashLifetime.rawValue)
        }
        XCTAssertFalse(isTransactionMessageWithBlockhashLifetime(nonceMessage))
        XCTAssertFalse(isTransactionMessageWithBlockhashLifetime(invalidBlockhash))
        XCTAssertTrue(isTransactionMessageWithBlockhashLifetime(validBlockhash))
        XCTAssertNoThrow(try assertIsTransactionMessageWithBlockhashLifetime(validBlockhash))
    }

    func testFeePayerAndInstructionMutatorsPreserveOrdering() throws {
        let feePayerA = try address("7mvYAxeCui21xYkAyQSjh6iBVZPpgVyt7PYv9km8V5mE")
        let feePayerB = try address("5LHng8dLBxCYyR3jdDbobLiRQ6pR74pYtxKohY93RbZN")
        let programA = try address("AALQD2dt1k43Acrkp4SvdhZaN4S115Ff2Bi7rHPti3sL")
        let programB = try address("DNAbkMkoMLRXF7wuLCrTzouMyzi25krr3B94yW87VvxU")
        let programC = try address("6Bkt4j67rxzFF6s9DaMRyfitftRrGxe4oYHPRHuFChzi")
        let existing = Instruction(programAddress: programA)
        let first = Instruction(programAddress: programB)
        let second = Instruction(programAddress: programC)
        let base = TransactionMessage(version: .v0, instructions: [existing])

        let paid = setTransactionMessageFeePayer(feePayerA, base)
        let samePaid = setTransactionMessageFeePayer(feePayerA, paid)
        let changedPaid = setTransactionMessageFeePayer(feePayerB, paid)
        let appended = appendTransactionMessageInstructions([first, second], base)
        let prepended = prependTransactionMessageInstructions([first, second], base)

        XCTAssertEqual(paid.feePayer?.address, feePayerA)
        XCTAssertEqual(samePaid, paid)
        XCTAssertEqual(changedPaid.feePayer?.address, feePayerB)
        XCTAssertEqual(appended.instructions, [existing, first, second])
        XCTAssertEqual(prepended.instructions, [first, second, existing])
    }

    func testComputeBudgetInstructionsEncodeDiscriminatorsAndValues() throws {
        let limit = try getSetComputeUnitLimitInstruction(200_000)
        let price = getSetComputeUnitPriceInstruction(5_000)
        let largePrice = getSetComputeUnitPriceInstruction(1 << 63)
        let heap = try getRequestHeapFrameInstruction(256_000)
        let loaded = try getSetLoadedAccountsDataSizeLimitInstruction(64_000)

        XCTAssertEqual(limit.programAddress, computeBudgetProgramAddress)
        XCTAssertEqual(limit.data, Data([2, 0x40, 0x0d, 0x03, 0x00]))
        XCTAssertEqual(try getComputeUnitLimitFromInstructionData(try XCTUnwrap(limit.data)), 200_000)
        XCTAssertTrue(isSetComputeUnitLimitInstruction(limit))
        XCTAssertFalse(isSetComputeUnitPriceInstruction(limit))

        XCTAssertEqual(price.programAddress, computeBudgetProgramAddress)
        XCTAssertEqual(price.data, Data([3, 0x88, 0x13, 0, 0, 0, 0, 0, 0]))
        XCTAssertEqual(try getPriorityFeeFromInstructionData(try XCTUnwrap(price.data)), 5_000)
        XCTAssertEqual(try getPriorityFeeFromInstructionData(try XCTUnwrap(largePrice.data)), 1 << 63)
        XCTAssertTrue(isSetComputeUnitPriceInstruction(price))
        XCTAssertFalse(isSetComputeUnitLimitInstruction(price))

        XCTAssertEqual(heap.programAddress, computeBudgetProgramAddress)
        XCTAssertEqual(heap.data, Data([1, 0x00, 0xe8, 0x03, 0x00]))
        XCTAssertEqual(try getHeapSizeFromInstructionData(try XCTUnwrap(heap.data)), 256_000)
        XCTAssertTrue(isRequestHeapFrameInstruction(heap))
        XCTAssertFalse(isSetLoadedAccountsDataSizeLimitInstruction(heap))

        XCTAssertEqual(loaded.programAddress, computeBudgetProgramAddress)
        XCTAssertEqual(loaded.data, Data([4, 0x00, 0xfa, 0x00, 0x00]))
        XCTAssertEqual(try getLoadedAccountsDataSizeLimitFromInstructionData(try XCTUnwrap(loaded.data)), 64_000)
        XCTAssertTrue(isSetLoadedAccountsDataSizeLimitInstruction(loaded))
        XCTAssertFalse(isRequestHeapFrameInstruction(loaded))
    }

    func testLegacyAndV0ComputeBudgetSettersAppendReplaceAndRemove() throws {
        for version in [TransactionVersion.legacy, .v0] {
            let other = Instruction(programAddress: try address("11111111111111111111111111111111"))
            let base = TransactionMessage(version: version, instructions: [other])

            let withLimit = try setTransactionMessageComputeUnitLimit(200_000, base)
            XCTAssertEqual(withLimit.instructions.count, 2)
            XCTAssertEqual(withLimit.instructions[0], other)
            XCTAssertEqual(try getTransactionMessageComputeUnitLimit(withLimit), 200_000)
            XCTAssertEqual(try getTransactionMessageComputeUnitLimit(try setTransactionMessageComputeUnitLimit(400_000, withLimit)), 400_000)
            XCTAssertEqual(try setTransactionMessageComputeUnitLimit(nil, withLimit).instructions, [other])
            XCTAssertEqual(try setTransactionMessageComputeUnitLimit(nil, base), base)

            let withPrice = try setTransactionMessageComputeUnitPrice(5_000, base)
            XCTAssertEqual(withPrice.instructions.count, 2)
            XCTAssertEqual(withPrice.instructions[0], other)
            XCTAssertEqual(try getTransactionMessageComputeUnitPrice(withPrice), 5_000)
            XCTAssertEqual(try getTransactionMessageComputeUnitPrice(try setTransactionMessageComputeUnitPrice(10_000, withPrice)), 10_000)
            XCTAssertEqual(try setTransactionMessageComputeUnitPrice(nil, withPrice).instructions, [other])
            XCTAssertEqual(try setTransactionMessageComputeUnitPrice(nil, base), base)

            let withHeap = try setTransactionMessageHeapSize(30_000, base)
            XCTAssertEqual(withHeap.instructions.count, 2)
            XCTAssertEqual(withHeap.instructions[0], other)
            XCTAssertEqual(try getTransactionMessageHeapSize(withHeap), 30_000)
            XCTAssertEqual(try getTransactionMessageHeapSize(try setTransactionMessageHeapSize(50_000, withHeap)), 50_000)
            XCTAssertEqual(try setTransactionMessageHeapSize(nil, withHeap).instructions, [other])
            XCTAssertEqual(try setTransactionMessageHeapSize(nil, base), base)

            let withLoadedLimit = try setTransactionMessageLoadedAccountsDataSizeLimit(60_000, base)
            XCTAssertEqual(withLoadedLimit.instructions.count, 2)
            XCTAssertEqual(withLoadedLimit.instructions[0], other)
            XCTAssertEqual(try getTransactionMessageLoadedAccountsDataSizeLimit(withLoadedLimit), 60_000)
            XCTAssertEqual(
                try getTransactionMessageLoadedAccountsDataSizeLimit(
                    try setTransactionMessageLoadedAccountsDataSizeLimit(100_000, withLoadedLimit)
                ),
                100_000
            )
            XCTAssertEqual(try setTransactionMessageLoadedAccountsDataSizeLimit(nil, withLoadedLimit).instructions, [other])
            XCTAssertEqual(try setTransactionMessageLoadedAccountsDataSizeLimit(nil, base), base)
        }
    }

    func testV1ConfigSettersPreserveNormalizeAndReadValues() throws {
        let base = createTransactionMessage(version: .v1)
        let withLimit = try setTransactionMessageComputeUnitLimit(200_000, base)
        let withHeap = try setTransactionMessageHeapSize(30_000, withLimit)
        let withLoadedLimit = try setTransactionMessageLoadedAccountsDataSizeLimit(60_000, withHeap)
        let withPriorityFee = setTransactionMessagePriorityFeeLamports(5_000, withLoadedLimit)

        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(withPriorityFee), 200_000)
        XCTAssertEqual(try getTransactionMessageHeapSize(withPriorityFee), 30_000)
        XCTAssertEqual(try getTransactionMessageLoadedAccountsDataSizeLimit(withPriorityFee), 60_000)
        XCTAssertEqual(getTransactionMessagePriorityFeeLamports(withPriorityFee), 5_000)

        let withoutLimit = try setTransactionMessageComputeUnitLimit(nil, withPriorityFee)
        XCTAssertNil(try getTransactionMessageComputeUnitLimit(withoutLimit))
        XCTAssertEqual(try getTransactionMessageHeapSize(withoutLimit), 30_000)
        XCTAssertEqual(try getTransactionMessageLoadedAccountsDataSizeLimit(withoutLimit), 60_000)
        XCTAssertEqual(getTransactionMessagePriorityFeeLamports(withoutLimit), 5_000)

        let withoutAll = setTransactionMessagePriorityFeeLamports(
            nil,
            try setTransactionMessageLoadedAccountsDataSizeLimit(nil, try setTransactionMessageHeapSize(nil, withoutLimit))
        )
        XCTAssertNil(withoutAll.config)
    }

    func testDurableNonceValidationRejectsMalformedOrMismatchedInputs() throws {
        let nonceAccount = try address("DhezFECsqmzuDxeuitFChbghTrwKLdsKdVsGArYbFEtm")
        let nonceAuthority = try address("2KntmCrnaf63tpNb8UMFFjFGGnYYAKQdmW9SbuCiRvhM")
        let otherProgram = try address("32JTd9jz5xGuLegzVouXxfzAVTiJYWMLrg6p8RxbV5xc")
        let advance = createAdvanceNonceAccountInstruction(
            nonceAccountAddress: nonceAccount,
            nonceAuthorityAddress: nonceAuthority
        )
        let nonceConstraint = TransactionMessageLifetimeConstraint.nonce(NonceLifetimeConstraint(nonce: "123"))
        let malformedAccounts = Instruction(
            programAddress: try address("11111111111111111111111111111111"),
            accounts: [],
            data: Data([4, 0, 0, 0])
        )
        let wrongProgram = Instruction(programAddress: otherProgram, accounts: advance.accounts, data: advance.data)
        let wrongData = Instruction(
            programAddress: advance.programAddress,
            accounts: advance.accounts,
            data: Data([2, 0, 0, 0])
        )
        let writableAuthority = Instruction(
            programAddress: advance.programAddress,
            accounts: [
                .account(writableAccount(nonceAccount)),
                .account(readonlyAccount(try address("SysvarRecentB1ockHashes11111111111111111111"))),
                .account(writableSignerAccount(nonceAuthority)),
            ],
            data: Data([4, 0, 0, 0])
        )
        let valid = TransactionMessage(version: .v0, instructions: [writableAuthority], lifetimeConstraint: nonceConstraint)

        for message in [
            TransactionMessage(version: .v0, lifetimeConstraint: nonceConstraint),
            TransactionMessage(version: .v0, instructions: [wrongProgram], lifetimeConstraint: nonceConstraint),
            TransactionMessage(version: .v0, instructions: [wrongData], lifetimeConstraint: nonceConstraint),
            TransactionMessage(version: .v0, instructions: [malformedAccounts], lifetimeConstraint: nonceConstraint),
            TransactionMessage(version: .v0, instructions: [advance]),
            TransactionMessage(
                version: .v0,
                instructions: [advance],
                lifetimeConstraint: .blockhash(
                    BlockhashLifetimeConstraint(
                        blockhash: "11111111111111111111111111111111",
                        lastValidBlockHeight: 123
                    )
                )
            ),
        ] {
            XCTAssertFalse(isTransactionMessageWithDurableNonceLifetime(message))
            XCTAssertThrowsError(try assertIsTransactionMessageWithDurableNonceLifetime(message)) { error in
                XCTAssertEqual(errorCode(error), SolanaErrorCode.transactionExpectedNonceLifetime.rawValue)
            }
        }

        XCTAssertTrue(isTransactionMessageWithDurableNonceLifetime(valid))
        XCTAssertNoThrow(try assertIsTransactionMessageWithDurableNonceLifetime(valid))
    }

    func testDurableNonceSetterPrependsPreservesMatchingAndReplacesDifferentInstruction() throws {
        let nonceAccountA = try address("DhezFECsqmzuDxeuitFChbghTrwKLdsKdVsGArYbFEtm")
        let nonceAuthorityA = try address("2KntmCrnaf63tpNb8UMFFjFGGnYYAKQdmW9SbuCiRvhM")
        let nonceAccountB = try address("SysvarRent111111111111111111111111111111111")
        let nonceAuthorityB = try address("SysvarC1ock11111111111111111111111111111111")
        let other = Instruction(programAddress: try address("32JTd9jz5xGuLegzVouXxfzAVTiJYWMLrg6p8RxbV5xc"))
        let configA = DurableNonceConfig(
            nonce: "123",
            nonceAccountAddress: nonceAccountA,
            nonceAuthorityAddress: nonceAuthorityA
        )
        let base = TransactionMessage(version: .v0, instructions: [other])
        let advanceA = createAdvanceNonceAccountInstruction(
            nonceAccountAddress: nonceAccountA,
            nonceAuthorityAddress: nonceAuthorityA
        )
        let advanceB = createAdvanceNonceAccountInstruction(
            nonceAccountAddress: nonceAccountB,
            nonceAuthorityAddress: nonceAuthorityB
        )

        let withNonce = setTransactionMessageLifetimeUsingDurableNonce(configA, base)
        XCTAssertEqual(withNonce.instructions, [advanceA, other])
        XCTAssertEqual(withNonce.lifetimeConstraint, .nonce(NonceLifetimeConstraint(nonce: "123")))

        let matchingFirst = TransactionMessage(version: .v0, instructions: [advanceA, other])
        let withMatchingFirst = setTransactionMessageLifetimeUsingDurableNonce(configA, matchingFirst)
        XCTAssertEqual(withMatchingFirst.instructions, [advanceA, other])

        let withDifferentFirst = TransactionMessage(
            version: .v0,
            instructions: [advanceB, other],
            lifetimeConstraint: .nonce(NonceLifetimeConstraint(nonce: "456"))
        )
        let replaced = setTransactionMessageLifetimeUsingDurableNonce(configA, withDifferentFirst)
        XCTAssertEqual(replaced.instructions, [advanceA, other])
        XCTAssertEqual(replaced.lifetimeConstraint, .nonce(NonceLifetimeConstraint(nonce: "123")))

        let sameAgain = setTransactionMessageLifetimeUsingDurableNonce(configA, withNonce)
        XCTAssertEqual(sameAgain, withNonce)
    }

    func testLookupTableCompressionReplacesOnlyEligibleNonSignerAccounts() throws {
        let programA = try address("AALQD2dt1k43Acrkp4SvdhZaN4S115Ff2Bi7rHPti3sL")
        let accountA = try address("DhezFECsqmzuDxeuitFChbghTrwKLdsKdVsGArYbFEtm")
        let accountB = try address("2KntmCrnaf63tpNb8UMFFjFGGnYYAKQdmW9SbuCiRvhM")
        let signer = try address("G35QeFd4jpXWfRkuRKwn8g4vYrmn8DWJ5v88Kkpd8z1V")
        let lookupTableA = try address("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let lookupTableB = try address("AddressLookupTab1e1111111111111111111111111")
        let existingLookup = readonlyLookupAccount(address: accountB, addressIndex: 0, lookupTableAddress: lookupTableB)
        let message = appendTransactionMessageInstruction(
            Instruction(
                programAddress: programA,
                accounts: [
                    .account(readonlyAccount(accountA)),
                    .account(writableAccount(accountB)),
                    .account(readonlySignerAccount(signer)),
                    .lookup(existingLookup),
                ]
            ),
            createTransactionMessage(version: .v0)
        )

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [
                lookupTableA: [accountA],
                lookupTableB: [accountB],
            ]
        )

        XCTAssertEqual(
            compressed.instructions.first?.accounts,
            [
                .lookup(readonlyLookupAccount(address: accountA, addressIndex: 0, lookupTableAddress: lookupTableA)),
                .lookup(writableLookupAccount(address: accountB, addressIndex: 0, lookupTableAddress: lookupTableB)),
                .account(readonlySignerAccount(signer)),
                .lookup(existingLookup),
            ]
        )
    }

    func testLookupTableCompressionLeavesProgramAccountsUnchanged() throws {
        let programA = try address("AALQD2dt1k43Acrkp4SvdhZaN4S115Ff2Bi7rHPti3sL")
        let programB = try address("DNAbkMkoMLRXF7wuLCrTzouMyzi25krr3B94yW87VvxU")
        let lookupTable = try address("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let message = appendTransactionMessageInstructions(
            [
                Instruction(programAddress: programA, accounts: []),
                Instruction(programAddress: programB, accounts: [.account(readonlyAccount(programA))]),
            ],
            createTransactionMessage(version: .v0)
        )

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [lookupTable: [programA]]
        )

        XCTAssertEqual(compressed, message)
    }

    func testTransactionConfigMasksReadBitsAndRejectSplitPriorityFeeBits() {
        XCTAssertTrue(try transactionConfigMaskHasPriorityFee(0b11))
        XCTAssertTrue(try transactionConfigMaskHasPriorityFee(0b11111))
        XCTAssertFalse(try transactionConfigMaskHasPriorityFee(0b00))
        XCTAssertFalse(try transactionConfigMaskHasPriorityFee(0b11100))
        XCTAssertTrue(transactionConfigMaskHasComputeUnitLimit(0b100))
        XCTAssertTrue(transactionConfigMaskHasComputeUnitLimit(0b111))
        XCTAssertFalse(transactionConfigMaskHasComputeUnitLimit(0b11011))
        XCTAssertTrue(transactionConfigMaskHasLoadedAccountsDataSizeLimit(0b1000))
        XCTAssertTrue(transactionConfigMaskHasLoadedAccountsDataSizeLimit(0b1111))
        XCTAssertFalse(transactionConfigMaskHasLoadedAccountsDataSizeLimit(0b10111))
        XCTAssertTrue(transactionConfigMaskHasHeapSize(0b10000))
        XCTAssertTrue(transactionConfigMaskHasHeapSize(0b11111))
        XCTAssertFalse(transactionConfigMaskHasHeapSize(0b01111))

        for mask in [0b01, 0b10] {
            XCTAssertThrowsError(try transactionConfigMaskHasPriorityFee(mask)) { error in
                XCTAssertEqual(errorCode(error), SolanaErrorCode.transactionInvalidConfigMaskPriorityFeeBits.rawValue)
            }
        }
    }
}

private func errorCode(_ error: any Error) -> Int? {
    (error as? any SolanaErrorCoded)?.code
}
