import Addresses
import CodecsStrings
import Keys
import Promises
import RpcTypes
import SolanaErrors
import TransactionConfirmation
import TransactionMessages
import Transactions
import XCTest

final class TransactionConfirmationDetailedBehaviorTests: XCTestCase {
    func testBlockHeightStrategyForwardsCommitmentToInitialAndRecheckedLookups() async throws {
        let recorder = DetailedEpochRecorder([
            EpochInfo(absoluteSlot: 200, blockHeight: 100),
            EpochInfo(absoluteSlot: 201, blockHeight: 101),
        ])
        let factory = createBlockHeightExceedencePromiseFactory(
            BlockHeightExceedenceSources(
                getEpochInfo: { commitment, _ in
                    await recorder.next(commitment)
                },
                slotNotifications: { _ in detailedSlotStream([201]) }
            )
        )

        do {
            try await factory(
                BlockHeightExceedenceConfig(
                    abortSignal: AbortSignal(),
                    commitment: .confirmed,
                    lastValidBlockHeight: 100
                )
            )
            XCTFail("Expected exceeded block height")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.blockHeightExceeded.rawValue)
            XCTAssertEqual(error.context["currentBlockHeight"], .uint(101))
            XCTAssertEqual(error.context["lastValidBlockHeight"], .uint(100))
        }

        let commitments = await recorder.commitments
        XCTAssertEqual(commitments, [.confirmed, .confirmed])
    }

    func testNonceStrategyDetectsInvalidNonceFromInitialLookupWithoutNotification() async throws {
        let factory = createNonceInvalidationPromiseFactory(
            NonceInvalidationSources(
                getAccountInfo: { _, commitment, _ in
                    XCTAssertEqual(commitment, .confirmed)
                    return NonceAccountInfo(data: EncodedDataResponse(data: detailedNonce5, encoding: "base58"))
                },
                accountNotifications: { _, commitment, _ in
                    XCTAssertEqual(commitment, .confirmed)
                    return detailedNeverAccountStream()
                }
            )
        )

        do {
            try await factory(
                NonceInvalidationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .confirmed,
                    currentNonceValue: detailedNonce4,
                    nonceAccountAddress: try detailedNonceAccountAddress()
                )
            )
            XCTFail("Expected invalid nonce")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.invalidNonce.rawValue)
            XCTAssertEqual(error.context["actualNonceValue"], .string(detailedNonce5))
            XCTAssertEqual(error.context["expectedNonceValue"], .string(detailedNonce4))
        }
    }

    func testNonceStrategyRejectsUnsupportedAccountEncodingAndShortBase64Data() async throws {
        let invalidEncodingFactory = createNonceInvalidationPromiseFactory(
            NonceInvalidationSources(
                getAccountInfo: { _, _, _ in NonceAccountInfo(data: EncodedDataResponse(data: detailedNonce4, encoding: "base64+zstd")) },
                accountNotifications: { _, _, _ in detailedNeverAccountStream() }
            )
        )

        do {
            try await invalidEncodingFactory(
                NonceInvalidationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .finalized,
                    currentNonceValue: detailedNonce4,
                    nonceAccountAddress: try detailedNonceAccountAddress()
                )
            )
            XCTFail("Expected invalid pattern")
        } catch {
            XCTAssertEqual(error as? CodecsError, .invalidPatternMatchValue)
        }

        let shortBase64Factory = createNonceInvalidationPromiseFactory(
            NonceInvalidationSources(
                getAccountInfo: { _, _, _ in NonceAccountInfo(data: EncodedDataResponse(data: Data(repeating: 0, count: 8).base64EncodedString(), encoding: "base64")) },
                accountNotifications: { _, _, _ in detailedNeverAccountStream() }
            )
        )

        do {
            try await shortBase64Factory(
                NonceInvalidationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .finalized,
                    currentNonceValue: detailedNonce4,
                    nonceAccountAddress: try detailedNonceAccountAddress()
                )
            )
            XCTFail("Expected short nonce account data")
        } catch let error as CodecsError {
            guard case let .invalidByteLength(codecDescription, expected, bytesLength) = error else {
                return XCTFail("Expected invalid byte length, got \(error)")
            }
            XCTAssertEqual(codecDescription, "nonce account")
            XCTAssertEqual(expected, 72)
            XCTAssertEqual(bytesLength, 8)
        }
    }

    func testRecentSignatureStrategyThrowsNotificationErrorsBeforeLookupCompletes() async throws {
        let factory = createRecentSignatureConfirmationPromiseFactory(
            RecentSignatureConfirmationSources(
                getSignatureStatuses: { _, _ in
                    try await detailedNeverVoid()
                    return []
                },
                signatureNotifications: { _, commitment, _ in
                    XCTAssertEqual(commitment, .confirmed)
                    return detailedSignatureStream([
                        SignatureNotification(value: SignatureStatus(err: .insufficientFundsForRent(accountIndex: 7))),
                    ])
                }
            )
        )

        do {
            try await factory(
                RecentSignatureConfirmationConfig(
                    abortSignal: AbortSignal(),
                    commitment: .confirmed,
                    signature: Signature(rawValue: "abc")
                )
            )
            XCTFail("Expected transaction error")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionErrorInsufficientFundsForRent.rawValue)
            XCTAssertEqual(error.context["accountIndex"], .int(7))
        }
    }

    func testTimeBasedWaiterRacesRecentSignatureAndTimeoutStrategies() async throws {
        let recorder = DetailedWaiterRecorder()

        try await waitForRecentTransactionConfirmationUntilTimeout(
            TimeBasedTransactionConfirmationConfig(
                abortSignal: AbortSignal(),
                commitment: .processed,
                getRecentSignatureConfirmationPromise: { config in
                    await recorder.recordRecent(config)
                    await recorder.waitUntilTimeoutRecorded()
                },
                getTimeoutPromise: { config in
                    await recorder.recordTimeout(config)
                    try await detailedNeverVoid()
                },
                signature: Signature(rawValue: String(repeating: "1", count: 64))
            )
        )

        let summary = await recorder.summary
        XCTAssertEqual(summary.recentSignature?.rawValue, String(repeating: "1", count: 64))
        XCTAssertEqual(summary.timeoutCommitment, .processed)
        XCTAssertEqual(summary.recentCommitment, .processed)
    }

    func testWaitersRejectTransactionsWithTheWrongLifetimeKind() async throws {
        let blockhashTransaction = try detailedTransaction(
            lifetime: .blockhash(
                TransactionBlockhashLifetime(blockhash: String(repeating: "4", count: 44), lastValidBlockHeight: 123)
            )
        )
        do {
            try await waitForDurableNonceTransactionConfirmation(
                DurableNonceTransactionConfirmationConfig(
                    commitment: .finalized,
                    getNonceInvalidationPromise: { _ in },
                    getRecentSignatureConfirmationPromise: { _ in },
                    transaction: blockhashTransaction
                )
            )
            XCTFail("Expected nonce lifetime")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionExpectedNonceLifetime.rawValue)
        }

        let nonceTransaction = try detailedTransaction(
            lifetime: .nonce(
                TransactionDurableNonceLifetime(
                    nonce: detailedNonce4,
                    nonceAccountAddress: try detailedNonceAccountAddress()
                )
            )
        )
        do {
            try await waitForRecentTransactionConfirmation(
                RecentTransactionConfirmationConfig(
                    commitment: .finalized,
                    getBlockHeightExceedencePromise: { _ in },
                    getRecentSignatureConfirmationPromise: { _ in },
                    transaction: nonceTransaction
                )
            )
            XCTFail("Expected blockhash lifetime")
        } catch let error as SolanaError {
            XCTAssertEqual(error.code, SolanaErrorCode.transactionExpectedBlockhashLifetime.rawValue)
        }
    }
}

private let detailedNonce4 = String(repeating: "4", count: 44)
private let detailedNonce5 = String(repeating: "5", count: 44)

private func detailedNonceAccountAddress() throws -> Address {
    try Address(String(repeating: "9", count: 44))
}

private func detailedFeePayer() throws -> Address {
    try Address(String(repeating: "9", count: 44))
}

private func detailedTransaction(lifetime: TransactionLifetimeConstraint) throws -> Transaction {
    Transaction(
        messageBytes: Data(),
        signatures: SignaturesMap([(try detailedFeePayer(), try SignatureBytes(Data(repeating: 0, count: 64)))]),
        lifetimeConstraint: lifetime
    )
}

private func detailedSlotStream(_ slots: [Slot]) -> AsyncThrowingStream<SlotNotification, any Error> {
    AsyncThrowingStream { continuation in
        for slot in slots {
            continuation.yield(SlotNotification(slot: slot))
        }
        continuation.finish()
    }
}

private func detailedNeverAccountStream() -> AsyncThrowingStream<AccountNotification, any Error> {
    AsyncThrowingStream { _ in }
}

private func detailedSignatureStream(_ notifications: [SignatureNotification]) -> AsyncThrowingStream<SignatureNotification, any Error> {
    AsyncThrowingStream { continuation in
        for notification in notifications {
            continuation.yield(notification)
        }
        continuation.finish()
    }
}

private func detailedNeverVoid() async throws {
    while true {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

private actor DetailedEpochRecorder {
    private var values: [EpochInfo]
    private var recordedCommitments: [Commitment?] = []

    init(_ values: [EpochInfo]) {
        self.values = values
    }

    var commitments: [Commitment?] {
        recordedCommitments
    }

    func next(_ commitment: Commitment?) -> EpochInfo {
        recordedCommitments.append(commitment)
        return values.removeFirst()
    }
}

private actor DetailedWaiterRecorder {
    private var storage = DetailedWaiterSummary()
    private var timeoutWaiters: [CheckedContinuation<Void, Never>] = []

    var summary: DetailedWaiterSummary {
        storage
    }

    func recordRecent(_ config: RecentSignatureConfirmationConfig) {
        storage.recentSignature = config.signature
        storage.recentCommitment = config.commitment
    }

    func recordTimeout(_ config: TimeoutPromiseConfig) {
        storage.timeoutCommitment = config.commitment
        let waiters = timeoutWaiters
        timeoutWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
    }

    func waitUntilTimeoutRecorded() async {
        if storage.timeoutCommitment != nil {
            return
        }
        await withCheckedContinuation { continuation in
            timeoutWaiters.append(continuation)
        }
    }
}

private struct DetailedWaiterSummary: Sendable, Equatable {
    var recentSignature: Signature?
    var recentCommitment: Commitment?
    var timeoutCommitment: Commitment?
}
