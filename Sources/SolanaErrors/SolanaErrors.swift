public import Foundation

public protocol SolanaErrorCoded: Error, Sendable {
    var code: Int { get }
    var contextDescription: String { get }
}

public struct SolanaErrorCode: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByIntegerLiteral {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        rawValue = value
    }
}

public indirect enum SolanaErrorContextValue: Sendable, Equatable, Codable, CustomStringConvertible {
    case null
    case string(String)
    case int(Int)
    case uint(UInt64)
    case bigint(String)
    case bool(Bool)
    case bytes(Data)
    case stringArray([String])
    case intArray([Int])
    case array([SolanaErrorContextValue])
    case object([String: SolanaErrorContextValue])

    public var description: String {
        switch self {
        case .null:
            return "null"
        case let .string(value):
            return value
        case let .int(value):
            return String(value)
        case let .uint(value):
            return String(value)
        case let .bigint(value):
            return value
        case let .bool(value):
            return String(value)
        case let .bytes(value):
            return value.map(String.init).joined(separator: ",")
        case let .stringArray(value):
            return value.joined(separator: ",")
        case let .intArray(value):
            return value.map(String.init).joined(separator: ",")
        case let .array(value):
            return "[" + value.map(\.description).joined(separator: ",") + "]"
        case let .object(value):
            return "{" + value.keys.sorted().map { key in "\(key):\(value[key]?.description ?? "null")" }.joined(separator: ",") + "}"
        }
    }
}

public struct SolanaErrorContext: Sendable, Equatable, Codable, ExpressibleByDictionaryLiteral {
    public var values: [String: SolanaErrorContextValue]

    public static let empty = SolanaErrorContext()

    public init() {
        values = [:]
    }

    public init(_ values: [String: SolanaErrorContextValue]) {
        self.values = values
    }

    public init(dictionaryLiteral elements: (String, SolanaErrorContextValue)...) {
        var out: [String: SolanaErrorContextValue] = [:]
        for (key, value) in elements {
            out[key] = value
        }
        values = out
    }

    public subscript(_ key: String) -> SolanaErrorContextValue? {
        values[key]
    }
}

public extension SolanaErrorCoded {
    var contextDescription: String {
        ""
    }
}

public struct SolanaError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    public let solanaCode: SolanaErrorCode
    public let context: SolanaErrorContext

    public var code: Int {
        solanaCode.rawValue
    }

    public var contextDescription: String {
        context.renderedDescription
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: solanaCode, context: context)
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        [
            NSLocalizedDescriptionKey: errorDescription ?? "Solana error #\(code)",
            "context": contextDescription,
        ]
    }

    public init(_ code: SolanaErrorCode, context: SolanaErrorContext = .empty) {
        solanaCode = code
        self.context = context
    }
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
    case invalidEnumVariant(
        variant: String,
        stringValues: [String],
        numericalValues: [Int],
        formattedNumericalValues: String
    )
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
    case wrappedSolanaError(code: Int, context: SolanaErrorContext)

    public var code: Int {
        switch self {
        case .cannotDecodeEmptyByteArray:
            return SolanaErrorCode.codecsCannotDecodeEmptyByteArray.rawValue
        case .invalidByteLength:
            return SolanaErrorCode.codecsInvalidByteLength.rawValue
        case .expectedFixedLength:
            return SolanaErrorCode.codecsExpectedFixedLength.rawValue
        case .expectedVariableLength:
            return SolanaErrorCode.codecsExpectedVariableLength.rawValue
        case .encoderDecoderSizeCompatibilityMismatch:
            return SolanaErrorCode.codecsEncoderDecoderSizeCompatibilityMismatch.rawValue
        case .encoderDecoderFixedSizeMismatch:
            return SolanaErrorCode.codecsEncoderDecoderFixedSizeMismatch.rawValue
        case .encoderDecoderMaxSizeMismatch:
            return SolanaErrorCode.codecsEncoderDecoderMaxSizeMismatch.rawValue
        case .invalidNumberOfItems:
            return SolanaErrorCode.codecsInvalidNumberOfItems.rawValue
        case .enumDiscriminatorOutOfRange:
            return SolanaErrorCode.codecsEnumDiscriminatorOutOfRange.rawValue
        case .invalidDiscriminatedUnionVariant:
            return SolanaErrorCode.codecsInvalidDiscriminatedUnionVariant.rawValue
        case .invalidEnumVariant:
            return SolanaErrorCode.codecsInvalidEnumVariant.rawValue
        case .numberOutOfRange:
            return SolanaErrorCode.codecsNumberOutOfRange.rawValue
        case .invalidStringForBase:
            return SolanaErrorCode.codecsInvalidStringForBase.rawValue
        case .expectedPositiveByteLength:
            return SolanaErrorCode.codecsExpectedPositiveByteLength.rawValue
        case .offsetOutOfRange:
            return SolanaErrorCode.codecsOffsetOutOfRange.rawValue
        case .invalidLiteralUnionVariant:
            return SolanaErrorCode.codecsInvalidLiteralUnionVariant.rawValue
        case .literalUnionDiscriminatorOutOfRange:
            return SolanaErrorCode.codecsLiteralUnionDiscriminatorOutOfRange.rawValue
        case .unionVariantOutOfRange:
            return SolanaErrorCode.codecsUnionVariantOutOfRange.rawValue
        case .invalidConstant:
            return SolanaErrorCode.codecsInvalidConstant.rawValue
        case .expectedZeroValueToMatchItemFixedSize:
            return SolanaErrorCode.codecsExpectedZeroValueToMatchItemFixedSize.rawValue
        case .encodedBytesMustNotIncludeSentinel:
            return SolanaErrorCode.codecsEncodedBytesMustNotIncludeSentinel.rawValue
        case .sentinelMissingInDecodedBytes:
            return SolanaErrorCode.codecsSentinelMissingInDecodedBytes.rawValue
        case .cannotUseLexicalValuesAsEnumDiscriminators:
            return SolanaErrorCode.codecsCannotUseLexicalValuesAsEnumDiscriminators.rawValue
        case .expectedDecoderToConsumeEntireByteArray:
            return SolanaErrorCode.codecsExpectedDecoderToConsumeEntireByteArray.rawValue
        case .invalidPatternMatchBytes:
            return SolanaErrorCode.codecsInvalidPatternMatchBytes.rawValue
        case .invalidPatternMatchValue:
            return SolanaErrorCode.codecsInvalidPatternMatchValue.rawValue
        case let .wrappedSolanaError(code, _):
            return code
        }
    }

    public var context: SolanaErrorContext {
        switch self {
        case let .cannotDecodeEmptyByteArray(codecDescription):
            return ["codecDescription": .string(codecDescription)]
        case let .invalidByteLength(codecDescription, expected, bytesLength):
            return [
                "bytesLength": .int(bytesLength),
                "codecDescription": .string(codecDescription),
                "expected": .int(expected),
            ]
        case .expectedFixedLength, .expectedVariableLength, .encoderDecoderSizeCompatibilityMismatch,
             .invalidPatternMatchBytes, .invalidPatternMatchValue:
            return .empty
        case let .wrappedSolanaError(_, context):
            return context
        case let .encoderDecoderFixedSizeMismatch(encoderFixedSize, decoderFixedSize):
            return ["decoderFixedSize": .int(decoderFixedSize), "encoderFixedSize": .int(encoderFixedSize)]
        case let .encoderDecoderMaxSizeMismatch(encoderMaxSize, decoderMaxSize):
            var values: [String: SolanaErrorContextValue] = [:]
            if let encoderMaxSize {
                values["encoderMaxSize"] = .int(encoderMaxSize)
            }
            if let decoderMaxSize {
                values["decoderMaxSize"] = .int(decoderMaxSize)
            }
            return SolanaErrorContext(values)
        case let .invalidNumberOfItems(codecDescription, expected, actual):
            return ["actual": .int(actual), "codecDescription": .string(codecDescription), "expected": .int(expected)]
        case let .enumDiscriminatorOutOfRange(discriminator, formattedValidDiscriminators, validDiscriminators):
            return [
                "discriminator": .int(discriminator),
                "formattedValidDiscriminators": .string(formattedValidDiscriminators),
                "validDiscriminators": .intArray(validDiscriminators),
            ]
        case let .invalidDiscriminatedUnionVariant(value, variants):
            return ["value": .string(value), "variants": .stringArray(variants)]
        case let .invalidEnumVariant(variant, stringValues, numericalValues, formattedNumericalValues):
            return [
                "formattedNumericalValues": .string(formattedNumericalValues),
                "numericalValues": .intArray(numericalValues),
                "stringValues": .stringArray(stringValues),
                "variant": .string(variant),
            ]
        case let .numberOutOfRange(codecDescription, min, max, value):
            return [
                "codecDescription": .string(codecDescription),
                "max": .string(max),
                "min": .string(min),
                "value": .string(value),
            ]
        case let .invalidStringForBase(value, base, alphabet):
            return ["alphabet": .string(alphabet), "base": .int(base), "value": .string(value)]
        case let .expectedPositiveByteLength(codecDescription, bytesLength):
            return ["bytesLength": .int(bytesLength), "codecDescription": .string(codecDescription)]
        case let .offsetOutOfRange(codecDescription, offset, bytesLength):
            return ["bytesLength": .int(bytesLength), "codecDescription": .string(codecDescription), "offset": .int(offset)]
        case let .invalidLiteralUnionVariant(value, variants):
            return ["value": .string(value), "variants": .stringArray(variants)]
        case let .literalUnionDiscriminatorOutOfRange(discriminator, minRange, maxRange):
            return ["discriminator": .int(discriminator), "maxRange": .int(maxRange), "minRange": .int(minRange)]
        case let .unionVariantOutOfRange(variant, minRange, maxRange):
            return ["maxRange": .int(maxRange), "minRange": .int(minRange), "variant": .int(variant)]
        case let .invalidConstant(constant, data, offset):
            return [
                "constant": .bytes(constant),
                "data": .bytes(data),
                "hexConstant": .string(hexBytes(constant)),
                "hexData": .string(hexBytes(data)),
                "offset": .int(offset),
            ]
        case let .expectedZeroValueToMatchItemFixedSize(codecDescription, zeroValue, expectedSize):
            return [
                "codecDescription": .string(codecDescription),
                "expectedSize": .int(expectedSize),
                "hexZeroValue": .string(hexBytes(zeroValue)),
                "zeroValue": .bytes(zeroValue),
            ]
        case let .encodedBytesMustNotIncludeSentinel(encodedBytes, sentinel):
            return [
                "encodedBytes": .bytes(encodedBytes),
                "hexEncodedBytes": .string(hexBytes(encodedBytes)),
                "hexSentinel": .string(hexBytes(sentinel)),
                "sentinel": .bytes(sentinel),
            ]
        case let .sentinelMissingInDecodedBytes(decodedBytes, sentinel):
            return [
                "decodedBytes": .bytes(decodedBytes),
                "hexDecodedBytes": .string(hexBytes(decodedBytes)),
                "hexSentinel": .string(hexBytes(sentinel)),
                "sentinel": .bytes(sentinel),
            ]
        case let .expectedDecoderToConsumeEntireByteArray(expectedLength, numExcessBytes):
            return ["expectedLength": .int(expectedLength), "numExcessBytes": .int(numExcessBytes)]
        case let .cannotUseLexicalValuesAsEnumDiscriminators(stringValues):
            return ["stringValues": .stringArray(stringValues)]
        }
    }

    public var contextDescription: String {
        context.renderedDescription
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: SolanaErrorCode(rawValue: code), context: context)
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.codecs"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription, context: context)
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
        switch self {
        case .invalidByteLength:
            return SolanaErrorCode.addressesInvalidByteLength.rawValue
        case .stringLengthOutOfRange:
            return SolanaErrorCode.addressesStringLengthOutOfRange.rawValue
        case .invalidBase58EncodedAddress:
            return SolanaErrorCode.addressesInvalidBase58EncodedAddress.rawValue
        case .invalidEd25519PublicKey:
            return SolanaErrorCode.addressesInvalidEd25519PublicKey.rawValue
        case .malformedPDA:
            return SolanaErrorCode.addressesMalformedPDA.rawValue
        case .pdaBumpSeedOutOfRange:
            return SolanaErrorCode.addressesPDABumpSeedOutOfRange.rawValue
        case .maxNumberOfPDASeedsExceeded:
            return SolanaErrorCode.addressesMaxNumberOfPDASeedsExceeded.rawValue
        case .maxPDASeedLengthExceeded:
            return SolanaErrorCode.addressesMaxPDASeedLengthExceeded.rawValue
        case .invalidSeedsPointOnCurve:
            return SolanaErrorCode.addressesInvalidSeedsPointOnCurve.rawValue
        case .failedToFindViablePDABumpSeed:
            return SolanaErrorCode.addressesFailedToFindViablePDABumpSeed.rawValue
        case .pdaEndsWithPDAMarker:
            return SolanaErrorCode.addressesPDAEndsWithPDAMarker.rawValue
        case .invalidOffCurveAddress:
            return SolanaErrorCode.addressesInvalidOffCurveAddress.rawValue
        }
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: SolanaErrorCode(rawValue: code), context: context)
    }

    public var contextDescription: String {
        context.renderedDescription
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.addresses"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription, context: context)
    }

    public var context: SolanaErrorContext {
        switch self {
        case let .invalidByteLength(actualLength), let .stringLengthOutOfRange(actualLength):
            return ["actualLength": .int(actualLength)]
        case let .pdaBumpSeedOutOfRange(bump):
            return ["bump": .int(bump)]
        case let .maxNumberOfPDASeedsExceeded(actual, maxSeeds):
            return ["actual": .int(actual), "maxSeeds": .int(maxSeeds)]
        case let .maxPDASeedLengthExceeded(actual, index, maxSeedLength):
            return ["actual": .int(actual), "index": .int(index), "maxSeedLength": .int(maxSeedLength)]
        default:
            return .empty
        }
    }
}

public enum CryptoError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case randomValuesFunctionUnimplemented

    public var code: Int {
        SolanaErrorCode.cryptoRandomValuesFunctionUnimplemented.rawValue
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: .cryptoRandomValuesFunctionUnimplemented)
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.crypto"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription)
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
        switch self {
        case .disallowedInInsecureContext:
            return SolanaErrorCode.subtleCryptoDisallowedInInsecureContext.rawValue
        case .digestUnimplemented:
            return SolanaErrorCode.subtleCryptoDigestUnimplemented.rawValue
        case .ed25519AlgorithmUnimplemented:
            return SolanaErrorCode.subtleCryptoEd25519AlgorithmUnimplemented.rawValue
        case .exportFunctionUnimplemented:
            return SolanaErrorCode.subtleCryptoExportFunctionUnimplemented.rawValue
        case .generateFunctionUnimplemented:
            return SolanaErrorCode.subtleCryptoGenerateFunctionUnimplemented.rawValue
        case .signFunctionUnimplemented:
            return SolanaErrorCode.subtleCryptoSignFunctionUnimplemented.rawValue
        case .verifyFunctionUnimplemented:
            return SolanaErrorCode.subtleCryptoVerifyFunctionUnimplemented.rawValue
        case .cannotExportNonExtractableKey:
            return SolanaErrorCode.subtleCryptoCannotExportNonExtractableKey.rawValue
        }
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: SolanaErrorCode(rawValue: code))
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.subtle-crypto"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription)
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
        switch self {
        case .invalidKeyPairByteLength:
            return SolanaErrorCode.keysInvalidKeyPairByteLength.rawValue
        case .invalidPrivateKeyByteLength:
            return SolanaErrorCode.keysInvalidPrivateKeyByteLength.rawValue
        case .invalidSignatureByteLength:
            return SolanaErrorCode.keysInvalidSignatureByteLength.rawValue
        case .signatureStringLengthOutOfRange:
            return SolanaErrorCode.keysSignatureStringLengthOutOfRange.rawValue
        case .publicKeyMustMatchPrivateKey:
            return SolanaErrorCode.keysPublicKeyMustMatchPrivateKey.rawValue
        case .invalidBase58InGrindRegex:
            return SolanaErrorCode.keysInvalidBase58InGrindRegex.rawValue
        case .writeKeyPairUnsupportedEnvironment:
            return SolanaErrorCode.keysWriteKeyPairUnsupportedEnvironment.rawValue
        }
    }

    public var context: SolanaErrorContext {
        switch self {
        case let .invalidKeyPairByteLength(byteLength):
            return ["byteLength": .int(byteLength)]
        case let .invalidPrivateKeyByteLength(actualLength),
             let .invalidSignatureByteLength(actualLength),
             let .signatureStringLengthOutOfRange(actualLength):
            return ["actualLength": .int(actualLength)]
        default:
            return .empty
        }
    }

    public var contextDescription: String {
        context.renderedDescription
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: SolanaErrorCode(rawValue: code), context: context)
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.keys"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription, context: context)
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
        switch self {
        case .addressCannotHaveMultipleSigners:
            return SolanaErrorCode.signerAddressCannotHaveMultipleSigners.rawValue
        case .expectedKeyPairSigner:
            return SolanaErrorCode.signerExpectedKeyPairSigner.rawValue
        case .expectedMessageSigner:
            return SolanaErrorCode.signerExpectedMessageSigner.rawValue
        case .expectedMessageModifyingSigner:
            return SolanaErrorCode.signerExpectedMessageModifyingSigner.rawValue
        case .expectedMessagePartialSigner:
            return SolanaErrorCode.signerExpectedMessagePartialSigner.rawValue
        case .expectedTransactionSigner:
            return SolanaErrorCode.signerExpectedTransactionSigner.rawValue
        case .expectedTransactionModifyingSigner:
            return SolanaErrorCode.signerExpectedTransactionModifyingSigner.rawValue
        case .expectedTransactionPartialSigner:
            return SolanaErrorCode.signerExpectedTransactionPartialSigner.rawValue
        case .expectedTransactionSendingSigner:
            return SolanaErrorCode.signerExpectedTransactionSendingSigner.rawValue
        case .transactionCannotHaveMultipleSendingSigners:
            return SolanaErrorCode.signerTransactionCannotHaveMultipleSendingSigners.rawValue
        case .transactionSendingSignerMissing:
            return SolanaErrorCode.signerTransactionSendingSignerMissing.rawValue
        case .walletMultisignUnimplemented:
            return SolanaErrorCode.signerWalletMultisignUnimplemented.rawValue
        case .walletAccountCannotSignTransaction:
            return SolanaErrorCode.signerWalletAccountCannotSignTransaction.rawValue
        }
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: SolanaErrorCode(rawValue: code))
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.signer"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription)
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
        switch self {
        case .invokedProgramsCannotPayFees:
            return SolanaErrorCode.transactionInvokedProgramsCannotPayFees.rawValue
        case .invokedProgramsMustNotBeWritable:
            return SolanaErrorCode.transactionInvokedProgramsMustNotBeWritable.rawValue
        case .expectedBlockhashLifetime:
            return SolanaErrorCode.transactionExpectedBlockhashLifetime.rawValue
        case .expectedNonceLifetime:
            return SolanaErrorCode.transactionExpectedNonceLifetime.rawValue
        case .versionNumberOutOfRange:
            return SolanaErrorCode.transactionVersionNumberOutOfRange.rawValue
        case .signaturesMissing:
            return SolanaErrorCode.transactionSignaturesMissing.rawValue
        case .addressMissing:
            return SolanaErrorCode.transactionAddressMissing.rawValue
        case .feePayerMissing:
            return SolanaErrorCode.transactionFeePayerMissing.rawValue
        case .feePayerSignatureMissing:
            return SolanaErrorCode.transactionFeePayerSignatureMissing.rawValue
        case .addressesCannotSignTransaction:
            return SolanaErrorCode.transactionAddressesCannotSignTransaction.rawValue
        case .cannotEncodeWithEmptySignatures:
            return SolanaErrorCode.transactionCannotEncodeWithEmptySignatures.rawValue
        case .messageSignaturesMismatch:
            return SolanaErrorCode.transactionMessageSignaturesMismatch.rawValue
        case .exceedsSizeLimit:
            return SolanaErrorCode.transactionExceedsSizeLimit.rawValue
        case .versionNumberNotSupported:
            return SolanaErrorCode.transactionVersionNumberNotSupported.rawValue
        case .malformedMessageBytes:
            return SolanaErrorCode.transactionMalformedMessageBytes.rawValue
        case .cannotEncodeWithEmptyMessageBytes:
            return SolanaErrorCode.transactionCannotEncodeWithEmptyMessageBytes.rawValue
        case .cannotDecodeEmptyTransactionBytes:
            return SolanaErrorCode.transactionCannotDecodeEmptyTransactionBytes.rawValue
        }
    }

    public var context: SolanaErrorContext {
        switch self {
        case let .signaturesMissing(addresses):
            return ["addresses": .stringArray(addresses)]
        default:
            return .empty
        }
    }

    public var contextDescription: String {
        context.renderedDescription
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: SolanaErrorCode(rawValue: code), context: context)
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.transaction"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription, context: context)
    }
}

public enum RpcError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case jsonRPC(code: Int, message: String)
    case integerOverflow
    case transportHTTPHeaderForbidden(headers: [String])
    case transportHTTPError(statusCode: Int, message: String, headers: [String: String])
    case apiPlanMissingForRPCMethod(method: String)

    public var code: Int {
        switch self {
        case let .jsonRPC(code, _):
            return code
        case .integerOverflow:
            return SolanaErrorCode.rpcIntegerOverflow.rawValue
        case .transportHTTPHeaderForbidden:
            return SolanaErrorCode.rpcTransportHTTPHeaderForbidden.rawValue
        case .transportHTTPError:
            return SolanaErrorCode.rpcTransportHTTPError.rawValue
        case .apiPlanMissingForRPCMethod:
            return SolanaErrorCode.rpcAPIPlanMissingForRPCMethod.rawValue
        }
    }

    public var context: SolanaErrorContext {
        switch self {
        case let .jsonRPC(_, message):
            return ["__serverMessage": .string(message)]
        case let .transportHTTPHeaderForbidden(headers):
            return ["headers": .stringArray(headers)]
        case let .transportHTTPError(statusCode, message, headers):
            return [
                "headers": .object(headers.mapValues(SolanaErrorContextValue.string)),
                "message": .string(message),
                "statusCode": .int(statusCode),
            ]
        case let .apiPlanMissingForRPCMethod(method):
            return ["method": .string(method)]
        case .integerOverflow:
            return .empty
        }
    }

    public var contextDescription: String {
        context.renderedDescription
    }

    public var errorDescription: String? {
        solanaErrorMessage(code: SolanaErrorCode(rawValue: code), context: context)
    }

    public static var errorDomain: String {
        "org.solana.swift-solana-kit.rpc"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        errorUserInfoDictionary(description: errorDescription, context: context)
    }
}

public func solanaErrorMessage(code: SolanaErrorCode, context: SolanaErrorContext = .empty) -> String {
    let format = solanaErrorMessages[code.rawValue] ?? "Solana error #$code"
    var rendered = render(format: format, context: context)
    if code.rawValue >= SolanaErrorCode.instructionErrorUnknown.rawValue,
       code.rawValue < SolanaErrorCode.instructionErrorUnknown.rawValue + 1000,
       case let .int(index)? = context["index"]
    {
        rendered += " (instruction #\(index + 1))"
    }
    return rendered
}

extension SolanaErrorContext {
    var renderedDescription: String {
        guard !values.isEmpty else { return "" }
        return values.keys.sorted().map { key in
            guard let value = values[key] else { return "\(key)=" }
            return "\(key)=\(value)"
        }.joined(separator: ", ")
    }
}

func render(format: String, context: SolanaErrorContext) -> String {
    enum State {
        case text(Int)
        case variable(Int)
        case escape
    }

    let codeUnits = Array(format.utf16)
    guard !codeUnits.isEmpty else { return "" }

    var output = ""
    var state: State = codeUnits[0] == 92 ? .escape : (codeUnits[0] == 36 ? .variable(0) : .text(0))

    func isWord(_ codeUnit: UInt16) -> Bool {
        codeUnit == 95 ||
            (codeUnit >= 48 && codeUnit <= 57) ||
            (codeUnit >= 65 && codeUnit <= 90) ||
            (codeUnit >= 97 && codeUnit <= 122)
    }

    func appendRange(_ start: Int, _ end: Int) {
        guard start < end else { return }
        output += String(decoding: codeUnits[start ..< end], as: UTF16.self)
    }

    func commit(upTo end: Int? = nil) {
        let end = end ?? codeUnits.count
        switch state {
        case let .text(start):
            appendRange(start, end)
        case let .variable(start):
            let variableName = String(decoding: codeUnits[(start + 1) ..< end], as: UTF16.self)
            if let value = context[variableName] {
                output += value.description
            } else {
                output += "$\(variableName)"
            }
        case .escape:
            break
        }
    }

    for index in codeUnits.indices.dropFirst() {
        let codeUnit = codeUnits[index]
        var nextState: State?
        switch state {
        case .escape:
            nextState = .text(index)
        case .text:
            if codeUnit == 92 {
                nextState = .escape
            } else if codeUnit == 36 {
                nextState = .variable(index)
            }
        case .variable:
            if codeUnit == 92 {
                nextState = .escape
            } else if codeUnit == 36 {
                nextState = .variable(index)
            } else if !isWord(codeUnit) {
                nextState = .text(index)
            }
        }
        if let nextState {
            commit(upTo: index)
            state = nextState
        }
    }

    commit()
    return output
}

func errorUserInfoDictionary(description: String?, context: SolanaErrorContext = .empty) -> [String: Any] {
    [
        NSLocalizedDescriptionKey: description ?? "",
        "context": context.renderedDescription,
    ]
}

func hexBytes(_ bytes: Data) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}
