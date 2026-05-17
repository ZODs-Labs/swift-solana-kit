import Addresses
import Foundation
import Instructions
import SolanaErrors
import TransactionMessages
import XCTest

final class TransactionMessageRuntimeCoverageTests: XCTestCase {
    func testBlockhashSetterReplacesOnlyLifetimeAndPreservesMessageFields() throws {
        let feePayer = try txAddress("7mvYAxeCui21xYkAyQSjh6iBVZPpgVyt7PYv9km8V5mE")
        let program = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let instruction = Instruction(programAddress: program, data: Data([1]))
        let config = V1TransactionConfig(computeUnitLimit: 400)
        let base = TransactionMessage(
            version: .v1,
            instructions: [instruction],
            feePayer: TransactionMessageFeePayer(address: feePayer),
            lifetimeConstraint: .nonce(NonceLifetimeConstraint(nonce: "nonce")),
            config: config
        )
        let first = BlockhashLifetimeConstraint(
            blockhash: "11111111111111111111111111111111",
            lastValidBlockHeight: 10
        )
        let second = BlockhashLifetimeConstraint(
            blockhash: "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi",
            lastValidBlockHeight: 20
        )

        let withFirst = setTransactionMessageLifetimeUsingBlockhash(first, base)
        let same = setTransactionMessageLifetimeUsingBlockhash(first, withFirst)
        let changed = setTransactionMessageLifetimeUsingBlockhash(second, withFirst)

        XCTAssertEqual(withFirst.version, .v1)
        XCTAssertEqual(withFirst.instructions, [instruction])
        XCTAssertEqual(withFirst.feePayer?.address, feePayer)
        XCTAssertEqual(withFirst.config, config)
        XCTAssertEqual(withFirst.lifetimeConstraint, .blockhash(first))
        XCTAssertEqual(same, withFirst)
        XCTAssertEqual(changed.lifetimeConstraint, .blockhash(second))
    }

    func testInstructionMutatorsAppendAndPrependSingleAndManyInstructions() throws {
        let first = Instruction(programAddress: try txAddress("11111111111111111111111111111111"), data: Data([1]))
        let second = Instruction(programAddress: try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr"), data: Data([2]))
        let third = Instruction(programAddress: try txAddress("SysvarRent111111111111111111111111111111111"), data: Data([3]))
        let base = TransactionMessage(
            version: .legacy,
            instructions: [first],
            feePayer: TransactionMessageFeePayer(address: try txAddress("7mvYAxeCui21xYkAyQSjh6iBVZPpgVyt7PYv9km8V5mE"))
        )

        XCTAssertEqual(appendTransactionMessageInstruction(second, base).instructions, [first, second])
        XCTAssertEqual(appendTransactionMessageInstructions([second, third], base).instructions, [first, second, third])
        XCTAssertEqual(prependTransactionMessageInstruction(second, base).instructions, [second, first])
        XCTAssertEqual(prependTransactionMessageInstructions([second, third], base).instructions, [second, third, first])
    }

    func testLookupTableCompressionReplacesReadonlyAndWritableNonSigners() throws {
        let program = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let readonly = try txAddress("SysvarRent111111111111111111111111111111111")
        let writable = try txAddress("SysvarC1ock11111111111111111111111111111111")
        let table = try txAddress("AddressLookupTab1e1111111111111111111111111")
        let message = TransactionMessage(
            version: .v0,
            instructions: [
                Instruction(
                    programAddress: program,
                    accounts: [.account(readonlyAccount(readonly)), .account(writableAccount(writable))]
                ),
            ]
        )

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [table: [readonly, writable]]
        )

        XCTAssertEqual(compressed.instructions.count, 1)
        guard let accounts = compressed.instructions.first?.accounts else {
            return XCTFail("Expected accounts")
        }
        XCTAssertEqual(accounts, [
            .lookup(readonlyLookupAccount(address: readonly, addressIndex: 0, lookupTableAddress: table)),
            .lookup(writableLookupAccount(address: writable, addressIndex: 1, lookupTableAddress: table)),
        ])
    }

    func testLookupTableCompressionSkipsSignersExistingLookupsAndProgramAddresses() throws {
        let program = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let signer = try txAddress("SysvarRent111111111111111111111111111111111")
        let existing = try txAddress("SysvarC1ock11111111111111111111111111111111")
        let table = try txAddress("AddressLookupTab1e1111111111111111111111111")
        let originalLookup = readonlyLookupAccount(address: existing, addressIndex: 0, lookupTableAddress: table)
        let message = TransactionMessage(
            version: .v0,
            instructions: [
                Instruction(
                    programAddress: program,
                    accounts: [
                        .account(readonlySignerAccount(signer)),
                        .account(writableSignerAccount(signer)),
                        .lookup(originalLookup),
                        .account(readonlyAccount(program)),
                    ]
                ),
            ]
        )

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [table: [signer, existing, program]]
        )

        XCTAssertEqual(compressed, message)
    }

    func testLookupTableCompressionUsesFirstMatchingLookupTableAndKeepsInputInstructionWhenNoAccountsChange() throws {
        let program = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let account = try txAddress("SysvarRent111111111111111111111111111111111")
        let unrelated = try txAddress("SysvarC1ock11111111111111111111111111111111")
        let firstTable = try txAddress("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let secondTable = try txAddress("AddressLookupTab1e1111111111111111111111111")
        let instruction = Instruction(programAddress: program, accounts: [.account(readonlyAccount(account))])
        let base = TransactionMessage(version: .v0, instructions: [instruction, Instruction(programAddress: unrelated)])

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            base,
            addressesByLookupTableAddress: [
                firstTable: [account],
                secondTable: [account],
            ]
        )
        let noChanges = compressTransactionMessageUsingAddressLookupTables(
            base,
            addressesByLookupTableAddress: [secondTable: [unrelated]]
        )

        XCTAssertEqual(noChanges, base)
        guard case let .lookup(meta)? = compressed.instructions.first?.accounts?.first else {
            return XCTFail("Expected lookup account")
        }
        XCTAssertEqual(meta.lookupTableAddress, firstTable)
        XCTAssertEqual(compressed.instructions[1], base.instructions[1])
    }

    func testLookupTableCompressionReplacesSameAccountAcrossInstructions() throws {
        let program = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let account = try txAddress("SysvarRent111111111111111111111111111111111")
        let table = try txAddress("AddressLookupTab1e1111111111111111111111111")
        let message = TransactionMessage(
            version: .v0,
            instructions: [
                Instruction(programAddress: program, accounts: [.account(readonlyAccount(account))]),
                Instruction(programAddress: program, accounts: [.account(readonlyAccount(account))]),
            ]
        )

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [table: [account]]
        )
        let expected = InstructionAccount.lookup(
            readonlyLookupAccount(address: account, addressIndex: 0, lookupTableAddress: table)
        )

        XCTAssertEqual(compressed.instructions[0].accounts, [expected])
        XCTAssertEqual(compressed.instructions[1].accounts, [expected])
    }

    func testLookupTableCompressionKeepsLookupTableIndexesPerAddressList() throws {
        let program = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let firstAddress = try txAddress("SysvarRent111111111111111111111111111111111")
        let secondAddress = try txAddress("SysvarC1ock11111111111111111111111111111111")
        let skippedAddress = try txAddress("DhezFECsqmzuDxeuitFChbghTrwKLdsKdVsGArYbFEtm")
        let firstTable = try txAddress("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let secondTable = try txAddress("AddressLookupTab1e1111111111111111111111111")
        let message = TransactionMessage(
            version: .v0,
            instructions: [
                Instruction(
                    programAddress: program,
                    accounts: [
                        .account(readonlyAccount(firstAddress)),
                        .account(writableAccount(secondAddress)),
                    ]
                ),
            ]
        )

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [
                firstTable: [skippedAddress, firstAddress],
                secondTable: [skippedAddress, skippedAddress, secondAddress],
            ]
        )

        XCTAssertEqual(compressed.instructions.first?.accounts, [
            .lookup(readonlyLookupAccount(address: firstAddress, addressIndex: 1, lookupTableAddress: firstTable)),
            .lookup(writableLookupAccount(address: secondAddress, addressIndex: 2, lookupTableAddress: secondTable)),
        ])
    }

    func testComputeBudgetInstructionsUseExactDiscriminatorsAndLittleEndianValues() throws {
        let limit = try getSetComputeUnitLimitInstruction(200_000)
        let price = getSetComputeUnitPriceInstruction(UInt64.max)
        let heap = try getRequestHeapFrameInstruction(256_000)
        let loaded = try getSetLoadedAccountsDataSizeLimitInstruction(64_000)

        XCTAssertEqual(limit.programAddress, computeBudgetProgramAddress)
        XCTAssertEqual(limit.data, Data([2, 0x40, 0x0d, 0x03, 0x00]))
        XCTAssertTrue(isSetComputeUnitLimitInstruction(limit))
        XCTAssertFalse(isSetComputeUnitLimitInstruction(Instruction(programAddress: computeBudgetProgramAddress, data: Data([2]))))

        XCTAssertEqual(price.data, Data([3, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]))
        XCTAssertEqual(try getPriorityFeeFromInstructionData(try XCTUnwrap(price.data)), UInt64.max)
        XCTAssertTrue(isSetComputeUnitPriceInstruction(price))
        XCTAssertFalse(isSetComputeUnitPriceInstruction(limit))

        XCTAssertEqual(heap.data, Data([1, 0x00, 0xe8, 0x03, 0x00]))
        XCTAssertTrue(isRequestHeapFrameInstruction(heap))
        XCTAssertFalse(isRequestHeapFrameInstruction(loaded))

        XCTAssertEqual(loaded.data, Data([4, 0x00, 0xfa, 0x00, 0x00]))
        XCTAssertTrue(isSetLoadedAccountsDataSizeLimitInstruction(loaded))
        XCTAssertFalse(isSetLoadedAccountsDataSizeLimitInstruction(heap))
    }

    func testComputeUnitPriceInstructionEncodesZeroAndLargeValues() throws {
        let zero = getSetComputeUnitPriceInstruction(0)
        let large = getSetComputeUnitPriceInstruction(0xab_cd_ef_01_23_45_67_89)

        XCTAssertEqual(zero.data, Data([3, 0, 0, 0, 0, 0, 0, 0, 0]))
        XCTAssertEqual(try getPriorityFeeFromInstructionData(try XCTUnwrap(zero.data)), 0)
        XCTAssertEqual(large.data, Data([3, 0x89, 0x67, 0x45, 0x23, 0x01, 0xef, 0xcd, 0xab]))
        XCTAssertEqual(try getPriorityFeeFromInstructionData(try XCTUnwrap(large.data)), 0xab_cd_ef_01_23_45_67_89)
    }

    func testComputeBudgetPredicatesRejectWrongProgramDiscriminatorAndLength() throws {
        let otherProgram = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let limitBytes = Data([2, 0x40, 0x0d, 0x03, 0x00])
        let wrongProgram = Instruction(programAddress: otherProgram, data: limitBytes)
        let wrongDiscriminator = Instruction(programAddress: computeBudgetProgramAddress, data: Data([3, 0x40, 0x0d, 0x03, 0x00]))
        let wrongLength = Instruction(programAddress: computeBudgetProgramAddress, data: Data([2, 0x40, 0x0d, 0x03]))

        XCTAssertFalse(isSetComputeUnitLimitInstruction(wrongProgram))
        XCTAssertFalse(isSetComputeUnitLimitInstruction(wrongDiscriminator))
        XCTAssertFalse(isSetComputeUnitLimitInstruction(wrongLength))
        XCTAssertFalse(isSetComputeUnitPriceInstruction(Instruction(programAddress: computeBudgetProgramAddress, data: Data([3]))))
        XCTAssertFalse(isRequestHeapFrameInstruction(Instruction(programAddress: computeBudgetProgramAddress, data: Data([1, 0, 0, 0]))))
        XCTAssertFalse(isSetLoadedAccountsDataSizeLimitInstruction(Instruction(programAddress: otherProgram, data: Data([4, 0, 0, 0, 0]))))
    }

    func testLegacyComputeBudgetSettersAppendReplaceRemoveAndReadValues() throws {
        let program = try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let other = Instruction(programAddress: program, data: Data([9]))
        let base = TransactionMessage(version: .legacy, instructions: [other])

        let withLimit = try setTransactionMessageComputeUnitLimit(200_000, base)
        XCTAssertEqual(withLimit.instructions[0], other)
        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(withLimit), 200_000)
        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(try setTransactionMessageComputeUnitLimit(400_000, withLimit)), 400_000)
        XCTAssertEqual(try setTransactionMessageComputeUnitLimit(nil, withLimit).instructions, [other])
        XCTAssertEqual(try setTransactionMessageComputeUnitLimit(nil, base), base)

        let withHeap = try setTransactionMessageHeapSize(256_000, base)
        XCTAssertEqual(try getTransactionMessageHeapSize(withHeap), 256_000)
        XCTAssertEqual(try setTransactionMessageHeapSize(nil, withHeap).instructions, [other])

        let withLoaded = try setTransactionMessageLoadedAccountsDataSizeLimit(64_000, base)
        XCTAssertEqual(try getTransactionMessageLoadedAccountsDataSizeLimit(withLoaded), 64_000)
        XCTAssertEqual(try setTransactionMessageLoadedAccountsDataSizeLimit(nil, withLoaded).instructions, [other])

        let withPrice = try setTransactionMessageComputeUnitPrice(5_000, base)
        XCTAssertEqual(try getTransactionMessageComputeUnitPrice(withPrice), 5_000)
        XCTAssertEqual(try setTransactionMessageComputeUnitPrice(nil, withPrice).instructions, [other])
    }

    func testV1ComputeBudgetSettersUpdateConfigWithoutAddingInstructions() throws {
        let base = TransactionMessage(
            version: .v1,
            instructions: [Instruction(programAddress: try txAddress("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr"))]
        )

        let configured = setTransactionMessagePriorityFeeLamports(
            50,
            try setTransactionMessageLoadedAccountsDataSizeLimit(
                64_000,
                try setTransactionMessageHeapSize(256_000, try setTransactionMessageComputeUnitLimit(200_000, base))
            )
        )
        XCTAssertEqual(configured.instructions, base.instructions)
        XCTAssertEqual(configured.config, V1TransactionConfig(
            computeUnitLimit: 200_000,
            heapSize: 256_000,
            loadedAccountsDataSizeLimit: 64_000,
            priorityFeeLamports: 50
        ))

        let removed = setTransactionMessagePriorityFeeLamports(
            nil,
            try setTransactionMessageLoadedAccountsDataSizeLimit(nil, try setTransactionMessageHeapSize(nil, try setTransactionMessageComputeUnitLimit(nil, configured)))
        )
        XCTAssertNil(removed.config)
        XCTAssertEqual(removed.instructions, base.instructions)
    }

    func testTransactionConfigMergePatchMaskAndValuesUseStableBitOrder() {
        let complete = V1TransactionConfig(
            computeUnitLimit: 200_000,
            heapSize: 256_000,
            loadedAccountsDataSizeLimit: 64_000,
            priorityFeeLamports: 1_000
        )
        let partial = V1TransactionConfig(computeUnitLimit: 200_000, priorityFeeLamports: 1_000)
        let base = setTransactionMessageConfig(complete, createTransactionMessage(version: .v1))

        XCTAssertEqual(getTransactionConfigMask(complete), 0b11111)
        XCTAssertEqual(getTransactionConfigMask(partial), 0b00111)
        XCTAssertEqual(getTransactionConfigValues(complete), [.u64(1_000), .u32(200_000), .u32(64_000), .u32(256_000)])
        XCTAssertEqual(setTransactionMessageConfig(V1TransactionConfig(), createTransactionMessage(version: .v1)).config, nil)
        XCTAssertEqual(
            setTransactionMessageConfig(
                V1TransactionConfigPatch(computeUnitLimit: .remove, heapSize: .set(128_000)),
                base
            ).config,
            V1TransactionConfig(heapSize: 128_000, loadedAccountsDataSizeLimit: 64_000, priorityFeeLamports: 1_000)
        )
    }

    func testTransactionConfigMaskPredicatesCoverPriorityFeeEncodingRules() throws {
        XCTAssertTrue(try transactionConfigMaskHasPriorityFee(0b11))
        XCTAssertTrue(try transactionConfigMaskHasPriorityFee(0b11111))
        XCTAssertFalse(try transactionConfigMaskHasPriorityFee(0b00))
        XCTAssertFalse(try transactionConfigMaskHasPriorityFee(0b11100))

        for mask in [0b01, 0b10] {
            XCTAssertThrowsError(try transactionConfigMaskHasPriorityFee(mask)) { error in
                guard let solanaError = error as? SolanaError else {
                    return XCTFail("Expected SolanaError")
                }
                XCTAssertEqual(solanaError.solanaCode, .transactionInvalidConfigMaskPriorityFeeBits)
                XCTAssertEqual(solanaError.context["mask"], .int(mask))
            }
        }

        XCTAssertTrue(transactionConfigMaskHasComputeUnitLimit(0b00100))
        XCTAssertFalse(transactionConfigMaskHasComputeUnitLimit(0b11011))
        XCTAssertTrue(transactionConfigMaskHasLoadedAccountsDataSizeLimit(0b01000))
        XCTAssertFalse(transactionConfigMaskHasLoadedAccountsDataSizeLimit(0b10111))
        XCTAssertTrue(transactionConfigMaskHasHeapSize(0b10000))
        XCTAssertFalse(transactionConfigMaskHasHeapSize(0b01111))
    }

    func testDecompileTransactionConfigConsumesValuesInMaskOrder() throws {
        let config = try decompileTransactionConfig(
            configMask: 0b11111,
            configValues: [.u64(5), .u32(200), .u32(300), .u32(400)]
        )
        XCTAssertEqual(config, V1TransactionConfig(
            computeUnitLimit: 200,
            heapSize: 400,
            loadedAccountsDataSizeLimit: 300,
            priorityFeeLamports: 5
        ))

        XCTAssertThrowsError(try decompileTransactionConfig(configMask: 0b00111, configValues: [.u32(5), .u32(200)])) { error in
            XCTAssertEqual((error as? SolanaError)?.solanaCode, .transactionInvalidConfigValueKind)
        }
        XCTAssertThrowsError(try decompileTransactionConfig(configMask: 0b00100, configValues: [])) { error in
            XCTAssertEqual((error as? SolanaError)?.solanaCode, .transactionInvalidConfigValueKind)
        }
    }
}

private func txAddress(_ value: String) throws -> Address {
    try address(value)
}
