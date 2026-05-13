public extension SolanaErrorCode {
    static let blockHeightExceeded: Self = 1
    static let invalidNonce: Self = 2
    static let nonceAccountNotFound: Self = 3
    static let blockhashStringLengthOutOfRange: Self = 4
    static let invalidBlockhashByteLength: Self = 5
    static let lamportsOutOfRange: Self = 6
    static let malformedBigintString: Self = 7
    static let malformedNumberString: Self = 8
    static let timestampOutOfRange: Self = 9
    static let malformedJSONRPCError: Self = 10
    static let failedToSendTransaction: Self = 11
    static let failedToSendTransactions: Self = 12
    static let jsonRPCParseError: Self = -32700
    static let jsonRPCInternalError: Self = -32603
    static let jsonRPCInvalidParams: Self = -32602
    static let jsonRPCMethodNotFound: Self = -32601
    static let jsonRPCInvalidRequest: Self = -32600
    static let jsonRPCServerErrorLongTermStorageUnreachable: Self = -32019
    static let jsonRPCServerErrorSlotNotEpochBoundary: Self = -32018
    static let jsonRPCServerErrorEpochRewardsPeriodActive: Self = -32017
    static let jsonRPCServerErrorMinContextSlotNotReached: Self = -32016
    static let jsonRPCServerErrorUnsupportedTransactionVersion: Self = -32015
    static let jsonRPCServerErrorBlockStatusNotAvailableYet: Self = -32014
    static let jsonRPCServerErrorTransactionSignatureLenMismatch: Self = -32013
    static let jsonRPCScanError: Self = -32012
    static let jsonRPCServerErrorTransactionHistoryNotAvailable: Self = -32011
    static let jsonRPCServerErrorKeyExcludedFromSecondaryIndex: Self = -32010
    static let jsonRPCServerErrorLongTermStorageSlotSkipped: Self = -32009
    static let jsonRPCServerErrorNoSnapshot: Self = -32008
    static let jsonRPCServerErrorSlotSkipped: Self = -32007
    static let jsonRPCServerErrorTransactionPrecompileVerificationFailure: Self = -32006
    static let jsonRPCServerErrorNodeUnhealthy: Self = -32005
    static let jsonRPCServerErrorBlockNotAvailable: Self = -32004
    static let jsonRPCServerErrorTransactionSignatureVerificationFailure: Self = -32003
    static let jsonRPCServerErrorSendTransactionPreflightFailure: Self = -32002
    static let jsonRPCServerErrorBlockCleanedUp: Self = -32001
    static let addressesInvalidByteLength: Self = 2800000
    static let addressesStringLengthOutOfRange: Self = 2800001
    static let addressesInvalidBase58EncodedAddress: Self = 2800002
    static let addressesInvalidEd25519PublicKey: Self = 2800003
    static let addressesMalformedPDA: Self = 2800004
    static let addressesPDABumpSeedOutOfRange: Self = 2800005
    static let addressesMaxNumberOfPDASeedsExceeded: Self = 2800006
    static let addressesMaxPDASeedLengthExceeded: Self = 2800007
    static let addressesInvalidSeedsPointOnCurve: Self = 2800008
    static let addressesFailedToFindViablePDABumpSeed: Self = 2800009
    static let addressesPDAEndsWithPDAMarker: Self = 2800010
    static let addressesInvalidOffCurveAddress: Self = 2800011
    static let accountsAccountNotFound: Self = 3230000
    static let accountsOneOrMoreAccountsNotFound: Self = 32300001
    static let accountsFailedToDecodeAccount: Self = 3230002
    static let accountsExpectedDecodedAccount: Self = 3230003
    static let accountsExpectedAllAccountsToBeDecoded: Self = 3230004
    static let subtleCryptoDisallowedInInsecureContext: Self = 3610000
    static let subtleCryptoDigestUnimplemented: Self = 3610001
    static let subtleCryptoEd25519AlgorithmUnimplemented: Self = 3610002
    static let subtleCryptoExportFunctionUnimplemented: Self = 3610003
    static let subtleCryptoGenerateFunctionUnimplemented: Self = 3610004
    static let subtleCryptoSignFunctionUnimplemented: Self = 3610005
    static let subtleCryptoVerifyFunctionUnimplemented: Self = 3610006
    static let subtleCryptoCannotExportNonExtractableKey: Self = 3610007
    static let cryptoRandomValuesFunctionUnimplemented: Self = 3611000
    static let keysInvalidKeyPairByteLength: Self = 3704000
    static let keysInvalidPrivateKeyByteLength: Self = 3704001
    static let keysInvalidSignatureByteLength: Self = 3704002
    static let keysSignatureStringLengthOutOfRange: Self = 3704003
    static let keysPublicKeyMustMatchPrivateKey: Self = 3704004
    static let keysInvalidBase58InGrindRegex: Self = 3704005
    static let keysWriteKeyPairUnsupportedEnvironment: Self = 3704006
    static let fsUnsupportedEnvironment: Self = 3712000
    static let instructionExpectedToHaveAccounts: Self = 4128000
    static let instructionExpectedToHaveData: Self = 4128001
    static let instructionProgramIDMismatch: Self = 4128002
    static let instructionErrorUnknown: Self = 4615000
    static let instructionErrorGenericError: Self = 4615001
    static let instructionErrorInvalidArgument: Self = 4615002
    static let instructionErrorInvalidInstructionData: Self = 4615003
    static let instructionErrorInvalidAccountData: Self = 4615004
    static let instructionErrorAccountDataTooSmall: Self = 4615005
    static let instructionErrorInsufficientFunds: Self = 4615006
    static let instructionErrorIncorrectProgramID: Self = 4615007
    static let instructionErrorMissingRequiredSignature: Self = 4615008
    static let instructionErrorAccountAlreadyInitialized: Self = 4615009
    static let instructionErrorUninitializedAccount: Self = 4615010
    static let instructionErrorUnbalancedInstruction: Self = 4615011
    static let instructionErrorModifiedProgramID: Self = 4615012
    static let instructionErrorExternalAccountLamportSpend: Self = 4615013
    static let instructionErrorExternalAccountDataModified: Self = 4615014
    static let instructionErrorReadonlyLamportChange: Self = 4615015
    static let instructionErrorReadonlyDataModified: Self = 4615016
    static let instructionErrorDuplicateAccountIndex: Self = 4615017
    static let instructionErrorExecutableModified: Self = 4615018
    static let instructionErrorRentEpochModified: Self = 4615019
    static let instructionErrorNotEnoughAccountKeys: Self = 4615020
    static let instructionErrorAccountDataSizeChanged: Self = 4615021
    static let instructionErrorAccountNotExecutable: Self = 4615022
    static let instructionErrorAccountBorrowFailed: Self = 4615023
    static let instructionErrorAccountBorrowOutstanding: Self = 4615024
    static let instructionErrorDuplicateAccountOutOfSync: Self = 4615025
    static let instructionErrorCustom: Self = 4615026
    static let instructionErrorInvalidError: Self = 4615027
    static let instructionErrorExecutableDataModified: Self = 4615028
    static let instructionErrorExecutableLamportChange: Self = 4615029
    static let instructionErrorExecutableAccountNotRentExempt: Self = 4615030
    static let instructionErrorUnsupportedProgramID: Self = 4615031
    static let instructionErrorCallDepth: Self = 4615032
    static let instructionErrorMissingAccount: Self = 4615033
    static let instructionErrorReentrancyNotAllowed: Self = 4615034
    static let instructionErrorMaxSeedLengthExceeded: Self = 4615035
    static let instructionErrorInvalidSeeds: Self = 4615036
    static let instructionErrorInvalidRealloc: Self = 4615037
    static let instructionErrorComputationalBudgetExceeded: Self = 4615038
    static let instructionErrorPrivilegeEscalation: Self = 4615039
    static let instructionErrorProgramEnvironmentSetupFailure: Self = 4615040
    static let instructionErrorProgramFailedToComplete: Self = 4615041
    static let instructionErrorProgramFailedToCompile: Self = 4615042
    static let instructionErrorImmutable: Self = 4615043
    static let instructionErrorIncorrectAuthority: Self = 4615044
    static let instructionErrorBorshIoError: Self = 4615045
    static let instructionErrorAccountNotRentExempt: Self = 4615046
    static let instructionErrorInvalidAccountOwner: Self = 4615047
    static let instructionErrorArithmeticOverflow: Self = 4615048
    static let instructionErrorUnsupportedSysvar: Self = 4615049
    static let instructionErrorIllegalOwner: Self = 4615050
    static let instructionErrorMaxAccountsDataAllocationsExceeded: Self = 4615051
    static let instructionErrorMaxAccountsExceeded: Self = 4615052
    static let instructionErrorMaxInstructionTraceLengthExceeded: Self = 4615053
    static let instructionErrorBuiltinProgramsMustConsumeComputeUnits: Self = 4615054
    static let signerAddressCannotHaveMultipleSigners: Self = 5508000
    static let signerExpectedKeyPairSigner: Self = 5508001
    static let signerExpectedMessageSigner: Self = 5508002
    static let signerExpectedMessageModifyingSigner: Self = 5508003
    static let signerExpectedMessagePartialSigner: Self = 5508004
    static let signerExpectedTransactionSigner: Self = 5508005
    static let signerExpectedTransactionModifyingSigner: Self = 5508006
    static let signerExpectedTransactionPartialSigner: Self = 5508007
    static let signerExpectedTransactionSendingSigner: Self = 5508008
    static let signerTransactionCannotHaveMultipleSendingSigners: Self = 5508009
    static let signerTransactionSendingSignerMissing: Self = 5508010
    static let signerWalletMultisignUnimplemented: Self = 5508011
    static let signerWalletAccountCannotSignTransaction: Self = 5508012
    static let offchainMessageMaximumLengthExceeded: Self = 5607000
    static let offchainMessageRestrictedAsciiBodyCharacterOutOfRange: Self = 5607001
    static let offchainMessageApplicationDomainStringLengthOutOfRange: Self = 5607002
    static let offchainMessageInvalidApplicationDomainByteLength: Self = 5607003
    static let offchainMessageNumSignaturesMismatch: Self = 5607004
    static let offchainMessageNumRequiredSignersCannotBeZero: Self = 5607005
    static let offchainMessageVersionNumberNotSupported: Self = 5607006
    static let offchainMessageMessageFormatMismatch: Self = 5607007
    static let offchainMessageMessageLengthMismatch: Self = 5607008
    static let offchainMessageMessageMustBeNonEmpty: Self = 5607009
    static let offchainMessageNumEnvelopeSignaturesCannotBeZero: Self = 5607010
    static let offchainMessageSignaturesMissing: Self = 5607011
    static let offchainMessageEnvelopeSignersMismatch: Self = 5607012
    static let offchainMessageAddressesCannotSignOffchainMessage: Self = 5607013
    static let offchainMessageUnexpectedVersion: Self = 5607014
    static let offchainMessageSignatoriesMustBeSorted: Self = 5607015
    static let offchainMessageSignatoriesMustBeUnique: Self = 5607016
    static let offchainMessageSignatureVerificationFailure: Self = 5607017
    static let transactionInvokedProgramsCannotPayFees: Self = 5663000
    static let transactionInvokedProgramsMustNotBeWritable: Self = 5663001
    static let transactionExpectedBlockhashLifetime: Self = 5663002
    static let transactionExpectedNonceLifetime: Self = 5663003
    static let transactionVersionNumberOutOfRange: Self = 5663004
    static let transactionFailedToDecompileAddressLookupTableContentsMissing: Self = 5663005
    static let transactionFailedToDecompileAddressLookupTableIndexOutOfRange: Self = 5663006
    static let transactionFailedToDecompileInstructionProgramAddressNotFound: Self = 5663007
    static let transactionFailedToDecompileFeePayerMissing: Self = 5663008
    static let transactionSignaturesMissing: Self = 5663009
    static let transactionAddressMissing: Self = 5663010
    static let transactionFeePayerMissing: Self = 5663011
    static let transactionFeePayerSignatureMissing: Self = 5663012
    static let transactionInvalidNonceTransactionInstructionsMissing: Self = 5663013
    static let transactionInvalidNonceTransactionFirstInstructionMustBeAdvanceNonce: Self = 5663014
    static let transactionAddressesCannotSignTransaction: Self = 5663015
    static let transactionCannotEncodeWithEmptySignatures: Self = 5663016
    static let transactionMessageSignaturesMismatch: Self = 5663017
    static let transactionFailedToEstimateComputeLimit: Self = 5663018
    static let transactionFailedWhenSimulatingToEstimateComputeLimit: Self = 5663019
    static let transactionExceedsSizeLimit: Self = 5663020
    static let transactionVersionNumberNotSupported: Self = 5663021
    static let transactionNonceAccountCannotBeInLookupTable: Self = 5663022
    static let transactionMalformedMessageBytes: Self = 5663023
    static let transactionCannotEncodeWithEmptyMessageBytes: Self = 5663024
    static let transactionCannotDecodeEmptyTransactionBytes: Self = 5663025
    static let transactionVersionZeroMustBeEncodedWithSignaturesFirst: Self = 5663026
    static let transactionSignatureCountTooHighForTransactionBytes: Self = 5663027
    static let transactionInvalidConfigMaskPriorityFeeBits: Self = 5663028
    static let transactionInvalidNonceAccountIndex: Self = 5663029
    static let transactionInvalidConfigValueKind: Self = 5663030
    static let transactionInstructionHeadersPayloadsMismatch: Self = 5663031
    static let transactionTooManySignerAddresses: Self = 5663032
    static let transactionTooManyAccountAddresses: Self = 5663033
    static let transactionTooManyInstructions: Self = 5663034
    static let transactionTooManyAccountsInInstruction: Self = 5663035
    static let transactionErrorUnknown: Self = 7050000
    static let transactionErrorAccountInUse: Self = 7050001
    static let transactionErrorAccountLoadedTwice: Self = 7050002
    static let transactionErrorAccountNotFound: Self = 7050003
    static let transactionErrorProgramAccountNotFound: Self = 7050004
    static let transactionErrorInsufficientFundsForFee: Self = 7050005
    static let transactionErrorInvalidAccountForFee: Self = 7050006
    static let transactionErrorAlreadyProcessed: Self = 7050007
    static let transactionErrorBlockhashNotFound: Self = 7050008
    static let transactionErrorCallChainTooDeep: Self = 7050009
    static let transactionErrorMissingSignatureForFee: Self = 7050010
    static let transactionErrorInvalidAccountIndex: Self = 7050011
    static let transactionErrorSignatureFailure: Self = 7050012
    static let transactionErrorInvalidProgramForExecution: Self = 7050013
    static let transactionErrorSanitizeFailure: Self = 7050014
    static let transactionErrorClusterMaintenance: Self = 7050015
    static let transactionErrorAccountBorrowOutstanding: Self = 7050016
    static let transactionErrorWouldExceedMaxBlockCostLimit: Self = 7050017
    static let transactionErrorUnsupportedVersion: Self = 7050018
    static let transactionErrorInvalidWritableAccount: Self = 7050019
    static let transactionErrorWouldExceedMaxAccountCostLimit: Self = 7050020
    static let transactionErrorWouldExceedAccountDataBlockLimit: Self = 7050021
    static let transactionErrorTooManyAccountLocks: Self = 7050022
    static let transactionErrorAddressLookupTableNotFound: Self = 7050023
    static let transactionErrorInvalidAddressLookupTableOwner: Self = 7050024
    static let transactionErrorInvalidAddressLookupTableData: Self = 7050025
    static let transactionErrorInvalidAddressLookupTableIndex: Self = 7050026
    static let transactionErrorInvalidRentPayingAccount: Self = 7050027
    static let transactionErrorWouldExceedMaxVoteCostLimit: Self = 7050028
    static let transactionErrorWouldExceedAccountDataTotalLimit: Self = 7050029
    static let transactionErrorDuplicateInstruction: Self = 7050030
    static let transactionErrorInsufficientFundsForRent: Self = 7050031
    static let transactionErrorMaxLoadedAccountsDataSizeExceeded: Self = 7050032
    static let transactionErrorInvalidLoadedAccountsDataSizeLimit: Self = 7050033
    static let transactionErrorResanitizationNeeded: Self = 7050034
    static let transactionErrorProgramExecutionTemporarilyRestricted: Self = 7050035
    static let transactionErrorUnbalancedTransaction: Self = 7050036
    static let instructionPlansMessageCannotAccommodatePlan: Self = 7618000
    static let instructionPlansMessagePackerAlreadyComplete: Self = 7618001
    static let instructionPlansEmptyInstructionPlan: Self = 7618002
    static let instructionPlansFailedToExecuteTransactionPlan: Self = 7618003
    static let instructionPlansNonDivisibleTransactionPlansNotSupported: Self = 7618004
    static let instructionPlansFailedSingleTransactionPlanResultNotFound: Self = 7618005
    static let instructionPlansUnexpectedInstructionPlan: Self = 7618006
    static let instructionPlansUnexpectedTransactionPlan: Self = 7618007
    static let instructionPlansUnexpectedTransactionPlanResult: Self = 7618008
    static let instructionPlansExpectedSuccessfulTransactionPlanResult: Self = 7618009
    static let codecsCannotDecodeEmptyByteArray: Self = 8078000
    static let codecsInvalidByteLength: Self = 8078001
    static let codecsExpectedFixedLength: Self = 8078002
    static let codecsExpectedVariableLength: Self = 8078003
    static let codecsEncoderDecoderSizeCompatibilityMismatch: Self = 8078004
    static let codecsEncoderDecoderFixedSizeMismatch: Self = 8078005
    static let codecsEncoderDecoderMaxSizeMismatch: Self = 8078006
    static let codecsInvalidNumberOfItems: Self = 8078007
    static let codecsEnumDiscriminatorOutOfRange: Self = 8078008
    static let codecsInvalidDiscriminatedUnionVariant: Self = 8078009
    static let codecsInvalidEnumVariant: Self = 8078010
    static let codecsNumberOutOfRange: Self = 8078011
    static let codecsInvalidStringForBase: Self = 8078012
    static let codecsExpectedPositiveByteLength: Self = 8078013
    static let codecsOffsetOutOfRange: Self = 8078014
    static let codecsInvalidLiteralUnionVariant: Self = 8078015
    static let codecsLiteralUnionDiscriminatorOutOfRange: Self = 8078016
    static let codecsUnionVariantOutOfRange: Self = 8078017
    static let codecsInvalidConstant: Self = 8078018
    static let codecsExpectedZeroValueToMatchItemFixedSize: Self = 8078019
    static let codecsEncodedBytesMustNotIncludeSentinel: Self = 8078020
    static let codecsSentinelMissingInDecodedBytes: Self = 8078021
    static let codecsCannotUseLexicalValuesAsEnumDiscriminators: Self = 8078022
    static let codecsExpectedDecoderToConsumeEntireByteArray: Self = 8078023
    static let codecsInvalidPatternMatchValue: Self = 8078024
    static let codecsInvalidPatternMatchBytes: Self = 8078025
    static let fixedPointsInvalidTotalBits: Self = 8090000
    static let fixedPointsInvalidFractionalBits: Self = 8090001
    static let fixedPointsInvalidDecimals: Self = 8090002
    static let fixedPointsFractionalBitsExceedTotalBits: Self = 8090003
    static let fixedPointsValueOutOfRange: Self = 8090004
    static let fixedPointsInvalidString: Self = 8090005
    static let fixedPointsInvalidZeroDenominatorRatio: Self = 8090006
    static let fixedPointsArithmeticOverflow: Self = 8090007
    static let fixedPointsShapeMismatch: Self = 8090008
    static let fixedPointsDivisionByZero: Self = 8090009
    static let fixedPointsStrictModePrecisionLoss: Self = 8090010
    static let fixedPointsMalformedRawValue: Self = 8090011
    static let fixedPointsTotalBitsNotByteAligned: Self = 8090012
    static let rpcIntegerOverflow: Self = 8100000
    static let rpcTransportHTTPHeaderForbidden: Self = 8100001
    static let rpcTransportHTTPError: Self = 8100002
    static let rpcAPIPlanMissingForRPCMethod: Self = 8100003
    static let rpcSubscriptionsCannotCreateSubscriptionPlan: Self = 8190000
    static let rpcSubscriptionsExpectedServerSubscriptionID: Self = 8190001
    static let rpcSubscriptionsChannelClosedBeforeMessageBuffered: Self = 8190002
    static let rpcSubscriptionsChannelConnectionClosed: Self = 8190003
    static let rpcSubscriptionsChannelFailedToConnect: Self = 8190004
    static let subscribableRetryNotSupported: Self = 8195000
    static let programClientsInsufficientAccountMetas: Self = 8500000
    static let programClientsUnrecognizedInstructionType: Self = 8500001
    static let programClientsFailedToIdentifyInstruction: Self = 8500002
    static let programClientsUnexpectedResolvedInstructionInputType: Self = 8500003
    static let programClientsResolvedInstructionInputMustBeNonNull: Self = 8500004
    static let programClientsUnrecognizedAccountType: Self = 8500005
    static let programClientsFailedToIdentifyAccount: Self = 8500006
    static let walletNotConnected: Self = 8900000
    static let walletNoSignerConnected: Self = 8900001
    static let walletSignerNotAvailable: Self = 8900002
    static let invariantViolationSubscriptionIteratorStateMissing: Self = 9900000
    static let invariantViolationSubscriptionIteratorMustNotPollBeforeResolvingExistingMessagePromise: Self = 9900001
    static let invariantViolationCachedAbortableIterableCacheEntryMissing: Self = 9900002
    static let invariantViolationSwitchMustBeExhaustive: Self = 9900003
    static let invariantViolationDataPublisherChannelUnimplemented: Self = 9900004
    static let invariantViolationInvalidInstructionPlanKind: Self = 9900005
    static let invariantViolationInvalidTransactionPlanKind: Self = 9900006
}

let solanaErrorMessages: [Int: String] = [
    SolanaErrorCode.blockHeightExceeded.rawValue: "The network has progressed past the last block for which this transaction could have been committed.",
    SolanaErrorCode.invalidNonce.rawValue: "The nonce `$expectedNonceValue` is no longer valid. It has advanced to `$actualNonceValue`",
    SolanaErrorCode.nonceAccountNotFound.rawValue: "No nonce account could be found at address `$nonceAccountAddress`",
    SolanaErrorCode.blockhashStringLengthOutOfRange.rawValue: "Expected base58-encoded blockhash string of length in the range [32, 44]. Actual length: $actualLength.",
    SolanaErrorCode.invalidBlockhashByteLength.rawValue: "Expected base58 encoded blockhash to decode to a byte array of length 32. Actual length: $actualLength.",
    SolanaErrorCode.lamportsOutOfRange.rawValue: "Lamports value must be in the range [0, 2e64-1]",
    SolanaErrorCode.malformedBigintString.rawValue: "`$value` cannot be parsed as a `BigInt`",
    SolanaErrorCode.malformedNumberString.rawValue: "`$value` cannot be parsed as a `Number`",
    SolanaErrorCode.timestampOutOfRange.rawValue: "Timestamp value must be in the range [-(2n ** 63n), (2n ** 63n) - 1]. `$value` given",
    SolanaErrorCode.malformedJSONRPCError.rawValue: "$message",
    SolanaErrorCode.failedToSendTransaction.rawValue: "Failed to send transaction$causeMessage",
    SolanaErrorCode.failedToSendTransactions.rawValue: "Failed to send transactions$causeMessages",
    SolanaErrorCode.jsonRPCParseError.rawValue: "JSON-RPC error: An error occurred on the server while parsing the JSON text ($__serverMessage)",
    SolanaErrorCode.jsonRPCInternalError.rawValue: "JSON-RPC error: Internal JSON-RPC error ($__serverMessage)",
    SolanaErrorCode.jsonRPCInvalidParams.rawValue: "JSON-RPC error: Invalid method parameter(s) ($__serverMessage)",
    SolanaErrorCode.jsonRPCMethodNotFound.rawValue: "JSON-RPC error: The method does not exist / is not available ($__serverMessage)",
    SolanaErrorCode.jsonRPCInvalidRequest.rawValue: "JSON-RPC error: The JSON sent is not a valid `Request` object ($__serverMessage)",
    SolanaErrorCode.jsonRPCServerErrorLongTermStorageUnreachable.rawValue: "Failed to query long-term storage; please try again",
    SolanaErrorCode.jsonRPCServerErrorSlotNotEpochBoundary.rawValue: "Rewards cannot be found because slot $slot is not the epoch boundary. This may be due to gap in the queried node's local ledger or long-term storage",
    SolanaErrorCode.jsonRPCServerErrorEpochRewardsPeriodActive.rawValue: "Epoch rewards period still active at slot $slot",
    SolanaErrorCode.jsonRPCServerErrorMinContextSlotNotReached.rawValue: "Minimum context slot has not been reached",
    SolanaErrorCode.jsonRPCServerErrorUnsupportedTransactionVersion.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorBlockStatusNotAvailableYet.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorTransactionSignatureLenMismatch.rawValue: "Transaction signature length mismatch",
    SolanaErrorCode.jsonRPCScanError.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorTransactionHistoryNotAvailable.rawValue: "Transaction history is not available from this node",
    SolanaErrorCode.jsonRPCServerErrorKeyExcludedFromSecondaryIndex.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorLongTermStorageSlotSkipped.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorNoSnapshot.rawValue: "No snapshot",
    SolanaErrorCode.jsonRPCServerErrorSlotSkipped.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorTransactionPrecompileVerificationFailure.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorNodeUnhealthy.rawValue: "Node is unhealthy; behind by $numSlotsBehind slots",
    SolanaErrorCode.jsonRPCServerErrorBlockNotAvailable.rawValue: "$__serverMessage",
    SolanaErrorCode.jsonRPCServerErrorTransactionSignatureVerificationFailure.rawValue: "Transaction signature verification failure",
    SolanaErrorCode.jsonRPCServerErrorSendTransactionPreflightFailure.rawValue: "Transaction simulation failed",
    SolanaErrorCode.jsonRPCServerErrorBlockCleanedUp.rawValue: "$__serverMessage",
    SolanaErrorCode.addressesInvalidByteLength.rawValue: "Expected base58 encoded address to decode to a byte array of length 32. Actual length: $actualLength.",
    SolanaErrorCode.addressesStringLengthOutOfRange.rawValue: "Expected base58-encoded address string of length in the range [32, 44]. Actual length: $actualLength.",
    SolanaErrorCode.addressesInvalidBase58EncodedAddress.rawValue: "$putativeAddress is not a base58-encoded address.",
    SolanaErrorCode.addressesInvalidEd25519PublicKey.rawValue: "The `CryptoKey` must be an `Ed25519` public key.",
    SolanaErrorCode.addressesMalformedPDA.rawValue: "Expected given program derived address to have the following format: [Address, ProgramDerivedAddressBump].",
    SolanaErrorCode.addressesPDABumpSeedOutOfRange.rawValue: "Expected program derived address bump to be in the range [0, 255], got: $bump.",
    SolanaErrorCode.addressesMaxNumberOfPDASeedsExceeded.rawValue: "A maximum of $maxSeeds seeds, including the bump seed, may be supplied when creating an address. Received: $actual.",
    SolanaErrorCode.addressesMaxPDASeedLengthExceeded.rawValue: "The seed at index $index with length $actual exceeds the maximum length of $maxSeedLength bytes.",
    SolanaErrorCode.addressesInvalidSeedsPointOnCurve.rawValue: "Invalid seeds; point must fall off the Ed25519 curve.",
    SolanaErrorCode.addressesFailedToFindViablePDABumpSeed.rawValue: "Unable to find a viable program address bump seed.",
    SolanaErrorCode.addressesPDAEndsWithPDAMarker.rawValue: "Program address cannot end with PDA marker.",
    SolanaErrorCode.addressesInvalidOffCurveAddress.rawValue: "$putativeOffCurveAddress is not a base58-encoded off-curve address.",
    SolanaErrorCode.accountsAccountNotFound.rawValue: "Account not found at address: $address",
    SolanaErrorCode.accountsOneOrMoreAccountsNotFound.rawValue: "Accounts not found at addresses: $addresses",
    SolanaErrorCode.accountsFailedToDecodeAccount.rawValue: "Failed to decode account data at address: $address",
    SolanaErrorCode.accountsExpectedDecodedAccount.rawValue: "Expected decoded account at address: $address",
    SolanaErrorCode.accountsExpectedAllAccountsToBeDecoded.rawValue: "Not all accounts were decoded. Encoded accounts found at addresses: $addresses.",
    SolanaErrorCode.subtleCryptoDisallowedInInsecureContext.rawValue: "Cryptographic operations are only allowed in secure browser contexts. Read more here: https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts.",
    SolanaErrorCode.subtleCryptoDigestUnimplemented.rawValue: "No digest implementation could be found.",
    SolanaErrorCode.subtleCryptoEd25519AlgorithmUnimplemented.rawValue: "This runtime does not support the generation of Ed25519 key pairs.\n\nInstall @solana/webcrypto-ed25519-polyfill and call its `install` function before generating keys in environments that do not support Ed25519.\n\nFor a list of runtimes that currently support Ed25519 operations, visit https://github.com/WICG/webcrypto-secure-curves/issues/20.",
    SolanaErrorCode.subtleCryptoExportFunctionUnimplemented.rawValue: "No key export implementation could be found.",
    SolanaErrorCode.subtleCryptoGenerateFunctionUnimplemented.rawValue: "No key generation implementation could be found.",
    SolanaErrorCode.subtleCryptoSignFunctionUnimplemented.rawValue: "No signing implementation could be found.",
    SolanaErrorCode.subtleCryptoVerifyFunctionUnimplemented.rawValue: "No signature verification implementation could be found.",
    SolanaErrorCode.subtleCryptoCannotExportNonExtractableKey.rawValue: "Cannot export a non-extractable key.",
    SolanaErrorCode.cryptoRandomValuesFunctionUnimplemented.rawValue: "No random values implementation could be found.",
    SolanaErrorCode.keysInvalidKeyPairByteLength.rawValue: "Key pair bytes must be of length 64, got $byteLength.",
    SolanaErrorCode.keysInvalidPrivateKeyByteLength.rawValue: "Expected private key bytes with length 32. Actual length: $actualLength.",
    SolanaErrorCode.keysInvalidSignatureByteLength.rawValue: "Expected base58-encoded signature to decode to a byte array of length 64. Actual length: $actualLength.",
    SolanaErrorCode.keysSignatureStringLengthOutOfRange.rawValue: "Expected base58-encoded signature string of length in the range [64, 88]. Actual length: $actualLength.",
    SolanaErrorCode.keysPublicKeyMustMatchPrivateKey.rawValue: "The provided private key does not match the provided public key.",
    SolanaErrorCode.keysInvalidBase58InGrindRegex.rawValue: "The grind regex `/$source/` contains the character `$character`, which is not in the base58 alphabet and can never match a Solana address.",
    SolanaErrorCode.keysWriteKeyPairUnsupportedEnvironment.rawValue: "Writing a key pair to disk is not supported in this environment.",
    SolanaErrorCode.fsUnsupportedEnvironment.rawValue: "Filesystem operation `$operation` is not supported in this environment.",
    SolanaErrorCode.instructionExpectedToHaveAccounts.rawValue: "The instruction does not have any accounts.",
    SolanaErrorCode.instructionExpectedToHaveData.rawValue: "The instruction does not have any data.",
    SolanaErrorCode.instructionProgramIDMismatch.rawValue: "Expected instruction to have progress address $expectedProgramAddress, got $actualProgramAddress.",
    SolanaErrorCode.instructionErrorUnknown.rawValue: "The instruction failed with the error: $errorName",
    SolanaErrorCode.instructionErrorGenericError.rawValue: "Generic instruction error",
    SolanaErrorCode.instructionErrorInvalidArgument.rawValue: "Invalid program argument",
    SolanaErrorCode.instructionErrorInvalidInstructionData.rawValue: "Invalid instruction data",
    SolanaErrorCode.instructionErrorInvalidAccountData.rawValue: "Invalid account data for instruction",
    SolanaErrorCode.instructionErrorAccountDataTooSmall.rawValue: "Account data too small for instruction",
    SolanaErrorCode.instructionErrorInsufficientFunds.rawValue: "Insufficient funds for instruction",
    SolanaErrorCode.instructionErrorIncorrectProgramID.rawValue: "Incorrect program id for instruction",
    SolanaErrorCode.instructionErrorMissingRequiredSignature.rawValue: "Missing required signature for instruction",
    SolanaErrorCode.instructionErrorAccountAlreadyInitialized.rawValue: "Instruction requires an uninitialized account",
    SolanaErrorCode.instructionErrorUninitializedAccount.rawValue: "Instruction requires an initialized account",
    SolanaErrorCode.instructionErrorUnbalancedInstruction.rawValue: "Sum of account balances before and after instruction do not match",
    SolanaErrorCode.instructionErrorModifiedProgramID.rawValue: "Instruction illegally modified the program id of an account",
    SolanaErrorCode.instructionErrorExternalAccountLamportSpend.rawValue: "Instruction spent from the balance of an account it does not own",
    SolanaErrorCode.instructionErrorExternalAccountDataModified.rawValue: "Instruction modified data of an account it does not own",
    SolanaErrorCode.instructionErrorReadonlyLamportChange.rawValue: "Instruction changed the balance of a read-only account",
    SolanaErrorCode.instructionErrorReadonlyDataModified.rawValue: "Instruction modified data of a read-only account",
    SolanaErrorCode.instructionErrorDuplicateAccountIndex.rawValue: "Instruction contains duplicate accounts",
    SolanaErrorCode.instructionErrorExecutableModified.rawValue: "Instruction changed executable bit of an account",
    SolanaErrorCode.instructionErrorRentEpochModified.rawValue: "Instruction modified rent epoch of an account",
    SolanaErrorCode.instructionErrorNotEnoughAccountKeys.rawValue: "Insufficient account keys for instruction",
    SolanaErrorCode.instructionErrorAccountDataSizeChanged.rawValue: "Program other than the account's owner changed the size of the account data",
    SolanaErrorCode.instructionErrorAccountNotExecutable.rawValue: "Instruction expected an executable account",
    SolanaErrorCode.instructionErrorAccountBorrowFailed.rawValue: "Instruction tries to borrow reference for an account which is already borrowed",
    SolanaErrorCode.instructionErrorAccountBorrowOutstanding.rawValue: "Instruction left account with an outstanding borrowed reference",
    SolanaErrorCode.instructionErrorDuplicateAccountOutOfSync.rawValue: "Instruction modifications of multiply-passed account differ",
    SolanaErrorCode.instructionErrorCustom.rawValue: "Custom program error: #$code",
    SolanaErrorCode.instructionErrorInvalidError.rawValue: "Program returned invalid error code",
    SolanaErrorCode.instructionErrorExecutableDataModified.rawValue: "Instruction changed executable accounts data",
    SolanaErrorCode.instructionErrorExecutableLamportChange.rawValue: "Instruction changed the balance of an executable account",
    SolanaErrorCode.instructionErrorExecutableAccountNotRentExempt.rawValue: "Executable accounts must be rent exempt",
    SolanaErrorCode.instructionErrorUnsupportedProgramID.rawValue: "Unsupported program id",
    SolanaErrorCode.instructionErrorCallDepth.rawValue: "Cross-program invocation call depth too deep",
    SolanaErrorCode.instructionErrorMissingAccount.rawValue: "An account required by the instruction is missing",
    SolanaErrorCode.instructionErrorReentrancyNotAllowed.rawValue: "Cross-program invocation reentrancy not allowed for this instruction",
    SolanaErrorCode.instructionErrorMaxSeedLengthExceeded.rawValue: "Length of the seed is too long for address generation",
    SolanaErrorCode.instructionErrorInvalidSeeds.rawValue: "Provided seeds do not result in a valid address",
    SolanaErrorCode.instructionErrorInvalidRealloc.rawValue: "Failed to reallocate account data",
    SolanaErrorCode.instructionErrorComputationalBudgetExceeded.rawValue: "Computational budget exceeded",
    SolanaErrorCode.instructionErrorPrivilegeEscalation.rawValue: "Cross-program invocation with unauthorized signer or writable account",
    SolanaErrorCode.instructionErrorProgramEnvironmentSetupFailure.rawValue: "Failed to create program execution environment",
    SolanaErrorCode.instructionErrorProgramFailedToComplete.rawValue: "Program failed to complete",
    SolanaErrorCode.instructionErrorProgramFailedToCompile.rawValue: "Program failed to compile",
    SolanaErrorCode.instructionErrorImmutable.rawValue: "Account is immutable",
    SolanaErrorCode.instructionErrorIncorrectAuthority.rawValue: "Incorrect authority provided",
    SolanaErrorCode.instructionErrorBorshIoError.rawValue: "Failed to serialize or deserialize account data",
    SolanaErrorCode.instructionErrorAccountNotRentExempt.rawValue: "An account does not have enough lamports to be rent-exempt",
    SolanaErrorCode.instructionErrorInvalidAccountOwner.rawValue: "Invalid account owner",
    SolanaErrorCode.instructionErrorArithmeticOverflow.rawValue: "Program arithmetic overflowed",
    SolanaErrorCode.instructionErrorUnsupportedSysvar.rawValue: "Unsupported sysvar",
    SolanaErrorCode.instructionErrorIllegalOwner.rawValue: "Provided owner is not allowed",
    SolanaErrorCode.instructionErrorMaxAccountsDataAllocationsExceeded.rawValue: "Accounts data allocations exceeded the maximum allowed per transaction",
    SolanaErrorCode.instructionErrorMaxAccountsExceeded.rawValue: "Max accounts exceeded",
    SolanaErrorCode.instructionErrorMaxInstructionTraceLengthExceeded.rawValue: "Max instruction trace length exceeded",
    SolanaErrorCode.instructionErrorBuiltinProgramsMustConsumeComputeUnits.rawValue: "Builtin programs must consume compute units",
    SolanaErrorCode.signerAddressCannotHaveMultipleSigners.rawValue: "Multiple distinct signers were identified for address `$address`. Please ensure that you are using the same signer instance for each address.",
    SolanaErrorCode.signerExpectedKeyPairSigner.rawValue: "The provided value does not implement the `KeyPairSigner` interface",
    SolanaErrorCode.signerExpectedMessageSigner.rawValue: "The provided value does not implement any of the `MessageSigner` interfaces",
    SolanaErrorCode.signerExpectedMessageModifyingSigner.rawValue: "The provided value does not implement the `MessageModifyingSigner` interface",
    SolanaErrorCode.signerExpectedMessagePartialSigner.rawValue: "The provided value does not implement the `MessagePartialSigner` interface",
    SolanaErrorCode.signerExpectedTransactionSigner.rawValue: "The provided value does not implement any of the `TransactionSigner` interfaces",
    SolanaErrorCode.signerExpectedTransactionModifyingSigner.rawValue: "The provided value does not implement the `TransactionModifyingSigner` interface",
    SolanaErrorCode.signerExpectedTransactionPartialSigner.rawValue: "The provided value does not implement the `TransactionPartialSigner` interface",
    SolanaErrorCode.signerExpectedTransactionSendingSigner.rawValue: "The provided value does not implement the `TransactionSendingSigner` interface",
    SolanaErrorCode.signerTransactionCannotHaveMultipleSendingSigners.rawValue: "More than one `TransactionSendingSigner` was identified.",
    SolanaErrorCode.signerTransactionSendingSignerMissing.rawValue: "No `TransactionSendingSigner` was identified. Please provide a valid `TransactionWithSingleSendingSigner` transaction.",
    SolanaErrorCode.signerWalletMultisignUnimplemented.rawValue: "Wallet account signers do not support signing multiple messages/transactions in a single operation",
    SolanaErrorCode.signerWalletAccountCannotSignTransaction.rawValue: "The wallet account $address cannot be used to create a transaction signer because it does not implement either the `solana:signTransaction` or `solana:signAndSendTransaction` feature. At least one of these features is required. The account supports the following features: $supportedFeatures.",
    SolanaErrorCode.offchainMessageMaximumLengthExceeded.rawValue: "The message body provided has a byte-length of $actualBytes. The maximum allowable byte-length is $maxBytes",
    SolanaErrorCode.offchainMessageRestrictedAsciiBodyCharacterOutOfRange.rawValue: "The message body provided contains characters whose codes fall outside the allowed range. In order to ensure clear-signing compatiblity with hardware wallets, the message may only contain line feeds and characters in the range [\\x20-\\x7e].",
    SolanaErrorCode.offchainMessageApplicationDomainStringLengthOutOfRange.rawValue: "Expected base58-encoded application domain string of length in the range [32, 44]. Actual length: $actualLength.",
    SolanaErrorCode.offchainMessageInvalidApplicationDomainByteLength.rawValue: "Expected base58 encoded application domain to decode to a byte array of length 32. Actual length: $actualLength.",
    SolanaErrorCode.offchainMessageNumSignaturesMismatch.rawValue: "The offchain message preamble specifies $numRequiredSignatures required signature(s), got $signaturesLength.",
    SolanaErrorCode.offchainMessageNumRequiredSignersCannotBeZero.rawValue: "Offchain message must specify the address of at least one required signer",
    SolanaErrorCode.offchainMessageVersionNumberNotSupported.rawValue: "This version of Kit does not support decoding offchain messages with version $unsupportedVersion. The current max supported version is 0.",
    SolanaErrorCode.offchainMessageMessageFormatMismatch.rawValue: "Expected message format $expectedMessageFormat, got $actualMessageFormat",
    SolanaErrorCode.offchainMessageMessageLengthMismatch.rawValue: "The message length specified in the message preamble is $specifiedLength bytes. The actual length of the message is $actualLength bytes.",
    SolanaErrorCode.offchainMessageMessageMustBeNonEmpty.rawValue: "Offchain message content must be non-empty",
    SolanaErrorCode.offchainMessageNumEnvelopeSignaturesCannotBeZero.rawValue: "Offchain message envelope must reserve space for at least one signature",
    SolanaErrorCode.offchainMessageSignaturesMissing.rawValue: "Offchain message is missing signatures for addresses: $addresses.",
    SolanaErrorCode.offchainMessageEnvelopeSignersMismatch.rawValue: "The signer addresses in this offchain message envelope do not match the list of required signers in the message preamble. These unexpected signers were present in the envelope: `[$unexpectedSigners]`. These required signers were missing from the envelope `[$missingSigners]`.",
    SolanaErrorCode.offchainMessageAddressesCannotSignOffchainMessage.rawValue: "Attempted to sign an offchain message with an address that is not a signer for it",
    SolanaErrorCode.offchainMessageUnexpectedVersion.rawValue: "Expected offchain message version $expectedVersion. Got $actualVersion.",
    SolanaErrorCode.offchainMessageSignatoriesMustBeSorted.rawValue: "The signatories of this offchain message must be listed in lexicographical order",
    SolanaErrorCode.offchainMessageSignatoriesMustBeUnique.rawValue: "An address must be listed no more than once among the signatories of an offchain message",
    SolanaErrorCode.offchainMessageSignatureVerificationFailure.rawValue: "Offchain message signature verification failed. Signature mismatch for required signatories [$signatoriesWithInvalidSignatures]. Missing signatures for signatories [$signatoriesWithMissingSignatures]",
    SolanaErrorCode.transactionInvokedProgramsCannotPayFees.rawValue: "This transaction includes an address (`$programAddress`) which is both invoked and set as the fee payer. Program addresses may not pay fees",
    SolanaErrorCode.transactionInvokedProgramsMustNotBeWritable.rawValue: "This transaction includes an address (`$programAddress`) which is both invoked and marked writable. Program addresses may not be writable",
    SolanaErrorCode.transactionExpectedBlockhashLifetime.rawValue: "Transaction does not have a blockhash lifetime",
    SolanaErrorCode.transactionExpectedNonceLifetime.rawValue: "Transaction is not a durable nonce transaction",
    SolanaErrorCode.transactionVersionNumberOutOfRange.rawValue: "Transaction version must be in the range [0, 127]. `$actualVersion` given",
    SolanaErrorCode.transactionFailedToDecompileAddressLookupTableContentsMissing.rawValue: "Contents of these address lookup tables unknown: $lookupTableAddresses",
    SolanaErrorCode.transactionFailedToDecompileAddressLookupTableIndexOutOfRange.rawValue: "Lookup of address at index $highestRequestedIndex failed for lookup table `$lookupTableAddress`. Highest known index is $highestKnownIndex. The lookup table may have been extended since its contents were retrieved",
    SolanaErrorCode.transactionFailedToDecompileInstructionProgramAddressNotFound.rawValue: "Could not find program address at index $index",
    SolanaErrorCode.transactionFailedToDecompileFeePayerMissing.rawValue: "No fee payer set in CompiledTransaction",
    SolanaErrorCode.transactionSignaturesMissing.rawValue: "Transaction is missing signatures for addresses: $addresses.",
    SolanaErrorCode.transactionAddressMissing.rawValue: "Transaction is missing an address at index: $index.",
    SolanaErrorCode.transactionFeePayerMissing.rawValue: "Transaction is missing a fee payer.",
    SolanaErrorCode.transactionFeePayerSignatureMissing.rawValue: "Could not determine this transaction's signature. Make sure that the transaction has been signed by its fee payer.",
    SolanaErrorCode.transactionInvalidNonceTransactionInstructionsMissing.rawValue: "Transaction with no instructions cannot be durable nonce transaction.",
    SolanaErrorCode.transactionInvalidNonceTransactionFirstInstructionMustBeAdvanceNonce.rawValue: "Transaction first instruction is not advance nonce account instruction.",
    SolanaErrorCode.transactionAddressesCannotSignTransaction.rawValue: "Attempted to sign a transaction with an address that is not a signer for it",
    SolanaErrorCode.transactionCannotEncodeWithEmptySignatures.rawValue: "Transaction has no expected signers therefore it cannot be encoded",
    SolanaErrorCode.transactionMessageSignaturesMismatch.rawValue: "The transaction message expected the transaction to have $numRequiredSignatures signatures, got $signaturesLength.",
    SolanaErrorCode.transactionFailedToEstimateComputeLimit.rawValue: "Failed to estimate the compute unit consumption for this transaction message. This is likely because simulating the transaction failed. Inspect the `cause` property of this error to learn more",
    SolanaErrorCode.transactionFailedWhenSimulatingToEstimateComputeLimit.rawValue: "Transaction failed when it was simulated in order to estimate the compute unit consumption. The compute unit estimate provided is for a transaction that failed when simulated and may not be representative of the compute units this transaction would consume if successful. Inspect the `cause` property of this error to learn more",
    SolanaErrorCode.transactionExceedsSizeLimit.rawValue: "Transaction size $transactionSize exceeds limit of $transactionSizeLimit bytes",
    SolanaErrorCode.transactionVersionNumberNotSupported.rawValue: "This version of Kit does not support decoding transactions with version $unsupportedVersion. The current max supported version is 1.",
    SolanaErrorCode.transactionNonceAccountCannotBeInLookupTable.rawValue: "The transaction has a durable nonce lifetime (with nonce `$nonce`), but the nonce account address is in a lookup table. The lifetime constraint cannot be constructed without fetching the lookup tables for the transaction.",
    SolanaErrorCode.transactionMalformedMessageBytes.rawValue: "Transaction message bytes are malformed: $messageBytes",
    SolanaErrorCode.transactionCannotEncodeWithEmptyMessageBytes.rawValue: "Transaction message bytes are empty, so the transaction cannot be encoded",
    SolanaErrorCode.transactionCannotDecodeEmptyTransactionBytes.rawValue: "Transaction bytes are empty, so no transaction can be decoded",
    SolanaErrorCode.transactionVersionZeroMustBeEncodedWithSignaturesFirst.rawValue: "Transaction version 0 must be encoded with signatures first. This transaction was encoded with first byte $firstByte, which is expected to be a signature count for v0 transactions.",
    SolanaErrorCode.transactionSignatureCountTooHighForTransactionBytes.rawValue: "The provided transaction bytes expect that there should be $numExpectedSignatures signatures, but the bytes are not long enough to contain a transaction message with this many signatures. The provided bytes are $transactionBytesLength bytes long.",
    SolanaErrorCode.transactionInvalidConfigMaskPriorityFeeBits.rawValue: "Invalid transaction config mask: $mask. Bits 0 and 1 must match (both set or both unset)",
    SolanaErrorCode.transactionInvalidNonceAccountIndex.rawValue: "The transaction has a durable nonce lifetime, but the nonce account index is invalid. Expected a nonce account index less than $numberOfStaticAccounts, got $nonceAccountIndex.",
    SolanaErrorCode.transactionInvalidConfigValueKind.rawValue: "The transaction config value for $configName has the incorrect kind. Expected $expectedKind, got $actualKind.",
    SolanaErrorCode.transactionInstructionHeadersPayloadsMismatch.rawValue: "The transaction does not have the same number of instruction headers and instruction payloads. Got $numInstructionHeaders instruction headers, and $numInstructionPayloads instruction payloads.",
    SolanaErrorCode.transactionTooManySignerAddresses.rawValue: "Transaction has $actualCount unique signer addresses but the maximum allowed is $maxAllowed",
    SolanaErrorCode.transactionTooManyAccountAddresses.rawValue: "Transaction has $actualCount unique account addresses but the maximum allowed is $maxAllowed",
    SolanaErrorCode.transactionTooManyInstructions.rawValue: "Transaction has $actualCount instructions but the maximum allowed is $maxAllowed",
    SolanaErrorCode.transactionTooManyAccountsInInstruction.rawValue: "The instruction at index $instructionIndex has $actualCount account references but the maximum allowed is $maxAllowed",
    SolanaErrorCode.transactionErrorUnknown.rawValue: "The transaction failed with the error `$errorName`",
    SolanaErrorCode.transactionErrorAccountInUse.rawValue: "Account in use",
    SolanaErrorCode.transactionErrorAccountLoadedTwice.rawValue: "Account loaded twice",
    SolanaErrorCode.transactionErrorAccountNotFound.rawValue: "Attempt to debit an account but found no record of a prior credit.",
    SolanaErrorCode.transactionErrorProgramAccountNotFound.rawValue: "Attempt to load a program that does not exist",
    SolanaErrorCode.transactionErrorInsufficientFundsForFee.rawValue: "Insufficient funds for fee",
    SolanaErrorCode.transactionErrorInvalidAccountForFee.rawValue: "This account may not be used to pay transaction fees",
    SolanaErrorCode.transactionErrorAlreadyProcessed.rawValue: "This transaction has already been processed",
    SolanaErrorCode.transactionErrorBlockhashNotFound.rawValue: "Blockhash not found",
    SolanaErrorCode.transactionErrorCallChainTooDeep.rawValue: "Loader call chain is too deep",
    SolanaErrorCode.transactionErrorMissingSignatureForFee.rawValue: "Transaction requires a fee but has no signature present",
    SolanaErrorCode.transactionErrorInvalidAccountIndex.rawValue: "Transaction contains an invalid account reference",
    SolanaErrorCode.transactionErrorSignatureFailure.rawValue: "Transaction did not pass signature verification",
    SolanaErrorCode.transactionErrorInvalidProgramForExecution.rawValue: "This program may not be used for executing instructions",
    SolanaErrorCode.transactionErrorSanitizeFailure.rawValue: "Transaction failed to sanitize accounts offsets correctly",
    SolanaErrorCode.transactionErrorClusterMaintenance.rawValue: "Transactions are currently disabled due to cluster maintenance",
    SolanaErrorCode.transactionErrorAccountBorrowOutstanding.rawValue: "Transaction processing left an account with an outstanding borrowed reference",
    SolanaErrorCode.transactionErrorWouldExceedMaxBlockCostLimit.rawValue: "Transaction would exceed max Block Cost Limit",
    SolanaErrorCode.transactionErrorUnsupportedVersion.rawValue: "Transaction version is unsupported",
    SolanaErrorCode.transactionErrorInvalidWritableAccount.rawValue: "Transaction loads a writable account that cannot be written",
    SolanaErrorCode.transactionErrorWouldExceedMaxAccountCostLimit.rawValue: "Transaction would exceed max account limit within the block",
    SolanaErrorCode.transactionErrorWouldExceedAccountDataBlockLimit.rawValue: "Transaction would exceed account data limit within the block",
    SolanaErrorCode.transactionErrorTooManyAccountLocks.rawValue: "Transaction locked too many accounts",
    SolanaErrorCode.transactionErrorAddressLookupTableNotFound.rawValue: "Transaction loads an address table account that doesn't exist",
    SolanaErrorCode.transactionErrorInvalidAddressLookupTableOwner.rawValue: "Transaction loads an address table account with an invalid owner",
    SolanaErrorCode.transactionErrorInvalidAddressLookupTableData.rawValue: "Transaction loads an address table account with invalid data",
    SolanaErrorCode.transactionErrorInvalidAddressLookupTableIndex.rawValue: "Transaction address table lookup uses an invalid index",
    SolanaErrorCode.transactionErrorInvalidRentPayingAccount.rawValue: "Transaction leaves an account with a lower balance than rent-exempt minimum",
    SolanaErrorCode.transactionErrorWouldExceedMaxVoteCostLimit.rawValue: "Transaction would exceed max Vote Cost Limit",
    SolanaErrorCode.transactionErrorWouldExceedAccountDataTotalLimit.rawValue: "Transaction would exceed total account data limit",
    SolanaErrorCode.transactionErrorDuplicateInstruction.rawValue: "Transaction contains a duplicate instruction ($index) that is not allowed",
    SolanaErrorCode.transactionErrorInsufficientFundsForRent.rawValue: "Transaction results in an account ($accountIndex) with insufficient funds for rent",
    SolanaErrorCode.transactionErrorMaxLoadedAccountsDataSizeExceeded.rawValue: "Transaction exceeded max loaded accounts data size cap",
    SolanaErrorCode.transactionErrorInvalidLoadedAccountsDataSizeLimit.rawValue: "LoadedAccountsDataSizeLimit set for transaction must be greater than 0.",
    SolanaErrorCode.transactionErrorResanitizationNeeded.rawValue: "ResanitizationNeeded",
    SolanaErrorCode.transactionErrorProgramExecutionTemporarilyRestricted.rawValue: "Execution of the program referenced by account at index $accountIndex is temporarily restricted.",
    SolanaErrorCode.transactionErrorUnbalancedTransaction.rawValue: "Sum of account balances before and after transaction do not match",
    SolanaErrorCode.instructionPlansMessageCannotAccommodatePlan.rawValue: "The provided message has insufficient capacity to accommodate the next instruction(s) in this plan. Expected at least $numBytesRequired free byte(s), got $numFreeBytes byte(s).",
    SolanaErrorCode.instructionPlansMessagePackerAlreadyComplete.rawValue: "No more instructions to pack; the message packer has completed the instruction plan.",
    SolanaErrorCode.instructionPlansEmptyInstructionPlan.rawValue: "The provided instruction plan is empty.",
    SolanaErrorCode.instructionPlansFailedToExecuteTransactionPlan.rawValue: "The provided transaction plan failed to execute. See the `transactionPlanResult` attribute for more details. Note that the `cause` property is deprecated, and a future version will not set it.",
    SolanaErrorCode.instructionPlansNonDivisibleTransactionPlansNotSupported.rawValue: "This transaction plan executor does not support non-divisible sequential plans. To support them, you may create your own executor such that multi-transaction atomicity is preserved — e.g. by targetting RPCs that support transaction bundles.",
    SolanaErrorCode.instructionPlansFailedSingleTransactionPlanResultNotFound.rawValue: "No failed transaction plan result was found in the provided transaction plan result.",
    SolanaErrorCode.instructionPlansUnexpectedInstructionPlan.rawValue: "Unexpected instruction plan. Expected $expectedKind plan, got $actualKind plan.",
    SolanaErrorCode.instructionPlansUnexpectedTransactionPlan.rawValue: "Unexpected transaction plan. Expected $expectedKind plan, got $actualKind plan.",
    SolanaErrorCode.instructionPlansUnexpectedTransactionPlanResult.rawValue: "Unexpected transaction plan result. Expected $expectedKind plan, got $actualKind plan.",
    SolanaErrorCode.instructionPlansExpectedSuccessfulTransactionPlanResult.rawValue: "Expected a successful transaction plan result. I.e. there is at least one failed or cancelled transaction in the plan.",
    SolanaErrorCode.codecsCannotDecodeEmptyByteArray.rawValue: "Codec [$codecDescription] cannot decode empty byte arrays.",
    SolanaErrorCode.codecsInvalidByteLength.rawValue: "Codec [$codecDescription] expected $expected bytes, got $bytesLength.",
    SolanaErrorCode.codecsExpectedFixedLength.rawValue: "Expected a fixed-size codec, got a variable-size one.",
    SolanaErrorCode.codecsExpectedVariableLength.rawValue: "Expected a variable-size codec, got a fixed-size one.",
    SolanaErrorCode.codecsEncoderDecoderSizeCompatibilityMismatch.rawValue: "Encoder and decoder must either both be fixed-size or variable-size.",
    SolanaErrorCode.codecsEncoderDecoderFixedSizeMismatch.rawValue: "Encoder and decoder must have the same fixed size, got [$encoderFixedSize] and [$decoderFixedSize].",
    SolanaErrorCode.codecsEncoderDecoderMaxSizeMismatch.rawValue: "Encoder and decoder must have the same max size, got [$encoderMaxSize] and [$decoderMaxSize].",
    SolanaErrorCode.codecsInvalidNumberOfItems.rawValue: "Expected [$codecDescription] to have $expected items, got $actual.",
    SolanaErrorCode.codecsEnumDiscriminatorOutOfRange.rawValue: "Enum discriminator out of range. Expected a number in [$formattedValidDiscriminators], got $discriminator.",
    SolanaErrorCode.codecsInvalidDiscriminatedUnionVariant.rawValue: "Invalid discriminated union variant. Expected one of [$variants], got $value.",
    SolanaErrorCode.codecsInvalidEnumVariant.rawValue: "Invalid enum variant. Expected one of [$stringValues] or a number in [$formattedNumericalValues], got $variant.",
    SolanaErrorCode.codecsNumberOutOfRange.rawValue: "Codec [$codecDescription] expected number to be in the range [$min, $max], got $value.",
    SolanaErrorCode.codecsInvalidStringForBase.rawValue: "Invalid value $value for base $base with alphabet $alphabet.",
    SolanaErrorCode.codecsExpectedPositiveByteLength.rawValue: "Codec [$codecDescription] expected a positive byte length, got $bytesLength.",
    SolanaErrorCode.codecsOffsetOutOfRange.rawValue: "Codec [$codecDescription] expected offset to be in the range [0, $bytesLength], got $offset.",
    SolanaErrorCode.codecsInvalidLiteralUnionVariant.rawValue: "Invalid literal union variant. Expected one of [$variants], got $value.",
    SolanaErrorCode.codecsLiteralUnionDiscriminatorOutOfRange.rawValue: "Literal union discriminator out of range. Expected a number between $minRange and $maxRange, got $discriminator.",
    SolanaErrorCode.codecsUnionVariantOutOfRange.rawValue: "Union variant out of range. Expected an index between $minRange and $maxRange, got $variant.",
    SolanaErrorCode.codecsInvalidConstant.rawValue: "Expected byte array constant [$hexConstant] to be present in data [$hexData] at offset [$offset].",
    SolanaErrorCode.codecsExpectedZeroValueToMatchItemFixedSize.rawValue: "Codec [$codecDescription] expected zero-value [$hexZeroValue] to have the same size as the provided fixed-size item [$expectedSize bytes].",
    SolanaErrorCode.codecsEncodedBytesMustNotIncludeSentinel.rawValue: "Sentinel [$hexSentinel] must not be present in encoded bytes [$hexEncodedBytes].",
    SolanaErrorCode.codecsSentinelMissingInDecodedBytes.rawValue: "Expected sentinel [$hexSentinel] to be present in decoded bytes [$hexDecodedBytes].",
    SolanaErrorCode.codecsCannotUseLexicalValuesAsEnumDiscriminators.rawValue: "Enum codec cannot use lexical values [$stringValues] as discriminators. Either remove all lexical values or set `useValuesAsDiscriminators` to `false`.",
    SolanaErrorCode.codecsExpectedDecoderToConsumeEntireByteArray.rawValue: "This decoder expected a byte array of exactly $expectedLength bytes, but $numExcessBytes unexpected excess bytes remained after decoding. Are you sure that you have chosen the correct decoder for this data?",
    SolanaErrorCode.codecsInvalidPatternMatchValue.rawValue: "Invalid pattern match value. The provided value does not match any of the specified patterns.",
    SolanaErrorCode.codecsInvalidPatternMatchBytes.rawValue: "Invalid pattern match bytes. The provided byte array does not match any of the specified patterns.",
    SolanaErrorCode.fixedPointsInvalidTotalBits.rawValue: "Invalid `totalBits`. Expected a positive integer, got $totalBits.",
    SolanaErrorCode.fixedPointsInvalidFractionalBits.rawValue: "Invalid `fractionalBits`. Expected a non-negative integer, got $fractionalBits.",
    SolanaErrorCode.fixedPointsInvalidDecimals.rawValue: "Invalid `decimals`. Expected a non-negative integer, got $decimals.",
    SolanaErrorCode.fixedPointsFractionalBitsExceedTotalBits.rawValue: "`fractionalBits` ($fractionalBits) must not exceed `totalBits` ($totalBits).",
    SolanaErrorCode.fixedPointsValueOutOfRange.rawValue: "Fixed-point value of kind `$kind` is out of range for $signedness $totalBits-bit storage. Expected a raw bigint in [$min, $max], got $raw.",
    SolanaErrorCode.fixedPointsInvalidString.rawValue: "Invalid string `$input` for fixed-point value of kind `$kind`.",
    SolanaErrorCode.fixedPointsInvalidZeroDenominatorRatio.rawValue: "Invalid ratio $numerator/$denominator for fixed-point value of kind `$kind`. Denominator must be non-zero.",
    SolanaErrorCode.fixedPointsArithmeticOverflow.rawValue: "Fixed-point operation `$operation` of kind `$kind` overflowed. Expected a raw bigint in [$min, $max], got $result.",
    SolanaErrorCode.fixedPointsShapeMismatch.rawValue: "Fixed-point `$operation` operation expected $expectedKind ($expectedSignedness, $expectedTotalBits bits, $expectedScale $expectedScaleLabel); got $actualKind ($actualSignedness, $actualTotalBits bits, $actualScale $actualScaleLabel).",
    SolanaErrorCode.fixedPointsDivisionByZero.rawValue: "Fixed-point division by zero for value of kind `$kind` ($signedness, $totalBits bits).",
    SolanaErrorCode.fixedPointsStrictModePrecisionLoss.rawValue: "Fixed-point operation `$operation` of kind `$kind` cannot be performed exactly; pass a rounding mode other than `strict` to allow a rounded result.",
    SolanaErrorCode.fixedPointsMalformedRawValue.rawValue: "Fixed-point value of kind `$kind` has a malformed `raw` field. Expected a bigint, got `$raw`.",
    SolanaErrorCode.fixedPointsTotalBitsNotByteAligned.rawValue: "Fixed-point codec of kind `$kind` requires `totalBits` to be a multiple of 8; got $totalBits.",
    SolanaErrorCode.rpcIntegerOverflow.rawValue: "The $argumentLabel argument to the `$methodName` RPC method$optionalPathLabel was `$value`. This number is unsafe for use with the Solana JSON-RPC because it exceeds `Number.MAX_SAFE_INTEGER`.",
    SolanaErrorCode.rpcTransportHTTPHeaderForbidden.rawValue: "HTTP header(s) forbidden: $headers. Learn more at https://developer.mozilla.org/en-US/docs/Glossary/Forbidden_header_name.",
    SolanaErrorCode.rpcTransportHTTPError.rawValue: "HTTP error ($statusCode): $message",
    SolanaErrorCode.rpcAPIPlanMissingForRPCMethod.rawValue: "Could not find an API plan for RPC method: `$method`",
    SolanaErrorCode.rpcSubscriptionsCannotCreateSubscriptionPlan.rawValue: "The notification name must end in 'Notifications' and the API must supply a subscription plan creator function for the notification '$notificationName'.",
    SolanaErrorCode.rpcSubscriptionsExpectedServerSubscriptionID.rawValue: "Failed to obtain a subscription id from the server",
    SolanaErrorCode.rpcSubscriptionsChannelClosedBeforeMessageBuffered.rawValue: "WebSocket was closed before payload could be added to the send buffer",
    SolanaErrorCode.rpcSubscriptionsChannelConnectionClosed.rawValue: "WebSocket connection closed",
    SolanaErrorCode.rpcSubscriptionsChannelFailedToConnect.rawValue: "WebSocket failed to connect",
    SolanaErrorCode.subscribableRetryNotSupported.rawValue: "This `ReactiveStreamStore` does not support retry. Use `createReactiveStoreFromDataPublisherFactory` to construct a retryable store.",
    SolanaErrorCode.programClientsInsufficientAccountMetas.rawValue: "The provided instruction is missing some accounts. Expected at least $expectedAccountMetas account(s), got $actualAccountMetas.",
    SolanaErrorCode.programClientsUnrecognizedInstructionType.rawValue: "Unrecognized instruction type '$instructionType' for the $programName program.",
    SolanaErrorCode.programClientsFailedToIdentifyInstruction.rawValue: "The provided instruction could not be identified as an instruction from the $programName program.",
    SolanaErrorCode.programClientsUnexpectedResolvedInstructionInputType.rawValue: "Expected resolved instruction input '$inputName' to be of type `$expectedType`.",
    SolanaErrorCode.programClientsResolvedInstructionInputMustBeNonNull.rawValue: "Expected resolved instruction input '$inputName' to be non-null.",
    SolanaErrorCode.programClientsUnrecognizedAccountType.rawValue: "Unrecognized account type '$accountType' for the $programName program.",
    SolanaErrorCode.programClientsFailedToIdentifyAccount.rawValue: "The provided account could not be identified as an account from the $programName program.",
    SolanaErrorCode.walletNotConnected.rawValue: "Cannot $operation: no wallet connected",
    SolanaErrorCode.walletNoSignerConnected.rawValue: "No signing wallet connected (status: $status)",
    SolanaErrorCode.walletSignerNotAvailable.rawValue: "Connected wallet does not support signing",
    SolanaErrorCode.invariantViolationSubscriptionIteratorStateMissing.rawValue: "Invariant violation: WebSocket message iterator is missing state storage. It should be impossible to hit this error; please file an issue at https://sola.na/web3invariant",
    SolanaErrorCode.invariantViolationSubscriptionIteratorMustNotPollBeforeResolvingExistingMessagePromise.rawValue: "Invariant violation: WebSocket message iterator state is corrupt; iterated without first resolving existing message promise. It should be impossible to hit this error; please file an issue at https://sola.na/web3invariant",
    SolanaErrorCode.invariantViolationCachedAbortableIterableCacheEntryMissing.rawValue: "Invariant violation: Found no abortable iterable cache entry for key `$cacheKey`. It should be impossible to hit this error; please file an issue at https://sola.na/web3invariant",
    SolanaErrorCode.invariantViolationSwitchMustBeExhaustive.rawValue: "Invariant violation: Switch statement non-exhaustive. Received unexpected value `$unexpectedValue`. It should be impossible to hit this error; please file an issue at https://sola.na/web3invariant",
    SolanaErrorCode.invariantViolationDataPublisherChannelUnimplemented.rawValue: "Invariant violation: This data publisher does not publish to the channel named `$channelName`. Supported channels include $supportedChannelNames.",
    SolanaErrorCode.invariantViolationInvalidInstructionPlanKind.rawValue: "Invalid instruction plan kind: $kind.",
    SolanaErrorCode.invariantViolationInvalidTransactionPlanKind.rawValue: "Invalid transaction plan kind: $kind."
]
