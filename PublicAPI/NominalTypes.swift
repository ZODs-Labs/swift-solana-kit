public protocol NominalMarker: Sendable {}
public enum ValidAffinePoint: NominalMarker {}
public enum InvalidAffinePoint: NominalMarker {}
public enum Base58Encoding: NominalMarker {}
public enum Base64Encoding: NominalMarker {}
public enum ZstdCompression: NominalMarker {}
public struct Brand<RawValue: Sendable, Marker: NominalMarker>: RawRepresentable, Sendable {
    public let rawValue: RawValue
    public init(rawValue: RawValue)
}
public typealias AffinePoint<RawValue: Sendable, Validity: NominalMarker> = Brand<RawValue, Validity>
public typealias CompressedData<RawValue: Sendable, Format: NominalMarker> = Brand<RawValue, Format>
public typealias EncodedString<Encoding: NominalMarker> = Brand<String, Encoding>
