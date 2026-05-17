import Accounts
import Addresses
import CodecsNumbers
import Foundation
import InstructionPlans
import Instructions
import PluginInterfaces
import ProgramClientCore
import Promises
import RpcSpec
import RpcSpecTypes
import RpcTypes
import Signers
import SolanaErrors
import TransactionMessages
import XCTest

final class ProgramClientCoreDetailedBehaviorTests: XCTestCase {
    func testResolvedInstructionExtractionReportsNilAndWrongTypesWithInputNames() throws {
        let address = try Address("11111111111111111111111111111111")
        let pda = ProgramDerivedAddress(address: address, bump: try ProgramDerivedAddressBump(254))
        let signer = NoopSigner(address: address).transactionSigner

        XCTAssertEqual(try getResolvedInstructionAccountAsProgramDerivedAddress("vault", .programDerivedAddress(pda)), pda)
        XCTAssertEqual(try getResolvedInstructionAccountAsTransactionSigner("authority", .transactionSigner(signer)).address, address)

        assertProgramClientError(
            try getAddressFromResolvedInstructionAccount("mint", nil),
            code: .programClientsResolvedInstructionInputMustBeNonNull,
            context: ["inputName": .string("mint")]
        )
        assertProgramClientError(
            try getResolvedInstructionAccountAsProgramDerivedAddress("metadata", nil),
            code: .programClientsUnexpectedResolvedInstructionInputType,
            context: ["expectedType": .string("ProgramDerivedAddress"), "inputName": .string("metadata")]
        )
        assertProgramClientError(
            try getResolvedInstructionAccountAsTransactionSigner("payer", .programDerivedAddress(pda)),
            code: .programClientsUnexpectedResolvedInstructionInputType,
            context: ["expectedType": .string("TransactionSigner"), "inputName": .string("payer")]
        )
    }

    func testAccountMetaFactoryCreatesRolesForEveryResolvedAccountShape() throws {
        let programAddress = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("SysvarC1ock11111111111111111111111111111111")
        let signerAddress = try Address("SysvarRent111111111111111111111111111111111")
        let pda = ProgramDerivedAddress(address: accountAddress, bump: try ProgramDerivedAddressBump(42))
        let signer = NoopSigner(address: signerAddress).transactionSigner
        let factory = getAccountMetaFactory(programAddress: programAddress, optionalAccountStrategy: .programID)

        let readonlyAddress = try factory("readonly", ResolvedInstructionAccount(isWritable: false, value: .address(accountAddress)))
        let writableAddress = try factory("writable", ResolvedInstructionAccount(isWritable: true, value: .address(accountAddress)))
        let writablePda = try factory("pda", ResolvedInstructionAccount(isWritable: true, value: .programDerivedAddress(pda)))
        let readonlySigner = try factory("authority", ResolvedInstructionAccount(isWritable: false, value: .transactionSigner(signer)))
        let writableSigner = try factory("payer", ResolvedInstructionAccount(isWritable: true, value: .transactionSigner(signer)))
        let missing = try factory("optional", ResolvedInstructionAccount(isWritable: true, value: nil))

        XCTAssertEqual(readonlyAddress?.address, accountAddress)
        XCTAssertEqual(readonlyAddress?.role, .readonly)
        XCTAssertNil(readonlyAddress?.signer)
        XCTAssertEqual(writableAddress?.role, .writable)
        XCTAssertEqual(writablePda?.address, accountAddress)
        XCTAssertEqual(writablePda?.role, .writable)
        XCTAssertEqual(readonlySigner?.address, signerAddress)
        XCTAssertEqual(readonlySigner?.role, .readonlySigner)
        XCTAssertEqual(readonlySigner?.signer?.address, signerAddress)
        XCTAssertEqual(writableSigner?.role, .writableSigner)
        XCTAssertEqual(missing?.address, programAddress)
        XCTAssertEqual(missing?.role, .readonly)
        XCTAssertNil(missing?.signer)
    }

    func testSelfPlanAndSendItemsPreserveInputsAndForwardConfigToEveryOperation() async throws {
        let signal = AbortSignal()
        let recorder = ProgramClientPlanSendRecorder(signal: signal)
        let client = ProgramClientRecordingTransactionClient(recorder: recorder)
        let instruction = try Instruction(programAddress: Address("11111111111111111111111111111111"))
        let item = addSelfPlanAndSendFunctions(client: client, input: instruction)
        let config = PluginTransactionConfig(abortSignal: signal)

        _ = try await item.planTransaction(config: config)
        _ = try await item.planTransactions(config: config)
        _ = try await item.sendTransaction(config: config)
        _ = try await item.sendTransactions(config: config)

        XCTAssertEqual(item.input, instruction)
        let calls = await recorder.calls()
        XCTAssertEqual(calls.map(\.name), ["planTransaction", "planTransactions", "sendTransaction", "sendTransactions"])
        XCTAssertEqual(calls.map(\.sawSignal), [true, true, true, true])
        XCTAssertEqual(calls.map(\.input), [.instruction, .instruction, .instruction, .instruction])
    }

    func testCustomAsyncInputResolverRunsForEachOperationAndPropagatesFailures() async throws {
        let recorder = ProgramClientPlanSendRecorder()
        let client = ProgramClientRecordingTransactionClient(recorder: recorder)
        let counter = ProgramClientInputCounter()
        let instruction = try Instruction(programAddress: Address("11111111111111111111111111111111"))
        let item = addSelfPlanAndSendFunctions(client: client, input: {
            await counter.next()
            return instruction
        }) { resolved in
            .instruction(resolved)
        }

        _ = try await item.planTransaction()
        _ = try await item.sendTransactions()

        let resolvedCount = await counter.value()
        let resolvedCalls = await recorder.calls()
        XCTAssertEqual(resolvedCount, 2)
        XCTAssertEqual(resolvedCalls.map(\.input), [.instruction, .instructionPlanInput])

        let failing = addSelfPlanAndSendFunctions(client: client, input: {
            await counter.next()
            throw ProgramClientTestError(message: "resolve")
        }) { (_: Instruction) in
            .instruction(instruction)
        }

        await XCTAssertThrowsErrorAsync(try await failing.sendTransaction()) { error in
            XCTAssertEqual((error as? ProgramClientTestError)?.message, "resolve")
        }
        let finalCount = await counter.value()
        let finalCalls = await recorder.calls()
        XCTAssertEqual(finalCount, 3)
        XCTAssertEqual(finalCalls.count, 2)
    }

    func testSelfFetchingCodecForwardsSingleFetchConfigAndDecodesExistingAccounts() async throws {
        let owner = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("SysvarC1ock11111111111111111111111111111111")
        let signal = AbortSignal()
        let recorder = ProgramClientRpcRecorder(responses: [
            .object([RpcJsonObjectMember("value", Self.base64Account(owner: owner, bytes: "AQ==", space: 1))]),
        ])
        let rpc = await recorder.makeRpc()
        let codec = addSelfFetchFunctions(
            client: ProgramClientRpcClient(rpc: rpc),
            codec: getU8Codec()
        )

        let result = try await codec.fetchMaybe(
            accountAddress,
            config: FetchAccountConfig(abortSignal: signal, commitment: .confirmed, minContextSlot: 55)
        )

        guard case let .exists(account) = result else {
            return XCTFail("Expected account")
        }
        XCTAssertEqual(account.address, accountAddress)
        XCTAssertEqual(account.data, 1)
        XCTAssertEqual(account.lamports, 1_000_000)
        XCTAssertEqual(account.programAddress, owner)
        XCTAssertEqual(account.space, 1)

        let recordedConfig = await recorder.firstConfig()
        let config = try XCTUnwrap(recordedConfig)
        XCTAssertTrue(config.abortSignal === signal)
        XCTAssertEqual(config.payload.value(for: "method"), .string("getAccountInfo"))
        XCTAssertEqual(
            config.payload.value(for: "params"),
            .array([
                .string(accountAddress.rawValue),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("commitment", .string("confirmed")),
                    RpcJsonObjectMember("minContextSlot", .bigint("55")),
                ]),
            ])
        )
    }

    func testSelfFetchingCodecReturnsMissingMaybeAndThrowsWhenRequired() async throws {
        let accountAddress = try Address("SysvarRent111111111111111111111111111111111")
        let recorder = ProgramClientRpcRecorder(responses: [
            .object([RpcJsonObjectMember("value", .null)]),
            .object([RpcJsonObjectMember("value", .null)]),
        ])
        let rpc = await recorder.makeRpc()
        let codec = addSelfFetchFunctions(
            client: ProgramClientRpcClient(rpc: rpc),
            codec: getU8Codec()
        )

        let maybe = try await codec.fetchMaybe(accountAddress)
        XCTAssertEqual(maybe, .missing(address: accountAddress))

        await XCTAssertThrowsErrorAsync(try await codec.fetch(accountAddress)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.solanaCode, .accountsAccountNotFound)
            XCTAssertEqual(solanaError?.context["address"], .string(accountAddress.rawValue))
        }
    }

    func testSelfFetchingCodecPreservesMultipleFetchOrderAndReportsAllMissingAddresses() async throws {
        let owner = try Address("11111111111111111111111111111111")
        let first = try Address("SysvarC1ock11111111111111111111111111111111")
        let second = try Address("SysvarRent111111111111111111111111111111111")
        let third = try Address("Sysvar1111111111111111111111111111111111111")
        let recorder = ProgramClientRpcRecorder(responses: [
            .object([
                RpcJsonObjectMember("value", .array([
                    Self.base64Account(owner: owner, bytes: "AQ==", space: 1),
                    .null,
                    Self.base64Account(owner: owner, bytes: "Ag==", space: 1),
                ])),
            ]),
            .object([
                RpcJsonObjectMember("value", .array([
                    Self.base64Account(owner: owner, bytes: "AQ==", space: 1),
                    .null,
                    .null,
                ])),
            ]),
        ])
        let rpc = await recorder.makeRpc()
        let codec = addSelfFetchFunctions(
            client: ProgramClientRpcClient(rpc: rpc),
            codec: getU8Codec()
        )

        let maybeAccounts = try await codec.fetchAllMaybe(
            [first, second, third],
            config: FetchAccountsConfig(commitment: .processed, minContextSlot: 9)
        )

        XCTAssertEqual(maybeAccounts.count, 3)
        XCTAssertEqual(maybeAccounts[0].account?.data, 1)
        XCTAssertEqual(maybeAccounts[0].address, first)
        XCTAssertEqual(maybeAccounts[1], .missing(address: second))
        XCTAssertEqual(maybeAccounts[2].account?.data, 2)
        XCTAssertEqual(maybeAccounts[2].address, third)

        let recordedConfig = await recorder.firstConfig()
        let config = try XCTUnwrap(recordedConfig)
        XCTAssertEqual(config.payload.value(for: "method"), .string("getMultipleAccounts"))
        XCTAssertEqual(
            config.payload.value(for: "params"),
            .array([
                .array([.string(first.rawValue), .string(second.rawValue), .string(third.rawValue)]),
                .object([
                    RpcJsonObjectMember("encoding", .string("base64")),
                    RpcJsonObjectMember("commitment", .string("processed")),
                    RpcJsonObjectMember("minContextSlot", .bigint("9")),
                ]),
            ])
        )

        await XCTAssertThrowsErrorAsync(try await codec.fetchAll([first, second, third])) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.solanaCode, .accountsOneOrMoreAccountsNotFound)
            XCTAssertEqual(solanaError?.context["addresses"], .stringArray([second.rawValue, third.rawValue]))
        }
    }

    func testSelfFetchingCodecMapsDecodeFailuresToAccountContext() async throws {
        let owner = try Address("11111111111111111111111111111111")
        let accountAddress = try Address("Sysvar1111111111111111111111111111111111111")
        let recorder = ProgramClientRpcRecorder(responses: [
            .object([RpcJsonObjectMember("value", Self.base64Account(owner: owner, bytes: "", space: 0))]),
        ])
        let rpc = await recorder.makeRpc()
        let codec = addSelfFetchFunctions(
            client: ProgramClientRpcClient(rpc: rpc),
            codec: getU8Codec()
        )

        await XCTAssertThrowsErrorAsync(try await codec.fetchMaybe(accountAddress)) { error in
            let solanaError = error as? SolanaError
            XCTAssertEqual(solanaError?.solanaCode, .accountsFailedToDecodeAccount)
            XCTAssertEqual(solanaError?.context["address"], .string(accountAddress.rawValue))
        }
    }

    private static func base64Account(owner: Address, bytes: String, space: UInt64) -> RpcJsonValue {
        .object([
            RpcJsonObjectMember("data", .array([.string(bytes), .string("base64")])),
            RpcJsonObjectMember("executable", .bool(false)),
            RpcJsonObjectMember("lamports", .bigint("1000000")),
            RpcJsonObjectMember("owner", .string(owner.rawValue)),
            RpcJsonObjectMember("space", .bigint(String(space))),
        ])
    }
}

private actor ProgramClientInputCounter {
    private var count = 0

    func next() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private actor ProgramClientPlanSendRecorder {
    private var recordedCalls: [ProgramClientPlanSendCall] = []
    private let signal: AbortSignal

    init(signal: AbortSignal = AbortSignal()) {
        self.signal = signal
    }

    func record(_ name: String, config: PluginTransactionConfig?, input: ProgramClientPlanSendInput) {
        recordedCalls.append(ProgramClientPlanSendCall(
            name: name,
            input: input,
            sawSignal: config?.abortSignal === signal
        ))
    }

    func calls() -> [ProgramClientPlanSendCall] {
        recordedCalls
    }
}

private struct ProgramClientPlanSendCall: Sendable, Equatable {
    let name: String
    let input: ProgramClientPlanSendInput
    let sawSignal: Bool
}

private enum ProgramClientPlanSendInput: Sendable, Equatable {
    case instruction
    case instructionPlan
    case instructionPlanInput
    case singleTransactionPlan
    case transactionMessage
    case transactionPlan
}

private struct ProgramClientRecordingTransactionClient: ClientWithTransactionPlanning, ClientWithTransactionSending {
    let recorder: ProgramClientPlanSendRecorder
    let message = TransactionMessage(version: .legacy)

    func planTransaction(
        _ input: InstructionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> TransactionMessage {
        await recorder.record("planTransaction", config: config, input: input.summary)
        return message
    }

    func planTransactions(
        _ input: InstructionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> TransactionPlan {
        await recorder.record("planTransactions", config: config, input: input.summary)
        return .single(SingleTransactionPlan(message: message))
    }

    func sendTransaction(
        _ input: SingleTransactionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> SuccessfulSingleTransactionPlanResult {
        await recorder.record("sendTransaction", config: config, input: input.summary)
        return SuccessfulSingleTransactionPlanResult(
            plannedMessage: message,
            context: TransactionPlanExecutionContext()
        )
    }

    func sendTransactions(
        _ input: PluginInterfaces.TransactionPlanInput,
        config: PluginTransactionConfig?
    ) async throws -> TransactionPlanResult {
        await recorder.record("sendTransactions", config: config, input: input.summary)
        return .single(.successful(SuccessfulSingleTransactionPlanResult(
            plannedMessage: message,
            context: TransactionPlanExecutionContext()
        )))
    }
}

private struct ProgramClientRpcClient: ClientWithRpc {
    let rpc: Rpc
}

private actor ProgramClientRpcRecorder {
    private var responses: [RpcJsonValue]
    private var configs: [RpcTransportConfig] = []

    init(responses: [RpcJsonValue]) {
        self.responses = responses
    }

    func makeRpc() -> Rpc {
        createRpc(api: createJsonRpcApi()) { config in
            try await self.transport(config)
        }
    }

    func transport(_ config: RpcTransportConfig) async throws -> RpcJsonValue {
        configs.append(config)
        guard !responses.isEmpty else {
            throw ProgramClientTestError(message: "missing response")
        }
        return responses.removeFirst()
    }

    func firstConfig() -> RpcTransportConfig? {
        configs.first
    }
}

private extension InstructionPlanInput {
    var summary: ProgramClientPlanSendInput {
        switch self {
        case .instruction:
            .instruction
        case .plan:
            .instructionPlan
        case .array:
            .instructionPlanInput
        }
    }
}

private extension SingleTransactionPlanInput {
    var summary: ProgramClientPlanSendInput {
        switch self {
        case .instruction:
            .instruction
        case .instructionPlan:
            .instructionPlan
        case .instructionPlanInput:
            .instructionPlanInput
        case .singleTransactionPlan:
            .singleTransactionPlan
        case .transactionMessage:
            .transactionMessage
        }
    }
}

private extension PluginInterfaces.TransactionPlanInput {
    var summary: ProgramClientPlanSendInput {
        switch self {
        case .instruction:
            .instruction
        case .instructionPlan:
            .instructionPlan
        case .instructionPlanInput:
            .instructionPlanInput
        case .transactionPlan:
            .transactionPlan
        }
    }
}

private struct ProgramClientTestError: Error, Sendable, Equatable {
    let message: String
}

private func assertProgramClientError<T>(
    _ expression: @autoclosure () throws -> T,
    code: SolanaErrorCode,
    context: [String: SolanaErrorContextValue],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        guard let solanaError = error as? SolanaError else {
            return XCTFail("Expected SolanaError", file: file, line: line)
        }
        XCTAssertEqual(solanaError.solanaCode, code, file: file, line: line)
        for (key, value) in context {
            XCTAssertEqual(solanaError.context[key], value, file: file, line: line)
        }
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Sendable,
    _ verify: (any Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        verify(error)
    }
}
