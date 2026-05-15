public import Addresses
import CodecsCore
import CodecsNumbers
public import CryptoBackend
public import Foundation
import Instructions
public import Keys
import SolanaErrors
public import TransactionMessages

public typealias TransactionMessageBytes = Data
public typealias TransactionMessageBytesBase64 = String
public typealias Base64EncodedWireTransaction = String

private let signatureByteLength = 64
private let signatureCountFlagMask: UInt8 = 0b1000_0000
private let versionFlagMask: UInt8 = 0b0111_1111
private let v1StaticAddressOffset = 1 + 3 + 4 + 32 + 1 + 1
private let systemProgramAddress = Address(unchecked: "11111111111111111111111111111111")

public struct TransactionSignature: Sendable, Equatable, Hashable {
    public let address: Address
    public let signature: SignatureBytes?

    public init(address: Address, signature: SignatureBytes?) {
        self.address = address
        self.signature = signature
    }
}

public struct SignaturesMap: Sendable, Equatable, Hashable {
    public let entries: [TransactionSignature]

    public init(entries: [TransactionSignature] = []) {
        self.entries = Self.collapse(entries)
    }

    public init(_ pairs: [(Address, SignatureBytes?)]) {
        self.init(entries: pairs.map { TransactionSignature(address: $0.0, signature: $0.1) })
    }

    public var count: Int {
        entries.count
    }

    public var isEmpty: Bool {
        entries.isEmpty
    }

    public var addresses: [Address] {
        entries.map(\.address)
    }

    public var signatures: [SignatureBytes?] {
        entries.map(\.signature)
    }

    public func contains(_ address: Address) -> Bool {
        index(of: address) != nil
    }

    public func signature(for address: Address) -> SignatureBytes? {
        guard let index = index(of: address) else {
            return nil
        }
        return entries[index].signature
    }

    func replacing(_ updates: [Address: SignatureBytes]) -> SignaturesMap {
        let replaced = entries.map { entry in
            TransactionSignature(address: entry.address, signature: updates[entry.address] ?? entry.signature)
        }
        return SignaturesMap(entries: replaced)
    }

    func index(of address: Address) -> Int? {
        entries.firstIndex { $0.address == address }
    }

    private static func collapse(_ entries: [TransactionSignature]) -> [TransactionSignature] {
        var out: [TransactionSignature] = []
        for entry in entries {
            if let index = out.firstIndex(where: { $0.address == entry.address }) {
                out[index] = entry
            } else {
                out.append(entry)
            }
        }
        return out
    }
}

public struct TransactionBlockhashLifetime: Sendable, Equatable, Hashable {
    public let blockhash: Blockhash
    public let lastValidBlockHeight: UInt64

    public init(blockhash: Blockhash, lastValidBlockHeight: UInt64) {
        self.blockhash = blockhash
        self.lastValidBlockHeight = lastValidBlockHeight
    }
}

public struct TransactionDurableNonceLifetime: Sendable, Equatable, Hashable {
    public let nonce: Nonce
    public let nonceAccountAddress: Address

    public init(nonce: Nonce, nonceAccountAddress: Address) {
        self.nonce = nonce
        self.nonceAccountAddress = nonceAccountAddress
    }
}

public enum TransactionLifetimeConstraint: Sendable, Equatable, Hashable {
    case blockhash(TransactionBlockhashLifetime)
    case nonce(TransactionDurableNonceLifetime)
}

public struct Transaction: Sendable, Equatable, Hashable {
    public let messageBytes: TransactionMessageBytes
    public let signatures: SignaturesMap
    public let lifetimeConstraint: TransactionLifetimeConstraint?

    public init(
        messageBytes: TransactionMessageBytes,
        signatures: SignaturesMap,
        lifetimeConstraint: TransactionLifetimeConstraint? = nil
    ) {
        self.messageBytes = messageBytes
        self.signatures = signatures
        self.lifetimeConstraint = lifetimeConstraint
    }
}

public let transactionPacketSize = 1_280
public let transactionPacketHeaderSize = 40 + 8
public let transactionSizeLimit = transactionPacketSize - transactionPacketHeaderSize
public let legacyTransactionSizeLimit = 1_232
public let v1TransactionSizeLimit = 4_096

public struct TransactionEncoder: Sendable {
    public init() {}

    public func getSizeFromValue(_ transaction: Transaction) throws -> Int {
        switch try envelopeShape(messageBytes: transaction.messageBytes) {
        case .signaturesFirst:
            return try shortU16Size(transaction.signatures.count) + encodedSignaturesSize(transaction.signatures)
                + transaction.messageBytes.count
        case .messageFirst:
            let signatureCount = try signatureCountForVersionedMessage(transaction.messageBytes, offset: 0)
            return transaction.messageBytes.count + signatureCount * signatureByteLength
        }
    }

    public func encode(_ transaction: Transaction) throws -> Data {
        var bytes = Data(count: try getSizeFromValue(transaction))
        _ = try write(transaction, into: &bytes, at: 0)
        return bytes
    }

    public func write(_ transaction: Transaction, into bytes: inout Data, at offset: Int) throws -> Int {
        let encoded: Data
        switch try envelopeShape(messageBytes: transaction.messageBytes) {
        case .signaturesFirst:
            var next = Data()
            next.append(try encodeShortU16(transaction.signatures.count))
            next.append(try encodeSignatures(transaction.signatures))
            next.append(transaction.messageBytes)
            encoded = next
        case .messageFirst:
            let signatureCount = try signatureCountForVersionedMessage(transaction.messageBytes, offset: 0)
            var next = Data()
            next.append(transaction.messageBytes)
            next.append(try encodeSignatures(transaction.signatures, fixedCount: signatureCount))
            encoded = next
        }
        try writeData(encoded, into: &bytes, at: offset, description: "transaction")
        return offset + encoded.count
    }
}

public struct TransactionDecoder: Sendable {
    public init() {}

    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Transaction {
        try read(bytes, at: offset).0
    }

    public func read(_ bytes: Data, at offset: Int) throws -> (Transaction, Int) {
        switch try envelopeShape(transactionBytes: bytes, offset: offset) {
        case .signaturesFirst:
            return try readSignaturesFirst(bytes, offset: offset)
        case .messageFirst:
            return try readMessageFirst(bytes, offset: offset)
        }
    }
}

public struct TransactionCodec: Sendable {
    private let encoder = TransactionEncoder()
    private let decoder = TransactionDecoder()

    public init() {}

    public func getSizeFromValue(_ transaction: Transaction) throws -> Int {
        try encoder.getSizeFromValue(transaction)
    }

    public func encode(_ transaction: Transaction) throws -> Data {
        try encoder.encode(transaction)
    }

    public func write(_ transaction: Transaction, into bytes: inout Data, at offset: Int) throws -> Int {
        try encoder.write(transaction, into: &bytes, at: offset)
    }

    public func decode(_ bytes: Data, at offset: Int = 0) throws -> Transaction {
        try decoder.decode(bytes, at: offset)
    }

    public func read(_ bytes: Data, at offset: Int) throws -> (Transaction, Int) {
        try decoder.read(bytes, at: offset)
    }
}

public func compileTransaction(_ transactionMessage: TransactionMessage) throws -> Transaction {
    let compiledMessage = try compileTransactionMessage(transactionMessage)
    let messageBytes = try getCompiledTransactionMessageEncoder().encode(compiledMessage)
    let signerAddresses = compiledMessage.staticAccountsForTransactions.prefix(compiledMessage.headerForTransactions.numSignerAccounts)
    let signatures = SignaturesMap(entries: signerAddresses.map {
        TransactionSignature(address: $0, signature: nil)
    })

    let lifetimeConstraint: TransactionLifetimeConstraint?
    switch transactionMessage.lifetimeConstraint {
    case let .blockhash(constraint):
        lifetimeConstraint = .blockhash(
            TransactionBlockhashLifetime(
                blockhash: constraint.blockhash,
                lastValidBlockHeight: constraint.lastValidBlockHeight
            )
        )
    case let .nonce(constraint):
        if isTransactionMessageWithDurableNonceLifetime(transactionMessage),
           let nonceAccountAddress = transactionMessage.instructions.first?.accounts?.first?.address {
            lifetimeConstraint = .nonce(
                TransactionDurableNonceLifetime(
                    nonce: constraint.nonce,
                    nonceAccountAddress: nonceAccountAddress
                )
            )
        } else {
            lifetimeConstraint = nil
        }
    case nil:
        lifetimeConstraint = nil
    }

    return Transaction(messageBytes: messageBytes, signatures: signatures, lifetimeConstraint: lifetimeConstraint)
}

public func getTransactionLifetimeConstraintFromCompiledTransactionMessage(
    _ compiledTransactionMessage: CompiledTransactionMessage
) throws -> TransactionLifetimeConstraint {
    switch compiledTransactionMessage {
    case let .legacy(message):
        return try transactionLifetimeConstraintForLegacyOrV0(
            instructions: message.instructions,
            lifetimeToken: message.lifetimeToken,
            staticAccounts: message.staticAccounts
        )
    case let .v0(message):
        return try transactionLifetimeConstraintForLegacyOrV0(
            instructions: message.instructions,
            lifetimeToken: message.lifetimeToken,
            staticAccounts: message.staticAccounts
        )
    case let .v1(message):
        guard let lifetimeToken = message.lifetimeToken else {
            throw SolanaError(.transactionExpectedBlockhashLifetime)
        }
        if let header = message.instructionHeaders.first,
           let payload = message.instructionPayloads.first,
           compiledV1InstructionIsAdvanceNonceInstruction(
               header: header,
               payload: payload,
               staticAccounts: message.staticAccounts
           ) {
            guard let nonceIndex = payload.instructionAccountIndices.first else {
                throw SolanaError(
                    .transactionInvalidNonceAccountIndex,
                    context: [
                        "nonce": .string(lifetimeToken),
                        "nonceAccountIndex": .int(-1),
                        "numberOfStaticAccounts": .int(message.staticAccounts.count),
                    ]
                )
            }
            guard nonceIndex >= 0, nonceIndex < message.staticAccounts.count else {
                throw SolanaError(
                    .transactionInvalidNonceAccountIndex,
                    context: [
                        "nonce": .string(lifetimeToken),
                        "nonceAccountIndex": .int(nonceIndex),
                        "numberOfStaticAccounts": .int(message.staticAccounts.count),
                    ]
                )
            }
            return .nonce(
                TransactionDurableNonceLifetime(
                    nonce: lifetimeToken,
                    nonceAccountAddress: message.staticAccounts[nonceIndex]
                )
            )
        }
        return .blockhash(TransactionBlockhashLifetime(blockhash: lifetimeToken, lastValidBlockHeight: UInt64.max))
    }
}

public func isTransactionWithBlockhashLifetime(_ transaction: Transaction) -> Bool {
    if case let .blockhash(lifetime) = transaction.lifetimeConstraint {
        return isAddress(lifetime.blockhash)
    }
    return false
}

public func assertIsTransactionWithBlockhashLifetime(_ transaction: Transaction) throws {
    if !isTransactionWithBlockhashLifetime(transaction) {
        throw SolanaError(.transactionExpectedBlockhashLifetime)
    }
}

public func isTransactionWithDurableNonceLifetime(_ transaction: Transaction) -> Bool {
    if case .nonce = transaction.lifetimeConstraint {
        return true
    }
    return false
}

public func assertIsTransactionWithDurableNonceLifetime(_ transaction: Transaction) throws {
    if !isTransactionWithDurableNonceLifetime(transaction) {
        throw SolanaError(.transactionExpectedNonceLifetime)
    }
}

public func getSignatureFromTransaction(_ transaction: Transaction) throws -> Signature {
    guard let signatureBytes = transaction.signatures.entries.first?.signature else {
        throw SolanaError(.transactionFeePayerSignatureMissing)
    }
    return base58EncodedSignature(signatureBytes)
}

public func partiallySignTransaction(
    _ keyPairs: [KeyPair],
    _ transaction: Transaction,
    using backend: any CryptoBackend
) throws -> Transaction {
    var newSignatures: [Address: SignatureBytes] = [:]
    var unexpectedSigners: [Address] = []

    for keyPair in keyPairs {
        let signerAddress = try getAddressFromPublicKey(keyPair.publicKey.rawValue)
        guard let entryIndex = transaction.signatures.index(of: signerAddress) else {
            unexpectedSigners.append(signerAddress)
            continue
        }
        if !unexpectedSigners.isEmpty {
            continue
        }

        let existingSignature = transaction.signatures.entries[entryIndex].signature
        let newSignature = try signBytes(transaction.messageBytes, with: keyPair.privateKey, using: backend)
        if existingSignature == newSignature {
            continue
        }
        newSignatures[signerAddress] = newSignature
    }

    if !unexpectedSigners.isEmpty {
        throw SolanaError(
            .transactionAddressesCannotSignTransaction,
            context: [
                "expectedAddresses": .stringArray(transaction.signatures.addresses.map(\.rawValue)),
                "unexpectedAddresses": .stringArray(unexpectedSigners.map(\.rawValue)),
            ]
        )
    }

    if newSignatures.isEmpty {
        return transaction
    }

    return Transaction(
        messageBytes: transaction.messageBytes,
        signatures: transaction.signatures.replacing(newSignatures),
        lifetimeConstraint: transaction.lifetimeConstraint
    )
}

public func signTransaction(
    _ keyPairs: [KeyPair],
    _ transaction: Transaction,
    using backend: any CryptoBackend
) throws -> Transaction {
    let signedTransaction = try partiallySignTransaction(keyPairs, transaction, using: backend)
    try assertIsFullySignedTransaction(signedTransaction)
    return signedTransaction
}

public func isFullySignedTransaction(_ transaction: Transaction) -> Bool {
    transaction.signatures.entries.allSatisfy { $0.signature != nil }
}

public func assertIsFullySignedTransaction(_ transaction: Transaction) throws {
    let missingAddresses = transaction.signatures.entries.compactMap { entry in
        entry.signature == nil ? entry.address.rawValue : nil
    }
    if !missingAddresses.isEmpty {
        throw SolanaError(
            .transactionSignaturesMissing,
            context: ["addresses": .stringArray(missingAddresses)]
        )
    }
}

public func isSendableTransaction(_ transaction: Transaction) throws -> Bool {
    if !isFullySignedTransaction(transaction) {
        return false
    }
    return try isTransactionWithinSizeLimit(transaction)
}

public func assertIsSendableTransaction(_ transaction: Transaction) throws {
    try assertIsFullySignedTransaction(transaction)
    try assertIsTransactionWithinSizeLimit(transaction)
}

public func getTransactionEncoder() -> TransactionEncoder {
    TransactionEncoder()
}

public func getTransactionDecoder() -> TransactionDecoder {
    TransactionDecoder()
}

public func getTransactionCodec() -> TransactionCodec {
    TransactionCodec()
}

public func getBase64EncodedWireTransaction(_ transaction: Transaction) throws -> Base64EncodedWireTransaction {
    try getTransactionEncoder().encode(transaction).base64EncodedString()
}

public func getTransactionSize(_ transaction: Transaction) throws -> Int {
    try getTransactionEncoder().getSizeFromValue(transaction)
}

public func getTransactionSizeLimit(_ transaction: Transaction) -> Int {
    let firstByte = transaction.messageBytes.first ?? 0
    return (firstByte & versionFlagMask) == 1 ? v1TransactionSizeLimit : legacyTransactionSizeLimit
}

public func isTransactionWithinSizeLimit(_ transaction: Transaction) throws -> Bool {
    if transaction.messageBytes.isEmpty {
        return true
    }
    let size = try getTransactionSize(transaction)
    return size <= getTransactionSizeLimit(transaction)
}

public func assertIsTransactionWithinSizeLimit(_ transaction: Transaction) throws {
    if transaction.messageBytes.isEmpty {
        return
    }
    let sizeLimit = getTransactionSizeLimit(transaction)
    let transactionSize = try getTransactionSize(transaction)
    if transactionSize > sizeLimit {
        throw SolanaError(
            .transactionExceedsSizeLimit,
            context: [
                "transactionSize": .int(transactionSize),
                "transactionSizeLimit": .int(sizeLimit),
            ]
        )
    }
}

public func getTransactionMessageSize(_ transactionMessage: TransactionMessage) throws -> Int {
    try getTransactionSize(compileTransaction(transactionMessage))
}

public func getTransactionMessageSizeLimit(_ transactionMessage: TransactionMessage) -> Int {
    transactionMessage.version == .v1 ? v1TransactionSizeLimit : legacyTransactionSizeLimit
}

public func isTransactionMessageWithinSizeLimit(_ transactionMessage: TransactionMessage) throws -> Bool {
    let transactionSize = try getTransactionMessageSize(transactionMessage)
    return transactionSize <= getTransactionMessageSizeLimit(transactionMessage)
}

public func assertIsTransactionMessageWithinSizeLimit(_ transactionMessage: TransactionMessage) throws {
    let transactionSize = try getTransactionMessageSize(transactionMessage)
    let sizeLimit = getTransactionMessageSizeLimit(transactionMessage)
    if transactionSize > sizeLimit {
        throw SolanaError(
            .transactionExceedsSizeLimit,
            context: [
                "transactionSize": .int(transactionSize),
                "transactionSizeLimit": .int(sizeLimit),
            ]
        )
    }
}

private enum TransactionEnvelopeShape {
    case signaturesFirst
    case messageFirst
}

private func envelopeShape(messageBytes: Data) throws -> TransactionEnvelopeShape {
    guard let firstByte = messageBytes.first else {
        throw SolanaError(.transactionCannotEncodeWithEmptyMessageBytes)
    }
    if (firstByte & signatureCountFlagMask) == 0 {
        return .signaturesFirst
    }
    let version = Int(firstByte & versionFlagMask)
    if version == 0 {
        return .signaturesFirst
    }
    if version == 1 {
        return .messageFirst
    }
    throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(version)])
}

private func envelopeShape(transactionBytes: Data, offset: Int) throws -> TransactionEnvelopeShape {
    if offset < 0 {
        throw CodecsError.offsetOutOfRange(
            codecDescription: "transaction",
            offset: offset,
            bytesLength: transactionBytes.count
        )
    }
    guard offset < transactionBytes.count else {
        throw SolanaError(.transactionCannotDecodeEmptyTransactionBytes)
    }
    let firstByte = transactionBytes[offset]
    if (firstByte & signatureCountFlagMask) == 0 {
        return .signaturesFirst
    }
    let version = Int(firstByte & versionFlagMask)
    if version == 0 {
        throw SolanaError(
            .transactionVersionZeroMustBeEncodedWithSignaturesFirst,
            context: [
                "firstByte": .int(Int(firstByte)),
                "transactionBytes": .bytes(Data(transactionBytes[offset...])),
            ]
        )
    }
    if version == 1 {
        return .messageFirst
    }
    throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(version)])
}

private func readSignaturesFirst(_ bytes: Data, offset: Int) throws -> (Transaction, Int) {
    let (signatureCount, signaturesOffset) = try decodeShortU16(bytes, offset: offset)
    let signaturesEnd = signaturesOffset + signatureCount * signatureByteLength
    guard signaturesEnd <= bytes.count else {
        throw CodecsError.invalidByteLength(
            codecDescription: "signatures",
            expected: signaturesEnd,
            bytesLength: bytes.count
        )
    }
    var signatures: [SignatureBytes?] = []
    var nextOffset = signaturesOffset
    for _ in 0..<signatureCount {
        let signatureData = Data(bytes[nextOffset..<(nextOffset + signatureByteLength)])
        signatures.append(try decodedSignature(signatureData))
        nextOffset += signatureByteLength
    }
    let messageBytes = Data(bytes[nextOffset...])
    let signerAddresses = try decodeLegacyOrV0SignerAddresses(messageBytes)
    if signerAddresses.count != signatures.count {
        throw messageSignaturesMismatch(
            numRequiredSignatures: signerAddresses.count,
            signaturesLength: signatures.count,
            signerAddresses: signerAddresses
        )
    }
    return (
        Transaction(
            messageBytes: messageBytes,
            signatures: makeSignaturesMap(signerAddresses: signerAddresses, signatures: signatures)
        ),
        bytes.count
    )
}

private func readMessageFirst(_ bytes: Data, offset: Int) throws -> (Transaction, Int) {
    let signatureCount = try signatureCountForVersionedMessage(bytes, offset: offset)
    let signatureBytesLength = signatureCount * signatureByteLength
    let messageBytesLength = bytes.count - offset - signatureBytesLength
    if messageBytesLength < 0 {
        throw SolanaError(
            .transactionSignatureCountTooHighForTransactionBytes,
            context: [
                "numExpectedSignatures": .int(signatureCount),
                "transactionBytes": .bytes(Data(bytes[offset...])),
                "transactionBytesLength": .int(bytes.count - offset),
            ]
        )
    }
    let messageBytesEnd = offset + messageBytesLength
    let messageBytes = Data(bytes[offset..<messageBytesEnd])
    var signatures: [SignatureBytes?] = []
    var nextOffset = messageBytesEnd
    for _ in 0..<signatureCount {
        let signatureData = Data(bytes[nextOffset..<(nextOffset + signatureByteLength)])
        signatures.append(try decodedSignature(signatureData))
        nextOffset += signatureByteLength
    }
    let signerAddresses = try decodeV1SignerAddresses(messageBytes, count: signatureCount)
    if signerAddresses.count != signatures.count {
        throw messageSignaturesMismatch(
            numRequiredSignatures: signerAddresses.count,
            signaturesLength: signatures.count,
            signerAddresses: signerAddresses
        )
    }
    return (
        Transaction(
            messageBytes: messageBytes,
            signatures: makeSignaturesMap(signerAddresses: signerAddresses, signatures: signatures)
        ),
        nextOffset
    )
}

private func signatureCountForVersionedMessage(_ messageBytes: Data, offset: Int) throws -> Int {
    if messageBytes.count < offset + 2 {
        throw SolanaError(.transactionMalformedMessageBytes, context: ["messageBytes": .bytes(messageBytes)])
    }
    return Int(messageBytes[offset + 1])
}

private func decodeLegacyOrV0SignerAddresses(_ messageBytes: Data) throws -> [Address] {
    guard let firstByte = messageBytes.first else {
        throw SolanaError(.transactionMalformedMessageBytes, context: ["messageBytes": .bytes(messageBytes)])
    }

    let headerOffset: Int
    if (firstByte & signatureCountFlagMask) == 0 {
        headerOffset = 0
    } else {
        let version = Int(firstByte & versionFlagMask)
        guard version == 0 else {
            throw SolanaError(.transactionVersionNumberNotSupported, context: ["unsupportedVersion": .int(version)])
        }
        headerOffset = 1
    }
    guard messageBytes.count >= headerOffset + 3 else {
        throw SolanaError(.transactionMalformedMessageBytes, context: ["messageBytes": .bytes(messageBytes)])
    }
    let numRequiredSignatures = Int(messageBytes[headerOffset])
    let (numStaticAccounts, staticAddressOffset) = try decodeShortU16(messageBytes, offset: headerOffset + 3)
    let staticAccounts = try decodeAddresses(messageBytes, offset: staticAddressOffset, count: numStaticAccounts)
    return Array(staticAccounts.prefix(numRequiredSignatures))
}

private func decodeV1SignerAddresses(_ messageBytes: Data, count: Int) throws -> [Address] {
    try decodeAddresses(messageBytes, offset: v1StaticAddressOffset, count: count)
}

private func decodeAddresses(_ bytes: Data, offset: Int, count: Int) throws -> [Address] {
    var addresses: [Address] = []
    var nextOffset = offset
    let decoder = getAddressDecoder()
    for _ in 0..<count {
        let (address, updatedOffset) = try decoder.read(bytes, at: nextOffset)
        addresses.append(address)
        nextOffset = updatedOffset
    }
    return addresses
}

private func makeSignaturesMap(signerAddresses: [Address], signatures: [SignatureBytes?]) -> SignaturesMap {
    SignaturesMap(entries: zip(signerAddresses, signatures).map {
        TransactionSignature(address: $0.0, signature: $0.1)
    })
}

private func decodedSignature(_ signatureData: Data) throws -> SignatureBytes? {
    if signatureData.allSatisfy({ $0 == 0 }) {
        return nil
    }
    return try SignatureBytes(signatureData)
}

private func encodedSignaturesSize(_ signatures: SignaturesMap) throws -> Int {
    try ensureNonEmptySignatures(signatures)
    return signatures.count * signatureByteLength
}

private func encodeSignatures(_ signatures: SignaturesMap, fixedCount: Int? = nil) throws -> Data {
    try ensureNonEmptySignatures(signatures)
    if let fixedCount, signatures.count != fixedCount {
        throw CodecsError.invalidNumberOfItems(
            codecDescription: "signatures",
            expected: fixedCount,
            actual: signatures.count
        )
    }
    var bytes = Data()
    for entry in signatures.entries {
        bytes.append(entry.signature?.rawValue ?? Data(repeating: 0, count: signatureByteLength))
    }
    return bytes
}

private func ensureNonEmptySignatures(_ signatures: SignaturesMap) throws {
    if signatures.isEmpty {
        throw SolanaError(.transactionCannotEncodeWithEmptySignatures)
    }
}

private func compiledLegacyInstructionIsAdvanceNonceInstruction(
    _ instruction: CompiledInstruction,
    staticAccounts: [Address]
) -> Bool {
    guard instruction.programAddressIndex >= 0,
          instruction.programAddressIndex < staticAccounts.count,
          staticAccounts[instruction.programAddressIndex] == systemProgramAddress,
          instruction.data == Data([4, 0, 0, 0]),
          instruction.accountIndices?.count == 3 else {
        return false
    }
    return true
}

private func transactionLifetimeConstraintForLegacyOrV0(
    instructions: [CompiledInstruction],
    lifetimeToken: String?,
    staticAccounts: [Address]
) throws -> TransactionLifetimeConstraint {
    guard let lifetimeToken else {
        throw SolanaError(.transactionExpectedBlockhashLifetime)
    }
    if let firstInstruction = instructions.first,
       compiledLegacyInstructionIsAdvanceNonceInstruction(firstInstruction, staticAccounts: staticAccounts) {
        guard let nonceIndex = firstInstruction.accountIndices?.first,
              nonceIndex >= 0,
              nonceIndex < staticAccounts.count else {
            throw SolanaError(
                .transactionNonceAccountCannotBeInLookupTable,
                context: ["nonce": .string(lifetimeToken)]
            )
        }
        return .nonce(
            TransactionDurableNonceLifetime(
                nonce: lifetimeToken,
                nonceAccountAddress: staticAccounts[nonceIndex]
            )
        )
    }
    return .blockhash(TransactionBlockhashLifetime(blockhash: lifetimeToken, lastValidBlockHeight: UInt64.max))
}

private func compiledV1InstructionIsAdvanceNonceInstruction(
    header: InstructionHeader,
    payload: InstructionPayload,
    staticAccounts: [Address]
) -> Bool {
    guard header.programAccountIndex >= 0,
          header.programAccountIndex < staticAccounts.count,
          staticAccounts[header.programAccountIndex] == systemProgramAddress,
          payload.instructionData == Data([4, 0, 0, 0]),
          header.numInstructionAccounts == 3 else {
        return false
    }
    return true
}

private func messageSignaturesMismatch(
    numRequiredSignatures: Int,
    signaturesLength: Int,
    signerAddresses: [Address]
) -> SolanaError {
    SolanaError(
        .transactionMessageSignaturesMismatch,
        context: [
            "numRequiredSignatures": .int(numRequiredSignatures),
            "signaturesLength": .int(signaturesLength),
            "signerAddresses": .stringArray(signerAddresses.map(\.rawValue)),
        ]
    )
}

private func encodeShortU16(_ value: Int) throws -> Data {
    try getShortU16Encoder().encode(value)
}

private func decodeShortU16(_ bytes: Data, offset: Int) throws -> (Int, Int) {
    try getShortU16Decoder().read(bytes, at: offset)
}

private func shortU16Size(_ value: Int) throws -> Int {
    try getShortU16Encoder().getSizeFromValue(value)
}

private func writeData(_ source: Data, into destination: inout Data, at offset: Int, description: String) throws {
    if offset < 0 || offset > destination.count {
        throw CodecsError.offsetOutOfRange(
            codecDescription: description,
            offset: offset,
            bytesLength: destination.count
        )
    }
    let end = offset + source.count
    if end > destination.count {
        throw CodecsError.invalidByteLength(
            codecDescription: description,
            expected: end,
            bytesLength: destination.count
        )
    }
    destination.replaceSubrange(offset..<end, with: source)
}

private extension CompiledTransactionMessage {
    var headerForTransactions: MessageHeader {
        switch self {
        case let .legacy(message):
            message.header
        case let .v0(message):
            message.header
        case let .v1(message):
            message.header
        }
    }

    var staticAccountsForTransactions: [Address] {
        switch self {
        case let .legacy(message):
            message.staticAccounts
        case let .v0(message):
            message.staticAccounts
        case let .v1(message):
            message.staticAccounts
        }
    }
}
