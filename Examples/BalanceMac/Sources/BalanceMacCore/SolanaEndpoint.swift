public import Foundation

public struct SolanaEndpoint: Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let url: URL

    public init(id: String, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }

    public static let devnet = SolanaEndpoint(
        id: "devnet",
        name: "Devnet",
        url: knownURL("https://api.devnet.solana.com")
    )

    public static let testnet = SolanaEndpoint(
        id: "testnet",
        name: "Testnet",
        url: knownURL("https://api.testnet.solana.com")
    )

    public static let mainnetBeta = SolanaEndpoint(
        id: "mainnet-beta",
        name: "Mainnet Beta",
        url: knownURL("https://api.mainnet-beta.solana.com")
    )

    public static let custom = SolanaEndpoint(
        id: "custom",
        name: "Custom",
        url: knownURL("https://api.devnet.solana.com")
    )

    public static let presets: [SolanaEndpoint] = [.devnet, .testnet, .mainnetBeta, .custom]

    public static func custom(urlText: String) throws -> SolanaEndpoint {
        guard let url = URL(string: urlText), let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            throw BalanceLookupError.invalidEndpoint(urlText)
        }
        return SolanaEndpoint(id: "custom", name: "Custom", url: url)
    }

    private static func knownURL(_ value: String) -> URL {
        URL(string: value) ?? URL(fileURLWithPath: "/")
    }
}
