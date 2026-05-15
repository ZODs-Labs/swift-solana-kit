import Addresses
import Foundation
import Instructions
import SolanaErrors
import TransactionMessages
import XCTest

final class TransactionMessagesTests: XCTestCase {
    func testTransactionMessageBuilders() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let blockhash = "11111111111111111111111111111111"
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let instruction = Instruction(programAddress: program, data: Data([1, 2, 3]))

        let message = createTransactionMessage(version: .v0)
        let paid = setTransactionMessageFeePayer(feePayer, message)
        let withLifetime = setTransactionMessageLifetimeUsingBlockhash(
            BlockhashLifetimeConstraint(blockhash: blockhash, lastValidBlockHeight: 42),
            paid
        )
        let withInstruction = appendTransactionMessageInstruction(instruction, withLifetime)

        XCTAssertEqual(withInstruction.version, .v0)
        XCTAssertEqual(withInstruction.feePayer?.address, feePayer)
        XCTAssertTrue(isTransactionMessageWithBlockhashLifetime(withInstruction))
        XCTAssertEqual(withInstruction.instructions, [instruction])
    }

    func testDurableNonceLifetimePrependsAdvanceNonceInstruction() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let nonceAccount = try address("SysvarRent111111111111111111111111111111111")
        let nonceAuthority = try address("SysvarC1ock11111111111111111111111111111111")
        let message = setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
        let withNonce = setTransactionMessageLifetimeUsingDurableNonce(
            DurableNonceConfig(
                nonce: "11111111111111111111111111111111",
                nonceAccountAddress: nonceAccount,
                nonceAuthorityAddress: nonceAuthority
            ),
            message
        )

        XCTAssertEqual(withNonce.instructions.count, 1)
        XCTAssertTrue(isAdvanceNonceAccountInstruction(try XCTUnwrap(withNonce.instructions.first)))
        XCTAssertTrue(isTransactionMessageWithDurableNonceLifetime(withNonce))
        XCTAssertNoThrow(try assertIsTransactionMessageWithDurableNonceLifetime(withNonce))
        XCTAssertThrowsError(try assertIsTransactionMessageWithBlockhashLifetime(withNonce)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionExpectedBlockhashLifetime.rawValue)
        }
    }

    func testPrependingInstructionsPreservesNonceLifetimeAtRuntime() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let nonceAccount = try address("SysvarRent111111111111111111111111111111111")
        let nonceAuthority = try address("SysvarC1ock11111111111111111111111111111111")
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let nonce = "11111111111111111111111111111111"
        let message = setTransactionMessageLifetimeUsingDurableNonce(
            DurableNonceConfig(
                nonce: nonce,
                nonceAccountAddress: nonceAccount,
                nonceAuthorityAddress: nonceAuthority
            ),
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
        )

        let prepended = prependTransactionMessageInstruction(
            Instruction(programAddress: program),
            message
        )
        let compiled = try compileTransactionMessage(prepended)

        XCTAssertFalse(isTransactionMessageWithDurableNonceLifetime(prepended))
        XCTAssertEqual(prepended.lifetimeConstraint, .nonce(NonceLifetimeConstraint(nonce: nonce)))
        XCTAssertEqual(compiled.lifetimeToken, nonce)
    }

    func testComputeBudgetInstructionMutations() throws {
        let base = createTransactionMessage(version: .legacy)
        let withLimit = try setTransactionMessageComputeUnitLimit(400_000, base)
        XCTAssertEqual(withLimit.instructions.count, 1)
        XCTAssertTrue(isSetComputeUnitLimitInstruction(withLimit.instructions[0]))
        XCTAssertEqual(try getTransactionMessageComputeUnitLimit(withLimit), 400_000)

        let sameLimit = try setTransactionMessageComputeUnitLimit(400_000, withLimit)
        XCTAssertEqual(sameLimit, withLimit)

        let removed = try setTransactionMessageComputeUnitLimit(nil, withLimit)
        XCTAssertTrue(removed.instructions.isEmpty)

        let priced = try setTransactionMessageComputeUnitPrice(10_000, base)
        XCTAssertEqual(try getTransactionMessageComputeUnitPrice(priced), 10_000)
        XCTAssertTrue(isSetComputeUnitPriceInstruction(priced.instructions[0]))

        let heap = try setTransactionMessageHeapSize(256_000, base)
        XCTAssertEqual(try getTransactionMessageHeapSize(heap), 256_000)
        XCTAssertTrue(isRequestHeapFrameInstruction(heap.instructions[0]))

        let loaded = try setTransactionMessageLoadedAccountsDataSizeLimit(64_000, base)
        XCTAssertEqual(try getTransactionMessageLoadedAccountsDataSizeLimit(loaded), 64_000)
        XCTAssertTrue(isSetLoadedAccountsDataSizeLimitInstruction(loaded.instructions[0]))
    }

    func testComputeBudgetInstructionConstructorsRejectOutOfRangeU32Values() throws {
        let tooLarge = Int(UInt32.max) + 1

        for makeInstruction in [
            getSetComputeUnitLimitInstruction,
            getRequestHeapFrameInstruction,
            getSetLoadedAccountsDataSizeLimitInstruction,
        ] {
            XCTAssertThrowsError(try makeInstruction(-1)) { error in
                XCTAssertEqual(solanaCode(error), SolanaErrorCode.codecsNumberOutOfRange.rawValue)
            }
            XCTAssertThrowsError(try makeInstruction(tooLarge)) { error in
                XCTAssertEqual(solanaCode(error), SolanaErrorCode.codecsNumberOutOfRange.rawValue)
            }
        }
    }

    func testCompileLegacyMessageAndCodecRoundTrip() throws {
        let message = try legacyMessage()
        let compiled = try compileTransactionMessage(message)

        guard case let .legacy(legacy) = compiled else {
            return XCTFail("Expected legacy message")
        }

        XCTAssertEqual(legacy.header.numSignerAccounts, 2)
        XCTAssertEqual(legacy.header.numReadonlySignerAccounts, 1)
        XCTAssertEqual(legacy.header.numReadonlyNonSignerAccounts, 1)
        XCTAssertEqual(legacy.lifetimeToken, "11111111111111111111111111111111")

        let codec = getCompiledTransactionMessageCodec()
        let encoded = try codec.encode(compiled)
        let decoded = try codec.decode(encoded)
        XCTAssertEqual(decoded, compiled)

        let decompiled = try decompileTransactionMessage(
            decoded,
            config: DecompileTransactionMessageConfig(lastValidBlockHeight: 500)
        )
        XCTAssertEqual(decompiled.feePayer, message.feePayer)
        XCTAssertEqual(decompiled.instructions, message.instructions)
        XCTAssertEqual(decompiled.lifetimeConstraint, message.lifetimeConstraint)
    }

    func testCompileV0WithLookupTablesAndDecompile() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let account = try address("SysvarRent111111111111111111111111111111111")
        let lookupTable = try address("AddressLookupTab1e1111111111111111111111111")
        let base = setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
        let instruction = Instruction(
            programAddress: program,
            accounts: [.account(readonlyAccount(account))],
            data: Data([9])
        )
        let message = setTransactionMessageLifetimeUsingBlockhash(
            BlockhashLifetimeConstraint(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 9),
            appendTransactionMessageInstruction(instruction, base)
        )
        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [lookupTable: [account]]
        )
        let compiled = try compileTransactionMessage(compressed)

        guard case let .v0(v0) = compiled else {
            return XCTFail("Expected v0 message")
        }
        XCTAssertEqual(v0.staticAccounts, [feePayer, program])
        XCTAssertEqual(v0.addressTableLookups, [
            AddressTableLookup(lookupTableAddress: lookupTable, readonlyIndexes: [0], writableIndexes: []),
        ])
        XCTAssertEqual(v0.instructions.first?.accountIndices, [2])

        let decoded = try getCompiledTransactionMessageCodec().decode(try getCompiledTransactionMessageCodec().encode(compiled))
        XCTAssertEqual(decoded, compiled)
        let decompiled = try decompileTransactionMessage(
            decoded,
            config: DecompileTransactionMessageConfig(addressesByLookupTableAddress: [lookupTable: [account]])
        )
        XCTAssertEqual(decompiled.instructions.first?.accounts, compressed.instructions.first?.accounts)
    }

    func testLookupTableCompressionPreservesInputLookupOrder() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let account = try address("SysvarRent111111111111111111111111111111111")
        let firstLookupTable = try address("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let secondLookupTable = try address("AddressLookupTab1e1111111111111111111111111")
        let message = appendTransactionMessageInstruction(
            Instruction(
                programAddress: program,
                accounts: [.account(readonlyAccount(account))]
            ),
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v0))
        )

        let compressed = compressTransactionMessageUsingAddressLookupTables(
            message,
            addressesByLookupTableAddress: [
                firstLookupTable: [account],
                secondLookupTable: [account],
            ]
        )

        guard case let .lookup(meta) = compressed.instructions.first?.accounts?.first else {
            return XCTFail("Expected lookup account")
        }
        XCTAssertEqual(meta.lookupTableAddress, firstLookupTable)
    }

    func testV1ConfigCompileCodecAndDecompile() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let config = V1TransactionConfig(
            computeUnitLimit: 300_000,
            heapSize: 256_000,
            loadedAccountsDataSizeLimit: 64_000,
            priorityFeeLamports: UInt64.max
        )
        let message = setTransactionMessageLifetimeUsingBlockhash(
            BlockhashLifetimeConstraint(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 10),
            appendTransactionMessageInstruction(
                Instruction(programAddress: program, accounts: [], data: Data()),
                setTransactionMessageConfig(config, setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .v1)))
            )
        )

        let compiled = try compileTransactionMessage(message)
        guard case let .v1(v1) = compiled else {
            return XCTFail("Expected v1 message")
        }
        XCTAssertEqual(v1.configMask, 0b00011111)
        XCTAssertEqual(v1.configValues, [.u64(UInt64.max), .u32(300_000), .u32(64_000), .u32(256_000)])
        XCTAssertEqual(v1.numInstructions, 1)
        XCTAssertEqual(v1.numStaticAccounts, 2)

        let encoded = try getCompiledTransactionMessageCodec().encode(compiled)
        let decoded = try getCompiledTransactionMessageCodec().decode(encoded)
        XCTAssertEqual(decoded, compiled)
        XCTAssertEqual(try decompileTransactionMessage(decoded).config, config)
    }

    func testV1ConfigPatchCanRemoveSetAndLeaveFieldsUnchanged() throws {
        let baseConfig = V1TransactionConfig(
            computeUnitLimit: 300_000,
            heapSize: 256_000,
            loadedAccountsDataSizeLimit: 64_000
        )
        let message = setTransactionMessageConfig(baseConfig, createTransactionMessage(version: .v1))
        let patched = setTransactionMessageConfig(
            V1TransactionConfigPatch(
                computeUnitLimit: .remove,
                loadedAccountsDataSizeLimit: .set(96_000),
                priorityFeeLamports: .set(50_000)
            ),
            message
        )

        XCTAssertEqual(
            patched.config,
            V1TransactionConfig(
                heapSize: 256_000,
                loadedAccountsDataSizeLimit: 96_000,
                priorityFeeLamports: 50_000
            )
        )
    }

    func testV1ConfigPatchRemovesConfigWhenAllFieldsBecomeEmpty() throws {
        let message = setTransactionMessageConfig(
            V1TransactionConfig(computeUnitLimit: 300_000, heapSize: 256_000),
            createTransactionMessage(version: .v1)
        )
        let patched = setTransactionMessageConfig(
            V1TransactionConfigPatch(computeUnitLimit: .remove, heapSize: .remove),
            message
        )

        XCTAssertNil(patched.config)
    }

    func testV1MessageCodecRejectsOutOfRangeIntegerFields() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let codec = getCompiledTransactionMessageCodec()
        let invalidConfigMask = CompiledTransactionMessage.v1(
            V1CompiledTransactionMessage(
                configMask: -1,
                configValues: [],
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 0,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructionHeaders: [],
                instructionPayloads: [],
                lifetimeToken: "11111111111111111111111111111111",
                numInstructions: 0,
                numStaticAccounts: 1,
                staticAccounts: [feePayer]
            )
        )
        let invalidInstructionDataLength = CompiledTransactionMessage.v1(
            V1CompiledTransactionMessage(
                configMask: 0,
                configValues: [],
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 0,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructionHeaders: [
                    InstructionHeader(
                        numInstructionAccounts: 0,
                        numInstructionDataBytes: Int(UInt16.max) + 1,
                        programAccountIndex: 0
                    ),
                ],
                instructionPayloads: [InstructionPayload(instructionAccountIndices: [], instructionData: Data())],
                lifetimeToken: "11111111111111111111111111111111",
                numInstructions: 1,
                numStaticAccounts: 1,
                staticAccounts: [feePayer]
            )
        )

        XCTAssertThrowsError(try codec.encode(invalidConfigMask)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.codecsNumberOutOfRange.rawValue)
        }
        XCTAssertThrowsError(try codec.encode(invalidInstructionDataLength)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.codecsNumberOutOfRange.rawValue)
        }
    }

    func testTransactionVersionCodec() throws {
        let codec = getTransactionVersionCodec()
        XCTAssertEqual(try codec.encode(.legacy), Data())
        XCTAssertEqual(try codec.encode(.v0), Data([0x80]))
        XCTAssertEqual(try codec.encode(.v1), Data([0x81]))
        XCTAssertEqual(try codec.read(Data([0x80]), at: 0).0, .v0)
        XCTAssertEqual(try codec.read(Data([0x81]), at: 0).0, .v1)
        XCTAssertEqual(try codec.read(Data([0]), at: 0).0, .legacy)
    }

    func testTransactionVersionCodecRejectsUnsupportedAndOutOfRangeVersions() throws {
        let codec = getTransactionVersionCodec()

        XCTAssertThrowsError(try codec.encode(.unsupported(2))) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionVersionNumberNotSupported.rawValue)
        }
        XCTAssertThrowsError(try codec.encode(.unsupported(-1))) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionVersionNumberOutOfRange.rawValue)
        }
        XCTAssertThrowsError(try codec.encode(.unsupported(128))) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionVersionNumberOutOfRange.rawValue)
        }
        XCTAssertThrowsError(try codec.decode(Data([0x82]))) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionVersionNumberNotSupported.rawValue)
        }
    }

    func testCompileLimitErrorsUseTransactionCodes() throws {
        let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let instruction = Instruction(programAddress: program)
        let message = setTransactionMessageFeePayer(
            feePayer,
            TransactionMessage(version: .legacy, instructions: Array(repeating: instruction, count: 65))
        )

        XCTAssertThrowsError(try compileTransactionMessage(message)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionTooManyInstructions.rawValue)
        }
    }

    func testCompiledInstructionHelpersRejectMissingAccounts() throws {
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let missingAccount = try address("SysvarRent111111111111111111111111111111111")
        let instruction = Instruction(
            programAddress: program,
            accounts: [.account(readonlyAccount(missingAccount))],
            data: Data([1])
        )
        let orderedProgram = InstructionAccount.account(readonlyAccount(program))

        XCTAssertThrowsError(try getCompiledInstructions([instruction], orderedAccounts: [orderedProgram])) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionAddressMissing.rawValue)
        }
        XCTAssertThrowsError(try getInstructionPayload(instruction, accountIndex: [program: 0])) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionAddressMissing.rawValue)
        }
        XCTAssertThrowsError(try getInstructionHeader(instruction, accountIndex: [:])) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionAddressMissing.rawValue)
        }
    }

    func testCompiledInstructionHelpersUseLastDuplicateAccountIndex() throws {
        let accountAddress = try address("SysvarRent111111111111111111111111111111111")
        let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
        let instruction = Instruction(
            programAddress: program,
            accounts: [.account(readonlyAccount(accountAddress))]
        )
        let orderedAccounts: [InstructionAccount] = [
            .account(readonlyAccount(accountAddress)),
            .account(readonlyAccount(program)),
            .account(writableAccount(accountAddress)),
            .account(readonlyAccount(program)),
        ]

        let compiled = try getCompiledInstructions([instruction], orderedAccounts: orderedAccounts)

        XCTAssertEqual(compiled, [CompiledInstruction(accountIndices: [2], programAddressIndex: 3)])
    }

    func testDecompileLegacyNoInstructionsUsesDefaultBlockhashLifetime() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let blockhash = "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL"
        let compiled = CompiledTransactionMessage.legacy(
            LegacyCompiledTransactionMessage(
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 0,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructions: [],
                lifetimeToken: blockhash,
                staticAccounts: [feePayer]
            )
        )

        let transaction = try decompileTransactionMessage(compiled)

        XCTAssertEqual(transaction.version, .legacy)
        XCTAssertEqual(transaction.feePayer?.address, feePayer)
        XCTAssertEqual(
            transaction.lifetimeConstraint,
            .blockhash(BlockhashLifetimeConstraint(blockhash: blockhash, lastValidBlockHeight: UInt64.max))
        )
        XCTAssertEqual(transaction.instructions, [])
    }

    func testDecompileLegacyInstructionRolesAndData() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let writableSigner = try address("H4RdPRWYk3pKw2CkNznxQK6J6herjgQke2pzFJW4GC6x")
        let readonlySigner = try address("G35QeFd4jpXWfRkuRKwn8g4vYrmn8DWJ5v88Kkpd8z1V")
        let writable = try address("3LeBzRE9Yna5zi9R8vdT3MiNQYuEp4gJgVyhhwmqfCtd")
        let readonly = try address("8kud9bpNvfemXYdTFjs5cZ8fZinBkx8JAnhVmRwJZk5e")
        let program = try address("HZMKVnRrWLyQLwPLTTLKtY7ET4Cf7pQugrTr9eTBrpsf")
        let compiled = CompiledTransactionMessage.legacy(
            LegacyCompiledTransactionMessage(
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 2,
                    numReadonlySignerAccounts: 1,
                    numSignerAccounts: 3
                ),
                instructions: [
                    CompiledInstruction(
                        accountIndices: [1, 2, 3, 4],
                        data: Data([0, 1, 2, 3, 4]),
                        programAddressIndex: 5
                    ),
                ],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                staticAccounts: [feePayer, writableSigner, readonlySigner, writable, readonly, program]
            )
        )

        let transaction = try decompileTransactionMessage(compiled)

        XCTAssertEqual(transaction.instructions, [
            Instruction(
                programAddress: program,
                accounts: [
                    .account(writableSignerAccount(writableSigner)),
                    .account(readonlySignerAccount(readonlySigner)),
                    .account(writableAccount(writable)),
                    .account(readonlyAccount(readonly)),
                ],
                data: Data([0, 1, 2, 3, 4])
            ),
        ])
    }

    func testDecompileLegacyDurableNonceFeePayerCases() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let nonce = "27kqzE1RifbyoFtibDRTjbnfZ894jsNpuR77JJkt3vgH"
        let nonceAccount = try address("DhezFECsqmzuDxeuitFChbghTrwKLdsKdVsGArYbFEtm")
        let nonceAuthority = try address("2KntmCrnaf63tpNb8UMFFjFGGnYYAKQdmW9SbuCiRvhM")
        let systemProgram = try address("11111111111111111111111111111111")
        let recentBlockhashes = try address("SysvarRecentB1ockHashes11111111111111111111")
        let first = try decompileTransactionMessage(
            CompiledTransactionMessage.legacy(
                LegacyCompiledTransactionMessage(
                    header: MessageHeader(
                        numReadonlyNonSignerAccounts: 2,
                        numReadonlySignerAccounts: 0,
                        numSignerAccounts: 1
                    ),
                    instructions: [
                        CompiledInstruction(accountIndices: [1, 3, 0], data: Data([4, 0, 0, 0]), programAddressIndex: 2),
                    ],
                    lifetimeToken: nonce,
                    staticAccounts: [nonceAuthority, nonceAccount, systemProgram, recentBlockhashes]
                )
            )
        )
        let second = try decompileTransactionMessage(
            CompiledTransactionMessage.legacy(
                LegacyCompiledTransactionMessage(
                    header: MessageHeader(
                        numReadonlyNonSignerAccounts: 2,
                        numReadonlySignerAccounts: 1,
                        numSignerAccounts: 2
                    ),
                    instructions: [
                        CompiledInstruction(accountIndices: [2, 4, 1], data: Data([4, 0, 0, 0]), programAddressIndex: 3),
                    ],
                    lifetimeToken: nonce,
                    staticAccounts: [feePayer, nonceAuthority, nonceAccount, systemProgram, recentBlockhashes]
                )
            )
        )

        XCTAssertEqual(first.feePayer?.address, nonceAuthority)
        XCTAssertEqual(
            first.instructions,
            [
                Instruction(
                    programAddress: systemProgram,
                    accounts: [
                        .account(writableAccount(nonceAccount)),
                        .account(readonlyAccount(recentBlockhashes)),
                        .account(writableSignerAccount(nonceAuthority)),
                    ],
                    data: Data([4, 0, 0, 0])
                ),
            ]
        )
        XCTAssertEqual(
            first.lifetimeConstraint,
            .nonce(NonceLifetimeConstraint(nonce: nonce))
        )
        XCTAssertEqual(second.feePayer?.address, feePayer)
        XCTAssertEqual(
            second.instructions.first?.accounts,
            [
                .account(writableAccount(nonceAccount)),
                .account(readonlyAccount(recentBlockhashes)),
                .account(readonlySignerAccount(nonceAuthority)),
            ]
        )
    }

    func testDecompileV0LookupTablesPreserveWritableThenReadonlyMetas() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let program = try address("HZMKVnRrWLyQLwPLTTLKtY7ET4Cf7pQugrTr9eTBrpsf")
        let lookupTable1 = try address("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let lookupTable2 = try address("8qN8g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7")
        let lookupAccount1 = try address("9fhzQgdY7y7TpYHvH4sVBjJRzgq2LbqNq7hPvWvKAzWz")
        let lookupAccount2 = try address("BqN3g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7g7")
        let compiled = CompiledTransactionMessage.v0(
            V0CompiledTransactionMessage(
                addressTableLookups: [
                    AddressTableLookup(lookupTableAddress: lookupTable1, readonlyIndexes: [0], writableIndexes: []),
                    AddressTableLookup(lookupTableAddress: lookupTable2, readonlyIndexes: [], writableIndexes: [0]),
                ],
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 1,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructions: [CompiledInstruction(accountIndices: [2, 3], programAddressIndex: 1)],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                staticAccounts: [feePayer, program]
            )
        )

        let transaction = try decompileTransactionMessage(
            compiled,
            config: DecompileTransactionMessageConfig(
                addressesByLookupTableAddress: [
                    lookupTable1: [lookupAccount1],
                    lookupTable2: [lookupAccount2],
                ]
            )
        )

        XCTAssertEqual(transaction.instructions, [
            Instruction(
                programAddress: program,
                accounts: [
                    .lookup(writableLookupAccount(
                        address: lookupAccount2,
                        addressIndex: 0,
                        lookupTableAddress: lookupTable2
                    )),
                    .lookup(readonlyLookupAccount(
                        address: lookupAccount1,
                        addressIndex: 0,
                        lookupTableAddress: lookupTable1
                    )),
                ]
            ),
        ])
    }

    func testDecompileLegacyOmitsEmptyAccountsAndData() throws {
        let program = try address("HZMKVnRrWLyQLwPLTTLKtY7ET4Cf7pQugrTr9eTBrpsf")
        let compiled = CompiledTransactionMessage.legacy(
            LegacyCompiledTransactionMessage(
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 1,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 0
                ),
                instructions: [
                    CompiledInstruction(accountIndices: [], data: Data(), programAddressIndex: 0),
                ],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                staticAccounts: [program]
            )
        )

        let transaction = try decompileTransactionMessage(compiled)

        XCTAssertEqual(transaction.instructions, [Instruction(programAddress: program)])
    }

    func testDecompileV0MultipleInstructionsAndLastValidBlockHeight() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let program1 = try address("3hpECiFPtnyxoWqWqcVyfBUDhPKSZXWDduNXFywo8ncP")
        let program2 = try address("Cmqw16pVQvmW1b7Ek1ioQ5Ggf1PaoXi5XxsK9iVSbRKC")
        let program3 = try address("GJRYBLa6XpfswT1AN5tpGp8NHtUirwAdTPdSYXsW9L3S")
        let blockhash = "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL"
        let compiled = CompiledTransactionMessage.v0(
            V0CompiledTransactionMessage(
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 3,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructions: [
                    CompiledInstruction(programAddressIndex: 1),
                    CompiledInstruction(programAddressIndex: 2),
                    CompiledInstruction(programAddressIndex: 3),
                ],
                lifetimeToken: blockhash,
                staticAccounts: [feePayer, program1, program2, program3]
            )
        )

        let transaction = try decompileTransactionMessage(
            compiled,
            config: DecompileTransactionMessageConfig(lastValidBlockHeight: 100)
        )

        XCTAssertEqual(transaction.version, .v0)
        XCTAssertEqual(transaction.instructions, [
            Instruction(programAddress: program1),
            Instruction(programAddress: program2),
            Instruction(programAddress: program3),
        ])
        XCTAssertEqual(
            transaction.lifetimeConstraint,
            .blockhash(BlockhashLifetimeConstraint(blockhash: blockhash, lastValidBlockHeight: 100))
        )
    }

    func testDecompileV0StaticAndLookupAccountsInSameInstruction() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let staticAccount = try address("H4RdPRWYk3pKw2CkNznxQK6J6herjgQke2pzFJW4GC6x")
        let program = try address("HZMKVnRrWLyQLwPLTTLKtY7ET4Cf7pQugrTr9eTBrpsf")
        let lookupTable = try address("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let lookupAccount = try address("9fhzQgdY7y7TpYHvH4sVBjJRzgq2LbqNq7hPvWvKAzWz")
        let compiled = CompiledTransactionMessage.v0(
            V0CompiledTransactionMessage(
                addressTableLookups: [
                    AddressTableLookup(lookupTableAddress: lookupTable, readonlyIndexes: [0], writableIndexes: []),
                ],
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 1,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 2
                ),
                instructions: [
                    CompiledInstruction(accountIndices: [1, 3], programAddressIndex: 2),
                ],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                staticAccounts: [feePayer, staticAccount, program]
            )
        )

        let transaction = try decompileTransactionMessage(
            compiled,
            config: DecompileTransactionMessageConfig(addressesByLookupTableAddress: [lookupTable: [lookupAccount]])
        )

        XCTAssertEqual(transaction.instructions, [
            Instruction(
                programAddress: program,
                accounts: [
                    .account(writableSignerAccount(staticAccount)),
                    .lookup(readonlyLookupAccount(
                        address: lookupAccount,
                        addressIndex: 0,
                        lookupTableAddress: lookupTable
                    )),
                ]
            ),
        ])
    }

    func testDecompileV0DurableNonceWithMultipleInstructions() throws {
        let nonce = "27kqzE1RifbyoFtibDRTjbnfZ894jsNpuR77JJkt3vgH"
        let nonceAccount = try address("DhezFECsqmzuDxeuitFChbghTrwKLdsKdVsGArYbFEtm")
        let nonceAuthority = try address("2KntmCrnaf63tpNb8UMFFjFGGnYYAKQdmW9SbuCiRvhM")
        let systemProgram = try address("11111111111111111111111111111111")
        let recentBlockhashes = try address("SysvarRecentB1ockHashes11111111111111111111")
        let program1 = try address("3hpECiFPtnyxoWqWqcVyfBUDhPKSZXWDduNXFywo8ncP")
        let program2 = try address("Cmqw16pVQvmW1b7Ek1ioQ5Ggf1PaoXi5XxsK9iVSbRKC")
        let compiled = CompiledTransactionMessage.v0(
            V0CompiledTransactionMessage(
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 4,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructions: [
                    CompiledInstruction(accountIndices: [1, 3, 0], data: Data([4, 0, 0, 0]), programAddressIndex: 2),
                    CompiledInstruction(accountIndices: [0, 1], data: Data([1, 2, 3, 4]), programAddressIndex: 4),
                    CompiledInstruction(programAddressIndex: 5),
                ],
                lifetimeToken: nonce,
                staticAccounts: [nonceAuthority, nonceAccount, systemProgram, recentBlockhashes, program1, program2]
            )
        )

        let transaction = try decompileTransactionMessage(compiled)

        XCTAssertEqual(
            transaction.lifetimeConstraint,
            .nonce(NonceLifetimeConstraint(nonce: nonce))
        )
        XCTAssertEqual(transaction.instructions, [
            Instruction(
                programAddress: systemProgram,
                accounts: [
                    .account(writableAccount(nonceAccount)),
                    .account(readonlyAccount(recentBlockhashes)),
                    .account(writableSignerAccount(nonceAuthority)),
                ],
                data: Data([4, 0, 0, 0])
            ),
            Instruction(
                programAddress: program1,
                accounts: [
                    .account(writableSignerAccount(nonceAuthority)),
                    .account(writableAccount(nonceAccount)),
                ],
                data: Data([1, 2, 3, 4])
            ),
            Instruction(programAddress: program2),
        ])
    }

    func testDecompileV0LookupTableErrors() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let program = try address("HZMKVnRrWLyQLwPLTTLKtY7ET4Cf7pQugrTr9eTBrpsf")
        let lookupTable = try address("FwR5Cu5b5zXHa5KHuGQkN7UhSNebc756N1EhR2aHHLHq")
        let lookupAccount = try address("9fhzQgdY7y7TpYHvH4sVBjJRzgq2LbqNq7hPvWvKAzWz")
        let missingLookup = CompiledTransactionMessage.v0(
            V0CompiledTransactionMessage(
                addressTableLookups: [
                    AddressTableLookup(lookupTableAddress: lookupTable, readonlyIndexes: [0], writableIndexes: []),
                ],
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 1,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructions: [CompiledInstruction(programAddressIndex: 1)],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                staticAccounts: [feePayer, program]
            )
        )
        let outOfRange = CompiledTransactionMessage.v0(
            V0CompiledTransactionMessage(
                addressTableLookups: [
                    AddressTableLookup(lookupTableAddress: lookupTable, readonlyIndexes: [5], writableIndexes: []),
                ],
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 1,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructions: [CompiledInstruction(programAddressIndex: 1)],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                staticAccounts: [feePayer, program]
            )
        )

        XCTAssertThrowsError(try decompileTransactionMessage(missingLookup)) { error in
            XCTAssertEqual(
                solanaCode(error),
                SolanaErrorCode.transactionFailedToDecompileAddressLookupTableContentsMissing.rawValue
            )
        }
        XCTAssertThrowsError(
            try decompileTransactionMessage(
                outOfRange,
                config: DecompileTransactionMessageConfig(addressesByLookupTableAddress: [lookupTable: [lookupAccount]])
            )
        ) { error in
            XCTAssertEqual(
                solanaCode(error),
                SolanaErrorCode.transactionFailedToDecompileAddressLookupTableIndexOutOfRange.rawValue
            )
        }
    }

    func testDecompileV1RejectsInstructionAccountIndexOutOfRange() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let program = try address("HZMKVnRrWLyQLwPLTTLKtY7ET4Cf7pQugrTr9eTBrpsf")
        let compiled = CompiledTransactionMessage.v1(
            V1CompiledTransactionMessage(
                configMask: 0,
                configValues: [],
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 1,
                    numReadonlySignerAccounts: 0,
                    numSignerAccounts: 1
                ),
                instructionHeaders: [
                    InstructionHeader(
                        numInstructionAccounts: 1,
                        numInstructionDataBytes: 0,
                        programAccountIndex: 1
                    ),
                ],
                instructionPayloads: [
                    InstructionPayload(instructionAccountIndices: [2], instructionData: Data()),
                ],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                numInstructions: 1,
                numStaticAccounts: 2,
                staticAccounts: [feePayer, program]
            )
        )

        XCTAssertThrowsError(try decompileTransactionMessage(compiled)) { error in
            XCTAssertEqual(
                solanaCode(error),
                SolanaErrorCode.transactionFailedToDecompileInstructionProgramAddressNotFound.rawValue
            )
        }
    }

    func testDecompileRejectsHeaderThatReferencesMissingStaticAccounts() throws {
        let feePayer = try address("7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")
        let compiled = CompiledTransactionMessage.legacy(
            LegacyCompiledTransactionMessage(
                header: MessageHeader(
                    numReadonlyNonSignerAccounts: 0,
                    numReadonlySignerAccounts: 1,
                    numSignerAccounts: 2
                ),
                instructions: [],
                lifetimeToken: "J4yED2jcMAHyQUg61DBmm4njmEydUr2WqrV9cdEcDDgL",
                staticAccounts: [feePayer]
            )
        )

        XCTAssertThrowsError(try decompileTransactionMessage(compiled)) { error in
            XCTAssertEqual(solanaCode(error), SolanaErrorCode.transactionAddressMissing.rawValue)
        }
    }
}

private func legacyMessage() throws -> TransactionMessage {
    let feePayer = try address("GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G")
    let program = try address("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr")
    let writable = try address("SysvarRent111111111111111111111111111111111")
    let readonlySigner = try address("SysvarC1ock11111111111111111111111111111111")
    let instruction = Instruction(
        programAddress: program,
        accounts: [
            .account(writableAccount(writable)),
            .account(readonlySignerAccount(readonlySigner)),
        ],
        data: Data([1, 2, 3])
    )
    return setTransactionMessageLifetimeUsingBlockhash(
        BlockhashLifetimeConstraint(blockhash: "11111111111111111111111111111111", lastValidBlockHeight: 500),
        appendTransactionMessageInstruction(
            instruction,
            setTransactionMessageFeePayer(feePayer, createTransactionMessage(version: .legacy))
        )
    )
}

private func solanaCode(_ error: any Error) -> Int? {
    (error as? any SolanaErrorCoded)?.code
}
