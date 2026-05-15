import Addresses
import CodecsStrings
import Keys
import os
import Promises
import RpcTypes
import SolanaErrors
@testable import TransactionConfirmation
import TransactionMessages
import Transactions
import XCTest

final class TransactionConfirmationTests: XCTestCase {
    func testTimeoutPromiseDurationsAndAbort() async throws {
        XCTAssertEqual(timeoutNanoseconds(for: .processed), 30_000_000_000)
        XCTAssertEqual(timeoutNanoseconds(for: .confirmed), 60_000_000_000)
        XCTAssertEqual(timeoutNanoseconds(for: .finalized), 60_000_000_000)

        let signal = AbortSignal()
        do {
            try await getTimeoutPromise(TimeoutPromiseConfig(abortSignal: signal, commitment: .processed), timeoutNanoseconds: 1)
            XCTFail("Expected timeout")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }

        let aborted = AbortSignal()
        aborted.abort()
        do {
            try await getTimeoutPromise(TimeoutPromiseConfig(abortSignal: aborted, commitment: .finalized), timeoutNanoseconds: 1)
            XCTFail("Expected timeout")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }

        let futureAbort = AbortSignal()
        let futureAbortTask = Task {
            try await getTimeoutPromise(
                TimeoutPromiseConfig(abortSignal: futureAbort, commitment: .finalized),
                timeoutNanoseconds: 1_000_000_000
            )
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        futureAbort.abort()
        do {
            try await futureAbortTask.value
            XCTFail("Expected abort")
        } catch {
            XCTAssertTrue(error is AbortError)
        }
    }

    func testBlockHeightExceedenceChecksInitialAndRecalibratedHeights() async throws {
        let immediateFactory = createBlockHeightExceedencePromiseFactory(
            BlockHeightExceedenceSources(
                getEpochInfo: { _, _ in EpochInfo(absoluteSlot: 101, blockHeight: 101) },
                slotNotifications: { _ in neverSlotStream() }
            )
        )

        do {
            try await immediateFactory(BlockHeightExceedenceConfig(abortSignal: AbortSignal(), lastValidBlockHeight: 100))
            XCTFail("Expected exceeded block height")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.blockHeightExceeded.rawValue)
            XCTAssertEqual(error.context["currentBlockHeight"], .uint(101))
            XCTAssertEqual(error.context["lastValidBlockHeight"], .uint(100))
        }

        let epochs = EpochInfoSequence([
            EpochInfo(absoluteSlot: 198, blockHeight: 98),
            EpochInfo(absoluteSlot: 201, blockHeight: 100),
            EpochInfo(absoluteSlot: 202, blockHeight: 101),
        ])
        let recalibratingFactory = createBlockHeightExceedencePromiseFactory(
            BlockHeightExceedenceSources(
                getEpochInfo: { _, _ in await epochs.next() },
                slotNotifications: { _ in slotStream([199, 200, 201, 202]) }
            )
        )

        do {
            try await recalibratingFactory(BlockHeightExceedenceConfig(abortSignal: AbortSignal(), lastValidBlockHeight: 100))
            XCTFail("Expected exceeded block height")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.blockHeightExceeded.rawValue)
            XCTAssertEqual(error.context["currentBlockHeight"], .uint(101))
        }
        let epochCallCount = await epochs.callCount
        XCTAssertEqual(epochCallCount, 3)
    }

    func testNonceInvalidationChecksOneShotAndSubscriptionData() async throws {
        let missingFactory = createNonceInvalidationPromiseFactory(
            NonceInvalidationSources(
                getAccountInfo: { _, _, _ in nil },
                accountNotifications: { _, _, _ in neverAccountStream() }
            )
        )

        do {
            try await missingFactory(
                NonceInvalidationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .finalized,
                    currentNonceValue: nonce4,
                    nonceAccountAddress: nonceAccountAddress()
                )
            )
            XCTFail("Expected missing nonce account")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.nonceAccountNotFound.rawValue)
            XCTAssertEqual(error.context["nonceAccountAddress"], .string(try nonceAccountAddress().rawValue))
        }

        let changedFactory = createNonceInvalidationPromiseFactory(
            NonceInvalidationSources(
                getAccountInfo: { _, _, _ in NonceAccountInfo(data: EncodedDataResponse(data: nonce4, encoding: "base58")) },
                accountNotifications: { _, _, _ in accountStream([try nonceAccountData(nonce5)]) }
            )
        )

        do {
            try await changedFactory(
                NonceInvalidationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .finalized,
                    currentNonceValue: nonce4,
                    nonceAccountAddress: try nonceAccountAddress()
                )
            )
            XCTFail("Expected invalid nonce")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.invalidNonce.rawValue)
            XCTAssertEqual(error.context["actualNonceValue"], .string(nonce5))
            XCTAssertEqual(error.context["expectedNonceValue"], .string(nonce4))
        }
    }

    func testNonceInvalidationDoesNotTreatAlreadyAbortedSignalAsImmediateFailure() async throws {
        let recorder = SignalStateRecorder()
        let alreadyAborted = AbortSignal()
        alreadyAborted.abort()
        let factory = createNonceInvalidationPromiseFactory(
            NonceInvalidationSources(
                getAccountInfo: { _, _, signal in
                    await recorder.record(signal.aborted)
                    try await neverVoid()
                    return nil
                },
                accountNotifications: { _, _, signal in
                    await recorder.record(signal.aborted)
                    return accountStream([try nonceAccountData(nonce5)])
                }
            )
        )

        do {
            try await factory(
                NonceInvalidationConfig(
                    abortSignal: alreadyAborted,
                    commitment: .finalized,
                    currentNonceValue: nonce4,
                    nonceAccountAddress: try nonceAccountAddress()
                )
            )
            XCTFail("Expected invalid nonce")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.invalidNonce.rawValue)
        }
        let recordedStates = await recorder.values
        XCTAssertEqual(recordedStates.first, false)
    }

    func testRecentSignatureConfirmationUsesSubscriptionThenLookup() async throws {
        let ordered = ConfirmationOrder()
        let signatureValue = Signature(rawValue: "abc")
        let confirmingFactory = createRecentSignatureConfirmationPromiseFactory(
            RecentSignatureConfirmationSources(
                getSignatureStatuses: { signatures, _ in
                    await ordered.record("lookup:\(signatures.first?.rawValue ?? "")")
                    return [SignatureStatus(confirmationStatus: .finalized)]
                },
                signatureNotifications: { signature, commitment, _ in
                    await ordered.record("subscribe:\(signature.rawValue):\(commitment.rawValue)")
                    return neverSignatureStream()
                }
            )
        )

        try await confirmingFactory(
            RecentSignatureConfirmationConfig(
                abortSignal: AbortSignal(),
                commitment: .finalized,
                signature: signatureValue
            )
        )
        let orderedEvents = await ordered.events
        XCTAssertEqual(orderedEvents, ["subscribe:abc:finalized", "lookup:abc"])

        let failingFactory = createRecentSignatureConfirmationPromiseFactory(
            RecentSignatureConfirmationSources(
                getSignatureStatuses: { _, _ in [SignatureStatus(confirmationStatus: .finalized, err: .duplicateInstruction(3))] },
                signatureNotifications: { _, _, _ in neverSignatureStream() }
            )
        )
        do {
            try await failingFactory(
                RecentSignatureConfirmationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .finalized,
                    signature: signatureValue
                )
            )
            XCTFail("Expected transaction error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionErrorDuplicateInstruction.rawValue)
            XCTAssertEqual(error.context["index"], .int(3))
        }

        let instructionFailingFactory = createRecentSignatureConfirmationPromiseFactory(
            RecentSignatureConfirmationSources(
                getSignatureStatuses: { _, _ in [SignatureStatus(confirmationStatus: .finalized, err: .instructionError(index: 5, error: .custom(7)))] },
                signatureNotifications: { _, _, _ in neverSignatureStream() }
            )
        )
        do {
            try await instructionFailingFactory(
                RecentSignatureConfirmationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .finalized,
                    signature: signatureValue
                )
            )
            XCTFail("Expected instruction error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.instructionErrorCustom.rawValue)
            XCTAssertEqual(error.context["code"], .int(7))
            XCTAssertEqual(error.context["index"], .int(5))
        }

        let unknownFailingFactory = createRecentSignatureConfirmationPromiseFactory(
            RecentSignatureConfirmationSources(
                getSignatureStatuses: { _, _ in [SignatureStatus(confirmationStatus: .finalized, err: .unknown("o no"))] },
                signatureNotifications: { _, _, _ in neverSignatureStream() }
            )
        )
        do {
            try await unknownFailingFactory(
                RecentSignatureConfirmationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .finalized,
                    signature: signatureValue
                )
            )
            XCTFail("Expected unknown transaction error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionErrorUnknown.rawValue)
            XCTAssertEqual(error.context["errorName"], .string("o no"))
        }
    }

    func testRecentSignatureConfirmationDoesNotTreatAlreadyAbortedSignalAsImmediateFailure() async throws {
        let recorder = SignalStateRecorder()
        let alreadyAborted = AbortSignal()
        alreadyAborted.abort()
        let factory = createRecentSignatureConfirmationPromiseFactory(
            RecentSignatureConfirmationSources(
                getSignatureStatuses: { _, signal in
                    await recorder.record(signal.aborted)
                    try await neverVoid()
                    return []
                },
                signatureNotifications: { _, _, signal in
                    await recorder.record(signal.aborted)
                    return signatureStream([SignatureNotification(value: SignatureStatus())])
                }
            )
        )

        try await factory(
            RecentSignatureConfirmationConfig(
                abortSignal: alreadyAborted,
                commitment: .finalized,
                signature: Signature(rawValue: "abc")
            )
        )
        let recordedStates = await recorder.values
        XCTAssertEqual(recordedStates.first, false)
    }

    func testRecentSignatureConfirmationResolvesWhenNotificationStreamFinishes() async throws {
        let factory = createRecentSignatureConfirmationPromiseFactory(
            RecentSignatureConfirmationSources(
                getSignatureStatuses: { _, _ in
                    try await neverVoid()
                    return []
                },
                signatureNotifications: { _, _, _ in emptySignatureStream() }
            )
        )

        try await factory(
            RecentSignatureConfirmationConfig(
                abortSignal: AbortSignal(),
                commitment: .finalized,
                signature: Signature(rawValue: "abc")
            )
        )
    }

    func testWaitersRaceRecentSignatureWithLifetimeStrategies() async throws {
        let durableRecorder = WaiterRecorder()
        let durableTransaction = try makeTransaction(lifetime: .nonce(TransactionDurableNonceLifetime(nonce: nonce4, nonceAccountAddress: nonceAccountAddress())))

        try await waitForDurableNonceTransactionConfirmation(
            DurableNonceTransactionConfirmationConfig(
                abortSignal: AbortSignal(),
                commitment: .finalized,
                getNonceInvalidationPromise: { config in
                    await durableRecorder.recordNonce(config)
                    try await neverVoid()
                },
                getRecentSignatureConfirmationPromise: { config in
                    await durableRecorder.recordRecent(config)
                },
                transaction: durableTransaction
            )
        )

        let durableSummary = await durableRecorder.summary
        XCTAssertEqual(durableSummary.nonceValue, nonce4)
        XCTAssertEqual(durableSummary.nonceAccount, try nonceAccountAddress())
        XCTAssertEqual(durableSummary.signature?.rawValue, String(repeating: "1", count: 64))

        let recentRecorder = WaiterRecorder()
        let recentTransaction = try makeTransaction(
            lifetime: .blockhash(TransactionBlockhashLifetime(blockhash: String(repeating: "4", count: 44), lastValidBlockHeight: 123))
        )

        try await waitForRecentTransactionConfirmation(
            RecentTransactionConfirmationConfig(
                abortSignal: AbortSignal(),
                commitment: .confirmed,
                getBlockHeightExceedencePromise: { config in
                    await recentRecorder.recordBlockHeight(config)
                    try await neverVoid()
                },
                getRecentSignatureConfirmationPromise: { config in
                    await recentRecorder.recordRecent(config)
                },
                transaction: recentTransaction
            )
        )

        let recentSummary = await recentRecorder.summary
        XCTAssertEqual(recentSummary.lastValidBlockHeight, 123)
        XCTAssertEqual(recentSummary.signature?.rawValue, String(repeating: "1", count: 64))

        let unsigned = Transaction(
            messageBytes: Data(),
            signatures: SignaturesMap([(try feePayer(), nil)]),
            lifetimeConstraint: .blockhash(TransactionBlockhashLifetime(blockhash: String(repeating: "4", count: 44), lastValidBlockHeight: 123))
        )
        do {
            try await waitForRecentTransactionConfirmation(
                RecentTransactionConfirmationConfig(
                    commitment: .finalized,
                    getBlockHeightExceedencePromise: { _ in },
                    getRecentSignatureConfirmationPromise: { _ in },
                    transaction: unsigned
                )
            )
            XCTFail("Expected missing fee payer signature")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionFeePayerSignatureMissing.rawValue)
        }
    }

    func testWaitersForwardCallerAbortToChildSignalsSynchronously() async throws {
        let abortProbe = AbortProbe()
        let abortSignal = AbortSignal()
        let recentTransaction = try makeTransaction(
            lifetime: .blockhash(TransactionBlockhashLifetime(blockhash: String(repeating: "4", count: 44), lastValidBlockHeight: 123))
        )

        let task = Task {
            try await waitForRecentTransactionConfirmation(
                RecentTransactionConfirmationConfig(
                    abortSignal: abortSignal,
                    commitment: .finalized,
                    getBlockHeightExceedencePromise: { config in
                        abortProbe.observe(config.abortSignal)
                        _ = await config.abortSignal.waitUntilAborted()
                        throw AbortError()
                    },
                    getRecentSignatureConfirmationPromise: { config in
                        abortProbe.observe(config.abortSignal)
                        _ = await config.abortSignal.waitUntilAborted()
                        throw AbortError()
                    },
                    transaction: recentTransaction
                )
            )
        }

        try await waitUntil {
            abortProbe.startedCount == 2
        }
        abortSignal.abort()
        XCTAssertEqual(abortProbe.abortedCount, 2)

        do {
            try await task.value
            XCTFail("Expected abort")
        } catch {
            XCTAssertTrue(error is AbortError)
        }
    }
}

private let nonce4 = String(repeating: "4", count: 44)
private let nonce5 = String(repeating: "5", count: 44)

private func nonceAccountAddress() throws -> Address {
    try Address(String(repeating: "9", count: 44))
}

private func feePayer() throws -> Address {
    try Address(String(repeating: "9", count: 44))
}

private func makeTransaction(lifetime: TransactionLifetimeConstraint) throws -> Transaction {
    Transaction(
        messageBytes: Data(),
        signatures: SignaturesMap([(try feePayer(), try SignatureBytes(Data(repeating: 0, count: 64)))]),
        lifetimeConstraint: lifetime
    )
}

private func nonceAccountData(_ nonce: Nonce) throws -> EncodedDataResponse {
    var bytes = Data(repeating: 0, count: 4 + 4 + 32 + 32)
    let nonceBytes = try getBase58Encoder().encode(nonce)
    bytes.replaceSubrange((4 + 4 + 32) ..< (4 + 4 + 32 + 32), with: nonceBytes)
    return EncodedDataResponse(data: bytes.base64EncodedString(), encoding: "base64")
}

private func slotStream(_ slots: [Slot]) -> AsyncThrowingStream<SlotNotification, any Error> {
    AsyncThrowingStream { continuation in
        for slot in slots {
            continuation.yield(SlotNotification(slot: slot))
        }
        continuation.finish()
    }
}

private func accountStream(_ data: [EncodedDataResponse]) -> AsyncThrowingStream<AccountNotification, any Error> {
    AsyncThrowingStream { continuation in
        for item in data {
            continuation.yield(AccountNotification(value: NonceAccountInfo(data: item)))
        }
        continuation.finish()
    }
}

private func neverSlotStream() -> AsyncThrowingStream<SlotNotification, any Error> {
    AsyncThrowingStream { _ in }
}

private func neverAccountStream() -> AsyncThrowingStream<AccountNotification, any Error> {
    AsyncThrowingStream { _ in }
}

private func neverSignatureStream() -> AsyncThrowingStream<SignatureNotification, any Error> {
    AsyncThrowingStream { _ in }
}

private func emptySignatureStream() -> AsyncThrowingStream<SignatureNotification, any Error> {
    AsyncThrowingStream { continuation in
        continuation.finish()
    }
}

private func signatureStream(_ notifications: [SignatureNotification]) -> AsyncThrowingStream<SignatureNotification, any Error> {
    AsyncThrowingStream { continuation in
        for notification in notifications {
            continuation.yield(notification)
        }
        continuation.finish()
    }
}

private func neverVoid() async throws {
    while true {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

private func waitUntil(timeoutNanoseconds: UInt64 = 500_000_000, _ predicate: @Sendable () -> Bool) async throws {
    let start = ContinuousClock.now
    while !predicate() {
        try await Task.sleep(nanoseconds: 1_000_000)
        if elapsedNanoseconds(since: start) > timeoutNanoseconds {
            XCTFail("Timed out waiting for condition")
            return
        }
    }
}

private func elapsedNanoseconds(since start: ContinuousClock.Instant) -> UInt64 {
    let components = start.duration(to: ContinuousClock.now).components
    let seconds = UInt64(max(0, components.seconds))
    let attoseconds = UInt64(max(0, components.attoseconds))
    return seconds * 1_000_000_000 + attoseconds / 1_000_000_000
}

private final class AbortProbe: Sendable {
    private struct State: Sendable {
        var startedCount = 0
        var abortedCount = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var startedCount: Int {
        state.withLock(\.startedCount)
    }

    var abortedCount: Int {
        state.withLock(\.abortedCount)
    }

    func observe(_ signal: AbortSignal) {
        state.withLock { $0.startedCount += 1 }
        _ = signal.addAbortHandler { [self] _ in
            state.withLock { $0.abortedCount += 1 }
        }
    }
}

private actor EpochInfoSequence {
    private var values: [EpochInfo]
    private var calls = 0

    init(_ values: [EpochInfo]) {
        self.values = values
    }

    var callCount: Int {
        calls
    }

    func next() -> EpochInfo {
        calls += 1
        return values.removeFirst()
    }
}

private actor ConfirmationOrder {
    private var recorded: [String] = []

    var events: [String] {
        recorded
    }

    func record(_ event: String) {
        recorded.append(event)
    }
}

private actor SignalStateRecorder {
    private var recorded: [Bool] = []

    var values: [Bool] {
        recorded
    }

    func record(_ value: Bool) {
        recorded.append(value)
    }
}

private actor WaiterRecorder {
    private var storage = WaiterSummary()

    var summary: WaiterSummary {
        storage
    }

    func recordNonce(_ config: NonceInvalidationConfig) {
        storage.nonceValue = config.currentNonceValue
        storage.nonceAccount = config.nonceAccountAddress
    }

    func recordBlockHeight(_ config: BlockHeightExceedenceConfig) {
        storage.lastValidBlockHeight = config.lastValidBlockHeight
    }

    func recordRecent(_ config: RecentSignatureConfirmationConfig) {
        storage.signature = config.signature
    }
}

private struct WaiterSummary: Sendable, Equatable {
    var nonceValue: Nonce?
    var nonceAccount: Address?
    var lastValidBlockHeight: UInt64?
    var signature: Signature?
}
