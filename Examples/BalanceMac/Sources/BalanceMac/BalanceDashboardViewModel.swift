import BalanceMacCore
import Observation

@MainActor
@Observable
final class BalanceDashboardViewModel {
    var addressText = "11111111111111111111111111111111"
    var selectedEndpointID = SolanaEndpoint.devnet.id
    var customEndpointText = SolanaEndpoint.devnet.url.absoluteString
    private(set) var snapshot: BalanceLookupSnapshot?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    @ObservationIgnored private let service: BalanceLookupService

    init(service: BalanceLookupService = BalanceLookupService()) {
        self.service = service
    }

    var canSubmit: Bool {
        !isLoading && !addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refreshIfNeeded() async {
        guard snapshot == nil, errorMessage == nil else {
            return
        }
        await refresh()
    }

    func refresh() async {
        let address = addressText
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let endpoint = try selectedEndpoint()
            snapshot = try await service.lookup(addressText: address, endpoint: endpoint)
        } catch {
            snapshot = nil
            errorMessage = error.localizedDescription
        }
    }

    private func selectedEndpoint() throws -> SolanaEndpoint {
        if selectedEndpointID == SolanaEndpoint.custom.id {
            return try SolanaEndpoint.custom(urlText: customEndpointText)
        }
        return SolanaEndpoint.presets.first { $0.id == selectedEndpointID } ?? .devnet
    }
}
