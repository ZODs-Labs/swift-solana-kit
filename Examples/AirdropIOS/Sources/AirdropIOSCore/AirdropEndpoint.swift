public import Foundation

public struct AirdropEndpoint: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let url: URL

    public init(id: String, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }

    public static let devnet = AirdropEndpoint(
        id: "devnet",
        name: "Devnet",
        url: knownURL("https://api.devnet.solana.com")
    )

    public static let localnet = AirdropEndpoint(
        id: "localnet",
        name: "Local Validator",
        url: knownURL("http://127.0.0.1:8899")
    )

    public static let presets: [AirdropEndpoint] = [.devnet, .localnet]

    private static func knownURL(_ value: String) -> URL {
        URL(string: value) ?? URL(fileURLWithPath: "/")
    }
}
