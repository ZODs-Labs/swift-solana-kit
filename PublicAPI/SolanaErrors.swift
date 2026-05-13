import Foundation

public protocol SolanaErrorCoded: Error, Sendable {
    var code: Int { get }
    var contextDescription: String { get }
}

public struct SolanaErrorCode: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByIntegerLiteral {
    public let rawValue: Int
    public init(rawValue: Int)
    public init(integerLiteral value: Int)
}

public extension SolanaErrorCode {
    static let blockHeightExceeded: Self
    static let invalidNonce: Self
    static let nonceAccountNotFound: Self
    static let blockhashStringLengthOutOfRange: Self
    static let invalidBlockhashByteLength: Self
    static let lamportsOutOfRange: Self
    static let malformedBigintString: Self
    static let malformedNumberString: Self
    static let timestampOutOfRange: Self
    static let malformedJSONRPCError: Self
    static let failedToSendTransaction: Self
    static let failedToSendTransactions: Self
    static let jsonRPCParseError: Self
    static let jsonRPCInternalError: Self
    static let jsonRPCInvalidParams: Self
    static let jsonRPCMethodNotFound: Self
    static let jsonRPCInvalidRequest: Self
    static let jsonRPCServerErrorLongTermStorageUnreachable: Self
    static let jsonRPCServerErrorSlotNotEpochBoundary: Self
    static let jsonRPCServerErrorEpochRewardsPeriodActive: Self
    static let jsonRPCServerErrorMinContextSlotNotReached: Self
    static let jsonRPCServerErrorUnsupportedTransactionVersion: Self
    static let jsonRPCServerErrorBlockStatusNotAvailableYet: Self
    static let jsonRPCServerErrorTransactionSignatureLenMismatch: Self
    static let jsonRPCScanError: Self
    static let jsonRPCServerErrorTransactionHistoryNotAvailable: Self
    static let jsonRPCServerErrorKeyExcludedFromSecondaryIndex: Self
    static let jsonRPCServerErrorLongTermStorageSlotSkipped: Self
    static let jsonRPCServerErrorNoSnapshot: Self
    static let jsonRPCServerErrorSlotSkipped: Self
    static let jsonRPCServerErrorTransactionPrecompileVerificationFailure: Self
    static let jsonRPCServerErrorNodeUnhealthy: Self
    static let jsonRPCServerErrorBlockNotAvailable: Self
    static let jsonRPCServerErrorTransactionSignatureVerificationFailure: Self
    static let jsonRPCServerErrorSendTransactionPreflightFailure: Self
    static let jsonRPCServerErrorBlockCleanedUp: Self
    static let addressesInvalidByteLength: Self
    static let addressesStringLengthOutOfRange: Self
    static let addressesInvalidBase58EncodedAddress: Self
    static let addressesInvalidEd25519PublicKey: Self
    static let addressesMalformedPDA: Self
    static let addressesPDABumpSeedOutOfRange: Self
    static let addressesMaxNumberOfPDASeedsExceeded: Self
    static let addressesMaxPDASeedLengthExceeded: Self
    static let addressesInvalidSeedsPointOnCurve: Self
    static let addressesFailedToFindViablePDABumpSeed: Self
    static let addressesPDAEndsWithPDAMarker: Self
    static let addressesInvalidOffCurveAddress: Self
    static let accountsAccountNotFound: Self
    static let accountsOneOrMoreAccountsNotFound: Self
    static let accountsFailedToDecodeAccount: Self
    static let accountsExpectedDecodedAccount: Self
    static let accountsExpectedAllAccountsToBeDecoded: Self
    static let subtleCryptoDisallowedInInsecureContext: Self
    static let subtleCryptoDigestUnimplemented: Self
    static let subtleCryptoEd25519AlgorithmUnimplemented: Self
    static let subtleCryptoExportFunctionUnimplemented: Self
    static let subtleCryptoGenerateFunctionUnimplemented: Self
    static let subtleCryptoSignFunctionUnimplemented: Self
    static let subtleCryptoVerifyFunctionUnimplemented: Self
    static let subtleCryptoCannotExportNonExtractableKey: Self
    static let cryptoRandomValuesFunctionUnimplemented: Self
    static let keysInvalidKeyPairByteLength: Self
    static let keysInvalidPrivateKeyByteLength: Self
    static let keysInvalidSignatureByteLength: Self
    static let keysSignatureStringLengthOutOfRange: Self
    static let keysPublicKeyMustMatchPrivateKey: Self
    static let keysInvalidBase58InGrindRegex: Self
    static let keysWriteKeyPairUnsupportedEnvironment: Self
    static let fsUnsupportedEnvironment: Self
    static let instructionExpectedToHaveAccounts: Self
    static let instructionExpectedToHaveData: Self
    static let instructionProgramIDMismatch: Self
    static let instructionErrorUnknown: Self
    static let instructionErrorGenericError: Self
    static let instructionErrorInvalidArgument: Self
    static let instructionErrorInvalidInstructionData: Self
    static let instructionErrorInvalidAccountData: Self
    static let instructionErrorAccountDataTooSmall: Self
    static let instructionErrorInsufficientFunds: Self
    static let instructionErrorIncorrectProgramID: Self
    static let instructionErrorMissingRequiredSignature: Self
    static let instructionErrorAccountAlreadyInitialized: Self
    static let instructionErrorUninitializedAccount: Self
    static let instructionErrorUnbalancedInstruction: Self
    static let instructionErrorModifiedProgramID: Self
    static let instructionErrorExternalAccountLamportSpend: Self
    static let instructionErrorExternalAccountDataModified: Self
    static let instructionErrorReadonlyLamportChange: Self
    static let instructionErrorReadonlyDataModified: Self
    static let instructionErrorDuplicateAccountIndex: Self
    static let instructionErrorExecutableModified: Self
    static let instructionErrorRentEpochModified: Self
    static let instructionErrorNotEnoughAccountKeys: Self
    static let instructionErrorAccountDataSizeChanged: Self
    static let instructionErrorAccountNotExecutable: Self
    static let instructionErrorAccountBorrowFailed: Self
    static let instructionErrorAccountBorrowOutstanding: Self
    static let instructionErrorDuplicateAccountOutOfSync: Self
    static let instructionErrorCustom: Self
    static let instructionErrorInvalidError: Self
    static let instructionErrorExecutableDataModified: Self
    static let instructionErrorExecutableLamportChange: Self
    static let instructionErrorExecutableAccountNotRentExempt: Self
    static let instructionErrorUnsupportedProgramID: Self
    static let instructionErrorCallDepth: Self
    static let instructionErrorMissingAccount: Self
    static let instructionErrorReentrancyNotAllowed: Self
    static let instructionErrorMaxSeedLengthExceeded: Self
    static let instructionErrorInvalidSeeds: Self
    static let instructionErrorInvalidRealloc: Self
    static let instructionErrorComputationalBudgetExceeded: Self
    static let instructionErrorPrivilegeEscalation: Self
    static let instructionErrorProgramEnvironmentSetupFailure: Self
    static let instructionErrorProgramFailedToComplete: Self
    static let instructionErrorProgramFailedToCompile: Self
    static let instructionErrorImmutable: Self
    static let instructionErrorIncorrectAuthority: Self
    static let instructionErrorBorshIoError: Self
    static let instructionErrorAccountNotRentExempt: Self
    static let instructionErrorInvalidAccountOwner: Self
    static let instructionErrorArithmeticOverflow: Self
    static let instructionErrorUnsupportedSysvar: Self
    static let instructionErrorIllegalOwner: Self
    static let instructionErrorMaxAccountsDataAllocationsExceeded: Self
    static let instructionErrorMaxAccountsExceeded: Self
    static let instructionErrorMaxInstructionTraceLengthExceeded: Self
    static let instructionErrorBuiltinProgramsMustConsumeComputeUnits: Self
    static let signerAddressCannotHaveMultipleSigners: Self
    static let signerExpectedKeyPairSigner: Self
    static let signerExpectedMessageSigner: Self
    static let signerExpectedMessageModifyingSigner: Self
    static let signerExpectedMessagePartialSigner: Self
    static let signerExpectedTransactionSigner: Self
    static let signerExpectedTransactionModifyingSigner: Self
    static let signerExpectedTransactionPartialSigner: Self
    static let signerExpectedTransactionSendingSigner: Self
    static let signerTransactionCannotHaveMultipleSendingSigners: Self
    static let signerTransactionSendingSignerMissing: Self
    static let signerWalletMultisignUnimplemented: Self
    static let signerWalletAccountCannotSignTransaction: Self
    static let offchainMessageMaximumLengthExceeded: Self
    static let offchainMessageRestrictedAsciiBodyCharacterOutOfRange: Self
    static let offchainMessageApplicationDomainStringLengthOutOfRange: Self
    static let offchainMessageInvalidApplicationDomainByteLength: Self
    static let offchainMessageNumSignaturesMismatch: Self
    static let offchainMessageNumRequiredSignersCannotBeZero: Self
    static let offchainMessageVersionNumberNotSupported: Self
    static let offchainMessageMessageFormatMismatch: Self
    static let offchainMessageMessageLengthMismatch: Self
    static let offchainMessageMessageMustBeNonEmpty: Self
    static let offchainMessageNumEnvelopeSignaturesCannotBeZero: Self
    static let offchainMessageSignaturesMissing: Self
    static let offchainMessageEnvelopeSignersMismatch: Self
    static let offchainMessageAddressesCannotSignOffchainMessage: Self
    static let offchainMessageUnexpectedVersion: Self
    static let offchainMessageSignatoriesMustBeSorted: Self
    static let offchainMessageSignatoriesMustBeUnique: Self
    static let offchainMessageSignatureVerificationFailure: Self
    static let transactionInvokedProgramsCannotPayFees: Self
    static let transactionInvokedProgramsMustNotBeWritable: Self
    static let transactionExpectedBlockhashLifetime: Self
    static let transactionExpectedNonceLifetime: Self
    static let transactionVersionNumberOutOfRange: Self
    static let transactionFailedToDecompileAddressLookupTableContentsMissing: Self
    static let transactionFailedToDecompileAddressLookupTableIndexOutOfRange: Self
    static let transactionFailedToDecompileInstructionProgramAddressNotFound: Self
    static let transactionFailedToDecompileFeePayerMissing: Self
    static let transactionSignaturesMissing: Self
    static let transactionAddressMissing: Self
    static let transactionFeePayerMissing: Self
    static let transactionFeePayerSignatureMissing: Self
    static let transactionInvalidNonceTransactionInstructionsMissing: Self
    static let transactionInvalidNonceTransactionFirstInstructionMustBeAdvanceNonce: Self
    static let transactionAddressesCannotSignTransaction: Self
    static let transactionCannotEncodeWithEmptySignatures: Self
    static let transactionMessageSignaturesMismatch: Self
    static let transactionFailedToEstimateComputeLimit: Self
    static let transactionFailedWhenSimulatingToEstimateComputeLimit: Self
    static let transactionExceedsSizeLimit: Self
    static let transactionVersionNumberNotSupported: Self
    static let transactionNonceAccountCannotBeInLookupTable: Self
    static let transactionMalformedMessageBytes: Self
    static let transactionCannotEncodeWithEmptyMessageBytes: Self
    static let transactionCannotDecodeEmptyTransactionBytes: Self
    static let transactionVersionZeroMustBeEncodedWithSignaturesFirst: Self
    static let transactionSignatureCountTooHighForTransactionBytes: Self
    static let transactionInvalidConfigMaskPriorityFeeBits: Self
    static let transactionInvalidNonceAccountIndex: Self
    static let transactionInvalidConfigValueKind: Self
    static let transactionInstructionHeadersPayloadsMismatch: Self
    static let transactionTooManySignerAddresses: Self
    static let transactionTooManyAccountAddresses: Self
    static let transactionTooManyInstructions: Self
    static let transactionTooManyAccountsInInstruction: Self
    static let transactionErrorUnknown: Self
    static let transactionErrorAccountInUse: Self
    static let transactionErrorAccountLoadedTwice: Self
    static let transactionErrorAccountNotFound: Self
    static let transactionErrorProgramAccountNotFound: Self
    static let transactionErrorInsufficientFundsForFee: Self
    static let transactionErrorInvalidAccountForFee: Self
    static let transactionErrorAlreadyProcessed: Self
    static let transactionErrorBlockhashNotFound: Self
    static let transactionErrorCallChainTooDeep: Self
    static let transactionErrorMissingSignatureForFee: Self
    static let transactionErrorInvalidAccountIndex: Self
    static let transactionErrorSignatureFailure: Self
    static let transactionErrorInvalidProgramForExecution: Self
    static let transactionErrorSanitizeFailure: Self
    static let transactionErrorClusterMaintenance: Self
    static let transactionErrorAccountBorrowOutstanding: Self
    static let transactionErrorWouldExceedMaxBlockCostLimit: Self
    static let transactionErrorUnsupportedVersion: Self
    static let transactionErrorInvalidWritableAccount: Self
    static let transactionErrorWouldExceedMaxAccountCostLimit: Self
    static let transactionErrorWouldExceedAccountDataBlockLimit: Self
    static let transactionErrorTooManyAccountLocks: Self
    static let transactionErrorAddressLookupTableNotFound: Self
    static let transactionErrorInvalidAddressLookupTableOwner: Self
    static let transactionErrorInvalidAddressLookupTableData: Self
    static let transactionErrorInvalidAddressLookupTableIndex: Self
    static let transactionErrorInvalidRentPayingAccount: Self
    static let transactionErrorWouldExceedMaxVoteCostLimit: Self
    static let transactionErrorWouldExceedAccountDataTotalLimit: Self
    static let transactionErrorDuplicateInstruction: Self
    static let transactionErrorInsufficientFundsForRent: Self
    static let transactionErrorMaxLoadedAccountsDataSizeExceeded: Self
    static let transactionErrorInvalidLoadedAccountsDataSizeLimit: Self
    static let transactionErrorResanitizationNeeded: Self
    static let transactionErrorProgramExecutionTemporarilyRestricted: Self
    static let transactionErrorUnbalancedTransaction: Self
    static let instructionPlansMessageCannotAccommodatePlan: Self
    static let instructionPlansMessagePackerAlreadyComplete: Self
    static let instructionPlansEmptyInstructionPlan: Self
    static let instructionPlansFailedToExecuteTransactionPlan: Self
    static let instructionPlansNonDivisibleTransactionPlansNotSupported: Self
    static let instructionPlansFailedSingleTransactionPlanResultNotFound: Self
    static let instructionPlansUnexpectedInstructionPlan: Self
    static let instructionPlansUnexpectedTransactionPlan: Self
    static let instructionPlansUnexpectedTransactionPlanResult: Self
    static let instructionPlansExpectedSuccessfulTransactionPlanResult: Self
    static let codecsCannotDecodeEmptyByteArray: Self
    static let codecsInvalidByteLength: Self
    static let codecsExpectedFixedLength: Self
    static let codecsExpectedVariableLength: Self
    static let codecsEncoderDecoderSizeCompatibilityMismatch: Self
    static let codecsEncoderDecoderFixedSizeMismatch: Self
    static let codecsEncoderDecoderMaxSizeMismatch: Self
    static let codecsInvalidNumberOfItems: Self
    static let codecsEnumDiscriminatorOutOfRange: Self
    static let codecsInvalidDiscriminatedUnionVariant: Self
    static let codecsInvalidEnumVariant: Self
    static let codecsNumberOutOfRange: Self
    static let codecsInvalidStringForBase: Self
    static let codecsExpectedPositiveByteLength: Self
    static let codecsOffsetOutOfRange: Self
    static let codecsInvalidLiteralUnionVariant: Self
    static let codecsLiteralUnionDiscriminatorOutOfRange: Self
    static let codecsUnionVariantOutOfRange: Self
    static let codecsInvalidConstant: Self
    static let codecsExpectedZeroValueToMatchItemFixedSize: Self
    static let codecsEncodedBytesMustNotIncludeSentinel: Self
    static let codecsSentinelMissingInDecodedBytes: Self
    static let codecsCannotUseLexicalValuesAsEnumDiscriminators: Self
    static let codecsExpectedDecoderToConsumeEntireByteArray: Self
    static let codecsInvalidPatternMatchValue: Self
    static let codecsInvalidPatternMatchBytes: Self
    static let fixedPointsInvalidTotalBits: Self
    static let fixedPointsInvalidFractionalBits: Self
    static let fixedPointsInvalidDecimals: Self
    static let fixedPointsFractionalBitsExceedTotalBits: Self
    static let fixedPointsValueOutOfRange: Self
    static let fixedPointsInvalidString: Self
    static let fixedPointsInvalidZeroDenominatorRatio: Self
    static let fixedPointsArithmeticOverflow: Self
    static let fixedPointsShapeMismatch: Self
    static let fixedPointsDivisionByZero: Self
    static let fixedPointsStrictModePrecisionLoss: Self
    static let fixedPointsMalformedRawValue: Self
    static let fixedPointsTotalBitsNotByteAligned: Self
    static let rpcIntegerOverflow: Self
    static let rpcTransportHTTPHeaderForbidden: Self
    static let rpcTransportHTTPError: Self
    static let rpcAPIPlanMissingForRPCMethod: Self
    static let rpcSubscriptionsCannotCreateSubscriptionPlan: Self
    static let rpcSubscriptionsExpectedServerSubscriptionID: Self
    static let rpcSubscriptionsChannelClosedBeforeMessageBuffered: Self
    static let rpcSubscriptionsChannelConnectionClosed: Self
    static let rpcSubscriptionsChannelFailedToConnect: Self
    static let subscribableRetryNotSupported: Self
    static let programClientsInsufficientAccountMetas: Self
    static let programClientsUnrecognizedInstructionType: Self
    static let programClientsFailedToIdentifyInstruction: Self
    static let programClientsUnexpectedResolvedInstructionInputType: Self
    static let programClientsResolvedInstructionInputMustBeNonNull: Self
    static let programClientsUnrecognizedAccountType: Self
    static let programClientsFailedToIdentifyAccount: Self
    static let walletNotConnected: Self
    static let walletNoSignerConnected: Self
    static let walletSignerNotAvailable: Self
    static let invariantViolationSubscriptionIteratorStateMissing: Self
    static let invariantViolationSubscriptionIteratorMustNotPollBeforeResolvingExistingMessagePromise: Self
    static let invariantViolationCachedAbortableIterableCacheEntryMissing: Self
    static let invariantViolationSwitchMustBeExhaustive: Self
    static let invariantViolationDataPublisherChannelUnimplemented: Self
    static let invariantViolationInvalidInstructionPlanKind: Self
    static let invariantViolationInvalidTransactionPlanKind: Self
}

public enum SolanaErrorContextValue: Sendable, Equatable, Codable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case uint(UInt64)
    case bool(Bool)
    case bytes(Data)
    case stringArray([String])
    case intArray([Int])
    public var description: String {
        get
    }
}

public struct SolanaErrorContext: Sendable, Equatable, Codable, ExpressibleByDictionaryLiteral {
    public var values: [String: SolanaErrorContextValue]
    public static let empty: SolanaErrorContext
    public init()
    public init(_ values: [String: SolanaErrorContextValue])
    public init(dictionaryLiteral elements: (String, SolanaErrorContextValue)...)
    public subscript(_: String) -> SolanaErrorContextValue? {
        get
    }
}

public struct SolanaError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    public let solanaCode: SolanaErrorCode
    public let context: SolanaErrorContext
    public var code: Int {
        get
    }

    public var contextDescription: String {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }

    public init(_ code: SolanaErrorCode, context: SolanaErrorContext = .empty)
}

public enum CodecsError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case cannotDecodeEmptyByteArray(codecDescription: String)
    case invalidByteLength(codecDescription: String, expected: Int, bytesLength: Int)
    case expectedFixedLength
    case expectedVariableLength
    case encoderDecoderSizeCompatibilityMismatch
    case encoderDecoderFixedSizeMismatch(encoderFixedSize: Int, decoderFixedSize: Int)
    case encoderDecoderMaxSizeMismatch(encoderMaxSize: Int?, decoderMaxSize: Int?)
    case invalidNumberOfItems(codecDescription: String, expected: Int, actual: Int)
    case enumDiscriminatorOutOfRange(discriminator: Int, formattedValidDiscriminators: String, validDiscriminators: [Int])
    case invalidDiscriminatedUnionVariant(value: String, variants: [String])
    case invalidEnumVariant(variant: String, stringValues: [String], numericalValues: [Int], formattedNumericalValues: String)
    case numberOutOfRange(codecDescription: String, min: String, max: String, value: String)
    case invalidStringForBase(value: String, base: Int, alphabet: String)
    case expectedPositiveByteLength(codecDescription: String, bytesLength: Int)
    case offsetOutOfRange(codecDescription: String, offset: Int, bytesLength: Int)
    case invalidLiteralUnionVariant(value: String, variants: [String])
    case literalUnionDiscriminatorOutOfRange(discriminator: Int, minRange: Int, maxRange: Int)
    case unionVariantOutOfRange(variant: Int, minRange: Int, maxRange: Int)
    case invalidConstant(constant: Data, data: Data, offset: Int)
    case expectedZeroValueToMatchItemFixedSize(codecDescription: String, zeroValue: Data, expectedSize: Int)
    case encodedBytesMustNotIncludeSentinel(encodedBytes: Data, sentinel: Data)
    case sentinelMissingInDecodedBytes(decodedBytes: Data, sentinel: Data)
    case cannotUseLexicalValuesAsEnumDiscriminators(stringValues: [String])
    case expectedDecoderToConsumeEntireByteArray(expectedLength: Int, numExcessBytes: Int)
    case invalidPatternMatchBytes
    case invalidPatternMatchValue
    public var code: Int {
        get
    }

    public var context: SolanaErrorContext {
        get
    }

    public var contextDescription: String {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }
}

public enum AddressError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case invalidByteLength(actualLength: Int)
    case stringLengthOutOfRange(actualLength: Int)
    case invalidBase58EncodedAddress
    case invalidEd25519PublicKey
    case malformedPDA
    case pdaBumpSeedOutOfRange(bump: Int)
    case maxNumberOfPDASeedsExceeded(actual: Int, maxSeeds: Int)
    case maxPDASeedLengthExceeded(actual: Int, index: Int, maxSeedLength: Int)
    case invalidSeedsPointOnCurve
    case failedToFindViablePDABumpSeed
    case pdaEndsWithPDAMarker
    case invalidOffCurveAddress
    public var code: Int {
        get
    }

    public var errorDescription: String? {
        get
    }

    public var contextDescription: String {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }

    public var context: SolanaErrorContext {
        get
    }
}

public enum CryptoError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case randomValuesFunctionUnimplemented
    public var code: Int {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }
}

public enum SubtleCryptoError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case disallowedInInsecureContext
    case digestUnimplemented
    case ed25519AlgorithmUnimplemented
    case exportFunctionUnimplemented
    case generateFunctionUnimplemented
    case signFunctionUnimplemented
    case verifyFunctionUnimplemented
    case cannotExportNonExtractableKey
    public var code: Int {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }
}

public enum KeysError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case invalidKeyPairByteLength(byteLength: Int)
    case invalidPrivateKeyByteLength(actualLength: Int)
    case invalidSignatureByteLength(actualLength: Int)
    case signatureStringLengthOutOfRange(actualLength: Int)
    case publicKeyMustMatchPrivateKey
    case invalidBase58InGrindRegex
    case writeKeyPairUnsupportedEnvironment
    public var code: Int {
        get
    }

    public var context: SolanaErrorContext {
        get
    }

    public var contextDescription: String {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }
}

public enum SignerError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case addressCannotHaveMultipleSigners
    case expectedKeyPairSigner
    case expectedMessageSigner
    case expectedMessageModifyingSigner
    case expectedMessagePartialSigner
    case expectedTransactionSigner
    case expectedTransactionModifyingSigner
    case expectedTransactionPartialSigner
    case expectedTransactionSendingSigner
    case transactionCannotHaveMultipleSendingSigners
    case transactionSendingSignerMissing
    case walletMultisignUnimplemented
    case walletAccountCannotSignTransaction
    public var code: Int {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }
}

public enum TransactionError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case invokedProgramsCannotPayFees
    case invokedProgramsMustNotBeWritable
    case expectedBlockhashLifetime
    case expectedNonceLifetime
    case versionNumberOutOfRange
    case signaturesMissing(addresses: [String])
    case addressMissing
    case feePayerMissing
    case feePayerSignatureMissing
    case addressesCannotSignTransaction
    case cannotEncodeWithEmptySignatures
    case messageSignaturesMismatch
    case exceedsSizeLimit
    case versionNumberNotSupported
    case malformedMessageBytes
    case cannotEncodeWithEmptyMessageBytes
    case cannotDecodeEmptyTransactionBytes
    public var code: Int {
        get
    }

    public var context: SolanaErrorContext {
        get
    }

    public var contextDescription: String {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }
}

public enum RpcError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case jsonRPC(code: Int, message: String)
    case integerOverflow
    case transportHTTPHeaderForbidden(headerName: String)
    case transportHTTPError(statusCode: Int, message: String)
    case apiPlanMissingForRPCMethod(method: String)
    public var code: Int {
        get
    }

    public var context: SolanaErrorContext {
        get
    }

    public var contextDescription: String {
        get
    }

    public var errorDescription: String? {
        get
    }

    public static var errorDomain: String {
        get
    }

    public var errorCode: Int {
        get
    }

    public var errorUserInfo: [String: Any] {
        get
    }
}

public func solanaErrorMessage(code: SolanaErrorCode, context: SolanaErrorContext = .empty) -> String
