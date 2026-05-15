public import Foundation

public struct ActivityEndpoint: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let url: URL

    public init(id: String, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }

    public static let mainnetBeta = ActivityEndpoint(
        id: "mainnet-beta",
        name: "Mainnet Beta",
        url: knownURL("https://api.mainnet-beta.solana.com")
    )

    public static let devnet = ActivityEndpoint(
        id: "devnet",
        name: "Devnet",
        url: knownURL("https://api.devnet.solana.com")
    )

    public static let testnet = ActivityEndpoint(
        id: "testnet",
        name: "Testnet",
        url: knownURL("https://api.testnet.solana.com")
    )

    public static let presets: [ActivityEndpoint] = [.mainnetBeta, .devnet, .testnet]

    private static func knownURL(_ value: String) -> URL {
        URL(string: value) ?? URL(fileURLWithPath: "/")
    }
}
