public import CodecsCore
public import CryptoBackend
public import Foundation
public import SolanaErrors
import CodecsStrings

private let addressByteLength = 32
private let minimumAddressStringLength = 32
private let maximumAddressStringLength = 44
private let maximumSeedLength = 32
private let maximumSeeds = 16
private let pdaMarkerBytes = Data([
    80, 114, 111, 103, 114, 97, 109, 68, 101, 114, 105, 118, 101, 100, 65, 100,
    100, 114, 101, 115, 115,
])

public struct Address: Sendable, Equatable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let rawValue: String

    public var description: String {
        rawValue
    }

    public init(_ rawValue: String) throws(AddressValidationError) {
        try assertIsAddress(rawValue)
        self.rawValue = rawValue
    }

    package init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = try address(value)
    }

    public func encode(to encoder: any Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Address, rhs: Address) -> Bool {
        compareAddressStrings(lhs.rawValue, rhs.rawValue) < 0
    }
}

public enum AddressValidationError: SolanaErrorCoded, Sendable, Equatable, LocalizedError, CustomNSError {
    case addresses(AddressError)
    case codecs(CodecsError)

    public var code: Int {
        switch self {
        case let .addresses(error):
            error.code
        case let .codecs(error):
            error.code
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .addresses(error):
            error.errorDescription
        case let .codecs(error):
            error.errorDescription
        }
    }

    public var contextDescription: String {
        switch self {
        case let .addresses(error):
            error.contextDescription
        case let .codecs(error):
            error.contextDescription
        }
    }

    public static var errorDomain: String {
        "Solana.AddressValidationError"
    }

    public var errorCode: Int {
        code
    }

    public var errorUserInfo: [String: Any] {
        switch self {
        case let .addresses(error):
            error.errorUserInfo
        case let .codecs(error):
            error.errorUserInfo
        }
    }
}

public struct OffCurveAddress: Sendable, Equatable, Hashable, CustomStringConvertible {
    public let address: Address

    public var rawValue: String {
        address.rawValue
    }

    public var description: String {
        rawValue
    }

    init(_ address: Address) {
        self.address = address
    }
}

public enum ProgramDerivedAddressSeed: Sendable, Equatable {
    case bytes(Data)
    case utf8(String)

    func data() -> Data {
        switch self {
        case let .bytes(bytes):
            bytes
        case let .utf8(value):
            Data(value.utf8)
        }
    }
}

public struct ProgramDerivedAddressBump: Sendable, Equatable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let rawValue: UInt8

    public var description: String {
        String(rawValue)
    }

    public init(_ rawValue: Int) throws(AddressError) {
        guard rawValue >= 0 && rawValue <= 255 else {
            throw AddressError.pdaBumpSeedOutOfRange(bump: rawValue)
        }
        self.rawValue = UInt8(rawValue)
    }

    init(unchecked rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static func < (lhs: ProgramDerivedAddressBump, rhs: ProgramDerivedAddressBump) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ProgramDerivedAddress: Sendable, Equatable, Hashable, Codable {
    public let address: Address
    public let bump: ProgramDerivedAddressBump

    public init(address: Address, bump: ProgramDerivedAddressBump) {
        self.address = address
        self.bump = bump
    }
}

public func assertIsAddress(_ putativeAddress: String) throws(AddressValidationError) {
    let length = putativeAddress.utf16.count
    guard length >= minimumAddressStringLength && length <= maximumAddressStringLength else {
        throw .addresses(.stringLengthOutOfRange(actualLength: length))
    }

    let bytes: Data
    do {
        bytes = try getBase58Encoder().encode(putativeAddress)
    } catch let error {
        throw .codecs(error)
    }

    guard bytes.count == addressByteLength else {
        throw .addresses(.invalidByteLength(actualLength: bytes.count))
    }
}

public func isAddress(_ putativeAddress: String) -> Bool {
    do {
        try assertIsAddress(putativeAddress)
        return true
    } catch {
        return false
    }
}

public func address(_ putativeAddress: String) throws(AddressValidationError) -> Address {
    try Address(putativeAddress)
}

public func getAddressEncoder() -> AnyFixedSizeEncoder<Address> {
    let encoder = fixEncoderSize(getBase58Encoder(), fixedBytes: addressByteLength)
    return transformEncoder(encoder) { address in address.rawValue }
}

public func getAddressDecoder() -> AnyFixedSizeDecoder<Address> {
    let decoder = fixDecoderSize(getBase58Decoder(), fixedBytes: addressByteLength)
    return transformDecoder(decoder) { Address(unchecked: $0) }
}

public func getAddressCodec() -> AnyFixedSizeCodec<Address, Address> {
    let encoder = getAddressEncoder()
    let decoder = getAddressDecoder()
    return createCodec(fixedSize: addressByteLength) { value, bytes, offset in
        try encoder.write(value, into: &bytes, at: offset)
    } read: { bytes, offset in
        try decoder.read(bytes, at: offset)
    }
}

public func getAddressComparator() -> @Sendable (Address, Address) -> Int {
    { lhs, rhs in compareAddressStrings(lhs.rawValue, rhs.rawValue) }
}

public func isOffCurveAddress(_ putativeOffCurveAddress: Address, using backend: any CryptoBackend) -> Bool {
    guard let bytes = try? addressBytes(putativeOffCurveAddress) else {
        return false
    }
    return backend.isOnCurve(bytes) == false
}

public func assertIsOffCurveAddress(
    _ putativeOffCurveAddress: Address,
    using backend: any CryptoBackend
) throws(AddressError) {
    guard isOffCurveAddress(putativeOffCurveAddress, using: backend) else {
        throw AddressError.invalidOffCurveAddress
    }
}

public func offCurveAddress(
    _ putativeOffCurveAddress: Address,
    using backend: any CryptoBackend
) throws(AddressError) -> OffCurveAddress {
    try assertIsOffCurveAddress(putativeOffCurveAddress, using: backend)
    return OffCurveAddress(putativeOffCurveAddress)
}

public func getAddressFromPublicKey(_ publicKeyBytes: Data) throws(AddressError) -> Address {
    guard publicKeyBytes.count == addressByteLength else {
        throw AddressError.invalidEd25519PublicKey
    }
    return try uncheckedAddress(from: publicKeyBytes)
}

public func getPublicKeyFromAddress(_ address: Address) throws(CodecsError) -> Data {
    try getAddressEncoder().encode(address)
}

public func isProgramDerivedAddress(_ value: ProgramDerivedAddress) -> Bool {
    isAddress(value.address.rawValue)
}

public func assertIsProgramDerivedAddress(_ value: ProgramDerivedAddress) throws(AddressError) {
    guard isProgramDerivedAddress(value) else {
        throw AddressError.malformedPDA
    }
}

public func getProgramDerivedAddress(
    programAddress: Address,
    seeds: [ProgramDerivedAddressSeed],
    using backend: any CryptoBackend
) throws(AddressError) -> ProgramDerivedAddress {
    var bumpSeed = 255
    while bumpSeed > 0 {
        do {
            let address = try createProgramDerivedAddress(
                programAddress: programAddress,
                seeds: seeds + [.bytes(Data([UInt8(bumpSeed)]))],
                using: backend
            )
            return ProgramDerivedAddress(
                address: address,
                bump: ProgramDerivedAddressBump(unchecked: UInt8(bumpSeed))
            )
        } catch AddressError.invalidSeedsPointOnCurve {
            bumpSeed -= 1
        } catch {
            throw error
        }
    }
    throw AddressError.failedToFindViablePDABumpSeed
}

public func createAddressWithSeed(
    baseAddress: Address,
    programAddress: Address,
    seed: ProgramDerivedAddressSeed,
    using backend: any CryptoBackend
) throws(AddressError) -> Address {
    let seedBytes = try validatedSeedBytes(seed, index: 0)
    let programAddressBytes = try addressBytes(programAddress)

    if programAddressBytes.count >= pdaMarkerBytes.count &&
        programAddressBytes.suffix(pdaMarkerBytes.count) == pdaMarkerBytes {
        throw AddressError.pdaEndsWithPDAMarker
    }

    let digest = backend.sha256(try addressBytes(baseAddress) + seedBytes + programAddressBytes)
    return try uncheckedAddress(from: digest)
}

func compressedPointBytesAreOnCurve(_ bytes: Data, using backend: any CryptoBackend) -> Bool {
    guard bytes.count == addressByteLength else {
        return false
    }
    return backend.isOnCurve(bytes)
}

private func createProgramDerivedAddress(
    programAddress: Address,
    seeds: [ProgramDerivedAddressSeed],
    using backend: any CryptoBackend
) throws(AddressError) -> Address {
    guard seeds.count <= maximumSeeds else {
        throw AddressError.maxNumberOfPDASeedsExceeded(actual: seeds.count, maxSeeds: maximumSeeds)
    }

    var seedBytes = Data()
    for (index, seed) in seeds.enumerated() {
        seedBytes += try validatedSeedBytes(seed, index: index)
    }

    let programAddressBytes = try addressBytes(programAddress)
    let digest = backend.sha256(seedBytes + programAddressBytes + pdaMarkerBytes)
    if compressedPointBytesAreOnCurve(digest, using: backend) {
        throw AddressError.invalidSeedsPointOnCurve
    }
    return try uncheckedAddress(from: digest)
}

private func validatedSeedBytes(_ seed: ProgramDerivedAddressSeed, index: Int) throws(AddressError) -> Data {
    let bytes = seed.data()
    guard bytes.count <= maximumSeedLength else {
        throw AddressError.maxPDASeedLengthExceeded(
            actual: bytes.count,
            index: index,
            maxSeedLength: maximumSeedLength
        )
    }
    return bytes
}

private func addressBytes(_ address: Address) throws(AddressError) -> Data {
    do {
        return try getAddressEncoder().encode(address)
    } catch {
        throw AddressError.invalidBase58EncodedAddress
    }
}

private func uncheckedAddress(from bytes: Data) throws(AddressError) -> Address {
    do {
        return try getAddressDecoder().decode(bytes)
    } catch {
        throw AddressError.invalidByteLength(actualLength: bytes.count)
    }
}

private func compareAddressStrings(_ lhs: String, _ rhs: String) -> Int {
    let lhsScalars = Array(lhs.unicodeScalars)
    let rhsScalars = Array(rhs.unicodeScalars)
    let count = Swift.min(lhsScalars.count, rhsScalars.count)

    for index in 0 ..< count {
        let lhsScalar = lhsScalars[index]
        let rhsScalar = rhsScalars[index]
        if lhsScalar == rhsScalar {
            continue
        }

        let lhsFolded = asciiFold(lhsScalar)
        let rhsFolded = asciiFold(rhsScalar)
        if lhsFolded != rhsFolded {
            return lhsFolded < rhsFolded ? -1 : 1
        }

        let lhsIsLowercase = isAsciiLowercase(lhsScalar)
        let rhsIsLowercase = isAsciiLowercase(rhsScalar)
        if lhsIsLowercase != rhsIsLowercase {
            return lhsIsLowercase ? -1 : 1
        }

        return lhsScalar.value < rhsScalar.value ? -1 : 1
    }

    if lhsScalars.count == rhsScalars.count {
        return 0
    }
    return lhsScalars.count < rhsScalars.count ? -1 : 1
}

private func asciiFold(_ scalar: UnicodeScalar) -> UInt32 {
    if scalar.value >= 65 && scalar.value <= 90 {
        return scalar.value + 32
    }
    return scalar.value
}

private func isAsciiLowercase(_ scalar: UnicodeScalar) -> Bool {
    scalar.value >= 97 && scalar.value <= 122
}
